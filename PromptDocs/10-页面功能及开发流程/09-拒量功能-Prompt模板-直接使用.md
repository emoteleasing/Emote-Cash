# 拒量功能 Prompt 模板（直接使用）

## 使用说明

与 **Prompts参考** 中各模块的 `Prompt模板-直接使用.md` 用法一致：替换下列占位符后，复制「Prompt 内容」代码块全文发给 AI。

- `{架构模式}` / `{布局方式}` / 各工具类名：来自 `PromptDocs/PromptDocs/项目配置.txt`（与 README 同级）
- `{页面设计图链接或图片路径}`：来自 `页面设计图.txt` 中与本模块对应的 key（拒量 H5 多为配置 URL，可填 **无**）

**需求文档（业务唯一来源）**：与本文件同目录的 `09-拒量功能.md`  
（在 Cursor 中建议用 `@` 引用该文件全文。）

**跨页入口（修改首页/订单列表时必须对照）**：

- `02-首页Loan.md`（`userStatus==51` 提示词、`termV3` `6234303`）
- `06-订单列表.md`（`status==31` 点击）
- `00-全流程字段与判断总表.md` §I

---

## Prompt 内容

```
请为 HQElenFiae iOS 应用实现或调整「拒量（推荐产品 H5）」及相关入口逻辑。

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

- `PromptDocs/PromptDocs/00-基础框架/00-项目基础规范.md`（含 termV3 错误码 6230002/6230003/6234303 不 Toast）
- `PromptDocs/PromptDocs/00-基础框架/05-弹框系统通用.md`（首页处理中双按钮弹框）
- `PromptDocs/PromptDocs/00-基础框架/07-埋点与 bury.md`（拒量外链事件码 502）

跨页面字段与判断：

- `PromptDocs/PromptDocs/10-页面功能及开发流程/00-全流程字段与判断总表.md` §I
- `PromptDocs/PromptDocs/10-页面功能及开发流程/02-首页Loan.md` §2.3.2 / §2.3.3 / §2.5
- `PromptDocs/PromptDocs/10-页面功能及开发流程/06-订单列表.md` §6.6

## 三、本模块需求文档（业务与接口以此为准）

必须严格实现：

`PromptDocs/PromptDocs/10-页面功能及开发流程/09-拒量功能.md`

### 配置门控（实现必查）

- 配置键 **`rejectH5`**：`/app/v3/app/config` 优先，`/app/v3/category/config` 递归兜底；须为合法 http/https URL。
- 统一判断：`HQE_isRejectH5Configured` / `HQE_configuredPageURL`；未配置时各入口行为以需求文档「配置门控」表为准，**禁止**误跳拒量或误展示箭头。

### 三入口（与配置门控联动）

1. **首页提示词**：`userStatus == 51` — 已配置才显示箭头且可点击进拒量 H5；未配置无箭头、点击无反应。
2. **首页产品**：`termV3` 返回 **`6234303`** — 已配置直接 push 拒量 H5（不弹框）；未配置仅弹 `HQE_presentHomeProcessingOrderDialog`（`resultMsg`），Know More/Confirm **均不导航**。
3. **订单列表**：点击 **`status == 31`**（*Reject*）— 已配置进拒量 H5；未配置进订单详情 H5（与其它订单一致）。

`6230002` / `6230003` 不属于拒量分支：仍弹框且 Know More 可进订单详情（见 `02-首页Loan.md`）。

### 拒量 H5 容器（`HQERejectH5ViewController`）

- WKWebView 全屏；导航标题 *Accurate Recommendation*；支持手势返回。
- URL：配置 href + 查询参数 `appId`（`hqelenfiae`）、`mobile`（会话手机号，可空串）。
- `didFinish` 注入：`rejectData('<escaped json>')`，字段含 `appId/salt/mobile/baseUrl/userId/token`；防重复注入；JSON 转义规则见需求文档。
- H5 → 原生：`iosHandler`，消息体字符串 **`thirdUrl=<url>&type=<type>`**（非 JSON 对象）。
- 打开外链前上报埋点 **502**，`remark1` = `type`；`UIApplication openURL`。

## 四、输出要求

- 代码风格、目录分层、类前缀与 `00-项目基础规范.md` 一致。
- 复用已有 `HQEAppConfigHelper`、`HQEUnifiedAlertPresenter`、`HQENetworkClient` 等，禁止平行重复实现。
- 若改动首页或订单列表，列出对应 Presenter / ViewController 文件。
- 自测矩阵：有/无 `rejectH5` × 三入口 + H5 `rejectData` 注入 + `iosHandler` 外链 + 502 埋点。

请根据以上要求生成或修改代码。
```

---
