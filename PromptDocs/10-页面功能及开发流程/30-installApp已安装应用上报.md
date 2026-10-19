# 30. installApp 已安装应用上报

> **用途**：下单后数据抓取链路中，在调用 `/app/v3/order/ready` **之前**，上报本机已安装的目标 App 列表。  
> **工程落点（本仓库）**：`Loan/HQITOrderDataCaptureCoordinator`（`uploadInstallAppsThen:` / `getAppsIsExitResult`）。  
> **可直接实现的 Prompt**：同目录 [`30-installApp已安装应用上报-Prompt模板-直接使用.md`](./30-installApp已安装应用上报-Prompt模板-直接使用.md)。

---

## 30.1 目标与位置

### 在抓取流水线中的顺序

```
POST /app/v3/mobile/device
    ↓
通讯录权限 +（可选）POST /app/v3/mobile/contact 分片
    ↓
POST /app/v3/mobile/installApp     ← 本模块（有 list 才请求；空 list 跳过）
    ↓
POST /app/v3/order/ready
```

- **触发时机**：通讯录阶段结束后、`order/ready` 之前；无论强制通讯录（`retrieveMobileContact==1`）与否，**都要走此步骤**（有 list 才真正发请求）。
- **与 UI**：不单独弹 Loading / 进度条；沿用抓取进度弹框或外层 HUD 即可。
- **空 list**：**不请求** `installApp`，直接进入 `order/ready`。
- **失败策略**：**best-effort**。接口失败、超时均**不得阻断**后续 `ready`；失败时仍继续 `order/ready`。

关联总流程：[`05-数据抓取与通讯录分片.md`](./05-数据抓取与通讯录分片.md)。

---

## 30.2 接口规格：`POST /app/v3/mobile/installApp`

### 路径

| 逻辑路径 | 说明 |
|----------|------|
| `/app/v3/mobile/installApp` | 业务逻辑 endpoint；路径混淆表无映射时保持原路径（本环境 `python.py` 为恒等映射） |

网络层走工程统一 `requestWithEndpoint:signedData:unsignedData:...`，公共参数、签名规则与其它 `/app/v3/*` 一致。

### 业务入参（逻辑字段）

| 逻辑字段 | signed / unsigned | 类型 | 必填 | 说明 |
|----------|-------------------|------|------|------|
| `orderId` | **signed** | String | 是 | 下单成功返回的订单号；空串视为非法，但上报失败仍不阻断 ready |
| `list` | **unsigned** | Array\<Object\> | 有值才请求 | 已安装 App 数组；**无命中（空数组）时不调接口**，直接 `ready` |
| `remarks` | — | — | **禁止** | **不要传** `remarks`（及任何备注字段） |

### 本工程混淆出参/入参别名（Wire）

> 若网络层直接按 wire key 组包（当前 `HQITOrderDataCaptureCoordinator` 做法），按下表传；若网络层先写逻辑名再自动混淆，则写逻辑名即可。

| 逻辑字段 | Wire 字段（本包混淆） |
|----------|----------------------|
| `orderId` | `objection` |
| `list` | `exact` |
| 列表项 `appName` | `appName`（通常不混淆） |

**调用示例（逻辑语义）**：

```text
signedData   = { orderId: "<orderId>" }
unsignedData = { list: [ { appName: "paytm" }, { appName: "shadowrocket" }, ... ] }
```

**本仓库当前实现（wire 直传）**：

```objc
signedData   = @{ @"objection": orderId };
unsignedData = @{ @"exact": list };   // list 元素形如 @{ @"appName": scheme }
```

### 列表项结构

| 字段 | 类型 | 说明 |
|------|------|------|
| `appName` | String | **URL Scheme 字符串本身**（与 `Info.plist` → `LSApplicationQueriesSchemes` 中声明的 scheme 一致），**不是** App Store 显示名，也不是 Bundle ID |

示例：

```json
[
  { "appName": "paytm" },
  { "appName": "shadowrocket" }
]
```

### 成功 / 失败

- 成功：`resultCode == 200`（或工程统一成功码）→ 继续 `order/ready`。
- 失败：任意网络错误 / 业务错误 → **仍继续** `order/ready`；可不弹 Toast（避免打断抓取 UX）。
- Loading / ErrorToast：对本接口建议 `showLoading=NO`、`showErrorToast=NO`。

---

## 30.3 获取已安装 App 数组（核心实现）

### 原理（iOS 限制）

iOS 不允许枚举本机全部已装 App。合规做法：

1. 在 **`Info.plist` → `LSApplicationQueriesSchemes`** 中**预先声明**待探测的 URL Scheme 列表。
2. 对每个 scheme 调用 `UIApplication.canOpenURL(URL(string: "\(scheme)://"))`。
3. 返回 `true` 的 scheme 视为「已安装」，写入结果数组。

> Apple 对 `LSApplicationQueriesSchemes` 有数量上限（历史上约 **50** 条）。超出部分可能无法探测，plist 维护时注意裁剪。

### 算法（必须按此实现）

```
输入：无（从 Main Bundle 读 Info.plist）
输出：Array<{ appName: String }>

1. declared = Bundle.main.object(forInfoDictionaryKey: "LSApplicationQueriesSchemes")
   - 若不是 Array → 返回 []
2. result = []
3. for scheme in declared:
   - 跳过非 String / 空串
   - url = URL(string: "\(scheme)://")
   - 若 url != nil 且 UIApplication.shared.canOpenURL(url) == true:
       result.append({ "appName": scheme })
4. return result
```

