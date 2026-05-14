# 项目计划

## 当前阶段

第二阶段：围绕真实用户体验补齐 iOS 保存、筛选发现与收藏。反馈/举报和分享暂不做，PR 等 fork 开发完成后再评估；发布 CI 等本阶段功能整体完成后统一运行。

## 任务列表

- [x] 创建 fork 并拉取源码（2026-05-14）
- [x] 确认上游当前仅发布 Android APK（2026-05-14）
- [x] 新增 AltStore 元数据与 source.json 生成脚本（2026-05-14）
- [x] 新增 iOS 未签名 IPA 构建与 Pages 发布 workflow（2026-05-14）
- [x] 在 GitHub Actions 上执行首个 tag 发布并验证 source.json 与 Release 资产（2026-05-14）
- [x] 在 iOS 设备上通过 AltStore 添加源并安装成功（2026-05-14）
- [x] 完成用户视角产品缺口分析（2026-05-14）
- [x] 完成后续实施路线图（2026-05-14）
- [x] 发布 v0.2.2，修复 iOS 保存图片走系统相册权限与 Photos 写入链路（2026-05-14）
- [x] 修复 v0.2.2 实机反馈的 iOS 保存失败：历史路径失效、主页 MethodChannel/Photos 写入失败（2026-05-14，待统一发布实机回归）
- [x] 抽象 API 查询模型并补充元数据/标签/分类接口（2026-05-14）
- [x] 增加标签发现、标签预览与方向筛选（2026-05-14）
- [x] 增加收藏（2026-05-14）
- [x] 统一发布 v0.3.0 并验证 iOS/Android CI、Release 资产与 AltStore 源（2026-05-14）
- [ ] 完成 fork 侧发布与实机回归后再评估上游 PR

## 验收标准

- GitHub Release 中存在 `niceview-unsigned.ipa`
- GitHub Pages 可访问 `https://uucz.github.io/NiceView/source.json`
- AltStore 能添加源，并在源内展示 `Nice View`
- AltStore 下载 IPA 后权限校验通过
- iOS 保存图片后能在系统 Photos 中看到（v0.3.0 统一发布后实机回归）
- 用户不手输标签也能发现可用标签
- 收藏图片不会被 30 张历史上限淘汰
- `source.json` 已更新到 `0.3.0+1`，且 IPA 下载地址返回 HTTP 200

## 风险登记

见 `_PROJECT_RISKS.csv`。
