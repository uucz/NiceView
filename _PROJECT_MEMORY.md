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

## 2026-05-14：v0.3.0 发布验证

- 标签：`v0.3.0`
- 提交：`c6e8ea7 feat: add discovery filters and favorites`
- Actions：
  - `iOS AltStore Release` 成功，run id：`25850852113`
  - `Android Release APK` 成功，run id：`25850852103`
- Release：`https://github.com/uucz/NiceView/releases/tag/v0.3.0`
- AltStore 源：`https://uucz.github.io/NiceView/source.json`
- IPA：`https://github.com/uucz/NiceView/releases/download/v0.3.0/niceview-unsigned.ipa`
- 验证结果：
  - iOS workflow 中 `Analyze and test`、IPA 构建、source.json 生成、Release 上传、Pages 部署全部成功。
  - Android workflow 中 `Analyze`、`Test`、release APK 构建和 artifact 上传全部成功。
  - `source.json` 已发布为 `0.3.0+1`，下载地址指向 `v0.3.0/niceview-unsigned.ipa`。
  - Release 资产包含 `niceview-unsigned.ipa` 和 `source.json`；IPA 大小为 `7107686` 字节，和源内 `size` 一致。
  - IPA 下载地址经重定向后返回 HTTP `200`，`content-type` 为 `application/octet-stream`。
- 待验证：用户在 iOS 设备通过 AltStore 更新 `v0.3.0` 后，实测系统相册保存、标签发现/方向筛选、收藏。

## 2026-05-14：v0.3.0 实机验收

- 用户已在 iOS 设备实机测试 `v0.3.0`。
- 验收结果：
  - 主页保存图片可以进入系统 Photos。
  - 浏览记录中保存图片可以进入系统 Photos。
  - 方向、分类、标签预览可用。
  - 收藏在 App 重启后仍保留。
- 结论：本阶段核心开发计划已完成并通过实机验收。
- PR 状态：可以进入是否向上游贡献的评估阶段；当前暂不发起 PR。

## 2026-05-14：v0.3.0 后用户视角二次深挖

- 背景：用户要求继续站在真实用户角度深度探索“已有能力”和“用户需要但尚未做的部分”。
- 工具与证据：
  - 继续使用本地 `_PROJECT_*` 文件记录计划、风险和证据。
  - 使用本地 `rg`、`sed` 检查 v0.3.0 代码入口、侧栏、标签发现、图集缺口和额度路径。
  - 使用 `curl -L` 重新验证 `https://veil.ortlinde.com/v1/site-config`、`/v1/tags`、`/v1/galleries`、`/v1/gallery/{id}`、`/tags` 和 `/static/site.js`。
- 关键发现：
  - v0.3.0 已完成保存、筛选发现和收藏，但侧栏主要依赖左滑，历史、筛选、额度和标签发现仍容易被新用户忽略。
  - 站点当前规模约为 `63763` 图集、`444108` 图片、`117187` 标签和 `44` 分类；App 目前只加载前 24 个热门标签和少量精选标签，标签探索仍偏浅。
  - 站点固定图片接口 `/v1/image/{id}` 有独立 `300s / 60 次` 限制，当前标签预览中的固定图片加载未进入本地额度模型，后续需要拆分额度桶。
  - `/v1/galleries` 与 `/v1/gallery/{id}` 可支持图集延续探索，但图集详情包含外部来源和下载链接，移动端初期不应暴露外部下载入口。
  - 用户长期需要默认方向、默认分类、常驻排除标签、缓存清理、历史上限和可访问性补强。
- 产物：
  - 重写 `_PRODUCT_REVIEW.md` 为 v0.3.0 后产品缺口分析。
  - 重写 `_IMPLEMENTATION_ROADMAP.md` 为下一阶段实施路线图。
  - 更新 `_PROJECT_PLAN.md`、`_PROJECT_RISKS.csv`、`_PROJECT_EVIDENCE.csv`。
- 决策：
  - 下一批优先做“可发现性与请求稳定”。
  - 反馈/举报入口和系统分享继续不做。
  - 上游 PR 继续暂不发起。

## 2026-05-14：下一批详细实施计划

- 背景：用户要求进一步规划探索，需要把路线图压到可实施切片。
- 产物：新增 `_NEXT_BATCH_PLAN.md`。
- 代码边界确认：
  - `RandomImagePage` 当前依靠左滑打开侧栏，缺少显式筛选入口。
  - `QuotaState` 当前是单桶 `70 / 300s`，无法区分随机接口和固定图片接口。
  - `tagPreviewImages` 中的 6 张固定图片直接调用 `_apiClient.imageById`，未经过 `_quotaGuardedFetch`。
  - `HistoryGrid` 和 `TagStrip` 删除依赖长按，普通用户不容易发现。
- API 边界确认：
  - `/v1/site-config` 最新样本显示约 `63765` 图集、`444284` 图片、`117189` 标签。
  - `/v1/image/{id}` 限流策略是 `300s / 60 次 / 封 30 分钟`。
  - `/v1/gallery/{id}` 的图片分页参数实测为 `image_limit` 和 `image_offset`，不是普通 `limit/offset`。
- 下一批推荐顺序：
  1. 先做双桶额度模型。
  2. 再做标签预览缓存和局部失败处理。
  3. 再做显式侧栏入口和一次性轻引导。
  4. 最后做标签、历史、收藏的显式删除入口。
- 决策：本批仍不做反馈/举报、系统分享和上游 PR；开发完成后再统一跑 CI 与发布回归。

## 2026-05-14：ADR-001 下一批架构决策