### 本仓库方法名（参考）

| 方法 | 职责 |
|------|------|
| `lsApplicationQueriesSchemes` | 读取 plist 声明列表 |
| `getAppsIsExitResult` | 按上表算法生成 `[{appName: scheme}, ...]` |
| `uploadInstallAppsThen:` | 调 `installApp`，成功/失败都执行 `then` → 再 `ready` |

### 伪代码（Objective-C 风格，可直接移植）

```objc
- (NSArray<NSString *> *)lsApplicationQueriesSchemes {
    id value = [[NSBundle mainBundle] objectForInfoDictionaryKey:@"LSApplicationQueriesSchemes"];
    if (![value isKindOfClass:[NSArray class]]) return @[];
    return (NSArray<NSString *> *)value;
}

- (NSArray<NSDictionary *> *)getAppsIsExitResult {
    NSMutableArray<NSDictionary *> *appList = [NSMutableArray array];
    for (NSString *scheme in [self lsApplicationQueriesSchemes]) {
        if (![scheme isKindOfClass:[NSString class]] || scheme.length == 0) continue;
        NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@://", scheme]];
        if (url && [[UIApplication sharedApplication] canOpenURL:url]) {
            [appList addObject:@{ @"appName": scheme }];
        }
    }
    return appList;
}

- (void)uploadInstallAppsThen:(void (^)(void))then {
    NSArray *list = [self getAppsIsExitResult] ?: @[];
    void (^continueBlock)(void) = ^{ if (then) then(); };
    if (list.count == 0) { continueBlock(); return; }  // 空 list 不请求
    [[NetworkClient shared] requestWithEndpoint:@"/app/v3/mobile/installApp"
                                     signedData:@{ @"objection": orderId ?: @"" }   // 或逻辑名 orderId
                                   unsignedData:@{ @"exact": list }                // 或逻辑名 list
                                    showLoading:@NO
                                 showErrorToast:@NO
                                        success:^(id resp) { continueBlock(); }
                                        failure:^(NSError *e, NSString *m) { continueBlock(); }];
}
```

### 调用点

在「准备调用 `order/ready`」处统一包一层：

```text
callReady(allowContact):
    uploadInstallAppsThen:
        requestReady(allowContact)
```

不要在 device 之前、也不要在 contact 分片中途穿插；**固定在 ready 前一步**。

---

## 30.4 Info.plist 配置要求

- Key：`LSApplicationQueriesSchemes`（Array of String）。
- 每项为一个 URL scheme（不含 `://`），例如：`paytm`、`phonepe`、`gpay`、`whatsapp`、`shadowrocket`…
- **探测结果里的 `appName` 必须与 plist 中字符串完全一致**（大小写敏感）。
- 未写入 plist 的 scheme：`canOpenURL` 在 iOS 9+ 会恒为 `false`，无法探测。
- 本仓库当前已声明一批印度金融/支付/社交等 scheme，见工程 `Info.plist`；新产品包可按市场增减，但须遵守数量上限。

### 本仓库当前声明列表（`HQITwoFncesd/Info.plist`，实现时可整表拷贝）

```
kreditbee, freopay, cashe.page.link, dhani, navi, lazypay, kissht, bajajsuperapp,
slice, paymeindiaotpless, indialends, mv, cred, whatsapp, telegram, truecaller,
sharechat, paytm, phonepe, gpay, bhim, mobikwik, hdfcbankmbrw, imobile, axis,
sbiyono, flipkart, amazonpay, myntra, supply, swiggy, blinkit, rapido, olacabs,
uber, zomato, mmtpayment, bb-app, paisabazaar, dream11, my11circle, linkedin,
apna, nflx, hotstar, shadowrocket, filza, umangapp.com.negd.boi, digilocker,
IrctcRailConnectUrlScheme
```

---

## 30.5 路径混淆 / 网络清单

| 项 | 口径 |
|----|------|
| 逻辑 endpoint | `/app/v3/mobile/installApp` |
| 路径映射 | 无独立混淆时保持原路径；若环境有映射表，在 `python.py`（或等价 path map）登记 |
| 接口总表 | 见 `99-接口清单/01-接口总表.md` §9.5 |

---

## 30.6 验收清单

- [ ] 抓取流水线顺序为：`device` →（contact 可选）→ **`installApp`（有 list）** → `ready`
- [ ] `installApp` 步骤在强抓 / 非强抓下均会进入；**空 list 跳过请求**
- [ ] signed 仅带 `orderId`（wire：`objection`）；unsigned 仅带 `list`（wire：`exact`）
- [ ] **不传** `remarks`
- [ ] `list` 元素仅为 `{ "appName": "<scheme>" }`，scheme 来自 `LSApplicationQueriesSchemes` 且 `canOpenURL` 为 true
- [ ] 无一命中（`list` 为空）时**不请求** `installApp`，直接 `ready`
- [ ] 接口失败不阻断 `ready`，不弹错误 Toast（推荐）
- [ ] 真机已装 Paytm 等时，日志可见对应 `appName` 进入请求体

---

## 30.7 与其它模块关系

| 模块 | 关系 |
|------|------|
| `05-数据抓取与通讯录分片` | 抓取主流程；本能力为其子步骤 |
| `04` / `08` / `28` 下单与复借 | 下单成功拿到 `orderId` 后进入抓取协调器，自然带上本步骤 |
| `03-设备信息收集器` | **无关**；installApp 不读设备大字段，只读 scheme 探测结果 |
