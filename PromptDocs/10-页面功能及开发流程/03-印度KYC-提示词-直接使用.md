# 03. 印度 KYC 提示词 — 直接使用

> **用途**：按本文档即可完整实现**印度市场原生 KYC 多步认证**。仅描述功能、流程、校验与接口口径，**不含具体代码**；文档自洽，无需查阅其他 KYC 说明。

---

## 一、实现目标

实现一套**服务端驱动顺序**的 KYC 原生流程：

1. 进入时拉取 `/app/v3/kyc/status`，得到有序步骤列表 `kycList`。
2. 定位第一个未完成步骤（`kycStatus != 1`），按 `kycId` 打开对应原生页。
3. 每步完成后再次拉 status，**替换当前页** push 下一步；全部完成后回首页并刷新。
4. 支持动态表单（字段配置来自 `/app/v3/kyc/init`）、印度手机号校验、紧急联系人通讯录、Aadhaar/PAN 证件上传、静默活体、收款账户与 IFSC 四级联动。

---

## 二、入口与导航

### 2.1 业务入口

| 场景 | 条件 | 行为 |
|------|------|------|
| 首页 | `userStatus == 10`，用户点击顶部提示语或 Apply Now | 调用 KYC 导航 `start` |
| EMI 结果页 | Apply Now 且 `userStatus == 10` | 调用 KYC 导航 `start`，入口标记为 EMI |
| 银行卡编辑 | `userStatus == 10` | 禁止进入绑卡（见银行卡模块，非本文重点） |

首页**不在**冷启动时主动请求 KYC status；仅在用户点击上述入口时请求。

### 2.2 导航状态机

**启动 `start(from:entry:)`**

1. 展示 Loading。
2. 请求 `/app/v3/kyc/status`。
3. 失败：Toast/错误弹框，结束。
4. 成功：解析 `kycList`，找第一个 `kycStatus != 1` 的步骤。
   - 若全部已完成：提示「KYC already completed」，执行完成流程。
   - 否则：push 对应步骤页；传入真实 `kycId` 与是否为「最后一个未完成步骤」标志。

**步骤提交成功后 `advance(from:)`**

1. 再次请求 status。
2. 若仍有未完成步骤：用新 VC **替换**导航栈顶（不叠多层 KYC 页）。
3. 若全部完成：执行完成流程。

**完成流程 `finishFlow`**

| 入口 | 行为 |
|------|------|
| 默认（首页 Tab） | `popToRoot`；发通知刷新首页（`HQTKYCCompletedRefreshHome`、`HQTHomeShouldRefresh`） |
| EMI 入口 | 无动画 `popToRoot`；**切换 Tab 到首页**；同上发刷新通知 |

**未完成退出 `confirmExit`**

| 入口 | 行为 |
|------|------|
| 默认 | 同完成流程（回首页根） |
| EMI | **pop 回 EMI 结果页**（不切换 Tab） |

### 2.3 返回键拦截（所有 KYC 步骤页统一）

- 导航栏返回、侧滑返回（若启用）均拦截，弹出退出确认框。
- 标题：`Confirm to return?`
- 说明：文案 key **`a40`**，默认 `Do you want to pause the authentication and return to the homepage?`
- 按钮：`Cancel`（留页）/ `Confirm`（调用 `confirmExit`）
- **禁止**点击背景关闭；**各步骤页**弹框样式与文案必须一致。

### 2.4 主按钮文案

- 非最后一步：`Continue`
- 最后一步未完成步骤：`Apply Now`
- 收款账户页提交按钮固定文案 key **`m62`**，默认 `Submit`（不受上述规则影响）

---

## 三、步骤识别（kycId → 页面）

服务端 `kycList` 每项含：`kycId`、`kycSort`、`kycStatus`（1=已完成）、可选 `kycType`。

按 `kycId`（**大小写不敏感**）映射原生页：

