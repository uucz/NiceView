import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../services/app_exceptions.dart';
import '../domain/image_query.dart';

final veilApiClientProvider = Provider<VeilApiClient>((ref) {
  return VeilApiClient();
});

class VeilImageResponse {
  const VeilImageResponse({
    required this.bytes,
    required this.contentType,
    this.imageId,
    this.galleryId,
    this.meta,
  });

  final List<int> bytes;
  final String? contentType;
  final int? imageId;
  final int? galleryId;
  final ImageMeta? meta;

  VeilImageResponse withMeta(ImageMeta meta) {
    return VeilImageResponse(
      bytes: bytes,
      contentType: contentType,
      imageId: imageId ?? meta.id,
      galleryId: galleryId ?? meta.gallery?.id,
      meta: meta,
    );
  }
}

class VeilApiClient {
  VeilApiClient() : _client = HttpClient() {
    _client.connectionTimeout = const Duration(seconds: 60);
    _client.idleTimeout = const Duration(seconds: 15);
  }

  static const _host = 'veil.ortlinde.com';
  static const _receiveTimeout = Duration(seconds: 90);

  final HttpClient _client;

  Future<VeilImageResponse> random({ImageQuery query = const ImageQuery()}) {
    return _imageRequest(
      '/v1/random',
      queryParameters: query.toQueryParameters(),
    );
  }

  Future<VeilImageResponse> imageById(int imageId) {
    return _imageRequest('/v1/image/$imageId');
  }

  Future<ImageMeta> randomMeta({ImageQuery query = const ImageQuery()}) async {
    final json = await _jsonRequest(
      '/v1/random/meta',
      queryParameters: query.toQueryParameters(),
    );
    return ImageMeta.fromJson(json);
  }

  Future<List<TagSummary>> featuredTags() async {
    final json = await _jsonRequest('/v1/featured-tags');
    return _items(json).map(TagSummary.fromJson).toList();
  }

  Future<List<TagSummary>> tags({
    int limit = 24,
    int offset = 0,
  }) async {
    final json = await _jsonRequest(
      '/v1/tags',
      queryParameters: {
        'limit': limit.toString(),
        'offset': offset.toString(),
      },
    );
    return _items(json).map(TagSummary.fromJson).toList();
  }

  Future<List<CategorySummary>> categories() async {
    final json = await _jsonRequest('/v1/categories');
    return _items(json).map(CategorySummary.fromJson).toList();
  }

  Future<TagPreview> tagPreview(String tag) async {
    final json = await _jsonRequest('/v1/tag/$tag/preview');
    return TagPreview.fromJson(json);
  }

  Future<VeilImageResponse> _imageRequest(
    String path, {
    Map<String, Object?>? queryParameters,
  }) async {
    final normalizedQuery = queryParameters?.map(
      (key, value) => MapEntry(key, value?.toString()),
    );
    final uri = Uri.https(_host, path, normalizedQuery);
    _log('GET $uri');

    late final HttpClientResponse response;
    try {
      final request = await _client.getUrl(uri).timeout(_receiveTimeout);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'image/*,*/*;q=0.8')
        ..set(HttpHeaders.userAgentHeader, 'NiceView/1.0');
      response = await request.close().timeout(_receiveTimeout);
    } on TimeoutException catch (error) {
      _log('request timeout: $error');
      throw const NiceViewException('网络请求超时，稍后再试');
    } on SocketException catch (error) {
      _log('socket error: $error');
      throw const NiceViewException('网络连接失败，稍后再试');
    } on HandshakeException catch (error) {
      _log('tls error: $error');
      throw const NiceViewException('安全连接失败，稍后再试');
    } on HttpException catch (error) {
      _log('http error: $error');
      throw NiceViewException(error.message);
    }

    final statusCode = response.statusCode;
    final contentType = response.headers.contentType?.mimeType ??
        response.headers.value(HttpHeaders.contentTypeHeader);
    _log('response $statusCode type=$contentType');

