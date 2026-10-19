# 04-产品申请下单 H5 提示词（直接使用）

## 使用场景
用于实现“首页产品点击 -> H5产品申请页 -> 定位/抓取/成功页消息桥接 -> 原生好评引导”。

> **联调说明（PHI352-DC）**：以下 §8 为已验证可用的实现口径；按本文实现可直接复现「定位 → H5 下单 → uploadData 抓取 → uploadDataSucc」全链路。

## 可直接粘贴给 AI

```
实现 iOS 原生 H5 产品申请容器（Apply 页面），要求如下：

1) 入口与链接
- 首页点击产品列表项时，先请求 `/app/v3/product/termV3`（signed: **仅** productId，不参与 wire 字段混淆）。
- termV3 成功后再进入 H5 产品申请页；失败不进入并提示。
- H5 链接来自 app/config 字段 `productApplyLink`（支持相对路径拼域名）；打开时追加 `productId` 查询参数。
- 实现类：`HQTProductApplyHandler` → `HQTProductApplyH5ViewController`。

2) H5 容器
- WKWebView，隐藏原生导航，禁右滑返回，顶部进度条。
- JS 通道名固定：`iosHandler`（`WKScriptMessageHandler`）。
- `mobileUserdata`：页面加载后重试注入（与 KYC 一致，base64 + 多次重试），必含 token、baseUrl、productId、salt、countryCode 等。
- 每条桥接消息打印：`📩 [Apply] iosHandler action=... body=...`。

3) 定位消息（positionPermission）
- H5 发 `positionPermission`（action 大小写不敏感）。
- 强抓配置：`retrieveMobileContact == 1`（与通讯录强抓共用同一配置字段）。
- 若定位流程未结束 H5 就发 `uploadData`：Native **暂存 orderId**，定位回传后再启动抓取（`pendingUploadOrderId`）。

**回传 payload 口径（已联调，禁止混用）**

| 场景 | payload | H5 调用 |
|------|---------|---------|
| 有真实坐标 | `{"longitude":"121.123456","latitude":"14.567890"}` | 字符串字段，保留 6 位小数 |
| 首次系统弹窗拒绝 | `""` | `positionPermission("")` |
| 强抓拿不到定位 / b3 Cancel / b3 去设置 | `""` | 同上 |
| 非强抓、非首次、无权限 | `{"longitude":"-360","latitude":"-360"}` | 降级继续 |

**禁止**：`{"longitude":"","latitude":""}`。

**回传 H5 的实现要点（关键）**
- 写入 `localStorage` / `sessionStorage` 键 `positionPermission`（对象用 `JSON.stringify` 存）。
- 必须**依次尝试**（与 `mobileUserdata` 相同思路）：
  1. `window.positionPermission(p)` — p 为对象
  2. `window.positionPermission(JSON.stringify(p))` — 字符串
- 空串时：`positionPermission("")`，storage 也为 `""`。
- 控制台应出现：`positionPermission H5 回调 status=ok_obj` 或 `ok_str`（若为 `no_fn` 说明 H5 未注册回调）。
- 实现：`HQTProductApplyLocationBridge` + `deliverPositionPermission`（base64 注入 JS）。

4) 抓取消息（uploadData&&orderId）— **下单成功后由 H5 触发**
- H5 发字符串：`uploadData&&{orderId}`，例：`uploadData&&2059164805263581184`。
- 也支持 JSON：`{ "orderId": "..." }` 或 `{ "type": "uploadData&&..." }`。
- Native **不调用** userSubmitV3；仅 H5 下单成功后抓数。

**抓取串行链路（实现：`HQTOrderDataCaptureCoordinator`）**
1. `POST /app/v3/mobile/device`（signed: orderId；unsigned: 设备信息）— 此阶段仅 HUD Loading，**不**展示进度弹框。
2. 通讯录权限处理（强抓拒绝 / iOS 18+ **Limited 部分授权** → 失败；非强抓 → `allowContact=2` 可跳过上传）。
   - 仅 `.authorized` 可读通讯录；`requestAccess` 的 `granted` 不可单独判断（Limited 时可能仍为 true）。
   - 实现：`HQTOrderDataCaptureCoordinator` + `HQTContactsScrapeBuilder.isContactAccessGranted`（见 `05-数据抓取与通讯录分片.md` §5.3）。
3. 展示 **`HQTScrapeProgressDialog`**（Under review 进度 UI，15–20s 自然增至 99%，完成后 100% 关闭）。
4. 有联系人则分片 `POST /app/v3/mobile/contact`。
5. `POST /app/v3/order/ready`（unsigned: allowContact，授权为空串，Limited 为 `"2"`）。
6. 成功 → `uploadDataSucc()`；失败 → `uploadDataFail()`（`evalH5Callback` 调 `window.uploadDataSucc` / `window.uploadDataFail`）。

**通讯录二次引导弹框（强抓、系统已弹过后再次出现）**
- 协调器：`failOnContactsSecondaryInteraction: true`。
- 用户点 **去设置** 或 **关闭**：均 `completion(false)` → H5 `uploadDataFail()`。
- **仅产品申请页**：在 `uploadDataFail` 的 `evaluateJavaScript` **completion 之后** `popViewController` 回上一页（`onContactsSecondaryDismiss` 置位 `shouldPopAfterContactsSecondaryUploadDataFail`）。
- 其它失败场景（device/ready/首次系统拒权等）只 `uploadDataFail`，**不**自动 pop。

5) 申请页返回（productGoBack）
- H5 发 `productGoBack` → Native **直接** `popToRootViewController`，**不弹**返回确认卡片（当前产品口径）。

6) 申请成功页（successfulGoBack / successfulGoFeedback）
- 先在当前 H5 上展示好评引导（满足 `feedbackGuidance` + 安装周期一次），**不得先 pop**。
- 结束后再 `pop` 一层并刷新首页。

7) 其它桥接
- `cameraPermission` → `CameraPermissionSucc` / `CameraPermissionFail`。
- `getUserData` / `getMobileUserdata` / `getAppData` → 重新注入 `mobileUserdata`。
- `loginOut` / `deleteAccount` → 清会话回登录页。
```

