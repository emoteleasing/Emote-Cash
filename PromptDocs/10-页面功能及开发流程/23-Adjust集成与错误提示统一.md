# Adjust 集成与错误提示统一

## 修改概述

本次修改包含三个主要内容：
1. 配置 Adjust SDK 的 App Token 并确保 ADID 正确上传
2. 统一网络错误和协议链接未就绪的提示信息
3. 实现全局 Loading HUD 用于域名切换等长时操作

## 1. Adjust SDK 配置

### 1.1 配置 App Token

**文件**：`HQTeConsmpton/Info.plist`

**修改内容**：
```xml
<key>HQTAdjustAppToken</key>
<string>b8konpwlkef4</string>
```

**说明**：
- Adjust App Token 用于标识应用
- Token 值：`b8konpwlkef4`
- 配置在 Info.plist 中，应用启动时自动读取

### 1.2 Adjust SDK 初始化（与 IDFA/ATT 编排）

**编排类**：`HQTIDFAAdjustCoordinator`（`Utils/HQTIDFAAdjustCoordinator.swift`）  
**SDK 封装**：`HQTAdjustManager`（运行时桥接 Adjust SDK）

**调用位置**：

| 时机 | 方法 |
|------|------|
| `didFinishLaunchingWithOptions` | `HQTIDFAAdjustCoordinator.shared.startIDFAAdjustFlow()` |
| `applicationDidBecomeActive` | `onApplicationDidBecomeActive()`（`notDetermined` 时补弹 ATT） |
| 启动配置拉取结束 | `initializeAdjustIfNeeded()` |

**流程要点**（详见 `00-基础框架/24-IDFA与Adjust初始化流程.md`）：

1. 启动后 **延迟 3 秒** 再检查 IDFA/ATT。
2. 检查时启动 **10 秒兜底**：超时仍未初始化 Adjust 则强制再试。
3. **authorized / denied / restricted / 未知 / iOS&lt;14**：检查后 **直接** 初始化 Adjust。
4. **notDetermined**：弹 ATT，用户 **同意或拒绝后** 均初始化；无操作由 10 秒兜底。
5. `adjustToken` 来自 `/app/v3/app/config`（非 Info.plist 写死）；无 token 则跳过。

**说明**：

- 使用生产环境；Debug 可在 `HQTAdjustManager` 内调整日志级别。
- 用户拒绝 ATT **不得** 跳过 Adjust 初始化。

### 1.3 ADID 获取

**获取方法**：
```swift
static func fetchAdid(completion: @escaping (String?) -> Void) {
    if (Bundle.main.object(forInfoDictionaryKey: "HQTAdjustAppToken") as? String)?.count ?? 0 < 4 {
        completion(nil)
        return
    }
    Adjust.adid { adid in
        DispatchQueue.main.async {
            completion(adid)
        }
    }
}
```

**说明**：
- 异步获取 ADID
- 如果 Token 未配置，返回 `nil`
- 回调在主线程执行

### 1.4 ADID 上传

#### 首页用户信息上传

**文件**：`HQTeConsmpton/Home/HQTHomeLoanViewController.swift`

**上传逻辑**：
```swift
private func runUserInfoThenContinue() {
    HQTAdjustTracker.fetchAdid { [weak self] adid in
        guard let self else { return }
        var signed: [String: Any] = [:]
        if let adid, !adid.isEmpty {
            signed["adid"] = adid
        }
        HQTNetworkClient.shared.post(
            endpoint: "/app/v3/user/info", 
            signedData: signed, 
            unsignedData: nil
        ) { result in
            // 处理响应
        }
    }
}
```

**说明**：
- 首页加载时自动上传 ADID
- ADID 作为签名参数（`signedData`）上传
- 接口：`/app/v3/user/info`

#### 推送通知注册

**文件**：`HQTeConsmpton/Shared/Utils/HQTPushNotificationManager.swift`

**上传逻辑**：
```swift
HQTAdjustTracker.fetchAdid { adid in
    if let adid, !adid.isEmpty {
        signedData["adid"] = adid
    }
    // 上传推送 token
}
```

**说明**：
- 推送通知注册时上传 ADID
- ADID 作为签名参数上传

#### 个人中心页面

