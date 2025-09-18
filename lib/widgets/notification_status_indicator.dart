import 'package:flutter/material.dart';

enum NotificationStatusType {
  none,
  pending,
  resolved,
}

class NotificationStatusIndicator extends StatelessWidget {
  final NotificationStatusType status;
  final int? consecutiveAbsences;
  final bool showText;
  final double size;

  const NotificationStatusIndicator({
    Key? key,
    required this.status,
    this.consecutiveAbsences,
    this.showText = true,
    this.size = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (status == NotificationStatusType.none) {
      return const SizedBox.shrink();
    }

    Color color;
    IconData icon;
    String text;

    switch (status) {
      case NotificationStatusType.pending:
        color = Colors.orange;
        icon = Icons.notification_important;
        text = 'Notified';
        break;
      case NotificationStatusType.resolved:
        color = Colors.green;
        icon = Icons.check_circle;
        text = 'Resolved';
        break;
      default:
        return const SizedBox.shrink();
    }

    if (!showText) {
      return Icon(
        icon,
        color: color,
        size: size,
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: size, color: color),
          const SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: size - 2,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class AttendanceUrgencyIndicator extends StatelessWidget {
  final int consecutiveAbsences;
  final NotificationStatusType? notificationStatus;
  final double size;

  const AttendanceUrgencyIndicator({
    Key? key,
    required this.consecutiveAbsences,
    this.notificationStatus,
    this.size = 12,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Don't show urgency indicator if issue is resolved
    if (notificationStatus == NotificationStatusType.resolved) {
      return const SizedBox.shrink();
    }

    if (consecutiveAbsences < 3) {
      return const SizedBox.shrink();
    }

    Color color;
    IconData icon;
    String text;

    if (consecutiveAbsences >= 5) {
      color = const Color(0xFF8B0000); // Dark red
      icon = Icons.priority_high;
      text = 'CRITICAL';
    } else if (consecutiveAbsences >= 4) {
      color = const Color(0xFFDC2626); // Red
      icon = Icons.warning;
      text = 'URGENT';
    } else {
      color = const Color(0xFFF59E0B); // Orange
      icon = Icons.info;
      text = 'ATTENTION';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: size, color: color),
          const SizedBox(width: 2),
          Text(
            text,
            style: TextStyle(
              fontSize: size - 2,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}