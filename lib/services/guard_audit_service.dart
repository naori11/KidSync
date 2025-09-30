import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'audit_log_service.dart';

/// Specialized audit logging service for guard operations
/// Extends the base AuditLogService to provide guard-specific logging methods
class GuardAuditService {
  final AuditLogService _auditService = AuditLogService();
  final supabase = Supabase.instance.client;

  // RFID SCAN OPERATIONS

  /// Log RFID scan attempts (successful and failed)
  Future<bool> logRFIDScanAttempt({
    required String rfidUid,
    required bool isSuccessful,
    String? studentId,
    String? studentName,
    String? failureReason,
    Map<String, dynamic>? scanMetadata,
  }) async {
    return await _auditService.logEvent(
      actionType: isSuccessful ? 'Security' : 'Security',
      actionCategory: 'RFID Operations',
      description: isSuccessful
          ? 'RFID scan successful for UID: $rfidUid${studentName != null ? ' (Student: $studentName)' : ''}'
          : 'RFID scan failed for UID: $rfidUid${failureReason != null ? ' - Reason: $failureReason' : ''}',
      targetType: 'rfid_scan',
      targetId: rfidUid,
      targetName: studentName ?? 'Unknown',
      module: 'Guard - RFID System',
      status: isSuccessful ? 'success' : 'warning',
      metadata: {
        'rfid_uid': rfidUid,
        'student_id': studentId,
        'scan_successful': isSuccessful,
        'failure_reason': failureReason,
        'timestamp': DateTime.now().toIso8601String(),
        ...?scanMetadata,
      },
    );
  }

  /// Log student entry/check-in operations
  Future<bool> logStudentEntry({
    required String studentId,
    required String studentName,
    required String rfidUid,
    String? sectionName,
    bool isSuccessful = true,
    String? notes,
  }) async {
    return await _auditService.logEvent(
      actionType: 'Security',
      actionCategory: 'Student Entry/Exit',
      description: isSuccessful
          ? 'Student check-in: $studentName entered school premises via RFID scan'
          : 'Student check-in failed: $studentName - RFID scan unsuccessful',
      targetType: 'student',
      targetId: studentId,
      targetName: studentName,
      module: 'Guard - Entry System',
      status: isSuccessful ? 'success' : 'error',
      metadata: {
        'action': 'entry',
        'rfid_uid': rfidUid,
        'section_name': sectionName,
        'entry_time': DateTime.now().toIso8601String(),
        'notes': notes,
        'verified_by': 'RFID Scan',
      },
    );
  }

  /// Log student exit/check-out operations with approval/denial
  Future<bool> logStudentExit({
    required String studentId,
    required String studentName,
    required String rfidUid,
    required bool isApproved,
    String? fetcherName,
    String? fetcherType,
    String? denyReason,
    String? exitType, // 'regular', 'early_dismissal', 'emergency_exit'
    String? sectionName,
    String? notes,
    Map<String, dynamic>? scheduleOverride,
  }) async {
    return await _auditService.logEvent(
      actionType: isApproved ? 'Security' : 'Security',
      actionCategory: 'Student Entry/Exit',
      description: isApproved
          ? 'Student check-out approved: $studentName exited with ${fetcherName ?? 'authorized person'}${exitType != null && exitType != 'regular' ? ' ($exitType)' : ''}'
          : 'Student check-out denied: $studentName - ${denyReason ?? 'Unauthorized pickup attempt'}',
      targetType: 'student',
      targetId: studentId,
      targetName: studentName,
      module: 'Guard - Exit System',
      status: isApproved ? 'success' : 'warning',
      metadata: {
        'action': 'exit',
        'rfid_uid': rfidUid,
        'approved': isApproved,
        'fetcher_name': fetcherName,
        'fetcher_type': fetcherType,
        'deny_reason': denyReason,
        'exit_type': exitType,
        'section_name': sectionName,
        'exit_time': DateTime.now().toIso8601String(),
        'notes': notes,
        'schedule_override': scheduleOverride,
      },
    );
  }

  // FETCHER VERIFICATION OPERATIONS

  /// Log authorized fetcher verification attempts
  Future<bool> logAuthorizedFetcherVerification({
    required String studentId,
    required String studentName,
    required String fetcherId,
    required String fetcherName,
    required String fetcherType, // 'parent', 'guardian', etc.
    required bool isVerified,
    String? verificationMethod,
    String? notes,
  }) async {
    return await _auditService.logEvent(
      actionType: 'Security',
      actionCategory: 'Fetcher Verification',
      description: isVerified
          ? 'Authorized fetcher verified: $fetcherName ($fetcherType) for student $studentName'
          : 'Authorized fetcher verification failed: $fetcherName for student $studentName',
      targetType: 'fetcher_verification',
      targetId: '${studentId}_$fetcherId',
      targetName: '$fetcherName - $studentName',
      module: 'Guard - Fetcher System',
      status: isVerified ? 'success' : 'warning',
      metadata: {
        'student_id': studentId,
        'fetcher_id': fetcherId,
        'fetcher_type': fetcherType,
        'verification_method': verificationMethod,
        'verified': isVerified,
        'verification_time': DateTime.now().toIso8601String(),
        'notes': notes,
      },
    );
  }

