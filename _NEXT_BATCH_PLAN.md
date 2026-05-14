# 下一批详细实施计划：可发现性与请求稳定

日期：2026-05-14
范围：v0.3.0 之后的第一批开发。目标是让现有能力更容易被用户发现，并修正请求额度模型，使快速浏览、标签预览和未来图集浏览不会误触服务端限制。
边界：本批不做反馈/举报，不做系统分享，不提上游 PR，不打发布 tag；开发完成后再统一跑 CI 和实机回归。
架构决策：见 `_ADR_001_NEXT_BATCH_ARCHITECTURE.md`。

## 1. 当前证据与约束

### 本地代码事实

- 主界面筛选侧栏位于 `RandomImagePage`，当前主要通过左滑或图片舞台左滑打开，没有独立筛选按钮。
- `HistoryGrid` 和 `TagStrip` 都依赖长按触发删除，用户可发现性不足。
- `QuotaState` 目前只有单个 `limit=70 / window=300s`，不能区分随机接口和固定图片接口。
- `RandomImageRepository.fetchRandom` 和 `fetchImageById` 会经过 `_quotaGuardedFetch`。
- `RandomImageRepository.tagPreviewImages` 先请求 `/v1/tag/{name}/preview`，再直接调用 `_apiClient.imageById` 拉 6 张图；这 6 次固定图片请求绕过了 `_quotaGuardedFetch`。
- `QuotaBar` 只展示单一请求额度，无法解释标签预览或未来图集图片加载消耗的是固定图片桶。

### 站点 API 事实

- `/v1/site-config` 当前公告：
  - 随机类接口：`300s / 100 次 / 封 30 分钟`
  - 固定图片接口 `/v1/image/{id}`：`300s / 60 次 / 封 30 分钟`
- 当前站点规模约为 `63765` 图集、`444284` 图片、`117189` 标签、`44` 分类，规模仍在增长。
- `/v1/tags` 支持 `limit` 和 `offset`，返回 `items/total/limit/offset`。
- `/v1/tags?search=Metart`、`?q=Metart`、`?name=Metart` 当前与基础热门列表返回一致，不能假设服务端搜索可用。
- `/v1/galleries` 支持 `limit` 和 `offset`。
- `/v1/gallery/{id}` 的图片分页参数实测为 `image_limit` 和 `image_offset`；普通 `limit/offset` 不改变图片分页。
- `GET /v1/image/{id}` 不支持 HEAD，GET 响应含 `cache-control: public, max-age=3600`、`x-image-id` 和 `content-type`，适合做短期预览缓存。

## 2. 推荐实施顺序

### 3.1A：主界面显式入口和一次性轻引导

目的：让用户不用猜手势也能进入筛选、历史和信息侧栏。

文件边界：
- `lib/features/random_image/presentation/random_image_page.dart`
- `lib/features/random_image/presentation/widgets/image_stage.dart`
- `lib/features/tags/data/local_tag_store.dart` 或新增轻量偏好 store

实施要点：
- 在主界面左上角或右上角增加筛选/菜单图标按钮，调用既有 `_openDrawer()`。
- 保留左滑手势，但按钮成为主要可见入口。
- 首次启动显示一次短引导，内容只覆盖筛选、下一张、保存、收藏、历史，不解释太多概念。
- 引导关闭后写入 `SharedPreferences`，后续不再自动出现。
- 加入基础 `Semantics` 标签，便于后续可访问性验证。

验收：
- 新用户不用滑动手势即可打开侧栏。
- 重启 App 后轻引导不会重复出现。
- 主图缩放时按钮不会干扰缩放和拖拽。
- 现有保存、收藏、下一张位置不被遮挡。

### 3.1B：请求额度模型拆桶

目的：与服务端实际限制对齐，避免标签预览和未来图集浏览误伤用户。

文件边界：
- `lib/features/random_image/domain/quota_state.dart`
- `lib/services/quota_service.dart`
- `lib/features/random_image/presentation/widgets/quota_bar.dart`
- `lib/features/random_image/data/random_image_repository.dart`
- `test/history_image_test.dart` 可继续承载轻量单测，也可拆出 `quota_state_test.dart`

推荐模型：
- 新增 `QuotaBucket`：
  - `random`: 80 次 / 300 秒，本地低于服务端 100 次
  - `image`: 50 次 / 300 秒，本地低于服务端 60 次
- `QuotaState` 从单一事件列表改成两个桶的事件列表与两个冷却时间。
- 旧键 `nice_view.quota_events` 保留迁移：第一次加载时把旧事件迁到 `random` 桶，避免升级后立即丢失保护。
- `tryConsumeRemoteRequest()` 改为 `tryConsume(QuotaBucket bucket)`。
- `startServerLockout()` 改为 `startServerLockout(QuotaBucket bucket)`，服务端公告为封 30 分钟，不再使用 60 秒作为真实冷却假设。
- `QuotaBar` 可先展示两个简短行：随机/元数据、固定图片；复杂详情留到设置页。

接口归类：
- `random(query)`：`random` 桶。
- `randomMeta(query)`：`random` 桶。
- `imageById(id)`：`image` 桶。
- 标签预览里的 6 张固定图：`image` 桶。
- 未来图集页里的图片加载：`image` 桶。

验收：
- 单测覆盖两个桶独立计数、独立恢复、独立冷却。
- 旧单桶数据能迁移，不导致升级后异常。
- 标签预览失败时能提示固定图片额度不足，而不是泛化为网络失败。
- 主界面的下一张仍只受随机桶与预加载状态影响。

### 3.1C：标签预览缓存与局部失败处理

目的：减少重复固定图片请求，让标签预览失败不会污染主界面体验。