**文件**：`HQTeConsmpton/Mine/HQTMineViewController.swift`

**上传逻辑**：
```swift
var signed: [String: Any] = [:]
let ud = UserDefaults.standard
if let adid = ud.string(forKey: "HQE_ADJUST_ADID"), !adid.isEmpty {
    signed["adid"] = adid
    if let firebase = ud.string(forKey: "HQE_FIREBASE_INSTANCE_ID"), !firebase.isEmpty {
        signed["firebaseInstanceId"] = firebase
    }
}
```

**说明**：
- 个人中心页面从 UserDefaults 读取 ADID
- 同时上传 Firebase Instance ID

### 1.5 ADID 上传场景总结

| 场景 | 接口 | 参数位置 | 说明 |
|------|------|---------|------|
| **首页加载** | `/app/v3/user/info` | signedData | 首次进入首页时上传 |
| **推送注册** | 推送相关接口 | signedData | 注册推送通知时上传 |
| **个人中心** | 个人中心相关接口 | signedData | 从 UserDefaults 读取 |

## 2. 错误提示统一

### 2.1 统一的错误提示文案

**文案**：`"The system is busy. Please try again in 2 minutes."`

**适用场景**：
1. 网络请求失败（域名未就绪）
2. 协议链接未就绪（登录页面）
3. 配置 URL 未就绪（各种 WebView 页面）

### 2.2 网络错误提示

**文件**：`HQTeConsmpton/Network/HQTNetworkError.swift`

**修改内容**：
```swift
enum HQTNetworkError: LocalizedError {
    case domainNotReady
    // ... 其他错误类型
    
    var errorDescription: String? {
        switch self {
        case .domainNotReady:
            return "The system is busy. Please try again in 2 minutes."
        // ... 其他错误处理
        }
    }
}
```

**说明**：
- `domainNotReady` 错误统一返回此提示
- 其他网络错误保持原有提示

### 2.3 登录页面协议链接提示

**文件**：`HQTeConsmpton/Login/HQTLoginViewController.swift`

**修改前**：
```swift
HQTToast.show("Agreement link is not ready yet. Please wait for app config to load, then try again.", on: view)
```

**修改后**：
```swift
HQTToast.show("The system is busy. Please try again in 2 minutes.", on: view)
```

**触发场景**：
- 用户点击"Privacy Policy"链接
- 用户点击"Service Agreement"链接
- 配置未加载完成时

### 2.4 其他使用场景

#### 官方网站页面

**文件**：
- `HQTeConsmpton/Mine/OfficialWebsite/HQTOfficialWebsiteViewController.swift`
- `HQTeConsmpton/Mine/Repayment/HQTRepaymentInstructionsViewController.swift`

**使用场景**：
```swift
guard HQTConfigURLResolver.normalizedURLString(forConfigKey: "officialWebsiteUrl") != nil else {
    HQTToast.show("The system is busy. Please try again in 2 minutes.", on: view)
    return
}
```

#### 配置 WebView 页面

**文件**：`HQTeConsmpton/Web/HQTConfigWebViewController.swift`

**使用场景**：
```swift
guard let raw = HQTConfigURLResolver.normalizedURLString(forConfigKey: configKey),
      let url = URL(string: raw)
else {
    emptyLabel.text = "The system is busy. Please try again in 2 minutes."
    emptyLabel.isHidden = false
    webView.isHidden = true
    HQTToast.show("The system is busy. Please try again in 2 minutes.", on: view)
    return
}
```

### 2.5 错误提示使用总结

| 场景 | 文件 | 触发条件 | 提示方式 |
|------|------|---------|---------|
| **网络域名未就绪** | HQTNetworkError.swift | 域名配置未加载 | Toast |
| **登录协议链接** | HQTLoginViewController.swift | 协议 URL 未就绪 | Toast |
| **官方网站** | OfficialWebsiteViewController.swift | 官网 URL 未就绪 | Toast |
| **还款说明** | RepaymentInstructionsViewController.swift | 官网 URL 未就绪 | Toast |
| **配置 WebView** | HQTConfigWebViewController.swift | 配置 URL 未就绪 | Label + Toast |

## 3. 全局 Loading HUD 实现

