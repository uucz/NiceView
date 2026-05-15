import 'dart:async';
import 'dart:collection';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/app_exceptions.dart';
import '../../../services/download_service.dart';
import '../../../services/quota_service.dart';
import '../../tags/data/local_tag_store.dart';
import '../data/favorite_store.dart';
import '../data/history_store.dart';
import '../data/random_image_repository.dart';
import '../data/user_preferences_store.dart';
import '../domain/history_image.dart';
import '../domain/image_query.dart';
import '../domain/quota_state.dart';
import '../domain/random_image.dart';

final randomImageControllerProvider =
    StateNotifierProvider<RandomImageController, RandomImageViewState>((ref) {
  final controller = RandomImageController(
    repository: ref.watch(randomImageRepositoryProvider),
    tagStore: ref.watch(localTagStoreProvider),
    historyStore: ref.watch(historyStoreProvider),
    favoriteStore: ref.watch(favoriteStoreProvider),
    preferencesStore: ref.watch(userPreferencesStoreProvider),
    downloadService: ref.watch(downloadServiceProvider),
    quotaController: ref.read(quotaControllerProvider.notifier),
    readQuotaState: () => ref.read(quotaControllerProvider),
  );
  unawaited(controller.initialize());
  return controller;
});

const _unset = Object();
const _defaultPreloadTarget = 6;

class RandomImageViewState {
  const RandomImageViewState({
    required this.preloadQueue,
    required this.historyImages,
    required this.preloadTarget,
    required this.isFastBrowseMode,
    required this.consecutivePreloadExhaustions,
    required this.isImageZoomed,
    required this.userTags,
    required this.isInitialLoading,
    required this.isPreloading,
    required this.isNextLoading,
    required this.isDownloading,
    required this.query,
    required this.featuredTags,
    required this.popularTags,
    required this.categories,
    required this.isDiscoveryLoading,
    required this.favoriteImages,
    required this.historyLimit,
    this.currentImage,
    this.selectedTag,
    this.errorMessage,
    this.lastLoadError,
  });

  factory RandomImageViewState.initial() {
    return const RandomImageViewState(
      preloadQueue: [],
      historyImages: [],
      preloadTarget: _defaultPreloadTarget,
      isFastBrowseMode: false,
      consecutivePreloadExhaustions: 0,
      isImageZoomed: false,
      userTags: [],
      isInitialLoading: true,
      isPreloading: false,
      isNextLoading: false,
      isDownloading: false,
      query: ImageQuery(),
      featuredTags: [],
      popularTags: [],
      categories: [],
      isDiscoveryLoading: false,
      favoriteImages: [],
      historyLimit: 30,
    );
  }

  final RandomImage? currentImage;
  final List<RandomImage> preloadQueue;
  final List<HistoryImage> historyImages;
  final int preloadTarget;
  final bool isFastBrowseMode;
  final int consecutivePreloadExhaustions;
  final bool isImageZoomed;
  final String? selectedTag;
  final List<String> userTags;
  final bool isInitialLoading;
  final bool isPreloading;
  final bool isNextLoading;
  final bool isDownloading;
  final ImageQuery query;
  final List<TagSummary> featuredTags;
  final List<TagSummary> popularTags;
  final List<CategorySummary> categories;
  final bool isDiscoveryLoading;
  final List<HistoryImage> favoriteImages;
  final int historyLimit;
  final String? errorMessage;
  final String? lastLoadError;

