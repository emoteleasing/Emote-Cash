# installApp 已安装应用上报 Prompt 模板（直接使用）

## 使用说明

与 **Prompts参考** 中各模块的 `Prompt模板-直接使用.md` 用法一致：替换下列占位符后，复制「Prompt 内容」代码块全文发给 AI。

- `{架构模式}` / `{布局方式}` / 各工具类名：来自 `PromptDocs/PromptDocs/项目配置.txt`（与 README 同级）
- `{页面设计图链接或图片路径}`：本模块无独立 UI，填 **无**

**需求文档（业务唯一来源）**：与本文件同目录的 `30-installApp已安装应用上报.md`  
（在 Cursor 中建议用 `@` 引用该文件全文。）

抓取主流程仍以 `05-数据抓取与通讯录分片.md` 为准；本模块是 ready 前的子步骤。

---

## Prompt 内容

```
请为 HQEigFina iOS 应用实现「已安装应用上报」能力，接入数据抓取流水线。语言与工程一致（Swift / Objective-C 均可，以仓库现有协调器为准）。

## 一、项目配置

**架构模式**: {架构模式}

**字体工具类**: {字体工具类名称}（填「无」则用系统 UIFont）

**布局工具类**: {布局工具类名称}（填「无」则按像素或约束直接写）

**HUD工具类**: {HUD工具类名称}

**网络请求工具类**: {网络请求工具类名称}

**布局方式**: {布局方式}

**页面设计图**: 无

## 二、全局规范（必须先遵守）

阅读并遵守（建议作为附件提供全文）：

- `PromptDocs/PromptDocs/00-基础框架/00-项目基础规范.md`
- `PromptDocs/PromptDocs/00-基础框架/02-基础网络请求规范.md`
- `PromptDocs/PromptDocs/10-页面功能及开发流程/05-数据抓取与通讯录分片.md`

## 三、本模块需求文档（业务与接口以此为准）

必须严格实现：

`PromptDocs/PromptDocs/10-页面功能及开发流程/30-installApp已安装应用上报.md`

### 3.1 流水线位置（硬性）

在数据抓取协调器中，调用 `/app/v3/order/ready` **之前**先走本步骤：

```
device →（可选 contact）→ installApp（有 list 才请求）→ ready
```

- 与强抓 / 非强抓无关：只要会走到 ready，就要走此步骤。
- **`list` 为空：不请求 `installApp`，直接 `ready`。**
- 不要单独弹 Loading / Toast；沿用抓取进度弹框即可。
- **失败不阻断 ready**（success / failure 均继续调用 ready）。

### 3.2 接口入参（硬性）

`POST /app/v3/mobile/installApp`

| 逻辑字段 | signed/unsigned | Wire（本包若直传混淆名） | 说明 |
|----------|-----------------|--------------------------|------|
| `orderId` | signed | `objection` | 下单成功订单号 |
| `list` | unsigned | `exact` | 已安装 App 数组；**无命中（空）则不请求接口**，直接 ready |
| `remarks` | — | — | **禁止传** |

`list` 单条结构：

```json
{ "appName": "<scheme>" }
```

- `appName` = URL Scheme 字符串本身（与 `Info.plist` → `LSApplicationQueriesSchemes` 完全一致）
- **不要**传显示名、Bundle ID；**不要**给列表项额外加 `crazy` / `remarks` 等字段
- unsigned 只传 `exact`（或逻辑名 `list`，由网络层统一混淆），**禁止** `exact` 与 `list` 双写

### 3.3 获取数组方法（硬性，必须按此实现）

```
lsApplicationQueriesSchemes:
  读 Bundle Main Info.plist 的 LSApplicationQueriesSchemes；非 Array 则返回 []

getAppsIsExitResult:
  for scheme in declared:
    跳过非 String / 空串
    url = "\(scheme)://"
    if canOpenURL(url) == true:
      append { "appName": scheme }
  return result
```

调用：

```
callReady(allowContact):
  uploadInstallAppsThen:
    requestReady(allowContact)
```

### 3.4 Info.plist

- 必须在 `LSApplicationQueriesSchemes` 预先声明待探测 scheme（不含 `://`）
- 未声明的 scheme 在 iOS 9+ `canOpenURL` 恒为 false
- 注意系统数量上限（约 50 条）

## 四、输出要求

- 优先改数据抓取协调器（如 `HQITOrderDataCaptureCoordinator` / 工程等价类），不要平行再写一套抓取流程。
- 复用已有网络层 `requestWithEndpoint:signedData:unsignedData:`。
- 说明改动文件与自测要点（空 list 跳过接口、命中若干 scheme、接口失败仍能 ready）。

请根据以上要求生成或修改代码。
```

---
