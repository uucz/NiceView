# 项目计划

## 当前阶段

第二阶段：围绕真实用户体验补齐 iOS 保存、筛选发现、反馈举报与收藏分享。

## 任务列表

- [x] 创建 fork 并拉取源码（2026-05-14）
- [x] 确认上游当前仅发布 Android APK（2026-05-14）
- [x] 新增 AltStore 元数据与 source.json 生成脚本（2026-05-14）
- [x] 新增 iOS 未签名 IPA 构建与 Pages 发布 workflow（2026-05-14）
- [x] 在 GitHub Actions 上执行首个 tag 发布并验证 source.json 与 Release 资产（2026-05-14）
- [x] 在 iOS 设备上通过 AltStore 添加源并安装成功（2026-05-14）
- [x] 完成用户视角产品缺口分析（2026-05-14）
- [x] 完成后续实施路线图（2026-05-14）
- [ ] 修复 iOS 保存图片到系统相册
- [ ] 抽象 API 查询模型并补充元数据/标签/分类/反馈接口
- [ ] 增加标签发现、标签预览与方向筛选
- [ ] 增加反馈/举报入口
- [ ] 增加收藏与分享
- [ ] 整理上游 PR 拆分方案并先开 issue/discussion

## 验收标准

- GitHub Release 中存在 `niceview-unsigned.ipa`
- GitHub Pages 可访问 `https://uucz.github.io/NiceView/source.json`
- AltStore 能添加源，并在源内展示 `Nice View`
- AltStore 下载 IPA 后权限校验通过
- iOS 保存图片后能在系统 Photos 中看到
- 用户不手输标签也能发现可用标签
- 用户能对当前图片提交反馈/举报
- 收藏图片不会被 30 张历史上限淘汰

## 风险登记

见 `_PROJECT_RISKS.csv`。
