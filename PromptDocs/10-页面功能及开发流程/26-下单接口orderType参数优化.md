# 下单接口 orderType 参数优化

## 修改概述

优化 `/app/v3/order/userSubmitV3` 下单接口的参数：
- `orderType` 字段只在复借时添加
- 普通下单不添加 `orderType` 字段
- 避免不必要的参数传递

## 1. 修改背景

### 1.1 原有逻辑

**所有下单请求都包含 orderType**：
```swift
var unsigned: [String: Any] = [
    "showTerm": showTerm,
    "orderType": orderType,  // 总是添加，即使是 0
]
```

**问题**：
- 普通下单时 `orderType = 0`，但仍然传递该字段
- 增加了不必要的参数
- 可能导致后端处理逻辑混淆

### 1.2 新逻辑

**只在复借时添加 orderType**：
```swift
var unsigned: [String: Any] = [
    "showTerm": showTerm,
]
// orderType 只在复借时添加（orderType == 1）
if orderType == 1 {
    unsigned["orderType"] = orderType
}
```

**优点**：
- 普通下单不传递 `orderType` 字段
- 参数更简洁
- 语义更清晰

## 2. 代码修改

### 2.1 修改位置

**文件**：`HQTeConsmpton/Home/HQTProductApplyViewController.swift`

**方法**：`sendUserSubmitV3(longitude:latitude:)`

### 2.2 修改内容

**修改前**：
```swift
var unsigned: [String: Any] = [
    "showTerm": showTerm,
    "orderType": orderType,
]
if let rid = selectedBankRecordId, !rid.isEmpty {
    unsigned["bankCardBindId"] = rid
}
```

**修改后**：
```swift
var unsigned: [String: Any] = [
    "showTerm": showTerm,
]
// orderType 只在复借时添加（orderType == 1）
if orderType == 1 {
    unsigned["orderType"] = orderType
}
if let rid = selectedBankRecordId, !rid.isEmpty {
    unsigned["bankCardBindId"] = rid
}
```

### 2.3 复借下单方法

**方法**：`performReloanOrderSubmit(productId:loanAmount:showTerm:longitude:latitude:)`

**说明**：
- 复借下单方法已经正确设置 `orderType = 1`
- 无需修改

```swift
let unsigned: [String: Any] = [
    "showTerm": showTerm,
    "orderType": 1, // 复借固定为1
]
```

## 3. userSubmitV3 签名字段（与 orderType 无关）

> 完整说明见 `00-基础框架/02-基础网络请求规范.md` §2.4.4。

| 参与签名 | 不参与签名 |
|----------|------------|
| `productId`、`loanAmount`、`longitude`、`latitude`（6 位小数字符串）、`imei="null"`、`serialNo` | `showTerm`；`orderType`（仅复借时出现在 `data`）；`bankCardBindId`（可选） |

## 4. 参数对比

### 4.1 普通下单（orderType = 0）

**修改前**：
```json
{
  "showTerm": "30 Days",
  "orderType": 0,
  "bankCardBindId": "123456"
}
```

**修改后**：
```json
{
  "showTerm": "30 Days",
  "bankCardBindId": "123456"
}
```

**说明**：不再包含 `orderType` 字段

### 4.2 复借下单（orderType = 1）

**修改前**：
```json
{
  "showTerm": "30 Days",
  "orderType": 1
}
```

**修改后**：
```json
{
  "showTerm": "30 Days",
  "orderType": 1
}
```

**说明**：保持不变，仍然包含 `orderType` 字段

## 5. orderType 说明

### 5.1 定义

**文件**：`HQTeConsmpton/Home/HQTProductApplyViewController.swift`

```swift
/// `0` 普通下单，`1` 复借（`04-产品申请与下单.md` 4.4.2）
private let orderType: Int
```

### 5.2 取值

| 值 | 含义 | 场景 | 是否传递 |
|----|------|------|---------|
| **0** | 普通下单 | 从首页产品列表进入 | **不传递** |
| **1** | 复借下单 | 从复借弹框进入 | **传递**（字符串 `"1"`） |

### 5.3 初始化

