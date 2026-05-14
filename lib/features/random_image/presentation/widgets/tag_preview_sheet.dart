import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../app/theme.dart';
import '../../data/random_image_repository.dart';
import '../../domain/random_image.dart';

class TagPreviewSheet extends ConsumerStatefulWidget {
  const TagPreviewSheet({
    required this.tag,
    required this.onUseTag,
    super.key,
  });

  final String tag;
  final ValueChanged<String> onUseTag;

  @override
  ConsumerState<TagPreviewSheet> createState() => _TagPreviewSheetState();
}

class _TagPreviewSheetState extends ConsumerState<TagPreviewSheet> {
  late Future<List<RandomImage>> _future;

  @override
  void initState() {
    super.initState();
    _future = _load();
  }

  @override
  void didUpdateWidget(covariant TagPreviewSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.tag != widget.tag) {
      _future = _load();
    }
  }

  @override
  Widget build(BuildContext context) {
    final height = MediaQuery.sizeOf(context).height * 0.72;
    return SafeArea(
      child: SizedBox(
        height: height,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.tag,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: niceText,
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                    tooltip: '关闭',
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Expanded(
                child: FutureBuilder<List<RandomImage>>(
                  future: _future,
                  builder: (context, snapshot) {
                    if (snapshot.connectionState != ConnectionState.done) {
                      return const Center(
                        child: CircularProgressIndicator(strokeWidth: 2),
                      );
                    }
                    if (snapshot.hasError) {
                      return _PreviewError(onRetry: _retry);
                    }
                    final images = snapshot.data ?? const <RandomImage>[];
                    if (images.isEmpty) {
                      return const Center(
                        child: Text(
                          '暂无预览',
                          style: TextStyle(color: niceMuted),
                        ),
                      );
                    }
                    return GridView.builder(
                      itemCount: images.length,
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 3,
                        mainAxisSpacing: 8,
                        crossAxisSpacing: 8,
                        childAspectRatio: 0.72,
                      ),
                      itemBuilder: (context, index) {
                        final image = images[index];
                        return ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: ColoredBox(
                            color: Colors.white.withValues(alpha: 0.06),
                            child: Image.file(
                              File(image.localFilePath),
                              fit: BoxFit.cover,
                              errorBuilder: (_, __, ___) {
                                return const Center(
                                  child: Icon(
                                    Icons.broken_image_outlined,
                                    color: niceMuted,
                                  ),
                                );
                              },
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
              const SizedBox(height: 14),
              FilledButton(
                onPressed: () => widget.onUseTag(widget.tag),
                child: const Text('使用这个标签'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<List<RandomImage>> _load() {
    return ref.read(randomImageRepositoryProvider).tagPreviewImages(widget.tag);
  }

  void _retry() {
    setState(() => _future = _load());
  }
}

class _PreviewError extends StatelessWidget {
  const _PreviewError({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.broken_image_outlined, color: niceMuted, size: 32),
          const SizedBox(height: 10),
          const Text('预览加载失败', style: TextStyle(color: niceMuted)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: onRetry,
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重试'),
          ),
        ],
      ),
    );
  }
}