    late final List<int> bytes;
    try {
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(_receiveTimeout)) {
        builder.add(chunk);
      }
      bytes = builder.takeBytes();
      _log('received ${bytes.length} bytes');
    } on TimeoutException catch (error) {
      _log('body timeout: $error');
      throw const NiceViewException('图片下载超时，稍后再试');
    } on SocketException catch (error) {
      _log('body socket error: $error');
      throw const NiceViewException('图片下载中断，稍后再试');
    } on HttpException catch (error) {
      _log('body http error: $error');
      throw const NiceViewException('图片下载中断，稍后再试');
    }

    if (statusCode == 429) {
      throw const ServerLockoutException('请求太快了，请稍后再试');
    }
    if (statusCode == 404) {
      throw const ImageNotFoundException('图片不存在');
    }
    if (statusCode < 200 || statusCode >= 300) {
      throw NiceViewException('服务器暂时不可用：$statusCode');
    }

    if (bytes.isEmpty) {
      throw const NiceViewException('图片数据为空');
    }

    if (contentType != null && !contentType.startsWith('image/')) {
      throw const EmptyTagException('该标签暂时没有图片');
    }

    return VeilImageResponse(
      bytes: bytes,
      contentType: contentType,
      imageId: int.tryParse(response.headers.value('x-image-id') ?? ''),
      galleryId: int.tryParse(response.headers.value('x-gallery-id') ?? ''),
    );
  }

  Future<Map<String, Object?>> _jsonRequest(
    String path, {
    Map<String, Object?>? queryParameters,
  }) async {
    final normalizedQuery = queryParameters?.map(
      (key, value) => MapEntry(key, value?.toString()),
    );
    final uri = Uri.https(_host, path, normalizedQuery);
    _log('GET $uri');

    late final HttpClientResponse response;
    try {
      final request = await _client.getUrl(uri).timeout(_receiveTimeout);
      request.headers
        ..set(HttpHeaders.acceptHeader, 'application/json')
        ..set(HttpHeaders.userAgentHeader, 'NiceView/1.0');
      response = await request.close().timeout(_receiveTimeout);
    } on TimeoutException catch (error) {
      _log('json request timeout: $error');
      throw const NiceViewException('网络请求超时，稍后再试');
    } on SocketException catch (error) {
      _log('json socket error: $error');
      throw const NiceViewException('网络连接失败，稍后再试');
    } on HandshakeException catch (error) {
      _log('json tls error: $error');
      throw const NiceViewException('安全连接失败，稍后再试');
    } on HttpException catch (error) {
      _log('json http error: $error');
      throw NiceViewException(error.message);
    }

    final statusCode = response.statusCode;
    late final String body;
    try {
      body = await utf8.decodeStream(response).timeout(_receiveTimeout);
    } on TimeoutException catch (error) {
      _log('json body timeout: $error');
      throw const NiceViewException('响应读取超时，稍后再试');
    } on SocketException catch (error) {
      _log('json body socket error: $error');
      throw const NiceViewException('响应读取中断，稍后再试');
    } on HttpException catch (error) {
      _log('json body http error: $error');
      throw const NiceViewException('响应读取中断，稍后再试');
    }

    if (statusCode == 429) {
      throw const ServerLockoutException('请求太快了，请稍后再试');
    }
    if (statusCode == 404) {
      throw const ImageNotFoundException('内容不存在');
    }
    if (statusCode < 200 || statusCode >= 300) {
      throw NiceViewException('服务器暂时不可用：$statusCode');
    }

    try {
      return Map<String, Object?>.from(jsonDecode(body) as Map);
    } on FormatException catch (error) {
      _log('json decode error: $error');
      throw const NiceViewException('服务器返回数据格式异常');
    }
  }

  List<Map<String, Object?>> _items(Map<String, Object?> json) {
    return (json['items'] as List<dynamic>? ?? const <dynamic>[])
        .map((item) => Map<String, Object?>.from(item as Map))
        .toList();
  }

  void _log(String message) {
    if (kDebugMode) {
      debugPrint('[NiceView][VeilApi] $message');
    }
  }
}