  RandomImageViewState copyWith({
    Object? currentImage = _unset,
    List<RandomImage>? preloadQueue,
    List<HistoryImage>? historyImages,
    int? preloadTarget,
    bool? isFastBrowseMode,
    int? consecutivePreloadExhaustions,
    bool? isImageZoomed,
    Object? selectedTag = _unset,
    List<String>? userTags,
    bool? isInitialLoading,
    bool? isPreloading,
    bool? isNextLoading,
    bool? isDownloading,
    ImageQuery? query,
    List<TagSummary>? featuredTags,
    List<TagSummary>? popularTags,
    List<CategorySummary>? categories,
    bool? isDiscoveryLoading,
    List<HistoryImage>? favoriteImages,
    int? historyLimit,
    Object? errorMessage = _unset,
    Object? lastLoadError = _unset,
  }) {
    return RandomImageViewState(
      currentImage: identical(currentImage, _unset)
          ? this.currentImage
          : currentImage as RandomImage?,
      preloadQueue: preloadQueue ?? this.preloadQueue,
      historyImages: historyImages ?? this.historyImages,
      preloadTarget: preloadTarget ?? this.preloadTarget,
      isFastBrowseMode: isFastBrowseMode ?? this.isFastBrowseMode,
      consecutivePreloadExhaustions:
          consecutivePreloadExhaustions ?? this.consecutivePreloadExhaustions,
      isImageZoomed: isImageZoomed ?? this.isImageZoomed,
      selectedTag: identical(selectedTag, _unset)
          ? this.selectedTag
          : selectedTag as String?,
      userTags: userTags ?? this.userTags,
      isInitialLoading: isInitialLoading ?? this.isInitialLoading,
      isPreloading: isPreloading ?? this.isPreloading,
      isNextLoading: isNextLoading ?? this.isNextLoading,
      isDownloading: isDownloading ?? this.isDownloading,
      query: query ?? this.query,
      featuredTags: featuredTags ?? this.featuredTags,
      popularTags: popularTags ?? this.popularTags,
      categories: categories ?? this.categories,
      isDiscoveryLoading: isDiscoveryLoading ?? this.isDiscoveryLoading,
      favoriteImages: favoriteImages ?? this.favoriteImages,
      historyLimit: historyLimit ?? this.historyLimit,
      errorMessage: identical(errorMessage, _unset)
          ? this.errorMessage
          : errorMessage as String?,
      lastLoadError: identical(lastLoadError, _unset)
          ? this.lastLoadError
          : lastLoadError as String?,
    );
  }
}

class CacheUsage {
  const CacheUsage({
    required this.historyBytes,
    required this.favoriteBytes,
    required this.preloadBytes,
    required this.temporaryBytes,
  });

  final int historyBytes;
  final int favoriteBytes;
  final int preloadBytes;
  final int temporaryBytes;

  int get totalBytes =>
      historyBytes + favoriteBytes + preloadBytes + temporaryBytes;
}

class RandomImageController extends StateNotifier<RandomImageViewState> {
  RandomImageController({
    required RandomImageRepository repository,
    required LocalTagStore tagStore,
    required HistoryStore historyStore,
    required FavoriteStore favoriteStore,
    required UserPreferencesStore preferencesStore,
    required DownloadService downloadService,
    required QuotaController quotaController,
    required QuotaState Function() readQuotaState,
  })  : _repository = repository,
        _tagStore = tagStore,
        _historyStore = historyStore,
        _favoriteStore = favoriteStore,
        _preferencesStore = preferencesStore,
        _downloadService = downloadService,
        _quotaController = quotaController,
        _readQuotaState = readQuotaState,
        super(RandomImageViewState.initial());

  final RandomImageRepository _repository;
  final LocalTagStore _tagStore;
  final HistoryStore _historyStore;
  final FavoriteStore _favoriteStore;
  final UserPreferencesStore _preferencesStore;
  final DownloadService _downloadService;
  final QuotaController _quotaController;
  final QuotaState Function() _readQuotaState;
  final ListQueue<int> _recentImageIds = ListQueue<int>();
  final Set<String> _pendingConsumedPreloadPaths = <String>{};

  bool _initialized = false;
  bool _isPreloading = false;
  int _generation = 0;

  Future<void> initialize() async {
    if (_initialized) {
      return;
    }
    _initialized = true;
    _log('initialize');

    final tags = _tagStore.loadTags();
    final selectedTag = _tagStore.loadSelectedTag();
    final effectiveSelectedTag =
        selectedTag != null && tags.contains(selectedTag) ? selectedTag : null;
    if (effectiveSelectedTag != selectedTag) {
      await _tagStore.saveSelectedTag(effectiveSelectedTag);
    }
    final defaultQuery = _preferencesStore.loadDefaultQuery();
    final initialQuery = defaultQuery.copyWith(tag: effectiveSelectedTag);

    var historyImages = await _historyStore.load();
    final favoriteImages = await _favoriteStore.load();
    final historyLimit = _historyStore.loadHistoryLimit();
    var restoredImage = await _restoreLastCurrent(historyImages);
    var preloadQueue = await _historyStore.loadPreloadQueue(
      queryKey: initialQuery.cacheKey,
    );
    if (restoredImage == null && preloadQueue.isNotEmpty) {
      restoredImage = preloadQueue.first;
      preloadQueue = preloadQueue.skip(1).toList();
      historyImages = await _historyStore.upsertFromRandomImage(restoredImage);
      if (historyImages.isNotEmpty) {
        restoredImage = _randomImageFromHistory(historyImages.first);
      }
      preloadQueue = await _historyStore.savePreloadQueue(
        preloadQueue,
        queryKey: initialQuery.cacheKey,
      );
    } else if (restoredImage != null) {
      preloadQueue = preloadQueue
          .where((image) => !_isSameImage(image, restoredImage!))
          .toList();
      preloadQueue = await _historyStore.savePreloadQueue(
        preloadQueue,
        queryKey: initialQuery.cacheKey,
      );
    }
    if (!mounted) {
      return;
    }
    if (restoredImage != null) {
      _rememberImageId(restoredImage.imageId);
    }
    for (final image in preloadQueue) {
      _rememberImageId(image.imageId);
    }
    state = state.copyWith(
      currentImage: restoredImage,
      preloadQueue: preloadQueue,
      userTags: tags,
      selectedTag: effectiveSelectedTag,
      query: initialQuery,
      historyImages: historyImages,
      favoriteImages: favoriteImages,
      historyLimit: historyLimit,
      preloadTarget: _defaultPreloadTarget,
      isInitialLoading: restoredImage == null,
    );
    unawaited(loadDiscovery());

    if (restoredImage == null) {
      await _loadFreshCurrent(isInitial: true);
    } else {
      unawaited(_fillPreloadQueue(_generation));
    }
  }

