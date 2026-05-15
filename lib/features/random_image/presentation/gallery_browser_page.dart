import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../services/app_exceptions.dart';
import '../data/random_image_repository.dart';
import '../domain/image_query.dart';
import 'gallery_detail_page.dart';

class GalleryBrowserPage extends ConsumerStatefulWidget {
  const GalleryBrowserPage({super.key});

  @override
  ConsumerState<GalleryBrowserPage> createState() => _GalleryBrowserPageState();
}

class _GalleryBrowserPageState extends ConsumerState<GalleryBrowserPage> {
  static const _pageSize = 30;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final List<GallerySummary> _galleries = <GallerySummary>[];
  String _filter = '';
  bool _isLoading = false;
  bool _hasNext = true;
  int _offset = 0;
  int _total = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _filter = _searchController.text.trim());
    });
    _scrollController.addListener(_maybeLoadMore);
    unawaited(_loadMore(reset: true));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final galleries = _visibleGalleries();
    return Scaffold(
      backgroundColor: niceBlack,
      appBar: AppBar(
        backgroundColor: niceBlack,
        foregroundColor: niceText,
        title: const Text('图集'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _isLoading ? null : () => _loadMore(reset: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(
                  controller: _searchController,
                  style: const TextStyle(color: niceText),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _filter.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空',
                            onPressed: _searchController.clear,
                            icon: const Icon(Icons.close_rounded),
                          ),
                    hintText: '筛选已加载图集标题',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '已加载 ${_galleries.length} / $_total',
                  style: const TextStyle(color: niceMuted, fontSize: 12),
                ),
              ],
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
              child: _InlineError(
                message: _errorMessage!,
                onRetry: _isLoading ? null : () => _loadMore(reset: false),
              ),
            ),
          Expanded(
            child: galleries.isEmpty && !_isLoading
                ? const Center(
                    child: Text(
                      '没有匹配的已加载图集',
                      style: TextStyle(color: niceMuted),
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
                    itemCount: galleries.length + 1,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    itemBuilder: (context, index) {
                      if (index == galleries.length) {
                        return _LoadMoreRow(
                          isLoading: _isLoading,
                          hasNext: _hasNext,
                          onLoadMore:
                              _isLoading ? null : () => _loadMore(reset: false),
                        );
                      }
                      final gallery = galleries[index];
                      return _GalleryRow(
                        gallery: gallery,
                        onOpen: () => _openGallery(gallery),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<GallerySummary> _visibleGalleries() {
    final needle = _filter.toLowerCase();
    if (needle.isEmpty) {
      return List<GallerySummary>.from(_galleries);
    }
    return _galleries.where((gallery) {
      return gallery.title.toLowerCase().contains(needle) ||
          (gallery.category?.toLowerCase().contains(needle) ?? false);
    }).toList();
  }

  Future<void> _loadMore({required bool reset}) async {
    if (_isLoading) {
      return;
    }
    if (!reset && !_hasNext) {
      return;
    }
    setState(() {
      _isLoading = true;
      _errorMessage = null;
      if (reset) {
        _galleries.clear();
        _offset = 0;
        _hasNext = true;
      }
    });

    try {
      final page = await ref.read(randomImageRepositoryProvider).galleries(
            limit: _pageSize,
            offset: _offset,
          );
      if (!mounted) {
        return;
      }
      final seen = _galleries.map((gallery) => gallery.id).toSet();
      setState(() {
        _galleries.addAll(page.items.where((gallery) => seen.add(gallery.id)));
        _offset = page.offset + page.limit;
        _total = page.total;
        _hasNext = page.hasNext;
      });
    } catch (error) {
      if (mounted) {
        setState(() => _errorMessage = _messageForError(error));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients || _isLoading || !_hasNext) {
      return;
    }
    if (_scrollController.position.extentAfter < 720) {
      unawaited(_loadMore(reset: false));
    }
  }

  Future<void> _openGallery(GallerySummary gallery) {
    return Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GalleryDetailPage(
          galleryId: gallery.id,
          initialTitle: gallery.title,
        ),
      ),
    );
  }

  String _messageForError(Object error) {
    if (error is NiceViewException) {
      return error.message;
    }
    return '图集加载失败';
  }
}

class _GalleryRow extends StatelessWidget {
  const _GalleryRow({
    required this.gallery,
    required this.onOpen,
  });

  final GallerySummary gallery;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    final count = gallery.imageCount > 0
        ? '${gallery.imageCount} 张'
        : '图片数未知';
    return Semantics(
      button: true,
      label: '图集 ${gallery.title}',
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        leading: Container(
          width: 48,
          height: 64,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: const Icon(Icons.photo_library_rounded, color: niceMuted),
        ),
        title: Text(
          gallery.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: niceText, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          [
            if (gallery.category != null) gallery.category!,
            count,
            if (gallery.uploadedImages > 0) '已上传 ${gallery.uploadedImages}',
          ].join(' · '),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: niceMuted, fontSize: 12),
        ),
        trailing: const Icon(Icons.chevron_right_rounded),
        onTap: onOpen,
      ),
    );
  }
}

class _LoadMoreRow extends StatelessWidget {
  const _LoadMoreRow({
    required this.isLoading,
    required this.hasNext,
    required this.onLoadMore,
  });

  final bool isLoading;
  final bool hasNext;
  final VoidCallback? onLoadMore;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: SizedBox.square(
            dimension: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }
    if (!hasNext) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
        child: Center(
          child: Text('已加载到底', style: TextStyle(color: niceMuted)),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 14),
      child: Center(
        child: OutlinedButton.icon(
          onPressed: onLoadMore,
          icon: const Icon(Icons.expand_more_rounded),
          label: const Text('加载更多'),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({
    required this.message,
    required this.onRetry,
  });

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Icon(Icons.error_outline_rounded, color: niceDanger, size: 18),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            message,
            style: const TextStyle(color: niceMuted, fontSize: 12),
          ),
        ),
        TextButton(
          onPressed: onRetry,
          child: const Text('重试'),
        ),
      ],
    );
  }
}
