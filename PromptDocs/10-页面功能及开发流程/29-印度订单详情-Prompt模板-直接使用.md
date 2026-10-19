# 29. 印度订单详情 — Prompt 模板（直接使用）

按 `29-印度订单详情.md` 实现 / 校验 `HQITOrderDetailViewController`。

## 必须

1. 入参 `orderId` + `productId`；请求 `/app/v3/order/detailV2`（signed `orderId`，unsigned `appType=DC` + 可选 `productId`）。
2. UI：导航同 Feedback；产品卡 / 银行卡白卡 / 明细白卡 / `with_icon` 提示；底部按钮贴页面底 -32，无额外底栏。
3. 字段白名单与显隐、EMI、文案 tipId、按钮矩阵严格按 **29.4～29.8**。
4. 不展示 `repayExtensionFeeAmount`。
5. Repay → `repay/connect`；Defer → `repay/extension`；`periodNoList=["1"]`；`data.connect` 打开 `HQITPaymentWebViewController`。
6. 订单列表 / 首页 Know More / withdrawal_detail 均 push 本页。

## 验收

- [ ] 60 + ifExtension=1 显示 Defer|Repay；61 仅 Repay
- [ ] 60/61 有 UPI 第二段文案
- [ ] 无银行卡账号时隐藏银行卡模块
- [ ] Amount due 在 deduction 与 repaid 都为空时不展示
- [ ] 禁左滑返回
