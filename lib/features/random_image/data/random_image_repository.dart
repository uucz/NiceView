import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../services/app_exceptions.dart';
import '../../../services/quota_service.dart';
import '../domain/image_query.dart';
import '../domain/quota_state.dart';
import '../domain/random_image.dart';
import 'tag_preview_cache.dart';
import 'veil_api_client.dart';

final randomImageRepositoryProvider = Provider<RandomImageRepository>((ref) {
  return RandomImageRepository(
    ref.watch(veilApiClientProvider),
    ref.read(quotaControllerProvider.notifier),
    ref.watch(tagPreviewCacheProvider),
  );
});

class RandomImageRepository {
  RandomImageRepository(
    this._apiClient,
    this._quotaController,
    this._tagPreviewCache,
  );

  final VeilApiClient _apiClient;
  final QuotaController _quotaController;
  final TagPreviewCache _tagPreviewCache;

  Future<RandomImage> fetchRandom({ImageQuery query = const ImageQuery()}) {
    return _fetchRandomResponse(query);
  }

  Future<RandomImage> fetchImageById(
    int imageId, {
    String? sourceTag,
    String? queryKey,
  }) {
    return _quotaGuardedFetch(
      QuotaBucket.image,
      () => _apiClient.imageById(imageId),
      sourceTag: sourceTag,
      queryKey: queryKey,
    );
  }

  Future<List<TagSummary>> featuredTags() {
    return _quotaGuardedRequest(
      QuotaBucket.random,
      () => _apiClient.featuredTags(),
    );
  }

  Future<List<TagSummary>> tags({int limit = 24, int offset = 0}) {
    return _quotaGuardedRequest(
      QuotaBucket.random,
      () => _apiClient.tags(limit: limit, offset: offset),
    );
  }

  Future<PagedResult<TagSummary>> tagsPage({
    int limit = 24,
    int offset = 0,
  }) {
    return _quotaGuardedRequest(
      QuotaBucket.random,
      () => _apiClient.tagsPage(limit: limit, offset: offset),
    );
  }

  Future<List<CategorySummary>> categories() {
    return _quotaGuardedRequest(
      QuotaBucket.random,
      () => _apiClient.categories(),
    );
  }

  Future<PagedResult<GallerySummary>> galleries({
    int limit = 24,
    int offset = 0,
  }) {
    return _quotaGuardedRequest(
      QuotaBucket.random,
      () => _apiClient.galleries(limit: limit, offset: offset),
    );
  }

  Future<GalleryDetail> gallery(
    int galleryId, {
    int imageLimit = 24,
    int imageOffset = 0,
  }) {
    return _quotaGuardedRequest(
      QuotaBucket.random,
      () => _apiClient.gallery(
        galleryId,
        imageLimit: imageLimit,
        imageOffset: imageOffset,
      ),
    );
  }

  Future<List<RandomImage>> tagPreviewImages(String tag) async {
    await _tagPreviewCache.evictExpired();
    final cachedImages = await _tagPreviewCache.read(tag);
    if (cachedImages != null) {
      return cachedImages;
    }

    final preview = await _quotaGuardedRequest(
      QuotaBucket.random,
      () => _apiClient.tagPreview(tag),
    );
    final images = <RandomImage>[];
    for (final imageId in preview.imageIds) {
      images.add(
        await fetchImageById(
          imageId,
          sourceTag: tag,
          queryKey: ImageQuery(tag: tag).cacheKey,
        ),
      );
    }
    await _tagPreviewCache.write(tag, images);
    return images;
  }

  Future<RandomImage> _quotaGuardedFetch(
    QuotaBucket bucket,
    Future<VeilImageResponse> Function() request, {
    String? sourceTag,
    String? queryKey,
  }) async {
    final response = await _quotaGuardedRequest(bucket, request);
    return _persistResponse(
      response,
      sourceTag: sourceTag,
      queryKey: queryKey,
    );
  }

