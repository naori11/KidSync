import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/driver_models.dart';
import '../../services/driver_service.dart';
import '../../services/verification_service.dart';
import '../../services/driver_audit_service.dart';
import '../../utils/time_utils.dart';

class DriverPickupTab extends StatefulWidget {
  final Color primaryColor;
  final bool isMobile;

  const DriverPickupTab({
    required this.primaryColor,
    required this.isMobile,
    Key? key,
  }) : super(key: key);

  @override
  State<DriverPickupTab> createState() => _DriverPickupTabState();
}

class _DriverPickupTabState extends State<DriverPickupTab> {
  List<Map<String, dynamic>> morningPickupStudents = [];
  List<Map<String, dynamic>> afternoonDropoffStudents = [];
  List<Student> pickedUpStudents = [];
  List<Student> droppedOffStudents = [];
  final DriverService _driverService = DriverService();
  final VerificationService _verificationService = VerificationService();
  final DriverAuditService _driverAuditService = DriverAuditService();
  bool _isLoading = true;
  bool _isProcessing = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  Future<void> _initializeData() async {
    try {
      setState(() {
        _isLoading = true;
        _error = null;
      });

      // Get current user (driver)
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) {
        setState(() {
          _error = 'User not authenticated';
          _isLoading = false;
        });
        return;
      }

      // Get today's students with pickup/dropoff patterns
      final studentsData = await _driverService.getTodaysStudentsWithPatterns(
        user.id,
      );

      // Get all students (both driver and parent responsible)
      final allStudents = studentsData['all_students'];

      // Separate into morning pickup and afternoon dropoff based on patterns
      morningPickupStudents = [];
      afternoonDropoffStudents = [];

      // Only include students where the driver is responsible for that task.
      for (final studentData in allStudents) {
        final dropoffPerson =
            studentData['dropoff_person']?.toString().toLowerCase();
        final pickupPerson =
            studentData['pickup_person']?.toString().toLowerCase();

        // Morning pickup: include only if dropoff_person is 'driver'
        if (dropoffPerson == 'driver') {
          morningPickupStudents.add({
            ...studentData,
            'task_type': 'morning_pickup',
            'is_driver_responsible': true,
          });
        }

        // Afternoon dropoff: include only if pickup_person is 'driver'
        if (pickupPerson == 'driver') {
          afternoonDropoffStudents.add({
            ...studentData,
            'task_type': 'afternoon_dropoff',
            'is_driver_responsible': true,
          });
        }
      }

      // Load pickup/dropoff status for today
      await _loadTodaysStatus();

      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = 'Error loading data: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadTodaysStatus() async {
    try {
      final user = Supabase.instance.client.auth.currentUser!;

      // Clear current lists
      pickedUpStudents.clear();
      droppedOffStudents.clear();

      // Combine all students from both morning pickup and afternoon dropoff
      final allStudents = <Map<String, dynamic>>[];
      allStudents.addAll(morningPickupStudents);
      allStudents.addAll(afternoonDropoffStudents);

      // Remove duplicates based on student ID
      final uniqueStudents = <int, Map<String, dynamic>>{};
      for (final studentData in allStudents) {
        final studentId = studentData['students']['id'];
        uniqueStudents[studentId] = studentData;
      }

      // Check status for each unique student
      for (final studentData in uniqueStudents.values) {
        final student = studentData['students'];
        final studentId = student['id'];

        final wasPickedUp = await _driverService.wasStudentPickedUpToday(
          studentId,
          user.id,
        );

        final wasDroppedOff = await _driverService.wasStudentDroppedOffToday(
          studentId,
          user.id,
        );

        final studentModel = Student(
          id: studentId.toString(),
          name: '${student['fname']} ${student['lname']}',
          grade: student['grade_level'] ?? 'Unknown',
          studentDbId: studentId,
          sectionName: student['sections']?['name'],
        );

        if (wasPickedUp) {
          final pickupTime = await _driverService.getStudentPickupTime(
            studentId,
            user.id,
          );

          final updatedStudent = studentModel.copyWith(
            isPickedUp: true,
            pickupTime: pickupTime,
            driverName: user.userMetadata?['fname'] ?? 'Driver',
          );

          pickedUpStudents.add(updatedStudent);
        }

        if (wasDroppedOff) {
          final updatedStudent = studentModel.copyWith(
            isPickedUp: true,
            pickupTime: await _driverService.getStudentPickupTime(
              studentId,
              user.id,
            ),
            driverName: user.userMetadata?['fname'] ?? 'Driver',
          );

          droppedOffStudents.add(updatedStudent);
        }
      }

      setState(() {});
    } catch (e) {
      print('Error loading today\'s status: $e');
    }
  }

