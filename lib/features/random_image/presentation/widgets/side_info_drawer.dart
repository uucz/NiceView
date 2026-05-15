import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/image_query.dart';
import '../../domain/quota_state.dart';
import '../random_image_controller.dart';
import 'quota_bar.dart';
import 'tag_strip.dart';

class SideInfoDrawer extends StatefulWidget {
  const SideInfoDrawer({
    required this.state,
    required this.quota,
    required this.onTagSelected,
    required this.onAddTag,
    required this.onDeleteTag,
    required this.onOrientationSelected,
    required this.onCategorySelected,
    required this.onPreviewTag,
    required this.onToggleExcludeTag,
    required this.onClearFilters,
    required this.onOpenHistory,
    required this.onOpenTagBrowser,
    required this.onOpenGalleries,
    required this.onOpenGallery,
    required this.onOpenSettings,
    required this.onSaveDefaultQuery,
    required this.onClearDefaultQuery,
    required this.onAddUserTag,
    super.key,
  });

  final RandomImageViewState state;
  final QuotaState quota;
  final ValueChanged<String?> onTagSelected;
  final VoidCallback onAddTag;
  final ValueChanged<String> onDeleteTag;
  final ValueChanged<ImageOrientation?> onOrientationSelected;
  final ValueChanged<String?> onCategorySelected;
  final ValueChanged<String> onPreviewTag;
  final ValueChanged<String> onToggleExcludeTag;
  final VoidCallback onClearFilters;
  final VoidCallback onOpenHistory;
  final VoidCallback onOpenTagBrowser;
  final VoidCallback onOpenGalleries;
  final ValueChanged<int> onOpenGallery;
  final VoidCallback onOpenSettings;
  final VoidCallback onSaveDefaultQuery;
  final VoidCallback onClearDefaultQuery;
  final ValueChanged<String> onAddUserTag;

  @override
  State<SideInfoDrawer> createState() => _SideInfoDrawerState();
}

