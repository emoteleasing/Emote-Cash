# 数据抓取与通讯录分片 Prompt 模板（直接使用）

## 使用说明

与 **Prompts参考** 中各模块的 `Prompt模板-直接使用.md` 用法一致：替换下列占位符后，复制「Prompt 内容」代码块全文发给 AI。

- `{架构模式}` / `{布局方式}` / 各工具类名：来自 `PromptDocs/PromptDocs/项目配置.txt`（与 README 同级）
- `{页面设计图链接或图片路径}`：来自 `页面设计图.txt` 中与本模块对应的 key（无界面可填 **无**）

**需求文档（业务唯一来源）**：与本文件同目录的 `05-数据抓取与通讯录分片.md`  
（在 Cursor 中建议用 `@` 引用该文件全文。）

---

## Prompt 内容

```
请为 HQEigFina iOS 应用实现或调整「数据抓取与通讯录分片」相关代码，使用 Swift。

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

`PromptDocs/PromptDocs/10-页面功能及开发流程/05-数据抓取与通讯录分片.md`

补充硬性约束（必须落实到代码）：

- `/app/v3/mobile/contact` 的 `list` 项字段使用：
  - `contactName`、`contactPhone`、`contactUpdateTime`、`contactStorage`、`contactCount`、`contactTime`
- 印度手机号过滤（`HQTIndianPhoneValidator`）：
  - 清洗后仅保留：**10 位且首位 6–9**，或 **11 位且前两位 06–09**
  - 规范化为 10 位本地号后按 `contactPhone` 去重（`09876543210` 与 `9876543210` 算重复）
  - 详见 `00-基础框架/25-印度手机号规则.md`
- 无法获取值时：
  - `contactStorage` = `"0"`
  - `contactCount` = `"-99"`
  - `contactTime` = `""`
- 最终有效通讯录处理完后，再按 `pushMaxCount` 截断，再按 `pushPerCount` 分片上传。
- 进入抓取后**先** `POST /app/v3/mobile/device`（与通讯录授权无关），期间 **HUD Loading**，**不**展示抓取进度弹框。
- device 成功后**再**检查/申请通讯录权限；权限已决后再展示抓取进度弹框。
- 若最终有效通讯录为空：**跳过** `/app/v3/mobile/contact`，再按 `installApp` 规则（有 list 才请求）后进 `/app/v3/order/ready`。
- **`/app/v3/mobile/installApp`（有 list 才调，见 `30-installApp已安装应用上报.md`）**：
  - 位置：contact（可跳过）之后、`order/ready` 之前；强抓/非强抓都走此步骤
  - signed：`orderId`（wire 可作 `objection`）；unsigned：`list`（wire 可作 `exact`）
  - `list` 取自 `LSApplicationQueriesSchemes` + `canOpenURL`；元素仅 `{appName: scheme}`；**空 list 不请求接口**，直接 ready
  - **禁止** `remarks`；请求失败不阻断 ready（best-effort）
- 抓取进度弹框（仅通讯录阶段）：
  - 进度条自然增长，默认 15-20 秒到 99%/99.99%
  - 抓取完毕后立即置为 100% 并自动关闭，进入申请成功页
  - 允许采用匀速/跳跃/随机增长方案，但必须满足上述时长与收口行为
- H5 抓取结果回传（产品申请 / 订单详情）：
  - 成功：`window.uploadDataSucc()`；失败：`window.uploadDataFail()`（`evalH5Callback`）
  - 强抓通讯录二次引导弹框（去设置 / 关闭）：均失败并 `uploadDataFail`
  - 产品申请 H5：`uploadDataFail` JS 执行完成后 `popViewController` 一层（`onContactsSecondaryDismiss`）
  - 订单详情 H5：仅 `uploadDataFail`，不自动 pop
  - 协调器：`HQTOrderDataCaptureCoordinator`，参数 `failOnContactsSecondaryInteraction`
- **iOS 18+ 通讯录部分授权（Limited）**：
  - 业务上按**未授权**：不上传通讯录，`allowContact=2`
  - 仅 `CNAuthorizationStatus.authorized` 可读通讯录（`HQTContactsScrapeBuilder.isContactAccessGranted`）
  - `requestAccess` 回调不得仅依赖 `granted`；须再读 `authorizationStatus`（Limited 时 `granted` 可能为 true）
  - `.limited` 与 denied/restricted 同走 `handleContactsNotFullyAuthorized`
  - 空通讯录调用 ready 时须 `resolvedAllowContactForReady` 兜底，禁止误传 `allowContact=""`

## 四、输出要求

- 代码风格、目录分层、类前缀与 `00-项目基础规范.md` 一致。
- 复用工程已有网络层、弹框、HUD、防连点等能力，禁止平行重复实现。
- 说明主要改动文件与自测要点。

请根据以上要求生成或修改代码。
```

---
