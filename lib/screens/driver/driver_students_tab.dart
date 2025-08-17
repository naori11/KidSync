import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  List<Map<String, dynamic>> todayStudents = [];
  List<Map<String, dynamic>> pickupStudents = [];
  List<Map<String, dynamic>> dropoffStudents = [];
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
      final today = DateTime.now();
      final dayOfWeek = today.weekday; // 1 = Monday, 7 = Sunday
      final todayDate = DateFormat('yyyy-MM-dd').format(today);

      print(
        'Loading students for driver: $currentUserId, day: $dayOfWeek, date: $todayDate',
      );

      // Get students assigned to this driver
      final assignedStudentsResponse = await supabase
          .from('driver_assignments')
          .select('''
            student_id,
            pickup_time,
            dropoff_time,
            schedule_days,
            students!inner(
              id,
              fname,
              lname,
              grade_level,
              address,
              sections(name, grade_level)
            )
          ''')
          .eq('driver_id', currentUserId)
          .eq('status', 'active');

      print('Found ${assignedStudentsResponse.length} assigned students');

      List<Map<String, dynamic>> allStudents = [];
      List<Map<String, dynamic>> todayPickupList = [];
      List<Map<String, dynamic>> todayDropoffList = [];

      for (var assignment in assignedStudentsResponse) {
        final student = assignment['students'];
        final studentId = student['id'];

        // Check if today is in the schedule days
        final scheduleDays = assignment['schedule_days'];
        bool isScheduledToday = false;

        if (scheduleDays != null) {
          List<String> days = [];
          if (scheduleDays is List) {
            days = scheduleDays.cast<String>();
          } else if (scheduleDays is String) {
            // Handle PostgreSQL array format
            String daysStr = scheduleDays.toString();
            if (daysStr.startsWith('{') && daysStr.endsWith('}')) {
              daysStr = daysStr.substring(1, daysStr.length - 1);
            }
            days =
                daysStr
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
          }

          // Check if today's day name is in the schedule
          final dayNames = [
            'Monday',
            'Tuesday',
            'Wednesday',
            'Thursday',
            'Friday',
            'Saturday',
            'Sunday',
          ];
          final todayName = dayNames[dayOfWeek - 1];
          isScheduledToday = days.contains(todayName);
        }

        if (!isScheduledToday) continue; // Skip if not scheduled today

        // Check for exceptions for today
        final exceptionResponse = await supabase
            .from('pickup_dropoff_exceptions')
            .select('pickup_person, dropoff_person, reason')
            .eq('student_id', studentId)
            .eq('exception_date', todayDate);

        // Check pattern for today
        final patternResponse = await supabase
            .from('pickup_dropoff_patterns')
            .select('pickup_person, dropoff_person')
            .eq('student_id', studentId)
            .eq('day_of_week', dayOfWeek);

        String pickupPerson = 'driver'; // default
        String dropoffPerson = 'driver'; // default
        String? exceptionReason;

        // Use exception if exists, otherwise use pattern, otherwise default
        if (exceptionResponse.isNotEmpty) {
          final exception = exceptionResponse.first;
          pickupPerson = exception['pickup_person'] ?? 'driver';
          dropoffPerson = exception['dropoff_person'] ?? 'driver';
          exceptionReason = exception['reason'];
        } else if (patternResponse.isNotEmpty) {
          final pattern = patternResponse.first;
          pickupPerson = pattern['pickup_person'] ?? 'driver';
          dropoffPerson = pattern['dropoff_person'] ?? 'driver';
        }

        final studentData = {
          ...assignment,
          'pickup_person': pickupPerson,
          'dropoff_person': dropoffPerson,
          'exception_reason': exceptionReason,
          'full_name': '${student['fname']} ${student['lname']}',
        };

        allStudents.add(studentData);

        // Add to pickup list if driver should pick up
        if (pickupPerson == 'driver') {
          todayPickupList.add({...studentData, 'task_type': 'pickup'});
        }

        // Add to dropoff list if driver should drop off
        if (dropoffPerson == 'driver') {
          todayDropoffList.add({...studentData, 'task_type': 'dropoff'});
        }
      }

      // Sort by time
      todayPickupList.sort(
        (a, b) => (a['pickup_time'] ?? '').compareTo(b['pickup_time'] ?? ''),
      );
      todayDropoffList.sort(
        (a, b) => (a['dropoff_time'] ?? '').compareTo(b['dropoff_time'] ?? ''),
      );

      setState(() {
        todayStudents = allStudents;
        pickupStudents = todayPickupList;
        dropoffStudents = todayDropoffList;
        isLoading = false;
      });

      print('Loaded ${allStudents.length} students for today');
      print('Pickup tasks: ${todayPickupList.length}');
      print('Dropoff tasks: ${todayDropoffList.length}');
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
            elevation: 6,
            shadowColor: widget.primaryColor.withOpacity(0.2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
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
                  'Pickup Tasks',
                  pickupStudents.length.toString(),
                  Icons.upload,
                  Colors.blue,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Dropoff Tasks',
                  dropoffStudents.length.toString(),
                  Icons.download,
                  Colors.green,
                ),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Today's Tasks Summary
          if (pickupStudents.isNotEmpty || dropoffStudents.isNotEmpty) ...[
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

        // Pickup Tasks
        if (pickupStudents.isNotEmpty) ...[
          _buildTaskTypeSection(
            'Morning Pickup',
            pickupStudents,
            Colors.blue,
            Icons.upload,
          ),
          const SizedBox(height: 16),
        ],

        // Dropoff Tasks
        if (dropoffStudents.isNotEmpty) ...[
          _buildTaskTypeSection(
            'Afternoon Dropoff',
            dropoffStudents,
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
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        padding: const EdgeInsets.all(16),
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
    final isPickup = task['task_type'] == 'pickup';
    final time = isPickup ? task['pickup_time'] : task['dropoff_time'];
    final hasException = task['exception_reason'] != null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: hasException ? Colors.orange : color.withOpacity(0.2),
          width: hasException ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withOpacity(0.1),
            radius: 20,
            child: Text(
              '${student['fname'][0]}${student['lname'][0]}',
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['full_name'],
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '${student['grade_level']} • ${student['address'] ?? 'No address'}',
                  style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                ),
                if (hasException) ...[
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Icon(Icons.warning, size: 14, color: Colors.orange),
                      const SizedBox(width: 4),
                      Expanded(
                        child: Text(
                          'Exception: ${task['exception_reason']}',
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                time ?? 'No time',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
              Text(
                isPickup ? 'Pickup' : 'Dropoff',
                style: TextStyle(fontSize: 12, color: Colors.grey[600]),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // Keep your existing helper methods
  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Card(
      elevation: 6,
      shadowColor: color.withOpacity(0.2),
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
      elevation: 3,
      shadowColor: widget.primaryColor.withOpacity(0.1),
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