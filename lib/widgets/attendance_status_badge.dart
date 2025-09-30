import 'package:flutter/material.dart';

/// Status badge types for attendance escalation
enum AttendanceBadgeType {
  none,
  attention,
  urgent,
  monitoring,
  critical,
  resolved,
}

/// Reusable status badge widget for attendance issues
class AttendanceStatusBadge extends StatelessWidget {
  final AttendanceBadgeType type;
  final String? customText;
  final double fontSize;
  final EdgeInsets padding;

  const AttendanceStatusBadge({
    super.key,
    required this.type,
    this.customText,
    this.fontSize = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  });

  @override
  Widget build(BuildContext context) {
    if (type == AttendanceBadgeType.none) {
      return const SizedBox.shrink();
    }

    final config = _getBadgeConfig();
    
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: config.color,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            config.icon,
            size: fontSize + 2,
            color: Colors.white,
          ),
          const SizedBox(width: 2),
          Text(
            customText ?? config.text,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  _BadgeConfig _getBadgeConfig() {
    switch (type) {
      case AttendanceBadgeType.critical:
        return _BadgeConfig(
          text: 'CRITICAL',
          color: const Color(0xFF8B0000), // Dark red
          icon: Icons.dangerous,
        );
      case AttendanceBadgeType.urgent:
        return _BadgeConfig(
          text: 'URGENT',
          color: const Color(0xFFDC2626), // Red
          icon: Icons.priority_high,
        );
      case AttendanceBadgeType.monitoring:
        return _BadgeConfig(
          text: 'MONITORING',
          color: const Color(0xFF3B82F6), // Blue
          icon: Icons.visibility,
        );
      case AttendanceBadgeType.attention:
        return _BadgeConfig(
          text: 'ATTENTION',
          color: const Color(0xFFF59E0B), // Orange
          icon: Icons.info,
        );
      case AttendanceBadgeType.resolved:
        return _BadgeConfig(
          text: 'RESOLVED',
          color: const Color(0xFF10B981), // Green
          icon: Icons.check_circle,
        );
      default:
        return _BadgeConfig(
          text: '',
          color: Colors.grey,
          icon: Icons.info,
        );
    }
  }
}

class _BadgeConfig {
  final String text;
  final Color color;
  final IconData icon;

  _BadgeConfig({
    required this.text,
    required this.color,
    required this.icon,
  });
}

/// Creates a badge from service badge status
class AttendanceStatusBadgeFromService extends StatelessWidget {
  final Map<String, dynamic> badgeStatus;
  final double fontSize;
  final EdgeInsets padding;

  const AttendanceStatusBadgeFromService({
    super.key,
    required this.badgeStatus,
    this.fontSize = 8,
    this.padding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
  });

  @override
  Widget build(BuildContext context) {
    final badgeType = badgeStatus['badgeType'] as String? ?? 'none';
    final customText = badgeStatus['badgeText'] as String?;

    AttendanceBadgeType type;
    switch (badgeType) {
      case 'critical':
        type = AttendanceBadgeType.critical;
        break;
      case 'urgent':
        type = AttendanceBadgeType.urgent;
        break;
      case 'monitoring':
        type = AttendanceBadgeType.monitoring;
        break;
      case 'attention':
        type = AttendanceBadgeType.attention;
        break;
      case 'resolved':
        type = AttendanceBadgeType.resolved;
        break;
      default:
        type = AttendanceBadgeType.none;
    }

    return AttendanceStatusBadge(
      type: type,
      customText: customText,
      fontSize: fontSize,
      padding: padding,
    );
  }
}