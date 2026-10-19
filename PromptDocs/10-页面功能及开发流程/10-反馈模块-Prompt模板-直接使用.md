# 反馈模块 Prompt 模板（直接使用 · 原生）

## 使用说明

替换占位符后，复制「Prompt 内容」发给 AI。

**需求文档**：同目录 `10-反馈模块.md`  
**项目配置**：`PromptDocs/项目配置.txt`

---

## Prompt 内容

```
请为 HQITwoFncesd iOS 实现或调整「问题反馈」原生页（Objective-C / MVVM+Masonry）。

## 配置
- 字体：HQITFontHelper（Ubuntu）
- 布局：Masonry
- 类前缀：HQIT
- 设计图：{页面设计图}

## 需求
严格按 `PromptDocs/10-页面功能及开发流程/10-反馈模块.md`：
1. UI：顶栏 Feedback；Your phone number；Your question（0/1000）；Upload Pictures（最多3张）；提示语写死；底栏 Submit。
2. 校验：手机号空/非法、问题空（文案见文档）。
3. 上传 `/app/v3/sys/upload`；提交 `/app/v3/user/problemFeedback`（unsigned：description、contactWay、pictureUrl）。
4. 入口：我的页 Feedback → `HQITFeedbackViewController`（`ExitPopOne`）；下单成功页 Feedback 同页但 `ExitPopToNavRoot`。
5. **离开规则**：我的 → 仅 pop 一层；首页下单成功 → `popToRoot` 回首页根；订单复借成功 → `popToRoot` 回订单列表根（返回与提交成功一致）。

## 输出
说明改动文件与自测要点。
```
