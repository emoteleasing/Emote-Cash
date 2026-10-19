# 03-H5 KYC（四步）提示词 - 直接使用

> **工程实现**：`KYC/HQTKYCH5ViewController.swift`、`KYC/HQTKYCNavigation.swift`、`KYC/HQTKYCModels.swift`；首页入口 `HQTHomeHintRouter` / `HQTHomeLoanPresenter`。

## 一、目标

- KYC 统一跳转 H5 单页，完成四步认证（每步在原生侧传入 H5 的 **`kycId` 字符串**与下列一致）：
  1. `personal`
  2. `work_questionnaire`
  3. `urgent_contact`
  4. `identity_liveness`
- 入口：`userStatus=10` 时，首页顶部提示词或 `Apply now` 点击后先请求 `/app/v3/kyc/four/status`，再按 `data.echoMap.willExecuteStepNumber`（1–4）映射为上述 **`kycId`** 后跳 H5（见下文「二」）。

## 二、H5 页面参数（原生 -> H5）

进入 H5 时，原生调用 JS 方法名：`mobileUserdata`，传入：

- `baseUrl`（可用域名）
- `userId`
- `token`
- `UA`
- `phoneNum`
- `deviceId`
- `clientVersion`
- `appId`
- `salt`
- `countryCode`（多国家包）
- `kycId`：**必须为字符串**，与接口步骤号一一对应（`mobileUserdata` 与若原生拼接的 URL `?kycId=` 应使用同一套取值）：

| `willExecuteStepNumber`（`/app/v3/kyc/four/status` → `data.echoMap`） | 传入 H5 的 `kycId` |
| ---: | --- |
| 1 | `personal` |
| 2 | `work_questionnaire` |
| 3 | `urgent_contact` |
| 4 | `identity_liveness` |

**禁止混淆字段（PHI352-DC 已踩坑）**

- `HQTAPIProjectWireMap` 中 `personal` ↔ `exigency` 等仅用于 **API 请求/响应 wire**，**不得**写入 H5。
- 实现类 `HQTKYCStepMapper.kycIdString(forStep:)` 必须返回上表逻辑名；日志/联调若出现 `kycId=exigency` 说明映射错误，H5 无法展示对应步骤。
- `HQTKYCNavigation.buildPageURL`：打开 `kycLink` 时**始终**用 `willExecuteStepNumber` 映射后的 `kycId` 覆盖 URL 上的 `kycId` / `explain` / `step` / `willExecuteStepNumber`（配置里若带错参数也要纠正）。

交互通道名：`iosHandler`。

## 三、链接配置

- KYC 主链接：`kycLink`
- 修改银行卡页：`updateBankLink`
- 银行卡页若为编辑传 `bindId`，新增不传。

## 四、页面与交互要求

- 隐藏原生导航栏。
- 禁止右滑返回。
- H5 返回确认弹窗由 H5 处理。
- 进入 H5 在顶部显示加载进度条（可不使用全屏遮罩 loading）。
- H5 完成 KYC 后发消息给 iOS，iOS 返回首页并继续后续流程；若满足自动下单条件（`hasOrder==0` + `userStatus==20` + `firstLoanOptionLine==system`），按 `02-首页Loan.md` §2.7 启动自动下单。

## 五、权限二次弹窗（与 H5 弹窗不冲突）

- H5 请求相机权限二次弹窗时，原生不要 `present`，改为 `addSubview` 到 `keyWindow`。
- H5 成功获取照片后会发送 `getPicSucc`，原生需关闭该二次权限弹窗。

## 六、紧急联系人（selectContact）

### 触发

- H5 点击联系人姓名/手机号区域 -> 发消息：`selectContact`。

### 原生行为

- 打开系统联系人选择器（`CNContactPickerViewController`），仅用于“选择联系人手机号回填”。
- 仅在选中手机号属性时回传给 H5：`{name, phone}`（JSON 字符串）。
- 回传优先触发：
  - `window.selectContact(payloadString)`
  - `window.onSelectContact(payloadString)`（兼容旧页面）

### 原生数据处理规则

- 姓名：`givenName + familyName`；若都空则取 `nickname`；去前后空格。
- 手机号：去掉特殊字符和空格，仅保留数字。
- 去重：同一次 KYC 页面会话内，已选择过的号码不重复回传。

### 权限判断与异常分支（必须实现）

- 首次进入联系人选择不额外弹自定义通讯录权限框，直接交给系统联系人选择器处理。
- 用户取消选择：不回调、不清空已有值。
- 选中结果无姓名或无手机号：不回调，保持当前表单状态。
- 联系人选择器不可拉起（极端异常）：原生 toast 通用失败提示（例如：`Unable to read contacts, please retry.`）。
- 注意：`m13/m14/m19/m20` 是“紧急联系人业务校验提示”，由 H5 按提交规则触发，原生只负责稳定回填联系人数据。

## 七、紧急联系人校验与错误提示（H5 必须实现）

- 联系人信息不完整（name/phone/relationship 缺任一）：
  - key：`m19` 或 `m20` 随机
  - `KT_CONTACTNO` 替换联系人序号（Contact 01 -> 1，Contact 02 -> 2）
