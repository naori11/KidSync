import 'package:flutter/material.dart';
import '../services/attendance_ticketing_service.dart';
import '../widgets/notification_status_indicator.dart';
import '../widgets/smart_attendance_button.dart';

class StudentRowWithTicketing extends StatefulWidget {
  final Map<String, dynamic> student;
  final Map<String, dynamic> section;
  final String teacherName;
  final String? teacherId;
  final VoidCallback? onStatusChanged;

  const StudentRowWithTicketing({
    Key? key,
    required this.student,
    required this.section,
    required this.teacherName,
    this.teacherId,
    this.onStatusChanged,
  }) : super(key: key);

  @override
  State<StudentRowWithTicketing> createState() => _StudentRowWithTicketingState();
}

class _StudentRowWithTicketingState extends State<StudentRowWithTicketing> {
  final AttendanceTicketingService _ticketingService = AttendanceTicketingService();
  
  bool _isLoading = true;
  int _consecutiveAbsences = 0;
  NotificationStatusType _notificationStatus = NotificationStatusType.none;

  @override
  void initState() {
    super.initState();
    _loadStudentStatus();
  }

  Future<void> _loadStudentStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // Load consecutive absences
      final consecutiveAbsences = await _ticketingService.getConsecutiveAbsences(
        studentId: widget.student['id'],
        sectionId: widget.section['id'],
      );

      // Load ticket status
      final ticketStatus = await _ticketingService.getTicketStatus(
        studentId: widget.student['id'],
        sectionId: widget.section['id'],
      );

      setState(() {
        _consecutiveAbsences = consecutiveAbsences;
        
        if (ticketStatus['hasTicket']) {
          _notificationStatus = ticketStatus['isResolved'] 
              ? NotificationStatusType.resolved 
              : NotificationStatusType.pending;
        } else {
          _notificationStatus = NotificationStatusType.none;
        }
      });
    } catch (e) {
      print('Error loading student status: $e');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentName = '${widget.student['fname']} ${widget.student['lname']}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          // Student avatar
          CircleAvatar(
            radius: 24,
            backgroundColor: const Color(0xFFE5E7EB),
            backgroundImage: widget.student['profile_image_url'] != null 
                ? NetworkImage(widget.student['profile_image_url'])
                : null,
            child: widget.student['profile_image_url'] == null
                ? Text(
                    studentName[0].toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF374151),
                      fontSize: 18,
                    ),
                  )
                : null,
          ),
          
          const SizedBox(width: 16),
          
          // Student info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        studentName,
                        style: const TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 16,
                          color: Color(0xFF1F2937),
                        ),
                      ),
                    ),
                    // Status indicators
                    if (!_isLoading) ...[
                      AttendanceUrgencyIndicator(
                        consecutiveAbsences: _consecutiveAbsences,
                        notificationStatus: _notificationStatus,
                      ),
                      const SizedBox(width: 8),
                      NotificationStatusIndicator(
                        status: _notificationStatus,
                        consecutiveAbsences: _consecutiveAbsences,
                      ),
                    ],
                  ],
                ),
                
                const SizedBox(height: 4),
                
                Text(
                  widget.section['name'],
                  style: const TextStyle(
                    fontSize: 14,
                    color: Color(0xFF6B7280),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                
                if (!_isLoading && _consecutiveAbsences > 0) ...[
                  const SizedBox(height: 6),
                  Text(
                    "$_consecutiveAbsences consecutive absences",
                    style: const TextStyle(
                      fontSize: 12,
                      color: Color(0xFFDC2626),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ],
            ),
          ),
          
          const SizedBox(width: 16),
          
          // Action buttons
          if (!_isLoading)
            SmartAttendanceButton(
              studentId: widget.student['id'],
              sectionId: widget.section['id'],
              studentName: studentName,
              teacherName: widget.teacherName,
              sectionName: widget.section['name'],
              teacherId: widget.teacherId,
              onActionComplete: () {
                _loadStudentStatus();
                widget.onStatusChanged?.call();
              },
            )
          else
            const SizedBox(
              width: 120,
              height: 36,
              child: Center(
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Extension method to make the consecutive absences method accessible
extension AttendanceTicketingServiceExtension on AttendanceTicketingService {
  Future<int> getConsecutiveAbsencesPublic({
    required int studentId,
    required int sectionId,
  }) async {
    return await getConsecutiveAbsences(
      studentId: studentId,
      sectionId: sectionId,
    );
  }
}