class _SideInfoDrawerState extends State<SideInfoDrawer> {
  late final TextEditingController _searchController;
  String _tagSearch = '';

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController()
      ..addListener(() {
        setState(() => _tagSearch = _searchController.text.trim());
      });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = widget.state;
    final image = state.currentImage;
    return Material(
      color: const Color(0xFF151618),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 24),
          children: [
            _SectionTitle(
              title: '当前筛选',
              trailing: state.query.summary,
              onClear: state.query.isEmpty ? null : widget.onClearFilters,
            ),
            const SizedBox(height: 16),
            QuotaBar(quota: widget.quota),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onSaveDefaultQuery,
                    icon: const Icon(Icons.bookmark_add_rounded),
                    label: const Text('保存默认'),
                    style: _outlinedStyle(),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: widget.onClearDefaultQuery,
                    icon: const Icon(Icons.restart_alt_rounded),
                    label: const Text('清除默认'),
                    style: _outlinedStyle(),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            const _SectionLabel('方向'),
            const SizedBox(height: 10),
            _DirectionFilter(
              selected: state.query.orientation,
              onSelected: widget.onOrientationSelected,
            ),
            const SizedBox(height: 22),
            const _SectionLabel('分类'),
            const SizedBox(height: 10),
            _CategoryFilter(
              categories: state.categories,
              selected: state.query.category,
              onSelected: widget.onCategorySelected,
            ),
            const SizedBox(height: 22),
            const _SectionLabel('我的标签'),
            const SizedBox(height: 10),
            TagStrip(
              tags: state.userTags,
              selectedTag: state.selectedTag,
              onSelected: widget.onTagSelected,
              onDelete: widget.onDeleteTag,
            ),
            const SizedBox(height: 14),
            OutlinedButton.icon(
              onPressed: widget.onAddTag,
              icon: const Icon(Icons.add_rounded),
              label: const Text('添加标签'),
              style: _outlinedStyle(),
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: _SectionLabel('探索')),
                if (state.isDiscoveryLoading)
                  const SizedBox.square(
                    dimension: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: widget.onOpenTagBrowser,
              icon: const Icon(Icons.sell_rounded),
              label: const Text('打开完整标签浏览'),
              style: _outlinedStyle(),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _searchController,
              style: const TextStyle(color: niceText),
              decoration: InputDecoration(
                prefixIcon: const Icon(Icons.search_rounded),
                hintText: '筛选标签',
                filled: true,
                fillColor: Colors.white.withValues(alpha: 0.08),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
            const SizedBox(height: 12),
            _DiscoveryTags(
              tags: _visibleDiscoveryTags(state),
              selectedTag: state.selectedTag,
              excludedTags: state.query.excludeTags,
              onSelected: widget.onTagSelected,
              onPreview: widget.onPreviewTag,
              onToggleExclude: widget.onToggleExcludeTag,
            ),
            const SizedBox(height: 22),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.history_rounded, color: niceMuted),
              title: const Text('浏览历史'),
              subtitle: Text(
                '${state.historyImages.length} / ${state.historyLimit}  ·  收藏 ${state.favoriteImages.length}',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: widget.onOpenHistory,
              textColor: niceText,
              iconColor: niceMuted,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading:
                  const Icon(Icons.photo_library_rounded, color: niceMuted),
              title: const Text('图集浏览'),
              subtitle: const Text('按图集继续看同一组图片'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: widget.onOpenGalleries,
              textColor: niceText,
              iconColor: niceMuted,
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.settings_rounded, color: niceMuted),
              title: const Text('设置与数据'),
              subtitle: const Text('缓存、历史上限和默认偏好'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: widget.onOpenSettings,
              textColor: niceText,
              iconColor: niceMuted,
            ),
            const SizedBox(height: 20),
            const _SectionLabel('当前图片'),
            const SizedBox(height: 10),
            _InfoRow(label: '筛选', value: state.query.summary),
            _InfoRow(label: 'Image ID', value: image?.imageId?.toString()),
            _InfoRow(label: 'Gallery ID', value: image?.galleryId?.toString()),
            _InfoRow(label: '方向', value: image?.orientation?.label),
            _InfoRow(label: '尺寸', value: _formatSize(image?.width, image?.height)),
            _InfoRow(label: '分类', value: image?.galleryCategory),
            if (image?.galleryId != null && image?.galleryTitle != null)
              _GalleryInfoRow(
                title: image!.galleryTitle!,
                onOpen: () => widget.onOpenGallery(image.galleryId!),
              )
            else
              _InfoRow(label: '图集', value: image?.galleryTitle),
            _InfoRow(label: 'Content-Type', value: image?.contentType),
            _InfoRow(label: '获取时间', value: _formatTime(image?.fetchedAt)),
            if (image != null && image.tags.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: image.tags.take(8).map((tag) {
                  return ActionChip(
                    label: Text(tag),
                    avatar: const Icon(Icons.more_horiz_rounded, size: 16),
                    onPressed: () => _showImageTagActions(context, tag),
                    backgroundColor: Colors.white.withValues(alpha: 0.08),
                    side: BorderSide(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  );
                }).toList(),
              ),
            ],
            if (state.isPreloading) ...[
              const SizedBox(height: 16),
              const LinearProgressIndicator(minHeight: 2),
            ],
          ],
        ),
      ),
    );
  }

  List<TagSummary> _visibleDiscoveryTags(RandomImageViewState state) {
    final tags = <TagSummary>[];
    final seen = <String>{};
    for (final tag in [...state.featuredTags, ...state.popularTags]) {
      final key = tag.name.toLowerCase();
      if (seen.add(key)) {
        tags.add(tag);
      }
    }
    if (_tagSearch.isEmpty) {
      return tags.take(18).toList();
    }
    final needle = _tagSearch.toLowerCase();
    return tags
        .where((tag) =>
            tag.name.toLowerCase().contains(needle) ||
            (tag.normalizedName?.toLowerCase().contains(needle) ?? false))
        .take(24)
        .toList();
  }

  String? _formatSize(int? width, int? height) {
    if (width == null || height == null) {
      return null;
    }
    return '$width x $height';
  }

  String? _formatTime(DateTime? value) {
    if (value == null) {
      return null;
    }
    String two(int number) => number.toString().padLeft(2, '0');
    return '${two(value.hour)}:${two(value.minute)}:${two(value.second)}';
  }

  ButtonStyle _outlinedStyle() {
    return OutlinedButton.styleFrom(
      foregroundColor: niceText,
      side: BorderSide(color: Colors.white.withValues(alpha: 0.16)),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Future<void> _showImageTagActions(BuildContext context, String tag) async {
    final excluded = widget.state.query.excludeTags.any(
      (item) => item.toLowerCase() == tag.toLowerCase(),
    );
    final action = await showModalBottomSheet<_ImageTagAction>(
      context: context,
      backgroundColor: const Color(0xFF17181A),
      builder: (context) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(tag, overflow: TextOverflow.ellipsis),
                textColor: niceText,
              ),
              ListTile(
                leading: const Icon(Icons.sell_rounded),
                title: const Text('使用标签'),
                onTap: () => Navigator.of(context).pop(_ImageTagAction.use),
              ),
              ListTile(
                leading: const Icon(Icons.grid_view_rounded),
                title: const Text('预览标签'),
                onTap: () => Navigator.of(context).pop(_ImageTagAction.preview),
              ),
              ListTile(
                leading: Icon(
                  excluded
                      ? Icons.visibility_rounded
                      : Icons.visibility_off_rounded,
                ),
                title: Text(excluded ? '取消排除' : '加入排除'),
                onTap: () => Navigator.of(context).pop(_ImageTagAction.exclude),
              ),
              ListTile(
                leading: const Icon(Icons.playlist_add_rounded),
                title: const Text('加入我的标签'),
                onTap: () => Navigator.of(context).pop(_ImageTagAction.add),
              ),
            ],
          ),
        );
      },
    );
    if (!mounted || action == null) {
      return;
    }
    switch (action) {
      case _ImageTagAction.use:
        widget.onTagSelected(tag);
        break;
      case _ImageTagAction.preview:
        widget.onPreviewTag(tag);
        break;
      case _ImageTagAction.exclude:
        widget.onToggleExcludeTag(tag);
        break;
      case _ImageTagAction.add:
        widget.onAddUserTag(tag);
        break;
    }
  }
}

