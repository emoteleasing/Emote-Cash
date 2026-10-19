# 推送与通知权限 — Prompt 模板（直接使用）

> 复制本页即可让 AI 在 **HQElenFiae（Objective-C）** 实现与现网一致的推送能力。  
> 代码入口：`HQEPushNotificationManager`、`HQEPermissionSecondaryPresenter`、`HQEHomeLoanPresenter` 弹框链。

---

## 一、目标

1. Firebase + APNs + FCM；冷启动 **不** 主动弹系统通知权限。
2. **首页弹框优先级**：版本更新 → 待提现 → 复借 → **通知权限**（无复借时在链末；有复借时仅 **Cancel** 后触发；强制更新阻断则 `HQE_HOME_NOTIFICATION_DEFERRED`，回首页/登录后链末补弹）。
3. 通知引导 **每日最多一步**（`HQE_LAST_NOTIFICATION_PROMPT_DATE` = `yyyy-MM-dd`）：首日仅系统弹窗；系统拒绝后**次日**才可弹 b15 自定义引导。
4. `Denied` 且当日未处理过：展示 **b15**（Settings/Cancel）；`NotDetermined`：**禁止**先弹 b15。
5. 授权成功后刷新 FCM / InstallationId，**重试获取 googleToken 直至成功**，再调 `/app/v3/user/info` 上传（仅权限允许时传 `googleToken`）。
6. 埋点：**600** 授权成功、**601** 每次拒绝、**602** 从后台/非活跃点击推送进 App（去抖）。

---

## 二、启动（AppDelegate，勿用 Swift 模板照抄）

```objc
// willFinishLaunching
[HQEPushNotificationManager ensureFirebaseConfiguredEarly];

// didFinishLaunching
[HQEPushNotificationManager configureAtLaunch];

// didRegisterForRemoteNotificationsWithDeviceToken:
[[HQEPushNotificationManager shared] application:application didRegisterForRemoteNotificationsWithDeviceToken:deviceToken];
```

- 需 `GoogleService-Info.plist`、`Pod 'Firebase'`、`UIBackgroundModes` 含 `remote-notification`。
- **不要**在 `didFinishLaunching` 里直接 `requestAuthorization`（仅首页链触发）。

---

## 三、首页弹框链接入

在 `HQEHomeLoanPresenter` 的 `hq_runDialogPriorityChain`：

- 无复借：`hq_presentReloanIfNeeded` 直接 `completion` → 链末 `hq_presentNotificationPermissionIfNeeded`。
- 有复借：**Cancel** 在 `dismiss` 后检查通知；**Apply Now** 设 `HQE_HOME_NOTIFICATION_DEFERRED`，复借成功/失败回首页 **`refreshHomePipeline` 弹框链结束后**再检查通知（`home_pipelineDidFinish` 在通知步骤之后）。
- 强制更新：`hq_setHomeNotificationDeferred`，链中断；下次 `refreshHomePipeline` 链走通后在末位补通知（`HQE_HOME_NOTIFICATION_DEFERRED`）。

`hq_presentNotificationPermissionIfNeeded` 内延迟 0.3s 调用：

```objc
[HQEPushNotificationManager runHomeNotificationPermissionStepInWindow:win completion:completion];
```

---

## 四、权限与二次弹框

| 状态 | 行为 |
|------|------|
| Authorized / Provisional / Ephemeral | 注册 APNs、拉 FCM、上报 user/info |
| NotDetermined + 今日未弹 | **仅** `requestAuthorization`（系统弹窗，无 b15） |
| Denied + 今日未弹（通常为系统拒绝的**次日**） | b15 **Settings/Cancel** → 打开系统设置 |
| 今日已处理 | 跳过（含当日已弹过系统或 b15） |

文案：`[HQEAppConfigHelper resolvedCopyTemplateForKey:@"b15" defaultTemplate:@"We recommend enabling notifications to avoid missing updates about loan approval and successful disbursement!"]`，替换 `KT_APPNAME`。

实现：`[HQEPermissionSecondaryPresenter presentNotificationB15InWindow:settingsStyle:onConfirm:onCancel:]`。

---

## 五、FCM 与 user/info

- 获取：`[FIRMessaging messaging] tokenWithCompletion:`；失败每 **2s** 重试，最多 **20** 次。
- 打印：`NSLog(@"[HQEPush] googleToken=%@", token);`
- 缓存：`HQN_GOOGLE_FCM_TOKEN`、`HQE_FIREBASE_INSTANCE_ID`
- 上报：`POST /app/v3/user/info`
  - `signedData`：`adid`、`firebaseInstanceId`（有则传）
  - `unsignedData`：**仅通知已授权** 时传 `googleToken`
- `sceneDidBecomeActive` → `onAppBecameActiveRevalidatePushAndUpload`（从设置返回补偿）。

---

## 六、埋点

```objc
// 600 — requestAuthorization granted == YES
[HQEBuryRecorder recordEventCode:600 eventContent:nil remark1:nil remark2:nil remark3:nil];

// 601 — granted == NO（每次拒绝）
[HQEBuryRecorder recordEventCode:601 ...];

// 602 — 点击推送，且 applicationState 为 inactive 或 background
[HQEBuryRecorder recordPushNotificationOpen602Debounced];
```

在 `UNUserNotificationCenterDelegate` 的 `didReceiveNotificationResponse:` 中判断 `UIApplication.sharedApplication.applicationState`。

---

## 七、检查清单

- [ ] AppDelegate 已 early configure Firebase + 转发 APNs token
- [ ] 首页弹框链已接通知末位
- [ ] 每日频控 key `HQE_LAST_NOTIFICATION_PROMPT_DATE`
- [ ] b15 文案 + 权限弹框样式一致
- [ ] 600/601/602 埋点
- [ ] googleToken 控制台打印 + 授权后重试上传
- [ ] 未授权不传 googleToken

---

## 八、相关文档

- `00-基础框架/06-通知与推送能力实现.md`
- `00-基础框架/07-埋点与 bury.md` §7.7
- `02-首页Loan.md` §2.4.1
