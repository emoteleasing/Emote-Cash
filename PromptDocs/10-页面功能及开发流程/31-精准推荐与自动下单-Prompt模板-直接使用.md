# 精准推荐与首页自动下单 Prompt 模板（直接使用）

## 使用说明

与同目录其它 `*-Prompt模板-直接使用.md` 用法一致：替换下列占位符后，复制「Prompt 内容」代码块全文发给 AI。

- `{架构模式}` / `{布局方式}` / 各工具类名：来自项目配置占位文件  
- `{页面设计图链接或图片路径}`：匹配中弹框、列表页、无产品/View Now、成功页等设计；无则填 **无**

**需求文档（业务唯一来源）**：与本文件同目录的 `31-精准推荐与自动下单.md`  
（在 Cursor 中建议用 `@` 引用该文件全文，并按需附上交叉文档。）

---

## Prompt 内容

```
请为实现「精准推荐 + 首页自动下单」完整链路，严格按需求文档实现全部功能。不要输出大段示例代码；说明流程、接口字段、页面态与自测即可落到实现中。

## 一、项目配置

**架构模式**: {架构模式}

**字体工具类**: {字体工具类名称}（填「无」则用系统字体）

**布局工具类**: {布局工具类名称}（填「无」则直接约束）

**HUD工具类**: {HUD工具类名称}

**网络请求工具类**: {网络请求工具类名称}

**布局方式**: {布局方式}

**页面设计图**: {页面设计图链接或图片路径}

## 二、全局规范（必须先遵守）

- `00-基础框架/00-项目基础规范.md`（含金额 ₹）
- `00-基础框架/02-基础网络请求规范.md`（签名、公共参数、deviceId）
- `00-基础框架/05-弹框系统通用.md`

交叉必读（抓取/定位/好评勿另起炉灶）：

- `05-数据抓取与通讯录分片.md`
- `30-installApp已安装应用上报.md`
- `12-定位权限处理规范.md`（二次引导挂 keyWindow）
- `13-下单成功与好评引导.md`
- `02-首页Loan.md`（userStatus 分流、弹框链；自动下单细节以 31 为准）

## 三、本模块需求文档（业务与接口以此为准）

必须严格实现：

`10-页面功能及开发流程/31-精准推荐与自动下单.md`

重点不得遗漏：

1. 自动下单资格：`hasOrder==0` + `userStatus==20` + `firstLoanOptionLine==system`（忽略大小写）+ 已登录 + `product/list` 非空；KYC 回首页消费标记启动并跳过弹框链；防重入。
2. 匹配中弹框 + `POST /app/v3/product/dcRecommend`；**10 秒无响应取消请求**，按 **4102007** 进无产品页。
3. 错误分流：4102007/空产品/超时 → notuijie；其它错误 → View Now（首页 promptCopy + 按 userStatus/4102006 跳订单筛选项）。
4. 解析 `productInfoList` / `amountDetailList` / `termDetailList`（含扁平聚合）；默认最大额+最高期；提交 `loanTerms` 用 `loanTerm`。
5. 列表交互：勾选、改档重置最高期、协议 `conditionsHref`、汇总、Apply 校验。
6. 定位强抓/非强抓、埋点 15/16、坐标六位小数或 `-360.000000`。
7. `POST /app/v3/order/userSubmitDcUpgrade`：signed `productIds,loanAmounts,loanTerms,longitude,latitude,imei="null",serialNo(=deviceId)`；unsigned 可选 `bankCardBindId`；禁止 `orderType`。
8. 自动下单：dcRecommend 成功后全选最大额+最高期，不进列表，直接定位→提交→抓取→成功页；失败页与手动一致。
9. 抓取用首个 orderId；成功页串行 `detailV2`（signed `objection`，unsigned `appType=DC`）展示全部订单；Confirm→好评→pop 根；过程不发 HomeShouldRefresh。

## 四、输出要求

- 复用已有网络层、弹框、抓取协调器、定位二次引导、金额格式化、好评；禁止平行实现。
- 不要粘贴大段示例代码；按 §31.14 自测清单自检。
- 若工程仍残留旧自动下单（termV3 + userSubmitV3 + 最低期），改为本文口径并删除冲突路径。

请根据以上要求生成或修改实现。
```

---