  void setImageZoomed(bool value) {
    if (state.isImageZoomed == value) {
      return;
    }
    state = state.copyWith(isImageZoomed: value);
  }

  Future<void> nextImage() async {
    if (state.isInitialLoading || state.isNextLoading) {
      return;
    }
    final quota = _readQuotaState();
    if (quota.isServerLocked) {
      final remaining = quota.serverLockoutRemaining;
      final label = remaining.inMinutes > 0
          ? '约 ${remaining.inMinutes + 1} 分钟'
          : '${remaining.inSeconds.clamp(1, 60).toInt()} 秒';
      state = state.copyWith(errorMessage: '随机/元数据正在服务器冷却，$label 后再试');
      return;
    }

    state = state.copyWith(errorMessage: null);
    if (state.preloadQueue.isNotEmpty) {
      final queue = [...state.preloadQueue];
      final next = queue.removeAt(0);
      final browsing = _nextBrowseMode(queue.isEmpty);
      final generation = _generation;
      final queryKey = state.query.cacheKey;
      _pendingConsumedPreloadPaths.add(next.localFilePath);
      state = state.copyWith(
        currentImage: next,
        preloadQueue: queue,
        isImageZoomed: false,
        consecutivePreloadExhaustions: browsing.exhaustions,
        isFastBrowseMode: browsing.isFast,
        preloadTarget: browsing.target,
      );
      unawaited(_persistConsumedPreloadedImage(
        next,
        generation: generation,
        queryKey: queryKey,
      ));
      unawaited(_fillPreloadQueue(_generation));
      return;
    }

    if (!_readQuotaState().canAcquire) {
      state = state.copyWith(errorMessage: _quotaRecoveryMessage());
      return;
    }

    final browsing = _nextBrowseMode(true);
    state = state.copyWith(
      isNextLoading: true,
      consecutivePreloadExhaustions: browsing.exhaustions,
      isFastBrowseMode: browsing.isFast,
      preloadTarget: browsing.target,
    );
    await _loadFreshCurrent();
  }

  Future<void> switchTag(String? tag) async {
    final normalized = tag?.trim();
    final effectiveTag =
        normalized == null || normalized.isEmpty ? null : normalized;
    if (effectiveTag == state.selectedTag && state.currentImage != null) {
      return;
    }

    await _applyQuery(state.query.copyWith(tag: effectiveTag));
  }

  Future<void> switchOrientation(ImageOrientation? orientation) async {
    if (orientation == state.query.orientation && state.currentImage != null) {
      return;
    }
    await _applyQuery(state.query.copyWith(orientation: orientation));
  }

  Future<void> switchCategory(String? category) async {
    final normalized = category?.trim();
    final effectiveCategory =
        normalized == null || normalized.isEmpty ? null : normalized;
    if (effectiveCategory == state.query.category &&
        state.currentImage != null) {
      return;
    }
    await _applyQuery(state.query.copyWith(category: effectiveCategory));
  }

  Future<void> toggleExcludedTag(String tag) async {
    final normalized = tag.trim();
    if (normalized.isEmpty) {
      return;
    }
    final excluded = [...state.query.excludeTags];
    final index = excluded.indexWhere(
      (item) => item.toLowerCase() == normalized.toLowerCase(),
    );
    if (index >= 0) {
      excluded.removeAt(index);
    } else {
      excluded.add(normalized);
    }
    await _applyQuery(state.query.copyWith(excludeTags: excluded));
  }

