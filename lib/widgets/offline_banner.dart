import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Shown at the top of a screen while the device has no connectivity.
/// [pendingCount] surfaces how many rides are queued in the offline store
/// waiting to sync, so the passenger knows their request wasn't lost.
class OfflineBanner extends StatelessWidget {
  final int pendingCount;
  const OfflineBanner({super.key, this.pendingCount = 0});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      color: AppColors.warning,
      child: Row(
        children: [
          const Icon(Icons.wifi_off_rounded, color: Colors.white, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              pendingCount > 0
                  ? 'No internet. $pendingCount request(s) saved. Will send when connected.'
                  : 'No internet connection',
              style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}
