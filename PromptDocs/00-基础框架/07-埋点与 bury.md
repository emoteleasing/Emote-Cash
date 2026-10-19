# 07. 埋点与 bury/record

按提示词 **生成或对齐 Native 埋点实现** 时，以 **§7.11** 为准；事件码与触发时机以 **§7.4–§7.8** 为准。

## 7.1 接口
- `/app/v3/bury/record`

## 7.2 上报字段（请求体 `data` 内最终形态）
- `eventCode`：事件码（**NSNumber**，必填，且参与签名）
- `eventContent`：**字符串**。业务无内容时固定为 **`"NULL"`**（四个大写字母，不是 JSON `null`，不是 `"<null>"`，不是 `"-"`）。
- `remark1` / `remark2` / `remark3`：**字符串**；无内容时同样为 **`"NULL"`**；有语义时传真实值（如 `productId`、URL、星级数字串等）。
- **调用约定**：各 VC 里对 `HQEBuryRecorder` **统一传 `nil` 或空串** 表示「无 eventContent / 无该 remark」；**禁止**在业务层自行拼 `@"NULL"` 或 `[NSNull null]` 传入（由 `HQEBuryRecorder` 集中替换）。

## 7.3 规则
- 五个字段必须按项目约定构造；**最终 POST 的 `data` 里上述四个字符串键均为非空字符串**，空语义一律为 **`"NULL"`**。
- **`eventContent` 默认不传业务文案**：除后端明确要求外，调用方 `eventContent` 传 **`nil`**（见 **§7.5–7.7** 表内「`nil`」列）。
- 埋点失败不影响主流程，只需要打印日志用于排查。
- 埋点与页面行为的绑定：
  - 按钮点击、弹框展示/关闭
  - 权限请求成功/失败
  - 复借展示与 Apply 点击
  - 好评流程展示/提交

## 7.4 登录（Native，`HQNLoginViewController`）
表内 **`eventContent` 列 = 调用 `recordEventCode` 时传入的 ObjC 参数**（`nil` 表示无文案，落盘为 **`"NULL"`**）。`remark*` 未列则调用时传 `nil`。

| eventCode | 说明 | eventContent（调用传参） | 触发时机 |
|-----------|------|----------------|----------|
| **2** | 协议：Privacy Policy 点击 | `nil` | 富文本协议链点击打开隐私页前 |
| **3** | 协议：Service Agreement 点击 | `nil` | 同上，服务协议 |
| **4** | Get OTP 点击 | `nil` | 用户点击获取验证码 |
| **5** | Sign in 点击 | `nil` | 用户点击登录 |

## 7.5 首页（Native，`HQNHomeViewController`）
下表 **「全无」** 表示 `remark1`–`remark3` 调用均传 **`nil`**（请求里对应 **`"NULL"`**）。**25** 无 orderId 时 remark1 传 `nil`。

| eventCode | 说明 | eventContent（调用） | remark1 / remark2 / remark3（调用） |
|-----------|------|----------------|-------------|
| **20** | Apply 入口（KYC 条 / 空列表条） | `nil` | remark1=`@"kyc"` / `@"empty"` |
| **21** | 产品列表点击申请 | `nil` | remark1=`productId` 字符串 |
| **22** | 复借 | `nil` | 仅展示：remark1=`@"reloan_show"`；申请：remark1=`productId` |
| **23** | 待提现引导弹层展示 | `nil` | 全无 |
| **24** | 待提现引导关闭 | `nil` | 全无 |
| **25** | 待提现引导点 Withdraw | `nil` | remark1=orderId 或 `nil` |
| **26** | 复借底部弹层关闭 | `nil` | 全无 |
| **30** | 版本更新弹框展示 | `nil` | remark1=latestVersion 或 `nil` |
| **31** | 版本更新点 Update/Upgrade | `nil` | remark1=URL 或 `nil` |
| **32** | 版本更新点 Cancel/Later | `nil` | 全无 |
| **40** | 好评引导弹层展示 | `nil` | 全无 |
| **41** | 好评引导取消 | `nil` | 全无 |
| **42** | 好评引导提交 | `nil` | remark1=星级 `@"1"`…`@"5"` |

## 7.6 权限检查（Native）

| eventCode | 说明 | eventContent（调用） | remark*（调用） | 触发时机 |
|-----------|------|----------------|----------------|----------|
| **11** / **12** | 相机权限成功 / 失败 | `nil` | 全无 | 每次校验相机权限 |
| **15** / **16** | 定位权限成功 / 失败 | `nil` | 全无 | 每次检查定位权限 |
| **17** / **18** | IDFA/ATT 成功 / 失败 | `nil` | 全无 | ATT 流程 |
| **19** | 通讯录完全授权 | `nil` | 全无 | `CNAuthorizationStatusAuthorized` |
| **20** | 通讯录拒绝 / 受限 | `nil` | 全无 | denied / restricted |
| **198** | 通讯录选择部分联系人 | `nil` | 全无 | iOS 18+ `Limited`（业务仍按未授权） |

## 7.6A KYC 证件页（Native，`HQITKYCDocumentViewController`）

