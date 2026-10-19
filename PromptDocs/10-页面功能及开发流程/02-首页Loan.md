# 02. 首页（Loan / SupHome）

> **拒量**：`userStatus==51` 提示词、`termV3` 错误码 `6234303` 的箭头/弹框/跳转门控见 [`09-拒量功能.md`](./09-拒量功能.md) 与 [`00-全流程字段与判断总表.md`](./00-全流程字段与判断总表.md) §I。

## 2.1 页面目标
- **非强制登录**：App 冷启动根页面为首页；**未登录**时不请求首页接口（§2.2），仅展示 **KYC 未认证（userStatus=10）** 访客 UI；任意可点击控件（提示语、Order、Bank、Apply Now、右上角「我的」等）**先弹出登录页**；登录成功后关闭登录 Modal 并执行 §2.2 流水线。
- 根据登录态与 `userStatus` 展示不同入口：
  - KYC 提示（userStatus=10）
  - 待提现提示（userStatus=32）
  - 产品列表与复借引导（其它状态）
  - **自动下单**（`hasOrder==0` + `userStatus==20` + `firstLoanOptionLine==system`，见 §2.7）
- 统一弹框优先级：版本更新、待提现、复借提示（自动下单启动时跳过本轮弹框链）。

## 2.2 页面进入流程（接口顺序）
> **未登录**：跳过本节全部接口，使用访客态（§2.3.5）。

1. `/app/v3/user/suphome`：获取首页主数据（含 `userStatus/promptCopy/withdrawalOrderId/hasOrder/firstLoanOptionLine`）
2. `/app/v3/user/info`：同步用户名字段（用于 Me 页展示；`adid` 放 **unsignedData**，**不参与签名**，见 §2.6）
3. `/app/v3/app/versionV2`：版本更新检查
4. **不请求** `/app/v3/product/list`（首页不再拉产品列表；自动下单产品来自 `dcRecommend`）。
5. **不在本阶段主动请求** `/app/v3/kyc/four/status`（仅在用户点击提示语或 Apply 时请求，见 §2.3.3）。
6. **流水线结束后**：先判断是否进入 **自动下单**（§2.7）；若已启动自动下单则 **跳过本轮弹框链**；否则再走 §2.4.1 弹框优先级。

### 2.2.1 首页数据刷新触发（非「每次 viewWillAppear」）
以下时机应重新跑 **§2.2 整条流水线**（或至少从 `suphome` 起按实现约定重拉）：
- **冷启动 / 首次进入首页**：第一次展示 Loan 根页时；
- **从其它页回到首页根**：离开首页后再回到 Loan 根（含导航 pop、模态关闭、切 Tab 回来等）；离开时打标，`viewWillAppear` 且栈顶为首页时整链刷新；若期间已收 `HQTHomeShouldRefresh` 则消标，避免双刷；
- **通知刷新**：登录成功、`HQTHomeShouldRefresh`、KYC/下单 H5 完成等场景。

未离开过首页时，**不应**仅因 `viewWillAppear` 重复触发整链刷新（避免多余请求与弹框打扰）。**不提供**首页列表下拉刷新（`UIRefreshControl`）。

## 2.3 userStatus 驱动规则
- 10：展示 KYC 跳转提示（Apply Now / Apply Now 按钮进入 KYC）
- 32：展示待提现弹框 `HQTWithdrawalDialog`（`HQTFunctionalDialogView` 底部卡片，与退出登录一致；**Withdraw** 进入待提现详情；**X** 关闭并继续弹框链）
- 其它：展示产品列表与复借入口（复借候选按接口筛选）

### 2.3.5 未登录访客态（非强制登录）
- 根路由：`HQTAppShell.installRoot` 始终进入首页，**不**以登录页为根。
- **不请求** §2.2 任一首页接口；`userStatus` 固定按 **10（KYC 未认证）** 渲染：展示提示语 + Order/Bank + **Apply Now**，**不展示**产品列表。
- **默认提示语**（`promptCopy` 为空时）：`Please complete the KYC certifcation beforeusing our loan service.`；提示语 **字号 14**。
- 点击首页任意交互 → `HQTAppShell.showLogin`（全屏 Modal）；登录成功 → `completeLogin` 关闭 Modal 并触发 §2.2 流水线。
- 登出 / 注销成功 / Token 失效（`2000001` / `2000002`，如 please sign in again）→ `returnToGuestHomeThenShowLogin`：先回首页访客态，**停顿 2 秒**后自动 `showLogin`（全屏 Modal）。

