# 银行卡模块 Prompt 模板（直接使用 · 印度）

## 使用说明

替换下列占位符后，复制「Prompt 内容」代码块全文发给 AI。

- `{架构模式}` / `{布局方式}` / 各工具类名：来自 `PromptDocs/项目配置.txt`
- `{页面设计图链接或图片路径}`：来自 `页面设计图.txt` 中「银行卡」key（无界面可填 **无**）

**需求文档（业务唯一来源）**：与本文件同目录的 `09-银行卡模块.md`

---

## Prompt 内容

```
请为 HQITwoFncesd iOS 应用实现或调整「银行卡模块」（印度），使用 Objective-C。

## 一、项目配置

**架构模式**: {架构模式}

**字体工具类**: {字体工具类名称}

**布局工具类**: {布局工具类名称}

**HUD工具类**: {HUD工具类名称}

**网络请求工具类**: {网络请求工具类名称}

**布局方式**: {布局方式}

**页面设计图**: {页面设计图链接或图片路径}

**类前缀**: HQIT

## 二、全局规范

遵守：

- `PromptDocs/00-基础框架/00-项目基础规范.md`
- 弹框、网络相关 `PromptDocs/00-基础框架/` 文档（按需）

## 三、本模块需求（必须严格实现）

`PromptDocs/10-页面功能及开发流程/09-银行卡模块.md`

### 展示页要点

1. 并行请求 `/app/v3/bankcard/list` 与 `/app/v3/user/info`。
2. 列表有值取**第一个**：左上 **Bank Account**（图标+文案写死）、中部 **accountNo**（标题 Bank Account Number）、底部 **accountName**；右上修改按钮；下方提示语写死（见需求文档）。**卡片不展示 IFSC**（`bankCode` 仅修改页使用）。
3. 无卡：空态，不展示修改入口。
4. `payAccountModifySwitch == on`（兼容 1/true）且有卡：显示修改按钮；**点击整张卡**进修改页；否则隐藏且不可进。

### 修改页要点

1. UI 同 KYC 支付账号；进入调 `/app/v3/kyc/init`，`kycId=pay_account`；按返回布局并回填绑卡信息。
2. 提交 `/app/v3/bankcard/modify`：
   - signed：`accountType="unknown"`、`bankCode`、`accountNo`
   - unsigned：`accountNoVerify`、`creditCard`（空则 `""`），可选 `accountName`
3. 返回直接 pop；成功后列表页刷新。

### 工程落点

- `HQITwoFncesd/Bank/HQITBankAccountViewController` + `ViewModel`
- `HQITwoFncesd/Bank/HQITBankAccountEditViewController` + `ViewModel`
- 复用 `HQITKYCIFSCViewController`

## 四、输出要求

- 代码风格、目录、类前缀与项目规范一致。
- 复用已有网络层、HUD、防连点；禁止平行重复实现。
- 说明主要改动文件与自测要点。
```