- 产物：新增 `_ADR_001_NEXT_BATCH_ARCHITECTURE.md`。
- 追加验证：
  - `/v1/tags?search=Metart`、`?q=Metart`、`?name=Metart` 与基础 `?limit=5` 返回一致，因此当前标签浏览页不能假设服务端搜索可用。
  - `HEAD /v1/image/30834` 返回 405，固定图片只能按 GET 验证。
  - `GET /v1/image/30834` 返回 `cache-control: public, max-age=3600`、`x-image-id: 30834`、`content-type: image/jpeg`，适合做短期标签预览缓存。
- 决策：
  - 采用双桶额度：`random=80/300s`、`image=50/300s`。
  - 服务端冷却按公告的 30 分钟建模，不继续把 60 秒当作真实封禁窗口。
  - 旧单桶 SharedPreferences 键迁入 random 桶，新键不覆盖旧键，便于回滚。
  - 标签预览缓存第一版使用内存 TTL 10 分钟、最多 20 个标签。
  - 标签浏览第一版不声称全量搜索，只筛选已加载标签并保留手动输入标签能力。

## 2026-05-14：v0.4.0 可发现性与请求稳定功能开发

- 实施范围：
  - 主界面增加显式筛选/信息按钮和一次性轻引导。
  - 请求额度拆成 `random=80/300s` 与 `image=50/300s` 两个桶，服务端冷却按桶记录 30 分钟；旧单桶记录迁移到 random 桶。
  - 标签预览增加 10 分钟内存缓存、局部重试和固定图片额度控制。
  - 新增完整标签浏览页：分页加载、本地筛选、按热度/名称排序、预览、使用、排除、加入我的标签。
  - 新增默认偏好：保存/清除默认方向、默认分类和常驻排除标签。
  - 当前图片标签 chip 改为动作入口，支持使用、预览、排除、加入我的标签。
  - 新增图集列表与图集详情页，使用 `image_limit/image_offset` 分页，同图集图片通过固定图片额度加载；不展示外部来源页、下载链接和附件。
  - 新增设置页：历史上限、历史/收藏/预加载/临时缓存占用、清理临时缓存、清空历史、清空收藏、清除默认偏好。
  - 离线/失败状态增加历史和收藏入口；核心按钮补 Semantics；关键操作加入 iOS haptic。
  - iOS 构建脚本注入 LaunchScreen storyboard，并用标准库生成 AppIcon PNG 资产。
- 版本：`pubspec.yaml` 已更新到 `0.4.0+1`，AltStore 描述和 README 已同步。
- 本地验证：
  - `git diff --check` 通过。
  - `python3 -m unittest discover -s scripts/tests` 通过。
  - `bash -n scripts/build_unsigned_ios_ipa.sh` 通过。
  - 本机缺少 `flutter` 与 `dart`，Flutter analyze/test/build 需在 CI 或安装工具链后执行。
- 回滚方式：
  - 若额度拆桶异常，可回滚 `quota_state.dart`、`quota_service.dart` 和 repository 中的桶调用，旧键仍保留。
  - 若新页面有布局或性能问题，可单独隐藏侧栏入口并保留底层 API/model。
  - 若 iOS 图标生成影响构建，可删除 build script 中 AppIcon 生成块和 LaunchScreen 拷贝行，恢复 Flutter 默认模板。

## 2026-05-14：上游 PR 评估

- 当前结论：暂不向上游发 PR。
- 原因：
  - 本 fork 已包含 AltStore 发布链、iOS Photos 原生保存、请求额度模型、标签/图集/设置等多条产品线，直接提交一个大 PR 不利于原作者审查。
  - AltStore source、GitHub Pages、fork 仓库名和发布策略明显偏 fork 运维，不适合作为上游通用改动。
  - v0.4.0 还需要 Flutter analyze/test/build、iOS 实机和 Android 回归确认。
- 后续若贡献，建议拆分：
  1. iOS Photos 保存修复与权限声明。
  2. 请求额度拆桶与标签预览缓存。
  3. 显式入口、删除入口和可访问性补强。
  4. 标签浏览、图集浏览和设置页作为可选产品功能单独讨论。

## 2026-05-15：v0.4.0 发布验证

- 标签：`v0.4.0`
- 代码提交：`e4a5c57 fix: satisfy gallery detail analyzer`
- 首次 tag 触发的 CI 因 `flutter analyze` 中 `unnecessary_brace_in_string_interps` 失败；已修复并将 `v0.4.0` 指向修复提交重新触发。
- Actions：
  - `iOS AltStore Release` 成功，run id：`25893835255`
  - `Android Release APK` 成功，run id：`25893835254`
- Release：`https://github.com/uucz/NiceView/releases/tag/v0.4.0`
- AltStore 源：`https://uucz.github.io/NiceView/source.json`
- IPA：`https://github.com/uucz/NiceView/releases/download/v0.4.0/niceview-unsigned.ipa`
- 验证结果：
  - iOS workflow 中 `Analyze and test`、IPA 构建、source.json 生成、Release 上传、Pages 部署全部成功。
  - Android workflow 中 `Analyze`、`Test`、release APK 构建和 artifact 上传全部成功。
  - `source.json` 已发布为 `0.4.0+1`，下载地址指向 `v0.4.0/niceview-unsigned.ipa`。
  - Release 资产包含 `niceview-unsigned.ipa` 和 `source.json`；IPA 大小为 `7253767` 字节，和源内 `size` 一致。
  - IPA 下载地址经重定向后返回 HTTP `200`，`content-type` 为 `application/octet-stream`。
- 待验证：用户在 iOS 设备通过 AltStore 更新 `v0.4.0` 后，实测侧栏入口、首次引导、标签浏览、图集浏览、设置页、默认偏好、保存 Photos 和收藏持久化。