### 2.3.0 金额千分位展示（全项目，首页必遵）
- 产品列表 **Quota range**、复借弹框内金额等，凡展示给用户的金额须经 **`HQTAmountFormatter`** 千分位后再显示（见 `00-项目基础规范.md` §00.7.1）。
- 示例：`lowAmount=800`、`highAmount=20000` → 展示为 **`₱800-₱20,000`**；勿直接拼接裸数字。
- **Reference Interest Rate** 等费率/百分比字段不做千分位。

### 2.3.1 提示语展示区域
- 位置：首页顶部，轮播图上方。
- 组成元素：
  - 提示文本：来自 `/app/v3/user/suphome` 接口的 `promptCopy` 字段
  - 箭头图标：`make_icon_go`（14x14），显示在文本最后一个字符的右侧
  - 点击区域：整个提示语区域可点击
- 布局规则：
  - 文本不限制行数（`numberOfLines = 0`），确保完整显示
  - 箭头图标使用 `NSLayoutManager` 精确定位在最后一个字符后面
  - 使用 `glyphRange` 和 `enumerateLineFragments` 计算最后一行位置

### 2.3.2 提示语箭头显示规则
- 以下状态显示提示语箭头：
  - `10, 30, 32, 41, 80, 81`
- **`userStatus == 51`**：仅当配置中存在合法 **`rejectH5`**（拒量 H5 链接）时显示箭头并可点击；未配置时**不显示箭头**，点击**无反应**（见 `09-拒量功能.md`）。
- 其它状态隐藏箭头。
- 箭头定位算法：
  ```swift
  // 获取实际显示的字形范围
  let glyphRange = manager.glyphRange(for: container)
  let lastGlyphIndex = glyphRange.location + glyphRange.length - 1
  let lastGlyphRect = manager.boundingRect(forGlyphRange: NSRange(location: lastGlyphIndex, length: 1), in: container)
  
  // 遍历行片段找到最后一行
  manager.enumerateLineFragments(forGlyphRange: glyphRange) { rect, usedRect, _, range, stop in
      if NSLocationInRange(lastGlyphIndex, range) {
          lastLineRect = usedRect
          stop.pointee = true
      }
  }
  
  // 计算图标位置：在最后一个字符的右侧
  let iconX = hintLabel.frame.minX + lastGlyphRect.maxX + 4
  let iconY = hintLabel.frame.minY + lastLineRect.midY - 7
  ```

### 2.3.3 首页主按钮文案与点击（提示语同跳转）

| userStatus | 按钮文案 | 点击 |
|------------|----------|------|
| 10 待 KYC | Apply Now | 进 KYC（`kyc/four/status` 路由步骤） |
| 20 待申请 | Apply Now | 精准推荐（自动下单态则静默批量下单） |
| 81 逾期 | **Pay Overdue** | 订单列表待还款（orderStatus=20） |
| 80 待还款 | Apply Now | 精准推荐 |
| 41 待改卡 | **Change Bank Account** | 订单列表提交申请（orderStatus=10） |
| 32 待提现 | **Get loan** | 订单列表提交申请（orderStatus=10） |
| 30 待抓取 | **Submit Application** | 订单列表提交申请（orderStatus=10） |
| 51 已拒绝 | Apply Now | **申请按钮**：调 `dcRecommend` → 有 `rejectH5` 进拒量页，否则进对应精准失败页（错误码/空态）；**消息区**有 `rejectH5` → 拒量页，未配置 → 无箭头、无响应 |
| 100 / 其它 | Apply Now | 精准推荐 |

### 2.3.4 提示语文案来源
- 主要来源：`/app/v3/user/suphome` 接口的 `promptCopy` 字段
- 默认文案（当 `promptCopy` 为空时）：
  - `"Please complete the KYC certifcation beforeusing our loan service."`