  Future<void> clearFilters() async {
    await _applyQuery(const ImageQuery());
  }

  Future<void> _applyQuery(ImageQuery query) async {
    _generation += 1;
    await _historyStore.clearPreloadQueue();
    await _tagStore.saveSelectedTag(query.tag);
    state = state.copyWith(
      selectedTag: query.tag,
      query: query,
      preloadQueue: const [],
      preloadTarget: _defaultPreloadTarget,
      isFastBrowseMode: false,
      consecutivePreloadExhaustions: 0,
      isImageZoomed: false,
      errorMessage: null,
    );

    await _loadFreshCurrent();
  }

  Future<void> loadDiscovery() async {
    if (state.isDiscoveryLoading) {
      return;
    }
    state = state.copyWith(isDiscoveryLoading: true);
    try {
      final results = await Future.wait<Object>([
        _repository.featuredTags(),
        _repository.tags(limit: 24),
        _repository.categories(),
      ]);
      if (!mounted) {
        return;
      }
      state = state.copyWith(
        featuredTags: results[0] as List<TagSummary>,
        popularTags: results[1] as List<TagSummary>,
        categories: results[2] as List<CategorySummary>,
      );
    } catch (error) {
      if (mounted) {
        state = state.copyWith(errorMessage: _messageForError(error));
      }
    } finally {
      if (mounted) {
        state = state.copyWith(isDiscoveryLoading: false);
      }
    }
  }

  Future<bool> addTag(String value, {bool switchTo = true}) async {
    final tag = value.trim();
    if (tag.isEmpty) {
      state = state.copyWith(errorMessage: '标签不能为空');
      return false;
    }
    if (tag.length > 60) {
      state = state.copyWith(errorMessage: '标签最长 60 个字符');
      return false;
    }
    if (state.userTags.any((item) => item.toLowerCase() == tag.toLowerCase())) {
      state = state.copyWith(errorMessage: '这个标签已经添加过了');
      return false;
    }

    final tags = [...state.userTags, tag];
    await _tagStore.saveTags(tags);
    state = state.copyWith(userTags: tags);
    if (switchTo) {
      await switchTag(tag);
    } else {
      state = state.copyWith(errorMessage: '已加入我的标签');
    }
    return true;
  }

  Future<void> deleteTag(String tag) async {
    final tags = state.userTags.where((item) => item != tag).toList();
    await _tagStore.saveTags(tags);
    state = state.copyWith(userTags: tags);
    if (state.selectedTag == tag) {
      await switchTag(null);
    }
  }

  Future<void> downloadCurrentImage() async {
    final current = state.currentImage;
    if (current == null || state.isDownloading) {
      return;
    }

    state = state.copyWith(isDownloading: true, errorMessage: null);
    var imageToSave = current;
    try {
      final localFile = File(imageToSave.localFilePath);
      if (!await localFile.exists()) {
        final imageId = imageToSave.imageId;
        if (imageId == null) {
          throw const NiceViewException('当前图片已丢失，请切换下一张后再下载');
        }
        if (!_readQuotaState().canAcquireFor(QuotaBucket.image)) {
          throw QuotaExceededException(
            _quotaRecoveryMessage(QuotaBucket.image),
          );
        }
        imageToSave = await _repository.fetchImageById(
          imageId,
          sourceTag: imageToSave.sourceTag,
          queryKey: imageToSave.queryKey,
        );
        if (mounted && state.currentImage?.imageId == imageId) {
          state = state.copyWith(currentImage: imageToSave);
        }
      }

      final destination = await _downloadService.saveImage(imageToSave);
      if (mounted) {
        state = state.copyWith(
          errorMessage: DownloadService.isSystemPhotoDestination(destination)
              ? '已保存到系统相册'
              : '已保存到应用文件',
        );
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(errorMessage: _messageForError(error));
      }
    } finally {
      if (mounted) {
        state = state.copyWith(isDownloading: false);
      }
    }
  }

