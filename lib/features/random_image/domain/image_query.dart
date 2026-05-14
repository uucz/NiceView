enum ImageOrientation {
  portrait('portrait', '竖图'),
  landscape('landscape', '横图');

  const ImageOrientation(this.apiValue, this.label);

  final String apiValue;
  final String label;

  static ImageOrientation? fromApiValue(String? value) {
    for (final item in values) {
      if (item.apiValue == value) {
        return item;
      }
    }
    return null;
  }
}

class ImageQuery {
  const ImageQuery({
    this.tag,
    this.orientation,
    this.category,
    this.includeTags = const <String>[],
    this.excludeTags = const <String>[],
    this.includeCategories = const <String>[],
    this.excludeCategories = const <String>[],
  });

  final String? tag;
  final ImageOrientation? orientation;
  final String? category;
  final List<String> includeTags;
  final List<String> excludeTags;
  final List<String> includeCategories;
  final List<String> excludeCategories;

  bool get usesMetaEndpoint =>
      orientation != null ||
      category != null ||
      includeTags.isNotEmpty ||
      excludeTags.isNotEmpty ||
      includeCategories.isNotEmpty ||
      excludeCategories.isNotEmpty;

  bool get isEmpty =>
      tag == null &&
      orientation == null &&
      category == null &&
      includeTags.isEmpty &&
      excludeTags.isEmpty &&
      includeCategories.isEmpty &&
      excludeCategories.isEmpty;

  String get cacheKey {
    final params = toQueryParameters();
    if (params.isEmpty) {
      return 'all';
    }
    final keys = params.keys.toList()..sort();
    return keys.map((key) => '$key=${params[key]}').join('&');
  }

  String get summary {
    final parts = <String>[];
    if (tag != null) {
      parts.add(tag!);
    }
    if (orientation != null) {
      parts.add(orientation!.label);
    }
    if (category != null) {
      parts.add(category!);
    }
    if (excludeTags.isNotEmpty) {
      parts.add('已排除 ${excludeTags.length}');
    }
    return parts.isEmpty ? '全部' : parts.join(' / ');
  }

  Map<String, String> toQueryParameters() {
    final params = <String, String>{};
    void setString(String key, String? value) {
      final normalized = value?.trim();
      if (normalized != null && normalized.isNotEmpty) {
        params[key] = normalized;
      }
    }

    void setList(String key, List<String> values) {
      final normalized = values
          .map((value) => value.trim())
          .where((value) => value.isNotEmpty)
          .toList();
      if (normalized.isNotEmpty) {
        params[key] = normalized.join(',');
      }
    }

    setString('tag', tag);
    setString('orientation', orientation?.apiValue);
    setString('category', category);
    setList('include_tag', includeTags);
    setList('exclude_tag', excludeTags);
    setList('include_category', includeCategories);
    setList('exclude_category', excludeCategories);
    return params;
  }

  ImageQuery copyWith({
    Object? tag = _unset,
    Object? orientation = _unset,
    Object? category = _unset,
    List<String>? includeTags,
    List<String>? excludeTags,
    List<String>? includeCategories,
    List<String>? excludeCategories,
  }) {
    return ImageQuery(
      tag: identical(tag, _unset) ? this.tag : tag as String?,
      orientation: identical(orientation, _unset)
          ? this.orientation
          : orientation as ImageOrientation?,
      category:
          identical(category, _unset) ? this.category : category as String?,
      includeTags: includeTags ?? this.includeTags,
      excludeTags: excludeTags ?? this.excludeTags,
      includeCategories: includeCategories ?? this.includeCategories,
      excludeCategories: excludeCategories ?? this.excludeCategories,
    );
  }
}

class ImageMeta {
  const ImageMeta({
    required this.id,
    this.width,
    this.height,
    this.orientation,
    this.sortOrder,
    this.gallery,
    this.tags = const <String>[],
  });

  final int id;
  final int? width;
  final int? height;
  final ImageOrientation? orientation;
  final int? sortOrder;
  final GalleryMeta? gallery;
  final List<String> tags;

  factory ImageMeta.fromJson(Map<String, Object?> json) {
    return ImageMeta(
      id: json['id'] as int,
      width: json['width'] as int?,
      height: json['height'] as int?,
      orientation: ImageOrientation.fromApiValue(json['orientation'] as String?),
      sortOrder: json['sort_order'] as int?,
      gallery: json['gallery'] is Map
          ? GalleryMeta.fromJson(
              Map<String, Object?>.from(json['gallery'] as Map),
            )
          : null,
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
    );
  }
}

class GalleryMeta {
  const GalleryMeta({
    required this.id,
    this.title,
    this.category,
  });

  final int id;
  final String? title;
  final String? category;

  factory GalleryMeta.fromJson(Map<String, Object?> json) {
    return GalleryMeta(
      id: json['id'] as int,
      title: json['title'] as String?,
      category: json['category'] as String?,
    );
  }
}

class TagSummary {
  const TagSummary({
    required this.name,
    this.id,
    this.normalizedName,
    this.galleryCount,
  });

  final int? id;
  final String name;
  final String? normalizedName;
  final int? galleryCount;

  factory TagSummary.fromJson(Map<String, Object?> json) {
    return TagSummary(
      id: json['id'] as int?,
      name: json['name'] as String,
      normalizedName: json['normalized_name'] as String?,
      galleryCount: json['gallery_count'] as int?,
    );
  }
}

class CategorySummary {
  const CategorySummary({
    required this.name,
    this.galleryCount,
  });

  final String name;
  final int? galleryCount;

  factory CategorySummary.fromJson(Map<String, Object?> json) {
    return CategorySummary(
      name: json['name'] as String,
      galleryCount: json['gallery_count'] as int?,
    );
  }
}

class TagPreview {
  const TagPreview({
    required this.tag,
    required this.imageIds,
  });

  final String tag;
  final List<int> imageIds;

  factory TagPreview.fromJson(Map<String, Object?> json) {
    return TagPreview(
      tag: json['tag'] as String,
      imageIds: (json['image_ids'] as List<dynamic>? ?? const <dynamic>[])
          .whereType<int>()
          .toList(),
    );
  }
}

const _unset = Object();