| kycId（逻辑名） | 页面 | 说明 |
|-----------------|------|------|
| `personal` | 个人信息 | 动态表单 |
| `work`、`work_questionnaire` | 工作信息 | 动态表单 |
| `questionnaire`、`survey`、`credit_standing`、`credit` 或含 `credit` | 信用问卷 | 动态表单 |
| `identity`、`identity_card` 或含 `identity`/`aadhaar` | Aadhaar 身份认证 | 正反面图 + 号码 |
| `pan`、`tax_card`、`pan_card` 或含 `pan`/`tax` | PAN 认证 | 正面图 + 号码 |
| `pay_account` 或含 `pay`/`account` | 收款账户 | 绑卡表单 + IFSC |
| `urgent_contact`、`contact`、`emergency_contact` 或含 `urgent`/`contact`/`emergency` | 紧急联系人 | 分组 + 通讯录 |
| `identity_liveness`、`liveness` 或含 `liveness` | 人脸活体 | 静默自拍 |
| 其他 | 不支持 | Toast `Unsupported KYC step: {kycId}` |

**排序**：按 `kycSort` 升序；同 sort 按 `kycId` 字典序。

**最后一步判定**：在「未完成步骤」子集中，sort 最大（同 sort 则 kycId 字典序最大）者为最后一步。

---

## 四、接口清单

### 4.1 流程与配置

| 接口 | 用途 | 入参 | 签名 |
|------|------|------|------|
| `/app/v3/kyc/status` | 获取步骤列表 | data 空 | 标准 |
| `/app/v3/kyc/init` | 获取某步字段配置 | `kycId` | `kycId` 参与 signedData |
| `/app/v3/kyc/commit` | 整步提交（表单类） | signed：`kycId`；unsigned：`kycCommitItemList` | 见左 |
| `/app/v3/kyc/item/commit` | 单字段提交（图片/OCR 后文本） | `kycId`、`itemCode`、`itemValueType`、`itemValue` | 均在 signedData |
| `/app/v3/kyc/liveness/silent` | 静默活体 | `liveness`（Base64 字符串） | signedData |

**status 响应**：`data.kycList[]` → `{ kycId, kycSort, kycStatus, kycType? }`

**init 响应**：`data.kycItemList[]` → 字段模型（见 §五）

**commit 提交体** `kycCommitItemList` 数组元素：

```
{ itemCode, itemValueType, itemValue }
```

- `itemValueType`：`"1"`=文本，`"2"`=图片（Base64）
- 表单步：只提交**非空**字段（紧急联系人、个人信息等用 compactMap）
- 收款账户步：**所有配置字段均提交**（含空值的 optional 字段）

**item/commit 成功响应**：可能含 `echoMap.cardNo` 或顶层 `cardNo` → OCR 识别的证件号，需回填 UI。

### 4.2 省市联动

| 接口 | 入参 |
|------|------|
| `/app/v3/sys/province` | `countryId=63` |
| `/app/v3/sys/city` | `provinceId`、`countryId=63` |

选项解析兼容：`buttonList`、`list`（字符串或字典数组）。

### 4.3 IFSC 四级联动

| 接口 | 入参 | 签名 |
|------|------|------|
| `/app/v3/sys/ifsc` | unsigned：`state` / `city` / `bank` / `branch`（逐级累加） | **业务参数不参与签名**（signedData 空，参数放 unsignedData） |

| 请求参数 | 返回 |
|----------|------|
| 无参数 | 州列表 |
| `state` | 城市列表 |
| `state`+`city` | 银行列表 |
| `state`+`city`+`bank` | 支行列表 |
| 四级齐全 | IFSC 码：`ifscCode`/`ifsc` 字段，或 `list[0]` 字符串 |

---

## 五、动态字段模型

从 `kycItemList` 解析，按 `itemSort` 升序渲染。

| 字段 | 含义 |
|------|------|
| `itemCode` | 唯一编码，提交键 |
| `itemName` | 展示标题 |
| `itemType` | `1` 输入；`3` 本地选择（buttonList）；`4` API 选择（省/市等） |
| `isRequired` | `1` 必填 |
| `itemSort` | 排序；紧急联系人分组：`max(1, itemSort/10)` 为组号 |
| `buttonList` | `{ buttonKey, buttonLabel, buttonSort }` |
| `regularExpression` | 可选正则，提交时校验 |
| `maxLength` | 可选；缺失时使用 §七 默认长度；仍无匹配则 **100 字符** |

**init 获取后处理**

1. 按 `itemSort` 升序排序。
2. 按 `itemType` 映射为输入 / 本地选择 / API 选择控件。
3. **预填充历史值**（若接口回显或本地缓存有值）。
4. 建立显示值与提交值双轨（见下）。

**双轨存储**

