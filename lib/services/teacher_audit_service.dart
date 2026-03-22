import 'package:supabase_flutter/supabase_flutter.dart';
import 'audit_log_service.dart';

/// Specialized audit logging service for teacher operations
/// Extends the base AuditLogService to provide teacher-specific logging methods
class TeacherAuditService {
  final AuditLogService _auditService = AuditLogService();
  final supabase = Supabase.instance.client;

  // ATTENDANCE MANAGEMENT OPERATIONS

  /// Log individual attendance marking actions
  Future<bool> logAttendanceMarking({
    required String studentId,
    required String studentName,
    required String sectionId,
    required String sectionName,
    required String status, // 'present', 'absent', 'late', 'excused'
    required String date,
    bool isRfidAssisted = false,
    String? previousStatus,
    String? notes,
    Map<String, dynamic>? attendanceDetails,
  }) async {
    return await _auditService.logEvent(
      actionType: 'Update',
      actionCategory: 'Attendance Management',
      description:
          'Marked $studentName as $status for $date${previousStatus != null ? ' (changed from $previousStatus)' : ''}${isRfidAssisted ? ' - RFID assisted' : ' - Manual entry'}',
      targetType: 'student_attendance',
      targetId: '${studentId}_${date}',
      targetName: '$studentName - $date Attendance',
      module: 'Teacher Panel',
      metadata: {
        'student_id': studentId,
        'student_name': studentName,
        'section_id': sectionId,
        'section_name': sectionName,
        'attendance_status': status,
        'previous_status': previousStatus,
        'attendance_date': date,
        'is_rfid_assisted': isRfidAssisted,
        'notes': notes,
        'timestamp': DateTime.now().toIso8601String(),
        ...?attendanceDetails,
      },
    );
  }

  /// Log bulk attendance operations (e.g., "Mark All Present")
  Future<bool> logBulkAttendanceOperation({
    required String sectionId,
    required String sectionName,
    required String
    operation, // 'mark_all_present', 'mark_all_absent', 'bulk_update'
    required int affectedStudentCount,
    required String date,
    List<Map<String, dynamic>>? affectedStudents,
    String? notes,
    Map<String, dynamic>? operationDetails,
  }) async {
    return await _auditService.logEvent(
      actionType: 'Bulk Update',
      actionCategory: 'Attendance Management',
      description:
          'Bulk operation: $operation for $sectionName on $date (affected $affectedStudentCount students)',
      targetType: 'section_attendance',
      targetId: '${sectionId}_${date}_bulk',
      targetName: '$sectionName - Bulk $operation',
      module: 'Teacher Panel',
      metadata: {
        'section_id': sectionId,
        'section_name': sectionName,
        'operation_type': operation,
        'affected_student_count': affectedStudentCount,
        'attendance_date': date,
        'affected_students': affectedStudents,
        'notes': notes,
        'timestamp': DateTime.now().toIso8601String(),
        ...?operationDetails,
      },
    );
  }

  /// Log early dismissal approvals
  Future<bool> logEarlyDismissal({
    required String studentId,
    required String studentName,
    required String sectionId,
    required String sectionName,
    required String dismissalTime,
    required String reason,
    String? approvedBy,
    String? fetcherName,
    String? fetcherRelation,
    String? notes,
    Map<String, dynamic>? dismissalDetails,
  }) async {
    return await _auditService.logEvent(
      actionType: 'Authorization',
      actionCategory: 'Attendance Management',
      description:
          'Early dismissal approved for $studentName at $dismissalTime - Reason: $reason${fetcherName != null ? ' (Fetcher: $fetcherName)' : ''}',
      targetType: 'early_dismissal',
      targetId: '${studentId}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$studentName - Early Dismissal',
      module: 'Teacher Panel',
      status: 'warning',
      metadata: {
        'student_id': studentId,
        'student_name': studentName,
        'section_id': sectionId,
        'section_name': sectionName,
        'dismissal_time': dismissalTime,
        'dismissal_reason': reason,
        'approved_by': approvedBy,
        'fetcher_name': fetcherName,
        'fetcher_relation': fetcherRelation,
        'notes': notes,
        'timestamp': DateTime.now().toIso8601String(),
        ...?dismissalDetails,
      },
    );
  }

