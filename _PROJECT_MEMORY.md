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

## 2026-05-14：产品视角缺口分析

- 产物：`_PRODUCT_REVIEW.md`
- 关键结论：
  - 当前产品完成了安装、随机浏览、标签、历史、下载和发布链的最小闭环。
  - P0 缺口是 iOS 保存图片语义不一致：当前非 Android 仅写入 App Documents，但 UI 文案提示已保存到系统相册。
  - API 公开能力远多于 App 当前能力，尤其是方向筛选、分类、include/exclude、标签列表、图集、元数据和反馈举报。
  - PR 暂不推进，等 fork 开发完成后再统一评估。

## 2026-05-14：后续实施路线图

- 产物：`_IMPLEMENTATION_ROADMAP.md`
- API 验证：
  - `/v1/site-config` 返回资源规模、精选分类、公告和封禁策略。
  - `/v1/featured-tags`、`/v1/categories`、`/v1/tags`、`/v1/random/meta`、`/v1/tag/{name}/preview` 已验证可用。
  - `/v1/feedback` body 为 `{ category, subject, message, contact }`。
- 推荐路线：
  1. 先修 iOS 保存到系统相册。
  2. 再抽象 API 查询模型。
  3. 再做标签发现、方向筛选和收藏。
  4. 反馈/举报和分享暂不做；上游 PR 暂停到 fork 功能稳定后再评估。

## 2026-05-14：v0.2.2 iOS 保存相册实施

- 目标：修复 iOS 点击保存后只写入 App Documents、但 UI 提示系统相册的问题。
- 实施：
  - Dart 层在 iOS 上改走 `nice_view/downloads` MethodChannel。
  - iOS CI 生成工程后注入 Swift `AppDelegate.swift`，使用 Photos framework 保存到系统相册。
  - `Info.plist` 注入 `NSPhotoLibraryAddUsageDescription` 和 `NSPhotoLibraryUsageDescription`。
  - AltStore `metadata.json` 同步声明照片权限。
  - 保存成功文案根据返回目的地显示“系统相册”或“应用文件”。

## 2026-05-14：v0.2.2 发布验证

- 标签：`v0.2.2`
- Actions：
  - `iOS AltStore Release` 成功，run id：`25848183155`
  - `Android Release APK` 成功，run id：`25848183146`
- Release：`https://github.com/uucz/NiceView/releases/tag/v0.2.2`
- AltStore 源：`https://uucz.github.io/NiceView/source.json`
- IPA：`https://github.com/uucz/NiceView/releases/download/v0.2.2/niceview-unsigned.ipa`
- 验证结果：
  - `source.json` 已发布为 `0.2.2+1`，下载地址指向 `v0.2.2/niceview-unsigned.ipa`。
  - `source.json` 已声明 `NSPhotoLibraryAddUsageDescription` 与 `NSPhotoLibraryUsageDescription`。
  - Release 资产包含 `niceview-unsigned.ipa` 和 `source.json`；IPA 大小为 `7062007` 字节，和源内 `size` 一致。
  - IPA 下载地址经重定向后返回 HTTP `200`，`content-type` 为 `application/octet-stream`。
- 待验证：用户在 iOS 设备上通过 AltStore 更新到 `v0.2.2` 后，实际点击保存并确认图片进入系统 Photos。
- 维护提醒：GitHub Actions 提示 Node.js 20 action runtime 将在 2026-09-16 移除，后续需要跟踪 `actions/*` 和 `softprops/action-gh-release` 对 Node.js 24 的支持。

## 2026-05-14：v0.2.2 iOS 保存实机失败与修复方向

- 用户实机反馈：
  - “浏览记录”保存提示：`保存失败，图片可能已经不在本机了`。
  - 主页保存提示：`网络连接失败，稍后再试`。
- 判断：
  - AltStore 更新后 iOS 沙盒路径可能变化，历史记录持久化的是绝对路径，需要在读取历史时按当前 `Application Support/history` 路径自愈。
  - 主页保存的网络错误不一定来自网络，`MissingPluginException` 等保存链路异常会落入通用兜底，需要改成明确保存错误。
  - iOS 原生保存不应依赖 `UIImage(data:)` 解码，改为将原始图片字节写入临时文件，再通过 `PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL:)` 写入 Photos。
- 执行策略：先本地修复和记录，不打新 tag、不触发发布 CI；等筛选发现和收藏等计划功能完成后统一跑 CI 与发布。

## 2026-05-14：v0.3.0 功能实现

- 实施范围：
  - 新增 `ImageQuery`、`ImageMeta`、`TagSummary`、`CategorySummary`、`TagPreview`。
  - `VeilApiClient` 接入 `/v1/random/meta`、`/v1/featured-tags`、`/v1/tags`、`/v1/categories`、`/v1/tag/{name}/preview`。
  - 随机图流支持方向、分类、排除标签等 query 参数，并按 `queryKey` 隔离预加载队列。
  - 侧栏加入方向筛选、分类筛选、标签发现、本地标签过滤、标签预览和排除标签。
  - 新增独立收藏缓存 `FavoriteStore`，收藏文件写入 `Application Support/favorites`，不受 30 张历史上限淘汰影响。
  - 历史页增加全部/收藏切换，主图和历史预览均可收藏/取消收藏。
- 发布策略：功能已开发完毕，接下来统一打 `v0.3.0` 标签跑 iOS/Android CI 与 AltStore 发布。
