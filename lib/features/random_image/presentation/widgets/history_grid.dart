import 'dart:io';

import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/history_image.dart';

class HistoryGrid extends StatelessWidget {
  const HistoryGrid({
    required this.images,
    required this.emptyLabel,
    this.favoriteImageIds = const <int?>{},
    required this.onOpen,
    required this.onDelete,
    super.key,
  });

  final List<HistoryImage> images;
  final String emptyLabel;
  final Set<int?> favoriteImageIds;
  final ValueChanged<HistoryImage> onOpen;
  final ValueChanged<HistoryImage> onDelete;

  @override
  Widget build(BuildContext context) {
    if (images.isEmpty) {
      return Center(
        child: Text(
          emptyLabel,
          style: const TextStyle(color: niceMuted),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(12),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 0.72,
      ),
      itemCount: images.length,
      itemBuilder: (context, index) {
        final image = images[index];
        return Semantics(
          button: true,
          label: '图片 ${image.imageId ?? image.historyId}',
          child: GestureDetector(
            onTap: () => onOpen(image),
            onLongPress: () => onDelete(image),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ColoredBox(
                color: Colors.white.withValues(alpha: 0.06),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.file(
                      File(image.localFilePath),
                      fit: BoxFit.cover,
                      semanticLabel: '历史图片 ${image.imageId ?? image.historyId}',
                      errorBuilder: (_, __, ___) {
                        return const Center(
                          child: Icon(
                            Icons.broken_image_outlined,
                            color: niceMuted,
                          ),
                        );
                      },
                    ),
                    if (image.imageId != null &&
                        favoriteImageIds.contains(image.imageId))
                      const Positioned(
                        left: 6,
                        top: 6,
                        child: Icon(
                          Icons.favorite_rounded,
                          color: niceDanger,
                          size: 18,
                        ),
                      ),
                    Positioned(
                      right: 4,
                      top: 4,
                      child: IconButton.filled(
                        tooltip: '删除',
                        onPressed: () => onDelete(image),
                        icon: const Icon(Icons.more_horiz_rounded),
                        iconSize: 17,
                        style: IconButton.styleFrom(
                          minimumSize: const Size(32, 32),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          backgroundColor:
                              Colors.black.withValues(alpha: 0.46),
                          foregroundColor: niceText,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
