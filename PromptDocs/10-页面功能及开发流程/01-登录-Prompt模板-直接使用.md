# 登录（OTP） Prompt 模板（直接使用）

## 使用说明

与 **Prompts参考** 中各模块的 `Prompt模板-直接使用.md` 用法一致：替换下列占位符后，复制「Prompt 内容」代码块全文发给 AI。

- `{架构模式}` / `{布局方式}` / 各工具类名：来自 `PromptDocs/PromptDocs/项目配置.txt`（与 README 同级）
- `{页面设计图链接或图片路径}`：来自 `页面设计图.txt` 中与本模块对应的 key（无界面可填 **无**）

**需求文档（业务唯一来源）**：与本文件同目录的 `01-登录.md`  
（在 Cursor 中建议用 `@` 引用该文件全文。）

---

## Prompt 内容

```
请为 HQEigFina iOS 应用实现或调整「登录（OTP）」相关代码，使用 Swift。

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

`PromptDocs/PromptDocs/10-页面功能及开发流程/01-登录.md`

## 四、登录校验与提示语（补充，必须实现）

- **输入长度限制（须在 `UITextFieldDelegate` 或等价层实现，与 `01-登录.md` §1.3、`25-印度手机号规则.md` 一致）**：
  - 手机号：**仅数字**；首位 `6`–`9`（非 `0` 前缀）最多 **10** 位；首位 `0`（含 `06`–`09`）最多 **11** 位；无数字时按 11 位上限。粘贴只保留数字。
  - OTP：**仅数字**，**最多 6 位**；非数字字符一律拒绝。
- `Get OTP` 点击前：
  - 若手机号为空：提示 `Please enter mobile number`
  - 若手机号不符合印度规则：提示 `Please enter correct phone number`
- `Get OTP` 接口成功（`resultCode=200`）后：**不得改动**既有倒计时与按钮文案逻辑；先执行原倒计时流程，再**单独** Toast **`OTP has been sent`**。
- `Sign in` 点击前：
  - 若手机号为空：提示 `Please enter mobile number`
  - 若手机号不符合印度规则：提示 `Please enter correct phone number`
  - 若 OTP 长度小于 6：提示 `Please enter correct OTP`
  - 若 OTP 不是 6 位纯数字：提示 `Please enter correct OTP`
  - 若未勾选协议：提示 `Please read and accept`
- 重复点击防抖提示：
  - 重复点 `Get OTP`：`Sending OTP... Please wait`
  - 重复点 `Sign in`：`Signing in... Please wait`
- 请求失败兜底提示：
  - 发验证码失败：`Failed to send OTP, please try again`
  - 登录失败：`Login failed, please try again`
- 发验证码成功交互：倒计时与按钮文案与改前一致；成功后在上述流程**之外**追加非阻断 Toast **`OTP has been sent`**。
- 错误呈现方式：仅使用 Toast，不展示字段下方红字错误文案。

> 手机号规则（严格，印度）：仅保留数字；**10 位且首位 6–9**，或 **11 位且前两位 06–09**；规范化为 10 位后提交；`09876543210` 与 `9876543210` 等价。详见 `25-印度手机号规则.md`。

## 五、输出要求

- 代码风格、目录分层、类前缀与 `00-项目基础规范.md` 一致。
- 复用工程已有网络层、弹框、HUD、防连点等能力，禁止平行重复实现。
- 说明主要改动文件与自测要点。

请根据以上要求生成或修改代码。
```

---