- **显示值** `displayValue`：UI 展示（label、用户输入文本）
- **提交键** `valueKey`：选择型字段的 `buttonKey`；输入型为 nil
- **commitValue**：`trim(valueKey ?? displayValue)`，空/`NULL` 视为空串
- **submitValue**：commitValue；印度手机号字段额外规范化为 10 位本地号

---

## 六、通用表单页（Personal / Work / Credit Standing）

三页逻辑相同，仅标题与 `kycId` 不同。

### 6.1 UI

- 单卡片 + 表格列表，每行一个字段。
- 底部主按钮（Continue / Apply Now）。
- 输入型：行内 TextField；选择型：整行可点，右侧展示已选 label。

### 6.2 字段交互

| itemType | 行为 |
|----------|------|
| 1 输入 | 输入过程中实时限制字符与长度（§七）；失焦写回 displayValue；失焦或提交时格式校验 |
| 3 选择 | 点击弹单选列表（buttonList）；选中后立即写入 displayValue=label、valueKey=key |
| 4 API | 点击拉远端选项；选中后写入显示值与提交值，并触发联动 |

**API 选择细则**

- **省份**（itemType=4，code 含 province/state）：点击请求 `/app/v3/sys/province`（`countryId=63`）→ 弹框选择 → 写入 label + key；记录 `provinceId` 供城市请求。
- **城市**（code 含 city）：未选省则提示 **`k22`**；已选省则带 `provinceId` 请求 city 列表 → 弹框选择。
- **省变更**：必须清空所有 city 字段的 displayValue 与 valueKey。

**不可编辑字段**

- `account_name` 或 code 为 `name` 的账户姓名字段：只读（收款账户页，§十）。

### 6.3 自动跳转下一字段

- 输入完成或选择完成后，可自动聚焦/跳转至下一个**空**字段。
- 典型触发：子女数量 `child_count` 达到配置长度；邮编、账号、电话满足最小有效长度后跳转。
- 必须维护「**导航进行中**」标记，避免并发跳转。

### 6.4 提交

1. 收起键盘。
2. 执行 `validateFormRows`（§八）。
3. 组装 `kycCommitItemList`（非空项，submitValue）。
4. Loading + 防连点（禁用按钮、透明度 0.5）。
5. `POST /app/v3/kyc/commit`。
6. 成功 → `advance`；失败 → 网络错误 Toast；finally 恢复按钮。

---

## 七、输入限制（实时过滤）

### 7.1 字段识别规则

| 识别 | 条件 |
|------|------|
| 手机号字段 | `itemCode` 或 `itemName` 含 `phone`/`mobile` |
| 印度手机号 | 手机号字段 **或** `itemCode == whatsapp` |
| 邮箱字段 | `itemCode` 或 `itemName` 含 `email` |
| 关系字段 | `itemCode` 含 `relation` |
| 姓名字段 | `itemCode` 含 `name` 且非关系字段 |
| IFSC | `itemCode == ifsc` |
| 信用卡号 | `itemCode == credit_card` |

### 7.2 字符过滤

| itemCode | 规则 | 键盘 |
|----------|------|------|
| `child_count`、`whatsapp`、`account_no`、`account_no_verify`、`credit_card`、`zip_code` | 仅数字 | 数字键盘 |
| `ifsc` | 仅字母数字，输入转大写 | 默认 + 全大写 |
| `email` | 无特殊过滤 | 邮箱键盘，禁 autocapitalization |
| 印度手机号 | 仅数字，按 §7.4 长度限制 | 数字键盘 |
| 其他 | 无过滤 | 默认 |

### 7.3 最大长度

| itemCode | 上限 |
|----------|------|
| `child_count` | 3 |
| `account_no`、`account_no_verify` | 18 |
| `credit_card` | 32 |
| `ifsc` | 11 |
| `email` | 128 |
| `whatsapp`（有 +91 前缀 UI） | 11 |
| `whatsapp`（无 +91 前缀） | 13 |
| `zip_code` | 16 |
| `first_name`、`last_name` | 50 |
| `address` | 256 |
| `card_no`、`pan_no`、`pan_card_no` | 20 |
| 其他未列字段 | **100**（或接口 `maxLength` 若配置） |

### 7.4 WhatsApp 特殊 UI

- 字段 `whatsapp`：左侧**固定展示 +91**（纯视觉，**不参与提交**）。
- 开关 `whatsAppShowsFixedCountryCodePrefix = true` 时启用；此时 max=11。
- 提交仍走印度手机号规则（§7.5）。