**普通下单**：
```swift
let vc = HQTProductApplyViewController(
    productId: productId,
    prefillProductName: productName,
    prefillProductLogoURL: logoURL,
    orderType: 0  // 默认值，可省略
)
```

**复借下单**：
```swift
let vc = HQTProductApplyViewController(
    productId: productId,
    prefillProductName: productName,
    prefillProductLogoURL: logoURL,
    orderType: 1  // 复借
)
```

## 6. 接口参数完整说明

> 签名字段与方式四规则以 `00-基础框架/02-基础网络请求规范.md` §2.4.4 为准。

### 6.1 接口端点

```
POST /app/v3/order/userSubmitV3
```

### 6.2 签名参数（signedData，共 6 个）

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `productId` | String | ✓ | 产品 ID |
| `loanAmount` | String | ✓ | 申请金额 |
| `longitude` | String | ✓ | **6 位小数字符串**；非强抓 `-360.000000` |
| `latitude` | String | ✓ | 同上 |
| `imei` | String | ✓ | 固定 **`"null"`** |
| `serialNo` | String | ✓ | 与 `deviceId` 一致 |

### 6.3 非签名参数（unsignedData）

| 参数 | 类型 | 必填 | 说明 |
|------|------|------|------|
| `showTerm` | String | ✓ | 期限展示值 |
| `orderType` | String | ✗ | **仅复借**传 **`"1"`** |
| `bankCardBindId` | String | ✗ | 有绑卡时传 |

**说明**：
- `orderType` 不参与签名；仅复借出现在 `data` 中
- `bankCardBindId` 只在有银行卡时传递

## 7. 测试建议

### 7.1 普通下单测试

1. **从首页产品列表进入**：
   - 选择产品
   - 填写信息
   - 点击 Apply now
   - 抓包查看请求参数
   - 验证 **不包含** `orderType` 字段

2. **验证参数**：
   ```json
   {
     "showTerm": "30 Days",
     "bankCardBindId": "123456"
   }
   ```

### 7.2 复借下单测试

1. **从复借弹框进入**：
   - 触发复借弹框
   - 点击 Apply
   - 抓包查看请求参数
   - 验证 **包含** `orderType: 1` 字段

2. **验证参数**：
   ```json
   {
     "showTerm": "30 Days",
     "orderType": 1
   }
   ```

### 7.3 边界测试

1. **orderType = 0 的情况**：
   - 确保普通下单不传递 `orderType`
   - 验证后端正常处理

2. **orderType = 1 的情况**：
   - 确保复借下单传递 `orderType: 1`
   - 验证后端正确识别为复借

## 8. 注意事项

### 8.1 后端兼容性

**问题**：后端是否兼容不传递 `orderType` 的情况？

**解决方案**：
- 后端应该将缺失的 `orderType` 视为普通下单（默认值 0）
- 或者后端根据其他字段判断是否为复借
- 需要与后端确认兼容性

### 8.2 复借判断

**后端如何判断复借**：
- 方式 1：根据 `orderType == 1` 判断
- 方式 2：根据用户状态判断（有历史订单）
- 方式 3：根据产品类型判断（userType == 2）

**建议**：
- 复借时明确传递 `orderType: 1`
- 普通下单不传递 `orderType`
- 后端根据是否存在 `orderType` 字段判断

### 8.3 与其他参数的关系

**bankCardBindId**：
- 普通下单：必须传递（已添加银行卡检查）
- 复借下单：可选（允许缺省）

**showTerm**：
- 所有下单都必须传递

## 9. 相关文档

- 签名字段总表：`00-基础框架/02-基础网络请求规范.md` §2.4.4
- 产品下单流程：`04-产品申请与下单.md`
- 复借流程：`08-复借流程.md`
- 下单接口说明：`04-产品申请与下单.md` 第 4.5 节

## 10. 修改日期

2026-04-30

## 11. 修改人员

AI Assistant (Kiro)

---

**总结**：
- ✅ `orderType` 只在复借时添加（orderType == 1）
- ✅ 普通下单不传递 `orderType` 字段
- ✅ 参数更简洁，语义更清晰
- ✅ 避免不必要的参数传递
- ✅ 需要确认后端兼容性
