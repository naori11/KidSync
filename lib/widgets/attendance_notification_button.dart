import 'package:flutter/material.dart';

/// Button states for attendance notification actions
enum AttendanceButtonState {
  urgent,
  escalate,
  monitoring,
  disabled,
  loading,
}

/// Smart notification button that adapts based on attendance status
class AttendanceNotificationButton extends StatelessWidget {
  final AttendanceButtonState state;
  final VoidCallback? onPressed;
  final Map<String, dynamic>? stats;
  final double? width;
  final double? height;

  const AttendanceNotificationButton({
    super.key,
    required this.state,
    this.onPressed,
    this.stats,
    this.width,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    final config = _getButtonConfig();
    
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: state == AttendanceButtonState.loading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: config.color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
        ),
        child: state == AttendanceButtonState.loading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    config.icon,
                    size: 16,
                    color: Colors.white,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    config.text,
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
      ),
    );
  }

  _ButtonConfig _getButtonConfig() {
    switch (state) {
      case AttendanceButtonState.urgent:
        return _ButtonConfig(
          text: 'Notify\nParents',
          color: const Color(0xFFDC2626), // Red
          icon: Icons.mail_outline,
        );
      case AttendanceButtonState.escalate:
        return _ButtonConfig(
          text: 'Escalate\nIssue',
          color: const Color(0xFFF59E0B), // Orange
          icon: Icons.warning_outlined,
        );
      case AttendanceButtonState.monitoring:
        return _ButtonConfig(
          text: 'Monitor\nProgress',
          color: const Color(0xFF3B82F6), // Blue
          icon: Icons.visibility_outlined,
        );
      case AttendanceButtonState.disabled:
        return _ButtonConfig(
          text: 'Good\nAttendance',
          color: const Color(0xFF10B981), // Green
          icon: Icons.check_circle_outline,
        );
      case AttendanceButtonState.loading:
        return _ButtonConfig(
          text: 'Loading...',
          color: const Color(0xFF6B7280), // Gray
          icon: Icons.hourglass_empty,
        );
    }
  }
}

class _ButtonConfig {
  final String text;
  final Color color;
  final IconData icon;

  _ButtonConfig({
    required this.text,
    required this.color,
    required this.icon,
  });
}

/// Action button for specific attendance actions
class AttendanceActionButton extends StatelessWidget {
  final String text;
  final IconData icon;
  final Color color;
  final VoidCallback? onPressed;
  final bool isLoading;
  final double? width;
  final double? height;

  const AttendanceActionButton({
    super.key,
    required this.text,
    required this.icon,
    required this.color,
    this.onPressed,
    this.isLoading = false,
    this.width,
    this.height = 40,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: ElevatedButton(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        ),
        child: isLoading
            ? const SizedBox(
                width: 16,
                height: 16,
                child: CircularProgressIndicator(
                  color: Colors.white,
                  strokeWidth: 2,
                ),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    text,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}