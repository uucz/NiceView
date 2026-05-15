import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../../../services/app_exceptions.dart';
import '../data/random_image_repository.dart';
import '../domain/image_query.dart';
import 'random_image_controller.dart';
import 'widgets/tag_preview_sheet.dart';

enum _TagSort { count, name }

class TagBrowserPage extends ConsumerStatefulWidget {
  const TagBrowserPage({super.key});

  @override
  ConsumerState<TagBrowserPage> createState() => _TagBrowserPageState();
}

class _TagBrowserPageState extends ConsumerState<TagBrowserPage> {
  static const _pageSize = 50;

  final _searchController = TextEditingController();
  final _scrollController = ScrollController();
  final List<TagSummary> _loadedTags = <TagSummary>[];
  String _filter = '';
  _TagSort _sort = _TagSort.count;
  bool _isLoading = false;
  bool _hasNext = true;
  int _total = 0;
  int _offset = 0;
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
    final controller = ref.read(randomImageControllerProvider.notifier);
    final tags = _visibleTags();
    return Scaffold(
      backgroundColor: niceBlack,
      appBar: AppBar(
        backgroundColor: niceBlack,
        foregroundColor: niceText,
        title: const Text('标签浏览'),
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
                  textInputAction: TextInputAction.search,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search_rounded),
                    suffixIcon: _filter.isEmpty
                        ? null
                        : IconButton(
                            tooltip: '清空',
                            onPressed: _searchController.clear,
                            icon: const Icon(Icons.close_rounded),
                          ),
                    hintText: '筛选已加载标签，或输入标签名',
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.08),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(8),
                      borderSide: BorderSide.none,
                    ),
                  ),
                  onSubmitted: (value) => _useTypedTag(value),
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    ChoiceChip(
                      label: const Text('按热度'),
                      selected: _sort == _TagSort.count,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _sort = _TagSort.count),
                    ),
                    const SizedBox(width: 8),
                    ChoiceChip(
                      label: const Text('按名称'),
                      selected: _sort == _TagSort.name,
                      showCheckmark: false,
                      onSelected: (_) => setState(() => _sort = _TagSort.name),
                    ),
                    const Spacer(),
                    Text(
                      '${_loadedTags.length} / $_total',
                      style: const TextStyle(color: niceMuted, fontSize: 12),
                    ),
                  ],
                ),
                if (_filter.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () => _useTypedTag(_filter),
                        icon: const Icon(Icons.sell_rounded),
                        label: const Text('使用输入标签'),
                      ),
                      OutlinedButton.icon(
                        onPressed: () => controller.addTag(
                          _filter,
                          switchTo: false,
                        ),
                        icon: const Icon(Icons.playlist_add_rounded),
                        label: const Text('加入我的标签'),
                      ),
                    ],
                  ),
                ],
              ],
            ),
          ),
          if (_errorMessage != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: _InlineError(
                message: _errorMessage!,
                onRetry: _isLoading ? null : () => _loadMore(reset: false),
              ),
            ),
          Expanded(
            child: tags.isEmpty && !_isLoading
                ? const Center(
                    child: Text(
                      '没有匹配的已加载标签',
                      style: TextStyle(color: niceMuted),
                    ),
                  )
                : ListView.separated(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 18),
                    itemCount: tags.length + 1,
                    separatorBuilder: (_, __) => Divider(
                      height: 1,
                      color: Colors.white.withValues(alpha: 0.06),
                    ),
                    itemBuilder: (context, index) {
                      if (index == tags.length) {
                        return _LoadMoreRow(
                          isLoading: _isLoading,
                          hasNext: _hasNext,
                          onLoadMore:
                              _isLoading ? null : () => _loadMore(reset: false),
                        );
                      }
                      final tag = tags[index];
                      return _TagRow(
                        tag: tag,
                        onUse: () => _useTag(tag.name),
                        onPreview: () => _showPreview(tag.name),
                        onExclude: () => controller.toggleExcludedTag(tag.name),
                        onAdd: () => controller.addTag(
                          tag.name,
                          switchTo: false,
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  List<TagSummary> _visibleTags() {
    final needle = _filter.toLowerCase();
    final filtered = _loadedTags.where((tag) {
      if (needle.isEmpty) {
        return true;
      }
      return tag.name.toLowerCase().contains(needle) ||
          (tag.normalizedName?.toLowerCase().contains(needle) ?? false);
    }).toList();
    filtered.sort((a, b) {
      return switch (_sort) {
        _TagSort.name => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        _TagSort.count =>
          (b.galleryCount ?? 0).compareTo(a.galleryCount ?? 0),
      };
    });
    return filtered;
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
        _loadedTags.clear();
        _offset = 0;
        _hasNext = true;
      }
    });

    try {
      final page = await ref.read(randomImageRepositoryProvider).tagsPage(
            limit: _pageSize,
            offset: _offset,
          );
      if (!mounted) {
        return;
      }
      final seen = _loadedTags.map((tag) => tag.name.toLowerCase()).toSet();
      setState(() {
        _loadedTags.addAll(
          page.items.where((tag) => seen.add(tag.name.toLowerCase())),
        );
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
    final position = _scrollController.position;
    if (position.extentAfter < 560) {
      unawaited(_loadMore(reset: false));
    }
  }

  Future<void> _showPreview(String tag) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF17181A),
      builder: (context) => TagPreviewSheet(
        tag: tag,
        onUseTag: (tag) {
          Navigator.of(context).pop();
          _useTag(tag);
        },
      ),
    );
  }

  void _useTypedTag(String value) {
    final tag = value.trim();
    if (tag.isEmpty) {
      return;
    }
    _useTag(tag);
  }

  void _useTag(String tag) {
    ref.read(randomImageControllerProvider.notifier).switchTag(tag);
    Navigator.of(context).pop();
  }

  String _messageForError(Object error) {
    if (error is NiceViewException) {
      return error.message;
    }
    return '标签加载失败';
  }
}

class _TagRow extends StatelessWidget {
  const _TagRow({
    required this.tag,
    required this.onUse,
    required this.onPreview,
    required this.onExclude,
    required this.onAdd,
  });

  final TagSummary tag;
  final VoidCallback onUse;
  final VoidCallback onPreview;
  final VoidCallback onExclude;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: '标签 ${tag.name}',
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        title: Text(
          tag.name,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(color: niceText, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          tag.galleryCount == null ? '图集数未知' : '${tag.galleryCount} 个图集',
          style: const TextStyle(color: niceMuted, fontSize: 12),
        ),
        onTap: onUse,
        trailing: Wrap(
          spacing: 2,
          children: [
            IconButton(
              tooltip: '预览',
              onPressed: onPreview,
              icon: const Icon(Icons.grid_view_rounded),
            ),
            PopupMenuButton<_TagAction>(
              tooltip: '更多操作',
              icon: const Icon(Icons.more_horiz_rounded),
              onSelected: (action) {
                switch (action) {
                  case _TagAction.use:
                    onUse();
                    break;
                  case _TagAction.preview:
                    onPreview();
                    break;
                  case _TagAction.exclude:
                    onExclude();
                    break;
                  case _TagAction.add:
                    onAdd();
                    break;
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _TagAction.use,
                  child: Text('使用标签'),
                ),
                PopupMenuItem(
                  value: _TagAction.preview,
                  child: Text('预览标签'),
                ),
                PopupMenuItem(
                  value: _TagAction.exclude,
                  child: Text('加入排除'),
                ),
                PopupMenuItem(
                  value: _TagAction.add,
                  child: Text('加入我的标签'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

enum _TagAction { use, preview, exclude, add }

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
