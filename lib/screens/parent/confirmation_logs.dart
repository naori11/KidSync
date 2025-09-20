import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/parent_audit_service.dart';

class ConfirmationLogsScreen extends StatefulWidget {
  final Color primaryColor;
  final bool isMobile;
  final int? selectedStudentId; // ADD THIS

  const ConfirmationLogsScreen({
    Key? key,
    required this.primaryColor,
    required this.isMobile,
    this.selectedStudentId, // ADD THIS
  }) : super(key: key);

  @override
  State<ConfirmationLogsScreen> createState() => _ConfirmationLogsScreenState();
}

class _ConfirmationLogsScreenState extends State<ConfirmationLogsScreen> {
  final supabase = Supabase.instance.client;
  final ParentAuditService _auditService = ParentAuditService();
  List<ConfirmationLog> confirmationLogs = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConfirmationLogs();
  }

  @override
  void didUpdateWidget(ConfirmationLogsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when selectedStudentId changes
    if (widget.selectedStudentId != oldWidget.selectedStudentId) {
      _loadConfirmationLogs();
    }
  }

  // Add this method to handle verification responses
  Future<void> _verifyEvent(ConfirmationLog log, String status, {String? notes}) async {
    try {
      // Update verification status in database
      await supabase
          .from('pickup_dropoff_verifications')
          .upsert({
            'pickup_dropoff_log_id': int.parse(log.id),
            'student_id': int.parse(log.studentId),
            'status': status,
            'parent_response_time': DateTime.now().toIso8601String(),
            'parent_notes': notes,
          });

      // Log the verification action
      await _auditService.logPickupDropoffVerification(
        childId: log.studentId,
        childName: log.studentName,
        eventType: log.eventType,
        verificationStatus: status,
        driverName: log.driverName,
        eventTime: log.eventTime,
        responseTime: DateTime.now(),
        parentNotes: notes,
        logId: log.id,
      );

      // Refresh the logs
      await _loadConfirmationLogs();

      // Show success message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${log.eventType.capitalizeFirst()} ${status.toLowerCase()} successfully'),
          backgroundColor: status == 'confirmed' ? Colors.green : Colors.orange,
        ),
      );
    } catch (e) {
      print('Error verifying event: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to verify ${log.eventType}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  Future<void> _loadConfirmationLogs() async {
    // Show message if no student selected
    if (widget.selectedStudentId == null) {
      setState(() {
        confirmationLogs = [];
        isLoading = false;
        errorMessage = null;
      });
      return;
    }

    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      // Get current user (parent) to filter verifications
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          errorMessage = 'User not authenticated';
          isLoading = false;
        });
        return;
      }

      // Get parent ID from user
      final parentResponse =
          await supabase
              .from('parents')
              .select('id')
              .eq('user_id', user.id)
              .maybeSingle();

      if (parentResponse == null) {
        setState(() {
          errorMessage = 'Parent information not found';
          isLoading = false;
        });
        return;
      }

      final parentId = parentResponse['id'];

      // Query pickup_dropoff_logs with left join to pickup_dropoff_verifications
      final logsResponse = await supabase
          .from('pickup_dropoff_logs')
          .select('''
            id,
            student_id,
            driver_id,
            pickup_time,
            dropoff_time,
            event_type,
            notes,
            created_at,
            students!pickup_dropoff_logs_student_id_fkey(
              fname,
              lname,
              grade_level,
              sections(name)
            ),
            drivers:users!pickup_dropoff_logs_driver_id_fkey(
              fname,
              lname
            )
          ''')
          .eq('student_id', widget.selectedStudentId!)
          .order('created_at', ascending: false)
          .limit(50);

      // Get verification data for this parent and student
      final verificationsResponse = await supabase
          .from('pickup_dropoff_verifications')
          .select('''
            pickup_dropoff_log_id,
            status,
            parent_response_time,
            parent_notes,
            event_type,
            event_time
          ''')
          .eq('student_id', widget.selectedStudentId!)
          .eq('parent_id', parentId);

      // Create a map of log_id to verification for quick lookup
      final Map<int?, Map<String, dynamic>> verificationMap = {};
      for (final verification in verificationsResponse) {
        final logId = verification['pickup_dropoff_log_id'];
        if (logId != null) {
          verificationMap[logId] = verification;
        }
      }

      final List<ConfirmationLog> logs =
          logsResponse.map((data) {
            final verification = verificationMap[data['id']];
            return ConfirmationLog.fromJson(data, verification);
          }).toList();

      setState(() {
        confirmationLogs = logs;
        isLoading = false;
      });
    } catch (error) {
      print('Error loading confirmation logs: $error');
      setState(() {
        errorMessage = 'Failed to load confirmation logs';
        isLoading = false;
      });
    }
  }

  String _getEventTypeText(String type) {
    switch (type.toLowerCase()) {
      case 'pickup':
        return 'Pickup';
      case 'dropoff':
        return 'Drop-off';
      default:
        return type
            .replaceAll('_', ' ')
            .split(' ')
            .map(
              (word) =>
                  word.isNotEmpty
                      ? word[0].toUpperCase() + word.substring(1)
                      : word,
            )
            .join(' ');
    }
  }

  String _formatDateTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
    } else if (difference.inHours > 0) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
    } else {
      return 'Just now';
    }
  }

  // Group logs by date
  Map<String, List<ConfirmationLog>> _groupLogsByDate(
    List<ConfirmationLog> logs,
  ) {
    final Map<String, List<ConfirmationLog>> grouped = {};

    for (final log in logs) {
      final dateOnly = DateTime(
        log.eventTime.year,
        log.eventTime.month,
        log.eventTime.day,
      );
      final key = _formatDateKey(dateOnly);
      grouped.putIfAbsent(key, () => []).add(log);
    }

    // Sort each group by time (most recent first)
    grouped.forEach((key, value) {
      value.sort((a, b) => b.eventTime.compareTo(a.eventTime));
    });

    return grouped;
  }

  String _formatDateKey(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final dateOnly = DateTime(date.year, date.month, date.day);

    if (dateOnly == today) {
      return 'Today';
    } else if (dateOnly == yesterday) {
      return 'Yesterday';
    } else {
      // Format as "Monday, January 15, 2024"
      const months = [
        'January',
        'February',
        'March',
        'April',
        'May',
        'June',
        'July',
        'August',
        'September',
        'October',
        'November',
        'December',
      ];
      const weekdays = [
        'Monday',
        'Tuesday',
        'Wednesday',
        'Thursday',
        'Friday',
        'Saturday',
        'Sunday',
      ];

      final weekday = weekdays[date.weekday - 1];
      final month = months[date.month - 1];
      return '$weekday, $month ${date.day}, ${date.year}';
    }
  }

  Widget _buildDateHeader(String dateKey) {
    return Container(
      margin: const EdgeInsets.only(top: 24, bottom: 16),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: widget.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: widget.primaryColor.withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.calendar_today, color: widget.primaryColor, size: 16),
          const SizedBox(width: 8),
          Text(
            dateKey,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: widget.primaryColor,
            ),
          ),
        ],
      ),
    );
  }

  List<Widget> _buildGroupedLogs() {
    final groupedLogs = _groupLogsByDate(confirmationLogs);
    final List<Widget> widgets = [];

    // Sort date keys to show most recent first
    final sortedKeys = groupedLogs.keys.toList();
    sortedKeys.sort((a, b) {
      // Custom sorting to put "Today" first, then "Yesterday", then chronological
      if (a == 'Today') return -1;
      if (b == 'Today') return 1;
      if (a == 'Yesterday') return -1;
      if (b == 'Yesterday') return 1;

      // For other dates, we need to parse them back to compare
      // Since they're formatted as "Monday, January 15, 2024", we'll use the original logs to sort
      final logsA = groupedLogs[a]!;
      final logsB = groupedLogs[b]!;
      final dateA = logsA.first.eventTime;
      final dateB = logsB.first.eventTime;
      return dateB.compareTo(dateA); // Most recent first
    });

    for (int i = 0; i < sortedKeys.length; i++) {
      final dateKey = sortedKeys[i];
      final logs = groupedLogs[dateKey]!;

      // Add date header (no top margin for first header)
      widgets.add(
        Container(
          margin: EdgeInsets.only(top: i == 0 ? 16 : 24, bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: widget.primaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: widget.primaryColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.calendar_today, color: widget.primaryColor, size: 16),
              const SizedBox(width: 8),
              Text(
                dateKey,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  fontSize: 14,
                  color: widget.primaryColor,
                ),
              ),
            ],
          ),
        ),
      );

      // Add logs for this date
      for (final log in logs) {
        widgets.add(_buildLogCard(log));
      }
    }

    return widgets;
  }

  Widget _buildLogCard(ConfirmationLog log) {
    final eventTypeText = _getEventTypeText(log.eventType);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with student name and verification status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        log.studentName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF222B45),
                        ),
                      ),
                      Text(
                        'Grade ${log.gradeLevel} - Section ${log.section}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8F9BB3),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                // Show verification status badge only for confirmed/denied
                if (log.verificationStatus != null &&
                    (log.verificationStatus!.toLowerCase() == 'confirmed' ||
                        log.verificationStatus!.toLowerCase() == 'denied'))
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Color(
                        int.parse(log.statusColor.replaceAll('#', '0xFF')),
                      ).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: Color(
                          int.parse(log.statusColor.replaceAll('#', '0xFF')),
                        ),
                        width: 1,
                      ),
                    ),
                    child: Text(
                      log.displayStatus.toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: Color(
                          int.parse(log.statusColor.replaceAll('#', '0xFF')),
                        ),
                      ),
                    ),
                  ),
              ],
            ),

            const SizedBox(height: 16),

            // Event details
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    log.eventType.toLowerCase() == 'pickup'
                        ? Icons.directions_car
                        : Icons.directions_walk,
                    color: widget.primaryColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        eventTypeText,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF222B45),
                        ),
                      ),
                      Text(
                        'Driver: ${log.driverName}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8F9BB3),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Date and time
            Row(
              children: [
                Icon(
                  Icons.access_time,
                  size: 16,
                  color: const Color(0xFF8F9BB3),
                ),
                const SizedBox(width: 8),
                Text(
                  _formatDateTime(log.eventTime),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8F9BB3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // Verification response time if available
            if (log.verificationResponseTime != null) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.verified,
                    size: 16,
                    color: const Color(0xFF8F9BB3),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Verified ${_formatDateTime(log.verificationResponseTime!)}',
                    style: const TextStyle(
                      fontSize: 14,
                      color: Color(0xFF8F9BB3),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],

            // Driver notes if available
            if (log.notes != null && log.notes!.isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8F9FA),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.note, size: 16, color: const Color(0xFF8F9BB3)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Driver Notes: ${log.notes!}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF8F9BB3),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Verification notes if available
            if (log.verificationNotes != null &&
                log.verificationNotes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E8),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(
                      Icons.comment,
                      size: 16,
                      color: const Color(0xFF19AE61),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your Notes: ${log.verificationNotes!}',
                        style: const TextStyle(
                          fontSize: 14,
                          color: Color(0xFF19AE61),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);

    // Show message if no student selected
    if (widget.selectedStudentId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 64,
              color: widget.primaryColor.withOpacity(0.5),
            ),
            SizedBox(height: 16),
            Text(
              'Please select a student',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF000000).withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Header
          Container(
            color: white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  height: 32,
                  width: 32,
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.contain,
                    errorBuilder:
                        (context, error, stackTrace) => Icon(
                          Icons.school,
                          color: widget.primaryColor,
                          size: 28,
                        ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  'Pickup & Drop-off Logs',
                  style: TextStyle(
                    color: black,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loadConfirmationLogs,
                  icon: Icon(
                    Icons.refresh,
                    color: widget.primaryColor,
                    size: 20,
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.history,
                    color: widget.primaryColor,
                    size: 20,
                  ),
                ),
              ],
            ),
          ),

          // Summary Card
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  spreadRadius: 1,
                ),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: _buildSummaryItem(
                    'Total Events',
                    '${confirmationLogs.length}',
                    Icons.event,
                    widget.primaryColor,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildSummaryItem(
                    'This Month',
                    '${confirmationLogs.where((log) => log.eventTime.month == DateTime.now().month).length}',
                    Icons.calendar_month,
                    Colors.blue,
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: _buildSummaryItem(
                    'Verified',
                    '${confirmationLogs.where((log) => log.verificationStatus?.toLowerCase() == "confirmed").length}',
                    Icons.verified,
                    Colors.green,
                  ),
                ),
              ],
            ),
          ),

          // Logs List
          if (isLoading)
            const Padding(
              padding: EdgeInsets.all(32),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (errorMessage != null)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.error_outline, size: 48, color: Colors.red[300]),
                    const SizedBox(height: 16),
                    Text(
                      errorMessage!,
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF8F9BB3),
                      ),
                    ),
                    const SizedBox(height: 16),
                    ElevatedButton(
                      onPressed: _loadConfirmationLogs,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: white,
                      ),
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            )
          else if (confirmationLogs.isEmpty)
            Padding(
              padding: const EdgeInsets.all(32),
              child: Center(
                child: Column(
                  children: [
                    Icon(Icons.history, size: 48, color: Colors.grey[300]),
                    const SizedBox(height: 16),
                    Text(
                      'No pickup/drop-off logs found',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF8F9BB3),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Pickup and drop-off logs will appear here once your child has transportation events.',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Color(0xFF8F9BB3),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            )
          else
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recent Pickup & Drop-off Events',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF222B45),
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._buildGroupedLogs(),
                  // Add bottom padding to prevent overflow
                  const SizedBox(height: 100),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(
    String label,
    String value,
    IconData icon,
    Color color,
  ) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 12),
        Text(
          value,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Color(0xFF222B45),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Color(0xFF8F9BB3),
            fontWeight: FontWeight.w500,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }
}

class ConfirmationLog {
  final String id;
  final String studentId;
  final String studentName;
  final String gradeLevel;
  final String section;
  final String eventType; // 'pickup' or 'dropoff'
  final String driverName;
  final DateTime eventTime;
  final String? notes;

  // Verification fields
  final String?
  verificationStatus; // 'confirmed', 'denied', 'pending', or null if no verification
  final DateTime? verificationResponseTime;
  final String? verificationNotes;

  ConfirmationLog({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.gradeLevel,
    required this.section,
    required this.eventType,
    required this.driverName,
    required this.eventTime,
    this.notes,
    this.verificationStatus,
    this.verificationResponseTime,
    this.verificationNotes,
  });

  factory ConfirmationLog.fromJson(
    Map<String, dynamic> json,
    Map<String, dynamic>? verification,
  ) {
    // Determine the actual event time based on event type
    DateTime eventTime;
    if (json['event_type'] == 'pickup' && json['pickup_time'] != null) {
      eventTime = DateTime.parse(json['pickup_time']);
    } else if (json['event_type'] == 'dropoff' &&
        json['dropoff_time'] != null) {
      eventTime = DateTime.parse(json['dropoff_time']);
    } else {
      eventTime = DateTime.parse(
        json['created_at'] ?? DateTime.now().toIso8601String(),
      );
    }

    return ConfirmationLog(
      id: json['id']?.toString() ?? '',
      studentId: json['student_id']?.toString() ?? '',
      studentName:
          '${json['students']?['fname'] ?? ''} ${json['students']?['lname'] ?? ''}'
              .trim(),
      gradeLevel: json['students']?['grade_level'] ?? '',
      section: json['students']?['sections']?['name'] ?? '',
      eventType: json['event_type'] ?? '',
      driverName:
          '${json['drivers']?['fname'] ?? ''} ${json['drivers']?['lname'] ?? ''}'
              .trim(),
      eventTime: eventTime,
      notes: json['notes'],
      verificationStatus: verification?['status'],
      verificationResponseTime:
          verification?['parent_response_time'] != null
              ? DateTime.parse(verification!['parent_response_time'])
              : null,
      verificationNotes: verification?['parent_notes'],
    );
  }

  // Helper getter for display status
  String get displayStatus {
    if (verificationStatus != null) {
      switch (verificationStatus!.toLowerCase()) {
        case 'confirmed':
          return 'Verified';
        case 'denied':
          return 'Denied';
        case 'pending':
          return 'Pending Verification';
        default:
          return verificationStatus!;
      }
    }
    return 'No Verification Required';
  }

  // Helper getter for status color
  String get statusColor {
    if (verificationStatus != null) {
      switch (verificationStatus!.toLowerCase()) {
        case 'confirmed':
          return '#19AE61'; // Green
        case 'denied':
          return '#FF0000'; // Red
        case 'pending':
          return '#FFA500'; // Orange
        default:
          return '#808080'; // Gray
      }
    }
    return '#808080'; // Gray for no verification
  }
}
