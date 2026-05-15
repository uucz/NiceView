import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme.dart';
import 'random_image_controller.dart';

class SettingsPage extends ConsumerStatefulWidget {
  const SettingsPage({super.key});

  @override
  ConsumerState<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends ConsumerState<SettingsPage> {
  Future<CacheUsage>? _usageFuture;
  int? _draftHistoryLimit;

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

    _usageFuture ??=
        ref.read(randomImageControllerProvider.notifier).loadCacheUsage();
    final state = ref.watch(randomImageControllerProvider);
    final controller = ref.read(randomImageControllerProvider.notifier);
    final historyLimit = _draftHistoryLimit ?? state.historyLimit;

    return Scaffold(
      backgroundColor: niceBlack,
      appBar: AppBar(
        backgroundColor: niceBlack,
        foregroundColor: niceText,
        title: const Text('设置'),
        actions: [
          IconButton(
            tooltip: '刷新缓存占用',
            onPressed: _reloadUsage,
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
        children: [
          const _SectionTitle('数据'),
          const SizedBox(height: 10),
          _MetricRow(label: '浏览历史', value: '${state.historyImages.length} 张'),
          _MetricRow(label: '收藏', value: '${state.favoriteImages.length} 张'),
          const SizedBox(height: 18),
          Text(
            '历史上限：$historyLimit',
            style: const TextStyle(color: niceText, fontWeight: FontWeight.w700),
          ),
          Slider(
            value: historyLimit.toDouble(),
            min: 10,
            max: 200,
            divisions: 19,
            label: historyLimit.toString(),
            onChanged: (value) {
              setState(() => _draftHistoryLimit = value.round());
            },
            onChangeEnd: (value) async {
              await controller.updateHistoryLimit(value.round());
              if (mounted) {
                setState(() => _draftHistoryLimit = null);
                _reloadUsage();
              }
            },
          ),
          const SizedBox(height: 10),
          FutureBuilder<CacheUsage>(
            future: _usageFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState != ConnectionState.done) {
                return const Padding(
                  padding: EdgeInsets.symmetric(vertical: 20),
                  child: Center(
                    child: SizedBox.square(
                      dimension: 24,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                  ),
                );
              }
              final usage = snapshot.data;
              if (usage == null) {
                return const Text(
                  '缓存占用读取失败',
                  style: TextStyle(color: niceMuted),
                );
              }
              return Column(
                children: [
                  _MetricRow(
                    label: '历史缓存',
                    value: _formatBytes(usage.historyBytes),
                  ),
                  _MetricRow(
                    label: '收藏缓存',
                    value: _formatBytes(usage.favoriteBytes),
                  ),
                  _MetricRow(
                    label: '预加载缓存',
                    value: _formatBytes(usage.preloadBytes),
                  ),
                  _MetricRow(
                    label: '临时图片缓存',
                    value: _formatBytes(usage.temporaryBytes),
                  ),
                  const Divider(height: 22),
                  _MetricRow(
                    label: '合计',
                    value: _formatBytes(usage.totalBytes),
                    strong: true,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const Text(
            '清理 App 内缓存不会删除已经保存到系统 Photos 的图片。',
            style: TextStyle(color: niceMuted, fontSize: 12),
          ),
          const SizedBox(height: 24),
          const _SectionTitle('清理'),
          const SizedBox(height: 10),
          _ActionButton(
            icon: Icons.cleaning_services_rounded,
            label: '清理临时缓存',
            onPressed: () async {
              await controller.clearTemporaryCache();
              _reloadUsage();
            },
          ),
          _ActionButton(
            icon: Icons.history_toggle_off_rounded,
            label: '清空浏览历史',
            isDanger: true,
            onPressed: () async {
              final confirmed = await _confirm(
                title: '清空浏览历史',
                message: '会删除 App 内历史缓存文件，收藏副本不会受影响。',
              );
              if (confirmed) {
                await controller.clearHistory();
                _reloadUsage();
              }
            },
          ),
          _ActionButton(
            icon: Icons.heart_broken_rounded,
            label: '清空收藏',
            isDanger: true,
            onPressed: () async {
              final confirmed = await _confirm(
                title: '清空收藏',
                message: '会删除 App 内收藏缓存文件，浏览历史不会受影响。',
              );
              if (confirmed) {
                await controller.clearFavorites();
                _reloadUsage();
              }
            },
          ),
          const SizedBox(height: 24),
          const _SectionTitle('偏好'),
          const SizedBox(height: 10),
          _ActionButton(
            icon: Icons.restart_alt_rounded,
            label: '清除默认筛选偏好',
            onPressed: controller.clearDefaultQuery,
          ),
        ],
      ),
    );
  }

  void _reloadUsage() {
    setState(() {
      _usageFuture =
          ref.read(randomImageControllerProvider.notifier).loadCacheUsage();
    });
  }

  Future<bool> _confirm({
    required String title,
    required String message,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF191A1C),
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认'),
          ),
        ],
      ),
    );
    return confirmed == true;
  }

  String _formatBytes(int value) {
    if (value < 1024) {
      return '$value B';
    }
    final kb = value / 1024;
    if (kb < 1024) {
      return '${kb.toStringAsFixed(1)} KB';
    }
    final mb = kb / 1024;
    return '${mb.toStringAsFixed(1)} MB';
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: niceText,
        fontSize: 16,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _MetricRow extends StatelessWidget {
  const _MetricRow({
    required this.label,
    required this.value,
    this.strong = false,
  });

  final String label;
  final String value;
  final bool strong;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                color: strong ? niceText : niceMuted,
                fontWeight: strong ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: niceText,
              fontWeight: strong ? FontWeight.w800 : FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isDanger = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isDanger;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
        style: OutlinedButton.styleFrom(
          foregroundColor: isDanger ? niceDanger : niceText,
          side: BorderSide(
            color: (isDanger ? niceDanger : Colors.white).withValues(
              alpha: isDanger ? 0.42 : 0.16,
            ),
          ),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ),
    );
  }
}
