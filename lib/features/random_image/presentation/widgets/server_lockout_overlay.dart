import 'package:flutter/material.dart';

import '../../../../app/theme.dart';
import '../../domain/quota_state.dart';

class ServerLockoutOverlay extends StatelessWidget {
  const ServerLockoutOverlay({
    required this.quota,
    super.key,
  });

  final QuotaState quota;

  @override
  Widget build(BuildContext context) {
    if (!quota.anyServerLocked) {
      return const SizedBox.shrink();
    }

    final remaining = quota.longestServerLockoutRemaining;
    final bucket = quota.longestServerLockedBucket;
    final label = remaining.inMinutes > 0
        ? '${remaining.inMinutes + 1}m'
        : '${remaining.inSeconds.clamp(0, 60).toInt()}s';
    return Positioned.fill(
      child: Stack(
        fit: StackFit.expand,
        children: [
          const ModalBarrier(color: Colors.black, dismissible: false),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: const TextStyle(
                    color: niceText,
                    fontSize: 48,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  '服务器正在冷却，稍后再试。',
                  style: TextStyle(color: niceMuted, fontSize: 13),
                ),
                if (bucket != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    bucket.label,
                    style: const TextStyle(color: niceMuted, fontSize: 12),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
