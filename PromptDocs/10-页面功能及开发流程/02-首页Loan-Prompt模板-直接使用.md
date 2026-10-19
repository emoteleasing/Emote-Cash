# 首页（Loan / SupHome） Prompt 模板（直接使用）

## 使用说明

与 **Prompts参考** 中各模块的 `Prompt模板-直接使用.md` 用法一致：替换下列占位符后，复制「Prompt 内容」代码块全文发给 AI。

- `{架构模式}` / `{布局方式}` / 各工具类名：来自 `PromptDocs/PromptDocs/项目配置.txt`（与 README 同级）
- `{页面设计图链接或图片路径}`：来自 `页面设计图.txt` 中与本模块对应的 key（无界面可填 **无**）

**需求文档（业务唯一来源）**：与本文件同目录的 `02-首页Loan.md`  
（在 Cursor 中建议用 `@` 引用该文件全文。）

---

## Prompt 内容

```
请为 HQEigFina iOS 应用实现或调整「首页（Loan / SupHome）」相关代码，使用 Swift。

## 一、项目配置

**架构模式**: {架构模式}

**字体工具类**: {字体工具类名称}（填「无」则用系统 UIFont）

**布局工具类**: {布局工具类名称}（填「无」则按像素或约束直接写）

**HUD工具类**: {HUD工具类名称}

**网络请求工具类**: {网络请求工具类名称}

**布局方式**: {布局方式}

**页面设计图**: {页面设计图链接或图片路径}

## 二、全局规范（必须先遵守）

阅读并遵守（建议作为附件提供全文）：

- `PromptDocs/PromptDocs/00-基础框架/00-项目基础规范.md`
- 与弹框、网络、埋点相关的 `PromptDocs/PromptDocs/00-基础框架/` 下文档（按本模块实际需要引用）

跨页面字段与判断可对照：

- `PromptDocs/PromptDocs/10-页面功能及开发流程/00-全流程字段与判断总表.md`（§I 拒量门控）
- `PromptDocs/PromptDocs/10-页面功能及开发流程/09-拒量功能.md`（拒量 H5 与三入口全文）
- `PromptDocs/PromptDocs/10-页面功能及开发流程/98-优化功能点清单.md`

## 三、本模块需求文档（业务与接口以此为准）

必须严格实现以下文档中的流程、接口顺序、参数口径、状态机与埋点规则：

`PromptDocs/PromptDocs/10-页面功能及开发流程/02-首页Loan.md`

补充硬性约束（必须落实到代码）：

- **非强制登录 / 访客首页**：
  - 冷启动根页面为首页；**未登录**不跑 §2.2 接口，UI 按 **userStatus=10**（KYC 未认证）展示；默认提示语与 **14pt** 见 `02-首页Loan.md` §2.3.4、§2.3.5。
  - 未登录点击首页任意控件 → Modal 登录；登录成功关闭 Modal 并跑 §2.2；登出/注销/Token 失效 → 访客首页 → 2 秒后自动 Modal 登录。

- **金额千分位（全项目）**：
  - 所有 UI 展示的金额（产品 Quota、复借弹框金额、订单/申请页额度等）必须使用 **`HQTAmountFormatter`** 千分位格式化（`,` 分组 + `₱` 前缀），禁止裸数字上屏。
  - 规范见 `00-基础框架/00-项目基础规范.md` §00.7.1；首页产品列表见 `02-首页Loan.md` §2.3.0。
  - 利率、带 `%` 的费率不做千分位。

- **首页流水线接口（`userStatus`）**：
  - `userStatus == 10`：不请求 `/app/v3/product/list`、不请求 `/app/v3/product/state`。
  - `userStatus != 10`：**始终**请求 `/app/v3/product/list`；**仅 `fjtip=on`** 时再请求 `/app/v3/product/state`（复借候选）。
- **`fjtip`（`dynamicParameter.fjtip`）**：`on` 时拉取 `product/state` 并允许展示复借 **首页弹框**；`off` 时不拉 `product/state`、不弹框。（首页 Tips 列表卡片已移除。）
- **首页数据刷新**：仅在「首次进入 Loan 根页、从 Me 切回 Loan、从子页 pop 回首页根、`HQTHomeShouldRefresh` 通知」时跑整链（或按工程约定从 `suphome` 起重拉），禁止无意义的每次 `viewWillAppear` 自动整链刷新；**不提供下拉刷新**。
- 首页产品列表 / 复借弹框点击申请前必须先请求 `/app/v3/product/termV3`。
- **首页复借弹框**（`enterSource: .reloan`）：`HQTReloanDialog` / `HQTReloanGuideDialog`；Apply 不立即关弹框；`HQTReloanFlowCoordinator` 原生链路（见 `08-复借流程.md` §8.4、§8.12）；定位阶段不 HUD；b3 挂 keyWindow；`userSubmitV3` 前 `dismissActiveReloanGuideDialog()`。
- **首页自动下单 / 精准推荐**（完整规格见 `31-精准推荐与自动下单.md`；入口见 `02` §2.7，必须实现）：
  - 条件：`hasOrder==0` + `userStatus==20` + `firstLoanOptionLine==system`（忽略大小写）+ `product/list` 非空 + 已登录。
  - 触发：① KYC 回首页流水线结束消费标记；② eligible 下点首页 Apply。非 eligible → 手动 `dcRecommend` 匹配。
  - 链路：`dcRecommend`（**10s 超时按 4102007**）→ 全部产品最大额+最高期 → 定位 → `userSubmitDcUpgrade`（不传 `orderType`）→ 抓取 → 精准推荐成功页；禁止旧 `termV3`+`userSubmitV3` 自动下单路径。
  - 启动时跳过本轮弹框链；协调器防重入。
- **复借抓取**：`HQTOrderDataCaptureCoordinator`（默认无 `uploadDataFail`）；通讯录 iOS 18+ Limited 按未授权（`05` §5.3、`08` §8.11）。
- 当 `termV3` 返回 `resultCode = 6230002` 或 `6230003`：
  - 弹项目统一弹框，文案用接口返回 `resultMsg`
  - 弹框按钮：`Confirm` / `Know More`；`Know More` 跳订单详情（§2.5）
- 当 `termV3` 返回 `resultCode = 6234303`（拒量，见 `09-拒量功能.md`）：
  - **`rejectH5` 已配置**：直接进入拒量 H5，**不弹框**
  - **未配置**：弹框展示 `resultMsg`，**不跳转**
- 首页 `userStatus == 51`（拒量态）：仅 `rejectH5` 已配置时提示词显示箭头且可进拒量 H5；未配置无箭头、点击无反应（详见 `09-拒量功能.md`）
- 除上述错误码外，其它失败按通用错误提示处理。
- 拒量 H5 页、桥接 `iosHandler`、`rejectData` 注入、埋点 502：以 `09-拒量功能.md` 为准，勿在首页重复实现一套。
- `userStatus = 10` 时首页不在初次加载阶段主动请求 `/app/v3/kyc/four/status`。
- 仅在用户点击首页提示语或 `Apply now` 时请求 `/app/v3/kyc/four/status`，并按返回 `willExecuteStepNumber` 路由 KYC 页面：
  - `1` -> Personal
  - `2` -> Work
  - `3` -> Emergency
  - `4` -> Liveness
  - 缺失/异常 -> 默认 Personal

## 四、输出要求

- 代码风格、目录分层、类前缀与 `00-项目基础规范.md` 一致。
- 复用工程已有网络层、弹框、HUD、防连点等能力，禁止平行重复实现。
- 说明主要改动文件与自测要点。

请根据以上要求生成或修改代码。
```

---