  Future<String> saveHistoryImage(HistoryImage image) async {
    final latest = _latestHistoryImage(image) ?? image;
    var imageToSave = _randomImageFromHistory(latest);

    final localFile = File(imageToSave.localFilePath);
    if (!await localFile.exists()) {
      final imageId = imageToSave.imageId;
      if (imageId == null) {
        final images = await _historyStore.removeMissing(latest);
        if (mounted) {
          state = state.copyWith(historyImages: images);
        }
        throw const NiceViewException('这张历史图已经不在本机了');
      }
      if (!_readQuotaState().canAcquireFor(QuotaBucket.image)) {
        throw QuotaExceededException(
          _quotaRecoveryMessage(QuotaBucket.image),
        );
      }

      imageToSave = await _repository.fetchImageById(
        imageId,
        sourceTag: imageToSave.sourceTag,
        queryKey: imageToSave.queryKey,
      );
      final images = await _historyStore.upsertFromRandomImage(imageToSave);
      if (mounted) {
        state = state.copyWith(historyImages: images);
      }
    }

    return _downloadService.saveImage(imageToSave);
  }

  bool isFavorite(int? imageId) {
    if (imageId == null) {
      return false;
    }
    return state.favoriteImages.any((image) => image.imageId == imageId);
  }

  Future<void> toggleCurrentFavorite() async {
    final current = state.currentImage;
    if (current == null) {
      return;
    }

    try {
      late final List<HistoryImage> favorites;
      if (isFavorite(current.imageId)) {
        favorites = await _favoriteStore.removeByImageId(current.imageId);
      } else if (await current.file.exists()) {
        favorites = await _favoriteStore.addFromRandomImage(current);
      } else {
        final imageId = current.imageId;
        if (imageId == null) {
          throw const NiceViewException('当前图片已丢失，请切换下一张后再收藏');
        }
        if (!_readQuotaState().canAcquireFor(QuotaBucket.image)) {
          throw QuotaExceededException(
            _quotaRecoveryMessage(QuotaBucket.image),
          );
        }
        final restored = await _repository.fetchImageById(
          imageId,
          sourceTag: current.sourceTag,
          queryKey: current.queryKey,
        );
        favorites = await _favoriteStore.addFromRandomImage(restored);
        if (mounted) {
          state = state.copyWith(currentImage: restored);
        }
      }
      if (mounted) {
        state = state.copyWith(
          favoriteImages: favorites,
          errorMessage: isFavorite(current.imageId) ? '已取消收藏' : '已收藏',
        );
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(errorMessage: _messageForError(error));
      }
    }
  }

  Future<void> toggleHistoryFavorite(HistoryImage image) async {
    final latest = _latestHistoryImage(image) ?? image;
    try {
      late final List<HistoryImage> favorites;
      if (isFavorite(latest.imageId)) {
        favorites = await _favoriteStore.removeByImageId(latest.imageId);
      } else if (await latest.file.exists()) {
        favorites = await _favoriteStore.addFromHistoryImage(latest);
      } else {
        final imageId = latest.imageId;
        if (imageId == null) {
          throw const NiceViewException('这张图片已经不在本机了');
        }
        if (!_readQuotaState().canAcquireFor(QuotaBucket.image)) {
          throw QuotaExceededException(
            _quotaRecoveryMessage(QuotaBucket.image),
          );
        }
        final restored = await _repository.fetchImageById(
          imageId,
          sourceTag: latest.sourceTag,
          queryKey: latest.queryKey,
        );
        final historyImages = await _historyStore.upsertFromRandomImage(
          restored,
        );
        favorites = await _favoriteStore.addFromRandomImage(restored);
        if (mounted) {
          state = state.copyWith(historyImages: historyImages);
        }
      }
      if (mounted) {
        state = state.copyWith(
          favoriteImages: favorites,
          errorMessage: isFavorite(latest.imageId) ? '已取消收藏' : '已收藏',
        );
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(errorMessage: _messageForError(error));
      }
    }
  }

  Future<void> deleteFavoriteImage(HistoryImage image) async {
    final favorites = await _favoriteStore.remove(image);
    if (mounted) {
      state = state.copyWith(favoriteImages: favorites);
    }
  }

  Future<void> deleteHistoryImage(HistoryImage image) async {
    final images = await _historyStore.delete(image);
    if (mounted) {
      state = state.copyWith(historyImages: images);
    }
  }

  Future<void> touchHistoryImage(HistoryImage image) async {
    final images = await _historyStore.touch(image);
    if (mounted) {
      state = state.copyWith(historyImages: images);
    }
  }

  Future<void> removeMissingHistoryImage(HistoryImage image) async {
    final images = await _historyStore.removeMissing(image);
    if (mounted) {
      state = state.copyWith(
        historyImages: images,
        errorMessage: '这张历史图已经不在本机了',
      );
    }
  }