### 3.1 功能说明

**文件**：`HQTeConsmpton/Shared/Utils/HQTLoadingHUD.swift`

**功能**：
- 全局 Loading 提示，用于域名切换、健康检查等长时操作
- 支持多次调用（使用引用计数机制）
- 自动在主线程显示和隐藏
- 半透明黑色背景 + 白色 spinner

### 3.2 实现细节

#### 核心方法

```swift
enum HQTLoadingHUD {
    /// 显示 loading（支持多次调用）
    static func show()
    
    /// 隐藏 loading（支持多次调用）
    static func dismiss()
    
    /// 强制清除 loading（用于异常情况）
    static func forceReset()
}
```

#### 引用计数机制

```swift
private static var referenceCount = 0
private static let lock = NSLock()

static func show() {
    lock.lock()
    referenceCount += 1
    let shouldShow = referenceCount == 1
    lock.unlock()
    
    guard shouldShow else { return }
    // 显示 HUD
}

static func dismiss() {
    lock.lock()
    referenceCount = max(0, referenceCount - 1)
    let shouldDismiss = referenceCount == 0
    lock.unlock()
    
    guard shouldDismiss else { return }
    // 隐藏 HUD
}
```

**说明**：
- 使用引用计数避免多次调用导致的显示/隐藏冲突
- 线程安全（使用 NSLock）
- 只有当引用计数为 0 时才真正隐藏 HUD

#### UI 实现

```swift
// 半透明黑色背景
let container = UIView()
container.backgroundColor = UIColor(white: 0, alpha: 0.4)

// 深色圆角气泡
let bubble = UIView()
bubble.backgroundColor = UIColor(white: 0.12, alpha: 0.92)
bubble.layer.cornerRadius = 12
bubble.layer.masksToBounds = true

// 白色 spinner
let spinner = UIActivityIndicatorView(style: .large)
spinner.color = .white
spinner.startAnimating()
```

**布局**：
- 容器覆盖整个屏幕
- 气泡居中显示（80x80）
- Spinner 在气泡中心

### 3.3 使用场景

#### 域名切换时显示 Loading

**文件**：`HQTeConsmpton/Network/HQTDomainManager.swift`

**使用位置**：`ensureDomainReady(completion:)` 方法

```swift
func ensureDomainReady(completion: @escaping (Bool) -> Void) {
    // 显示 loading
    DispatchQueue.main.async {
        HQTLoadingHUD.show()
    }
    
    DispatchQueue.global(qos: .userInitiated).async {
        // 执行域名健康检查
        
        // 成功：隐藏 loading
        DispatchQueue.main.async {
            HQTLoadingHUD.dismiss()
            completion(true)
        }
        
        // 或失败：隐藏 loading
        DispatchQueue.main.async {
            HQTLoadingHUD.dismiss()
            callbacks.forEach { $0(ok) }
        }
    }
}
```

**说明**：
- 域名切换开始时显示 loading
- 健康检查完成后隐藏 loading
- 无论成功或失败都会隐藏 loading

### 3.4 设计规范

**视觉效果**：
- 背景：半透明黑色（alpha: 0.4）
- 气泡：深色半透明（white: 0.12, alpha: 0.92）
- 圆角：12pt
- 尺寸：80x80
- Spinner：白色，large 样式

**动画**：
- 显示：0.2 秒淡入
- 隐藏：0.2 秒淡出

**交互**：
- 背景不可点击（阻止用户操作）
- 自动在主线程显示和隐藏

### 3.5 与 Toast 的区别

| 特性 | HQTLoadingHUD | HQTToast |
|------|--------------|----------|
| **用途** | 长时操作加载提示 | 短时文本提示 |
| **显示内容** | Spinner | 文本消息 |
| **背景** | 半透明黑色（全屏） | 无背景 |
| **位置** | 屏幕中心 | 屏幕中心 |
| **自动隐藏** | 否（需手动调用 dismiss） | 是（2 秒后自动隐藏） |
| **引用计数** | 是 | 否 |
| **阻止交互** | 是 | 否 |

## 4. 测试建议

### 4.1 Adjust 集成测试

1. **验证 Token 配置**：
   - 检查 Info.plist 中的 `HQTAdjustAppToken` 值
   - 确认值为 `b8konpwlkef4`

