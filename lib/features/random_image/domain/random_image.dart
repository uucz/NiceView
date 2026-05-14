import 'dart:convert';
import 'dart:io';

import 'image_query.dart';

class RandomImage {
  const RandomImage({
    required this.localFilePath,
    required this.fetchedAt,
    this.imageId,
    this.galleryId,
    this.contentType,
    this.sourceTag,
    this.queryKey,
    this.width,
    this.height,
    this.orientation,
    this.galleryTitle,
    this.galleryCategory,
    this.tags = const <String>[],
  });

  final String localFilePath;
  final int? imageId;
  final int? galleryId;
  final String? contentType;
  final String? sourceTag;
  final String? queryKey;
  final int? width;
  final int? height;
  final ImageOrientation? orientation;
  final String? galleryTitle;
  final String? galleryCategory;
  final List<String> tags;
  final DateTime fetchedAt;

  File get file => File(localFilePath);

  String get displayId => imageId?.toString() ?? '本地图片';

  RandomImage copyWith({
    String? localFilePath,
    int? imageId,
    int? galleryId,
    String? contentType,
    String? sourceTag,
    String? queryKey,
    int? width,
    int? height,
    ImageOrientation? orientation,
    String? galleryTitle,
    String? galleryCategory,
    List<String>? tags,
    DateTime? fetchedAt,
  }) {
    return RandomImage(
      localFilePath: localFilePath ?? this.localFilePath,
      imageId: imageId ?? this.imageId,
      galleryId: galleryId ?? this.galleryId,
      contentType: contentType ?? this.contentType,
      sourceTag: sourceTag ?? this.sourceTag,
      queryKey: queryKey ?? this.queryKey,
      width: width ?? this.width,
      height: height ?? this.height,
      orientation: orientation ?? this.orientation,
      galleryTitle: galleryTitle ?? this.galleryTitle,
      galleryCategory: galleryCategory ?? this.galleryCategory,
      tags: tags ?? this.tags,
      fetchedAt: fetchedAt ?? this.fetchedAt,
    );
  }

  Map<String, Object?> toJson() {
    return {
      'localFilePath': localFilePath,
      'imageId': imageId,
      'galleryId': galleryId,
      'contentType': contentType,
      'sourceTag': sourceTag,
      'queryKey': queryKey,
      'width': width,
      'height': height,
      'orientation': orientation?.apiValue,
      'galleryTitle': galleryTitle,
      'galleryCategory': galleryCategory,
      'tags': tags,
      'fetchedAt': fetchedAt.toIso8601String(),
    };
  }

  static RandomImage fromJson(Map<String, Object?> json) {
    return RandomImage(
      localFilePath: json['localFilePath'] as String,
      imageId: json['imageId'] as int?,
      galleryId: json['galleryId'] as int?,
      contentType: json['contentType'] as String?,
      sourceTag: json['sourceTag'] as String?,
      queryKey: json['queryKey'] as String?,
      width: json['width'] as int?,
      height: json['height'] as int?,
      orientation:
          ImageOrientation.fromApiValue(json['orientation'] as String?),
      galleryTitle: json['galleryTitle'] as String?,
      galleryCategory: json['galleryCategory'] as String?,
      tags: (json['tags'] as List<dynamic>? ?? const <dynamic>[])
          .map((item) => item.toString())
          .toList(),
      fetchedAt: DateTime.parse(json['fetchedAt'] as String),
    );
  }

  static List<RandomImage> listFromJsonString(String? value) {
    if (value == null || value.isEmpty) {
      return <RandomImage>[];
    }
    final decoded = jsonDecode(value) as List<dynamic>;
    return decoded.map((item) {
      return RandomImage.fromJson(Map<String, Object?>.from(item as Map));
    }).toList();
  }
}
