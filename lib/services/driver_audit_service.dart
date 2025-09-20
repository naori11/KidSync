import 'package:supabase_flutter/supabase_flutter.dart';
import 'audit_log_service.dart';

/// Specialized audit logging service for driver operations
/// Extends the base AuditLogService to provide driver-specific logging methods
class DriverAuditService {
  final AuditLogService _auditService = AuditLogService();
  final supabase = Supabase.instance.client;

  // STUDENT PICKUP/DROPOFF OPERATIONS (HIGH PRIORITY)

  /// Log student pickup operations
  Future<bool> logStudentPickup({
    required String studentId,
    required String studentName,
    required DateTime pickupTime,
    String? driverId,
    String? driverName,
    String? location,
    String? verificationStatus,
    String? notes,
    Map<String, dynamic>? pickupDetails,
  }) async {
    final currentUser = supabase.auth.currentUser;
    final actualDriverId = driverId ?? currentUser?.id;
    final actualDriverName = driverName ?? currentUser?.userMetadata?['fname'] ?? 'Unknown Driver';

    return await _auditService.logEvent(
      actionType: 'Create',
      actionCategory: 'Transportation Safety & Compliance',
      description: 'Student pickup completed: $studentName picked up by $actualDriverName at ${_formatTime(pickupTime)}${location != null ? ' from $location' : ''}',
      targetType: 'student_pickup',
      targetId: '${studentId}_${pickupTime.millisecondsSinceEpoch}',
      targetName: '$studentName - Pickup',
      module: 'Driver - Pickup/Dropoff',
      status: 'success',
      metadata: {
        'student_id': studentId,
        'student_name': studentName,
        'driver_id': actualDriverId,
        'driver_name': actualDriverName,
        'pickup_time': pickupTime.toIso8601String(),
        'location': location,
        'verification_status': verificationStatus,
        'notes': notes,
        'custody_transfer': 'driver_to_school',
        'safety_compliance': 'verified',
        'timestamp': DateTime.now().toIso8601String(),
        ...?pickupDetails,
      },
    );
  }

  /// Log student dropoff operations
  Future<bool> logStudentDropoff({
    required String studentId,
    required String studentName,
    required DateTime dropoffTime,
    String? driverId,
    String? driverName,
    String? location,
    String? verificationStatus,
    String? notes,
    Map<String, dynamic>? dropoffDetails,
  }) async {
    final currentUser = supabase.auth.currentUser;
    final actualDriverId = driverId ?? currentUser?.id;
    final actualDriverName = driverName ?? currentUser?.userMetadata?['fname'] ?? 'Unknown Driver';

    return await _auditService.logEvent(
      actionType: 'Create',
      actionCategory: 'Transportation Safety & Compliance',
      description: 'Student dropoff completed: $studentName dropped off by $actualDriverName at ${_formatTime(dropoffTime)}${location != null ? ' at $location' : ''}',
      targetType: 'student_dropoff',
      targetId: '${studentId}_${dropoffTime.millisecondsSinceEpoch}',
      targetName: '$studentName - Dropoff',
      module: 'Driver - Pickup/Dropoff',
      status: 'success',
      metadata: {
        'student_id': studentId,
        'student_name': studentName,
        'driver_id': actualDriverId,
        'driver_name': actualDriverName,
        'dropoff_time': dropoffTime.toIso8601String(),
        'location': location,
        'verification_status': verificationStatus,
        'notes': notes,
        'duty_of_care': 'completed',
        'safe_delivery': 'confirmed',
        'timestamp': DateTime.now().toIso8601String(),
        ...?dropoffDetails,
      },
    );
  }

  /// Log verification request creation for parent notifications
  Future<bool> logVerificationRequestCreation({
    required String studentId,
    required String studentName,
    required String eventType, // 'pickup' or 'dropoff'
    required DateTime eventTime,
    String? driverId,
    String? driverName,
    String? parentNotificationStatus,
    String? verificationMethod,
    Map<String, dynamic>? verificationDetails,
  }) async {
    final currentUser = supabase.auth.currentUser;
    final actualDriverId = driverId ?? currentUser?.id;
    final actualDriverName = driverName ?? currentUser?.userMetadata?['fname'] ?? 'Unknown Driver';

    return await _auditService.logEvent(
      actionType: 'Create',
      actionCategory: 'Transportation Safety & Compliance',
      description: 'Verification request created: $eventType verification for $studentName - Parent notification ${parentNotificationStatus ?? 'sent'}',
      targetType: 'verification_request',
      targetId: '${studentId}_${eventType}_${eventTime.millisecondsSinceEpoch}',
      targetName: '$studentName - $eventType Verification',
      module: 'Driver - Parent Verification',
      status: parentNotificationStatus == 'failed' ? 'warning' : 'success',
      metadata: {
        'student_id': studentId,
        'student_name': studentName,
        'driver_id': actualDriverId,
        'driver_name': actualDriverName,
        'event_type': eventType,
        'event_time': eventTime.toIso8601String(),
        'parent_notification_status': parentNotificationStatus,
        'verification_method': verificationMethod,
        'safety_verification': 'required',
        'parent_communication': 'initiated',
        'timestamp': DateTime.now().toIso8601String(),
        ...?verificationDetails,
      },
    );
  }

