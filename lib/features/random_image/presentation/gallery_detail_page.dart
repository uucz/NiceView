import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../services/app_exceptions.dart';
import '../data/random_image_repository.dart';
import '../domain/image_query.dart';
import '../domain/random_image.dart';
import 'random_image_controller.dart';

class GalleryDetailPage extends ConsumerStatefulWidget {
  const GalleryDetailPage({
    required this.galleryId,
    this.initialTitle,
    super.key,
  });

  final int galleryId;
  final String? initialTitle;

  @override
  ConsumerState<GalleryDetailPage> createState() => _GalleryDetailPageState();
}

class _GalleryDetailPageState extends ConsumerState<GalleryDetailPage> {
  static const _pageSize = 18;

  final _scrollController = ScrollController();
  final List<GalleryImageSummary> _images = <GalleryImageSummary>[];
  final Map<int, Future<RandomImage>> _imageFutures =
      <int, Future<RandomImage>>{};
  GalleryDetail? _detail;
  bool _isLoading = false;
  bool _hasNext = true;
  int _imageOffset = 0;
  int _totalImages = 0;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_maybeLoadMore);
    unawaited(_loadMore(reset: true));
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final title = detail?.title ?? widget.initialTitle ?? '图集';
    return Scaffold(
      backgroundColor: niceBlack,
      appBar: AppBar(
        backgroundColor: niceBlack,
        foregroundColor: niceText,
        title: Text(
          title,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: _isLoading ? null : () => _loadMore(reset: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverToBoxAdapter(
            child: _GalleryHeader(
              detail: detail,
              loadedCount: _images.length,
              totalImages: _totalImages,
              errorMessage: _errorMessage,
              onRetry: _isLoading ? null : () => _loadMore(reset: false),
            ),
          ),
          if (_images.isEmpty && !_isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: Center(
                child: Text('这个图集暂时没有可浏览图片', style: TextStyle(color: niceMuted)),
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
              sliver: SliverGrid(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 3,
                  mainAxisSpacing: 8,
                  crossAxisSpacing: 8,
                  childAspectRatio: 0.72,
                ),
                delegate: SliverChildBuilderDelegate(
                  (context, index) {
                    final image = _images[index];
                    return _GalleryImageTile(
                      summary: image,
                      future: _imageFutureFor(image),
                      onRetry: () {
                        setState(() => _imageFutures.remove(image.id));
                      },
                      onUse: _useImage,
                    );
                  },
                  childCount: _images.length,
                ),
              ),
            ),
          SliverToBoxAdapter(
            child: _LoadMoreRow(
              isLoading: _isLoading,
              hasNext: _hasNext,
              onLoadMore: _isLoading ? null : () => _loadMore(reset: false),
            ),
          ),
        ],
      ),
    );
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
        _detail = null;
        _images.clear();
        _imageFutures.clear();
        _imageOffset = 0;
        _hasNext = true;
      }
    });

    try {
      final detail = await ref.read(randomImageRepositoryProvider).gallery(
            widget.galleryId,
            imageLimit: _pageSize,
            imageOffset: _imageOffset,
          );
      if (!mounted) {
        return;
      }
      final seen = _images.map((image) => image.id).toSet();
      setState(() {
        _detail = detail;
        _images.addAll(detail.images.where((image) => seen.add(image.id)));
        _imageOffset = detail.imagePage.offset + detail.imagePage.limit;
        _totalImages = detail.imagePage.total;
        _hasNext = detail.imagePage.hasNext;
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

  Future<RandomImage> _imageFutureFor(GalleryImageSummary summary) {
    return _imageFutures.putIfAbsent(summary.id, () async {
      final detail = _detail;
      final image = await ref.read(randomImageRepositoryProvider).fetchImageById(
            summary.id,
            queryKey: 'gallery:${widget.galleryId}',
          );
      return image.copyWith(
        galleryId: widget.galleryId,
        width: summary.width,
        height: summary.height,
        orientation: summary.orientation,
        galleryTitle: detail?.title ?? widget.initialTitle,
        galleryCategory: detail?.category,
        tags: detail?.tags,
      );
    });
  }

  void _maybeLoadMore() {
    if (!_scrollController.hasClients || _isLoading || !_hasNext) {
      return;
    }
    if (_scrollController.position.extentAfter < 720) {
      unawaited(_loadMore(reset: false));
    }
  }

  void _useImage(RandomImage image) {
    ref.read(randomImageControllerProvider.notifier).useRandomImage(image);
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  String _messageForError(Object error) {
    if (error is NiceViewException) {
      return error.message;
    }
    return '图集加载失败';
  }
}

class _GalleryHeader extends StatelessWidget {
  const _GalleryHeader({
    required this.detail,
    required this.loadedCount,
    required this.totalImages,
    required this.errorMessage,
    required this.onRetry,
  });

  final GalleryDetail? detail;
  final int loadedCount;
  final int totalImages;
  final String? errorMessage;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final detail = this.detail;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (detail != null) ...[
            Text(
              [
                if (detail.category != null) detail.category!,
                '${loadedCount}/${totalImages == 0 ? detail.imageCount : totalImages} 张',
              ].join(' · '),
              style: const TextStyle(color: niceMuted, fontSize: 12),
            ),
            if (detail.tags.isNotEmpty) ...[
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: detail.tags.take(12).map((tag) {
                  return Chip(
                    label: Text(tag),
                    visualDensity: VisualDensity.compact,
                  );
                }).toList(),
              ),
            ],
          ],
          if (errorMessage != null) ...[
            const SizedBox(height: 8),
            Row(
              children: [
                const Icon(
                  Icons.error_outline_rounded,
                  color: niceDanger,
                  size: 18,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    errorMessage!,
                    style: const TextStyle(color: niceMuted, fontSize: 12),
                  ),
                ),
                TextButton(onPressed: onRetry, child: const Text('重试')),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _GalleryImageTile extends StatelessWidget {
  const _GalleryImageTile({
    required this.summary,
    required this.future,
    required this.onRetry,
    required this.onUse,
  });

  final GalleryImageSummary summary;
  final Future<RandomImage> future;
  final VoidCallback onRetry;
  final ValueChanged<RandomImage> onUse;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<RandomImage>(
      future: future,
      builder: (context, snapshot) {
        final image = snapshot.data;
        return Semantics(
          button: image != null,
          label: '图集图片 ${summary.sortOrder ?? summary.id}',
          child: Material(
            color: Colors.white.withValues(alpha: 0.06),
            borderRadius: BorderRadius.circular(8),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: image == null ? null : () => onUse(image),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  if (image != null)
                    Image.file(
                      File(image.localFilePath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const _TileIcon(
                        icon: Icons.broken_image_outlined,
                      ),
                    )
                  else if (snapshot.hasError)
                    _TileError(onRetry: onRetry)
                  else
                    const Center(
                      child: SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    ),
                  Positioned(
                    left: 6,
                    top: 6,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: Colors.black.withValues(alpha: 0.46),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 3,
                        ),
                        child: Text(
                          '#${summary.sortOrder ?? summary.id}',
                          style: const TextStyle(
                            color: niceText,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

class _TileError extends StatelessWidget {
  const _TileError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: IconButton(
        tooltip: '重试',
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded),
        color: niceMuted,
      ),
    );
  }
}

class _TileIcon extends StatelessWidget {
  const _TileIcon({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(child: Icon(icon, color: niceMuted));
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