- 手机号格式不合法：`m14`
- 手机号重复：`m13`
- 邮箱格式不合法（仅非空时校验）：`m12`
- 提交时只展示第一个错误并阻止下一步。

### 校验补充口径

- 联系人组“全空”时可跳过该组校验。
- 手机号重复判断需基于“标准化后号码”（仅数字）比较。
- 手机号格式校验按印度手机号规则（`HQTIndianPhoneValidator`；见 `25-印度手机号规则.md`）。

## 八、H5 -> Native 桥接动作（完整清单）

通道名固定：`iosHandler`。`action` 统一转小写后分发。

- `selectContact`：拉起系统联系人选择器。
- `getPicSucc`：关闭相机权限二次弹窗（原生 keyWindow 弹窗）。
- `cameraPermission` / `camerapermission`：检查相机权限；拒绝时弹二次引导。
- `photoLibraryPermission` / `photolibrarypermission`：请求相册权限（仅请求，不回调 H5）。
- `openCamera` / `opencamera`：拉起系统相机，成功后回传 base64 给 `window.getPicSucc`。
- `openPhotoLibrary` / `openphotolibrary`：拉起系统相册，成功后回传 base64 给 `window.getPicSucc`。
- `camera_permission_secondary` / `requestcamera`：展示原生“去设置”二次权限弹窗。
- `getUserData` / `getMobileUserData` / `mobileUserdata`：原生再次向 H5 注入用户数据。
- `kycComplete` / `finishKyc` / `kycDone` / `kycGoBack`：结束 KYC 并返回（首页流程默认回根）。
- `changeCardGoBack` / `bankCardModify`：银行卡修改场景返回上一页。
- `goBack`：优先走 H5 history.back。
- `logout` / `loginOut` / `deleteAccount`：清会话并重装根控制器到登录流程。

## 九、原生必须实现的提示/弹窗能力

- 域名不可用：toast `Domain unavailable`（或后端错误文案）。
- H5 链接非法：toast `Invalid KYC URL`。
- H5 加载失败：关闭 loading，保留页面可重试状态（不要卡死遮罩）。
- 相机权限被拒绝：展示统一弹窗（`Permission required` + `Settings/Cancel`），并使用 `keyWindow` 承载，不 `present`。
- `getPicSucc` 到达后必须关闭二次权限弹窗，避免遮挡 H5。
- H5 JS Alert/Confirm 需由原生代理承接，避免页面无响应。

## 十、可直接粘贴给 AI 的实现提示词（完整）

```
实现 H5 KYC 四步认证原生容器，要求：
1) 首页 userStatus=10 时，点击顶部提示词或 Apply now，先请求 /app/v3/kyc/four/status；
2) 从 data.echoMap.willExecuteStepNumber 映射 kycId（字符串）：1→personal，2→work_questionnaire，3→urgent_contact，4→identity_liveness（勿用 wire 名 exigency）；URL `?kycId=` 与 mobileUserdata 内 `kycId` 必须一致，且原生打开链接时强制覆盖错误 query；
3) H5 容器使用 WKWebView，隐藏导航栏，禁右滑返回，顶部加载进度条（可不使用全屏遮罩 loading）；
4) 进入 H5 后调用 window.mobileUserdata(...)，参数包含 baseUrl/userId/token/UA/phoneNum/deviceId/clientVersion/appId/salt/countryCode/kycId（kycId 为上述字符串，勿传数字 1–4）；
5) 桥通道名 iosHandler；
6) 桥通道名 iosHandler，action 不区分大小写，完整处理以下动作：
   selectContact/getPicSucc/cameraPermission/photoLibraryPermission/openCamera/openPhotoLibrary/camera_permission_secondary/requestcamera/getUserData/mobileUserdata/kycComplete/finishKyc/kycDone/changeCardGoBack/bankCardModify/goBack/logout/loginOut/deleteAccount；
7) selectContact：
   - 打开 CNContactPicker，读取被点击手机号属性；
   - 姓名规则：givenName+familyName，空则 nickname，trim；
   - 手机号规则：仅保留数字；
   - 结果无 name 或无 phone 不回填；
   - 同会话重复号码不重复回填；
   - 回传 JSON 字符串给 window.selectContact 与 window.onSelectContact；
8) 紧急联系人错误提示口径由 H5 实现并与原生对齐：
   - 不完整（name/phone/relationship 缺一）=> m19/m20 随机，替换 KT_CONTACTNO；
   - 手机号不合法 => m14（印度规则：10 位首位 6–9，或 11 位前两位 06–09；规范化后去重）；
   - 手机号重复 => m13（按标准化号码比较）；
   - 邮箱非空且格式错误 => m12；
   - 提交时仅展示首个错误并阻止下一步；
9) 相机二次权限弹窗必须使用 keyWindow addSubview 方案（不要 present），收到 getPicSucc 立即关闭；
10) 图片选择成功后，原生将 JPEG(base64) 通过 window.getPicSucc 回传 H5，并写 localStorage/sessionStorage；
11) 处理域名不可用、URL 非法、加载失败、权限拒绝等失败分支，统一 toast/弹窗，不得卡死遮罩；
12) KYC 完成类动作：默认 popToRoot；银行卡修改场景支持仅 pop 一层。
```

