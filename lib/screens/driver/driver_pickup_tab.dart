import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../models/driver_models.dart';
import '../../models/pickup_status.dart';
import '../../services/driver_service.dart';

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
  bool _isLoading = true;
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

  void _showPickupConfirmation(Student student) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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
                        foregroundColor: widget.primaryColor,
                        side: BorderSide(color: widget.primaryColor, width: 2),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      icon: Icon(
                        Icons.directions_car,
                        color: widget.primaryColor,
                      ),
                      label: Text(
                        'Confirm Drop-off',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: widget.primaryColor,
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

  void _showDropoffConfirmation(Student student) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
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

    try {
      final user = Supabase.instance.client.auth.currentUser!;
      final isCurrentlyPickedUp = pickedUpStudents.any(
        (s) => s.id == student.id,
      );

      if (isCurrentlyPickedUp) {
        // Remove student from picked up list (cancel pickup)
        setState(() {
          pickedUpStudents.removeWhere((s) => s.id == student.id);
          droppedOffStudents.removeWhere((s) => s.id == student.id);
        });

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

          // Pickup recorded successfully in database

          _showConfirmationDialog(
            '✓ ${student.name} marked as picked up - Parents notified',
            widget.primaryColor,
          );
        } else {
          _showConfirmationDialog(
            'Error recording pickup for ${student.name}',
            Colors.red,
          );
        }
      }
    } catch (e) {
      _showConfirmationDialog('Error: $e', Colors.red);
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

        _showConfirmationDialog(
          '${student.name} dropoff cancelled',
          Colors.orange,
        );
      } else {
        // Check if student was picked up first
        if (!pickedUpStudents.any((s) => s.id == student.id)) {
          _showConfirmationDialog(
            'Student must be picked up before dropoff',
            Colors.orange,
          );
          return;
        }

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

          _showConfirmationDialog(
            '✓ ${student.name} marked as dropped off - Parents notified',
            Colors.green,
          );
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

    final completedCount = pickedUpStudents.length;
    final totalCount = uniqueStudents.length;
    final progress = totalCount > 0 ? completedCount / totalCount : 0.0;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Card
          Card(
            elevation: 8,
            shadowColor: widget.primaryColor.withOpacity(0.3),
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
                          DateFormat('h:mm a').format(DateTime.now()),
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
                        '$completedCount / $totalCount',
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
          if (completedCount > 0) ...[
            Card(
              elevation: 4,
              shadowColor: widget.primaryColor.withOpacity(0.15),
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
                      'Students picked up: $completedCount',
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
                    if (completedCount == totalCount)
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
      elevation: isPickedUp || isDroppedOff ? 6 : 3,
      shadowColor:
          isPickedUp || isDroppedOff
              ? statusColor.withOpacity(0.2)
              : Colors.black.withOpacity(0.1),
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
                                        ? () => _confirmStudentPickup(student)
                                        : () =>
                                            _showPickupConfirmation(student))
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isPickedUp
                                      ? widget.primaryColor.withOpacity(0.7)
                                      : widget.primaryColor,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            icon: Icon(
                              isPickedUp ? Icons.check : Icons.directions_car,
                              size: 18,
                            ),
                            label: Text(
                              isPickedUp ? 'Picked Up' : 'Mark as Picked Up',
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
                                !isDroppedOff && isPickedUp
                                    ? () => _showDropoffConfirmation(student)
                                    : null,
                            style: ElevatedButton.styleFrom(
                              backgroundColor:
                                  isDroppedOff
                                      ? Colors.green.withOpacity(0.7)
                                      : Colors.green,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(vertical: 12),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            icon: Icon(
                              isDroppedOff ? Icons.check : Icons.home,
                              size: 18,
                            ),
                            label: Text(
                              isDroppedOff
                                  ? 'Dropped Off'
                                  : 'Mark as Dropped Off',
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
        return Center(
          child: Material(
            color: Colors.transparent,
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 40),
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.check,
                      color: Colors.white,
                      size: 32,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    message,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Colors.black87,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: color,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text('OK'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTaskCompletedDialog() {
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

  void _showStudentInfo(Student student) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return Center(
          child: AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            title: Row(
              children: [
                Icon(Icons.person, color: widget.primaryColor, size: 24),
                const SizedBox(width: 8),
                const Text(
                  'Student Information',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
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
                                fontSize: 16,
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
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }
}