enum _ImageTagAction { use, preview, exclude, add }

class _DirectionFilter extends StatelessWidget {
  const _DirectionFilter({
    required this.selected,
    required this.onSelected,
  });

  final ImageOrientation? selected;
  final ValueChanged<ImageOrientation?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterChip(
          label: '不限',
          selected: selected == null,
          onSelected: () => onSelected(null),
        ),
        for (final orientation in ImageOrientation.values)
          _FilterChip(
            label: orientation.label,
            selected: selected == orientation,
            onSelected: () => onSelected(orientation),
          ),
      ],
    );
  }
}

class _CategoryFilter extends StatelessWidget {
  const _CategoryFilter({
    required this.categories,
    required this.selected,
    required this.onSelected,
  });

  final List<CategorySummary> categories;
  final String? selected;
  final ValueChanged<String?> onSelected;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _FilterChip(
          label: '全部',
          selected: selected == null,
          onSelected: () => onSelected(null),
        ),
        for (final category in categories)
          _FilterChip(
            label: category.name,
            selected: selected == category.name,
            onSelected: () => onSelected(category.name),
          ),
      ],
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback onSelected;

  @override
  Widget build(BuildContext context) {
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      onSelected: (_) => onSelected(),
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      selectedColor: niceAmber.withValues(alpha: 0.24),
      side: BorderSide(
        color: selected ? niceAmber : Colors.white.withValues(alpha: 0.12),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      labelStyle: TextStyle(
        color: selected ? niceText : niceMuted,
        fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
      ),
    );
  }
}

class _DiscoveryTags extends StatelessWidget {
  const _DiscoveryTags({
    required this.tags,
    required this.selectedTag,
    required this.excludedTags,
    required this.onSelected,
    required this.onPreview,
    required this.onToggleExclude,
  });

