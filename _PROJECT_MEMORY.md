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

## 2026-05-14：v0.2.1 发布验证

- 标签：`v0.2.1`
- Actions：
  - `iOS AltStore Release` 成功，run id：`25845556990`
  - `Android Release APK` 成功，run id：`25845556969`
- Release：`https://github.com/uucz/NiceView/releases/tag/v0.2.1`
- AltStore 源：`https://uucz.github.io/NiceView/source.json`
- IPA：`https://github.com/uucz/NiceView/releases/download/v0.2.1/niceview-unsigned.ipa`
- 验证结果：`source.json` 已通过 `curl -L` 访问，Release 资产中 `niceview-unsigned.ipa` 大小为 `7052796` 字节，与源内 `size` 一致。
- 实机验证：用户已确认在 iOS 设备的 AltStore 中添加源并安装正常，权限校验与签名流程通过。