  /// Log emergency exit procedures
  Future<bool> logEmergencyExit({
    required String studentId,
    required String studentName,
    required String sectionId,
    required String sectionName,
    required String emergencyType, // 'medical', 'family', 'safety', 'other'
    required String reason,
    String? emergencyContact,
    String? contactNotified,
    String? authorizingTeacher,
    String? notes,
    Map<String, dynamic>? emergencyDetails,
  }) async {
    return await _auditService.logEvent(
      actionType: 'Alert',
      actionCategory: 'Attendance Management',
      description:
          'Emergency exit authorized for $studentName - Type: $emergencyType, Reason: $reason${emergencyContact != null ? ' (Contact: $emergencyContact)' : ''}',
      targetType: 'emergency_exit',
      targetId: '${studentId}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$studentName - Emergency Exit',
      module: 'Teacher Panel',
      status: 'error',
      metadata: {
        'student_id': studentId,
        'student_name': studentName,
        'section_id': sectionId,
        'section_name': sectionName,
        'emergency_type': emergencyType,
        'emergency_reason': reason,
        'emergency_contact': emergencyContact,
        'contact_notified': contactNotified,
        'authorizing_teacher': authorizingTeacher,
        'notes': notes,
        'timestamp': DateTime.now().toIso8601String(),
        ...?emergencyDetails,
      },
    );
  }

  // STUDENT ISSUE MANAGEMENT

  /// Log parent notification triggers
  Future<bool> logParentNotificationTrigger({
    required String studentId,
    required String studentName,
    required String
    notificationType, // 'attendance_ticket', 'behavior_alert', 'academic_concern'
    required String parentName,
    required String parentContact,
    required String notificationContent,
    String? triggerReason,
    Map<String, dynamic>? attendanceData,
    Map<String, dynamic>? notificationMetadata,
  }) async {
    return await _auditService.logEvent(
      actionType: 'Create',
      actionCategory: 'Student Issue Management',
      description:
          'Parent notification sent: $notificationType for $studentName to $parentName${triggerReason != null ? ' - Reason: $triggerReason' : ''}',
      targetType: 'parent_notification',
      targetId: '${studentId}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$studentName - $notificationType Notification',
      module: 'Teacher Panel',
      metadata: {
        'student_id': studentId,
        'student_name': studentName,
        'notification_type': notificationType,
        'parent_name': parentName,
        'parent_contact': parentContact,
        'notification_content': notificationContent,
        'trigger_reason': triggerReason,
        'attendance_data': attendanceData,
        'timestamp': DateTime.now().toIso8601String(),
        ...?notificationMetadata,
      },
    );
  }

  /// Log issue resolution actions
  Future<bool> logIssueResolution({
    required String issueId,
    required String studentId,
    required String studentName,
    required String
    issueType, // 'attendance_ticket', 'behavior_issue', 'academic_concern'
    required String
    resolution, // 'resolved_by_teacher', 'escalated_to_admin', 'parent_contacted'
    String? resolutionNotes,
    Map<String, dynamic>? followUpActions,
    Map<String, dynamic>? resolutionMetadata,
  }) async {
    return await _auditService.logEvent(
      actionType: 'Update',
      actionCategory: 'Student Issue Management',
      description:
          'Issue resolved: $issueType for $studentName - Resolution: $resolution${resolutionNotes != null ? ' (Notes: $resolutionNotes)' : ''}',
      targetType: 'issue_resolution',
      targetId: issueId,
      targetName: '$studentName - $issueType Resolution',
      module: 'Teacher Panel',
      metadata: {
        'student_id': studentId,
        'student_name': studentName,
        'issue_type': issueType,
        'resolution_type': resolution,
        'resolution_notes': resolutionNotes,
        'follow_up_actions': followUpActions,
        'timestamp': DateTime.now().toIso8601String(),
        ...?resolutionMetadata,
      },
    );
  }

  // DATA EXPORT & REPORTING