  /// Log pickup cancellation operations
  Future<bool> logPickupCancellation({
    required String studentId,
    required String studentName,
    required String reason,
    String? driverId,
    String? driverName,
    String? notes,
    Map<String, dynamic>? cancellationDetails,
  }) async {
    final currentUser = supabase.auth.currentUser;
    final actualDriverId = driverId ?? currentUser?.id;
    final actualDriverName = driverName ?? currentUser?.userMetadata?['fname'] ?? 'Unknown Driver';

    return await _auditService.logEvent(
      actionType: 'Update',
      actionCategory: 'Transportation Safety & Compliance',
      description: 'Pickup cancelled: $studentName pickup cancelled by $actualDriverName - Reason: $reason',
      targetType: 'pickup_cancellation',
      targetId: '${studentId}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$studentName - Pickup Cancelled',
      module: 'Driver - Pickup/Dropoff',
      status: 'warning',
      metadata: {
        'student_id': studentId,
        'student_name': studentName,
        'driver_id': actualDriverId,
        'driver_name': actualDriverName,
        'cancellation_reason': reason,
        'notes': notes,
        'operation_status': 'cancelled',
        'timestamp': DateTime.now().toIso8601String(),
        ...?cancellationDetails,
      },
    );
  }

  /// Log dropoff cancellation operations
  Future<bool> logDropoffCancellation({
    required String studentId,
    required String studentName,
    required String reason,
    String? driverId,
    String? driverName,
    String? notes,
    Map<String, dynamic>? cancellationDetails,
  }) async {
    final currentUser = supabase.auth.currentUser;
    final actualDriverId = driverId ?? currentUser?.id;
    final actualDriverName = driverName ?? currentUser?.userMetadata?['fname'] ?? 'Unknown Driver';

    return await _auditService.logEvent(
      actionType: 'Update',
      actionCategory: 'Transportation Safety & Compliance',
      description: 'Dropoff cancelled: $studentName dropoff cancelled by $actualDriverName - Reason: $reason',
      targetType: 'dropoff_cancellation',
      targetId: '${studentId}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$studentName - Dropoff Cancelled',
      module: 'Driver - Pickup/Dropoff',
      status: 'warning',
      metadata: {
        'student_id': studentId,
        'student_name': studentName,
        'driver_id': actualDriverId,
        'driver_name': actualDriverName,
        'cancellation_reason': reason,
        'notes': notes,
        'operation_status': 'cancelled',
        'timestamp': DateTime.now().toIso8601String(),
        ...?cancellationDetails,
      },
    );
  }

  // DRIVER AUTHENTICATION & SESSION (HIGH PRIORITY)

  /// Log driver login and session timeout activities (logout not logged)
  Future<bool> logDriverAuthActivity({
    required String activity, // 'login', 'session_timeout'
    String? driverId,
    String? driverName,
    String? ipAddress,
    String? deviceInfo,
    bool isSuccessful = true,
    String? failureReason,
    Duration? sessionDuration,
    Map<String, dynamic>? authMetadata,
  }) async {
    // Skip logging logout activities
    if (activity.toLowerCase() == 'logout') {
      return true;
    }

    final currentUser = supabase.auth.currentUser;
    final actualDriverId = driverId ?? currentUser?.id;
    final actualDriverName = driverName ?? currentUser?.userMetadata?['fname'] ?? 'Unknown Driver';

    return await _auditService.logEvent(
      actionType: 'Security',
      actionCategory: 'Authentication',
      description: isSuccessful
          ? 'Driver $activity successful: $actualDriverName${sessionDuration != null ? ' (session: ${sessionDuration.inMinutes}min)' : ''}'
          : 'Driver $activity failed: $actualDriverName - ${failureReason ?? 'Unknown error'}',
      targetType: 'driver_auth',
      targetId: actualDriverId,
      targetName: actualDriverName,
      module: 'Driver - Authentication',
      status: isSuccessful ? 'success' : 'error',
      metadata: {
        'activity_type': activity,
        'driver_id': actualDriverId,
        'driver_name': actualDriverName,
        'ip_address': ipAddress,
        'device_info': deviceInfo,
        'successful': isSuccessful,
        'failure_reason': failureReason,
        'session_duration_minutes': sessionDuration?.inMinutes,
        'access_control': 'verified',
        'shift_tracking': activity == 'login' ? 'started' : 'monitored',
        'accountability': 'logged',
        'timestamp': DateTime.now().toIso8601String(),
        ...?authMetadata,
      },
    );
  }