  /// Log temporary fetcher PIN verification attempts
  Future<bool> logTemporaryFetcherPINVerification({
    required String studentId,
    required String studentName,
    required String pin,
    required bool isSuccessful,
    String? fetcherName,
    String? tempFetcherId,
    String? failureReason,
    Map<String, dynamic>? fetcherDetails,
  }) async {
    return await _auditService.logEvent(
      actionType: isSuccessful ? 'Security' : 'Security',
      actionCategory: 'Fetcher Verification',
      description: isSuccessful
          ? 'Temporary fetcher PIN verified: $pin for ${fetcherName ?? 'unknown fetcher'} (Student: $studentName)'
          : 'Temporary fetcher PIN verification failed: $pin for student $studentName - ${failureReason ?? 'Invalid PIN'}',
      targetType: 'temp_fetcher_verification',
      targetId: tempFetcherId ?? '${studentId}_$pin',
      targetName: '${fetcherName ?? 'Unknown'} - $studentName',
      module: 'Guard - PIN System',
      status: isSuccessful ? 'success' : 'warning',
      metadata: {
        'student_id': studentId,
        'pin_code': pin,
        'temp_fetcher_id': tempFetcherId,
        'fetcher_name': fetcherName,
        'verification_successful': isSuccessful,
        'failure_reason': failureReason,
        'verification_time': DateTime.now().toIso8601String(),
        'fetcher_details': fetcherDetails,
      },
    );
  }

  /// Log unauthorized pickup attempt denials
  Future<bool> logUnauthorizedPickupAttempt({
    required String studentId,
    required String studentName,
    required String attemptType, // 'unknown_person', 'invalid_pin', 'suspicious_behavior'
    required String denyReason,
    String? attemptedFetcherName,
    String? attemptedPin,
    String? suspiciousDetails,
    Map<String, dynamic>? incidentDetails,
  }) async {
    return await _auditService.logEvent(
      actionType: 'Security',
      actionCategory: 'Security Incident',
      description: 'Unauthorized pickup attempt blocked: $denyReason (Student: $studentName)${attemptedFetcherName != null ? ' - Attempted by: $attemptedFetcherName' : ''}',
      targetType: 'security_incident',
      targetId: '${studentId}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$studentName - Unauthorized Pickup',
      module: 'Guard - Security',
      status: 'error',
      metadata: {
        'incident_type': 'unauthorized_pickup_attempt',
        'student_id': studentId,
        'attempt_type': attemptType,
        'deny_reason': denyReason,
        'attempted_fetcher_name': attemptedFetcherName,
        'attempted_pin': attemptedPin,
        'suspicious_details': suspiciousDetails,
        'incident_time': DateTime.now().toIso8601String(),
        'incident_details': incidentDetails,
      },
    );
  }

  // SECURITY & ACCESS CONTROL