### 7.5 印度手机号

**合法数字形态**

| 长度 | 规则 |
|------|------|
| 10 | 首位 6/7/8/9 |
| 11 | 前两位 06/07/08/09 |

**输入过程**

- 只保留数字；粘贴含空格/符号时自动清洗为纯数字。
- 动态 max：首位 `0` → 最多 11 位；首位 6–9 → 最多 10 位；尚未输入时按 11 位上限放行（便于先输入 `0`）。
- 超出 max 或非法前缀：拒绝输入。

**规范化（提交/去重/通讯录）**

- 12 位且以 `91` 开头：去掉国家码。
- 11 位且以 `0` 开头：去掉 leading 0 → 10 位本地号。
- `09876543210` 与 `9876543210` **视为同一号码**。
- 登录 mobile、紧急联系人 phone、通讯录抓取提交前均规范化为 **10 位本地数字字符串**（不含 `+91`）。

**错误文案**

| 场景 | 文案 |
|------|------|
| 手机号为空 | `Please enter mobile number` |
| 不符合印度规则 | key **`m14`**，默认 `Please enter correct phone number` |

---

## 八、校验规则

### 8.0 错误呈现（全局）

- 失败提示使用项目统一 **Toast / 错误弹框**。
- 通用字段失败：key **`a25`**，模板 `KT_XXX is empty or in an incorrect format.`，将 `KT_XXX` 替换为字段 `itemName`。
- 紧急联系人相关：模板中 **`KT_CONTACTNO`** 替换为联系人序号（Contact 01 → 1，Contact 02 → 2 …）。
- 一次校验命中多条规则时，**只展示第一个错误**并阻止提交/下一步。
- 提交按钮防连点；提交期间禁用并显示 Loading（§十八）。

### 8.1 通用表单 `validateFormRows`

顺序执行，**返回第一个错误**：

1. **必填**：`isRequired && commitValue 为空` → 文案 key **`a25`**，模板 `KT_XXX is empty or in an incorrect format.`，`KT_XXX` 替换为 `itemName`。
2. **邮箱**（itemType=1 且非空）：默认正则 `^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}([.-][A-Za-z]{2,})*$` 或字段自带 `regularExpression`；失败同上 a25。
3. **印度手机号**（非空）：`normalizedIndianMobile` 无效 → **`m14`**。
4. **字段正则**（非空）：匹配 `regularExpression`；失败 a25。
5. **省市联动**：存在 province/state 与 city 字段时，若 province 空而 city 非空 → **`k22`**。

### 8.2 收款账户 `validatePaymentAccountRows`

1. 除 `credit_card` 外，必填项为空 → a25。
2. **账号二次确认**：若存在 `account_no` 与 `account_no_verify`，任一侧非空则两者必须相等；不等 → **`k60`** `Bank account numbers do not match. Please check.`
3. 其他输入型非空字段走正则 → a25。
4. `credit_card`：**非必填**；仅当非空时校验 regex → a25。

### 8.3 紧急联系人 `validateEmergencyRows`

**联系人分组**（非 email、且为 contact 组字段）：按 `itemSort/10` 分组。

对每组：

| 情况 | 处理 |
|------|------|
| name、phone、relationship **全空** | **跳过**该组（可选联系人） |
| 任一有值但缺 name/phone/relationship | **`m19` 或 `m20` 随机二选一**；`KT_CONTACTNO` 替换为组序号（Contact 01→1） |
| phone 非空但印度规则不过 | **`m14`** |
| phone 规范化后在多组间重复 | **`m13`** `This contact has already been submitted. Please use another contact.` |

**邮箱字段**（独立 section）

- 必填且空 → `email_empty` / `Please enter your Email`
- 非空格式错 → **`m12`** `Invalid email format.`
- 非空 regex 失败 → a25

**其他非 contact 字段**：走通用必填 + regex。

**通讯录选取时即时校验**（选号码后、回填前）

- 格式错 → m14
- 与其他组重复（排除当前组）→ m13

---

## 九、紧急联系人页

### 9.1 结构

- 每个联系人一组 Section，标题 `Contact 01` / `Contact 02` …（组号两位补零）。
- 组内三行：**关系**（选择）、**姓名+电话**（合并卡片，点选通讯录）。
- 若配置含 email：独立 Section，普通输入框。

### 9.2 关系选择

