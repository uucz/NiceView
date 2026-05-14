# 项目计划

## 当前阶段

第一阶段：为 Nice View fork 补齐 iOS / AltStore 发布能力。

## 任务列表

- [x] 创建 fork 并拉取源码（2026-05-14）
- [x] 确认上游当前仅发布 Android APK（2026-05-14）
- [x] 新增 AltStore 元数据与 source.json 生成脚本（2026-05-14）
- [x] 新增 iOS 未签名 IPA 构建与 Pages 发布 workflow（2026-05-14）
- [x] 在 GitHub Actions 上执行首个 tag 发布并验证 source.json 与 Release 资产（2026-05-14）

## 验收标准

- GitHub Release 中存在 `niceview-unsigned.ipa`
- GitHub Pages 可访问 `https://uucz.github.io/NiceView/source.json`
- AltStore 能添加源，并在源内展示 `Nice View`（待实机验证）
- AltStore 下载 IPA 后权限校验通过（待实机验证）

## 风险登记

见 `_PROJECT_RISKS.csv`。
