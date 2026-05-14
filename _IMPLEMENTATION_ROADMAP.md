# Nice View 后续实施路线图

日期：2026-05-14  
目标：把 v0.2.1 的“可安装随机浏览客户端”推进到“可长期使用、可筛选、可收藏”的版本。PR 暂不推进，等 fork 开发完成后再统一评估。

## 0. 证据摘要

已验证 API：

| 能力 | 接口 | 当前 App 使用 | 规划 |
| --- | --- | --- | --- |
| 随机图片流 | `GET /v1/random` | 已使用 | 继续保留 |
| 固定图片流 | `GET /v1/image/{id}` | 已使用 | 用于预览和缓存 |
| 元数据 | `GET /v1/random/meta` | 未使用 | 当前图详情、方向、图集、标签 |
| 标签列表 | `GET /v1/tags` | 未使用 | 标签搜索、标签发现 |
| 精选标签 | `GET /v1/featured-tags` | 未使用 | 首屏推荐标签 |
| 标签预览 | `GET /v1/tag/{name}/preview` | 未使用 | 标签选择前预览 |
| 分类 | `GET /v1/categories` | 未使用 | 分类筛选 |
| 筛选参数 | `orientation/category/include_tag/exclude_tag/include_category/exclude_category` | 仅 `tag` | 分阶段接入 |
| 反馈 | `POST /v1/feedback` | 未使用 | 暂不接入 |
| 站点配置 | `GET /v1/site-config` | 未使用 | 展示资源规模、公告、封禁策略 |

已验证接口形态：

- `/v1/site-config` 返回规模：约 `63584` 图集、`442875` 图片、`116821+` 标签、`44` 分类，并包含封禁策略公告。
- `/v1/featured-tags` 返回 `items[]` 与 `tags_total`。
- `/v1/categories` 当前返回精选分类：`Cosplay`、`Japan`、`Korean`。
- `/v1/random/meta?orientation=landscape` 可返回方向筛选后的元数据。
- `/v1/random/meta?category=Cosplay&exclude_tag=AI%20Generated` 可组合筛选。
- `/v1/tag/原神/preview` 返回 6 个 `image_ids`。
- `/v1/feedback` body 为 `{ category, subject, message, contact }`，但当前阶段暂不接入。

## 1. 阶段一：修复 iOS 保存语义

### 用户目标

用户点“保存”后，图片应该真的出现在 iOS 系统相册，而不是只写入 App 沙盒。

### 改造点

1. `lib/services/download_service.dart`
   - 增加 iOS 分支，调用 MethodChannel。
   - 返回值区分 `photos://saved`、文件路径或平台 URI。

2. iOS 原生层
   - 当前仓库不提交 `ios/`，CI 通过 `scripts/build_unsigned_ios_ipa.sh` 临时生成。
   - 短期方案：脚本在 `flutter create --platforms=ios` 后注入 Swift AppDelegate 保存逻辑与 Info.plist 权限描述。
   - 中期方案：提交标准 `ios/` 目录，降低脚本生成复杂度，便于上游 PR 审阅。

3. `altstore/metadata.json`
   - 增加照片添加权限说明，确保 AltStore 元数据与 IPA 权限一致。

4. UI 文案
   - 保存到系统相册成功：`已保存到系统相册`
   - 保存到 App 文件成功：`已保存到应用文件`
   - 失败时提示具体原因。

### 验收标准

- iOS AltStore 安装后，主界面保存当前图片可在 Photos 中看到。
- 历史预览页保存也可在 Photos 中看到。
- AltStore 安装不报权限元数据不匹配。
- Android 保存行为不回退。

## 2. 阶段二：抽象查询模型和 API Client

### 用户目标

后续所有筛选都能稳定组合，不让 UI 到处拼 URL 字符串。

### 改造点

1. 新增 `ImageQuery`
   - `tag`
   - `orientation`
   - `category`
   - `includeTags`
   - `excludeTags`
   - `includeCategories`
   - `excludeCategories`

2. 扩展 `VeilApiClient`
   - `random(query)`
   - `randomMeta(query)`
   - `tags({limit, offset, search})`
   - `featuredTags()`
   - `categories()`
   - `tagPreview(name)`
   - 暂不接入 `submitFeedback`

3. 扩展 domain models
   - `ImageMeta`
   - `TagSummary`
   - `CategorySummary`

4. 测试
   - query 参数编码测试，尤其中文标签、逗号多值、空值剔除。
   - JSON 解析测试。

### 验收标准

- 所有 API 方法有单元测试覆盖。
- 旧的单标签随机行为保持不变。
- 不引入 UI 行为变化。

## 3. 阶段三：标签发现与方向筛选

### 用户目标

用户不需要猜标签名；能先看推荐、搜索，再决定筛选。

### 设计建议

1. 侧边栏拆成两个区域：
   - 当前筛选：全部 / 方向 / 分类 / 包含标签 / 排除标签。
   - 探索：精选标签、搜索标签、分类。

2. 标签选择交互：
   - 点击标签：按标签筛选。
   - 长按或更多按钮：预览该标签 6 张图。
   - 标签预览网格使用 `/v1/tag/{name}/preview` + `/v1/image/{id}`。

