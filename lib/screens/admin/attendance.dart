import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AttendancePage extends StatefulWidget {
  const AttendancePage({Key? key}) : super(key: key);

  @override
  State<AttendancePage> createState() => _AttendancePageState();
}

class _AttendancePageState extends State<AttendancePage> {
  final supabase = Supabase.instance.client;
  DateTime _currentMonth = DateTime.now();
  String _selectedStudentId = '';
  Map<String, dynamic>? _selectedStudent;
  bool isLoading = false;
  Map<DateTime, Map<String, dynamic>> _attendanceData = {};
  bool _showCalendarView = false;
  String _selectedGrade = 'Kindergarten';

  // Mock data for demonstration
  final List<Map<String, dynamic>> _students = [
    {
      'id': '1',
      'first_name': 'Alice',
      'last_name': 'Johnson',
      'grade': 'Kindergarten',
      'section': 'K-A',
      'status': 'present',
      'last_scan': '8:15 AM',
      'attendance_rate': '95%',
    },
    {
      'id': '2',
      'first_name': 'Bob',
      'last_name': 'Smith',
      'grade': 'Kindergarten',
      'section': 'K-A',
      'status': 'present',
      'last_scan': '8:15 AM',
      'attendance_rate': '93%',
    },
    {
      'id': '3',
      'first_name': 'Carol',
      'last_name': 'Williams',
      'grade': 'Kindergarten',
      'section': 'K-A',
      'status': 'absent',
      'last_scan': 'Absent',
      'attendance_rate': '95%',
    },
  ];

  @override
  void initState() {
    super.initState();
    if (_students.isNotEmpty) {
      _selectedStudentId = _students[0]['id'];
      _selectedStudent = _students[0];
      _fetchAttendanceData();
    }
  }

