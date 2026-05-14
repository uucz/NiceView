# ADR-001: 下一批可发现性与请求稳定架构

日期：2026-05-14
状态：通过
适用范围：v0.3.0 后第一批开发，包括双桶额度、标签预览缓存、显式入口、轻引导、显式删除入口。
非目标：反馈/举报、系统分享、上游 PR、发布 tag。

## 背景

v0.3.0 已经完成 iOS Photos 保存、标签/方向/分类发现和收藏，但继续使用时存在三个真实风险：

1. 用户看不到已有能力：筛选侧栏主要靠左滑，历史和删除操作也有隐性手势。
2. 请求额度模型不匹配：站点固定图片接口 `/v1/image/{id}` 是独立 `300s / 60 次` 限制，而 App 当前只有一个 `70 / 300s` 桶。
3. 标签预览会放大固定图片请求：一次标签预览会请求 6 张固定图，并且当前这些请求绕过了 `_quotaGuardedFetch`。

最新验证：
- `/v1/site-config` 公告随机类接口 `300s / 100 次`，固定图片接口 `300s / 60 次`。
- `/v1/tags?search=Metart`、`?q=Metart`、`?name=Metart` 与基础 `?limit=5` 返回一致，当前不能假设服务端标签搜索可用。
- `GET /v1/image/30834` 返回 `cache-control: public, max-age=3600`、`x-image-id: 30834`、`content-type: image/jpeg`，适合短期预览缓存。
- `/v1/gallery/{id}` 图片分页参数是 `image_limit/image_offset`。

## 备选方案

| option | maturity | performance | security | compatibility | score | notes | evidences |
| --- | --- | --- | --- | --- | --- | --- | --- |
| 双桶额度 + 预览缓存 + 显式入口分批实施 | 高 | 高 | 高 | 高 | 9 | 对齐服务端限制，改动可测试可回滚 | E031,E034,E036,E037 |
| 只做显式入口，不改额度 | 高 | 中 | 中 | 高 | 5 | 用户更容易使用，但更容易触发固定图片限流 | E029,E031 |
| 只做预览缓存，不拆额度 | 中 | 中 | 中 | 中 | 6 | 能减少重复请求，但首次预览和图集页仍无法解释额度 | E029,E037 |
| 引入全局网络限速队列 | 中 | 中 | 高 | 中 | 6 | 可统一节流，但会让随机浏览、预览、图集互相阻塞 | E031 |
| 标签页一次性拉取大量标签 | 中 | 中 | 高 | 中 | 5 | Web 端可行，移动端弱网和内存风险偏高 | E032 |

## 决策

采用“双桶额度 + 标签预览缓存 + 显式入口分批实施”。

实施顺序：
1. 双桶额度模型。
2. 标签预览缓存与局部失败处理。
3. 显式侧栏入口与一次性轻引导。
4. 标签、历史、收藏的显式删除入口。

## 设计细节

### 额度模型

新增枚举：

```dart
enum QuotaBucket {
  random,
  image,
}
```

推荐常量：

```dart
const randomLimit = 80;
const imageLimit = 50;
const quotaWindow = Duration(seconds: 300);
const serverLockout = Duration(minutes: 30);
```

说明：
- `random=80` 低于服务端随机类 `100/300s`，保留预加载安全余量。
- `image=50` 低于服务端固定图片 `60/300s`，为标签预览、历史恢复和未来图集页保留余量。
- 服务端公告是封 30 分钟；当前 App 显示 60 秒冷却不足以表达真实风险，后续应按桶记录 30 分钟冷却，文案可简化但不能误导。

`QuotaState` 建议字段：

```dart
class QuotaWindowState {
  const QuotaWindowState({
    required this.limit,
    required this.window,
    required this.events,
    this.serverLockoutUntil,
  });
}

class QuotaState {
  const QuotaState({
    required this.random,
    required this.image,
  });
}
```

关键 API：

```dart
bool canAcquire(QuotaBucket bucket);
int remaining(QuotaBucket bucket);
Duration? timeUntilNextAvailable(QuotaBucket bucket);
Duration serverLockoutRemaining(QuotaBucket bucket);
QuotaState consume(QuotaBucket bucket, DateTime now);
QuotaState startServerLockout(QuotaBucket bucket, DateTime until);
QuotaState pruned(DateTime now);
```

### SharedPreferences 迁移

旧键：
- `nice_view.quota_events`
- `nice_view.server_lockout_until`

新键：
- `nice_view.quota.random_events`
- `nice_view.quota.image_events`
- `nice_view.quota.random_lockout_until`
- `nice_view.quota.image_lockout_until`
- `nice_view.quota.v2_migrated`

迁移策略：
- 如果 `v2_migrated != true`，把旧 `quota_events` 迁入 random 桶。
- 把旧 `server_lockout_until` 迁入 random 桶。
- 不删除旧键，只写 `v2_migrated=true`，便于回滚到旧版本时仍有数据。
- 如果新键已存在，不覆盖新键。

### Repository 请求归类

推荐改造 `RandomImageRepository`：

```dart
Future<RandomImage> fetchRandom({ImageQuery query = const ImageQuery()}) {
  return _quotaGuardedFetch(
    QuotaBucket.random,
    () => _fetchRandomResponse(query),
    sourceTag: query.tag,
    queryKey: query.cacheKey,
  );
}

Future<RandomImage> fetchImageById(int imageId, {...}) {
  return _quotaGuardedFetch(
    QuotaBucket.image,
    () => _apiClient.imageById(imageId),
    ...
  );
}
```