2. **验证 SDK 初始化**：
   - 启动应用
   - 查看控制台日志：`Adjust: initSdk (production)`

3. **验证 ADID 获取**：
   - 进入首页
   - 查看网络请求日志
   - 确认 `/app/v3/user/info` 请求包含 `adid` 参数

4. **验证 ADID 上传**：
   - 使用抓包工具（如 Charles）
   - 查看请求参数中是否包含 `adid`
   - 确认 `adid` 值不为空

### 4.2 错误提示测试

1. **网络错误测试**：
   - 断开网络连接
   - 尝试加载首页
   - 验证提示：`"The system is busy. Please try again in 2 minutes."`

2. **协议链接测试**：
   - 在应用配置未加载完成时
   - 点击登录页面的"Privacy Policy"或"Service Agreement"
   - 验证提示：`"The system is busy. Please try again in 2 minutes."`

3. **配置 URL 测试**：
   - 在配置未加载完成时
   - 尝试打开官方网站或其他配置页面
   - 验证提示：`"The system is busy. Please try again in 2 minutes."`

### 4.3 Loading HUD 测试

1. **域名切换测试**：
   - 清除应用缓存
   - 重新启动应用
   - 观察首页加载时是否显示 loading
   - 验证 loading 在域名切换完成后自动隐藏

2. **多次调用测试**：
   - 模拟多个网络请求同时触发域名切换
   - 验证 loading 只显示一次
   - 验证所有请求完成后 loading 才隐藏

3. **视觉效果测试**：
   - 验证背景半透明黑色
   - 验证气泡深色圆角
   - 验证 spinner 白色且旋转
   - 验证居中显示

4. **交互测试**：
   - 验证 loading 显示时无法点击其他元素
   - 验证 loading 隐藏后可以正常交互

## 5. 注意事项

### 5.1 Adjust SDK

1. **Token 安全**：
   - Token 存储在 Info.plist 中
   - 不要将 Token 硬编码在代码中
   - Token 会随应用包一起分发

2. **ADID 获取时机**：
   - ADID 在 SDK 初始化后才能获取
   - 首次启动可能需要一些时间
   - 使用异步回调获取

3. **ADID 上传**：
   - ADID 作为签名参数上传
   - 确保在签名计算中包含 ADID
   - ADID 为空时不上传

### 5.2 错误提示

1. **提示文案统一**：
   - 所有系统繁忙相关的错误使用统一文案
   - 不要使用技术性的错误描述
   - 提供明确的重试时间建议

2. **用户体验**：
   - 错误提示应该简洁明了
   - 避免暴露技术细节
   - 提供解决方案或重试建议

3. **国际化**：
   - 当前使用英文提示
   - 如需支持多语言，需要添加本地化字符串

### 5.3 Loading HUD

1. **引用计数**：
   - 使用引用计数机制避免多次调用冲突
   - 确保 show() 和 dismiss() 成对调用
   - 异常情况可使用 forceReset() 强制清除

2. **线程安全**：
   - 内部使用 NSLock 保证线程安全
   - 自动在主线程显示和隐藏
   - 可以在任意线程调用

3. **使用场景**：
   - 仅用于长时操作（如域名切换、健康检查）
   - 不要用于短时操作（使用 Toast）
   - 确保操作完成后及时隐藏

## 6. 相关文档

- Adjust SDK 官方文档：https://help.adjust.com/zh/article/get-started-ios-sdk
- 网络请求规范：`02-基础网络请求规范.md`
- 用户信息上传：`02-首页Loan.md`
- 多域名策略：`00.9.2-多域名策略.md`

## 7. 修改日期

2026-04-30

## 8. 修改人员

AI Assistant (Kiro)

---

**总结**：
- ✅ 配置 Adjust App Token：`b8konpwlkef4`
- ✅ 确保 ADID 在首页、推送注册、个人中心等场景正确上传
- ✅ 统一网络错误和配置未就绪的提示文案
- ✅ 实现全局 Loading HUD 用于域名切换等长时操作
- ✅ 提升用户体验，避免技术性错误描述
- ✅ 提升用户体验，避免技术性错误描述
