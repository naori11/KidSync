import 'package:supabase_flutter/supabase_flutter.dart';

/// Dedicated audit logging service for parent-side actions and activities
/// This service provides consistent tracking for all parent user actions across the parent portal
class ParentAuditService {
  final supabase = Supabase.instance.client;
  static final ParentAuditService _instance = ParentAuditService._internal();
  factory ParentAuditService() => _instance;
  ParentAuditService._internal();

  /// Main method to log parent audit events
  Future<bool> logParentEvent({
    required String actionType,
    required String actionCategory,
    required String description,
    String? targetType,
    String? targetId,
    String? targetName,
    String module = 'Parent Portal',
    String status = 'success',
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Get current user information
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        print('Warning: No authenticated user found for parent audit logging');
        return false;
      }

      // Get parent user details from the users table
      String userName = 'Unknown Parent';
      String userRole = 'Parent';
      
      try {
        final userResponse = await supabase
            .from('users')
            .select('fname, lname, role')
            .eq('id', currentUser.id)
            .maybeSingle();

        if (userResponse != null) {
          userName = '${userResponse['fname'] ?? ''} ${userResponse['lname'] ?? ''}'.trim();
          userRole = userResponse['role'] ?? 'Parent';
        } else {
          // Fallback to parent table if not found in users
          final parentResponse = await supabase
              .from('parents')
              .select('fname, lname')
              .eq('user_id', currentUser.id)
              .maybeSingle();
          
          if (parentResponse != null) {
            userName = '${parentResponse['fname'] ?? ''} ${parentResponse['lname'] ?? ''}'.trim();
          } else {
            userName = currentUser.email ?? 'Unknown Parent';
          }
        }
      } catch (userQueryError) {
        print('Error fetching user details for parent audit: $userQueryError');
        userName = currentUser.email ?? 'Unknown Parent';
      }

      // If we still don't have a proper username, make a safer fallback
      if (userName.trim().isEmpty || userName == 'Unknown Parent') {
        userName = currentUser.email ?? 'Parent User';
      }

      // Prepare the audit log data
      final auditData = {
        'user_id': currentUser.id,
        'user_name': userName,
        'user_role': userRole,
        'action_type': actionType,
        'action_category': actionCategory,
        'action_description': description,
        'target_type': targetType,
        'target_id': targetId,
        'target_name': targetName,
        'module': module,
        'status': status,
        'old_values': oldValues,
        'new_values': newValues,
        'metadata': metadata,
      };

      // Insert the audit log
      await supabase.from('audit_logs').insert(auditData);
      return true;
    } catch (e) {
      print('Error logging parent audit event: $e');
      print('Action: $actionType - $description');
      return false;
    }
  }

  // HIGH PRIORITY - Child Safety & Authorization

  /// Log authorized fetcher management actions
  Future<bool> logAuthorizedFetcherManagement({
    required String action, // 'add', 'edit', 'remove', 'activate', 'deactivate'
    required String childId,
    required String childName,
    required String fetcherName,
    String? fetcherId,
    String? relationship,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? reason,
  }) async {
    String description;
    switch (action.toLowerCase()) {
      case 'add':
        description = 'Added authorized fetcher $fetcherName for $childName${relationship != null ? ' ($relationship)' : ''}';
        break;
      case 'edit':
        description = 'Updated authorized fetcher $fetcherName for $childName${relationship != null ? ' ($relationship)' : ''}';
        break;
      case 'remove':
        description = 'Removed authorized fetcher $fetcherName from $childName${reason != null ? ' (Reason: $reason)' : ''}';
        break;
      case 'activate':
        description = 'Activated authorized fetcher $fetcherName for $childName';
        break;
      case 'deactivate':
        description = 'Deactivated authorized fetcher $fetcherName for $childName';
        break;
      default:
        description = 'Modified authorized fetcher $fetcherName for $childName';
    }

    return await logParentEvent(
      actionType: action == 'remove' ? 'Delete' : 'Update',
      actionCategory: 'Child Safety & Authorization',
      description: description,
      targetType: 'authorized_fetcher',
      targetId: fetcherId ?? '${childId}_$fetcherName',
      targetName: '$fetcherName - $childName',
      module: 'Fetcher Management',
      oldValues: oldValues,
      newValues: newValues,
      metadata: {
        'child_id': childId,
        'child_name': childName,
        'fetcher_name': fetcherName,
        'relationship': relationship,
        'action': action,
        'reason': reason,
      },
    );
  }

  /// Log temporary fetcher creation with PIN
  Future<bool> logTemporaryFetcherCreation({
    required String childId,
    required String childName,
    required String fetcherName,
    required String relationship,
    required String pinCode,
    required String validDate,
    String? contactNumber,
    String? idType,
    String? idNumber,
    String? emergencyContact,
    String? notes,
  }) async {
    return await logParentEvent(
      actionType: 'Create',
      actionCategory: 'Child Safety & Authorization',
      description: 'Created temporary fetcher access for $fetcherName to fetch $childName (PIN: ***${pinCode.substring(pinCode.length - 2)}) valid for $validDate',
      targetType: 'temporary_fetcher',
      targetId: '${childId}_${pinCode}',
      targetName: '$fetcherName - $childName (Temporary)',
      module: 'Temporary Fetcher',
      status: 'success',
      newValues: {
        'fetcher_name': fetcherName,
        'relationship': relationship,
        'contact_number': contactNumber,
        'id_type': idType,
        'id_number': idNumber,
        'valid_date': validDate,
        'emergency_contact': emergencyContact,
        'notes': notes,
      },
      metadata: {
        'child_id': childId,
        'child_name': childName,
        'pin_code_last_digits': pinCode.substring(pinCode.length - 2),
        'security_level': 'high',
        'authorization_type': 'temporary',
      },
    );
  }

  /// Log emergency pickup requests
  Future<bool> logEmergencyPickupRequest({
    required String childId,
    required String childName,
    required String emergencyReason,
    required String requestedFetcher,
    String? approvalStatus,
    String? emergencyContact,
    String? additionalNotes,
    DateTime? requestedTime,
  }) async {
    return await logParentEvent(
      actionType: 'Create',
      actionCategory: 'Child Safety & Authorization',
      description: 'Emergency pickup request for $childName - Reason: $emergencyReason, Requested fetcher: $requestedFetcher${approvalStatus != null ? ', Status: $approvalStatus' : ''}',
      targetType: 'emergency_pickup_request',
      targetId: '${childId}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$childName - Emergency Pickup',
      module: 'Emergency Services',
      status: approvalStatus == 'denied' ? 'warning' : 'success',
      newValues: {
        'emergency_reason': emergencyReason,
        'requested_fetcher': requestedFetcher,
        'approval_status': approvalStatus,
        'emergency_contact': emergencyContact,
        'additional_notes': additionalNotes,
        'requested_time': requestedTime?.toIso8601String(),
      },
      metadata: {
        'child_id': childId,
        'child_name': childName,
        'emergency_level': 'high',
        'requires_verification': true,
        'timestamp': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Log transportation schedule changes
  Future<bool> logTransportationScheduleChange({
    required String childId,
    required String childName,
    required String changeType, // 'weekly_pattern', 'exception', 'emergency_change'
    required String description,
    Map<String, dynamic>? oldSchedule,
    Map<String, dynamic>? newSchedule,
    String? effectiveDate,
    String? reason,
    bool isEmergency = false,
  }) async {
    String actionDescription;
    if (isEmergency) {
      actionDescription = 'Emergency transportation change for $childName: $description${reason != null ? ' (Reason: $reason)' : ''}';
    } else {
      actionDescription = 'Updated transportation schedule for $childName: $description${effectiveDate != null ? ' effective $effectiveDate' : ''}';
    }

    return await logParentEvent(
      actionType: 'Update',
      actionCategory: 'Child Safety & Authorization',
      description: actionDescription,
      targetType: 'transportation_schedule',
      targetId: '${childId}_${changeType}',
      targetName: '$childName - Transportation Schedule',
      module: 'Transportation Management',
      status: isEmergency ? 'warning' : 'success',
      oldValues: oldSchedule,
      newValues: newSchedule,
      metadata: {
        'child_id': childId,
        'child_name': childName,
        'change_type': changeType,
        'effective_date': effectiveDate,
        'reason': reason,
        'is_emergency': isEmergency,
        'requires_verification': isEmergency,
      },
    );
  }

  // MEDIUM PRIORITY - Verification & Communication

  /// Log pickup/dropoff verifications
  Future<bool> logPickupDropoffVerification({
    required String childId,
    required String childName,
    required String eventType, // 'pickup', 'dropoff'
    required String verificationStatus, // 'confirmed', 'denied', 'pending'
    required String driverName,
    DateTime? eventTime,
    DateTime? responseTime,
    String? parentNotes,
    String? logId,
  }) async {
    String description;
    if (verificationStatus == 'confirmed') {
      description = 'Confirmed $eventType of $childName by $driverName';
    } else if (verificationStatus == 'denied') {
      description = 'DENIED $eventType of $childName by $driverName${parentNotes != null ? ' (Notes: $parentNotes)' : ''}';
    } else {
      description = '$eventType verification pending for $childName with $driverName';
    }

    return await logParentEvent(
      actionType: verificationStatus == 'denied' ? 'Alert' : 'Update',
      actionCategory: 'Verification & Communication',
      description: description,
      targetType: 'pickup_dropoff_verification',
      targetId: logId ?? '${childId}_${eventType}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$childName - $eventType Verification',
      module: 'Transportation Verification',
      status: verificationStatus == 'denied' ? 'warning' : 'success',
      newValues: {
        'event_type': eventType,
        'verification_status': verificationStatus,
        'driver_name': driverName,
        'event_time': eventTime?.toIso8601String(),
        'response_time': responseTime?.toIso8601String(),
        'parent_notes': parentNotes,
      },
      metadata: {
        'child_id': childId,
        'child_name': childName,
        'response_delay_minutes': responseTime != null && eventTime != null 
            ? responseTime.difference(eventTime).inMinutes 
            : null,
      },
    );
  }

  /// Log notification acknowledgments
  Future<bool> logNotificationAcknowledgment({
    required String notificationId,
    required String notificationType,
    required String childId,
    required String childName,
    required String responseType, // 'acknowledged', 'dismissed', 'responded'
    DateTime? acknowledgmentTime,
    String? responseNotes,
    Map<String, dynamic>? notificationData,
  }) async {
    return await logParentEvent(
      actionType: 'Update',
      actionCategory: 'Verification & Communication',
      description: '${responseType.toUpperCase()} $notificationType notification for $childName${responseNotes != null ? ' (Response: $responseNotes)' : ''}',
      targetType: 'notification_acknowledgment',
      targetId: notificationId,
      targetName: '$childName - $notificationType Notification',
      module: 'Communication',
      newValues: {
        'notification_type': notificationType,
        'response_type': responseType,
        'acknowledgment_time': acknowledgmentTime?.toIso8601String(),
        'response_notes': responseNotes,
      },
      metadata: {
        'child_id': childId,
        'child_name': childName,
        'notification_data': notificationData,
      },
    );
  }

  /// Log parent dashboard access and key metrics
  Future<bool> logDashboardAccess({
    String? parentId,
    String? parentName,
    Map<String, dynamic>? dashboardMetrics,
    Map<String, dynamic>? accessMetadata,
  }) async {
    final currentUser = supabase.auth.currentUser;
    final actualParentId = parentId ?? currentUser?.id;
    final actualParentName = parentName ?? currentUser?.userMetadata?['fname'] ?? 'Unknown Parent';

    return await logParentEvent(
      actionType: 'View',
      actionCategory: 'System Access',
      description: 'Parent dashboard accessed by $actualParentName',
      targetType: 'dashboard',
      targetId: 'parent_dashboard',
      targetName: 'Parent Dashboard',
      module: 'Parent - Dashboard',
      status: 'success',
      metadata: {
        'parent_id': actualParentId,
        'parent_name': actualParentName,
        'access_time': DateTime.now().toIso8601String(),
        'dashboard_metrics': dashboardMetrics,
        'session_activity': 'dashboard_access',
        ...?accessMetadata,
      },
    );
  }

  /// Log parent authentication events (logout not logged)
  Future<bool> logParentAuthentication({
    required String authAction, // 'login', 'session_expired', 'password_change'
    DateTime? sessionStartTime,
    DateTime? sessionEndTime,
    String? deviceInfo,
    String? ipAddress,
    Duration? sessionDuration,
    bool isSuccessful = true,
    String? failureReason,
  }) async {
    // Skip logging logout activities
    if (authAction.toLowerCase() == 'logout') {
      return true;
    }

    String description;
    switch (authAction.toLowerCase()) {
      case 'login':
        description = isSuccessful 
            ? 'Parent portal login successful'
            : 'Parent portal login failed${failureReason != null ? ': $failureReason' : ''}';
        break;
      case 'session_expired':
        description = 'Parent portal session expired${sessionDuration != null ? ' after ${sessionDuration.inMinutes} minutes' : ''}';
        break;
      case 'password_change':
        description = isSuccessful 
            ? 'Password changed successfully'
            : 'Password change failed${failureReason != null ? ': $failureReason' : ''}';
        break;
      default:
        description = 'Parent authentication event: $authAction';
    }

    return await logParentEvent(
      actionType: authAction == 'login' ? 'Security' : 'Update',
      actionCategory: 'Authentication & Security',
      description: description,
      targetType: 'parent_authentication',
      targetId: '${DateTime.now().millisecondsSinceEpoch}',
      targetName: 'Parent Authentication',
      module: 'Security',
      status: isSuccessful ? 'success' : 'error',
      newValues: {
        'auth_action': authAction,
        'session_start_time': sessionStartTime?.toIso8601String(),
        'session_end_time': sessionEndTime?.toIso8601String(),
        'device_info': deviceInfo,
        'ip_address': ipAddress,
        'session_duration_minutes': sessionDuration?.inMinutes,
        'is_successful': isSuccessful,
        'failure_reason': failureReason,
      },
      metadata: {
        'security_level': 'standard',
        'requires_monitoring': !isSuccessful,
      },
    );
  }

  // ADDITIONAL SUPPORT METHODS

  /// Log general parent portal actions
  Future<bool> logParentPortalAction({
    required String action,
    required String description,
    String? childId,
    String? childName,
    String? targetType,
    String? targetId,
    String? targetName,
    Map<String, dynamic>? metadata,
    String status = 'success',
  }) async {
    return await logParentEvent(
      actionType: action,
      actionCategory: 'Parent Portal Activity',
      description: description,
      targetType: targetType,
      targetId: targetId,
      targetName: targetName,
      metadata: {
        ...metadata ?? {},
        'child_id': childId,
        'child_name': childName,
      },
      status: status,
    );
  }

  /// Log student selection/switching
  Future<bool> logStudentSelection({
    required String newStudentId,
    required String newStudentName,
    String? previousStudentId,
    String? previousStudentName,
  }) async {
    return await logParentEvent(
      actionType: 'View',
      actionCategory: 'Parent Portal Activity',
      description: previousStudentId != null 
          ? 'Switched from $previousStudentName to $newStudentName'
          : 'Selected student: $newStudentName',
      targetType: 'student_selection',
      targetId: newStudentId,
      targetName: newStudentName,
      module: 'Student Selection',
      oldValues: previousStudentId != null ? {
        'student_id': previousStudentId,
        'student_name': previousStudentName,
      } : null,
      newValues: {
        'student_id': newStudentId,
        'student_name': newStudentName,
      },
      metadata: {
        'action_type': 'student_switch',
      },
    );
  }

  /// Log errors or security incidents
  Future<bool> logSecurityIncident({
    required String incidentType,
    required String description,
    String? childId,
    String? childName,
    String? threatLevel, // 'low', 'medium', 'high', 'critical'
    Map<String, dynamic>? incidentDetails,
  }) async {
    return await logParentEvent(
      actionType: 'Alert',
      actionCategory: 'Security Incident',
      description: description,
      targetType: 'security_incident',
      targetId: '${DateTime.now().millisecondsSinceEpoch}',
      targetName: incidentType,
      module: 'Security',
      status: 'warning',
      metadata: {
        'incident_type': incidentType,
        'threat_level': threatLevel ?? 'medium',
        'child_id': childId,
        'child_name': childName,
        'incident_details': incidentDetails,
        'requires_review': true,
      },
    );
  }

  /// Log file exports from parent portal
  Future<bool> logParentExport({
    required String exportType,
    required String fileName,
    String? childId,
    String? childName,
    String? dateRange,
    int? recordCount,
    String? filters,
  }) async {
    return await logParentEvent(
      actionType: 'Export',
      actionCategory: 'Data Access',
      description: 'Exported $exportType data${childName != null ? ' for $childName' : ''} to $fileName${recordCount != null ? ' ($recordCount records)' : ''}',
      targetType: 'parent_export',
      targetId: '${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$exportType Export',
      module: 'Data Export',
      metadata: {
        'export_type': exportType,
        'file_name': fileName,
        'child_id': childId,
        'child_name': childName,
        'date_range': dateRange,
        'record_count': recordCount,
        'filters': filters,
      },
    );
  }
}

/// Extension to capitalize first letter of a string
extension StringCapitalization on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}