- 提示语 **字号 14**（`HQTHomeTableHeaderView` / `hintLabel`）。
- 文案示例：
  - KYC 未完成：`"Please complete the KYC certifcation beforeusing our loan service."`
  - 待提现：`"You have an order pending withdrawal..."`
  - 其他状态：根据业务需求由后端配置

## 2.4 复借（与 `08-复借流程.md` ee1 对齐）
- **接口拉取**：首页 **不** 请求 `/app/v3/product/list`；复借若仍走 `product/state` 见 `08`（`fjtip=on`）。
- **展示与弹框开关**：`dynamicParameter.fjtip`（`HQEAppConfigHelper isFjtipOn`）
  - **on**：请求 `product/state` + 允许展示弹框链中的 **复借弹框**（会话内仅一次，见下）。**不再展示**首页 Tips 列表卡片（原 KYC 与产品列表之间的复借入口已移除）。
  - **off**：**不请求** `product/state`、不展示复借弹框；`reloanProduct` 置空。
- **候选解析**（`/app/v3/product/state` → `data`）：
  1. 若存在顶层 **`data.amountDetailList`**（数组）：遍历元素，取第一个 **`userType == 2`** 的条目作为复借产品（扁平结构，行内常含 `productId/productName/loanAmount` 等）。
  2. 否则若存在 **`data.list`**（数组）：在每个元素的 **`amountDetailList`** 中查找 **`userType == 2`**，命中则取 **该外层 list 元素** 作为复借产品（嵌套结构）。
- **首页复借入口**：已移除 Tips 卡片；复借仅 **弹框链**（`HQTReloanDialog.present` / `HQTReloanGuideDialog`）。**Apply Now** → `HQTProductApplyHandler.fetchTermV3(enterSource: .reloan)` → `HQTReloanFlowCoordinator`（见 `08-复借流程.md` §8.4），**不进入**产品申请 H5。
- **复借弹框**：版本、待提现之后；`fjtip=on` + 有候选 + `!HQTHomeSessionState.hasShownReloanDialogThisLaunch()`。Apply **不立即关闭弹框**；`userSubmitV3` 前 `dismissActiveReloanGuideDialog()`；定位 b3 叠在弹框上（keyWindow）。视觉对齐 Pencil「首页-复借提示」：主文案、浅蓝区、`bi_imagefujie`、产品行、**Apply Now** / **Cancel**。

### 2.4.1 弹框优先级（从高到低）
1. 版本更新弹框（会话内控制次数）
2. 待提现弹框（在 **§2.2.1** 触发首页流水线后的弹框链中检查）
3. 复借弹框（`fjtip=on` 时；会话内展示控制）
4. **通知权限引导**（`HQEPushNotificationManager runHomeNotificationPermissionStepInWindow:`）

**通知权限触发时机（与复借弹框）**：
- **无复借弹框**：版本/待提现链走完后延迟 **0.3s** 检查通知权限。
- **有复借弹框**：仅 **Cancel** 后延迟 **0.3s** 检查通知；**Apply Now** 设置 `HQTHomeSessionState.isNotificationDeferred = true`，复借成功并 **`runPipeline(.afterReloanFlow)`** 完成后再检查通知。
- **强制更新阻断**（无法关闭弹框链）：写入 `HQE_HOME_NOTIFICATION_DEFERRED`；下次回到首页/登录后重新走弹框链，链末再补通知引导。

**通知权限规则（与 `06-通知与推送能力实现.md` 一致）**：
- 冷启动不弹系统权限；仅在上述时机检查。
- **每日频控**：本地 `HQE_LAST_NOTIFICATION_PROMPT_DATE`（`yyyy-MM-dd`）；同一天只处理一次通知引导（系统或自定义二选一）。
- `NotDetermined`：**仅**调系统 `requestAuthorization`（**不**先弹 b15）；成功 **600** / 拒绝 **601**；当日记入频控，拒绝后**当天不再**弹 b15。
- `Denied`（系统已拒绝，无法再弹系统框）：**次日**（频控允许且仍为 Denied）才展示 **b15**（`Settings` / `Cancel`）→ 去系统设置；从设置返回后 `sceneDidBecomeActive` 补偿刷新 FCM 并上报。
- 已授权：静默 `registerForRemoteNotifications` + 拉 FCM / InstallationId，`/app/v3/user/info` 的 `unsignedData.googleToken` 上报（有 token 才传）；FCM 获取失败则间隔重试直至成功或达上限。
- 文案：**b15**（缺省：`We recommend enabling notifications to avoid missing updates about loan approval and successful disbursement!`）。
- 推送点击进 App：**602**（`inactive`/`background` 触发，去抖约 0.75s）；控制台打印 `googleToken`。