- itemType=3，弹 `itemName` 为标题的单选框；写入 label + key。

### 9.3 通讯录联动

**权限**：使用系统 `CNContactPicker`，**无需**单独申请通讯录读取权限。

**触发**：点击联系人卡片（姓名/电话区域）。

**已有姓名或电话时再点**：

- 弹框标题 `Reselect contact?`；主按钮 `Reselect` → 清空该组 name/phone → 再拉通讯录；`Cancel` 取消。

**选取流程**

1. 记录当前联系人组号。
2. 拉起系统通讯录选择器（优先选择**电话属性** `CNContactPhoneNumbersKey`）。
3. 读取：联系人全名（givenName + familyName）、被选中的电话号码。
4. 清洗号码（仅数字、处理 +91/前缀差异）→ 印度规则校验 → 跨组重复校验。
5. 校验通过：同组回填 name + 规范化 10 位 phone；刷新 UI；可按 §6.3 自动跳转下一空字段。

**取消与异常**

| 情况 | 处理 |
|------|------|
| 用户取消选择 | 不回填，保持原值 |
| 姓名或号码为空 | 无效选择，不回填；提交时按 incomplete 校验 |
| 格式不合法 | 即时提示 **`m14`** |
| 与其他组重复 | 即时提示 **`m13`** |
| 系统通讯录不可用/读取失败 | 通用错误 Toast，**不改变**当前表单状态 |

**电话展示**：左侧固定 `+91`（视觉）；号码格式 `xxxxx xxxxx`（前 5 + 空格 + 后 5）。

### 9.4 补充规则

- 联系人组**非全空**时，**关系为必选**（缺项走 m19/m20）。
- 去重必须使用规范化后的 10 位号码，避免 `09xxxxxxxxx` 与 `9xxxxxxxxx` 被当成不同号码。

### 9.5 提交

- 校验 `validateEmergencyRows`。
- payload：非空字段 compactMap，submitValue。
- commit → advance。

---

## 十、收款账户页（pay_account）

### 10.1 UI

- 顶部提示 Banner：key **`m61`**，默认说明填写正确可用银行账户。
- 表单列表；`ifsc` 行带「Find IFSC」入口；`credit_card` 标题后缀 **`(Optional)`**（key **`m64`**）。
- 底部 **`Submit`**（m62）。

### 10.2 账户姓名

- 进入页 init 后请求 `/app/v3/user/info`（或读缓存 userName）。
- 填入 `account_name` / `name` 字段，**不可编辑**。

### 10.3 IFSC 输入

- 可手动输入（11 位字母数字大写）或跳转 **Find IFSC** 子页。
- Find IFSC 子页四级：BANK State → City → Name → Branch（文案 key **m57–m60**）。
- 逐级选择；上级变更清空下级。
- 未选上级点下级：提示 **k54/k55/k56/k57**（请先选 state/city/bank/branch）。
- 四级齐全点 Continue：带四级参数请求 ifsc 接口 → 解析 IFSC → 回调填入主表 ifsc 字段 → pop 子页。
- 子页返回键：**不**弹 KYC 退出确认，普通 pop。

### 10.4 提交

- `validatePaymentAccountRows`。
- **所有字段**均写入 commit 列表（含空 optional）。
- commit → advance。

---

## 十一、Aadhaar 身份认证页（identity）

### 11.1 字段解析

- 图片字段：`itemCode` 含 `img`/`photo`/`picture`；含 `front`→正面槽，含 `back`→背面槽；否则第一张为 front、第二张为 back。
- 文本字段：itemType=1 → Aadhaar 号码输入框。

### 11.2 UI 要点

- 正/背面上传槽：虚线框 + 占位图标；有图时显示预览 + **删除按钮**。
- **删除**：清空该槽图片与上传状态，恢复占位文案与图标。
- 号码行：**拍照前即可编辑**输入 Aadhaar 号码；正面 OCR 回填 `cardNo` 时可覆盖空框。税卡（PAN）号码仍为只读 OCR。
- 底部 Continue/Apply Now。
- 文案 keys：**m31–m45**（页面标题、上传说明、提示语、Aadhaar Number、Front/Back、Camera/Album 等）。

### 11.3 上传流程（正/背面分别）

