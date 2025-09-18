import 'package:flutter/material.dart';

/// Attendance insights widget for teacher dashboard analytics
class AttendanceInsightsCard extends StatelessWidget {
  final Map<String, dynamic> insights;
  final VoidCallback? onViewDetails;

  const AttendanceInsightsCard({
    super.key,
    required this.insights,
    this.onViewDetails,
  });

  @override
  Widget build(BuildContext context) {
    final totalNotifications = insights['totalNotificationsSent'] as int? ?? 0;
    final issuesResolved = insights['issuesResolved'] as int? ?? 0;
    final escalatedCases = insights['escalatedCases'] as int? ?? 0;
    final resolutionRate = insights['resolutionRate'] as int? ?? 0;

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.analytics_outlined,
                color: Color(0xFF3B82F6),
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                "Attendance Insights",
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF222B45),
                ),
              ),
              const Spacer(),
              if (onViewDetails != null)
                TextButton(
                  onPressed: onViewDetails,
                  child: const Text(
                    "View Details",
                    style: TextStyle(
                      fontSize: 14,
                      color: Color(0xFF3B82F6),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _insightCard(
                  "Notifications Sent",
                  totalNotifications.toString(),
                  "This month",
                  const Color(0xFF3B82F6),
                  Icons.mail_outlined,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _insightCard(
                  "Issues Resolved",
                  issuesResolved.toString(),
                  "$resolutionRate% resolution rate",
                  resolutionRate >= 70 ? const Color(0xFF10B981) : const Color(0xFFF59E0B),
                  Icons.check_circle_outline,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _insightCard(
                  "Escalated Cases",
                  escalatedCases.toString(),
                  "Requiring attention",
                  escalatedCases > 0 ? const Color(0xFFDC2626) : const Color(0xFF10B981),
                  Icons.priority_high_outlined,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _insightCard(String title, String value, String subtitle, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: color.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icon,
                color: color,
                size: 16,
              ),
              const Spacer(),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: Color(0xFF6B7280),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 10,
              color: color.withOpacity(0.8),
            ),
          ),
        ],
      ),
    );
  }
}

/// Quick stats row widget for section summaries
class AttendanceQuickStats extends StatelessWidget {
  final int totalStudents;
  final int studentsWithIssues;
  final int urgentCases;
  final int notificationsSent;

  const AttendanceQuickStats({
    super.key,
    required this.totalStudents,
    required this.studentsWithIssues,
    required this.urgentCases,
    required this.notificationsSent,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _statChip(
            "Total Students",
            totalStudents.toString(),
            const Color(0xFF3B82F6),
            Icons.people_outline,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statChip(
            "With Issues",
            studentsWithIssues.toString(),
            studentsWithIssues > 0 ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
            Icons.warning_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statChip(
            "Urgent",
            urgentCases.toString(),
            urgentCases > 0 ? const Color(0xFFDC2626) : const Color(0xFF10B981),
            Icons.priority_high_outlined,
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: _statChip(
            "Notified",
            notificationsSent.toString(),
            const Color(0xFF8B5CF6),
            Icons.notifications_outlined,
          ),
        ),
      ],
    );
  }

  Widget _statChip(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: color.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 16,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
          Text(
            label,
            style: const TextStyle(
              fontSize: 10,
              color: Color(0xFF6B7280),
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}