| eventCode | 说明 | 触发时机 |
|-----------|------|----------|
| **50** | 身份证：点击选择照片-正面 | 点正面槽出选择 sheet |
| **53** | 身份证：打开相机页面-正面 | 进入自定义相机页 |
| **57** | 身份证：相册选择照片-正面 | sheet 点「Album」（非选完） |
| **66** | 身份证：点击提交 | 点 Continue |
| **40** | 税卡：点击提交 | 点 Continue |
| **41** | 税卡：点击选择照片 | 点正面槽出选择 sheet |
| **43** | 税卡：打开自定义相机页 | 进入自定义相机页 |
| **48** | 税卡：打开相册 | sheet 点「Album」 |

## 7.7 推送与通知权限（Native）
| eventCode | 说明 | eventContent（调用） | remark*（调用） | 触发时机 |
|-----------|------|----------------|----------------|----------|
| **600** | 通知权限成功 | `nil` | 全无 | 首页链 `requestAuthorization` 且 `granted==YES` |
| **601** | 通知权限拒绝 | `nil` | 全无 | 同上 `granted==NO` |
| **602** | 点击推送进 App | `nil` | 全无 | `UNNotificationDefaultActionIdentifier`；用 `recordPushNotificationOpen602Debounced` 约 **0.75s** 去重 |

说明：H5 内若存在同类行为，本表不要求 H5 侧实现，仅约束当前 Native 工程。

## 7.8 拒量 H5（`HQERejectH5ViewController`）

| eventCode | 说明 | eventContent（调用） | remark*（调用） | 触发时机 |
|-----------|------|----------------|----------------|----------|
| **502** | 拒量 H5 跳转外部浏览器 | `nil` | remark1=H5 消息中的 `type`（无则 `nil`） | `iosHandler` 解析 `thirdUrl=…&type=…` 后、`openURL` 之前 |

业务与桥接格式：`10-页面功能及开发流程/09-拒量功能.md`。

## 7.10 与业务子文档的对应关系
- H5 容器页 userdata / URL 工具类生成说明：`09-H5容器公共能力与工具类生成提示词.md`。
- 登录协议与按钮：`01-登录.md` §1.5 与本节 **7.4** 一致。
- 首页复借 / Apply / 弹框优先级：`02-首页Loan.md`、`08-复借流程.md` 与本节 **7.5** 一致。
- 拒量外链：**502** ↔ `09-拒量功能.md` 与本节 **7.8** 一致。
- 下单页通讯录与定位抓取：`05-数据抓取与通讯录分片.md` 与本节 **7.6** 一致。
- 好评展示策略：`13-下单成功与好评引导.md` 与本节 **7.5** 中 **40–42** 一致。

## 7.11 Native 实现约定（按本文生成 / 对齐代码）

以下与仓库 **`HQEBuryRecorder`**、`HQENetworkClient` 行为一致，生成新埋点或重写时请遵守。

### 7.11.1 类与接口

- **文件**：`Shared/Utils/HQEBuryRecorder.h`、`.m`
- **方法**：
```objc
+ (void)recordEventCode:(NSInteger)eventCode
           eventContent:(nullable NSString *)eventContent
                remark1:(nullable NSString *)remark1
                remark2:(nullable NSString *)remark2
                remark3:(nullable NSString *)remark3;
+ (void)recordPushNotificationOpen602Debounced;
```

### 7.11.2 组装 `signedData`（写入 `POST body` 的 `data`）

在 **`HQEBuryRecorder` 内部**（业务方不要重复实现）：

- 占位常量：字符串 **`@"NULL"`**（全大写）。
- 规则：
  - `eventContent.length > 0` → 用传入值；否则 → **`@"NULL"`**。
  - `remark1` / `remark2` / `remark3` 同理（**不再使用** `@"-"`、`[NSNull null]`、JSON `null` 表示空）。
- `eventCode`：`@(eventCode)` 放入字典。
- 请求：`[[HQENetworkClient shared] requestDataWithEndpoint:@"/app/v3/bury/record" signedData:... unsignedData:nil ...]`。

### 7.11.3 网络层与签名

- **`HQTNetworkClient.buildPOSTRequestBody`**：埋点 `data` 中空 remark/eventContent 等写入字面量 **`"NULL"`** 再序列化（与请求体一致）。
- **`HQTSigningHelper.signValueString`**（方式四）：`nil` / `NSNull` → 空字符串 `""`；埋点 `data` 内显式 **`"NULL"`** 字符串按字面量 **`NULL`** 参与 `*` 拼接与 `MD5` 签名（见 `02-基础网络请求规范.md` §2.4.1 方式四步骤 5）。

### 7.11.4 生成检查清单（给 AI）

1. 新业务埋点：只改各 VC 中的 **`recordEventCode:...`** 调用，**不要**在业务里写死 `@"NULL"`。
2. 表 **§7.4–7.7** 中「`nil`」仅指 **ObjC 传参**；文档 **§7.2** 描述的是 **HTTP `data` 最终字符串**。
3. 推送 **602** 必须走 **`recordPushNotificationOpen602Debounced`**，不要直接 `recordEventCode:602` 两处裸调导致双报。
4. 需要 remark 时只填 **remark1–3**，**eventContent 默认 `nil`**，除非产品明确要求 eventContent 承载文案。

