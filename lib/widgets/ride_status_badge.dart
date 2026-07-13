import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class RideStatusBadge extends StatelessWidget {
  final String status;
  const RideStatusBadge({super.key, required this.status});

  Color get _color {
    switch (status.toLowerCase()) {
      case 'searching':
        return AppColors.statusSearching;
      case 'accepted':
        return AppColors.statusAccepted;
      case 'on_the_way':
        return AppColors.statusOnWay;
      case 'arrived':
        return AppColors.statusArrived;
      case 'confirmed':
        return AppColors.statusAccepted;
      case 'scheduled':
        return AppColors.secondary;
      case 'completed':
        return AppColors.statusCompleted;
      case 'cancelled':
        return AppColors.statusCancelled;
      default:
        return AppColors.textHint;
    }
  }

  String get _label {
    switch (status.toLowerCase()) {
      case 'searching':
        return '🔍 Searching';
      case 'accepted':
        return '✅ Accepted';
      case 'on_the_way':
        return '🚗 On the Way';
      case 'arrived':
        return '📍 Arrived';
      case 'confirmed':
        return '✅ Confirmed';
      case 'scheduled':
        return '🗓️ Scheduled';
      case 'completed':
        return '🎉 Completed';
      case 'cancelled':
        return '❌ Cancelled';
      default:
        return status;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _color.withValues(alpha: 0.4)),
      ),
      child: Text(
        _label,
        style: TextStyle(color: _color, fontWeight: FontWeight.w700, fontSize: 13),
      ),
    );
  }
}
