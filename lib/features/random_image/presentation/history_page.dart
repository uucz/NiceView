import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import '../domain/history_image.dart';
import 'history_preview_page.dart';
import 'random_image_controller.dart';
import 'widgets/history_grid.dart';

class HistoryPage extends ConsumerStatefulWidget {
  const HistoryPage({super.key});

  @override
  ConsumerState<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends ConsumerState<HistoryPage> {
  bool _showFavorites = false;

  @override
  Widget build(BuildContext context) {
    ref.listen<String?>(
      randomImageControllerProvider.select((state) => state.errorMessage),
      (previous, next) {
        if (next == null) {
          return;
        }
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next)),
        );
        ref.read(randomImageControllerProvider.notifier).clearMessage();
      },
    );

    final state = ref.watch(randomImageControllerProvider);
    final controller = ref.read(randomImageControllerProvider.notifier);
    final images = _showFavorites ? state.favoriteImages : state.historyImages;
    return Scaffold(
      backgroundColor: niceBlack,
      appBar: AppBar(
        backgroundColor: niceBlack,
        foregroundColor: niceText,
        title: const Text('浏览历史'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 10),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('全部 ${state.historyImages.length}'),
                  selected: !_showFavorites,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _showFavorites = false),
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text('收藏 ${state.favoriteImages.length}'),
                  selected: _showFavorites,
                  showCheckmark: false,
                  onSelected: (_) => setState(() => _showFavorites = true),
                ),
              ],
            ),
          ),
          Expanded(
            child: HistoryGrid(
              images: images,
              favoriteImageIds:
                  state.favoriteImages.map((image) => image.imageId).toSet(),
              onOpen: (image) => _openPreview(context, ref, image, images),
              onDelete: (image) => _showFavorites
                  ? _confirmDeleteFavorite(context, controller, image)
                  : _confirmDeleteHistory(context, controller, image),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openPreview(
    BuildContext context,
    WidgetRef ref,
    HistoryImage image,
    List<HistoryImage> sourceImages,
  ) async {
    final controller = ref.read(randomImageControllerProvider.notifier);
    if (!await image.file.exists() && image.imageId == null) {
      if (_showFavorites) {
        await controller.deleteFavoriteImage(image);
      } else {
        await controller.removeMissingHistoryImage(image);
      }
      return;
    }

    final images = [...sourceImages];
    final index =
        images.indexWhere((item) => item.historyId == image.historyId);
    if (!_showFavorites) {
      unawaited(controller.touchHistoryImage(image));
    }
    if (!context.mounted) {
      return;
    }
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => HistoryPreviewPage(
          images: images,
          initialIndex: index < 0 ? 0 : index,
        ),
      ),
    );
  }

  Future<void> _confirmDeleteHistory(
    BuildContext context,
    RandomImageController controller,
    HistoryImage image,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF191A1C),
          title: const Text('删除历史图片'),
          content: const Text('删除后会同时移除这张历史缓存。收藏副本不会受影响。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await controller.deleteHistoryImage(image);
    }
  }

  Future<void> _confirmDeleteFavorite(
    BuildContext context,
    RandomImageController controller,
    HistoryImage image,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF191A1C),
          title: const Text('删除收藏'),
          content: const Text('删除后会移除收藏缓存文件，浏览历史不会受影响。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('删除'),
            ),
          ],
        );
      },
    );
    if (confirmed == true) {
      await controller.deleteFavoriteImage(image);
    }
  }
}