  /// Log teacher attendance export operations
  Future<bool> logTeacherAttendanceExport({
    required String sectionId,
    required String sectionName,
    required String
    exportType, // 'monthly_summary', 'detailed_report', 'student_calendar'
    required String fileName,
    required int recordCount,
    String? dateRange,
    String? filters,
    List<String>? includedStudents,
    Map<String, dynamic>? exportMetadata,
  }) async {
    return await _auditService.logEvent(
      actionType: 'Export',
      actionCategory: 'Data Export & Reporting',
      description:
          'Exported $exportType for $sectionName to $fileName ($recordCount records)${dateRange != null ? ' for $dateRange' : ''}',
      targetType: 'attendance_export',
      targetId: '${sectionId}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$sectionName - $exportType',
      module: 'Teacher Panel',
      metadata: {
        'section_id': sectionId,
        'section_name': sectionName,
        'export_type': exportType,
        'file_name': fileName,
        'record_count': recordCount,
        'date_range': dateRange,
        'applied_filters': filters,
        'included_students': includedStudents,
        'timestamp': DateTime.now().toIso8601String(),
        ...?exportMetadata,
      },
    );
  }

  /// Log monthly summary report generation
  Future<bool> logMonthlySummaryGeneration({
    required String sectionId,
    required String sectionName,
    required String month,
    required int studentCount,
    required Map<String, dynamic> summaryStats,
    String? exportFormat, // 'excel', 'pdf', 'csv'
    String? fileName,
    Map<String, dynamic>? reportMetadata,
  }) async {
    return await _auditService.logEvent(
      actionType: 'Generate',
      actionCategory: 'Data Export & Reporting',
      description:
          'Monthly summary generated for $sectionName ($month) - $studentCount students${fileName != null ? ' exported as $fileName' : ''}',
      targetType: 'monthly_summary',
      targetId: '${sectionId}_${month}',
      targetName: '$sectionName - $month Summary',
      module: 'Teacher Panel',
      metadata: {
        'section_id': sectionId,
        'section_name': sectionName,
        'report_month': month,
        'student_count': studentCount,
        'summary_statistics': summaryStats,
        'export_format': exportFormat,
        'file_name': fileName,
        'timestamp': DateTime.now().toIso8601String(),
        ...?reportMetadata,
      },
    );
  }

  // TEACHER AUTHENTICATION & SESSION

  /// Log teacher login/logout activities
  Future<bool> logTeacherAuthActivity({
    required String activity, // 'login', 'logout', 'session_timeout'
    String? teacherId,
    String? teacherName,
    String? ipAddress,
    String? deviceInfo,
    bool isSuccessful = true,
    String? failureReason,
    Map<String, dynamic>? authMetadata,
  }) async {
    final currentUser = supabase.auth.currentUser;
    final actualTeacherId = teacherId ?? currentUser?.id;
    final actualTeacherName =
        teacherName ?? currentUser?.email ?? 'Unknown Teacher';

    return await _auditService.logEvent(
      actionType: 'Security',
      actionCategory: 'Authentication',
      description:
          isSuccessful
              ? 'Teacher $activity successful: $actualTeacherName'
              : 'Teacher $activity failed: $actualTeacherName - ${failureReason ?? 'Unknown error'}',
      targetType: 'teacher_auth',
      targetId: actualTeacherId,
      targetName: actualTeacherName,
      module: 'Teacher Panel',
      status: isSuccessful ? 'success' : 'error',
      metadata: {
        'activity_type': activity,
        'teacher_id': actualTeacherId,
        'teacher_name': actualTeacherName,
        'ip_address': ipAddress,
        'device_info': deviceInfo,
        'failure_reason': failureReason,
        'timestamp': DateTime.now().toIso8601String(),
        ...?authMetadata,
      },
    );
  }