  Future<void> useRandomImage(RandomImage image) async {
    final historyImages = await _historyStore.upsertFromRandomImage(image);
    final current = historyImages.isEmpty
        ? image
        : _randomImageFromHistory(historyImages.first);
    _rememberImageId(current.imageId);
    if (mounted) {
      state = state.copyWith(
        currentImage: current,
        historyImages: historyImages,
        isImageZoomed: false,
        errorMessage: '已切换到图集图片',
      );
      unawaited(_fillPreloadQueue(_generation));
    }
  }

  Future<void> saveCurrentQueryAsDefault() async {
    await _preferencesStore.saveDefaultQuery(
      ImageQuery(
        orientation: state.query.orientation,
        category: state.query.category,
        excludeTags: state.query.excludeTags,
      ),
    );
    if (mounted) {
      state = state.copyWith(errorMessage: '已保存为默认偏好');
    }
  }

  Future<void> clearDefaultQuery() async {
    await _preferencesStore.clearDefaultQuery();
    if (mounted) {
      state = state.copyWith(errorMessage: '已清除默认偏好');
    }
  }

  Future<void> updateHistoryLimit(int limit) async {
    final images = await _historyStore.saveHistoryLimit(limit);
    if (mounted) {
      state = state.copyWith(
        historyImages: images,
        historyLimit: _historyStore.loadHistoryLimit(),
        errorMessage: '已更新历史上限',
      );
    }
  }

  Future<void> clearHistory() async {
    final images = await _historyStore.clearHistory();
    if (mounted) {
      state = state.copyWith(
        historyImages: images,
        errorMessage: '已清空浏览历史',
      );
    }
  }

  Future<void> clearFavorites() async {
    final favorites = await _favoriteStore.clear();
    if (mounted) {
      state = state.copyWith(
        favoriteImages: favorites,
        errorMessage: '已清空收藏',
      );
    }
  }

  Future<void> clearTemporaryCache() async {
    await _historyStore.clearTemporaryImageCache();
    if (mounted) {
      state = state.copyWith(
        preloadQueue: const [],
        errorMessage: '已清理临时缓存',
      );
    }
  }

  Future<CacheUsage> loadCacheUsage() async {
    final historyBytes = await _historyStore.historyCacheSizeBytes();
    final favoriteBytes = await _favoriteStore.cacheSizeBytes();
    final preloadBytes = await _historyStore.preloadCacheSizeBytes();
    final temporaryBytes = await _historyStore.temporaryImageCacheSizeBytes();
    return CacheUsage(
      historyBytes: historyBytes,
      favoriteBytes: favoriteBytes,
      preloadBytes: preloadBytes,
      temporaryBytes: temporaryBytes,
    );
  }

  void clearMessage() {
    if (state.errorMessage != null) {
      state = state.copyWith(errorMessage: null);
    }
  }

  Future<void> retryCurrent() async {
    await _loadFreshCurrent(isInitial: state.currentImage == null);
  }

  Future<RandomImage?> _restoreLastCurrent(
    List<HistoryImage> historyImages,
  ) async {
    final lastCurrent = await _historyStore.loadLastCurrent();
    final candidates = <HistoryImage>[
      if (lastCurrent != null) lastCurrent,
      ...historyImages,
    ];
    final seen = <String>{};
    for (final image in candidates) {
      if (!seen.add(image.historyId)) {
        continue;
      }
      if (await image.file.exists()) {
        _log('restore last current imageId=${image.imageId}');
        return _randomImageFromHistory(image);
      }
    }
    return null;
  }

  RandomImage _randomImageFromHistory(HistoryImage image) {
    return RandomImage(
      localFilePath: image.localFilePath,
      imageId: image.imageId,
      galleryId: image.galleryId,
      contentType: image.contentType,
      sourceTag: image.sourceTag,
      queryKey: image.queryKey,
      width: image.width,
      height: image.height,
      orientation: image.orientation,
      galleryTitle: image.galleryTitle,
      galleryCategory: image.galleryCategory,
      tags: image.tags,
      fetchedAt: image.fetchedAt,
    );
  }

  HistoryImage? _latestHistoryImage(HistoryImage image) {
    for (final item in state.historyImages) {
      if (item.historyId == image.historyId) {
        return item;
      }
    }
    return null;
  }