文件边界：
- `lib/features/random_image/presentation/widgets/tag_preview_sheet.dart`
- `lib/features/random_image/data/random_image_repository.dart`
- 可新增 `lib/features/random_image/data/tag_preview_cache.dart`

推荐策略：
- 内存缓存优先，TTL 10 分钟。
- 缓存内容包含 tag、imageIds、已落盘的本地临时图片路径、创建时间。
- 预览 sheet 内展示明确错误原因与重试按钮。
- 同一标签短时间重复打开直接复用缓存，不再重复打 `/v1/tag/{name}/preview` 和 6 次 `/v1/image/{id}`。
- 缓存最大条目建议 20 个标签；超出后移除最旧条目并尽力删除临时文件。

验收：
- 同一标签连续打开两次，第二次不重复消耗固定图片额度。
- 缓存过期后会重新拉取。
- 预览失败只显示在 sheet 内，不把主界面当前图清空。
- 关闭 sheet 时没有未捕获异常。

### 3.1D：删除与管理入口可见化

目的：保留长按快捷方式，同时给普通用户显式管理入口。

文件边界：
- `lib/features/random_image/presentation/widgets/tag_strip.dart`
- `lib/features/random_image/presentation/widgets/side_info_drawer.dart`
- `lib/features/random_image/presentation/widgets/history_grid.dart`
- `lib/features/random_image/presentation/history_page.dart`

实施要点：
- 我的标签 chip 增加更多按钮或显式删除图标，长按保留。
- 历史/收藏网格增加每张图右上角更多按钮，触发删除确认。
- 空状态文案按当前 tab 区分“暂无历史”和“暂无收藏”。
- 所有删除入口复用既有确认 dialog，不新增删除语义。

验收：
- 用户不用长按也能删除标签、历史和收藏。
- 收藏删除仍不影响历史，历史删除仍不影响收藏。
- 图格更多按钮不遮挡收藏标记。

## 3. 阶段二前置探索问题

完整标签浏览页开发前，需要先回答这些问题：

1. `/v1/tags` 是否支持服务端搜索参数。
   - 当前证据确认 `search/q/name` 参数会被忽略，先按“不支持服务端搜索”设计。
   - 若无服务端搜索，移动端应分页加载热门序列并本地过滤已加载数据，同时保留手动输入标签。

2. 标签页默认展示多少条。
   - 建议首屏 50，滚动每次加载 50。
   - 不照搬 Web 端 `limit=20000`，移动端弱网和内存成本更高。

3. “默认偏好”和“本次筛选”如何区分。
   - 建议侧栏顶部展示当前筛选。
   - 设置页管理默认方向、默认分类和常驻排除标签。
   - 本次临时筛选不立即写入默认偏好。

4. 当前图片标签动作是否进入本批。
   - 若阶段一工作量可控，可把“使用 / 预览 / 排除”作为 3.1E。
   - 若额度拆桶改动较大，应推迟到阶段二，避免一次改太多交互。

## 4. 阶段三前置探索问题

图集延续探索开发前，需要先确认：

1. 图集详情分页参数使用 `image_limit/image_offset`。
   - 已实测 `image_limit=5&image_offset=20` 返回 sort_order 21-25。
   - 普通 `limit/offset` 不改变图片分页。

2. 图集图片是否有宽高和方向。
   - 当前样本多数为 `null`，UI 不能依赖尺寸做排版。
   - 需要用固定比例网格或先拉图片后再展示。

3. 外部字段处理。
   - `source_page_url` 和 `download_links` 存在，但本 App 初期不展示。
   - 只使用标题、分类、标签、图片 ID 和分页。

4. 图集页如何消耗额度。
   - 图集详情 JSON 本身可算随机/元数据桶或独立轻量数据桶；当前先归入随机桶。
   - 图集图片 `/v1/image/{id}` 必须归入固定图片桶。

## 5. 测试与验证计划

开发期本地验证：
- `git diff --check`
- `python3 -m unittest discover -s scripts/tests`
- `bash -n scripts/build_unsigned_ios_ipa.sh`
- 可用时运行 Flutter 单测和 analyze；本机没有 Flutter 时依赖后续 GitHub Actions。

功能验收：
- 新入口：主界面按钮打开侧栏，左滑仍可用。
- 引导：首次出现一次，重启不重复。
- 额度：随机桶和固定图片桶独立恢复，预览消耗固定图片桶。
- 预览：同一标签重复打开复用缓存；失败可局部重试。
- 删除：标签、历史、收藏均有显式删除入口。

发布验收：
- 本批功能完成后再统一打 tag。
- iOS AltStore Release 与 Android Release APK 都通过。
- `source.json` 版本、下载地址和 IPA size 一致。
- iOS 实机确认：侧栏入口、标签预览、保存 Photos、收藏持久化均不回退。

## 6. 回滚方案

- 如果显式入口或轻引导造成 UI 干扰：可单独 revert 对 `random_image_page.dart` 和引导偏好 store 的改动。
- 如果额度拆桶造成异常：保留旧键迁移逻辑，并可回滚到单桶 `QuotaState`；回滚后应清理或忽略新桶键。
- 如果预览缓存造成文件残留：禁用缓存读取，保留直接拉取路径，并在设置/启动时清理预览缓存目录。
- 如果显式删除入口造成误触：保留更多按钮但增加确认强度；长按路径不需要回滚。

## 7. 建议开工切片

1. 先做 3.1B 额度拆桶。它是标签预览缓存和未来图集页的可靠性底座。
2. 再做 3.1C 标签预览缓存与局部错误。
3. 再做 3.1A 显式入口和轻引导。
4. 最后做 3.1D 删除入口可见化。

这个顺序让底层可靠性先稳定，再改用户可见交互；每个切片都能独立测试和回滚。
