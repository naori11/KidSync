import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ConfirmationLogsScreen extends StatefulWidget {
  final Color primaryColor;
  final bool isMobile;

  const ConfirmationLogsScreen({
    Key? key,
    required this.primaryColor,
    required this.isMobile,
  }) : super(key: key);

  @override
  State<ConfirmationLogsScreen> createState() => _ConfirmationLogsScreenState();
}

class _ConfirmationLogsScreenState extends State<ConfirmationLogsScreen> {
  final supabase = Supabase.instance.client;
  List<ConfirmationLog> confirmationLogs = [];
  bool isLoading = true;
  String? errorMessage;

  @override
  void initState() {
    super.initState();
    _loadConfirmationLogs();
  }

  Future<void> _loadConfirmationLogs() async {
    try {
      setState(() {
        isLoading = true;
        errorMessage = null;
      });

      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() {
          errorMessage = 'User not authenticated';
          isLoading = false;
        });
        return;
      }

      // Get parent ID
      final parentResponse =
          await supabase
              .from('parents')
              .select('id')
              .eq('user_id', user.id)
              .eq('status', 'active')
              .maybeSingle();

      if (parentResponse == null) {
        setState(() {
          errorMessage = 'Parent profile not found';
          isLoading = false;
        });
        return;
      }

      final parentId = parentResponse['id'];

      // Get student IDs for this parent
      final studentResponse = await supabase
          .from('parent_student')
          .select('student_id')
          .eq('parent_id', parentId);

      if (studentResponse.isEmpty) {
        setState(() {
          confirmationLogs = [];
          isLoading = false;
        });
        return;
      }

      final studentIds = studentResponse.map((s) => s['student_id']).toList();

      // Get confirmation logs for these students
      final logsResponse = await supabase
          .from('pickup_confirmations')
          .select('''
            id,
            student_id,
            confirmation_type,
            confirmed_by,
            confirmed_at,
            status,
            notes,
            students!inner(
              fname,
              lname,
              grade_level,
              section
            ),
            users!inner(
              fname,
              lname
            )
          ''')
          .inFilter('student_id', studentIds)
          .order('confirmed_at', ascending: false)
          .limit(50);

      final List<ConfirmationLog> logs =
          logsResponse.map((data) => ConfirmationLog.fromJson(data)).toList();

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

  String _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'confirmed':
        return '#19AE61'; // Green
      case 'pending':
        return '#FFA500'; // Orange
      case 'rejected':
        return '#FF0000'; // Red
      case 'cancelled':
        return '#808080'; // Gray
      default:
        return '#000000'; // Black
    }
  }

  String _getConfirmationTypeText(String type) {
    switch (type.toLowerCase()) {
      case 'pickup':
        return 'Pickup';
      case 'dropoff':
        return 'Drop-off';
      case 'early_pickup':
        return 'Early Pickup';
      case 'late_dropoff':
        return 'Late Drop-off';
      default:
        return type;
    }
  }

  Widget _buildLogCard(ConfirmationLog log) {
    final statusColor = _getStatusColor(log.status);
    final confirmationType = _getConfirmationTypeText(log.confirmationType);

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
            // Header row with student name and status
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${log.studentName}',
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
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Color(
                      int.parse(statusColor.replaceAll('#', '0xFF')),
                    ).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: Color(
                        int.parse(statusColor.replaceAll('#', '0xFF')),
                      ),
                      width: 1,
                    ),
                  ),
                  child: Text(
                    log.status.toUpperCase(),
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: Color(
                        int.parse(statusColor.replaceAll('#', '0xFF')),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // Confirmation details
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: widget.primaryColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    log.confirmationType.toLowerCase() == 'pickup'
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
                        confirmationType,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF222B45),
                        ),
                      ),
                      Text(
                        'Confirmed by ${log.confirmedByName}',
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
                  _formatDateTime(log.confirmedAt),
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF8F9BB3),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            // Notes if available
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
                        log.notes!,
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
          ],
        ),
      ),
    );
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

  @override
  Widget build(BuildContext context) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);

    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body: Column(
        children: [
          // Header
          Container(
            color: white,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: SafeArea(
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
                    'Confirmation Logs',
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
          ),

          // Main Content
          Expanded(
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary Card
                    Container(
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
                              'Total Confirmations',
                              '${confirmationLogs.length}',
                              Icons.check_circle,
                              widget.primaryColor,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildSummaryItem(
                              'This Month',
                              '${confirmationLogs.where((log) => log.confirmedAt.month == DateTime.now().month).length}',
                              Icons.calendar_month,
                              Colors.blue,
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: _buildSummaryItem(
                              'Pending',
                              '${confirmationLogs.where((log) => log.status.toLowerCase() == 'pending').length}',
                              Icons.pending,
                              Colors.orange,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Logs List
                    if (isLoading)
                      const Center(child: CircularProgressIndicator())
                    else if (errorMessage != null)
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.error_outline,
                              size: 48,
                              color: Colors.red[300],
                            ),
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
                      )
                    else if (confirmationLogs.isEmpty)
                      Center(
                        child: Column(
                          children: [
                            Icon(
                              Icons.history,
                              size: 48,
                              color: Colors.grey[300],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No confirmation logs found',
                              style: const TextStyle(
                                fontSize: 16,
                                color: Color(0xFF8F9BB3),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'Confirmation logs will appear here once you have pickup/drop-off confirmations.',
                              style: const TextStyle(
                                fontSize: 14,
                                color: Color(0xFF8F9BB3),
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Recent Confirmations',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF222B45),
                            ),
                          ),
                          const SizedBox(height: 16),
                          ...confirmationLogs.map((log) => _buildLogCard(log)),
                        ],
                      ),
                  ],
                ),
              ),
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
  final String confirmationType;
  final String confirmedByName;
  final DateTime confirmedAt;
  final String status;
  final String? notes;

  ConfirmationLog({
    required this.id,
    required this.studentId,
    required this.studentName,
    required this.gradeLevel,
    required this.section,
    required this.confirmationType,
    required this.confirmedByName,
    required this.confirmedAt,
    required this.status,
    this.notes,
  });

  factory ConfirmationLog.fromJson(Map<String, dynamic> json) {
    return ConfirmationLog(
      id: json['id'] ?? '',
      studentId: json['student_id'] ?? '',
      studentName:
          '${json['students']?['fname'] ?? ''} ${json['students']?['lname'] ?? ''}'
              .trim(),
      gradeLevel: json['students']?['grade_level'] ?? '',
      section: json['students']?['section'] ?? '',
      confirmationType: json['confirmation_type'] ?? '',
      confirmedByName:
          '${json['users']?['fname'] ?? ''} ${json['users']?['lname'] ?? ''}'
              .trim(),
      confirmedAt: DateTime.parse(
        json['confirmed_at'] ?? DateTime.now().toIso8601String(),
      ),
      status: json['status'] ?? '',
      notes: json['notes'],
    );
  }
}
