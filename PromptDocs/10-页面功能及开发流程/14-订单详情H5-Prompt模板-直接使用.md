# 14-订单详情 H5 提示词（直接使用）

## 使用场景
用于实现「订单列表 / 其它入口 -> H5 订单详情页 -> 与申请页相同的数据抓取与好评链路 -> 返回并刷新列表」。

## 可直接粘贴给 AI

```
实现 H5「订单详情」页，并与现有 iOS 产品申请容器（Apply）对齐，要求如下：

1) 链接与入口参数
- H5 入口 URL 来自 app/config 字段 `orderDetailsLink`（与 productApplyLink 同解析方式）。
- 打开时 URL 查询参数：
  - 必填：`orderId`
  - 可选：`productId`（仅当页面需要且原生有值时才带；不要传空占位）
  - 可选：`orderType`（待提现等场景按服务端约定传；可与列表项 orderType 一致）
- 页面加载后依赖原生注入的 `mobileUserdata`（含 baseUrl、userId、token、UA、deviceId、clientVersion、appId、salt、countryCode、appName 等；详情页还应包含 orderId，以及原生传入的 productId 等）。

2) JS 通道
- 与申请页相同：window.webkit.messageHandlers.iosHandler.postMessage(...)
- 通道名：iosHandler

3) 与申请页一致的消息
- positionPermission：申请定位；回传规则与申请页**完全一致**（见 `04-产品申请与下单-Prompt模板-直接使用.md` §3 定位 payload 表：首次拒绝 / 强抓失败 / b3 取消或去设置 → `""`；禁止 `{"longitude":"","latitude":""}`）。
- uploadData&&{orderId}：触发设备信息 + 通讯录分片 + ready；成功 uploadDataSucc，失败 uploadDataFail。
- 强抓通讯录二次引导（HQTPermissionSecondaryDialog）：点「去设置」或「关闭」均 uploadDataFail；**不**自动 pop 详情页（与申请页不同，申请页会在 uploadDataFail 后 pop 一层）。
- 协调器：HQTOrderDataCaptureCoordinator，failOnContactsSecondaryInteraction: true。
- successfulGoBack（及项目已约定的成功/反馈类 action）：触发原生好评引导（feedbackGuidance、安装周期一次），流程与申请页一致。
- getUserData / getMobileUserdata / getAppData / mobileUserdata：请求再次注入 mobileUserdata。
- cameraPermission、loginOut、deleteAccount：行为同申请页。

4) 详情页专用返回
- 用户点击详情页「返回」关闭详情时，发送 action：`orderGoBack`
- 原生将 pop 回上一页，并刷新订单列表（重新请求 order/list）。

5) 兼容（可选）
- 若误发 productGoBack，原生在订单详情模式下可按 orderGoBack 处理。

6) 业务自测
- 三种入口：仅 orderId；orderId+productId；待提现 orderId+orderType。
- 抓取与成功回跳、好评、低星感谢与申请页一致。
- orderGoBack 后列表数据已刷新。
```

## 自测清单
- URL 参数缺 `orderId` 时 H5 或原生应有明确提示（按项目约定）。
- 抓取三接口与申请页一致。
- 通讯录二次弹框：去设置/关闭后控制台有 `uploadDataFail`，且仍停留在订单详情 H5（无自动 pop）。
- successfulGoBack 后好评逻辑与 `13-下单成功与好评引导.md` 一致（含 **13.2.1**：当前 H5 上展示好评，结束后再 pop，不先回首页）。
- orderGoBack 后原生列表重新请求当前 Tab。