  /// Log teacher dashboard access and key metrics
  Future<bool> logDashboardAccess({
    String? teacherId,
    String? teacherName,
    List<String>? accessedSections,
    Map<String, dynamic>? dashboardMetrics,
    Map<String, dynamic>? accessMetadata,
  }) async {
    final currentUser = supabase.auth.currentUser;
    final actualTeacherId = teacherId ?? currentUser?.id;
    final actualTeacherName =
        teacherName ?? currentUser?.email ?? 'Unknown Teacher';

    return await _auditService.logEvent(
      actionType: 'Access',
      actionCategory: 'System Access',
      description:
          'Teacher dashboard accessed by $actualTeacherName${accessedSections != null ? ' (Sections: ${accessedSections.join(', ')})' : ''}',
      targetType: 'teacher_dashboard',
      targetId: 'dashboard_${actualTeacherId}',
      targetName: '$actualTeacherName Dashboard',
      module: 'Teacher Panel',
      metadata: {
        'teacher_id': actualTeacherId,
        'teacher_name': actualTeacherName,
        'accessed_sections': accessedSections,
        'dashboard_metrics': dashboardMetrics,
        'access_timestamp': DateTime.now().toIso8601String(),
        ...?accessMetadata,
      },
    );
  }

  // SECTION MANAGEMENT

  /// Log section access and management operations
  Future<bool> logSectionAccess({
    required String sectionId,
    required String sectionName,
    required String
    accessType, // 'view_attendance', 'edit_attendance', 'view_students', 'export_data'
    String? teacherId,
    String? teacherName,
    Map<String, dynamic>? accessDetails,
  }) async {
    final currentUser = supabase.auth.currentUser;
    final actualTeacherId = teacherId ?? currentUser?.id;
    final actualTeacherName =
        teacherName ?? currentUser?.email ?? 'Unknown Teacher';

    return await _auditService.logEvent(
      actionType: 'Access',
      actionCategory: 'Section Management',
      description:
          'Section access: $accessType for $sectionName by $actualTeacherName',
      targetType: 'section_access',
      targetId: '${sectionId}_${accessType}',
      targetName: '$sectionName - $accessType',
      module: 'Teacher Panel',
      metadata: {
        'section_id': sectionId,
        'section_name': sectionName,
        'access_type': accessType,
        'teacher_id': actualTeacherId,
        'teacher_name': actualTeacherName,
        'access_timestamp': DateTime.now().toIso8601String(),
        ...?accessDetails,
      },
    );
  }

  // HELPER METHODS

  /// Helper method to fetch student name by ID for cases where only ID is available
  Future<String> _getStudentNameById(String studentId) async {
    try {
      final studentData =
          await supabase
              .from('students')
              .select('fname, lname')
              .eq('id', studentId)
              .single();

      return '${studentData['fname']} ${studentData['lname']}';
    } catch (e) {
      print('Error fetching student name for ID $studentId: $e');
      return 'Student $studentId';
    }
  }

  /// Enhanced issue resolution that fetches student name if not provided
  Future<bool> logIssueResolutionWithLookup({
    required String issueId,
    required String studentId,
    String? studentName,
    required String issueType,
    required String resolution,
    String? resolutionNotes,
    Map<String, dynamic>? followUpActions,
    Map<String, dynamic>? resolutionMetadata,
  }) async {
    final actualStudentName =
        studentName ?? await _getStudentNameById(studentId);

    return await logIssueResolution(
      issueId: issueId,
      studentId: studentId,
      studentName: actualStudentName,
      issueType: issueType,
      resolution: resolution,
      resolutionNotes: resolutionNotes,
      followUpActions: followUpActions,
      resolutionMetadata: resolutionMetadata,
    );
  }

  /// Enhanced parent notification trigger that fetches student name if not provided
  Future<bool> logParentNotificationTriggerWithLookup({
    required String studentId,
    String? studentName,
    required String notificationType,
    required String parentName,
    required String parentContact,
    required String notificationContent,
    String? triggerReason,
    Map<String, dynamic>? attendanceData,
    Map<String, dynamic>? notificationMetadata,
  }) async {
    final actualStudentName =
        studentName ?? await _getStudentNameById(studentId);

    return await logParentNotificationTrigger(
      studentId: studentId,
      studentName: actualStudentName,
      notificationType: notificationType,
      parentName: parentName,
      parentContact: parentContact,
      notificationContent: notificationContent,
      triggerReason: triggerReason,
      attendanceData: attendanceData,
      notificationMetadata: notificationMetadata,
    );
  }
}