  void _previousMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month - 1, 1);
      _fetchAttendanceData();
    });
  }

  void _nextMonth() {
    setState(() {
      _currentMonth = DateTime(_currentMonth.year, _currentMonth.month + 1, 1);
      _fetchAttendanceData();
    });
  }

  void _onViewDetails(Map<String, dynamic> student) {
    setState(() {
      _selectedStudent = student;
      _selectedStudentId = student['id'];
      _showCalendarView = true;
      _fetchAttendanceData();
    });
  }

  void _onGradeSelected(String grade) {
    setState(() {
      _selectedGrade = grade;
    });
  }

  Future<void> _fetchAttendanceData() async {
    setState(() => isLoading = true);

    // In a real app, fetch from Supabase
    // For now, generate mock data
    final Map<DateTime, Map<String, dynamic>> mockData = {};

    // Get the number of days in the current month
    final daysInMonth = DateUtils.getDaysInMonth(
      _currentMonth.year,
      _currentMonth.month,
    );

    // Generate random attendance data for the month
    for (int i = 1; i <= daysInMonth; i++) {
      final date = DateTime(_currentMonth.year, _currentMonth.month, i);

      // Skip weekends
      if (date.weekday == DateTime.saturday ||
          date.weekday == DateTime.sunday) {
        continue;
      }

      // Random attendance (80% chance of being present)
      final bool isPresent =
          i % 7 != 0 && i % 6 != 0; // Skip every 6th and 7th day

      if (isPresent) {
        mockData[date] = {
          'status': 'present',
          'drop_time': '8:30 AM',
          'pick_time': '3:30 PM',
        };
      } else {
        mockData[date] = {
          'status': 'absent',
          'drop_time': null,
          'pick_time': null,
        };
      }
    }

    // Special case for the 28th day (marked as absent in the image)
    final specialDate = DateTime(_currentMonth.year, _currentMonth.month, 28);
    if (mockData.containsKey(specialDate)) {
      mockData[specialDate] = {
        'status': 'absent',
        'drop_time': null,
        'pick_time': null,
      };
    }

    setState(() {
      _attendanceData = mockData;
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F5),
      body: _showCalendarView ? _buildCalendarView() : _buildStudentListView(),
    );
  }

  Widget _buildStudentListView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grade Filter Tabs
          _buildGradeFilterTabs(),

          const SizedBox(height: 24),

          // Student List Header Row with Search
          _buildStudentListHeader(),

          const SizedBox(height: 16),

          // Student List
          Expanded(child: _buildStudentList()),
        ],
      ),
    );
  }

  Widget _buildGradeFilterTabs() {
    return Row(
      children: [
        _buildGradeTab('Kindergarten'),
        const SizedBox(width: 16),
        _buildGradeTab('Preschool'),
        const SizedBox(width: 16),
        _buildGradeTab('Grade 1-6', hasDropdown: true),
      ],
    );
  }

  Widget _buildGradeTab(String grade, {bool hasDropdown = false}) {
    final bool isSelected = _selectedGrade == grade;

    return InkWell(
      onTap: () => _onGradeSelected(grade),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2ECC71) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: isSelected ? null : Border.all(color: Colors.grey.shade300),
        ),
        child: Row(
          children: [
            Text(
              grade,
              style: TextStyle(
                fontSize: 14,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                color: isSelected ? Colors.white : Colors.black87,
              ),
            ),
            if (hasDropdown) ...[
              const SizedBox(width: 4),
              Icon(
                Icons.arrow_drop_down,
                size: 20,
                color: isSelected ? Colors.white : Colors.black54,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildStudentListHeader() {
    return Row(
      children: [
        const Text(
          'Student',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        const Spacer(),
        // Search box
        Container(
          width: 300,
          height: 40,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(Icons.search, color: Colors.grey.shade600, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Search student',
                    hintStyle: TextStyle(color: Colors.grey.shade400),
                    border: InputBorder.none,
                    contentPadding: const EdgeInsets.only(bottom: 10),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        // Date filter dropdown
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.grey.shade300),
          ),
          child: Row(
            children: [
              Icon(Icons.calendar_today, size: 16, color: Colors.grey.shade700),
              const SizedBox(width: 8),
              Text(
                'This Week',
                style: TextStyle(fontSize: 14, color: Colors.grey.shade700),
              ),
              const SizedBox(width: 4),
              Icon(Icons.arrow_drop_down, color: Colors.grey.shade700),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildStudentList() {
    return ListView.builder(
      itemCount: _students.length,
      itemBuilder: (context, index) {
        final student = _students[index];
        final bool isPresent = student['status'] == 'present';

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(8),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 5,
                spreadRadius: 1,
              ),
            ],
          ),
          child: Row(
            children: [
              // Student avatar and info
              CircleAvatar(
                radius: 20,
                backgroundColor: Colors.grey.shade200,
                child: Text(
                  student['first_name'][0],
                  style: TextStyle(
                    color: Colors.grey.shade700,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${student['first_name']} ${student['last_name']}',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${student['grade']} • ${student['section']}',
                      style: TextStyle(
                        fontSize: 14,
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ],
                ),
              ),

              // Status
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      isPresent
                          ? const Color(0xFFE8F5E9)
                          : const Color(0xFFFEE8E7),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Text(
                  isPresent ? 'Present' : 'Absent',
                  style: TextStyle(
                    color: isPresent ? const Color(0xFF2ECC71) : Colors.red,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),

              const SizedBox(width: 24),

              // Last scan and attendance info
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Last Scan: ${student['last_scan']}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Attendance: ${student['attendance_rate']}',
                    style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                  ),
                ],
              ),

              const SizedBox(width: 24),

              // View Details button
              TextButton.icon(
                onPressed: () => _onViewDetails(student),
                icon: const Icon(Icons.arrow_forward, size: 16),
                label: const Text('View Details'),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF2ECC71),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCalendarView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row with student name and controls
          _buildHeader(),

          const SizedBox(height: 24),

          // Calendar
          Expanded(
            child:
                isLoading
                    ? const Center(
                      child: CircularProgressIndicator(
                        color: Color(0xFF2ECC71),
                      ),
                    )
                    : _buildCalendar(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final studentName =
        _selectedStudent != null
            ? "${_selectedStudent!['first_name']} ${_selectedStudent!['last_name']}"
            : "Select a student";

    final studentGrade =
        _selectedStudent != null
            ? "${_selectedStudent!['grade']} • ${_selectedStudent!['section']}"
            : "";

    final monthYearFormat = DateFormat('MMMM yyyy');

    return Row(
      children: [
        // Back button
        IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => setState(() => _showCalendarView = false),
        ),

        // Student info
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  studentName,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  studentGrade,
                  style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
        ),

        // Export button
        TextButton.icon(
          icon: const Icon(Icons.file_download_outlined, size: 18),
          label: const Text("Export"),
          onPressed: () {
            // Export functionality would go here
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Export functionality would be implemented here'),
              ),
            );
          },
          style: TextButton.styleFrom(foregroundColor: Colors.black87),
        ),

        const SizedBox(width: 16),

        // Month navigation
        IconButton(
          icon: const Icon(Icons.chevron_left),
          onPressed: _previousMonth,
        ),

        SizedBox(
          width: 140,
          child: Text(
            monthYearFormat.format(_currentMonth),
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ),

        IconButton(
          icon: const Icon(Icons.chevron_right),
          onPressed: _nextMonth,
        ),
      ],
    );
  }

  Widget _buildCalendar() {
    // Calculate the first day of the month
    final firstDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      1,
    );

    // Calculate the start day of the calendar (Sunday before or on the first day)
    final startDay = firstDayOfMonth.subtract(
      Duration(days: firstDayOfMonth.weekday % 7),
    );

    // Calculate days in month to determine end date
    final daysInMonth = DateUtils.getDaysInMonth(
      _currentMonth.year,
      _currentMonth.month,
    );
    final lastDayOfMonth = DateTime(
      _currentMonth.year,
      _currentMonth.month,
      daysInMonth,
    );

    // Calculate the end day of the calendar (Saturday after or on the last day)
    final endDay = lastDayOfMonth.add(
      Duration(days: (6 - lastDayOfMonth.weekday) % 7),
    );

    // Calculate the number of weeks
    final numWeeks = ((endDay.difference(startDay).inDays + 1) / 7).ceil();

    return Column(
      children: [
        // Day of week header
        Row(
          children: const [
            Expanded(child: _DayOfWeekHeader('Sun')),
            Expanded(child: _DayOfWeekHeader('Mon')),
            Expanded(child: _DayOfWeekHeader('Tue')),
            Expanded(child: _DayOfWeekHeader('Wed')),
            Expanded(child: _DayOfWeekHeader('Thu')),
            Expanded(child: _DayOfWeekHeader('Fri')),
            Expanded(child: _DayOfWeekHeader('Sat')),
          ],
        ),
        const SizedBox(height: 8),

        // Calendar grid
        Expanded(
          child: GridView.builder(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 1.0,
              crossAxisSpacing: 4.0,
              mainAxisSpacing: 4.0,
            ),
            itemCount: numWeeks * 7,
            itemBuilder: (context, index) {
              final day = startDay.add(Duration(days: index));
              final isCurrentMonth = day.month == _currentMonth.month;

              // Get attendance data for this day
              final attendanceInfo =
                  _attendanceData[DateTime(day.year, day.month, day.day)];
              final bool isPresent =
                  attendanceInfo != null &&
                  attendanceInfo['status'] == 'present';

              return _buildDayCell(
                day: day,
                isCurrentMonth: isCurrentMonth,
                isPresent: isPresent,
                dropTime: attendanceInfo?['drop_time'],
                pickTime: attendanceInfo?['pick_time'],
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildDayCell({
    required DateTime day,
    required bool isCurrentMonth,
    bool isPresent = false,
    String? dropTime,
    String? pickTime,
  }) {
    final now = DateTime.now();
    final isToday =
        day.year == now.year && day.month == now.month && day.day == now.day;
    final isWeekend =
        day.weekday == DateTime.saturday || day.weekday == DateTime.sunday;

    // Use light gray background for days not in current month
    final backgroundColor =
        !isCurrentMonth
            ? Colors.grey[100]
            : isWeekend
            ? const Color(0xFFF9F9F9)
            : Colors.white;

    // Border
    final border =
        isToday
            ? Border.all(color: const Color(0xFF2ECC71), width: 2)
            : Border.all(color: Colors.grey[300]!, width: 1);

    // Text color
    final dayTextColor =
        !isCurrentMonth
            ? Colors.grey[400]
            : isWeekend
            ? Colors.grey[600]
            : Colors.black87;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        border: border,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Column(
        children: [
          // Day number
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 4),
            decoration: BoxDecoration(
              color:
                  !isCurrentMonth
                      ? Colors.grey[100]
                      : isPresent
                      ? const Color(0xFFE8F5E9)
                      : Colors.transparent,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(3),
              ),
            ),
            child: Text(
              day.day.toString(),
              style: TextStyle(
                color: dayTextColor,
                fontWeight: isToday ? FontWeight.bold : FontWeight.normal,
              ),
              textAlign: TextAlign.center,
            ),
          ),

          // Status indicator
          if (isCurrentMonth && !isWeekend)
            Expanded(
              child: Center(
                child:
                    isPresent
                        ? Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Green dot for present
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Color(0xFF2ECC71),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(height: 4),
                            // Drop time
                            if (dropTime != null)
                              Text(
                                'Drop: $dropTime',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey[600],
                                ),
                              ),
                            // Pick time
                            if (pickTime != null)
                              Text(
                                'Pick: $pickTime',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: Colors.grey[600],
                                ),
                              ),
                          ],
                        )
                        : Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Red dot for absent
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.red,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ],
                        ),
              ),
            ),
        ],
      ),
    );
  }
}

class _DayOfWeekHeader extends StatelessWidget {
  final String title;

  const _DayOfWeekHeader(this.title);

  @override
  Widget build(BuildContext context) {
    final isWeekend = title == 'Sun' || title == 'Sat';
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        title,
        style: TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: isWeekend ? Colors.grey[600] : Colors.grey[800],
        ),
        textAlign: TextAlign.center,
      ),
    );
  }
}