  /// Log guard login/logout activities
  Future<bool> logGuardAuthActivity({
    required String activity, // 'login', 'logout', 'session_timeout'
    String? guardId,
    String? guardName,
    String? ipAddress,
    String? deviceInfo,
    bool isSuccessful = true,
    String? failureReason,
  }) async {
    final currentUser = supabase.auth.currentUser;
    final actualGuardId = guardId ?? currentUser?.id;
    final actualGuardName = guardName ?? currentUser?.email ?? 'Unknown Guard';

    return await _auditService.logEvent(
      actionType: 'Security',
      actionCategory: 'Authentication',
      description: isSuccessful
          ? 'Guard $activity successful: $actualGuardName'
          : 'Guard $activity failed: $actualGuardName - ${failureReason ?? 'Unknown error'}',
      targetType: 'guard_auth',
      targetId: actualGuardId,
      targetName: actualGuardName,
      module: 'Guard - Authentication',
      status: isSuccessful ? 'success' : 'error',
      metadata: {
        'activity': activity,
        'guard_id': actualGuardId,
        'ip_address': ipAddress,
        'device_info': deviceInfo,
        'successful': isSuccessful,
        'failure_reason': failureReason,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log RFID system access and usage
  Future<bool> logRFIDSystemAccess({
    required String accessType, // 'system_start', 'system_stop', 'websocket_connect', 'websocket_disconnect'
    String? connectionDetails,
    bool isSuccessful = true,
    String? errorDetails,
  }) async {
    return await _auditService.logEvent(
      actionType: 'System',
      actionCategory: 'System Access',
      description: isSuccessful
          ? 'RFID system access: $accessType completed successfully'
          : 'RFID system access failed: $accessType - ${errorDetails ?? 'Unknown error'}',
      targetType: 'rfid_system',
      targetId: 'rfid_system_main',
      targetName: 'RFID Scanner System',
      module: 'Guard - RFID System',
      status: isSuccessful ? 'success' : 'error',
      metadata: {
        'access_type': accessType,
        'connection_details': connectionDetails,
        'successful': isSuccessful,
        'error_details': errorDetails,
        'access_time': DateTime.now().toIso8601String(),
      },
    );
  }

  // CRITICAL DECISION POINTS

  /// Log pickup denial decisions with detailed reasons
  Future<bool> logPickupDenialDecision({
    required String studentId,
    required String studentName,
    required String denyReason,
    required String fetcherType, // 'authorized', 'temporary', 'unauthorized'
    String? fetcherName,
    String? additionalNotes,
    Map<String, dynamic>? decisionContext,
  }) async {
    return await _auditService.logEvent(
      actionType: 'Security',
      actionCategory: 'Critical Decision',
      description: 'Pickup denied with reason: $denyReason (Student: $studentName, Fetcher: ${fetcherName ?? 'Unknown'}, Type: $fetcherType)',
      targetType: 'pickup_denial',
      targetId: '${studentId}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$studentName - Pickup Denied',
      module: 'Guard - Decision Making',
      status: 'warning',
      metadata: {
        'student_id': studentId,
        'deny_reason': denyReason,
        'fetcher_type': fetcherType,
        'fetcher_name': fetcherName,
        'additional_notes': additionalNotes,
        'decision_time': DateTime.now().toIso8601String(),
        'decision_context': decisionContext,
      },
    );
  }

  /// Log override authorizations and justifications
  Future<bool> logOverrideAuthorization({
    required String overrideType, // 'schedule_validation', 'emergency_exit', 'early_dismissal'
    required String studentId,
    required String studentName,
    required String justification,
    String? originalRestriction,
    String? overrideReason,
    Map<String, dynamic>? overrideDetails,
  }) async {
    return await _auditService.logEvent(
      actionType: 'Security',
      actionCategory: 'Override Authorization',
      description: 'Override authorized: $overrideType for student $studentName - Justification: $justification',
      targetType: 'override_authorization',
      targetId: '${studentId}_${overrideType}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$studentName - $overrideType Override',
      module: 'Guard - Override System',
      status: 'warning',
      metadata: {
        'override_type': overrideType,
        'student_id': studentId,
        'justification': justification,
        'original_restriction': originalRestriction,
        'override_reason': overrideReason,
        'override_time': DateTime.now().toIso8601String(),
        'override_details': overrideDetails,
      },
    );
  }

  /// Log emergency situation handling
  Future<bool> logEmergencyHandling({
    required String emergencyType, // 'emergency_exit', 'medical_emergency', 'security_threat'
    required String description,
    String? studentId,
    String? studentName,
    String? responseAction,
    String? emergencyContact,
    Map<String, dynamic>? emergencyDetails,
  }) async {
    return await _auditService.logEvent(
      actionType: 'Security',
      actionCategory: 'Emergency Response',
      description: 'Emergency handled: $emergencyType - $description${studentName != null ? ' (Student: $studentName)' : ''}',
      targetType: 'emergency_response',
      targetId: '${emergencyType}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: studentName != null ? '$studentName - $emergencyType' : emergencyType,
      module: 'Guard - Emergency Response',
      status: 'error',
      metadata: {
        'emergency_type': emergencyType,
        'student_id': studentId,
        'response_action': responseAction,
        'emergency_contact': emergencyContact,
        'emergency_time': DateTime.now().toIso8601String(),
        'emergency_details': emergencyDetails,
      },
    );
  }

  /// Log suspicious activity reporting
  Future<bool> logSuspiciousActivity({
    required String activityType,
    required String description,
    String? involvedPersons,
    String? location,
    String? reportedTo,
    String? followUpAction,
    Map<String, dynamic>? incidentDetails,
  }) async {
    return await _auditService.logEvent(
      actionType: 'Security',
      actionCategory: 'Security Incident',
      description: 'Suspicious activity reported: $activityType - $description',
      targetType: 'suspicious_activity',
      targetId: '${activityType}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$activityType - Suspicious Activity',
      module: 'Guard - Security Monitoring',
      status: 'warning',
      metadata: {
        'activity_type': activityType,
        'involved_persons': involvedPersons,
        'location': location,
        'reported_to': reportedTo,
        'follow_up_action': followUpAction,
        'incident_time': DateTime.now().toIso8601String(),
        'incident_details': incidentDetails,
      },
    );
  }

  // SYSTEM ERROR HANDLING

  /// Log system errors and guard responses
  Future<bool> logSystemError({
    required String errorType,
    required String errorDescription,
    String? systemComponent, // 'rfid_scanner', 'database', 'websocket', 'camera'
    String? errorCode,
    String? guardResponse,
    String? resolutionAction,
    Map<String, dynamic>? errorDetails,
  }) async {
    return await _auditService.logEvent(
      actionType: 'System',
      actionCategory: 'System Error',
      description: 'System error encountered: $errorType in ${systemComponent ?? 'unknown component'} - $errorDescription',
      targetType: 'system_error',
      targetId: '${errorType}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$errorType - ${systemComponent ?? 'System'}',
      module: 'Guard - Error Handling',
      status: 'error',
      metadata: {
        'error_type': errorType,
        'system_component': systemComponent,
        'error_code': errorCode,
        'guard_response': guardResponse,
        'resolution_action': resolutionAction,
        'error_time': DateTime.now().toIso8601String(),
        'error_details': errorDetails,
      },
    );
  }

  // SCHEDULE VALIDATION & OVERRIDES

  /// Log schedule validation checks and results
  Future<bool> logScheduleValidation({
    required String studentId,
    required String studentName,
    required bool canExit,
    String? validationResult,
    String? scheduleInfo,
    String? restrictionReason,
    TimeOfDay? classEndTime,
    String? currentClass,
    Map<String, dynamic>? scheduleDetails,
  }) async {
    return await _auditService.logEvent(
      actionType: 'System',
      actionCategory: 'Schedule Validation',
      description: canExit
          ? 'Schedule validation passed: $studentName can exit - $validationResult'
          : 'Schedule validation blocked: $studentName cannot exit - ${restrictionReason ?? 'Classes in session'}',
      targetType: 'schedule_validation',
      targetId: '${studentId}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$studentName - Schedule Check',
      module: 'Guard - Schedule System',
      status: canExit ? 'success' : 'info',
      metadata: {
        'student_id': studentId,
        'can_exit': canExit,
        'validation_result': validationResult,
        'schedule_info': scheduleInfo,
        'restriction_reason': restrictionReason,
        'class_end_time': classEndTime != null ? '${classEndTime.hour.toString().padLeft(2, '0')}:${classEndTime.minute.toString().padLeft(2, '0')}' : null,
        'current_class': currentClass,
        'validation_time': DateTime.now().toIso8601String(),
        'schedule_details': scheduleDetails,
      },
    );
  }

  // DASHBOARD & MONITORING

  /// Log guard dashboard access and key metrics
  Future<bool> logDashboardAccess({
    String? guardId,
    String? guardName,
    Map<String, dynamic>? dashboardMetrics,
  }) async {
    final currentUser = supabase.auth.currentUser;
    final actualGuardId = guardId ?? currentUser?.id;
    final actualGuardName = guardName ?? currentUser?.email ?? 'Unknown Guard';

    return await _auditService.logEvent(
      actionType: 'View',
      actionCategory: 'System Access',
      description: 'Guard dashboard accessed by $actualGuardName',
      targetType: 'dashboard',
      targetId: 'guard_dashboard',
      targetName: 'Guard Dashboard',
      module: 'Guard - Dashboard',
      status: 'success',
      metadata: {
        'guard_id': actualGuardId,
        'access_time': DateTime.now().toIso8601String(),
        'dashboard_metrics': dashboardMetrics,
      },
    );
  }

  /// Log shift changes and handovers
  Future<bool> logShiftChange({
    required String changeType, // 'shift_start', 'shift_end', 'handover'
    String? previousGuardId,
    String? previousGuardName,
    String? nextGuardId,
    String? nextGuardName,
    String? handoverNotes,
    Map<String, dynamic>? shiftDetails,
  }) async {
    return await _auditService.logEvent(
      actionType: 'System',
      actionCategory: 'Shift Management',
      description: 'Shift change: $changeType${previousGuardName != null ? ' (Previous: $previousGuardName)' : ''}${nextGuardName != null ? ' (Next: $nextGuardName)' : ''}',
      targetType: 'shift_change',
      targetId: '${changeType}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$changeType - Guard Shift',
      module: 'Guard - Shift Management',
      status: 'info',
      metadata: {
        'change_type': changeType,
        'previous_guard_id': previousGuardId,
        'previous_guard_name': previousGuardName,
        'next_guard_id': nextGuardId,
        'next_guard_name': nextGuardName,
        'handover_notes': handoverNotes,
        'shift_time': DateTime.now().toIso8601String(),
        'shift_details': shiftDetails,
      },
    );
  }
}