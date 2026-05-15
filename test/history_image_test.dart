import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:nice_view/features/random_image/data/random_image_repository.dart';
import 'package:nice_view/features/random_image/domain/history_image.dart';
import 'package:nice_view/features/random_image/domain/image_query.dart';
import 'package:nice_view/features/random_image/domain/random_image.dart';
import 'package:nice_view/services/download_service.dart';

void main() {
  test('empty history list can be sorted by callers', () {
    final images = HistoryImage.listFromJsonString(null);

    expect(images, isEmpty);
    expect(() => images.sort((a, b) => b.viewedAt.compareTo(a.viewedAt)),
        returnsNormally);
  });

  test('history list parses persisted json', () {
    final fetchedAt = DateTime(2026, 5, 14, 2, 30);
    final viewedAt = DateTime(2026, 5, 14, 2, 31);
    final value = jsonEncode([
      {
        'historyId': '42',
        'localFilePath': '/tmp/nice_view_42.jpg',
        'imageId': 42,
        'galleryId': 7,
        'contentType': 'image/jpeg',
        'sourceTag': 'city',
        'fetchedAt': fetchedAt.toIso8601String(),
        'viewedAt': viewedAt.toIso8601String(),
      },
    ]);

    final images = HistoryImage.listFromJsonString(value);

    expect(images.single.historyId, '42');
    expect(images.single.imageId, 42);
    expect(images.single.viewedAt, viewedAt);
  });

  test('content type maps to stable image extensions', () {
    expect(extensionForContentType('image/png'), '.png');
    expect(extensionForContentType('image/webp; charset=utf-8'), '.webp');
    expect(extensionForContentType('image/gif'), '.gif');
    expect(extensionForContentType(null), '.jpg');
  });

  test('preload queue images parse persisted json', () {
    final fetchedAt = DateTime(2026, 5, 14, 5, 10);
    final value = jsonEncode([
      {
        'localFilePath': '/tmp/preload_99.jpg',
        'imageId': 99,
        'galleryId': 11,
        'contentType': 'image/jpeg',
        'sourceTag': '原神',
        'fetchedAt': fetchedAt.toIso8601String(),
      },
    ]);

    final images = RandomImage.listFromJsonString(value);

    expect(images.single.imageId, 99);
    expect(images.single.sourceTag, '原神');
    expect(images.single.fetchedAt, fetchedAt);
  });

  test('download destinations identify system photo libraries', () {
    expect(
      DownloadService.isSystemPhotoDestination(
        'content://media/external/images/media/42',
      ),
      isTrue,
    );
    expect(
      DownloadService.isSystemPhotoDestination('photos://saved'),
      isTrue,
    );
    expect(
      DownloadService.isSystemPhotoDestination('/tmp/nice_view_42.jpg'),
      isFalse,
    );
  });

  test('image query encodes filters and stable cache keys', () {
    const query = ImageQuery(
      tag: '原神',
      orientation: ImageOrientation.portrait,
      category: 'Cosplay',
      excludeTags: ['AI Generated'],
    );

    expect(query.toQueryParameters(), {
      'tag': '原神',
      'orientation': 'portrait',
      'category': 'Cosplay',
      'exclude_tag': 'AI Generated',
    });
    expect(
      query.cacheKey,
      'category=Cosplay&exclude_tag=AI Generated&orientation=portrait&tag=原神',
    );
    expect(query.summary, '原神 / 竖图 / Cosplay / 已排除 1');
  });

  test('image metadata parses gallery and tags', () {
    final meta = ImageMeta.fromJson({
      'id': 53778,
      'width': 1200,
      'height': 800,
      'orientation': 'landscape',
      'sort_order': 15,
      'gallery': {
        'id': 921,
        'title': 'MetArt Yanika',
        'category': 'Europe',
      },
      'tags': ['Metart', 'Veto'],
    });

    expect(meta.id, 53778);
    expect(meta.orientation, ImageOrientation.landscape);
    expect(meta.gallery?.category, 'Europe');
    expect(meta.tags, ['Metart', 'Veto']);
  });

  test('gallery summary parses cover metadata', () {
    final gallery = GallerySummary.fromJson({
      'id': 62942,
      'title': 'XiuRen No.4948',
      'series_number': 'No.4948',
      'category': 'XiuRen',
      'image_count': 53,
      'uploaded_images': 12,
      'updated_at': '2026-05-14T00:04:30.583210+00:00',
      'cover': {
        'image_id': 3442205,
        'width': 1200,
        'height': 1800,
        'orientation': 'portrait',
      },
    });

    expect(gallery.id, 62942);
    expect(gallery.cover?.imageId, 3442205);
    expect(gallery.cover?.orientation, ImageOrientation.portrait);
    expect(gallery.imageCount, 53);
  });

  test('gallery detail parses image pagination without external fields', () {
    final detail = GalleryDetail.fromJson({
      'id': 921,
      'title': 'MetArt Yanika',
      'category': 'Europe',
      'image_count': 62,
      'cover_image_id': 53764,
      'source_page_url': 'https://example.invalid/source',
      'download_links': [
        {'url': 'https://example.invalid/download'},
      ],
      'attachments': [
        {'url': 'https://example.invalid/file'},
      ],
      'tags': ['Metart', 'Veto'],
      'images': [
        {
          'id': 53764,
          'sort_order': 1,
          'width': 1200,
          'height': 1800,
          'orientation': 'portrait',
          'file_size_bytes': 223611,
          'status': 'active',
          'uploaded': true,
        },
      ],
      'images_pagination': {
        'total': 62,
        'limit': 1,
        'offset': 0,
        'has_next': true,
      },
    });

    expect(detail.id, 921);
    expect(detail.tags, ['Metart', 'Veto']);
    expect(detail.images.single.id, 53764);
    expect(detail.images.single.orientation, ImageOrientation.portrait);
    expect(detail.imagePage.total, 62);
    expect(detail.hasMoreImages, isTrue);
  });
}