3. 方向筛选：
   - segmented control：不限 / 竖图 / 横图。
   - 切换后清空预加载队列并加载新图。

4. 分类筛选：
   - 初期只接入 `/v1/categories` 返回的精选分类。

### 验收标准

- 新用户首次打开侧边栏能看到可选标签和分类。
- 选择方向后返回图片 orientation 与选项一致。
- 标签预览失败时有重试或错误状态。
- 切换筛选不会展示旧筛选的预加载图片。

## 4. 阶段四：收藏

### 用户目标

用户能明确留下喜欢的图片，不被 30 张历史上限淘汰。

### 改造点

1. `HistoryImage` 增加收藏状态或新增 `FavoriteImage` 存储模型。
2. 主图和历史预览增加收藏按钮。
3. 历史页支持全部 / 收藏筛选。
4. 历史淘汰时不删除收藏文件。
5. 删除收藏需要明确二次确认。

### 验收标准

- 浏览 30 张以上后，收藏图片仍保留。
- 收藏图片在重启后仍能打开。
- 删除历史不会误删收藏。
- 删除收藏时用户明确知道会移除本地缓存文件。

## 5. 阶段五：整理发布与回归

### 用户目标

每一批功能完成后能稳定发布，不回退 AltStore、Android 或基础浏览体验。

### 改造点

1. 每个阶段合并前跑 Flutter analyze/test。
2. 每个用户可见阶段打 tag，走 Android 与 iOS/AltStore workflow。
3. 实机检查：
   - iOS AltStore 更新。
   - iOS 保存相册。
   - Android 随机浏览和保存。
   - 标签筛选与历史。
4. 更新 `_PROJECT_*` 记录。

### 验收标准

- Release 含 Android APK、iOS IPA 和 source.json。
- `source.json` 可访问且 size 与 IPA 一致。
- 实机确认新版本能安装/更新。

## 6. 上游 PR 暂停策略

当前不向上游提 PR。等 fork 功能完成并稳定后，再统一评估是否拆分贡献。

未来如需提 PR，推荐顺序：

1. Issue / Discussion：说明 fork 已验证 iOS + AltStore，询问维护者是否愿意接收。
2. PR 1：上游中立的 iOS / AltStore 发布链。
3. PR 2：iOS 保存到系统相册。
4. PR 3：API query / models 重构，不改变 UI。
5. PR 4：标签发现 + 方向筛选。
6. PR 5：收藏。

### 上游 PR 必须清理

- 删除 `_PROJECT_*` 与 `_PRODUCT_REVIEW.md`、`_IMPLEMENTATION_ROADMAP.md`。
- 移除 `uucz.github.io/NiceView` 硬编码。
- `developerName` 改回原作者或中性表述。
- README 不应把 fork 的 AltStore 源当成上游官方源。
- Pages 地址用 `${{ github.repository_owner }}` 自动推导，文档写启用步骤。

## 7. 风险登记

| id | 风险 | 影响 | 缓解 |
| --- | --- | --- | --- |
| R101 | iOS Photos 权限与 AltStore 元数据不一致 | 安装或运行失败 | 同步 Info.plist 和 `altstore/metadata.json`，实机验证 |
| R102 | API 筛选能力强，但 UI 一次性暴露太多 | 用户困惑 | 分阶段上线，先精选标签和方向 |
| R103 | 标签总量超过 11 万，直接全量加载会卡顿 | 性能问题 | 分页、搜索、缓存精选标签 |
| R104 | API 规划中存在反馈接口但当前不接入 | 需求边界漂移 | 路线图明确标记暂不接入，避免开发偏航 |
| R105 | 收藏与历史文件生命周期混乱 | 用户丢图 | 明确收藏不自动淘汰，删除动作二次确认 |
| R106 | 上游不接受发布链 PR | 协作失败 | 先开 issue，PR 拆小，保持 fork 可独立维护 |

## 8. 技术选型矩阵

| option | maturity | performance | compatibility | score | notes |
| --- | --- | --- | --- | --- | --- |
| 脚本注入 iOS 原生代码 | 中 | 高 | 中 | 7 | 改动少，但脚本复杂，上游审阅成本高 |
| 提交标准 `ios/` 目录 | 高 | 高 | 高 | 9 | 最符合 Flutter 项目常规，便于原生权限和 PR |
| 引入第三方相册保存插件 | 中 | 高 | 中 | 6 | 快，但增加依赖和 AltStore 权限不确定性 |
| 自写 MethodChannel 保存相册 | 高 | 高 | 高 | 8 | 依赖少、可控，需维护 iOS/Android 两端 |

推荐：提交标准 `ios/` 目录 + 自写 MethodChannel。若短期只服务 fork，可先脚本注入验证，再整理成上游 PR 形态。

## 9. 下一步执行建议

优先做阶段一。原因：

1. 它修复真实用户已安装后的核心信任问题。
2. 改动范围相对集中。
3. 它是后续所有 iOS 用户体验的质量底座。
4. 它会迫使我们决定是否提交 `ios/` 目录，这影响后续所有 iOS 功能维护方式。