`_fetchRandomResponse` 的注意点：
- 如果 `query.usesMetaEndpoint == true`，内部会先 `randomMeta` 再 `imageById(meta.id)`。
- 用户视角这是一次“复杂随机取图”，但技术上消耗一个随机请求和一个固定图片请求。
- 推荐做法：`randomMeta` 消耗 random 桶，随后固定图片下载消耗 image 桶。
- 为避免 `_quotaGuardedFetch(random)` 包裹内部 `image` 桶失败时状态不清楚，可将复杂随机拆成显式两步：
  - 先 `tryConsume(random)` 请求 meta。
  - 再 `fetchImageById(meta.id)` 走 image 桶。

### Controller 调整点

当前 `RandomImageController` 使用：
- `quota.canAcquire`
- `quota.remaining`
- `quota.isServerLocked`
- `quota.timeUntilNextAvailable`

双桶后推荐：
- 主界面下一张和预加载判断使用 random 桶。
- 复杂筛选如果需要固定图片桶，`fetchRandom` 内部再检查 image 桶，错误文案说明“固定图片额度不足”。
- `_quotaRecoveryMessage()` 增加可选 bucket 参数。
- `ServerLockoutOverlay` 应展示任一桶处于服务端冷却，文案尽量短。
- `QuotaBar` 展示两个桶：随机/元数据、图片预览。

### 标签预览缓存

新增缓存服务：

```dart
class TagPreviewCache {
  TagPreviewCache({
    this.ttl = const Duration(minutes: 10),
    this.maxEntries = 20,
  });

  TagPreviewCacheEntry? read(String tag);
  Future<void> write(String tag, List<RandomImage> images);
  Future<void> evictExpired();
  Future<void> clear();
}
```

缓存位置：
- 第一版使用内存缓存即可，避免复杂持久化生命周期。
- 若后续要跨启动缓存，再写入 `Application Support/tag_preview`，并在设置页提供清理入口。

缓存命中条件：
- tag 规范化后完全相同。
- entry 未超过 TTL。
- 本地文件仍存在。
- 图片数量不为 0。

淘汰策略：
- 超过 `maxEntries` 淘汰最旧 tag。
- 淘汰时尽力删除只属于预览缓存的临时文件。
- 不删除历史或收藏缓存文件。

### 标签浏览策略

由于当前 `/v1/tags` 未验证出服务端搜索，标签浏览页第一版采用：
- 首屏拉取 50 条。
- 向下滚动每次再拉 50 条。
- 搜索框只过滤“已加载标签”。
- 用户可以继续手动输入任意标签。
- UI 文案不要声称“搜索全部标签”，只称“筛选已加载标签”或“输入标签名”。

如果未来验证出服务端搜索，再把搜索切到服务端，不改变用户入口。

### 图集探索策略

图集页第一版只使用：
- `id`
- `title`
- `category`
- `image_count`
- `tags`
- `images[].id`
- `images[].sort_order`
- `images_pagination`

明确忽略：
- `source_page_url`
- `download_links`
- `attachments`

图片分页：
- 使用 `image_limit` 和 `image_offset`。
- 默认 `image_limit=30`。
- 图片网格不依赖 width/height，因为当前样本多为 null。

## 测试计划

单元测试：
- `QuotaState` 两个桶独立计数。
- `QuotaState` 两个桶独立恢复时间。
- `QuotaState` 两个桶独立服务端冷却。
- 旧 `nice_view.quota_events` 迁移到 random 桶。
- `QuotaBar` 至少不因双桶 state 构建失败。
- `TagPreviewCache` 命中、过期、文件缺失、最大条目淘汰。
- `ImageQuery` 既有测试保持通过。
- `GalleryDetail` 解析 `image_limit/image_offset` 响应样本。

手工验证：
- 快速下一张时随机桶减少。
- 打开标签预览时图片桶减少。
- 同一标签短时间重复打开不再减少图片桶。
- 图片桶耗尽时，主界面下一张仍能在随机桶有额度时尝试，但需要固定图的复杂筛选会提示固定图片额度不足。
- 侧栏入口、长按手势和显式删除入口都可用。

## 后果

正面影响：
- 请求模型与服务端策略对齐。
- 标签预览和未来图集页有稳定基础。
- 用户更容易发现筛选、历史和管理入口。

负面影响：
- `QuotaState` 与 `QuotaBar` 改动面较大。
- 双桶文案更复杂，需要避免让用户感觉负担变重。
- 预览缓存需要管理临时文件生命周期。

## 回滚方案

- 双桶额度：保留旧 SharedPreferences 键，必要时 revert 到单桶模型并忽略新键。
- 预览缓存：关闭缓存读取，回到直接请求；保留清理函数删除预览缓存目录。
- 显式入口：revert UI 按钮和轻引导 store，不影响左滑入口。
- 显式删除：revert更多按钮，长按删除路径仍保留。

## 引用

- `_NEXT_BATCH_PLAN.md`
- `_PROJECT_EVIDENCE.csv` E031-E037
- `lib/features/random_image/data/random_image_repository.dart`
- `lib/features/random_image/domain/quota_state.dart`
- `lib/features/random_image/presentation/widgets/tag_preview_sheet.dart`
