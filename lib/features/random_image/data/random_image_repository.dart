import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../../services/app_exceptions.dart';
import '../../../services/quota_service.dart';
import '../domain/image_query.dart';
import '../domain/random_image.dart';
import 'veil_api_client.dart';

final randomImageRepositoryProvider = Provider<RandomImageRepository>((ref) {
  return RandomImageRepository(
    ref.watch(veilApiClientProvider),
    ref.read(quotaControllerProvider.notifier),
  );
});

class RandomImageRepository {
  RandomImageRepository(this._apiClient, this._quotaController);

  final VeilApiClient _apiClient;
  final QuotaController _quotaController;

  Future<RandomImage> fetchRandom({ImageQuery query = const ImageQuery()}) {
    return _quotaGuardedFetch(
      () => _fetchRandomResponse(query),
      sourceTag: query.tag,
      queryKey: query.cacheKey,
    );
  }

  Future<RandomImage> fetchImageById(
    int imageId, {
    String? sourceTag,
    String? queryKey,
  }) {
    return _quotaGuardedFetch(
      () => _apiClient.imageById(imageId),
      sourceTag: sourceTag,
      queryKey: queryKey,
    );
  }

  Future<List<TagSummary>> featuredTags() {
    return _apiClient.featuredTags();
  }

  Future<List<TagSummary>> tags({int limit = 24, int offset = 0}) {
    return _apiClient.tags(limit: limit, offset: offset);
  }

  Future<List<CategorySummary>> categories() {
    return _apiClient.categories();
  }

  Future<List<RandomImage>> tagPreviewImages(String tag) async {
    final preview = await _apiClient.tagPreview(tag);
    final images = <RandomImage>[];
    for (final imageId in preview.imageIds) {
      final response = await _apiClient.imageById(imageId);
      images.add(
        await _persistResponse(
          response,
          sourceTag: tag,
          queryKey: ImageQuery(tag: tag).cacheKey,
        ),
      );
    }
    return images;
  }

  Future<RandomImage> _quotaGuardedFetch(
    Future<VeilImageResponse> Function() request, {
    String? sourceTag,
    String? queryKey,
  }) async {
    final allowed = await _quotaController.tryConsumeRemoteRequest();
    if (!allowed) {
      throw const QuotaExceededException('请求额度已用尽');
    }

    try {
      final response = await request();
      return _persistResponse(
        response,
        sourceTag: sourceTag,
        queryKey: queryKey,
      );
    } on ServerLockoutException {
      await _quotaController.startServerLockout();
      rethrow;
    }
  }

  Future<VeilImageResponse> _fetchRandomResponse(ImageQuery query) async {
    if (!query.usesMetaEndpoint) {
      return _apiClient.random(query: query);
    }

    final meta = await _apiClient.randomMeta(query: query);
    final response = await _apiClient.imageById(meta.id);
    return response.withMeta(meta);
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
