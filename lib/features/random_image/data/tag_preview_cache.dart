import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/random_image.dart';

final tagPreviewCacheProvider = Provider<TagPreviewCache>((ref) {
  return TagPreviewCache();
});

class TagPreviewCacheEntry {
  const TagPreviewCacheEntry({
    required this.tag,
    required this.images,
    required this.createdAt,
  });

  final String tag;
  final List<RandomImage> images;
  final DateTime createdAt;
}

class TagPreviewCache {
  TagPreviewCache({
    this.ttl = const Duration(minutes: 10),
    this.maxEntries = 20,
  });

  final Duration ttl;
  final int maxEntries;
  final Map<String, TagPreviewCacheEntry> _entries =
      <String, TagPreviewCacheEntry>{};

  Future<List<RandomImage>?> read(String tag) async {
    final key = _keyFor(tag);
    final entry = _entries[key];
    if (entry == null) {
      return null;
    }
    if (_isExpired(entry)) {
      await _remove(key);
      return null;
    }
    for (final image in entry.images) {
      if (!await image.file.exists()) {
        await _remove(key);
        return null;
      }
    }
    _entries
      ..remove(key)
      ..[key] = entry;
    return entry.images;
  }

  Future<void> write(String tag, List<RandomImage> images) async {
    if (images.isEmpty) {
      return;
    }
    final key = _keyFor(tag);
    _entries[key] = TagPreviewCacheEntry(
      tag: tag,
      images: images,
      createdAt: DateTime.now(),
    );
    await _evictOverflow();
  }

  Future<void> evictExpired() async {
    final keys = _entries.entries
        .where((entry) => _isExpired(entry.value))
        .map((entry) => entry.key)
        .toList();
    for (final key in keys) {
      await _remove(key);
    }
  }

  Future<void> clear() async {
    final keys = _entries.keys.toList();
    for (final key in keys) {
      await _remove(key);
    }
  }

  bool _isExpired(TagPreviewCacheEntry entry) {
    return DateTime.now().difference(entry.createdAt) > ttl;
  }

  Future<void> _evictOverflow() async {
    while (_entries.length > maxEntries) {
      await _remove(_entries.keys.first);
    }
  }

  Future<void> _remove(String key) async {
    final entry = _entries.remove(key);
    if (entry == null) {
      return;
    }
    for (final image in entry.images) {
      await _deleteFile(image.localFilePath);
    }
  }

  Future<void> _deleteFile(String path) async {
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _keyFor(String tag) {
    return tag.trim().toLowerCase();
  }
}
