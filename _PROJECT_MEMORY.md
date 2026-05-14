# 项目记忆

## 2026-05-14：建立 NiceView fork 并补 iOS / AltStore 发布链

- fork：`https://github.com/uucz/NiceView`
- 上游：`https://github.com/itsmorninghao/NiceView`
- 当前判断：上游 `v0.2.0` 仅发布 Android APK，没有可供 AltStore 安装的 iOS IPA。
- 决策：不手写静态 `source.json`，改为在 GitHub Actions 中构建未签名 IPA 后自动生成，避免 size、downloadURL、版本号不一致。
- 版本：fork 的首个 iOS/AltStore 版本定为 `0.2.1+1`，对应发布标签建议为 `v0.2.1`。
- 影响文件：
  - `.github/workflows/android-release.yml`
  - `.github/workflows/ios-altstore-release.yml`
  - `altstore/metadata.json`
  - `altstore/icon.svg`
  - `scripts/build_unsigned_ios_ipa.sh`
  - `scripts/generate_altstore_source.py`
  - `scripts/tests/test_generate_altstore_source.py`
  - `README.md`

## 2026-05-14：工具降级记录

- 触发条件：当前会话没有可直接调用的 Serena、sequential-thinking、shrimp-task-manager、memory MCP 服务。
- 降级动作：使用本地 `rg`、`sed`、GitHub CLI、GitHub API 与项目内 `_PROJECT_*` 文件记录计划、风险和证据。
- 回滚方式：删除本次新增的 AltStore/CI/项目记录文件，并将 README 恢复到上游内容。