## 2.5 产品申请按钮与跳转
- 点击产品申请触发流程由“产品申请/下单”模块负责。
- 首页点击“Apply Now/申请”时：
  - 必须触发防连点，避免重复拉起下单页面
  - 埋点按项目约定事件码上报
  - 先请求 `/app/v3/product/termV3`（`productId`）
- 若返回错误码 **`6230002` / `6230003`**：
    - 使用项目统一弹框展示接口返回 `resultMsg`
    - 按设计图使用双按钮文案（`Confirm` / `Know More`）
    - 点击 **Know More** 跳转订单详情页
    - 跳转参数：`productId = 当前产品ID`，`orderId` 从响应解析（缺省占位 `"1"`），`orderType` 按实现约定
- 若返回错误码 **`6234303`**（拒量，见 `09-拒量功能.md`）：
    - **`rejectH5` 已配置**：**不弹框**，直接进入拒量推荐产品 H5
    - **`rejectH5` 未配置**：弹统一处理中弹框（`resultMsg`），**不进行页面跳转**（Know More 不打开订单详情）
  - 其他错误码：按通用 Toast 失败提示
  - termV3 成功：**普通列表申请**（`enterSource=home`）进入产品申请页/H5；**若处于自动下单态**（§2.7）则 **不进** 申请页，改走自动下单协调器；**首页复借弹框**（`enterSource=reloan`）不进入申请页，走 `08-复借流程.md` §8.4 原生链路（`userSubmitV3` + 抓取 + 成功页）。

## 2.6 Adjust 与 user/info 上报规则
- Adjust 注册：
  - 启动阶段若存在 `adjustToken`，必须初始化 Adjust SDK（经 `HQTIDFAAdjustCoordinator`：3s 后 IDFA 检查 + 10s 兜底，见 `00-基础框架/24-IDFA与Adjust初始化流程.md`）。
- adid 上报：
  - 调用 `/app/v3/user/info` 时优先携带 `adid`（来自 Adjust），放入 **`unsignedData`**（写入 `data` 但不进业务签名；该接口仅公共参数验签）。
  - 有 `adjustToken` 时，流程必须确保 adid 能被读取并上传成功。
  - 当 adid 不可用时，按项目约定不上传无意义占位字段，避免污染请求体。

## 2.7 自动下单与精准推荐（入口摘要）

> **完整规格（接口字段、10s 超时、列表/错误/成功页、批量 `userSubmitDcUpgrade`）见 [`31-精准推荐与自动下单.md`](./31-精准推荐与自动下单.md)。** 本节仅保留首页侧入口与资格，避免与旧 `termV3`+`userSubmitV3` 描述冲突。

### 2.7.1 自动下单态判定（须同时成立）

| 字段 | 条件 |
|------|------|
| 登录 | 已登录 |
| `hasOrder` | `== 0` |
| `userStatus` | `== 20` |
| `firstLoanOptionLine` | 忽略大小写等于 `system` |

### 2.7.2 触发

1. KYC 完成回首页：会话标记 + 流水线结束且 eligible → 启动自动下单，**跳过本轮弹框链**。  
2. eligible 下点击首页主 Apply（及同等路由）→ 启动自动下单。  
3. 非 eligible → 手动精准推荐：匹配弹框 → `dcRecommend` → 列表/错误页（见 `31`）。

### 2.7.3 执行口径（详见 31）

```
dcRecommend（10s 超时按 4102007 页）
  → 全部产品：最大金额 + 最高期限 + 已勾协议
  → 定位 → userSubmitDcUpgrade（批量，不传 orderType）
  → 抓取（首单 orderId）→ 精准推荐成功页（全部 orderId）
```

定位/抓取/好评交叉：`12`、`05`、`30`、`13`。与复借同时出现时 **自动下单优先于弹框链**。