  void _showPickupCancellationConfirmation(Student student) {
    String selectedReason = 'Student not present';
    String customReason = '';
    bool useCustomReason = false;
    
    final predefinedReasons = [
      'Student not present',
      'Student sick/absent',
      'Parent pickup instead',
      'Early dismissal',
      'Schedule change',
      'Vehicle issue',
      'Emergency situation',
      'Other'
    ];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16),
            scrollable: true,
            title: Row(
              children: [
                Icon(Icons.cancel, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Cancel Pickup',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please select a reason for cancelling ${student.name}\'s pickup:',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: InputDecoration(
                    labelText: 'Cancellation Reason',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: predefinedReasons.map((reason) => DropdownMenuItem(
                    value: reason,
                    child: Text(reason),
                  )).toList(),
                  onChanged: (value) {
                    setModalState(() {
                      selectedReason = value!;
                      useCustomReason = value == 'Other';
                      if (!useCustomReason) customReason = '';
                    });
                  },
                ),
                if (useCustomReason) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Please specify',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) => customReason = value,
                    maxLength: 100,
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This will cancel the pickup and notify parents.',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : () {
                          final reason = useCustomReason && customReason.isNotEmpty 
                              ? customReason 
                              : selectedReason;
                          Navigator.of(context).pop();
                          _cancelPickup(student, reason);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 4,
                          shadowColor: Colors.orange.withOpacity(0.3),
                        ),
                        icon: _isProcessing 
                            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.cancel, color: Colors.white),
                        label: Text(
                          _isProcessing ? 'Cancelling...' : 'Yes, Cancel',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          side: BorderSide(color: Colors.grey[400]!, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(Icons.close, color: Colors.grey[600]),
                        label: Text(
                          'Keep Pickup',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showPickupConfirmation(Student student) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          scrollable: true,
          title: Row(
            children: [
              Icon(Icons.directions_car, color: widget.primaryColor, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Confirm Pickup',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to mark ${student.name} as picked up?',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _confirmStudentPickup(student);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 4,
                        shadowColor: widget.primaryColor.withOpacity(0.3),
                      ),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text(
                        'Confirm Pick-up',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                        side: BorderSide(color: Colors.grey[400]!, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(
                        Icons.cancel,
                        color: Colors.grey[600],
                      ),
                      label: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.grey[600],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  void _showDropoffCancellationConfirmation(Student student) {
    String selectedReason = 'Student not at school';
    String customReason = '';
    bool useCustomReason = false;
    
    final predefinedReasons = [
      'Student not at school',
      'Student left early',
      'Parent pickup instead',
      'After-school activity',
      'Schedule change',
      'Vehicle issue',
      'Emergency situation',
      'Other'
    ];

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setModalState) => AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16),
            scrollable: true,
            title: Row(
              children: [
                Icon(Icons.cancel, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Cancel Dropoff',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please select a reason for cancelling ${student.name}\'s dropoff:',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: InputDecoration(
                    labelText: 'Cancellation Reason',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  ),
                  items: predefinedReasons.map((reason) => DropdownMenuItem(
                    value: reason,
                    child: Text(reason),
                  )).toList(),
                  onChanged: (value) {
                    setModalState(() {
                      selectedReason = value!;
                      useCustomReason = value == 'Other';
                      if (!useCustomReason) customReason = '';
                    });
                  },
                ),
                if (useCustomReason) ...[
                  const SizedBox(height: 12),
                  TextFormField(
                    decoration: InputDecoration(
                      labelText: 'Please specify',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                      contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    onChanged: (value) => customReason = value,
                    maxLength: 100,
                  ),
                ],
                const SizedBox(height: 12),
                Container(
                  padding: EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.orange.shade200),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.info_outline, color: Colors.orange.shade700, size: 20),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'This will cancel the dropoff and notify parents.',
                          style: TextStyle(
                            color: Colors.orange.shade700,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: _isProcessing ? null : () {
                          final reason = useCustomReason && customReason.isNotEmpty 
                              ? customReason 
                              : selectedReason;
                          Navigator.of(context).pop();
                          _cancelDropoff(student, reason);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.orange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 4,
                          shadowColor: Colors.orange.withOpacity(0.3),
                        ),
                        icon: _isProcessing 
                            ? SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : const Icon(Icons.cancel, color: Colors.white),
                        label: Text(
                          _isProcessing ? 'Cancelling...' : 'Yes, Cancel',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => Navigator.of(context).pop(),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.grey[600],
                          side: BorderSide(color: Colors.grey[400]!, width: 2),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(Icons.close, color: Colors.grey[600]),
                        label: Text(
                          'Keep Dropoff',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showDropoffConfirmation(Student student) {
    // Check if student was picked up first before showing confirmation
    if (!pickedUpStudents.any((s) => s.id == student.id)) {
      _showConfirmationDialog(
        'Student must be picked up before dropoff',
        Colors.orange,
      );
      return;
    }
    
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          scrollable: true,
          title: Row(
            children: [
              Icon(Icons.home, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Confirm Dropoff',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Are you sure you want to mark ${student.name} as dropped off?',
                style: const TextStyle(fontSize: 16),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () {
                        Navigator.of(context).pop();
                        _confirmStudentDropoff(student);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 4,
                        shadowColor: Colors.green.withOpacity(0.3),
                      ),
                      icon: const Icon(Icons.check, color: Colors.white),
                      label: const Text(
                        'Confirm Drop-off',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.green,
                        side: BorderSide(color: Colors.green, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(Icons.home, color: Colors.green),
                      label: Text(
                        'Cancel',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Colors.green,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _confirmStudentPickup(Student student) async {
    if (student.studentDbId == null) {
      _showConfirmationDialog(
        'Error: Student database ID not found',
        Colors.red,
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final isCurrentlyPickedUp = pickedUpStudents.any(
        (s) => s.id == student.id,
      );

      if (isCurrentlyPickedUp) {
        // Remove student from picked up list (cancel pickup)
        setState(() {
          pickedUpStudents.removeWhere((s) => s.id == student.id);
          // Only remove from dropped off if they were actually dropped off
          if (droppedOffStudents.any((s) => s.id == student.id)) {
            droppedOffStudents.removeWhere((s) => s.id == student.id);
          }
        });
        
        // Call database cleanup for cancelled pickup record
        await _driverService.cancelPickup(
          studentId: student.studentDbId!,
          driverId: user.id,
          reason: 'Manual cancellation via driver app',
          notes: 'Driver manually cancelled pickup operation'
        );

        // Log pickup cancellation (HIGH PRIORITY - Transportation Safety & Compliance)
        try {
          await _driverAuditService.logPickupCancellation(
            studentId: student.studentDbId!.toString(),
            studentName: student.name,
            reason: 'Manual cancellation via driver app',
            driverId: user.id,
            driverName: user.userMetadata?['fname'] ?? 'Driver',
            notes: 'Driver cancelled pickup operation',
          );
        } catch (auditError) {
          print('Error logging pickup cancellation: $auditError');
        }

        _showConfirmationDialog(
          '${student.name} pickup cancelled',
          Colors.orange,
        );
      } else {
        // Record pickup in database
        final pickupTime = DateTime.now();
        final success = await _driverService.recordPickup(
          studentId: student.studentDbId!,
          driverId: user.id,
          pickupTime: pickupTime,
          notes: 'Picked up via driver app',
        );

        if (success) {
          // Add student to picked up list
          final updatedStudent = student.copyWith(
            isPickedUp: true,
            pickupTime: pickupTime,
            driverName: user.userMetadata?['fname'] ?? 'Driver',
          );

          setState(() {
            pickedUpStudents.add(updatedStudent);
          });

          // Log pickup operation (HIGH PRIORITY - Transportation Safety & Compliance)
          try {
            await _driverAuditService.logStudentPickup(
              studentId: student.studentDbId!.toString(),
              studentName: student.name,
              pickupTime: pickupTime,
              driverId: user.id,
              driverName: user.userMetadata?['fname'] ?? 'Driver',
              verificationStatus: 'pending',
              notes: 'Picked up via driver app',
            );
          } catch (auditError) {
            print('Error logging pickup operation: $auditError');
          }

          // Create verification request for parents
          try {
            await _verificationService.createVerificationRequest(
              studentId: student.studentDbId!,
              driverId: user.id,
              eventType: 'pickup',
              eventTime: pickupTime,
            );

            // Log verification request creation (HIGH PRIORITY - Parent Safety Verification)
            try {
              await _driverAuditService.logVerificationRequestCreation(
                studentId: student.studentDbId!.toString(),
                studentName: student.name,
                eventType: 'pickup',
                eventTime: pickupTime,
                driverId: user.id,
                driverName: user.userMetadata?['fname'] ?? 'Driver',
                parentNotificationStatus: 'sent',
                verificationMethod: 'app_notification',
              );
            } catch (auditError) {
              print('Error logging verification request: $auditError');
            }

            _showConfirmationDialog(
              '✓ ${student.name} marked as picked up - Verification request sent to parents',
              widget.primaryColor,
            );
          } catch (verificationError) {
            print('Error creating verification request: $verificationError');
            
            // Log verification request failure
            try {
              await _driverAuditService.logVerificationRequestCreation(
                studentId: student.studentDbId!.toString(),
                studentName: student.name,
                eventType: 'pickup',
                eventTime: pickupTime,
                driverId: user.id,
                driverName: user.userMetadata?['fname'] ?? 'Driver',
                parentNotificationStatus: 'failed',
                verificationMethod: 'app_notification',
              );
            } catch (auditError) {
              print('Error logging verification request failure: $auditError');
            }
            
            _showConfirmationDialog(
              '✓ ${student.name} marked as picked up - Warning: Could not send verification request',
              Colors.orange,
            );
          }
        } else {
          _showConfirmationDialog(
            'Error recording pickup for ${student.name}',
            Colors.red,
          );
        }
      }
    } catch (e) {
      _showConfirmationDialog('Error: $e', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  Future<void> _confirmStudentDropoff(Student student) async {
    if (student.studentDbId == null) {
      _showConfirmationDialog(
        'Error: Student database ID not found',
        Colors.red,
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final isCurrentlyDroppedOff = droppedOffStudents.any(
        (s) => s.id == student.id,
      );

      if (isCurrentlyDroppedOff) {
        // Remove student from dropped off list (cancel dropoff)
        setState(() {
          droppedOffStudents.removeWhere((s) => s.id == student.id);
        });

        // Call database cleanup for cancelled dropoff record
        await _driverService.cancelDropoff(
          studentId: student.studentDbId!,
          driverId: user.id,
          reason: 'Manual cancellation via driver app',
          notes: 'Driver manually cancelled dropoff operation'
        );

        // Log dropoff cancellation (HIGH PRIORITY - Transportation Safety & Compliance)
        try {
          await _driverAuditService.logDropoffCancellation(
            studentId: student.studentDbId!.toString(),
            studentName: student.name,
            reason: 'Manual cancellation via driver app',
            driverId: user.id,
            driverName: user.userMetadata?['fname'] ?? 'Driver',
            notes: 'Driver cancelled dropoff operation',
          );
        } catch (auditError) {
          print('Error logging dropoff cancellation: $auditError');
        }

        _showConfirmationDialog(
          '${student.name} dropoff cancelled',
          Colors.orange,
        );
      } else {
        // Record dropoff in database
        final dropoffTime = DateTime.now();
        final success = await _driverService.recordDropoff(
          studentId: student.studentDbId!,
          driverId: user.id,
          dropoffTime: dropoffTime,
          notes: 'Dropped off via driver app',
        );

        if (success) {
          // Add student to dropped off list
          final updatedStudent = student.copyWith(
            isPickedUp: true,
            pickupTime:
                pickedUpStudents
                    .firstWhere((s) => s.id == student.id)
                    .pickupTime,
            driverName: user.userMetadata?['fname'] ?? 'Driver',
          );

          setState(() {
            droppedOffStudents.add(updatedStudent);
          });

          // Log dropoff operation (HIGH PRIORITY - Transportation Safety & Compliance)
          try {
            await _driverAuditService.logStudentDropoff(
              studentId: student.studentDbId!.toString(),
              studentName: student.name,
              dropoffTime: dropoffTime,
              driverId: user.id,
              driverName: user.userMetadata?['fname'] ?? 'Driver',
              verificationStatus: 'pending',
              notes: 'Dropped off via driver app',
            );
          } catch (auditError) {
            print('Error logging dropoff operation: $auditError');
          }

          // Create verification request for parents
          try {
            await _verificationService.createVerificationRequest(
              studentId: student.studentDbId!,
              driverId: user.id,
              eventType: 'dropoff',
              eventTime: dropoffTime,
            );

            // Log verification request creation (HIGH PRIORITY - Parent Safety Verification)
            try {
              await _driverAuditService.logVerificationRequestCreation(
                studentId: student.studentDbId!.toString(),
                studentName: student.name,
                eventType: 'dropoff',
                eventTime: dropoffTime,
                driverId: user.id,
                driverName: user.userMetadata?['fname'] ?? 'Driver',
                parentNotificationStatus: 'sent',
                verificationMethod: 'app_notification',
              );
            } catch (auditError) {
              print('Error logging verification request: $auditError');
            }

            _showConfirmationDialog(
              '✓ ${student.name} marked as dropped off - Verification request sent to parents',
              Colors.green,
            );
          } catch (verificationError) {
            print('Error creating verification request: $verificationError');
            
            // Log verification request failure
            try {
              await _driverAuditService.logVerificationRequestCreation(
                studentId: student.studentDbId!.toString(),
                studentName: student.name,
                eventType: 'dropoff',
                eventTime: dropoffTime,
                driverId: user.id,
                driverName: user.userMetadata?['fname'] ?? 'Driver',
                parentNotificationStatus: 'failed',
                verificationMethod: 'app_notification',
              );
            } catch (auditError) {
              print('Error logging verification request failure: $auditError');
            }
            
            _showConfirmationDialog(
              '✓ ${student.name} marked as dropped off - Warning: Could not send verification request',
              Colors.orange,
            );
          }
        } else {
          _showConfirmationDialog(
            'Error recording dropoff for ${student.name}',
            Colors.red,
          );
        }
      }
    } catch (e) {
      _showConfirmationDialog('Error: $e', Colors.red);
    }
  }

  bool _isStudentPickedUp(Student student) {
    return pickedUpStudents.any((s) => s.id == student.id);
  }

  bool _isStudentDroppedOff(Student student) {
    return droppedOffStudents.any((s) => s.id == student.id);
  }

  /// Cancel pickup with reason and database cleanup
  Future<void> _cancelPickup(Student student, String reason) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      // Call the database cancellation method
      final success = await _driverService.cancelPickup(
        studentId: student.studentDbId!,
        driverId: user.id,
        reason: reason,
        notes: 'Cancelled via driver app',
      );

      if (success) {
        setState(() {
          // Remove from picked up list if they were picked up
          if (pickedUpStudents.any((s) => s.id == student.id)) {
            pickedUpStudents.removeWhere((s) => s.id == student.id);
          }
        });

        // Log pickup cancellation (HIGH PRIORITY - Transportation Safety & Compliance)
        try {
          await _driverAuditService.logPickupCancellation(
            studentId: student.studentDbId!.toString(),
            studentName: student.name,
            reason: reason,
            driverId: user.id,
            driverName: user.userMetadata?['fname'] ?? 'Driver',
            notes: 'Driver cancelled pickup operation via app',
          );
        } catch (auditError) {
          print('Error logging pickup cancellation: $auditError');
        }

        _showConfirmationDialog(
          '✓ ${student.name} pickup cancelled - Parents notified',
          Colors.orange,
        );
      } else {
        _showConfirmationDialog(
          'Error cancelling pickup for ${student.name}',
          Colors.red,
        );
      }
    } catch (e) {
      _showConfirmationDialog('Error: $e', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Cancel dropoff with reason and database cleanup
  Future<void> _cancelDropoff(Student student, String reason) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      // Call the database cancellation method
      final success = await _driverService.cancelDropoff(
        studentId: student.studentDbId!,
        driverId: user.id,
        reason: reason,
        notes: 'Cancelled via driver app',
      );

      if (success) {
        setState(() {
          // Remove from dropped off list if they were dropped off
          if (droppedOffStudents.any((s) => s.id == student.id)) {
            droppedOffStudents.removeWhere((s) => s.id == student.id);
          }
        });

        // Log dropoff cancellation (HIGH PRIORITY - Transportation Safety & Compliance)
        try {
          await _driverAuditService.logDropoffCancellation(
            studentId: student.studentDbId!.toString(),
            studentName: student.name,
            reason: reason,
            driverId: user.id,
            driverName: user.userMetadata?['fname'] ?? 'Driver',
            notes: 'Driver cancelled dropoff operation via app',
          );
        } catch (auditError) {
          print('Error logging dropoff cancellation: $auditError');
        }

        _showConfirmationDialog(
          '✓ ${student.name} dropoff cancelled - Parents notified',
          Colors.orange,
        );
      } else {
        _showConfirmationDialog(
          'Error cancelling dropoff for ${student.name}',
          Colors.red,
        );
      }
    } catch (e) {
      _showConfirmationDialog('Error: $e', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(widget.primaryColor),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading pickup tasks...',
              style: TextStyle(
                fontSize: 18,
                color: const Color(0xFF000000).withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    if (_error != null) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'Error Loading Data',
              style: TextStyle(
                fontSize: 18,
                color: Colors.red.withOpacity(0.7),
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF000000).withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeData,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    if (morningPickupStudents.isEmpty && afternoonDropoffStudents.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.event_available,
              size: 64,
              color: widget.primaryColor.withOpacity(0.5),
            ),
            const SizedBox(height: 16),
            Text(
              'No pickup/dropoff tasks scheduled for today',
              style: TextStyle(
                fontSize: 18,
                color: const Color(0xFF000000).withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'Check back tomorrow or contact your administrator',
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF000000).withOpacity(0.5),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initializeData,
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
              ),
              child: const Text('Refresh'),
            ),
          ],
        ),
      );
    }

    // Get unique students count for progress calculation
    final uniqueStudents = <int>{};
    for (final studentData in morningPickupStudents) {
      uniqueStudents.add(studentData['students']['id']);
    }
    for (final studentData in afternoonDropoffStudents) {
      uniqueStudents.add(studentData['students']['id']);
    }

    // Calculate progress based on total tasks completed vs total tasks
    final totalPickupTasks = morningPickupStudents.length;
    final totalDropoffTasks = afternoonDropoffStudents.length;
    final completedPickups = pickedUpStudents.length;
    final completedDropoffs = droppedOffStudents.length;
    final totalTasks = totalPickupTasks + totalDropoffTasks;
    final completedTasks = completedPickups + completedDropoffs;
    final progress = totalTasks > 0 ? completedTasks / totalTasks : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            color: Colors.white,
            elevation: 8,
            shadowColor: Colors.black.withOpacity(0.15),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: widget.primaryColor.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                    spreadRadius: 2,
                  ),
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.primaryColor,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'TODAY\'S TASK',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 12,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: widget.primaryColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          TimeUtils.formatTimeForDisplay(TimeUtils.nowPST()),
                          style: TextStyle(
                            color: widget.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Icon(Icons.school, color: widget.primaryColor, size: 24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Today\'s Pickup & Dropoff Tasks',
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF000000),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Progress Section
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Progress',
                              style: TextStyle(
                                fontSize: 14,
                                color: const Color(0xFF000000).withOpacity(0.7),
                              ),
                            ),
                            const SizedBox(height: 8),
                            LinearProgressIndicator(
                              value: progress,
                              backgroundColor: Colors.grey.withOpacity(0.3),
                              valueColor: AlwaysStoppedAnimation<Color>(
                                widget.primaryColor,
                              ),
                              minHeight: 8,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '$completedTasks / $totalTasks',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: widget.primaryColor,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Morning Pickup Section
          if (morningPickupStudents.isNotEmpty) ...[
            _buildSectionHeader(
              'Morning Pickup',
              morningPickupStudents.length,
              Colors.blue,
              Icons.upload,
            ),
            const SizedBox(height: 16),
            ...morningPickupStudents.map(
              (studentData) => _buildStudentCard(
                _convertToStudentModel(studentData),
                isDriverResponsible:
                    studentData['is_driver_responsible'] ?? false,
                taskType: 'morning_pickup',
                studentData: studentData,
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Afternoon Dropoff Section
          if (afternoonDropoffStudents.isNotEmpty) ...[
            _buildSectionHeader(
              'Afternoon Dropoff',
              afternoonDropoffStudents.length,
              Colors.green,
              Icons.download,
            ),
            const SizedBox(height: 16),
            ...afternoonDropoffStudents.map(
              (studentData) => _buildStudentCard(
                _convertToStudentModel(studentData),
                isDriverResponsible:
                    studentData['is_driver_responsible'] ?? false,
                taskType: 'afternoon_dropoff',
                studentData: studentData,
              ),
            ),
            const SizedBox(height: 24),
          ],

          const SizedBox(height: 24),

          // Action Buttons
          if (completedTasks > 0) ...[
            Card(
              color: Colors.white,
              elevation: 6,
              shadowColor: Colors.black.withOpacity(0.15),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: widget.primaryColor.withOpacity(0.08),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Pickup Summary',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Students picked up: $completedPickups',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF000000),
                      ),
                    ),
                    Text(
                      'Students dropped off: ${droppedOffStudents.length}',
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF000000),
                      ),
                    ),
                    Text(
                      'Time: ${DateFormat('h:mm a').format(DateTime.now())}',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF000000).withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 16),
                    if (completedTasks == totalTasks)
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            _showTaskCompletedDialog();
                          },
                          icon: const Icon(Icons.check_circle),
                          label: const Text('Complete Pickup Task'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.green,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper method to convert student data to Student model
  Student _convertToStudentModel(Map<String, dynamic> studentData) {
    final student = studentData['students'];
    return Student(
      id: student['id'].toString(),
      name: '${student['fname']} ${student['lname']}',
      grade: student['grade_level'] ?? 'Unknown',
      studentDbId: student['id'],
      sectionName: student['sections']?['name'],
    );
  }

  // Helper method to get scheduled time
  String _getScheduledTime(
    Map<String, dynamic>? studentData,
    bool isMorningPickup,
  ) {
    if (studentData == null) return 'No time set';

    final time =
        isMorningPickup
            ? studentData['pickup_time']
            : studentData['dropoff_time'];

    if (time == null) return 'No time set';

    try {
      // Parse time string (format: HH:mm:ss or HH:mm)
      final timeParts = time.toString().split(':');
      if (timeParts.length >= 2) {
        final hour = int.parse(timeParts[0]);
        final minute = int.parse(timeParts[1]);
        final timeOfDay = TimeOfDay(hour: hour, minute: minute);

        // Format to 12-hour format
        final now = DateTime.now();
        final dateTime = DateTime(
          now.year,
          now.month,
          now.day,
          timeOfDay.hour,
          timeOfDay.minute,
        );
        return DateFormat('h:mm a').format(dateTime);
      }
    } catch (e) {
      print('Error parsing time: $e');
    }

    return time.toString();
  }

  // Helper method to get student address
  String _getStudentAddress(Map<String, dynamic>? studentData) {
    if (studentData == null) return 'No address';

    final student = studentData['students'];
    final address = student?['address'];

    if (address == null || address.toString().trim().isEmpty) {
      return 'No address provided';
    }

    return address.toString();
  }

  // Helper method to build section headers
  Widget _buildSectionHeader(
    String title,
    int count,
    Color color,
    IconData icon,
  ) {
    return Row(
      children: [
        Icon(icon, color: color, size: 24),
        const SizedBox(width: 12),
        Text(
          title,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '$count student${count != 1 ? 's' : ''}',
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildStudentCard(
    Student student, {
    required bool isDriverResponsible,
    required String taskType,
    Map<String, dynamic>? studentData,
  }) {
    final isPickedUp = _isStudentPickedUp(student);
    final isDroppedOff = _isStudentDroppedOff(student);
    final pickedUpStudent = pickedUpStudents.firstWhere(
      (s) => s.id == student.id,
      orElse: () => student,
    );

    Color statusColor;
    IconData statusIcon;
    String statusText;

    if (isDroppedOff) {
      statusColor = Colors.green;
      statusIcon = Icons.home;
      statusText = 'Dropped Off';
    } else if (isPickedUp) {
      statusColor = widget.primaryColor;
      statusIcon = Icons.directions_car;
      statusText = 'Picked Up';
    } else {
      statusColor = Colors.grey;
      statusIcon = Icons.person;
      statusText = 'Waiting';
    }

    // Determine if this is a morning pickup or afternoon dropoff task
    final isMorningPickup = taskType == 'morning_pickup';
    final isAfternoonDropoff = taskType == 'afternoon_dropoff';

    return Card(
      color: Colors.white,
      elevation: isPickedUp || isDroppedOff ? 8 : 6,
      shadowColor: Colors.black.withOpacity(0.15),
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _showStudentInfo(student),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color:
                isDriverResponsible
                    ? Colors.white
                    : Colors.grey.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border:
                isPickedUp || isDroppedOff
                    ? Border.all(color: statusColor, width: 2)
                    : isDriverResponsible
                    ? null
                    : Border.all(color: Colors.grey.withOpacity(0.3), width: 1),
            boxShadow: [
              BoxShadow(
                color:
                    isPickedUp || isDroppedOff
                        ? statusColor.withOpacity(0.1)
                        : Colors.black.withOpacity(0.05),
                blurRadius: isPickedUp || isDroppedOff ? 8 : 4,
                offset: const Offset(0, 3),
                spreadRadius: isPickedUp || isDroppedOff ? 1 : 0,
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                // Top Row: Student Info and Status
                Row(
                  children: [
                    // Student Avatar
                    CircleAvatar(
                      backgroundColor: statusColor.withOpacity(0.1),
                      radius: 24,
                      child: Text(
                        student.name.split(' ').map((n) => n[0]).take(2).join(),
                        style: TextStyle(
                          color: statusColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Student Details
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            student.name,
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color:
                                  isDriverResponsible
                                      ? const Color(0xFF000000)
                                      : Colors.grey[600],
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${student.grade}${student.sectionName != null ? ' • ${student.sectionName}' : ''}',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.grey[600],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(statusIcon, color: Colors.white, size: 16),
                          const SizedBox(width: 4),
                          Text(
                            statusText,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Time and Location Row
                Row(
                  children: [
                    // Time Display
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: (isMorningPickup ? Colors.blue : Colors.green)
                              .withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isMorningPickup
                                      ? Icons.schedule
                                      : Icons.access_time,
                                  size: 16,
                                  color:
                                      isMorningPickup
                                          ? Colors.blue
                                          : Colors.green,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isMorningPickup
                                      ? 'Pickup Time'
                                      : 'Dropoff Time',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getScheduledTime(studentData, isMorningPickup),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color:
                                    isMorningPickup
                                        ? Colors.blue
                                        : Colors.green,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(width: 12),

                    // Address Display
                    Expanded(
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.grey.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  isMorningPickup ? Icons.home : Icons.school,
                                  size: 16,
                                  color: Colors.grey[600],
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isMorningPickup ? 'From Home' : 'To Home',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: Colors.grey[600],
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _getStudentAddress(studentData),
                              style: TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color: Colors.grey[800],
                              ),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),

                // Exception Information
                if (studentData?['exception_reason'] != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3)),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning, size: 16, color: Colors.orange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Exception: ${studentData!['exception_reason']}',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Colors.orange,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Pickup Time Display (if already picked up)
                if (isPickedUp && pickedUpStudent.pickupTime != null) ...[
                  const SizedBox(height: 12),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: widget.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.check_circle,
                          size: 16,
                          color: widget.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Picked up at ${DateFormat('h:mm a').format(pickedUpStudent.pickupTime!)}',
                          style: TextStyle(
                            fontSize: 13,
                            color: widget.primaryColor,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 16),

                // Action Buttons
                Row(
                  children: [
                    // Driver Responsibility Indicator
                    if (!isDriverResponsible) ...[
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          decoration: BoxDecoration(
                            color: Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: Colors.grey.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.person,
                                size: 16,
                                color: Colors.grey[600],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                isMorningPickup
                                    ? 'Parent Pickup'
                                    : 'Parent Dropoff',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ] else ...[
                      // Morning Pickup Button
                      if (isMorningPickup) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                !isDroppedOff
                                    ? (isPickedUp
                                        ? () => _showPickupCancellationConfirmation(student)
                                        : () => _showPickupConfirmation(student))
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isPickedUp
                                      ? Colors.orange.withOpacity(0.8)
                                      : widget.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            icon: Icon(
                              isPickedUp ? Icons.cancel : Icons.directions_car,
                              size: 18,
                            ),
                            label: Text(
                              isPickedUp ? 'Cancel Pickup' : 'Mark as Picked Up',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],

                      // Afternoon Dropoff Button
                      if (isAfternoonDropoff) ...[
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed:
                                isPickedUp
                                    ? (isDroppedOff
                                        ? () => _showDropoffCancellationConfirmation(student)
                                        : () => _showDropoffConfirmation(student))
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isDroppedOff
                                      ? Colors.orange.withOpacity(0.8)
                                      : Colors.green,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.grey.withOpacity(0.3),
                              disabledForegroundColor: Colors.grey[600],
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            icon: Icon(
                              isDroppedOff 
                                  ? Icons.cancel 
                                  : isPickedUp 
                                      ? Icons.home 
                                      : Icons.block,
                              size: 18,
                            ),
                            label: Text(
                              isDroppedOff
                                  ? 'Cancel Dropoff'
                                  : isPickedUp
                                      ? 'Mark as Dropped Off'
                                      : 'Pick up first',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showConfirmationDialog(String message, Color color) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          insetPadding: const EdgeInsets.symmetric(horizontal: 16),
          scrollable: true,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          contentPadding: const EdgeInsets.fromLTRB(24, 24, 24, 20),
          content: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 60,
                  height: 60,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: color.withOpacity(0.35),
                        blurRadius: 12,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.check, color: Colors.white, size: 32),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  message,
                  style: const TextStyle(
                    fontSize: 16.5,
                    fontWeight: FontWeight.w500,
                    color: Colors.black87,
                    height: 1.35,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 18),
                SizedBox(
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      elevation: 3,
                      shadowColor: color.withOpacity(0.35),
                      padding: const EdgeInsets.symmetric(horizontal: 28),
                      shape: const StadiumBorder(),
                    ),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTaskCompletedDialog() async {
    // Log task completion (MEDIUM PRIORITY - Operational Tracking)
    try {
      final user = Supabase.instance.client.auth.currentUser;
      final uniqueStudents = <int>{};
      for (final studentData in morningPickupStudents) {
        uniqueStudents.add(studentData['students']['id']);
      }
      for (final studentData in afternoonDropoffStudents) {
        uniqueStudents.add(studentData['students']['id']);
      }
      
      final totalStudents = uniqueStudents.length;
      final completedStudents = pickedUpStudents.length;
      final routeType = morningPickupStudents.isNotEmpty && afternoonDropoffStudents.isNotEmpty 
          ? 'mixed' 
          : morningPickupStudents.isNotEmpty 
              ? 'morning_pickup' 
              : 'afternoon_dropoff';
      
      // Calculate completion time based on first pickup
      final firstPickupTime = pickedUpStudents.isNotEmpty 
          ? pickedUpStudents.first.pickupTime 
          : DateTime.now();
      final completionTime = DateTime.now().difference(firstPickupTime ?? DateTime.now());
      
      await _driverAuditService.logTaskCompletion(
        totalStudents: totalStudents,
        completionTime: completionTime,
        routeType: routeType,
        driverId: user?.id,
        driverName: user?.userMetadata?['fname'] ?? 'Driver',
        routeEfficiencyMetrics: {
          'completed_students': completedStudents,
          'completion_rate': completedStudents / totalStudents,
          'minutes_per_student': completionTime.inMinutes / (completedStudents > 0 ? completedStudents : 1),
        },
        completedStudentIds: pickedUpStudents.map((s) => s.id).toList(),
        performanceMetrics: {
          'total_pickups': pickedUpStudents.length,
          'total_dropoffs': droppedOffStudents.length,
          'route_completion': 'successful',
        },
      );
    } catch (auditError) {
      print('Error logging task completion: $auditError');
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 24),
              const SizedBox(width: 8),
              const Text(
                'Task Completed!',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          content: const Text(
            'Pickup task completed! Parents will be notified.',
            style: TextStyle(fontSize: 16),
          ),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.green,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: const Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showStudentInfo(Student student) async {
    // Log student information access
    try {
      final user = Supabase.instance.client.auth.currentUser;
      await _driverAuditService.logStudentInfoAccess(
        studentId: student.studentDbId?.toString() ?? student.id,
        studentName: student.name,
        accessType: 'view_details',
        driverId: user?.id,
        driverName: user?.userMetadata?['fname'] ?? 'Driver',
        accessDetails: {
          'access_reason': 'driver_information_review',
          'student_grade': student.grade,
          'student_section': student.sectionName,
        },
      );
    } catch (auditError) {
      print('Error logging student info access: $auditError');
    }

    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Center(
          child: AlertDialog(
            backgroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            insetPadding: const EdgeInsets.symmetric(horizontal: 16),
            scrollable: true,
            title: Row(
              children: [
                Icon(Icons.person, color: widget.primaryColor, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Student Information',
                  style: TextStyle(fontSize: 19, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: FutureBuilder<Map<String, dynamic>>(
                future: _getStudentDetails(student),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final studentDetails = snapshot.data ?? {};
                  final parents =
                      studentDetails['parents'] as List<dynamic>? ?? [];

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildInfoRow('Name', student.name),
                      _buildInfoRow('Grade', student.grade),
                      _buildInfoRow('Student ID', student.id),
                      if (student.sectionName != null)
                        _buildInfoRow('Section', student.sectionName!),

                      // Contact Information Section
                      if (parents.isNotEmpty) ...[
                        const Divider(),
                        Row(
                          children: [
                            Icon(
                              Icons.contact_phone,
                              color: widget.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Parent/Guardian Information',
                              style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.bold,
                                color: widget.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...parents
                            .map(
                              (parent) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoRow(
                                    'Name',
                                    '${parent['fname']} ${parent['lname']}',
                                  ),
                                  _buildInfoRow(
                                    'Phone',
                                    parent['phone'] ?? 'N/A',
                                  ),
                                  _buildInfoRow(
                                    'Email',
                                    parent['email'] ?? 'N/A',
                                  ),
                                  if (parents.length > 1)
                                    const SizedBox(height: 8),
                                ],
                              ),
                            )
                            .toList(),
                      ],

                      if (_isStudentPickedUp(student)) ...[
                        const Divider(),
                        Row(
                          children: [
                            Icon(
                              Icons.directions_car,
                              color: widget.primaryColor,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Pickup Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: widget.primaryColor,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Pickup Time',
                          DateFormat('h:mm a').format(
                            pickedUpStudents
                                .firstWhere((s) => s.id == student.id)
                                .pickupTime!,
                          ),
                        ),
                        _buildInfoRow(
                          'Driver',
                          Supabase
                                  .instance
                                  .client
                                  .auth
                                  .currentUser
                                  ?.userMetadata?['fname'] ??
                              'Driver',
                        ),
                      ],
                      if (_isStudentDroppedOff(student)) ...[
                        const Divider(),
                        Row(
                          children: [
                            Icon(Icons.home, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'Dropoff Details',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.green,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        _buildInfoRow(
                          'Dropoff Time',
                          DateFormat('h:mm a').format(DateTime.now()),
                        ),
                        _buildInfoRow('Status', 'Completed'),
                      ],
                    ],
                  );
                },
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('Close', style: TextStyle(fontSize: 16)),
              ),
            ],
          ),
        );
      },
    );
  }

  Future<Map<String, dynamic>> _getStudentDetails(Student student) async {
    if (student.studentDbId == null) {
      return {};
    }

    try {
      // Get parent information for the student
      final parentResponse = await Supabase.instance.client
          .from('parent_student')
          .select('''
            parents!parent_student_parent_id_fkey (
              id,
              fname,
              lname,
              phone,
              email
            )
          ''')
          .eq('student_id', student.studentDbId!);

      final parents =
          parentResponse
              .map((item) => item['parents'])
              .where((parent) => parent != null)
              .toList();

      return {'parents': parents};
    } catch (e) {
      print('Error fetching student details: $e');
      return {};
    }
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 80,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
