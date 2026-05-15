import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../services/shared_preferences_provider.dart';
import '../domain/history_image.dart';
import '../domain/random_image.dart';
import 'random_image_repository.dart';

final favoriteStoreProvider = Provider<FavoriteStore>((ref) {
  return FavoriteStore(ref.watch(sharedPreferencesProvider));
});

class FavoriteStore {
  FavoriteStore(this._preferences);

  static const _favoritesKey = 'nice_view.favorite_images';

  final SharedPreferences _preferences;

  Future<List<HistoryImage>> load() async {
    final items = HistoryImage.listFromJsonString(
      _preferences.getString(_favoritesKey),
    );
    items.sort((a, b) => b.viewedAt.compareTo(a.viewedAt));
    return items;
  }

  Future<bool> isFavoriteImageId(int? imageId) async {
    if (imageId == null) {
      return false;
    }
    final images = await load();
    return images.any((image) => image.imageId == imageId);
  }

  Future<List<HistoryImage>> addFromRandomImage(RandomImage image) async {
    final source = File(image.localFilePath);
    if (!await source.exists()) {
      return load();
    }

    final now = DateTime.now();
    final images = await load();
    final existingIndex = image.imageId == null
        ? -1
        : images.indexWhere((item) => item.imageId == image.imageId);
    final favoriteId = image.imageId?.toString() ??
        'local_${now.microsecondsSinceEpoch}_${source.lengthSync()}';
    final targetPath = await _copyIntoFavoriteCache(
      source,
      favoriteId,
      image.contentType,
    );

    if (existingIndex >= 0) {
      final existing = images.removeAt(existingIndex);
      if (existing.localFilePath != targetPath) {
        await _deleteFile(existing.localFilePath);
      }
    }

    images.insert(
      0,
      HistoryImage(
        historyId: favoriteId,
        localFilePath: targetPath,
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
        viewedAt: now,
      ),
    );
    await _save(images);
    return images;
  }

  Future<List<HistoryImage>> addFromHistoryImage(HistoryImage image) {
    return addFromRandomImage(
      RandomImage(
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
      ),
    );
  }

  Future<List<HistoryImage>> remove(HistoryImage image) async {
    final images = await load();
    final removed = <HistoryImage>[];
    images.removeWhere((item) {
      final matched = image.imageId != null
          ? item.imageId == image.imageId
          : item.historyId == image.historyId;
      if (matched) {
        removed.add(item);
      }
      return matched;
    });
    for (final item in removed) {
      await _deleteFile(item.localFilePath);
    }
    await _save(images);
    return images;
  }

  Future<List<HistoryImage>> removeByImageId(int? imageId) async {
    if (imageId == null) {
      return load();
    }
    final images = await load();
    final removed = <HistoryImage>[];
    images.removeWhere((item) {
      final matched = item.imageId == imageId;
      if (matched) {
        removed.add(item);
      }
      return matched;
    });
    for (final item in removed) {
      await _deleteFile(item.localFilePath);
    }
    await _save(images);
    return images;
  }

  Future<List<HistoryImage>> clear() async {
    final images = await load();
    for (final image in images) {
      await _deleteFile(image.localFilePath);
    }
    await _preferences.remove(_favoritesKey);
    return <HistoryImage>[];
  }

  Future<int> cacheSizeBytes() async {
    final directory = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'favorites'),
    );
    if (!await directory.exists()) {
      return 0;
    }
    var size = 0;
    await for (final entity in directory.list(recursive: true)) {
      if (entity is File) {
        size += await entity.length();
      }
    }
    return size;
  }

  Future<String> _copyIntoFavoriteCache(
    File source,
    String favoriteId,
    String? contentType,
  ) async {
    final directory = Directory(
      p.join((await getApplicationSupportDirectory()).path, 'favorites'),
    );
    await directory.create(recursive: true);
    final target = File(
      p.join(directory.path,
          'nice_view_favorite_$favoriteId${extensionForContentType(contentType)}'),
    );
    await source.copy(target.path);
    return target.path;
  }

  Future<void> _save(List<HistoryImage> images) {
    return _preferences.setString(
      _favoritesKey,
      jsonEncode(images.map((image) => image.toJson()).toList()),
    );
  }

  Future<void> _deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }
}
