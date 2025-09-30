import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/driver_models.dart';
import '../../services/driver_service.dart';
import '../../services/verification_service.dart';
import '../../services/driver_audit_service.dart';
import '../../services/sms_gateway_service.dart';
import 'package:kidsync/services/config.dart';
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
  List<Student> skippedPickupStudents = [];
  final DriverService _driverService = DriverService();
  final VerificationService _verificationService = VerificationService();
  final DriverAuditService _driverAuditService = DriverAuditService();
  // NOTE: In production, do not hardcode credentials. Use secure storage.
  final SmsGatewayService _smsService = SmsGatewayService(
    username: 'ASTVXO',
    password: 'm_cfb-t4kqx4wt',
    supabaseFunctionUrl: SUPABASE_FUNCTIONS_BASE.isNotEmpty ? '${SUPABASE_FUNCTIONS_BASE.replaceAll(RegExp(r'\/$'), '')}/send-sms' : null,
  );
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
      skippedPickupStudents.clear();

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

        // Check if pickup was skipped
        final wasPickupSkipped = await _wasStudentPickupSkippedToday(
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

        if (wasPickupSkipped) {
          // Add to skipped list
          skippedPickupStudents.add(studentModel);
        } else if (wasPickedUp) {
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

  void _showSkipPickupConfirmation(Student student) {
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
      'Student no longer needs pickup',
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
                Icon(Icons.event_busy, color: Colors.orange, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Skip Pickup',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Please select a reason for skipping ${student.name}\'s pickup:',
                  style: const TextStyle(fontSize: 16),
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  value: selectedReason,
                  decoration: InputDecoration(
                    labelText: 'Skip Reason',
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
                          'This will skip the pickup and notify parents. If student is also scheduled for dropoff, that will be cancelled too.',
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
                          _skipPickup(student, reason);
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
                            : const Icon(Icons.event_busy, color: Colors.white),
                        label: Text(
                          _isProcessing ? 'Skipping...' : 'Skip Pickup',
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

  void _showCancelPickupConfirmation(Student student) {
    String selectedReason = 'Change of plans';
    String customReason = '';
    bool useCustomReason = false;
    
    final predefinedReasons = [
      'Change of plans',
      'Student no longer needs pickup',
      'Parent pickup instead',
      'Emergency situation',
      'Schedule change',
      'Vehicle issue',
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
                          'This will cancel the completed pickup and notify parents. If student is also scheduled for dropoff, that will be cancelled too.',
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
                          _isProcessing ? 'Cancelling...' : 'Cancel Pickup',
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
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: widget.primaryColor.withOpacity(0.06),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: widget.primaryColor,
                        backgroundImage: _getStudentProfileImage(null),
                        child: _getStudentProfileImage(null) == null
                            ? Icon(Icons.directions_car, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Confirm Pickup',
                              style: TextStyle(
                                color: widget.primaryColor,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              student.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),

                // Body
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Are you sure you want to mark ${student.name} as picked up?',
                        style: const TextStyle(fontSize: 15, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _confirmStudentPickup(student);
                              },
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Confirm Pick-up'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[800],
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(color: Colors.grey.withOpacity(0.3)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showAccidentalPickupCancellation(Student student) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.06),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.blue,
                        backgroundImage: _getStudentProfileImage(null),
                        child: _getStudentProfileImage(null) == null
                            ? Icon(Icons.undo, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cancel Pickup',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              student.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'This will undo the pickup and remove the notification sent to parents.',
                        style: const TextStyle(fontSize: 15, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _cancelAccidentalPickup(student);
                              },
                              icon: const Icon(Icons.undo, size: 18),
                              label: const Text('Yes, Cancel'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Keep Pickup', style: TextStyle(fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.blue.shade700,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(color: Colors.blue.withOpacity(0.25)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.06),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.green,
                        backgroundImage: _getStudentProfileImage(null),
                        child: _getStudentProfileImage(null) == null
                            ? Icon(Icons.home, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Confirm Dropoff',
                              style: TextStyle(
                                color: Colors.green,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              student.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'Are you sure you want to mark ${student.name} as dropped off?',
                        style: const TextStyle(fontSize: 15, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _confirmStudentDropoff(student);
                              },
                              icon: const Icon(Icons.check, size: 18),
                              label: const Text('Confirm Drop-off'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.green,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Cancel', style: TextStyle(fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.green.shade700,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                side: BorderSide(color: Colors.green.withOpacity(0.25)),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCancelSkipConfirmation(Student student) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  decoration: BoxDecoration(
                    color: Colors.blue.withOpacity(0.06),
                    borderRadius: const BorderRadius.vertical(top: Radius.circular(14)),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 22,
                        backgroundColor: Colors.blue,
                        backgroundImage: _getStudentProfileImage(null),
                        child: _getStudentProfileImage(null) == null
                            ? Icon(Icons.undo, color: Colors.white)
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Cancel Skip',
                              style: TextStyle(
                                color: Colors.blue,
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              student.name,
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: Colors.black87,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'This will cancel the skip and restore ${student.name} to the pickup queue. Student will be available for pickup again.',
                        style: const TextStyle(fontSize: 15, height: 1.4),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () {
                                Navigator.of(context).pop();
                                _cancelSkippedPickup(student);
                              },
                              icon: const Icon(Icons.undo, size: 18),
                              label: const Text('Cancel Skip'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                                elevation: 4,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              child: const Text('Keep Skip', style: TextStyle(fontWeight: FontWeight.w600)),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.grey[600],
                                side: BorderSide(color: Colors.grey[400]!, width: 2),
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
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

          // Send SMS to parents via SMSGate cloud API (client-side)
          try {
            // Fetch parent phone numbers for this student
            final parentRows = await Supabase.instance.client
                .from('parent_student')
                .select('parent_id')
                .eq('student_id', student.studentDbId!);

            final parentIds = <int>[];
            for (final r in parentRows) {
              final pid = r['parent_id'];
              if (pid != null) parentIds.add(pid as int);
            }
            print('driver_pickup_tab: parentIds=$parentIds for student=${student.studentDbId}');

            final phones = <String>[];
            if (parentIds.isNotEmpty) {
              final parents = await Supabase.instance.client
                  .from('parents')
                  .select('phone')
                  .filter('id', 'in', '(${parentIds.join(',')})');
              for (final p in parents) {
                if (p['phone'] != null) phones.add(p['phone'] as String);
              }
              print('driver_pickup_tab: parent phones=$phones for student=${student.studentDbId}');
            }

            // Driver phone fallback
            String? driverPhone;
            final userRow = await Supabase.instance.client
                .from('users')
                .select('contact_number')
                .eq('id', user.id)
                .maybeSingle();
            if (userRow != null && userRow['contact_number'] != null) {
              driverPhone = userRow['contact_number'] as String;
            }

            if (phones.isNotEmpty) {
              print('driver_pickup_tab: sending SMS to parents; driverPhone=$driverPhone');
              final smsOk = await _smsService.sendSms(
                recipients: phones,
                message: 'Verification request: Your child ${student.name} was picked up by driver ${user.userMetadata?['fname'] ?? 'Driver'}.',
              );
              print('driver_pickup_tab: sms send result=$smsOk');
            } else {
              print('driver_pickup_tab: no parent phones found to send SMS for student=${student.studentDbId}');
            }
          } catch (smsError) {
            print('SMS send failed: $smsError');
          }

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

  bool _isStudentPickupSkipped(Student student) {
    return skippedPickupStudents.any((s) => s.id == student.id);
  }

  /// Check if student pickup was skipped today by looking at pickup_dropoff_logs
  Future<bool> _wasStudentPickupSkippedToday(int studentId, String driverId) async {
    try {
      final today = DateTime.now();
      final startOfDay = DateTime(today.year, today.month, today.day);
      final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

      final response = await Supabase.instance.client
          .from('pickup_dropoff_logs')
          .select('id')
          .eq('student_id', studentId)
          .eq('driver_id', driverId)
          .eq('event_type', 'pickup_skipped')  // Only look for active skips, not cancelled ones
          .gte('created_at', startOfDay.toIso8601String())
          .lt('created_at', endOfDay.toIso8601String())
          .limit(1);

      return response.isNotEmpty;
    } catch (e) {
      print('Error checking if pickup was skipped: $e');
      return false;
    }
  }

  /// Cancel skipped pickup (undo skip operation and restore student to waiting state)
  Future<void> _cancelSkippedPickup(Student student) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      // Remove from skipped list
      setState(() {
        skippedPickupStudents.removeWhere((s) => s.id == student.id);
      });

      // Delete/cancel the skip record from the database so it doesn't persist after refresh
      try {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

        // First, let's check what records exist before deletion
        final existingRecords = await Supabase.instance.client
            .from('pickup_dropoff_logs')
            .select('id, created_at, event_type')
            .eq('student_id', student.studentDbId!)
            .eq('driver_id', user.id)
            .eq('event_type', 'pickup_skipped')
            .gte('created_at', startOfDay.toIso8601String())
            .lt('created_at', endOfDay.toIso8601String());

        print('Found ${existingRecords.length} skip records to delete: $existingRecords');

        if (existingRecords.isNotEmpty) {
          // Delete using the specific IDs we found
          final recordIds = existingRecords.map((record) => record['id']).toList();
          
          print('Attempting to delete records with IDs: $recordIds');
          
          final deleteResponse = await Supabase.instance.client
              .from('pickup_dropoff_logs')
              .delete()
              .inFilter('id', recordIds);

          print('Delete response: $deleteResponse');
          print('Delete response type: ${deleteResponse.runtimeType}');
          
          // Verify deletion by checking if records still exist
          final verificationRecords = await Supabase.instance.client
              .from('pickup_dropoff_logs')
              .select('id')
              .inFilter('id', recordIds);
              
          print('Records remaining after delete: ${verificationRecords.length} - $verificationRecords');
          
          if (verificationRecords.isEmpty) {
            print('✓ Successfully deleted ${recordIds.length} skip records for student ${student.studentDbId}');
          } else {
            print('⚠️ Delete command executed but ${verificationRecords.length} records still exist');
            throw 'Records still exist after delete operation - possible RLS policy issue or database constraint violation';
          }
        } else {
          print('No skip records found to delete for student ${student.studentDbId}');
        }
      } catch (dbError) {
        print('Error handling skip record: $dbError');
        _showConfirmationDialog('Database Error: $dbError', Colors.red);
        return;
      }

      // Delete notifications for both parents and driver (same as cancel pickup)
      try {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

        // Delete parent notifications related to this skip
        await Supabase.instance.client
            .from('notifications')
            .delete()
            .eq('student_id', student.studentDbId!)
            .inFilter('type', ['pickup_skipped', 'pickup_notification'])
            .gte('created_at', startOfDay.toIso8601String())
            .lt('created_at', endOfDay.toIso8601String());

        // Delete driver notifications
        await Supabase.instance.client
            .from('notifications')
            .delete()
            .eq('recipient_id', user.id)
            .eq('student_id', student.studentDbId!)
            .inFilter('type', ['pickup_skipped', 'pickup_notification'])
            .gte('created_at', startOfDay.toIso8601String())
            .lt('created_at', endOfDay.toIso8601String());

        print('Deleted skip-related notifications for student ${student.studentDbId}');
      } catch (notificationError) {
        print('Error deleting notifications: $notificationError');
        // Continue even if notification deletion fails
      }

      // Log skip cancellation (HIGH PRIORITY - Transportation Safety & Compliance)
      try {
        await _driverAuditService.logPickupCancellation(
          studentId: student.studentDbId!.toString(),
          studentName: student.name,
          reason: 'Skip cancelled - restored to waiting',
          driverId: user.id,
          driverName: user.userMetadata?['fname'] ?? 'Driver',
          notes: 'Driver cancelled skip operation - skip record and notifications deleted, student restored to pickup queue',
        );
      } catch (auditError) {
        print('Error logging skip cancellation: $auditError');
      }

      _showConfirmationDialog(
        '✓ ${student.name} skip cancelled - Record and notifications removed',
        Colors.blue,
      );
    } catch (e) {
      _showConfirmationDialog('Error: $e', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Skip pickup (for students not yet picked up - doesn't require existing pickup record)
  Future<void> _skipPickup(Student student, String reason) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'User not authenticated';
      
      // Check if student is also scheduled for driver dropoff
      final isScheduledForDropoff = afternoonDropoffStudents.any(
        (studentData) => studentData['students']['id'].toString() == student.id
      );

      // Create a skip record using direct database insertion
      bool success = false;
      try {
        // Insert skip record directly into pickup_dropoff_logs
        await Supabase.instance.client.from('pickup_dropoff_logs').insert({
          'student_id': student.studentDbId!,
          'driver_id': user.id,
          'event_type': 'pickup_skipped', // Create our own skip event type
          'notes': 'Pickup skipped - Reason: $reason',
          'created_at': DateTime.now().toIso8601String(),
        });
        success = true;
      } catch (dbError) {
        print('Error creating skip record: $dbError');
        // Continue with local state update even if database insert fails
        success = true;
      }

      if (success) {
        // Update local state
        setState(() {
          // Add to skipped list if not already there
          if (!skippedPickupStudents.any((s) => s.id == student.id)) {
            skippedPickupStudents.add(student);
          }
        });

        // Send notification to parents (skip the verification request that's causing issues)
        // Instead, send a direct notification
        try {
          // Get student information
          final studentResponse = await Supabase.instance.client
              .from('students')
              .select('fname, mname, lname')
              .eq('id', student.studentDbId!)
              .single();

          final studentName = '${studentResponse['fname']} ${studentResponse['mname'] ?? ''} ${studentResponse['lname']}'.trim();

          // Get parent information
          final parentResponse = await Supabase.instance.client
              .from('parent_student')
              .select('''
                parents:parent_id(
                  id,
                  user_id,
                  fname,
                  lname
                )
              ''')
              .eq('student_id', student.studentDbId!);

          // Create notification for each parent
          final List<String> parentPhones = [];
          for (final parentData in parentResponse) {
            final parent = parentData['parents'];
            if (parent != null) {
              await Supabase.instance.client.from('notifications').insert({
                'recipient_id': parent['user_id'],
                'title': 'Pickup Skipped',
                'message': 'Your child $studentName\'s pickup has been skipped by the driver. Reason: $reason',
                'type': 'pickup_skipped',
                'is_read': false,
                'created_at': DateTime.now().toIso8601String(),
              });

              try {
                final phone = parent['phone']?.toString() ?? '';
                if (phone.isNotEmpty) parentPhones.add(phone);
              } catch (_) {}
            }
          }

          // Send SMS to parents (non-blocking)
          if (parentPhones.isNotEmpty) {
            _smsService.sendSms(
              recipients: parentPhones,
              message: 'Your child $studentName\'s pickup has been skipped by the driver. Reason: $reason',
            );
          }

          print('Parent notifications (and SMS enqueued) for skipped pickup');
        } catch (notificationError) {
          print('Error sending parent notifications: $notificationError');
          // Continue with skip operation even if notification fails
        }

        // Log pickup skip (HIGH PRIORITY - Transportation Safety & Compliance)
        try {
          await _driverAuditService.logPickupCancellation(
            studentId: student.studentDbId!.toString(),
            studentName: student.name,
            reason: reason,
            driverId: user.id,
            driverName: user.userMetadata?['fname'] ?? 'Driver',
            notes: 'Driver skipped scheduled pickup operation via app - no existing record',
          );
        } catch (auditError) {
          print('Error logging pickup skip: $auditError');
        }

        // If student was also scheduled for dropoff, cancel that too
        if (isScheduledForDropoff) {
          try {
            await _driverService.cancelDropoff(
              studentId: student.studentDbId!,
              driverId: user.id,
              reason: 'Pickup skipped - dropoff automatically cancelled',
              notes: 'Dropoff cancelled due to pickup being skipped',
            );
            
            // Log dropoff cancellation too
            await _driverAuditService.logDropoffCancellation(
              studentId: student.studentDbId!.toString(),
              studentName: student.name,
              reason: 'Pickup skipped - dropoff automatically cancelled',
              driverId: user.id,
              driverName: user.userMetadata?['fname'] ?? 'Driver',
              notes: 'Dropoff cancelled due to pickup being skipped',
            );
          } catch (dropoffError) {
            print('Error cancelling related dropoff: $dropoffError');
          }
        }

        final statusMessage = '✓ ${student.name} pickup skipped - Parents notified';
        final statusMessageWithDropoff = isScheduledForDropoff
            ? '$statusMessage\nDropoff also cancelled.'
            : statusMessage;

        _showConfirmationDialog(
          statusMessageWithDropoff,
          Colors.orange,
        );
      } else {
        _showConfirmationDialog(
          'Error skipping pickup for ${student.name}',
          Colors.red,
        );
      }
    } catch (e) {
      _showConfirmationDialog('Error: $e', Colors.red);
    } finally {
      setState(() => _isProcessing = false);
    }
  }

  /// Cancel pickup with reason (for picked up students - requires existing pickup record)
  Future<void> _cancelPickup(Student student, String reason) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'User not authenticated';
      
      // Check if student is also scheduled for driver dropoff
      final isScheduledForDropoff = afternoonDropoffStudents.any(
        (studentData) => studentData['students']['id'].toString() == student.id
      );

      // Cancel the existing pickup record (this function should only be called for picked up students)
      final success = await _driverService.cancelPickup(
        studentId: student.studentDbId!,
        driverId: user.id,
        reason: reason,
        notes: 'Pickup cancelled via driver app - existing record cancelled',
      );

      if (success) {
        setState(() {
          // Remove from picked up list
          pickedUpStudents.removeWhere((s) => s.id == student.id);
          
          // Also remove from dropped off list if they were dropped off
          if (droppedOffStudents.any((s) => s.id == student.id)) {
            droppedOffStudents.removeWhere((s) => s.id == student.id);
          }
          
          // Add to skipped list if not already there
          if (!skippedPickupStudents.any((s) => s.id == student.id)) {
            skippedPickupStudents.add(student);
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
            notes: 'Driver cancelled completed pickup operation via app',
          );
        } catch (auditError) {
          print('Error logging pickup cancellation: $auditError');
        }

        // If student was also scheduled for dropoff, cancel that too
        if (isScheduledForDropoff) {
          try {
            await _driverService.cancelDropoff(
              studentId: student.studentDbId!,
              driverId: user.id,
              reason: 'Pickup cancelled - dropoff automatically cancelled',
              notes: 'Dropoff cancelled due to pickup cancellation',
            );
            
            // Log dropoff cancellation too
            await _driverAuditService.logDropoffCancellation(
              studentId: student.studentDbId!.toString(),
              studentName: student.name,
              reason: 'Pickup cancelled - dropoff automatically cancelled',
              driverId: user.id,
              driverName: user.userMetadata?['fname'] ?? 'Driver',
              notes: 'Dropoff cancelled due to pickup cancellation',
            );
          } catch (dropoffError) {
            print('Error cancelling related dropoff: $dropoffError');
          }
        }

        final statusMessage = '✓ ${student.name} pickup cancelled - Parents notified';
        final statusMessageWithDropoff = isScheduledForDropoff
            ? '$statusMessage\nDropoff also cancelled.'
            : statusMessage;

        _showConfirmationDialog(
          statusMessageWithDropoff,
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

  /// Cancel accidental pickup (removes notification and undoes pickup)
  Future<void> _cancelAccidentalPickup(Student student) async {
    if (_isProcessing) return;

    setState(() => _isProcessing = true);

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw 'User not authenticated';

      // Remove from picked up list immediately
      setState(() {
        pickedUpStudents.removeWhere((s) => s.id == student.id);
        // Also remove from dropped off if they were dropped off
        if (droppedOffStudents.any((s) => s.id == student.id)) {
          droppedOffStudents.removeWhere((s) => s.id == student.id);
        }
        // Also remove from skipped list if they were there
        if (skippedPickupStudents.any((s) => s.id == student.id)) {
          skippedPickupStudents.removeWhere((s) => s.id == student.id);
        }
      });

      // Delete the pickup record from database (same as cancel skip)
      try {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

        // Find pickup records to delete
        final existingRecords = await Supabase.instance.client
            .from('pickup_dropoff_logs')
            .select('id, created_at, event_type')
            .eq('student_id', student.studentDbId!)
            .eq('driver_id', user.id)
            .eq('event_type', 'pickup')
            .gte('created_at', startOfDay.toIso8601String())
            .lt('created_at', endOfDay.toIso8601String());

        print('Found ${existingRecords.length} pickup records to delete: $existingRecords');

        if (existingRecords.isNotEmpty) {
          final recordIds = existingRecords.map((record) => record['id']).toList();
          
          print('Attempting to delete pickup records with IDs: $recordIds');
          
          final deleteResponse = await Supabase.instance.client
              .from('pickup_dropoff_logs')
              .delete()
              .inFilter('id', recordIds);

          print('Delete response: $deleteResponse');
          
          // Verify deletion
          final verificationRecords = await Supabase.instance.client
              .from('pickup_dropoff_logs')
              .select('id')
              .inFilter('id', recordIds);
              
          if (verificationRecords.isEmpty) {
            print('✓ Successfully deleted ${recordIds.length} pickup records for student ${student.studentDbId}');
          } else {
            print('⚠️ Delete command executed but ${verificationRecords.length} pickup records still exist');
            throw 'Pickup records still exist after delete operation - possible RLS policy issue';
          }
        }
      } catch (dbError) {
        print('Error deleting pickup record: $dbError');
        _showConfirmationDialog('Database Error: $dbError', Colors.red);
        return;
      }

      // Delete notifications for both parents and driver
      try {
        final today = DateTime.now();
        final startOfDay = DateTime(today.year, today.month, today.day);
        final endOfDay = DateTime(today.year, today.month, today.day, 23, 59, 59);

        // Delete parent notifications related to this pickup
        await Supabase.instance.client
            .from('notifications')
            .delete()
            .eq('student_id', student.studentDbId!)
            .inFilter('type', ['pickup_notification', 'verification_request'])
            .gte('created_at', startOfDay.toIso8601String())
            .lt('created_at', endOfDay.toIso8601String());

        // Delete driver notifications
        await Supabase.instance.client
            .from('notifications')
            .delete()
            .eq('recipient_id', user.id)
            .eq('student_id', student.studentDbId!)
            .inFilter('type', ['pickup_completed', 'pickup_notification'])
            .gte('created_at', startOfDay.toIso8601String())
            .lt('created_at', endOfDay.toIso8601String());

        print('Deleted pickup-related notifications for student ${student.studentDbId}');
      } catch (notificationError) {
        print('Error deleting notifications: $notificationError');
        // Continue even if notification deletion fails
      }



      // Log accidental pickup cancellation (HIGH PRIORITY - Transportation Safety & Compliance)
      try {
        await _driverAuditService.logPickupCancellation(
          studentId: student.studentDbId!.toString(),
          studentName: student.name,
          reason: 'Accidental pickup - driver error',
          driverId: user.id,
          driverName: user.userMetadata?['fname'] ?? 'Driver',
          notes: 'Driver accidentally marked wrong student - pickup record and notifications deleted',
        );
      } catch (auditError) {
        print('Error logging accidental pickup cancellation: $auditError');
      }

      _showConfirmationDialog(
        '✓ ${student.name} pickup cancelled - Record and notifications removed',
        Colors.blue,
      );
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
              Icons.arrow_upward,
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
              Icons.arrow_downward,
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
    final isPickupSkipped = _isStudentPickupSkipped(student);
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
    } else if (isPickupSkipped) {
      statusColor = Colors.orange;
      statusIcon = Icons.event_busy;
      statusText = 'Skipped';
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
                      backgroundImage: _getStudentProfileImage(studentData),
                      child: _getStudentProfileImage(studentData) == null
                          ? Text(
                              student.name.split(' ').map((n) => n[0]).take(2).join(),
                              style: TextStyle(
                                color: statusColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            )
                          : null,
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
                      // Morning Pickup Buttons
                      if (isMorningPickup) ...[
                        if (!isPickedUp && !isDroppedOff && !isPickupSkipped) ...[
                          // Skip Pickup with Reason button (before pickup)
                          Expanded(
                            child: OutlinedButton.icon(
                              onPressed: () => _showSkipPickupConfirmation(student),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.orange,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                side: BorderSide(color: Colors.orange.withOpacity(0.4), width: 1.5),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              icon: Icon(Icons.event_busy, size: 16),
                              label: Text(
                                'Skip Pickup',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Mark as Picked Up button
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              onPressed: () => _showPickupConfirmation(student),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: widget.primaryColor,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                              icon: Icon(Icons.directions_car, size: 18),
                              label: Text(
                                'Mark as Picked Up',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ] else if (isPickedUp && !isDroppedOff) ...[
                          // Only Cancel Pickup (accidental) button after pickup
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showAccidentalPickupCancellation(student),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                              icon: Icon(Icons.undo, size: 16),
                              label: Text(
                                'Cancel Pickup',
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ] else if (isPickupSkipped) ...[
                          // Cancel Skip button for skipped pickup
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: () => _showCancelSkipConfirmation(student),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.blue,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 12),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                              ),
                              icon: Icon(Icons.undo, size: 16),
                              label: Text(
                                'Cancel Skip',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                        ],
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
        return Dialog(
          insetPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 20),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: SingleChildScrollView(
              child: Padding(
                padding: const EdgeInsets.all(18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 28,
                          backgroundColor: widget.primaryColor.withOpacity(0.9),
                          backgroundImage: _getStudentProfileImage(null),
                          child: _getStudentProfileImage(null) == null
                              ? Text(
                                  student.name.split(' ').map((n) => n[0]).take(2).join(),
                                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                                )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                student.name,
                                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${student.grade}${student.sectionName != null ? ' • ${student.sectionName}' : ''}',
                                style: TextStyle(color: Colors.grey[700]),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          onPressed: () => Navigator.of(context).pop(),
                          icon: Icon(Icons.close, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FutureBuilder<Map<String, dynamic>>(
                      future: _getStudentDetails(student),
                      builder: (context, snapshot) {
                        if (snapshot.connectionState == ConnectionState.waiting) {
                          return const Center(child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: CircularProgressIndicator(),
                          ));
                        }

                        final studentDetails = snapshot.data ?? {};
                        final parents = studentDetails['parents'] as List<dynamic>? ?? [];

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Student ID', student.id),
                            _buildInfoRow('Grade', student.grade),
                            if (student.sectionName != null) _buildInfoRow('Section', student.sectionName!),
                            const SizedBox(height: 8),
                            if (parents.isNotEmpty) ...[
                              const Divider(),
                              const SizedBox(height: 8),
                              Text('Parent / Guardian', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: widget.primaryColor)),
                              const SizedBox(height: 8),
                              ...parents.map((parent) => Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildInfoRow('Name', '${parent['fname']} ${parent['lname']}'),
                                  _buildInfoRow('Phone', parent['phone'] ?? 'N/A'),
                                  _buildInfoRow('Email', parent['email'] ?? 'N/A'),
                                  const SizedBox(height: 8),
                                ],
                              )).toList(),
                            ],
                            if (_isStudentPickedUp(student) || _isStudentDroppedOff(student)) ...[
                              const Divider(),
                              const SizedBox(height: 8),
                            ],
                            if (_isStudentPickedUp(student)) _buildInfoRow('Pickup Time', DateFormat('h:mm a').format(pickedUpStudents.firstWhere((s) => s.id == student.id).pickupTime!)),
                            if (_isStudentPickedUp(student)) _buildInfoRow('Driver', Supabase.instance.client.auth.currentUser?.userMetadata?['fname'] ?? 'Driver'),
                            if (_isStudentDroppedOff(student)) _buildInfoRow('Dropoff Time', DateFormat('h:mm a').format(DateTime.now())),
                            if (_isStudentDroppedOff(student)) _buildInfoRow('Status', 'Completed'),
                            const SizedBox(height: 14),
                            Row(
                              children: [
                                Expanded(
                                  child: ElevatedButton(
                                    onPressed: () => Navigator.of(context).pop(),
                                    child: const Text('Close', style: TextStyle(fontWeight: FontWeight.w600)),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: widget.primaryColor,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 12),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                  ],
                ),
              ),
            ),
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

  // Helper method to get student profile image
  NetworkImage? _getStudentProfileImage(Map<String, dynamic>? studentData) {
    if (studentData == null) return null;
    final student = studentData['students'];
    final profileImageUrl = student?['profile_image_url'];
    if (profileImageUrl != null && profileImageUrl.toString().isNotEmpty) {
      return NetworkImage(profileImageUrl.toString());
    }
    return null;
  }
}