## 自测清单（联调通过标准）

| 步骤 | 期望日志 / 现象 |
|------|----------------|
| 进 H5 | `mobileUserdata 注入成功`、`H5 bridge probe: iosHandler true` |
| 点 Apply 要定位 | `📩 action=positionpermission` |
| 定位回传 | `payload={"longitude":"...","latitude":"..."}` 或 `""`；`H5 回调 status=ok_str` 或 `ok_obj` |
| H5 下单成功 | `📩 action=uploaddata body=uploadData&&{orderId}` |
| 抓取 | `[Scrape] 开始 device → contact → ready`；Network 三条接口 200 |
| 结束 | `抓取成功，回调 H5 uploadDataSucc` |
| 二次通讯录弹框 | `通讯录二次弹框「去设置/关闭」→ 抓取失败` → `uploadDataFail` → `通讯录二次弹框后返回上一页` |

## 8. 已实现代码映射（后续按文档直接实现用）

| 能力 | 类 / 方法 |
|------|-----------|
| 入口 termV3 | `HQTProductApplyHandler`、`HQTNetworkClient.requestTermV3` |
| H5 容器 | `HQTProductApplyH5ViewController` |
| 桥接解析 | `HQTWebViewBridgeHelper.parseAction` / `parseUploadDataOrderId` |
| 定位 | `HQTProductApplyLocationBridge` |
| 抓取 | `HQTOrderDataCaptureCoordinator`（`failOnContactsSecondaryInteraction` / `onContactsSecondaryDismiss`） |
| 进度弹框 | `HQTScrapeProgressDialog`（`HQTHomeDialogs.swift`） |
| 好评 | `HQTProductRatingGuideDialog` |
| 网络日志 | `HQTNetworkLogger`（Debug 全量请求/响应） |
