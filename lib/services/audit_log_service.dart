import 'package:supabase_flutter/supabase_flutter.dart';

/// Centralized service for logging all administrative actions and system activities
/// This service provides a consistent way to track user actions across the entire application
class AuditLogService {
  final supabase = Supabase.instance.client;
  static final AuditLogService _instance = AuditLogService._internal();
  factory AuditLogService() => _instance;
  AuditLogService._internal();

  /// Main method to log audit events
  Future<bool> logEvent({
    required String actionType,
    required String actionCategory,
    required String description,
    String? targetType,
    String? targetId,
    String? targetName,
    String module = 'Admin Panel',
    String status = 'success',
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    Map<String, dynamic>? metadata,
  }) async {
    try {
      // Get current user information
      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        print('Warning: No authenticated user found for audit logging');
        return false;
      }

      // Get user details from the users table with fallback
      String userName = 'Unknown User';
      String userRole = 'Unknown';

      try {
        final userResponse =
            await supabase
                .from('users')
                .select('fname, lname, role')
                .eq('id', currentUser.id)
                .maybeSingle(); // Use maybeSingle() to handle no results gracefully

        if (userResponse != null) {
          userName =
              '${userResponse['fname'] ?? ''} ${userResponse['lname'] ?? ''}'
                  .trim();
          userRole = userResponse['role'] ?? 'Unknown';
          print(
            'Successfully fetched user details for audit: $userName ($userRole)',
          );
        } else {
          print(
            'Warning: User details not found in users table for ID: ${currentUser.id}',
          );
          // Fallback to auth user metadata or email
          userName = currentUser.email ?? 'Unknown User';
          userRole = currentUser.userMetadata?['role'] ?? 'Unknown';
          print('Using fallback user details: $userName ($userRole)');
        }
      } catch (userQueryError) {
        print('Error fetching user details for audit: $userQueryError');
        // Fallback to auth user metadata or email
        userName = currentUser.email ?? 'Unknown User';
        userRole = currentUser.userMetadata?['role'] ?? 'Unknown';
        print('Using fallback user details after error: $userName ($userRole)');
      }

      // If we still don't have a proper username, make a safer fallback
      if (userName.trim().isEmpty || userName == 'Unknown User') {
        userName = currentUser.email ?? 'System User';
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
        'old_values': oldValues, // Pass raw object for JSONB column
        'new_values': newValues, // Pass raw object for JSONB column
        'metadata': metadata, // Pass raw object for JSONB column
      };

      // Insert the audit log
      print(
        'Attempting to insert audit log: ${auditData['action_description']}',
      ); // Debug log
      await supabase.from('audit_logs').insert(auditData);
      print('Audit log inserted successfully'); // Debug log

      return true;
    } catch (e) {
      print('Error logging audit event: $e');
      print('Action: ${actionType} - ${description}'); // Enhanced error logging
      print(
        'Stack trace: ${StackTrace.current}',
      ); // Add stack trace for debugging
      return false;
    }
  }

  // SECURITY & AUTHENTICATION METHODS

  /// Log password change events
  Future<bool> logPasswordChange({
    String? targetUserId,
    String? targetUserName,
    bool isReset = false,
  }) async {
    return await logEvent(
      actionType: 'Security',
      actionCategory: 'Security & Authentication',
      description:
          isReset
              ? 'Password reset ${targetUserName != null ? 'for $targetUserName' : ''}'
              : 'Password changed ${targetUserName != null ? 'for $targetUserName' : ''}',
      targetType: 'user',
      targetId: targetUserId,
      targetName: targetUserName,
      module: 'Authentication',
    );
  }

  /// Log role assignment/changes
  Future<bool> logRoleChange({
    required String targetUserId,
    required String targetUserName,
    required String oldRole,
    required String newRole,
  }) async {
    return await logEvent(
      actionType: 'Update',
      actionCategory: 'Security & Authentication',
      description: 'Role changed from $oldRole to $newRole for $targetUserName',
      targetType: 'user',
      targetId: targetUserId,
      targetName: targetUserName,
      oldValues: {'role': oldRole},
      newValues: {'role': newRole},
    );
  }

  /// Log account creation
  Future<bool> logAccountCreation({
    required String targetUserId,
    required String targetUserName,
    required String role,
    Map<String, dynamic>? userData,
  }) async {
    return await logEvent(
      actionType: 'Create',
      actionCategory: 'Security & Authentication',
      description: 'Created new $role account for $targetUserName',
      targetType: 'user',
      targetId: targetUserId,
      targetName: targetUserName,
      newValues: userData,
    );
  }

  /// Log account deletion
  Future<bool> logAccountDeletion({
    required String targetUserId,
    required String targetUserName,
    required String role,
  }) async {
    return await logEvent(
      actionType: 'Delete',
      actionCategory: 'Security & Authentication',
      description: 'Deleted $role account for $targetUserName',
      targetType: 'user',
      targetId: targetUserId,
      targetName: targetUserName,
    );
  }

  /// Log account status changes
  Future<bool> logAccountStatusChange({
    required String targetUserId,
    required String targetUserName,
    required String oldStatus,
    required String newStatus,
  }) async {
    return await logEvent(
      actionType: 'Update',
      actionCategory: 'Security & Authentication',
      description:
          'Account status changed from $oldStatus to $newStatus for $targetUserName',
      targetType: 'user',
      targetId: targetUserId,
      targetName: targetUserName,
      oldValues: {'status': oldStatus},
      newValues: {'status': newStatus},
    );
  }

  // STUDENT MANAGEMENT METHODS

  /// Log student profile creation
  Future<bool> logStudentCreation({
    required String studentId,
    required String studentName,
    Map<String, dynamic>? studentData,
  }) async {
    return await logEvent(
      actionType: 'Create',
      actionCategory: 'Student Management',
      description: 'Created new student profile for $studentName',
      targetType: 'student',
      targetId: studentId,
      targetName: studentName,
      newValues: studentData,
    );
  }

  /// Log student profile modification
  Future<bool> logStudentUpdate({
    required String studentId,
    required String studentName,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
    String? specificField,
  }) async {
    String description = 'Updated student profile for $studentName';
    if (specificField != null) {
      description = 'Updated $specificField for student $studentName';
    }

    return await logEvent(
      actionType: 'Update',
      actionCategory: 'Student Management',
      description: description,
      targetType: 'student',
      targetId: studentId,
      targetName: studentName,
      oldValues: oldValues,
      newValues: newValues,
    );
  }

  /// Log student deletion
  Future<bool> logStudentDeletion({
    required String studentId,
    required String studentName,
  }) async {
    return await logEvent(
      actionType: 'Delete',
      actionCategory: 'Student Management',
      description: 'Deleted student profile for $studentName',
      targetType: 'student',
      targetId: studentId,
      targetName: studentName,
    );
  }

  /// Log RFID tag assignment/changes
  Future<bool> logRFIDAssignment({
    required String studentId,
    required String studentName,
    String? oldRFID,
    required String newRFID,
  }) async {
    return await logEvent(
      actionType: 'Update',
      actionCategory: 'Student Management',
      description:
          oldRFID != null
              ? 'Changed RFID tag for $studentName from $oldRFID to $newRFID'
              : 'Assigned RFID tag $newRFID to $studentName',
      targetType: 'student',
      targetId: studentId,
      targetName: studentName,
      oldValues: oldRFID != null ? {'rfid_uid': oldRFID} : null,
      newValues: {'rfid_uid': newRFID},
    );
  }

  /// Log student-parent relationship changes
  Future<bool> logStudentParentRelationship({
    required String studentId,
    required String studentName,
    required String parentId,
    required String parentName,
    required String action, // 'added', 'removed', 'updated'
    String? relationshipType,
  }) async {
    return await logEvent(
      actionType: action == 'removed' ? 'Delete' : 'Update',
      actionCategory: 'Student Management',
      description:
          '${action.capitalizeFirst()} parent relationship: $parentName ${action == 'removed' ? 'removed from' : 'linked to'} $studentName',
      targetType: 'student_parent_relationship',
      targetId: '${studentId}_$parentId',
      targetName: '$studentName - $parentName',
      metadata: {
        'student_id': studentId,
        'parent_id': parentId,
        'relationship_type': relationshipType,
        'action': action,
      },
    );
  }

  /// Log bulk student imports
  Future<bool> logBulkStudentImport({
    required int totalRecords,
    required int successCount,
    required int errorCount,
    String? fileName,
    List<String>? errors,
  }) async {
    return await logEvent(
      actionType: 'Import',
      actionCategory: 'Student Management',
      description:
          'Bulk imported students: $successCount successful, $errorCount failed out of $totalRecords total',
      module: 'Bulk Import',
      status: errorCount > 0 ? 'warning' : 'success',
      metadata: {
        'file_name': fileName,
        'total_records': totalRecords,
        'success_count': successCount,
        'error_count': errorCount,
        'errors': errors,
      },
    );
  }

  // USER MANAGEMENT METHODS

  /// Log user account creation/modification/deletion
  Future<bool> logUserManagement({
    required String action, // 'create', 'update', 'delete'
    required String targetUserId,
    required String targetUserName,
    String? role,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) async {
    String actionType;
    String description;

    switch (action.toLowerCase()) {
      case 'create':
        actionType = 'Create';
        description =
            'Created new user account for $targetUserName${role != null ? ' with role $role' : ''}';
        break;
      case 'update':
        actionType = 'Update';
        description = 'Updated user account for $targetUserName';
        break;
      case 'delete':
        actionType = 'Delete';
        description = 'Deleted user account for $targetUserName';
        break;
      default:
        actionType = 'Update';
        description = 'Modified user account for $targetUserName';
    }

    return await logEvent(
      actionType: actionType,
      actionCategory: 'User Management',
      description: description,
      targetType: 'user',
      targetId: targetUserId,
      targetName: targetUserName,
      oldValues: oldValues,
      newValues: newValues,
    );
  }

  /// Log bulk user operations
  Future<bool> logBulkUserOperation({
    required String operation,
    required int affectedCount,
    String? criteria,
  }) async {
    return await logEvent(
      actionType: 'Update',
      actionCategory: 'User Management',
      description:
          'Bulk $operation performed on $affectedCount users${criteria != null ? ' ($criteria)' : ''}',
      module: 'Bulk Operations',
      metadata: {
        'operation': operation,
        'affected_count': affectedCount,
        'criteria': criteria,
      },
    );
  }

  // SECTION MANAGEMENT METHODS

  /// Log section creation/modification/deletion
  Future<bool> logSectionManagement({
    required String action,
    required String sectionId,
    required String sectionName,
    String? gradeLevel,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) async {
    String actionType;
    String description;

    switch (action.toLowerCase()) {
      case 'create':
        actionType = 'Create';
        description =
            'Created new section $sectionName${gradeLevel != null ? ' for grade $gradeLevel' : ''}';
        break;
      case 'update':
        actionType = 'Update';
        description = 'Updated section $sectionName';
        break;
      case 'delete':
        actionType = 'Delete';
        description = 'Deleted section $sectionName';
        break;
      default:
        actionType = 'Update';
        description = 'Modified section $sectionName';
    }

    return await logEvent(
      actionType: actionType,
      actionCategory: 'Section Management',
      description: description,
      targetType: 'section',
      targetId: sectionId,
      targetName: sectionName,
      oldValues: oldValues,
      newValues: newValues,
    );
  }

  /// Log teacher-section assignments
  Future<bool> logTeacherSectionAssignment({
    required String action, // 'assign', 'unassign', 'update'
    required String teacherId,
    required String teacherName,
    required String sectionId,
    required String sectionName,
    String? subject,
  }) async {
    return await logEvent(
      actionType: action == 'unassign' ? 'Delete' : 'Update',
      actionCategory: 'Section Management',
      description:
          '${action.capitalizeFirst()}ed teacher $teacherName ${action == 'unassign' ? 'from' : 'to'} section $sectionName${subject != null ? ' for $subject' : ''}',
      targetType: 'teacher_section_assignment',
      targetId: '${teacherId}_$sectionId',
      targetName: '$teacherName - $sectionName',
      metadata: {
        'teacher_id': teacherId,
        'section_id': sectionId,
        'subject': subject,
        'action': action,
      },
    );
  }

  // PARENT/GUARDIAN MANAGEMENT METHODS

  /// Log parent profile creation/modification
  Future<bool> logParentManagement({
    required String action,
    required String parentId,
    required String parentName,
    Map<String, dynamic>? oldValues,
    Map<String, dynamic>? newValues,
  }) async {
    String actionType;
    String description;

    switch (action.toLowerCase()) {
      case 'create':
        actionType = 'Create';
        description = 'Created new parent profile for $parentName';
        break;
      case 'update':
        actionType = 'Update';
        description = 'Updated parent profile for $parentName';
        break;
      case 'delete':
        actionType = 'Delete';
        description = 'Deleted parent profile for $parentName';
        break;
      default:
        actionType = 'Update';
        description = 'Modified parent profile for $parentName';
    }

    return await logEvent(
      actionType: actionType,
      actionCategory: 'Parent/Guardian Management',
      description: description,
      targetType: 'parent',
      targetId: parentId,
      targetName: parentName,
      oldValues: oldValues,
      newValues: newValues,
    );
  }

  /// Log emergency contact updates
  Future<bool> logEmergencyContactUpdate({
    required String parentId,
    required String parentName,
    Map<String, dynamic>? oldContacts,
    Map<String, dynamic>? newContacts,
  }) async {
    return await logEvent(
      actionType: 'Update',
      actionCategory: 'Parent/Guardian Management',
      description: 'Updated emergency contact information for $parentName',
      targetType: 'parent',
      targetId: parentId,
      targetName: parentName,
      oldValues: oldContacts,
      newValues: newContacts,
    );
  }

  // DRIVER ASSIGNMENT METHODS

  /// Log student-driver assignments
  Future<bool> logDriverAssignment({
    required String action, // 'assign', 'unassign', 'update'
    required String studentId,
    required String studentName,
    required String driverId,
    required String driverName,
    Map<String, dynamic>? scheduleDetails,
  }) async {
    String actionVerb;
    switch (action.toLowerCase()) {
      case 'assign':
        actionVerb = 'Assigned';
        break;
      case 'unassign':
        actionVerb = 'Unassigned';
        break;
      case 'update':
        actionVerb = 'Updated';
        break;
      default:
        actionVerb = action.capitalizeFirst();
    }

    return await logEvent(
      actionType: action == 'unassign' ? 'Delete' : 'Update',
      actionCategory: 'Driver Assignment',
      description:
          '$actionVerb driver $driverName ${action == 'unassign' ? 'from' : 'to'} student $studentName',
      targetType: 'driver_assignment',
      targetId: '${studentId}_$driverId',
      targetName: '$studentName - $driverName',
      metadata: {
        'student_id': studentId,
        'driver_id': driverId,
        'action': action,
        'schedule_details': scheduleDetails,
      },
    );
  }

  /// Log transportation schedule changes
  Future<bool> logTransportationScheduleChange({
    required String assignmentId,
    required String studentName,
    required String driverName,
    Map<String, dynamic>? oldSchedule,
    Map<String, dynamic>? newSchedule,
  }) async {
    return await logEvent(
      actionType: 'Update',
      actionCategory: 'Driver Assignment',
      description:
          'Updated transportation schedule for $studentName with driver $driverName',
      targetType: 'driver_assignment',
      targetId: assignmentId,
      targetName: '$studentName - $driverName',
      oldValues: oldSchedule,
      newValues: newSchedule,
    );
  }

  // SYSTEM CONFIGURATION METHODS

  /// Log system settings modifications
  Future<bool> logSystemSettingsChange({
    required String settingName,
    required String oldValue,
    required String newValue,
    String? category,
  }) async {
    return await logEvent(
      actionType: 'Update',
      actionCategory: 'System Configuration',
      description:
          'Changed system setting $settingName from "$oldValue" to "$newValue"',
      targetType: 'system_setting',
      targetId: settingName,
      targetName: settingName,
      module: 'System Settings',
      oldValues: {'value': oldValue},
      newValues: {'value': newValue},
      metadata: {'category': category},
    );
  }

  /// Log export operations
  Future<bool> logExportOperation({
    required String exportType,
    required String fileName,
    required int recordCount,
    String? filters,
  }) async {
    return await logEvent(
      actionType: 'Export',
      actionCategory: 'Data Access & Privacy',
      description:
          'Exported $exportType data to $fileName ($recordCount records)',
      module: 'Data Export',
      metadata: {
        'export_type': exportType,
        'file_name': fileName,
        'record_count': recordCount,
        'filters': filters,
      },
    );
  }

  /// Log bulk import operations
  Future<bool> logBulkImportOperation({
    required String importType,
    required String fileName,
    required int totalRecords,
    required int successCount,
    required int errorCount,
    List<String>? errors,
  }) async {
    return await logEvent(
      actionType: 'Import',
      actionCategory: 'Data Access & Privacy',
      description:
          'Bulk imported $importType: $successCount successful, $errorCount failed out of $totalRecords total',
      module: 'Bulk Import',
      status: errorCount > 0 ? 'warning' : 'success',
      metadata: {
        'import_type': importType,
        'file_name': fileName,
        'total_records': totalRecords,
        'success_count': successCount,
        'error_count': errorCount,
        'errors': errors,
      },
    );
  }

  /// Log profile image uploads/changes
  Future<bool> logProfileImageChange({
    required String targetType, // 'user', 'student'
    required String targetId,
    required String targetName,
    String? oldImageUrl,
    String? newImageUrl,
  }) async {
    return await logEvent(
      actionType: 'Update',
      actionCategory: 'Data Access & Privacy',
      description:
          oldImageUrl != null
              ? 'Updated profile image for $targetName'
              : 'Added profile image for $targetName',
      targetType: targetType,
      targetId: targetId,
      targetName: targetName,
      oldValues:
          oldImageUrl != null ? {'profile_image_url': oldImageUrl} : null,
      newValues: {'profile_image_url': newImageUrl},
    );
  }

  // HELPER METHODS

  /// Log general admin panel actions
  Future<bool> logAdminAction({
    required String action,
    required String description,
    String? targetType,
    String? targetId,
    String? targetName,
    Map<String, dynamic>? metadata,
  }) async {
    return await logEvent(
      actionType: action,
      actionCategory: 'Admin Panel',
      description: description,
      targetType: targetType,
      targetId: targetId,
      targetName: targetName,
      metadata: metadata,
    );
  }

  /// Log errors or warnings
  Future<bool> logError({
    required String errorDescription,
    required String action,
    String? targetType,
    String? targetId,
    Map<String, dynamic>? errorDetails,
  }) async {
    return await logEvent(
      actionType: action,
      actionCategory: 'System Error',
      description: errorDescription,
      targetType: targetType,
      targetId: targetId,
      status: 'error',
      metadata: errorDetails,
      module: 'System',
    );
  }

  // TEACHER ATTENDANCE MANAGEMENT METHODS

  /// Log manual attendance marking
  Future<bool> logAttendanceMarking({
    required String studentId,
    required String studentName,
    required String sectionId,
    required String sectionName,
    required String status,
    required String date,
    String? previousStatus,
    String? notes,
    bool isRfidAssisted = false,
  }) async {
    String description;
    if (previousStatus != null && previousStatus != status) {
      description =
          'Updated attendance for $studentName in $sectionName from $previousStatus to $status for $date';
    } else {
      description = 'Marked $studentName as $status in $sectionName for $date';
    }

    if (isRfidAssisted) {
      description += ' (RFID-assisted)';
    }

    return await logEvent(
      actionType: previousStatus != null ? 'Update' : 'Create',
      actionCategory: 'Attendance Management',
      description: description,
      targetType: 'section_attendance',
      targetId: '${sectionId}_${studentId}_$date',
      targetName: '$studentName - $sectionName ($date)',
      module: 'Teacher Panel',
      oldValues: previousStatus != null ? {'status': previousStatus} : null,
      newValues: {'status': status, 'notes': notes},
      metadata: {
        'student_id': studentId,
        'section_id': sectionId,
        'date': date,
        'is_rfid_assisted': isRfidAssisted,
      },
    );
  }

  /// Log bulk attendance operations
  Future<bool> logBulkAttendanceOperation({
    required String operation, // 'mark_all_present', 'mark_all_absent', etc.
    required int studentCount,
    required String sectionId,
    required String sectionName,
    required String date,
    required String status,
    List<String>? affectedStudents,
  }) async {
    return await logEvent(
      actionType: 'Update',
      actionCategory: 'Attendance Management',
      description:
          'Bulk $operation: marked $studentCount students as $status in $sectionName for $date',
      targetType: 'section_attendance_bulk',
      targetId: '${sectionId}_$date',
      targetName: '$sectionName - Bulk Operation ($date)',
      module: 'Teacher Panel',
      newValues: {'status': status, 'operation': operation},
      metadata: {
        'section_id': sectionId,
        'date': date,
        'student_count': studentCount,
        'affected_students': affectedStudents,
        'operation_type': operation,
      },
    );
  }

  /// Log early dismissal authorization
  Future<bool> logEarlyDismissal({
    required String dismissalId,
    required String studentId,
    required String studentName,
    required String sectionId,
    required String sectionName,
    required String reason,
    required String pickupPerson,
    required String dismissalTime,
    String? notes,
  }) async {
    return await logEvent(
      actionType: 'Create',
      actionCategory: 'Attendance Management',
      description:
          'Authorized early dismissal for $studentName from $sectionName. Reason: $reason, Pickup: $pickupPerson',
      targetType: 'early_dismissal',
      targetId: dismissalId,
      targetName: '$studentName - Early Dismissal',
      module: 'Teacher Panel',
      newValues: {
        'student_id': studentId,
        'reason': reason,
        'pickup_person': pickupPerson,
        'dismissal_time': dismissalTime,
        'notes': notes,
      },
      metadata: {
        'student_id': studentId,
        'section_id': sectionId,
        'dismissal_time': dismissalTime,
      },
    );
  }

  /// Log emergency exit processing
  Future<bool> logEmergencyExit({
    required String studentId,
    required String studentName,
    required String sectionId,
    required String sectionName,
    required String exitTime,
    String? reason,
    String? emergencyContact,
  }) async {
    return await logEvent(
      actionType: 'Create',
      actionCategory: 'Attendance Management',
      description:
          'Processed emergency exit for $studentName from $sectionName at $exitTime',
      targetType: 'emergency_exit',
      targetId: '${studentId}_$exitTime',
      targetName: '$studentName - Emergency Exit',
      module: 'Teacher Panel',
      status: 'warning', // Emergency situations should be flagged
      newValues: {
        'student_id': studentId,
        'exit_time': exitTime,
        'reason': reason,
        'emergency_contact': emergencyContact,
      },
      metadata: {
        'student_id': studentId,
        'section_id': sectionId,
        'exit_time': exitTime,
        'is_emergency': true,
      },
    );
  }

  /// Log RFID attendance override
  Future<bool> logRfidAttendanceOverride({
    required String studentId,
    required String studentName,
    required String sectionId,
    required String sectionName,
    required String date,
    required String originalStatus,
    required String newStatus,
    String? overrideReason,
  }) async {
    return await logEvent(
      actionType: 'Update',
      actionCategory: 'Attendance Management',
      description:
          'Overrode RFID attendance for $studentName in $sectionName: $originalStatus → $newStatus${overrideReason != null ? ' (Reason: $overrideReason)' : ''}',
      targetType: 'rfid_attendance_override',
      targetId: '${sectionId}_${studentId}_$date',
      targetName: '$studentName - RFID Override',
      module: 'Teacher Panel',
      oldValues: {'status': originalStatus, 'source': 'rfid'},
      newValues: {'status': newStatus, 'source': 'manual_override'},
      metadata: {
        'student_id': studentId,
        'section_id': sectionId,
        'date': date,
        'override_reason': overrideReason,
        'is_rfid_override': true,
      },
    );
  }

  // TEACHER STUDENT ISSUE MANAGEMENT METHODS

  /// Log attendance issue flagging
  Future<bool> logAttendanceIssueFlag({
    required String studentId,
    required String studentName,
    required String sectionId,
    required String sectionName,
    required String issueType, // 'chronic_absence', 'frequent_tardiness', etc.
    required String severity, // 'low', 'medium', 'high', 'urgent'
    String? description,
    Map<String, dynamic>? issueDetails,
  }) async {
    return await logEvent(
      actionType: 'Create',
      actionCategory: 'Student Issue Management',
      description:
          'Flagged $issueType issue for $studentName in $sectionName (Severity: $severity)',
      targetType: 'attendance_issue',
      targetId: '${studentId}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$studentName - $issueType',
      module: 'Teacher Panel',
      status: severity == 'urgent' ? 'warning' : 'info',
      newValues: {
        'issue_type': issueType,
        'severity': severity,
        'description': description,
      },
      metadata: {
        'student_id': studentId,
        'section_id': sectionId,
        'issue_details': issueDetails,
      },
    );
  }

  /// Log parent notification triggers
  Future<bool> logParentNotificationTrigger({
    required String studentId,
    required String studentName,
    required String
    notificationType, // 'attendance_alert', 'absence_warning', etc.
    required String parentName,
    String? parentContact,
    String? notificationContent,
    Map<String, dynamic>? attendanceData,
  }) async {
    return await logEvent(
      actionType: 'Create',
      actionCategory: 'Student Issue Management',
      description:
          'Triggered $notificationType notification to $parentName for $studentName',
      targetType: 'parent_notification',
      targetId: '${studentId}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$studentName - Parent Notification',
      module: 'Teacher Panel',
      newValues: {
        'notification_type': notificationType,
        'parent_name': parentName,
        'parent_contact': parentContact,
        'content': notificationContent,
      },
      metadata: {'student_id': studentId, 'attendance_data': attendanceData},
    );
  }

  /// Log issue resolution
  Future<bool> logIssueResolution({
    required String issueId,
    required String studentId,
    required String studentName,
    required String issueType,
    required String resolution,
    String? resolutionNotes,
    Map<String, dynamic>? followUpActions,
  }) async {
    return await logEvent(
      actionType: 'Update',
      actionCategory: 'Student Issue Management',
      description:
          'Resolved $issueType issue for $studentName. Resolution: $resolution',
      targetType: 'issue_resolution',
      targetId: issueId,
      targetName: '$studentName - Issue Resolved',
      module: 'Teacher Panel',
      newValues: {
        'resolution': resolution,
        'resolution_notes': resolutionNotes,
        'status': 'resolved',
      },
      metadata: {
        'student_id': studentId,
        'issue_type': issueType,
        'follow_up_actions': followUpActions,
      },
    );
  }

  // TEACHER REPORTING & EXPORT METHODS

  /// Log attendance report export
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
  }) async {
    return await logEvent(
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
        'export_type': exportType,
        'file_name': fileName,
        'record_count': recordCount,
        'date_range': dateRange,
        'filters': filters,
        'included_students': includedStudents,
      },
    );
  }

  /// Log monthly summary generation
  Future<bool> logMonthlySummaryGeneration({
    required String sectionId,
    required String sectionName,
    required String month,
    required int totalStudents,
    required Map<String, int> attendanceStats,
    List<String>? studentsWithIssues,
  }) async {
    return await logEvent(
      actionType: 'View',
      actionCategory: 'Data Export & Reporting',
      description:
          'Generated monthly attendance summary for $sectionName ($month) - $totalStudents students',
      targetType: 'monthly_summary',
      targetId: '${sectionId}_$month',
      targetName: '$sectionName - Monthly Summary ($month)',
      module: 'Teacher Panel',
      metadata: {
        'section_id': sectionId,
        'month': month,
        'total_students': totalStudents,
        'attendance_stats': attendanceStats,
        'students_with_issues': studentsWithIssues,
      },
    );
  }

  /// Log student calendar access
  Future<bool> logStudentCalendarAccess({
    required String studentId,
    required String studentName,
    required String sectionId,
    required String sectionName,
    required String viewedMonth,
    Map<String, dynamic>? attendanceData,
  }) async {
    return await logEvent(
      actionType: 'View',
      actionCategory: 'Data Export & Reporting',
      description:
          'Accessed attendance calendar for $studentName in $sectionName ($viewedMonth)',
      targetType: 'student_calendar_access',
      targetId: '${studentId}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$studentName - Calendar Access',
      module: 'Teacher Panel',
      metadata: {
        'student_id': studentId,
        'section_id': sectionId,
        'viewed_month': viewedMonth,
        'attendance_data': attendanceData,
      },
    );
  }

  /// Log schedule modification by teacher
  Future<bool> logScheduleModification({
    required String sectionId,
    required String sectionName,
    required String
    modificationType, // 'class_time', 'class_days', 'schedule_override'
    Map<String, dynamic>? oldSchedule,
    Map<String, dynamic>? newSchedule,
    String? reason,
  }) async {
    return await logEvent(
      actionType: 'Update',
      actionCategory: 'Section Management',
      description:
          'Modified $modificationType for $sectionName${reason != null ? ' (Reason: $reason)' : ''}',
      targetType: 'schedule_modification',
      targetId: '${sectionId}_${DateTime.now().millisecondsSinceEpoch}',
      targetName: '$sectionName - Schedule Change',
      module: 'Teacher Panel',
      oldValues: oldSchedule,
      newValues: newSchedule,
      metadata: {
        'section_id': sectionId,
        'modification_type': modificationType,
        'reason': reason,
      },
    );
  }

  /// Fetch audit logs with filtering
  Future<List<Map<String, dynamic>>> getAuditLogs({
    int limit = 50,
    int offset = 0,
    String? userId,
    String? actionType,
    String? actionCategory,
    String? status,
    DateTime? startDate,
    DateTime? endDate,
    String? searchQuery,
  }) async {
    try {
      var query = supabase.from('audit_logs').select('*');

      // Apply filters
      if (userId != null) {
        query = query.eq('user_id', userId);
      }
      if (actionType != null && actionType != 'All Actions') {
        query = query.eq('action_type', actionType);
      }
      if (actionCategory != null && actionCategory != 'All Categories') {
        query = query.eq('action_category', actionCategory);
      }
      if (status != null && status != 'All Status') {
        query = query.eq('status', status);
      }
      if (startDate != null) {
        query = query.gte('created_at', startDate.toIso8601String());
      }
      if (endDate != null) {
        query = query.lte('created_at', endDate.toIso8601String());
      }
      if (searchQuery != null && searchQuery.isNotEmpty) {
        query = query.or(
          'action_description.ilike.%$searchQuery%,user_name.ilike.%$searchQuery%,target_name.ilike.%$searchQuery%',
        );
      }

      final response = await query
          .order('created_at', ascending: false)
          .range(offset, offset + limit - 1);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error fetching audit logs: $e');
      return [];
    }
  }
}

/// Extension to capitalize first letter of a string
extension StringCapitalization on String {
  String capitalizeFirst() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