  /// Log driver dashboard access and key metrics
  Future<bool> logDashboardAccess({
    String? driverId,
    String? driverName,
    Map<String, dynamic>? dashboardMetrics,
    Map<String, dynamic>? accessMetadata,
  }) async {
    final currentUser = supabase.auth.currentUser;
    final actualDriverId = driverId ?? currentUser?.id;
    final actualDriverName = driverName ?? currentUser?.userMetadata?['fname'] ?? 'Unknown Driver';

    return await _auditService.logEvent(
      actionType: 'View',
      actionCategory: 'System Access',
      description: 'Driver dashboard accessed by $actualDriverName',
      targetType: 'dashboard',
      targetId: 'driver_dashboard',
      targetName: 'Driver Dashboard',
      module: 'Driver - Dashboard',
      status: 'success',
      metadata: {
        'driver_id': actualDriverId,
        'driver_name': actualDriverName,
        'access_time': DateTime.now().toIso8601String(),
        'dashboard_metrics': dashboardMetrics,
        'session_activity': 'dashboard_access',
        ...?accessMetadata,
      },
    );
  }

  // TASK COMPLETION & OPERATIONAL TRACKING (MEDIUM PRIORITY)

  /// Log task completion and route efficiency
  Future<bool> logTaskCompletion({
    required int totalStudents,
    required Duration completionTime,
    required String routeType, // 'morning_pickup', 'afternoon_dropoff', 'mixed'
    String? driverId,
    String? driverName,
    Map<String, dynamic>? routeEfficiencyMetrics,
    List<String>? completedStudentIds,
    Map<String, dynamic>? performanceMetrics,
  }) async {
    final currentUser = supabase.auth.currentUser;
    final actualDriverId = driverId ?? currentUser?.id;
    final actualDriverName = driverName ?? currentUser?.userMetadata?['fname'] ?? 'Unknown Driver';

    return await _auditService.logEvent(
      actionType: 'Complete',
      actionCategory: 'Operational Tracking',
      description: 'Route task completed: $actualDriverName completed $routeType route with $totalStudents students in ${completionTime.inMinutes} minutes',
      targetType: 'task_completion',
      targetId: '${routeType}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$actualDriverName - $routeType Route',
      module: 'Driver - Route Management',
      status: 'success',
      metadata: {
        'driver_id': actualDriverId,
        'driver_name': actualDriverName,
        'route_type': routeType,
        'total_students': totalStudents,
        'completion_time_minutes': completionTime.inMinutes,
        'route_efficiency_metrics': routeEfficiencyMetrics,
        'completed_student_ids': completedStudentIds,
        'performance_metrics': performanceMetrics,
        'operational_status': 'completed',
        'efficiency_rating': _calculateEfficiencyRating(totalStudents, completionTime),
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log route start operations
  Future<bool> logRouteStart({
    required String routeType, // 'morning_pickup', 'afternoon_dropoff'
    required int scheduledStudents,
    String? driverId,
    String? driverName,
    DateTime? startTime,
    Map<String, dynamic>? routeDetails,
  }) async {
    final currentUser = supabase.auth.currentUser;
    final actualDriverId = driverId ?? currentUser?.id;
    final actualDriverName = driverName ?? currentUser?.userMetadata?['fname'] ?? 'Unknown Driver';
    final actualStartTime = startTime ?? DateTime.now();

    return await _auditService.logEvent(
      actionType: 'Start',
      actionCategory: 'Operational Tracking',
      description: 'Route started: $actualDriverName began $routeType route with $scheduledStudents scheduled students',
      targetType: 'route_start',
      targetId: '${routeType}_${actualStartTime.millisecondsSinceEpoch}',
      targetName: '$actualDriverName - $routeType Start',
      module: 'Driver - Route Management',
      status: 'info',
      metadata: {
        'driver_id': actualDriverId,
        'driver_name': actualDriverName,
        'route_type': routeType,
        'scheduled_students': scheduledStudents,
        'start_time': actualStartTime.toIso8601String(),
        'route_details': routeDetails,
        'operational_status': 'in_progress',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log student information access
  Future<bool> logStudentInfoAccess({
    required String studentId,
    required String studentName,
    required String accessType, // 'view_details', 'view_contact', 'view_schedule'
    String? driverId,
    String? driverName,
    Map<String, dynamic>? accessDetails,
  }) async {
    final currentUser = supabase.auth.currentUser;
    final actualDriverId = driverId ?? currentUser?.id;
    final actualDriverName = driverName ?? currentUser?.userMetadata?['fname'] ?? 'Unknown Driver';

    return await _auditService.logEvent(
      actionType: 'View',
      actionCategory: 'Data Access',
      description: 'Student information accessed: $actualDriverName viewed $accessType for $studentName',
      targetType: 'student_info_access',
      targetId: '${studentId}_${accessType}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$studentName - Info Access',
      module: 'Driver - Student Information',
      status: 'info',
      metadata: {
        'student_id': studentId,
        'student_name': studentName,
        'driver_id': actualDriverId,
        'driver_name': actualDriverName,
        'access_type': accessType,
        'access_details': accessDetails,
        'data_privacy': 'maintained',
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  // ERROR HANDLING & SYSTEM ISSUES

  /// Log system errors encountered by drivers
  Future<bool> logDriverSystemError({
    required String errorType,
    required String errorDescription,
    String? systemComponent, // 'app', 'verification_service', 'database', 'network'
    String? errorCode,
    String? driverResponse,
    String? resolutionAction,
    String? driverId,
    String? driverName,
    Map<String, dynamic>? errorDetails,
  }) async {
    final currentUser = supabase.auth.currentUser;
    final actualDriverId = driverId ?? currentUser?.id;
    final actualDriverName = driverName ?? currentUser?.userMetadata?['fname'] ?? 'Unknown Driver';

    return await _auditService.logEvent(
      actionType: 'System',
      actionCategory: 'System Error',
      description: 'Driver system error: $errorType in ${systemComponent ?? 'unknown component'} - $errorDescription (Driver: $actualDriverName)',
      targetType: 'driver_system_error',
      targetId: '${errorType}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$errorType - Driver System',
      module: 'Driver - Error Handling',
      status: 'error',
      metadata: {
        'error_type': errorType,
        'system_component': systemComponent,
        'error_code': errorCode,
        'driver_id': actualDriverId,
        'driver_name': actualDriverName,
        'driver_response': driverResponse,
        'resolution_action': resolutionAction,
        'error_time': DateTime.now().toIso8601String(),
        'error_details': errorDetails,
      },
    );
  }

  /// Log pickup/dropoff validation failures
  Future<bool> logValidationFailure({
    required String studentId,
    required String studentName,
    required String validationType, // 'pickup_time', 'dropoff_sequence', 'authorization'
    required String failureReason,
    String? driverId,
    String? driverName,
    String? expectedValue,
    String? actualValue,
    Map<String, dynamic>? validationDetails,
  }) async {
    final currentUser = supabase.auth.currentUser;
    final actualDriverId = driverId ?? currentUser?.id;
    final actualDriverName = driverName ?? currentUser?.userMetadata?['fname'] ?? 'Unknown Driver';

    return await _auditService.logEvent(
      actionType: 'Alert',
      actionCategory: 'Validation Error',
      description: 'Validation failure: $validationType validation failed for $studentName - $failureReason (Driver: $actualDriverName)',
      targetType: 'validation_failure',
      targetId: '${studentId}_${validationType}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$studentName - $validationType Validation',
      module: 'Driver - Validation',
      status: 'warning',
      metadata: {
        'student_id': studentId,
        'student_name': studentName,
        'driver_id': actualDriverId,
        'driver_name': actualDriverName,
        'validation_type': validationType,
        'failure_reason': failureReason,
        'expected_value': expectedValue,
        'actual_value': actualValue,
        'validation_time': DateTime.now().toIso8601String(),
        'validation_details': validationDetails,
      },
    );
  }

  // HELPER METHODS

  /// Format time for display in audit logs
  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:${time.minute.toString().padLeft(2, '0')}';
  }

  /// Calculate efficiency rating based on students and time
  String _calculateEfficiencyRating(int totalStudents, Duration completionTime) {
    if (totalStudents == 0) return 'N/A';
    
    final minutesPerStudent = completionTime.inMinutes / totalStudents;
    
    if (minutesPerStudent <= 3) return 'Excellent';
    if (minutesPerStudent <= 5) return 'Good';
    if (minutesPerStudent <= 8) return 'Average';
    return 'Needs Improvement';
  }
}