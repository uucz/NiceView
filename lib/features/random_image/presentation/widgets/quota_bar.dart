import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/quota_state.dart';

class QuotaBar extends StatelessWidget {
  const QuotaBar({
    required this.quota,
    super.key,
  });

  final QuotaState quota;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '请求额度',
          style: TextStyle(
            color: niceText,
            fontSize: 14,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 10),
        _QuotaBucketBar(
          label: '随机 / 元数据',
          quota: quota.random,
        ),
        const SizedBox(height: 12),
        _QuotaBucketBar(
          label: '图片预览',
          quota: quota.image,
        ),
      ],
    );
  }
}

class _QuotaBucketBar extends StatelessWidget {
  const _QuotaBucketBar({
    required this.label,
    required this.quota,
  });

  final String label;
  final QuotaWindowState quota;

  @override
  Widget build(BuildContext context) {
    final color = quota.progress >= 0.9
        ? niceDanger
        : quota.progress >= 0.7
            ? niceAmber
            : niceMuted;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              label,
              style: const TextStyle(color: niceMuted, fontSize: 12),
            ),
            Text(
              '${quota.used} / ${quota.limit}',
              style: const TextStyle(color: niceMuted, fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: quota.progress.clamp(0.0, 1.0).toDouble(),
            minHeight: 7,
            backgroundColor: Colors.white.withValues(alpha: 0.10),
            valueColor: AlwaysStoppedAnimation<Color>(color),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          _quotaStatus(quota),
          style: TextStyle(color: color, fontSize: 11),
        ),
      ],
    );
  }

  String _quotaStatus(QuotaWindowState quota) {
    final serverLockout = quota.serverLockoutRemaining;
    if (serverLockout > Duration.zero) {
      final minutes = serverLockout.inMinutes;
      if (minutes > 0) {
        return '约 ${minutes + 1} 分钟后解除服务器冷却';
      }
      return '${serverLockout.inSeconds}s 后解除服务器冷却';
    }

    final wait = quota.timeUntilNextAvailable;
    if (wait != null) {
      return '约 ${wait.inSeconds}s 后恢复';
    }

    final remaining = quota.remaining;
    if (quota.progress >= 0.9) {
      return '剩余 $remaining 次，快到上限';
    }
    if (quota.progress >= 0.7) {
      return '剩余 $remaining 次，注意节奏';
    }
    return '剩余 $remaining 次';
  }
}