  Future<void> _loadFreshCurrent({bool isInitial = false}) async {
    final generation = ++_generation;
    _log(
      'load current generation=$generation initial=$isInitial '
      'query=${state.query.summary}',
    );
    state = state.copyWith(
      isInitialLoading: isInitial && state.currentImage == null,
      isNextLoading: !isInitial || state.currentImage != null,
      errorMessage: null,
      lastLoadError: null,
    );

    try {
      final image = await _fetchRandomWithRetry(query: state.query);
      if (!mounted || generation != _generation) {
        _log('discard stale image generation=$generation');
        return;
      }
      _rememberImageId(image.imageId);
      final historyImages = await _historyStore.upsertFromRandomImage(image);
      if (!mounted || generation != _generation) {
        return;
      }
      state = state.copyWith(
        currentImage: image,
        historyImages: historyImages,
        isInitialLoading: false,
        isNextLoading: false,
        isImageZoomed: false,
        lastLoadError: null,
      );
      _log(
        'load success generation=$generation imageId=${image.imageId} '
        'path=${image.localFilePath}',
      );
      unawaited(_fillPreloadQueue(generation));
    } catch (error) {
      if (!mounted || generation != _generation) {
        return;
      }
      final message = _messageForError(error);
      _log('load failed generation=$generation error=$error message=$message');
      state = state.copyWith(
        isInitialLoading: false,
        isNextLoading: false,
        errorMessage: message,
        lastLoadError: message,
      );
    }
  }