1. ActionSheet：Camera / Album / Cancel。
2. **Camera**：申请相机权限（§十四）→ 证件相机页（后置、近焦、文档框 UI）→ 拍照。
3. **Album**：系统相册单选。
4. 图片处理（§十三）→ Base64。
5. **立即** `item/commit`（itemValueType=2）；Loading。
6. 成功：标记已上传；**正面**成功且响应含 `cardNo` → OCR 回填号码框。
7. 失败：
   - **正面**且错误码 **6212011 / 6212201**：弹身份证认证失败框（key **m44/m45**），确认后**仅清空正面**；**保留背面与人脸（若有）**。
   - 其他错误：Toast + 清空当前槽图片。

### 11.4 整页提交

1. 正面、背面均已 item/commit 成功。
2. 若有号码字段：非空 + validateFormRows 单字段校验。
3. 号码 `item/commit`（text）→ advance。
4. 若无号码字段配置：正背面完成后直接 advance。

---

## 十二、PAN 认证页（pan）

逻辑与 Aadhaar 类似，差异：

| 项 | PAN |
|----|-----|
| 图片 | 仅**正面**一槽 |
| 号码 | OCR 回填到**只读 Label**（非 TextField），有图后可展示 |
| 印地语 | 副标题/提示含印地语文案（keys **m48、m50、m53**） |
| 上传失败 6212011/6212201 | 弹失败框并清空图片（PAN 仅正面） |
| 提交 | 图片 item/commit 成功后，若有号码字段再 commit 文本 → advance |

---

## 十三、图片处理（证件/活体）

### 13.1 压缩

- 目标：**600KB 以内** JPEG。
- 策略：orientation 归一化 → 逐步降 quality → 仍超限则缩小尺寸（0.75 倍）再压。

### 13.2 证件图方向（Aadhaar/PAN）

**禁止**无条件固定旋转 90°；**禁止**在拍照预览阶段强制旋转。

1. **normalizeToUp**：按 EXIF 画成 `.up`。
2. **展示/提交**：若 `height > width`（竖图）→ **左旋 90°**；否则保持。
3. 展示与提交**同一套**方向逻辑。
4. 提交前：对 normalizedIdImageForSubmit 再 Base64。

### 13.3 活体图

- 前置摄像头拍照 → normalizeToUp → **水平镜像**（与镜像预览一致）→ 压缩 Base64。
- 字段名：`liveness`（非 identity_front_img + liveness_img 合并页模式）。

---

## 十四、人脸活体页（identity_liveness / liveness）

### 14.1 页面状态机

| 阶段 | UI | 主按钮 |
|------|-----|--------|
| idle | 占位人像图标 | **Start**（m25） |
| capturing | 前置相机预览 | **Take a photo**（m23） |
| preview | 静态预览图 | **Restart**（m24）+ **Continue/Apply Now** |

### 14.2 相机

- **前置广角** `builtInWideAngleCamera` front；不可用 → 提示 **m27** `Camera is unavailable...`
- 预览镜像；分辨率 720p；连续自动对焦 + `.near` 近距限制。
- 拍照失败 → **m26**；无图点 Continue → **m28** `Please take a photo first.`

### 14.3 权限

- 进入 capturing 前检查相机权限。
- 未决定：系统授权弹窗。
- 拒绝/受限：二次弹框，文案 key **`b2`**；Confirm → 系统设置；Cancel → 回 idle。
- **不支持相册选图**。

### 14.4 提交

- Base64 → `POST /app/v3/kyc/liveness/silent`，参数 `liveness`。
- 防连点；成功 → advance。

### 14.5 说明文案

- 英文 **m21**、印地语 **m22**（请把脸放入框内并拍清晰自拍）。

---

## 十五、证件相机页（Aadhaar/PAN 拍照）

- 模式：document（非 face）。
- 摄像头选型：**优先后置超广角** → 回退后置广角 → 均无则报错终止。
- 对焦：`continuousAutoFocus` + `autoFocusRangeRestriction = .near`。
- UI：文档取景框；拍照后 Preview：Retake / Confirm；Confirm 回调 UIImage。
- 拍照页仅做 orientation 归一化，**不**在拍照页做横竖判定旋转。

---

## 十六、错误码与 Toast 策略

| 错误码 | 场景 | 处理 |
|--------|------|------|
| **6212011**、**6212201** | Aadhaar **正面** / PAN 图片 item/commit | **不** Toast；弹「认证失败」对话框，引导重新上传；清空对应图片 |
| 其他网络/业务错误 | 常规 | Toast 或统一网络错误 |

