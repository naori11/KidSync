import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../services/driver_service.dart';

class DriverStudentsTab extends StatefulWidget {
  final Color primaryColor;
  final bool isMobile;

  const DriverStudentsTab({
    required this.primaryColor,
    required this.isMobile,
    Key? key,
  }) : super(key: key);

  @override
  State<DriverStudentsTab> createState() => _DriverStudentsTabState();
}

class _DriverStudentsTabState extends State<DriverStudentsTab> {
  final supabase = Supabase.instance.client;
  final DriverService _driverService = DriverService();
  List<Map<String, dynamic>> todayStudents = [];
  List<Map<String, dynamic>> morningPickupStudents = [];
  List<Map<String, dynamic>> afternoonDropoffStudents = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadTodayStudents();
  }

  Future<void> _loadTodayStudents() async {
    try {
      setState(() {
        isLoading = true;
        error = null;
      });

      final currentUser = supabase.auth.currentUser;
      if (currentUser == null) {
        throw Exception('User not logged in');
      }

      final currentUserId = currentUser.id;

      // Use the new service method
      final studentsData = await _driverService.getTodaysStudentsWithPatterns(
        currentUserId,
      );

      setState(() {
        todayStudents = studentsData['all_students'];
        morningPickupStudents = studentsData['morning_pickup'];
        afternoonDropoffStudents = studentsData['afternoon_dropoff'];
        isLoading = false;
      });

      print('Loaded ${todayStudents.length} students for today');
      print('Morning pickup tasks: ${morningPickupStudents.length}');
      print('Afternoon dropoff tasks: ${afternoonDropoffStudents.length}');
    } catch (e) {
      print('Error loading today\'s students: $e');
      setState(() {
        error = e.toString();
        isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error, size: 64, color: Colors.red),
            const SizedBox(height: 16),
            Text('Error loading students: $error'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadTodayStudents,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    // Group students by grade for display
    final studentsByGrade = <String, List<Map<String, dynamic>>>{};
    for (final student in todayStudents) {
      final grade = student['students']['grade_level'] ?? 'Unknown';
      studentsByGrade[grade] ??= [];
      studentsByGrade[grade]!.add(student);
    }

    final grades = studentsByGrade.keys.toList()..sort();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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
                    color: Colors.black.withOpacity(0.1),
                    blurRadius: 10,
                    spreadRadius: 2,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.group, color: widget.primaryColor, size: 28),
                      const SizedBox(width: 12),
                      Text(
                        'Today\'s Students',
                        style: const TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF000000),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Students assigned to you for ${DateFormat('EEEE, MMMM d, y').format(DateTime.now())}',
                    style: TextStyle(
                      fontSize: 16,
                      color: const Color(0xFF000000).withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Statistics
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Students',
                  todayStudents.length.toString(),
                  Icons.group,
                  widget.primaryColor,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Morning Pickup',
                  morningPickupStudents.length.toString(),
                  Icons.upload,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Afternoon Dropoff',
                  afternoonDropoffStudents.length.toString(),
                  Icons.download,
                  Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Today's Tasks Summary
          if (morningPickupStudents.isNotEmpty ||
              afternoonDropoffStudents.isNotEmpty) ...[
            _buildTasksSection(),
            const SizedBox(height: 24),
          ],

          // Students by Grade (if you want to keep this view)
          if (grades.isNotEmpty) ...[
            Text(
              'All Students by Grade',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: widget.primaryColor,
              ),
            ),
            const SizedBox(height: 16),
            ...grades.map(
              (grade) => _buildGradeSection(grade, studentsByGrade[grade]!),
            ),
          ] else ...[
            Center(
              child: Column(
                children: [
                  Icon(Icons.info, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    'No students assigned for today',
                    style: TextStyle(fontSize: 18, color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTasksSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Today\'s Tasks',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: widget.primaryColor,
          ),
        ),
        const SizedBox(height: 16),

        // Morning Pickup Tasks
        if (morningPickupStudents.isNotEmpty) ...[
          _buildTaskTypeSection(
            'Morning Pickup',
            morningPickupStudents,
            Colors.blue,
            Icons.upload,
          ),
          const SizedBox(height: 16),
        ],

        // Afternoon Dropoff Tasks
        if (afternoonDropoffStudents.isNotEmpty) ...[
          _buildTaskTypeSection(
            'Afternoon Dropoff',
            afternoonDropoffStudents,
            Colors.green,
            Icons.download,
          ),
        ],
      ],
    );
  }

  Widget _buildTaskTypeSection(
    String title,
    List<Map<String, dynamic>> tasks,
    Color color,
    IconData icon,
  ) {
    return Card(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: color, size: 20),
                const SizedBox(width: 8),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                const Spacer(),
                Chip(
                  label: Text('${tasks.length}'),
                  backgroundColor: color.withOpacity(0.1),
                  labelStyle: TextStyle(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            ...tasks.map((task) => _buildTaskItem(task, color)),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskItem(Map<String, dynamic> task, Color color) {
    final student = task['students'];
    final isMorningPickup = task['task_type'] == 'morning_pickup';
    final time = isMorningPickup ? task['pickup_time'] : task['dropoff_time'];
    final hasException = task['exception_reason'] != null;
    final isDriverResponsible =
        isMorningPickup
            ? task['dropoff_person'] == 'driver'
            : task['pickup_person'] == 'driver';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              hasException
                  ? Colors.orange
                  : isDriverResponsible
                  ? color.withOpacity(0.3)
                  : Colors.grey.withOpacity(0.3),
          width: hasException ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 12,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 16,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        children: [
          // Top Row: Student Info and Time
          Row(
            children: [
              // Student Avatar
              CircleAvatar(
                backgroundColor: color.withOpacity(0.1),
                radius: 24,
                child: Text(
                  '${student['fname'][0]}${student['lname'][0]}',
                  style: TextStyle(
                    color: color,
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
                      task['full_name'],
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
                      '${student['grade_level']}${student['sections']?['name'] != null ? ' • ${student['sections']['name']}' : ''}',
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),

              // Time Display
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  children: [
                    Text(
                      _formatTime(time),
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                    Text(
                      isMorningPickup ? 'Pickup' : 'Dropoff',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.grey[600],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Address Row
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  isMorningPickup ? Icons.home : Icons.school,
                  size: 16,
                  color: Colors.grey[600],
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    student['address'] ?? 'No address provided',
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.grey[700],
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),

          // Exception Information
          if (hasException) ...[
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
                      'Exception: ${task['exception_reason']}',
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

          // Driver Responsibility Indicator
          if (!isDriverResponsible) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: Colors.grey.withOpacity(0.1),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.person, size: 14, color: Colors.grey[600]),
                  const SizedBox(width: 6),
                  Text(
                    isMorningPickup ? 'Parent Pickup' : 'Parent Dropoff',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Helper method to format time
  String _formatTime(String? time) {
    if (time == null) return 'No time';

    try {
      // Parse time string (format: HH:mm:ss or HH:mm)
      final timeParts = time.split(':');
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

    return time;
  }

  // Keep your existing helper methods
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.15),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFF000000),
              ),
            ),
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                color: const Color(0xFF000000).withOpacity(0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGradeSection(String grade, List<Map<String, dynamic>> students) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
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
                child: Text(
                  grade,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '${students.length} student${students.length != 1 ? 's' : ''}',
                style: TextStyle(
                  fontSize: 16,
                  color: const Color(0xFF000000).withOpacity(0.7),
                ),
              ),
            ],
          ),
        ),
        ...students.map((student) => _buildStudentCard(student)),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildStudentCard(Map<String, dynamic> assignment) {
    final student = assignment['students'];
    final hasException = assignment['exception_reason'] != null;
    final pickupPerson = assignment['pickup_person'];
    final dropoffPerson = assignment['dropoff_person'];

    return Card(
      color: Colors.white,
      elevation: 8,
      shadowColor: Colors.black.withOpacity(0.2),
      margin: const EdgeInsets.only(bottom: 8),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            hasException
                ? BorderSide(color: Colors.orange, width: 2)
                : BorderSide.none,
      ),
      child: InkWell(
        onTap: () => _showStudentInfo(context, assignment),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: widget.primaryColor.withOpacity(0.1),
                radius: 24,
                child: Text(
                  '${student['fname'][0]}${student['lname'][0]}',
                  style: TextStyle(
                    color: widget.primaryColor,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      assignment['full_name'],
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF000000),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      student['grade_level'] ?? 'Unknown Grade',
                      style: TextStyle(
                        fontSize: 14,
                        color: const Color(0xFF000000).withOpacity(0.7),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        _buildPersonChip('Pickup', pickupPerson, Colors.blue),
                        const SizedBox(width: 8),
                        _buildPersonChip(
                          'Dropoff',
                          dropoffPerson,
                          Colors.green,
                        ),
                      ],
                    ),
                    if (hasException) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.warning, size: 14, color: Colors.orange),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              'Exception: ${assignment['exception_reason']}',
                              style: const TextStyle(
                                fontSize: 12,
                                color: Colors.orange,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                Icons.info_outline,
                color: widget.primaryColor.withOpacity(0.5),
                size: 20,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPersonChip(String label, String person, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color:
            person == 'driver'
                ? color.withOpacity(0.1)
                : Colors.grey.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: person == 'driver' ? color : Colors.grey,
          width: 1,
        ),
      ),
      child: Text(
        '$label: ${person == 'driver' ? 'You' : 'Parent'}',
        style: TextStyle(
          fontSize: 10,
          color: person == 'driver' ? color : Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  void _showStudentInfo(BuildContext context, Map<String, dynamic> assignment) {
    final student = assignment['students'];

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 8,
          title: Row(
            children: [
              Icon(Icons.person, color: widget.primaryColor, size: 24),
              const SizedBox(width: 8),
              Text(
                'Student Information',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black,
                ),
              ),
            ],
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildInfoRow('Name', assignment['full_name']),
                _buildInfoRow('Grade', student['grade_level'] ?? 'Unknown'),
                _buildInfoRow('Student ID', student['id'].toString()),
                _buildInfoRow('Address', student['address'] ?? 'No address'),

                const Divider(),

                // Today's Schedule
                Row(
                  children: [
                    Icon(Icons.schedule, color: widget.primaryColor, size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Today\'s Schedule',
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
                  assignment['pickup_time'] ?? 'Not set',
                ),
                _buildInfoRow(
                  'Dropoff Time',
                  assignment['dropoff_time'] ?? 'Not set',
                ),
                _buildInfoRow(
                  'Pickup Person',
                  assignment['pickup_person'] == 'driver'
                      ? 'You (Driver)'
                      : 'Parent',
                ),
                _buildInfoRow(
                  'Dropoff Person',
                  assignment['dropoff_person'] == 'driver'
                      ? 'You (Driver)'
                      : 'Parent',
                ),

                if (assignment['exception_reason'] != null) ...[
                  const Divider(),
                  Row(
                    children: [
                      Icon(Icons.warning, color: Colors.orange, size: 20),
                      const SizedBox(width: 8),
                      Text(
                        'Exception for Today',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.orange,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    assignment['exception_reason'],
                    style: const TextStyle(fontSize: 14),
                  ),
                ],
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              style: TextButton.styleFrom(foregroundColor: widget.primaryColor),
              child: const Text('Close', style: TextStyle(fontSize: 16)),
            ),
          ],
        );
      },
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
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
