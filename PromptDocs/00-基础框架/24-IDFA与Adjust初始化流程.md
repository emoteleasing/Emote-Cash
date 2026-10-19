# 24. IDFA 权限检查与 Adjust SDK 初始化流程

> 实现类：`HQTIDFAAdjustCoordinator`（`Utils/HQTIDFAAdjustCoordinator.swift`）  
> Adjust 封装：`HQTAdjustManager`  
> 入口：`AppDelegate.application(_:didFinishLaunchingWithOptions:)`

## 24.1 目标

- 在合规前提下完成 ATT/IDFA 检查。
- **所有路径最终都必须初始化 Adjust SDK**（存在有效 `adjustToken` 时），用户拒绝跟踪也不跳过。
- `adid` 供 `/app/v3/user/info` 等接口优先上报。

## 24.2 时序总览

```
didFinishLaunchingWithOptions
    └── startIDFAAdjustFlow()
            └── 延迟 3s
                    └── beginIDFACheckAndAdjustFlow()
                            ├── 启动 10s 兜底定时器 → performAdjustInitialization("fallback10s")
                            └── 按 ATT 状态分支（见 24.3）
```

并行：`applicationDidBecomeActive` → `performStartupSequence()` → 配置就绪后 `initializeAdjustIfNeeded()`。

## 24.3 ATT 状态分支（iOS 14+）

| 业务分类 | 系统状态 | 处理 |
|----------|----------|------|
| 有授权 | `.authorized` | 立即初始化 Adjust |
| 已拒绝 | `.denied` | 立即初始化 Adjust |
| 未知 | `.restricted`、`@unknown default` | 立即初始化 Adjust |
| 无授权（需用户选择） | `.notDetermined` | 应用 **active** 时 `requestTrackingAuthorization`；回调后（同意/拒绝）初始化 Adjust |
| iOS 14 以下 | （无 ATT API） | 视为有授权，立即初始化 Adjust |

**要点**：

1. `notDetermined` 时 **不在弹 ATT 之前** 初始化 Adjust，避免与「等用户选择后再初始化」冲突。
2. 用户完成 ATT 选择后 **无论同意或拒绝** 都调用 `performAdjustInitialization`。
3. 若用户长期不操作、`notDetermined` 且未弹窗，由 **10 秒兜底** 强制初始化（需已有 `adjustToken`，通常来自缓存配置）。
4. **有网才弹 ATT**；同意系统网络权限瞬间 App 常为 `Inactive`，此时不可调用 `requestTrackingAuthorization`（会静默失败）。须在回到 `Active` 后立刻补弹：监听 `UIApplicationDidBecomeActiveNotification`，并对 defer 做短时重试（避免必须退后台再进前台）。

## 24.4 10 秒兜底定时器

- 在 **开始 IDFA 检查** 时启动（与 3 秒延迟独立）。
- 超时仍未 `HQTAdjustManager.isInitialized == true` 时再次尝试 `performAdjustInitialization`。
- Adjust 初始化成功后 **取消** 兜底任务。

## 24.5 adjustToken 来源

- 优先 `/app/v3/app/config` → `adjustToken`（兼容 wire `adjustKey`）。
- 未下发时使用本包常量 `HQITAdjustAppToken`（当前：`ry93vjpnafi8`）。
- 无 token 时跳过 SDK 启动（兜底定时器同样无法初始化，仅打日志）。

## 24.6 接入清单（给 AI / 评审）

- [ ] `didFinishLaunchingWithOptions` 调用 `HQTIDFAAdjustCoordinator.shared.startIDFAAdjustFlow()`。
- [ ] `applicationDidBecomeActive` 调用 `onApplicationDidBecomeActive()`（补弹 ATT）。
- [ ] 启动配置完成后调用 `initializeAdjustIfNeeded()`（token 可能刚写入缓存）。
- [ ] **禁止** 在配置拉取回调之外单独、过早初始化 Adjust（避免绕过 IDFA 流程）。
- [ ] `Info.plist` 已配置 `NSUserTrackingUsageDescription`。
- [ ] 依赖 `AppTrackingTransparency.framework`（iOS 14+）。

## 24.7 与设备信息 IDFA 采集的关系

- `HQTDeviceInfoCollector` 内 `idfa` 字段仍按系统授权读取，与 Adjust `adid` 上报链路独立。
- `/app/v3/user/info` 的 `adid` **优先** Adjust SDK，见 `03-设备信息收集器.md` §3.3.1。