上述错误码列入 **noToastErrorCodes**，避免与对话框重复。

---

## 十七、文案 Key 速查

| Key | 默认英文 | 用途 |
|-----|----------|------|
| a25 | KT_XXX is empty or in an incorrect format. | 通用字段校验 |
| a40 | Do you want to pause the authentication... | KYC 退出确认 |
| b2 | Please enable camera access in Settings... | 相机二次授权 |
| k22 | Please select province first. | 未选省选市 |
| k54–k57 | Please select bank state/city/name/branch first. | IFSC 前置 |
| k59 | Failed to resolve IFSC... | IFSC 解析失败 |
| k60 | Bank account numbers do not match... | 账号不一致 |
| m12 | Invalid email format. | 邮箱 |
| m13 | This contact has already been submitted... | 联系人重复 |
| m14 | Please enter correct phone number | 印度手机号 |
| m19/m20 | 联系人 incomplete（随机） | 紧急联系人缺项 |
| m21–m28 | 活体页文案 | 见 §十四 |
| m31–m45 | Aadhaar 页文案 | 见 §十一 |
| m46–m53 | PAN 页文案 | 见 §十二 |
| m54–m64 | 收款账户/IFSC | 见 §十 |
| m65 | Continue | Find IFSC 按钮 |
| m66 | Emergency Contact | 紧急联系人标题 |

均优先读远程文案配置，缺失用默认模板；含 `KT_CONTACTNO` 处替换为联系人序号。

---

## 十八、提交流程防重复

所有带提交按钮的页面：

- 提交中：`isSubmitting=true`；按钮 `isEnabled=false`；`alpha=0.5`；展示 Loading。
- 回包后（成功/失败）：恢复按钮；隐藏 Loading。
- 提交中忽略重复点击。

---

## 十九、实现检查清单（交付前自检）

- [ ] status → 按 kycSort 逐步跳转，完成后刷新首页
- [ ] 每步 init 动态渲染；itemSort 排序
- [ ] 省市区联动；省变清空市
- [ ] 表单字段自动跳转下一空项（导航进行中防并发）
- [ ] init 回显/预填充；未配置 maxLength 时默认 100
- [ ] WhatsApp +91 纯展示；提交不含前缀
- [ ] 紧急联系人通讯录选取、重选确认、分组校验 m13/m14/m19/m20
- [ ] Aadhaar 正反面分别 item/commit；OCR 回填；6212011/6212201 弹框
- [ ] PAN 单面同上
- [ ] 活体前置相机三态；silent 接口；禁相册
- [ ] 收款账户账号确认、IFSC 四级、账户姓名只读
- [ ] 证件图 600KB、方向归一化、竖图左旋
- [ ] 返回键统一 a40 退出确认；EMI 入口未完成回 EMI、完成切首页
- [ ] 印度手机号输入限制 + 提交规范化 + 紧急联系人去重
- [ ] 校验只展示第一个错误；Toast 统一风格
- [ ] 最后一步按钮 Apply Now；收款账户 Submit 独立文案

---

## 二十、一键复制提示词（给 AI）

```
请实现 iOS 原生 KYC 多步认证模块，严格按项目文档《03-印度KYC-提示词-直接使用.md》：

1. 入口：userStatus=10 时首页/EMI 调 HQTKYCNavigation.start；EMI 未完成退出回 EMI，完成切首页。
2. /app/v3/kyc/status 取 kycList，按 kycSort 找首个 kycStatus!=1，映射九类页面（personal/work/credit/identity/pan/pay_account/emergency/liveness）。
3. 每步 /app/v3/kyc/init 动态表单；commit 用 /app/v3/kyc/commit（unsigned kycCommitItemList）；图片/OCR 用 /app/v3/kyc/item/commit；活体用 /app/v3/kyc/liveness/silent。
4. 输入限制与印度手机号规则见文档 §七；校验见 §八（含紧急联系人分组 m13/m14/m19/m20、收款账户 k60、IFSC 四级）。
5. 紧急联系人：CNContactPicker 回填、+91 展示、重选确认、规范化去重。
6. Aadhaar/PAN：相机/相册、600KB、竖图左旋、6212011/6212201 失败弹框；活体前置三态、禁相册。
7. 返回统一 a40 退出确认；提交防连点；文案走配置 key；表单可自动跳转下一空字段。
不要省略校验分支。
```
