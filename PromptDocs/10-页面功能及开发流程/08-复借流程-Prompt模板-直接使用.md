# 复借流程 Prompt 模板（直接使用）

## 使用说明

与 **Prompts参考** 中各模块的 `Prompt模板-直接使用.md` 用法一致：替换下列占位符后，复制「Prompt 内容」代码块全文发给 AI。

- `{架构模式}` / `{布局方式}` / 各工具类名：来自 `PromptDocs/PromptDocs/项目配置.txt`（与 README 同级）
- `{页面设计图链接或图片路径}`：来自 `页面设计图.txt` 中与本模块对应的 key（无界面可填 **无**）

**需求文档（业务唯一来源）**：与本文件同目录的 `08-复借流程.md`  
（在 Cursor 中建议用 `@` 引用该文件全文。）

---

## Prompt 内容

```
请为 HQEigFina iOS 应用实现或调整「复借流程」相关代码，使用 Swift。

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

- `PromptDocs/PromptDocs/10-页面功能及开发流程/00-全流程字段与判断总表.md`
- `PromptDocs/PromptDocs/10-页面功能及开发流程/98-优化功能点清单.md`

## 三、本模块需求文档（业务与接口以此为准）

必须严格实现以下文档中的流程、接口顺序、参数口径、状态机与埋点规则：

`PromptDocs/PromptDocs/10-页面功能及开发流程/08-复借流程.md`

## 四、首页复借硬性约束（PHI352-DC，必须落实到代码）

- **弹框**：`HQTReloanGuideDialog`；Apply **不立即 dismiss**；`HQTHomeSessionState.activeReloanGuideDialog` 持有至 `userSubmitV3` 前 `dismissActiveReloanGuideDialog()`。
- **termV3**：`HQTProductApplyHandler.fetchTermV3(enterSource: .reloan)`；失败须 `resetActiveReloanApplyInteraction()`。
- **主链路**：`HQTReloanFlowCoordinator`：`pickAmountAndTerm` 兼容 `amountDetailList`/`lamp`、`loanAmount`/`review`/`certain`/`furnish`、`termDetailList`/`mission`、`showTerm`/`brick`/`examination`。
- **定位**：`HQTProductApplyLocationBridge.resolveForNativeOrderSubmit`；定位阶段 **不** `showLoading`（避免挡住 keyWindow 上 b3）；`locationSecondaryUsesKeyWindow = true`；强抓失败保持复借弹框。
- **下单**：`orderType = "1"`；`orderId` 用 `HQTAPIFieldMapper.orderIdString(from:)`。
- **抓取**：`HQTOrderDataCaptureCoordinator`（`failOnContactsSecondaryInteraction` 默认 false）；device HUD → 通讯录 → 进度条 → contact? → ready。
- **iOS 18+ Limited**：按未授权（见 `05-数据抓取与通讯录分片.md` §5.3、`08-复借流程.md` §8.11）；不以 `requestAccess` 的 `granted` 单独判断。
- **成功**：`HQTProductApplyFeedbackGuide`（可选）→ Success 弹框 → 刷新首页 pipeline。

## 五、输出要求

- 代码风格、目录分层、类前缀与 `00-项目基础规范.md` 一致。
- 复用工程已有网络层、弹框、HUD、防连点等能力，禁止平行重复实现。
- 说明主要改动文件与自测要点。

请根据以上要求生成或修改代码。
```

---