  Future<RandomImage> _fetchRandomResponse(ImageQuery query) async {
    if (!query.usesMetaEndpoint) {
      return _quotaGuardedFetch(
        QuotaBucket.random,
        () => _apiClient.random(query: query),
        sourceTag: query.tag,
        queryKey: query.cacheKey,
      );
    }

    if (!_quotaController.canAcquire(QuotaBucket.image)) {
      throw QuotaExceededException(_quotaExceededMessage(QuotaBucket.image));
    }

    final meta = await _quotaGuardedRequest(
      QuotaBucket.random,
      () => _apiClient.randomMeta(query: query),
    );
    final response = await _quotaGuardedRequest(
      QuotaBucket.image,
      () => _apiClient.imageById(meta.id),
    );
    return _persistResponse(
      response.withMeta(meta),
      sourceTag: query.tag,
      queryKey: query.cacheKey,
    );
  }

  Future<T> _quotaGuardedRequest<T>(
    QuotaBucket bucket,
    Future<T> Function() request,
  ) async {
    final allowed = await _quotaController.tryConsume(bucket);
    if (!allowed) {
      throw QuotaExceededException(_quotaExceededMessage(bucket));
    }

    try {
      return await request();
    } on ServerLockoutException {
      await _quotaController.startServerLockout(bucket);
      throw ServerLockoutException(
        '${bucket.label}触发服务器冷却，请稍后再试',
      );
    }
  }

  String _quotaExceededMessage(QuotaBucket bucket) {
    final lockout = _quotaController.serverLockoutRemaining(bucket);
    if (lockout > Duration.zero) {
      final minutes = lockout.inMinutes;
      if (minutes > 0) {
        return '${bucket.label}正在服务器冷却，约 ${minutes + 1} 分钟后再试';
      }
      return '${bucket.label}正在服务器冷却，${lockout.inSeconds}s 后再试';
    }
    final wait = _quotaController.timeUntilNextAvailable(bucket)?.inSeconds;
    if (wait == null || wait <= 0) {
      return '${bucket.label}额度已用尽，请稍后再试';
    }
    return '${bucket.label}额度已用尽，约 ${wait}s 后恢复';
  }

  Future<RandomImage> _persistResponse(
    VeilImageResponse response, {
    String? sourceTag,
    String? queryKey,
  }) async {
    final cacheDirectory = Directory(
      p.join((await getTemporaryDirectory()).path, 'nice_view_images'),
    );
    await cacheDirectory.create(recursive: true);

    final extension = extensionForContentType(response.contentType);
    final token = response.imageId?.toString() ??
        DateTime.now().microsecondsSinceEpoch.toString();
    final file = File(
      p.join(
        cacheDirectory.path,
        'nice_view_${token}_${DateTime.now().millisecondsSinceEpoch}$extension',
      ),
    );
    await file.writeAsBytes(response.bytes, flush: true);
    if (kDebugMode) {
      debugPrint(
        '[NiceView][Repository] saved ${response.bytes.length} bytes to '
        '${file.path}',
      );
    }

    return RandomImage(
      localFilePath: file.path,
      imageId: response.imageId,
      galleryId: response.galleryId,
      contentType: response.contentType,
      sourceTag: sourceTag,
      queryKey: queryKey,
      width: response.meta?.width,
      height: response.meta?.height,
      orientation: response.meta?.orientation,
      galleryTitle: response.meta?.gallery?.title,
      galleryCategory: response.meta?.gallery?.category,
      tags: response.meta?.tags ?? const <String>[],
      fetchedAt: DateTime.now(),
    );
  }
}

String extensionForContentType(String? contentType) {
  final normalized = contentType?.split(';').first.trim().toLowerCase();
  return switch (normalized) {
    'image/png' => '.png',
    'image/webp' => '.webp',
    'image/gif' => '.gif',
    _ => '.jpg',
  };
}