  Future<RandomImage> _fetchRandomWithRetry({required ImageQuery query}) async {
    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt += 1) {
      try {
        return await _repository.fetchRandom(query: query);
      } on ImageNotFoundException catch (error) {
        lastError = error;
      } on NiceViewException catch (error) {
        if (error is QuotaExceededException ||
            error is ServerLockoutException ||
            error is EmptyTagException) {
          rethrow;
        }
        lastError = error;
        if (attempt < 2) {
          _log('retry random request after transient error: $error');
          await Future<void>.delayed(
              Duration(milliseconds: 500 + attempt * 750));
        }
      }
    }
    throw lastError ?? const ImageNotFoundException('图片不存在');
  }

  Future<void> _persistConsumedPreloadedImage(
    RandomImage image, {
    required int generation,
    required String queryKey,
  }) async {
    try {
      final historyImages = await _historyStore.upsertFromRandomImage(image);
      if (!mounted ||
          generation != _generation ||
          queryKey != state.query.cacheKey) {
        return;
      }

      final currentImage = historyImages.isEmpty
          ? image
          : _randomImageFromHistory(historyImages.first);
      _pendingConsumedPreloadPaths.remove(image.localFilePath);
      final displayedImage = state.currentImage;
      state = displayedImage != null && _isSameImage(displayedImage, image)
          ? state.copyWith(
              currentImage: currentImage,
              historyImages: historyImages,
            )
          : state.copyWith(historyImages: historyImages);

      final preloadQueue = await _historyStore.savePreloadQueue(
        state.preloadQueue,
        queryKey: queryKey,
        preservePaths: _pendingConsumedPreloadPaths,
      );
      if (!mounted ||
          generation != _generation ||
          queryKey != state.query.cacheKey) {
        return;
      }
      state = state.copyWith(preloadQueue: preloadQueue);
    } catch (error) {
      if (mounted &&
          generation == _generation &&
          queryKey == state.query.cacheKey) {
        state = state.copyWith(errorMessage: _messageForError(error));
      }
    } finally {
      _pendingConsumedPreloadPaths.remove(image.localFilePath);
    }
  }

  Future<void> _fillPreloadQueue(int generation) async {
    if (_isPreloading || _readQuotaState().isServerLocked) {
      return;
    }
    _isPreloading = true;
    if (mounted) {
      state = state.copyWith(isPreloading: true);
    }

    var attempts = 0;
    try {
      while (mounted &&
          generation == _generation &&
          state.preloadQueue.length < state.preloadTarget &&
          _readQuotaState().canAcquire &&
          attempts < state.preloadTarget * 4) {
        final quota = _readQuotaState();
        final missing = state.preloadTarget - state.preloadQueue.length;
        final remainingAttempts = state.preloadTarget * 4 - attempts;
        var requestCount = missing;
        if (requestCount > quota.remaining) {
          requestCount = quota.remaining;
        }
        if (requestCount > remainingAttempts) {
          requestCount = remainingAttempts;
        }
        if (requestCount <= 0) {
          break;
        }

        attempts += requestCount;
        _log('preload batch count=$requestCount missing=$missing');
        final results = await Future.wait(
          List.generate(requestCount, (_) async {
            try {
              return _PreloadResult(
                image: await _fetchRandomWithRetry(query: state.query),
              );
            } catch (error) {
              return _PreloadResult(error: error);
            }
          }),
        );
        if (!mounted || generation != _generation) {
          return;
        }

        var added = 0;
        final queue = [...state.preloadQueue];
        Object? firstError;
        for (final result in results) {
          final error = result.error;
          if (error != null) {
            if (error is ServerLockoutException) {
              throw error;
            }
            if (error is QuotaExceededException) {
              return;
            }
            firstError ??= error;
            continue;
          }

          final image = result.image;
          if (image == null || _isDuplicate(image, queue)) {
            continue;
          }
          _rememberImageId(image.imageId);
          queue.add(image);
          added += 1;
        }

        if (added > 0) {
          final preloadQueue = await _historyStore.savePreloadQueue(
            queue,
            queryKey: state.query.cacheKey,
            preservePaths: _pendingConsumedPreloadPaths,
          );
          if (!mounted || generation != _generation) {
            return;
          }
          state = state.copyWith(preloadQueue: preloadQueue);
        }

        if (added == 0 && firstError != null) {
          break;
        }
      }
    } catch (error) {
      if (mounted) {
        state = state.copyWith(errorMessage: _messageForError(error));
      }
    } finally {
      _isPreloading = false;
      if (mounted) {
        state = state.copyWith(isPreloading: false);
      }
    }
  }

  _BrowseMode _nextBrowseMode(bool queueExhausted) {
    if (!queueExhausted) {
      return _BrowseMode(
        exhaustions: 0,
        isFast: state.isFastBrowseMode,
        target: state.preloadTarget,
      );
    }

    final exhaustions = state.consecutivePreloadExhaustions + 1;
    final isFast = exhaustions >= 2 || state.isFastBrowseMode;
    return _BrowseMode(
      exhaustions: exhaustions,
      isFast: isFast,
      target: _defaultPreloadTarget,
    );
  }

  bool _isDuplicate(RandomImage image, [List<RandomImage>? preloadQueue]) {
    final imageId = image.imageId;
    if (imageId == null) {
      return false;
    }
    if (_recentImageIds.contains(imageId)) {
      return true;
    }
    if (state.currentImage?.imageId == imageId) {
      return true;
    }
    return (preloadQueue ?? state.preloadQueue)
        .any((item) => item.imageId == imageId);
  }

  bool _isSameImage(RandomImage a, RandomImage b) {
    final aId = a.imageId;
    final bId = b.imageId;
    if (aId != null && bId != null) {
      return aId == bId;
    }
    return a.localFilePath == b.localFilePath;
  }

  void _rememberImageId(int? imageId) {
    if (imageId == null) {
      return;
    }
    _recentImageIds.remove(imageId);
    _recentImageIds.addLast(imageId);
    while (_recentImageIds.length > 20) {
      _recentImageIds.removeFirst();
    }
  }

  String _quotaRecoveryMessage([QuotaBucket bucket = QuotaBucket.random]) {
    final quota = _readQuotaState();
    final lockout = quota.serverLockoutRemainingFor(bucket);
    if (lockout > Duration.zero) {
      final minutes = lockout.inMinutes;
      if (minutes > 0) {
        return '${bucket.label}正在服务器冷却，约 ${minutes + 1} 分钟后再试';
      }
      return '${bucket.label}正在服务器冷却，${lockout.inSeconds}s 后再试';
    }
    final wait = quota.timeUntilNextAvailableFor(bucket);
    if (wait == null || wait.inSeconds <= 0) {
      return '${bucket.label}额度已用尽，请稍后再试';
    }
    return '${bucket.label}额度已用尽，约 ${wait.inSeconds}s 后恢复';
  }

  String _messageForError(Object error) {
    if (error is ServerLockoutException) {
      return error.message;
    }
    if (error is QuotaExceededException) {
      return error.message;
    }
    if (error is EmptyTagException) {
      return '该标签暂时没有图片';
    }
    if (error is NiceViewException) {
      return error.message;
    }
    return '网络连接失败，稍后再试';
  }

  @override
  void dispose() {
    unawaited(_quotaController.pruneAndSave());
    super.dispose();
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[NiceView][Controller] $message');
    }
  }
}

class _PreloadResult {
  const _PreloadResult({
    this.image,
    this.error,
  });

  final RandomImage? image;
  final Object? error;
}

class _BrowseMode {
  const _BrowseMode({
    required this.exhaustions,
    required this.isFast,
    required this.target,
  });

  final int exhaustions;
  final bool isFast;
  final int target;
}