  final List<TagSummary> tags;
  final String? selectedTag;
  final List<String> excludedTags;
  final ValueChanged<String?> onSelected;
  final ValueChanged<String> onPreview;
  final ValueChanged<String> onToggleExclude;

  @override
  Widget build(BuildContext context) {
    if (tags.isEmpty) {
      return const Text(
        '暂无标签',
        style: TextStyle(color: niceMuted),
      );
    }
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: tags.map((tag) {
        final selected = selectedTag == tag.name;
        final excluded = excludedTags.any(
          (item) => item.toLowerCase() == tag.name.toLowerCase(),
        );
        return _DiscoveryTagChip(
          tag: tag,
          selected: selected,
          excluded: excluded,
          onSelected: () => onSelected(tag.name),
          onPreview: () => onPreview(tag.name),
          onToggleExclude: () => onToggleExclude(tag.name),
        );
      }).toList(),
    );
  }
}

class _DiscoveryTagChip extends StatelessWidget {
  const _DiscoveryTagChip({
    required this.tag,
    required this.selected,
    required this.excluded,
    required this.onSelected,
    required this.onPreview,
    required this.onToggleExclude,
  });

  final TagSummary tag;
  final bool selected;
  final bool excluded;
  final VoidCallback onSelected;
  final VoidCallback onPreview;
  final VoidCallback onToggleExclude;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? niceAmber.withValues(alpha: 0.22)
          : Colors.white.withValues(alpha: excluded ? 0.04 : 0.08),
      borderRadius: BorderRadius.circular(8),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onSelected,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 5, 4, 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 150),
                child: Text(
                  tag.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: excluded ? niceMuted : niceText,
                    decoration:
                        excluded ? TextDecoration.lineThrough : null,
                    fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              _TinyIconButton(
                icon: Icons.grid_view_rounded,
                tooltip: '预览',
                onPressed: onPreview,
              ),
              _TinyIconButton(
                icon: excluded
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                tooltip: excluded ? '取消排除' : '排除',
                onPressed: onToggleExclude,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TinyIconButton extends StatelessWidget {
  const _TinyIconButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: InkResponse(
        onTap: onPressed,
        radius: 18,
        child: Padding(
          padding: const EdgeInsets.all(5),
          child: Icon(icon, size: 16, color: niceMuted),
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({
    required this.title,
    required this.trailing,
    this.onClear,
  });

  final String title;
  final String trailing;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: niceText,
              fontSize: 18,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 170),
          child: Align(
            alignment: Alignment.centerRight,
            child: Text(
              trailing,
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: const TextStyle(color: niceAmber, fontSize: 14),
            ),
          ),
        ),
        if (onClear != null) ...[
          const SizedBox(width: 4),
          Tooltip(
            message: '清除筛选',
            child: IconButton(
              onPressed: onClear,
              icon: const Icon(Icons.filter_alt_off_rounded),
              iconSize: 18,
              visualDensity: VisualDensity.compact,
            ),
          ),
        ],
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: niceText,
        fontWeight: FontWeight.w700,
        fontSize: 14,
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String? value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 92,
            child: Text(
              label,
              style: const TextStyle(color: niceMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Text(
              value ?? '-',
              textAlign: TextAlign.right,
              overflow: TextOverflow.ellipsis,
              maxLines: 2,
              style: const TextStyle(color: niceText, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _GalleryInfoRow extends StatelessWidget {
  const _GalleryInfoRow({
    required this.title,
    required this.onOpen,
  });

  final String title;
  final VoidCallback onOpen;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(
            width: 92,
            child: Text(
              '图集',
              style: TextStyle(color: niceMuted, fontSize: 12),
            ),
          ),
          Expanded(
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onOpen,
                icon: const Icon(Icons.photo_library_rounded, size: 16),
                label: Text(
                  title,
                  overflow: TextOverflow.ellipsis,
                  maxLines: 1,
                ),
                style: TextButton.styleFrom(
                  foregroundColor: niceAmber,
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(0, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
