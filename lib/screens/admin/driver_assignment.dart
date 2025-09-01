import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math' as math;

class DriverAssignmentPage extends StatefulWidget {
  const DriverAssignmentPage({Key? key}) : super(key: key);

  @override
  State<DriverAssignmentPage> createState() => _DriverAssignmentPageState();
}

class _DriverAssignmentPageState extends State<DriverAssignmentPage> {
  final supabase = Supabase.instance.client;
  String _selectedView = 'assignments';
  String _searchQuery = '';
  String _selectedGradeFilter = 'All Grades';
  String _selectedDriverFilter = 'All Drivers';
  String _selectedStatusFilter = 'All Status';
  String _sortOption = 'Student Name (A-Z)';
  bool isLoading = false;

  // For pagination
  int _currentPage = 1;
  int _itemsPerPage = 10;
  int _totalPages = 1;

  // Data lists
  List<Map<String, dynamic>> assignments = [];
  List<Map<String, dynamic>> students = [];
  List<Map<String, dynamic>> drivers = [];

  // Stats
  int totalStudents = 0;
  int activeDrivers = 0;
  int unassignedStudents = 0;
  int pendingAssignments = 0;

  @override
  void initState() {
    super.initState();
    _loadAllData();
  }

  Future<void> _loadAllData() async {
    setState(() => isLoading = true);
    try {
      await Future.wait([
        _loadAssignments(),
        _loadStudents(),
        _loadDrivers(),
        _loadStats(),
      ]);
    } catch (e) {
      _showErrorSnackBar('Error loading data: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _loadAssignments() async {
    try {
      final response = await supabase
          .from('driver_assignments')
          .select('''
            *,
            students!inner(id, fname, mname, lname, grade_level, address, section_id,
              sections(name, grade_level)
            ),
            users!inner(id, fname, mname, lname, contact_number)
          ''')
          .order('created_at', ascending: false);

      setState(() {
        assignments = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading assignments: $e');
    }
  }

  Future<void> _loadStudents() async {
    try {
      print('Loading students...'); // Debug log

      // First, let's try a simpler query to see if students exist
      final simpleResponse = await supabase
          .from('students')
          .select('*')
          .eq('status', 'Active');

      print(
        'Simple student query result: ${simpleResponse.length} students found',
      ); // Debug log

      // Now try the complex query
      final response = await supabase
          .from('students')
          .select('''
          *,
          sections(name, grade_level),
          driver_assignments!driver_assignments_student_id_fkey(id, status, driver_id)
        ''')
          .eq('status', 'Active');

      print(
        'Complex student query result: ${response.length} students found',
      ); // Debug log
      print(
        'First student data: ${response.isNotEmpty ? response[0] : 'No data'}',
      ); // Debug log

      setState(() {
        students = List<Map<String, dynamic>>.from(response);
      });

      print('Students loaded successfully: ${students.length}'); // Debug log
    } catch (e) {
      print('Error loading students: $e');
      print('Error type: ${e.runtimeType}');

      // Fallback: try loading students without relationships
      try {
        print('Trying fallback query...');
        final fallbackResponse = await supabase
            .from('students')
            .select('*')
            .eq('status', 'Active');

        setState(() {
          students = List<Map<String, dynamic>>.from(
            fallbackResponse.map(
              (student) => {
                ...student,
                'sections': null,
                'driver_assignments': [],
              },
            ),
          );
        });

        print('Fallback successful: ${students.length} students loaded');
      } catch (fallbackError) {
        print('Fallback also failed: $fallbackError');
        setState(() {
          students = [];
        });
      }
    }
  }

  Future<void> _loadDrivers() async {
    try {
      final response = await supabase
          .from('users')
          .select('*')
          .eq('role', 'Driver');

      setState(() {
        drivers = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      print('Error loading drivers: $e');
    }
  }

  Future<void> _loadStats() async {
    try {
      print('Loading stats...'); // Debug log

      // Total students - use length of the response list
      final studentResponse = await supabase
          .from('students')
          .select('id')
          .eq('status', 'Active');

      print('Student count response: ${studentResponse.length}'); // Debug log

      // Active drivers
      final driverResponse = await supabase
          .from('users')
          .select('id')
          .eq('role', 'Driver');

      print('Driver count response: ${driverResponse.length}'); // Debug log

      // For unassigned students, let's use a different approach
      final allStudentsResponse = await supabase
          .from('students')
          .select('id')
          .eq('status', 'Active');

      final assignedStudentsResponse = await supabase
          .from('driver_assignments')
          .select('student_id')
          .eq('status', 'active');

      final assignedStudentIds =
          assignedStudentsResponse.map((a) => a['student_id']).toSet();
      final unassignedCount =
          allStudentsResponse
              .where((s) => !assignedStudentIds.contains(s['id']))
              .length;

      // Pending assignments
      final pendingResponse = await supabase
          .from('driver_assignments')
          .select('id')
          .eq('status', 'pending');

      setState(() {
        totalStudents = studentResponse.length;
        activeDrivers = driverResponse.length;
        unassignedStudents = unassignedCount;
        pendingAssignments = pendingResponse.length;
      });

      print(
        'Stats loaded - Students: $totalStudents, Drivers: $activeDrivers, Unassigned: $unassignedStudents, Pending: $pendingAssignments',
      );
    } catch (e) {
      print('Error loading stats: $e');
      // Set default values on error
      setState(() {
        totalStudents = 0;
        activeDrivers = 0;
        unassignedStudents = 0;
        pendingAssignments = 0;
      });
    }
  }

  Future<List<Map<String, dynamic>>> _getStudentSchedule(int sectionId) async {
    try {
      final response = await supabase
          .from('section_teachers')
          .select('''
          subject,
          days,
          start_time,
          end_time,
          users!section_teachers_teacher_id_fkey(fname, lname)
        ''')
          .eq('section_id', sectionId)
          .order('start_time', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      print('Error getting student schedule: $e');

      // Fallback: try without teacher relationship
      try {
        print('Trying fallback query without teacher relationship...');
        final fallbackResponse = await supabase
            .from('section_teachers')
            .select('''
            subject,
            days,
            start_time,
            end_time,
            teacher_id
          ''')
            .eq('section_id', sectionId)
            .order('start_time', ascending: true);

        // For each record, manually fetch teacher info
        List<Map<String, dynamic>> scheduleWithTeachers = [];

        for (var schedule in fallbackResponse) {
          Map<String, dynamic> scheduleItem = Map<String, dynamic>.from(
            schedule,
          );

          // Fetch teacher info separately
          if (schedule['teacher_id'] != null) {
            try {
              final teacherResponse =
                  await supabase
                      .from('users')
                      .select('fname, lname')
                      .eq('id', schedule['teacher_id'])
                      .eq('role', 'Teacher')
                      .single();

              scheduleItem['users'] = teacherResponse;
            } catch (teacherError) {
              print(
                'Error fetching teacher ${schedule['teacher_id']}: $teacherError',
              );
              scheduleItem['users'] = null;
            }
          } else {
            scheduleItem['users'] = null;
          }

          scheduleWithTeachers.add(scheduleItem);
        }

        return scheduleWithTeachers;
      } catch (fallbackError) {
        print('Fallback also failed: $fallbackError');
        return [];
      }
    }
  }

  Map<String, String> _calculatePickupDropoffTimes(
    List<Map<String, dynamic>> schedule,
  ) {
    if (schedule.isEmpty) {
      return {'pickup_time': '07:00', 'dropoff_time': '15:00'};
    }

    // Find earliest start time and latest end time across all subjects
    String? earliestStart;
    String? latestEnd;

    for (var subject in schedule) {
      final startTime = subject['start_time'] as String?;
      final endTime = subject['end_time'] as String?;

      if (startTime != null) {
        if (earliestStart == null || startTime.compareTo(earliestStart) < 0) {
          earliestStart = startTime;
        }
      }

      if (endTime != null) {
        if (latestEnd == null || endTime.compareTo(latestEnd) > 0) {
          latestEnd = endTime;
        }
      }
    }

    // Calculate pickup time (30 minutes before earliest class)
    String pickupTime = '07:00';
    if (earliestStart != null) {
      final parts = earliestStart.split(':');
      if (parts.length >= 2) {
        try {
          final hours = int.parse(parts[0]);
          final minutes = int.parse(parts[1]);
          final totalMinutes = hours * 60 + minutes - 30; // 30 minutes earlier

          // Ensure pickup time doesn't go before 6:00 AM
          final adjustedMinutes =
              totalMinutes < 360 ? 360 : totalMinutes; // 6:00 AM = 360 minutes

          final pickupHours = (adjustedMinutes / 60).floor();
          final pickupMins = adjustedMinutes % 60;
          pickupTime =
              '${pickupHours.toString().padLeft(2, '0')}:${pickupMins.toString().padLeft(2, '0')}';
        } catch (e) {
          print('Error parsing start time: $e');
        }
      }
    }

    // Calculate dropoff time (30 minutes after latest class)
    String dropoffTime = '15:00';
    if (latestEnd != null) {
      final parts = latestEnd.split(':');
      if (parts.length >= 2) {
        try {
          final hours = int.parse(parts[0]);
          final minutes = int.parse(parts[1]);
          final totalMinutes = hours * 60 + minutes + 30; // 30 minutes later

          final dropoffHours = (totalMinutes / 60).floor();
          final dropoffMins = totalMinutes % 60;
          dropoffTime =
              '${dropoffHours.toString().padLeft(2, '0')}:${dropoffMins.toString().padLeft(2, '0')}';
        } catch (e) {
          print('Error parsing end time: $e');
        }
      }
    }

    return {'pickup_time': pickupTime, 'dropoff_time': dropoffTime};
  }

  List<String> _getUniqueDaysFromSchedule(List<Map<String, dynamic>> schedule) {
    final Set<String> allDays = {};

    for (var subject in schedule) {
      final days = subject['days'];
      if (days != null) {
        if (days is List) {
          // If days is already a list
          allDays.addAll(days.cast<String>());
        } else if (days is String) {
          // If days is a string, try to parse it
          try {
            // Handle different possible formats
            if (days.startsWith('[') && days.endsWith(']')) {
              // JSON array format: ["Monday", "Tuesday"]
              final daysList =
                  days
                      .substring(1, days.length - 1)
                      .split(',')
                      .map((day) => day.trim().replaceAll('"', ''))
                      .where((day) => day.isNotEmpty)
                      .toList();
              allDays.addAll(daysList);
            } else {
              // Comma-separated format: "Monday,Tuesday,Wednesday"
              final daysList =
                  days
                      .split(',')
                      .map((day) => day.trim())
                      .where((day) => day.isNotEmpty)
                      .toList();
              allDays.addAll(daysList);
            }
          } catch (e) {
            print('Error parsing days: $e');
            // Fallback: treat as single day
            allDays.add(days);
          }
        }
      }
    }

    // Sort days in weekly order
    final weekDays = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    final sortedDays =
        allDays.toList()..sort((a, b) {
          final indexA = weekDays.indexOf(a);
          final indexB = weekDays.indexOf(b);
          if (indexA == -1) return 1;
          if (indexB == -1) return -1;
          return indexA.compareTo(indexB);
        });

    return sortedDays;
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isAdmin = user?.userMetadata?['role'] == 'Admin';

    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Standardized Header
            Row(
              children: [
                const Text(
                  "Driver Assignment Management",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                // Standardized Search bar
                Container(
                  width: 260,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(8),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: "Search students, drivers...",
                      hintStyle: TextStyle(
                        fontSize: 14,
                        color: Color(0xFF9E9E9E),
                      ),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Color(0xFF2ECC71),
                        size: 20,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 12.0,
                        horizontal: 16.0,
                      ),
                    ),
                    onChanged: (value) {
                      setState(() => _searchQuery = value);
                      _applyFiltersAndSearch();
                    },
                  ),
                ),
                const SizedBox(width: 12),
                // Standardized Add New button
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    label: const Text(
                      "Add Assignment",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 2,
                      shadowColor: Colors.black.withOpacity(0.1),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onPressed: isAdmin ? () => _showAssignmentDialog() : null,
                  ),
                ),
                const SizedBox(width: 12),
                // Standardized Export button
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    icon: const Icon(
                      Icons.file_download_outlined,
                      color: Color(0xFF2ECC71),
                      size: 18,
                    ),
                    label: const Text(
                      "Export",
                      style: TextStyle(
                        color: Color(0xFF2ECC71),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0xFF2ECC71),
                        width: 1.5,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      elevation: 1,
                      shadowColor: Colors.black.withOpacity(0.05),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Export functionality coming soon...'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Standardized Breadcrumb
            const Padding(
              padding: EdgeInsets.only(top: 8.0, bottom: 24.0),
              child: Text(
                "Home / Driver Assignment Management",
                style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
              ),
            ),

            // Stats
            Row(
              children: [
                _buildStatCard(
                  'Total Students',
                  totalStudents.toString(),
                  Icons.school,
                  const Color(0xFF2ECC71),
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Active Drivers',
                  activeDrivers.toString(),
                  Icons.directions_bus,
                  Colors.blue,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Unassigned',
                  unassignedStudents.toString(),
                  Icons.warning,
                  Colors.orange,
                ),
                const SizedBox(width: 16),
                _buildStatCard(
                  'Pending',
                  pendingAssignments.toString(),
                  Icons.schedule,
                  Colors.purple,
                ),
              ],
            ),

            const SizedBox(height: 24),

            // View Tabs and Filters
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  // View Tabs
                  Row(
                    children: [
                      _buildViewTab(
                        'assignments',
                        'Assignment View',
                        Icons.assignment,
                      ),
                      const SizedBox(width: 16),
                      _buildViewTab('students', 'Students View', Icons.school),
                      const SizedBox(width: 16),
                      _buildViewTab(
                        'drivers',
                        'Drivers View',
                        Icons.directions_bus,
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Divider(height: 1),
                  const SizedBox(height: 20),

                  // Filter row
                  _buildFilterRow(),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Content Area
            Expanded(
              child:
                  isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2ECC71),
                        ),
                      )
                      : _buildContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildViewTab(String value, String label, IconData icon) {
    final isSelected = _selectedView == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedView = value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        decoration: BoxDecoration(
          color: isSelected ? const Color(0xFF2ECC71) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected ? const Color(0xFF2ECC71) : Colors.grey[300]!,
            width: 2,
          ),
          boxShadow:
              isSelected
                  ? [
                    BoxShadow(
                      color: const Color(0xFF2ECC71).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ]
                  : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 20,
              color: isSelected ? Colors.white : Colors.grey[600],
            ),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? Colors.white : Colors.grey[600],
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                fontSize: 16,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterRow() {
    return Row(
      children: [
        _buildFilterDropdown(
          'Grade',
          _selectedGradeFilter,
          ['All Grades', 'Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5'],
          (value) {
            setState(() => _selectedGradeFilter = value!);
            _applyFiltersAndSearch();
          },
        ),
        const SizedBox(width: 16),
        _buildFilterDropdown(
          'Driver',
          _selectedDriverFilter,
          [
            'All Drivers',
            ...drivers.map((d) => '${d['fname']} ${d['lname']}'),
            'Unassigned',
          ],
          (value) {
            setState(() => _selectedDriverFilter = value!);
            _applyFiltersAndSearch();
          },
        ),
        const SizedBox(width: 16),
        if (_selectedView == 'assignments') ...[
          _buildFilterDropdown(
            'Status',
            _selectedStatusFilter,
            ['All Status', 'Active', 'Pending', 'Inactive'],
            (value) {
              setState(() => _selectedStatusFilter = value!);
              _applyFiltersAndSearch();
            },
          ),
          const SizedBox(width: 16),
        ],
        _buildFilterDropdown('Sort', _sortOption, [
          'Student Name (A-Z)',
          'Student Name (Z-A)',
          'Grade Level',
          'Date Created',
        ], (value) => setState(() => _sortOption = value!)),
      ],
    );
  }

  Widget _buildFilterDropdown(
    String label,
    String value,
    List<String> items,
    ValueChanged<String?> onChanged,
  ) {
    return Container(
      height: 48,
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE0E0E0)),
        borderRadius: BorderRadius.circular(10),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          icon: const Icon(Icons.keyboard_arrow_down),
          items:
              items
                  .map(
                    (item) => DropdownMenuItem(value: item, child: Text(item)),
                  )
                  .toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _applyFiltersAndSearch() {
    // This will trigger a rebuild and apply filters in the respective build methods
    setState(() {});
  }

  Widget _buildContent() {
    switch (_selectedView) {
      case 'students':
        return _buildStudentsView();
      case 'drivers':
        return _buildDriversView();
      default:
        return _buildAssignmentsView();
    }
  }

  String _displayTime(dynamic timeValue) {
    if (timeValue == null) return '-';

    // If already a TimeOfDay, use localized formatter (handles AM/PM)
    if (timeValue is TimeOfDay) return timeValue.format(context);

    final timeStr = timeValue.toString();
    // Match HH:MM or HH:MM:SS (capture hours and minutes)
    final match = RegExp(r'(\d{1,2}):(\d{2})(?::\d{2})?').firstMatch(timeStr);
    if (match != null) {
      final h = int.tryParse(match.group(1)!) ?? 0;
      final m = int.tryParse(match.group(2)!) ?? 0;
      final tod = TimeOfDay(hour: h, minute: m);
      return tod.format(context); // e.g. "7:30 AM"
    }

    return timeStr;
  }

  Widget _buildAssignmentsView() {
    final filteredAssignments = _getFilteredAssignments();
    final paginatedAssignments = _getPaginatedData(filteredAssignments);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 2),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: TableHeaderCell(text: 'Student')),
                Expanded(flex: 1, child: TableHeaderCell(text: 'Grade')),
                Expanded(flex: 2, child: TableHeaderCell(text: 'Driver')),
                Expanded(flex: 1, child: TableHeaderCell(text: 'Pickup Time')),
                Expanded(flex: 1, child: TableHeaderCell(text: 'Dropoff Time')),
                Expanded(flex: 1, child: TableHeaderCell(text: 'Status')),
                Expanded(flex: 1, child: TableHeaderCell(text: 'Actions')),
              ],
            ),
          ),

          // Table Content
          Expanded(
            child:
                paginatedAssignments.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.assignment, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No assignments found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: paginatedAssignments.length,
                      itemBuilder: (context, index) {
                        final assignment = paginatedAssignments[index];
                        final student = assignment['students'];
                        final driver = assignment['users'];
                        final section = student['sections'];

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[100]!),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Student Info
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${student['fname']} ${student['lname']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF1A1A1A),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    Text(
                                      section != null
                                          ? section['name']
                                          : 'No Section',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Grade
                              Expanded(
                                flex: 1,
                                child: Text(
                                  student['grade_level'] ?? '-',
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),

                              // Driver
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${driver['fname']} ${driver['lname']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF1A1A1A),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    Text(
                                      driver['contact_number'] ?? 'No contact',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Pickup Time
                              Expanded(
                                flex: 1,
                                child: Text(
                                  _displayTime(assignment['pickup_time']),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),

                              // Dropoff Time
                              Expanded(
                                flex: 1,
                                child: Text(
                                  _displayTime(assignment['dropoff_time']),
                                  style: const TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Color(0xFF1A1A1A),
                                  ),
                                ),
                              ),

                              // Status
                              Expanded(
                                flex: 1,
                                child: _buildStatusChip(assignment['status']),
                              ),

                              // Actions
                              Expanded(
                                flex: 1,
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.edit, size: 20),
                                      onPressed:
                                          () => _editAssignment(assignment),
                                      tooltip: 'Edit',
                                    ),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.delete,
                                        size: 20,
                                        color: Colors.red,
                                      ),
                                      onPressed:
                                          () => _deleteAssignment(assignment),
                                      tooltip: 'Delete',
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),

          // Pagination
          if (filteredAssignments.length > _itemsPerPage)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: _buildPagination(filteredAssignments.length),
            ),
        ],
      ),
    );
  }

  Widget _buildStudentsView() {
    final filteredStudents = _getFilteredStudents();
    final paginatedStudents = _getPaginatedData(filteredStudents);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 2),
              ),
            ),
            // make Row non-const so we can use Align for per-column alignment
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Student - left aligned (matches content)
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: const TableHeaderCell(text: 'Student'),
                  ),
                ),
                // Grade - centered
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.center,
                    child: const TableHeaderCell(text: 'Grade'),
                  ),
                ),
                // Address - left aligned
                Expanded(
                  flex: 2,
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: const TableHeaderCell(text: 'Address'),
                  ),
                ),
                // Assignment Status - centered to match content
                Expanded(
                  flex: 1,
                  child: Align(
                    alignment: Alignment.center,
                    child: const TableHeaderCell(text: 'Assignment Status'),
                  ),
                ),
              ],
            ),
          ),

          // Table Content
          Expanded(
            child:
                paginatedStudents.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.school, size: 64, color: Colors.grey),
                          SizedBox(height: 16),
                          Text(
                            'No students found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: paginatedStudents.length,
                      itemBuilder: (context, index) {
                        final student = paginatedStudents[index];
                        final section = student['sections'];
                        final isAssigned =
                            (student['driver_assignments'] as List).any(
                              (assignment) =>
                                  assignment['status']
                                      ?.toString()
                                      .toLowerCase() ==
                                  'active',
                            );

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[100]!),
                            ),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Student Info (left)
                              Expanded(
                                flex: 2,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${student['fname']} ${student['lname']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF1A1A1A),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    Text(
                                      section != null
                                          ? section['name']
                                          : 'No Section',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Grade (centered both vertically & horizontally)
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child: Text(
                                    student['grade_level'] ?? '-',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      color: Color(0xFF1A1A1A),
                                    ),
                                  ),
                                ),
                              ),

                              // Address (left)
                              Expanded(
                                flex: 2,
                                child: Align(
                                  alignment: Alignment.centerLeft,
                                  child: Text(
                                    student['address'] ?? 'No address',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: Color(0xFF1A1A1A),
                                      fontWeight: FontWeight.w500,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ),

                              // Assignment Status (centered)
                              Expanded(
                                flex: 1,
                                child: Center(
                                  child:
                                      isAssigned
                                          ? Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(
                                                Icons.check_circle,
                                                color: Colors.green,
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Assigned',
                                                style: TextStyle(
                                                  color: Colors.green,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          )
                                          : Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: const [
                                              Icon(
                                                Icons.warning,
                                                color: Colors.orange,
                                                size: 20,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Unassigned',
                                                style: TextStyle(
                                                  color: Colors.orange,
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ],
                                          ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),

          // Pagination
          if (filteredStudents.length > _itemsPerPage)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: _buildPagination(filteredStudents.length),
            ),
        ],
      ),
    );
  }

  Widget _buildDriversView() {
    final filteredDrivers = _getFilteredDrivers();
    final paginatedDrivers = _getPaginatedData(filteredDrivers);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Table Header
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 2),
              ),
            ),
            child: const Row(
              children: [
                Expanded(flex: 2, child: TableHeaderCell(text: 'Driver')),
                Expanded(flex: 2, child: TableHeaderCell(text: 'Contact')),
                Expanded(
                  flex: 1,
                  child: TableHeaderCell(text: 'Assigned Students'),
                ),
                Expanded(flex: 2, child: TableHeaderCell(text: 'Students')),
                Expanded(flex: 1, child: TableHeaderCell(text: 'Actions')),
              ],
            ),
          ),

          // Table Content
          Expanded(
            child:
                paginatedDrivers.isEmpty
                    ? const Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.directions_bus,
                            size: 64,
                            color: Colors.grey,
                          ),
                          SizedBox(height: 16),
                          Text(
                            'No drivers found',
                            style: TextStyle(
                              fontSize: 18,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    )
                    : ListView.builder(
                      itemCount: paginatedDrivers.length,
                      itemBuilder: (context, index) {
                        final driver = paginatedDrivers[index];
                        final driverAssignments =
                            assignments
                                .where((a) => a['driver_id'] == driver['id'])
                                .toList();

                        return Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 20,
                            vertical: 16,
                          ),
                          decoration: BoxDecoration(
                            border: Border(
                              bottom: BorderSide(color: Colors.grey[100]!),
                            ),
                          ),
                          child: Row(
                            children: [
                              // Driver Info
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${driver['fname']} ${driver['lname']}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF1A1A1A),
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                    Text(
                                      'Driver',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Contact
                              Expanded(
                                flex: 2,
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      driver['contact_number'] ?? 'No contact',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                    Text(
                                      driver['email'] ?? 'No email',
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: Colors.grey[600],
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),

                              // Assigned Count
                              Expanded(
                                flex: 1,
                                child: Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color:
                                        driverAssignments.isNotEmpty
                                            ? Colors.green.withOpacity(0.1)
                                            : Colors.grey.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color:
                                          driverAssignments.isNotEmpty
                                              ? Colors.green.withOpacity(0.3)
                                              : Colors.grey.withOpacity(0.3),
                                      width: 2,
                                    ),
                                  ),
                                  child: Text(
                                    '${driverAssignments.length} students',
                                    style: TextStyle(
                                      color:
                                          driverAssignments.isNotEmpty
                                              ? Colors.green
                                              : Colors.grey,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ),
                              ),

                              // Student Names
                              Expanded(
                                flex: 2,
                                child:
                                    driverAssignments.isNotEmpty
                                        ? Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children:
                                              driverAssignments.take(3).map((
                                                  assignment,
                                                ) {
                                                  final student =
                                                      assignment['students'];
                                                  return Text(
                                                    '${student['fname']} ${student['lname']}',
                                                    style: const TextStyle(
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color: Color(0xFF1A1A1A),
                                                    ),
                                                  );
                                                }).toList()
                                                ..addAll(
                                                  driverAssignments.length > 3
                                                      ? [
                                                        Text(
                                                          '+ ${driverAssignments.length - 3} more',
                                                          style: TextStyle(
                                                            fontSize: 14,
                                                            color:
                                                                Colors
                                                                    .grey[600],
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ]
                                                      : [],
                                                ),
                                        )
                                        : const Text(
                                          'No assignments',
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 16,
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                              ),

                              // Actions
                              Expanded(
                                flex: 1,
                                child: TextButton(
                                  onPressed: () => _viewDriverDetails(driver),
                                  child: const Text(
                                    'View Details',
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
          ),

          // Pagination
          if (filteredDrivers.length > _itemsPerPage)
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[200]!)),
              ),
              child: _buildPagination(filteredDrivers.length),
            ),
        ],
      ),
    );
  }

  Widget _buildStatusChip(String? status) {
    Color color;
    String text;

    switch (status?.toLowerCase()) {
      case 'active':
        color = Colors.green;
        text = 'Active';
        break;
      case 'pending':
        color = Colors.orange;
        text = 'Pending';
        break;
      case 'inactive':
        color = Colors.red;
        text = 'Inactive';
        break;
      default:
        color = Colors.grey;
        text = 'Unknown';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        textAlign: TextAlign.center,
      ),
    );
  }

  Widget _buildPagination(int totalItems) {
    _totalPages = (totalItems / _itemsPerPage).ceil();

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          'Showing ${(_currentPage - 1) * _itemsPerPage + 1}-${(_currentPage * _itemsPerPage).clamp(1, totalItems)} of $totalItems',
          style: TextStyle(
            color: Colors.grey[600],
            fontSize: 16,
            fontWeight: FontWeight.w500,
          ),
        ),
        Row(
          children: [
            IconButton(
              onPressed:
                  _currentPage > 1
                      ? () => setState(() => _currentPage--)
                      : null,
              icon: const Icon(Icons.chevron_left, size: 24),
            ),
            ...List.generate(_totalPages.clamp(1, 5), (index) {
              final pageNum = index + 1;
              return TextButton(
                onPressed: () => setState(() => _currentPage = pageNum),
                style: TextButton.styleFrom(
                  backgroundColor:
                      _currentPage == pageNum ? const Color(0xFF2ECC71) : null,
                  foregroundColor:
                      _currentPage == pageNum ? Colors.white : null,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                child: Text(
                  '$pageNum',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              );
            }),
            IconButton(
              onPressed:
                  _currentPage < _totalPages
                      ? () => setState(() => _currentPage++)
                      : null,
              icon: const Icon(Icons.chevron_right, size: 24),
            ),
          ],
        ),
      ],
    );
  }

  // Filtering and pagination helper methods
  List<Map<String, dynamic>> _getFilteredAssignments() {
    List<Map<String, dynamic>> filtered = List.from(assignments);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((assignment) {
            final student = assignment['students'];
            final driver = assignment['users'];
            final studentName =
                '${student['fname']} ${student['lname']}'.toLowerCase();
            final driverName =
                '${driver['fname']} ${driver['lname']}'.toLowerCase();
            return studentName.contains(_searchQuery.toLowerCase()) ||
                driverName.contains(_searchQuery.toLowerCase());
          }).toList();
    }

    // Apply grade filter
    if (_selectedGradeFilter != 'All Grades') {
      filtered =
          filtered.where((assignment) {
            final student = assignment['students'];
            return student['grade_level'] == _selectedGradeFilter;
          }).toList();
    }

    // Apply driver filter
    if (_selectedDriverFilter != 'All Drivers') {
      if (_selectedDriverFilter == 'Unassigned') {
        // This shouldn't happen in assignments view, but handle it
        filtered = [];
      } else {
        filtered =
            filtered.where((assignment) {
              final driver = assignment['users'];
              final driverName = '${driver['fname']} ${driver['lname']}';
              return driverName == _selectedDriverFilter;
            }).toList();
      }
    }

    // Apply status filter
    if (_selectedStatusFilter != 'All Status') {
      filtered =
          filtered.where((assignment) {
            return assignment['status']?.toLowerCase() ==
                _selectedStatusFilter.toLowerCase();
          }).toList();
    }

    return filtered;
  }

  List<Map<String, dynamic>> _getFilteredStudents() {
    List<Map<String, dynamic>> filtered = List.from(students);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((student) {
            final studentName =
                '${student['fname']} ${student['lname']}'.toLowerCase();
            return studentName.contains(_searchQuery.toLowerCase());
          }).toList();
    }

    // Apply grade filter
    if (_selectedGradeFilter != 'All Grades') {
      filtered =
          filtered.where((student) {
            return student['grade_level'] == _selectedGradeFilter;
          }).toList();
    }

    // Apply driver filter (assignment status)
    if (_selectedDriverFilter == 'Unassigned') {
      filtered =
          filtered.where((student) {
            final hasActiveAssignment = student['driver_assignments'].any(
              (assignment) => assignment['status'] == 'Active',
            );
            return !hasActiveAssignment;
          }).toList();
    } else if (_selectedDriverFilter != 'All Drivers') {
      // Filter by specific driver
      filtered =
          filtered.where((student) {
            return student['driver_assignments'].any((assignment) {
              if (assignment['status'] != 'Active') return false;
              final driverAssignment = assignments.firstWhere(
                (a) => a['id'] == assignment['id'],
                orElse: () => {},
              );
              if (driverAssignment.isEmpty) return false;
              final driver = driverAssignment['users'];
              final driverName = '${driver['fname']} ${driver['lname']}';
              return driverName == _selectedDriverFilter;
            });
          }).toList();
    }

    return filtered;
  }

  List<Map<String, dynamic>> _getFilteredDrivers() {
    List<Map<String, dynamic>> filtered = List.from(drivers);

    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered =
          filtered.where((driver) {
            final driverName =
                '${driver['fname']} ${driver['lname']}'.toLowerCase();
            final contact = (driver['contact_number'] ?? '').toLowerCase();
            return driverName.contains(_searchQuery.toLowerCase()) ||
                contact.contains(_searchQuery.toLowerCase());
          }).toList();
    }

    return filtered;
  }

  List<Map<String, dynamic>> _getPaginatedData(
    List<Map<String, dynamic>> data,
  ) {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, data.length);
    return data.sublist(startIndex, endIndex);
  }

  // Dialog and action methods
  void _showAssignmentDialog() {
    showDialog(
      context: context,
      builder:
          (context) => _AssignmentDialog(
            students: students,
            drivers: drivers,
            getStudentSchedule: _getStudentSchedule,
            calculatePickupDropoffTimes: _calculatePickupDropoffTimes,
            getUniqueDaysFromSchedule: _getUniqueDaysFromSchedule,
          ),
    ).then((result) {
      if (result != null) {
        _createAssignment(result);
      }
    });
  }

  void _showBulkAssignDialog() {
    showDialog(
      context: context,
      builder:
          (context) =>
              _BulkAssignmentDialog(students: students, drivers: drivers),
    ).then((result) {
      if (result != null) {
        _performBulkAssignment(result);
      }
    });
  }

  void _editAssignment(Map<String, dynamic> assignment) {
    showDialog(
      context: context,
      builder:
          (context) => _AssignmentDialog(
            isEdit: true,
            existingAssignment: assignment,
            students: students,
            drivers: drivers,
            getStudentSchedule: _getStudentSchedule,
            calculatePickupDropoffTimes: _calculatePickupDropoffTimes,
            getUniqueDaysFromSchedule: _getUniqueDaysFromSchedule,
          ),
    ).then((result) {
      if (result != null) {
        _updateAssignment(assignment['id'], result);
      }
    });
  }

  void _deleteAssignment(Map<String, dynamic> assignment) {
    final student = assignment['students'];
    final driver = assignment['users'];
    final studentName = '${student['fname']} ${student['lname']}';
    final driverName = '${driver['fname']} ${driver['lname']}';

    showDialog(
      context: context,
      builder:
          (context) => _DeleteAssignmentDialog(
            studentName: studentName,
            driverName: driverName,
          ),
    ).then((result) {
      if (result == true) {
        _performDeleteAssignment(assignment['id']);
      }
    });
  }

  void _assignStudent(Map<String, dynamic> student) {
    showDialog(
      context: context,
      builder:
          (context) => _AssignmentDialog(
            students: [student],
            drivers: drivers,
            preselectedStudentId: student['id'].toString(),
            getStudentSchedule: _getStudentSchedule,
            calculatePickupDropoffTimes: _calculatePickupDropoffTimes,
            getUniqueDaysFromSchedule: _getUniqueDaysFromSchedule,
          ),
    ).then((result) {
      if (result != null) {
        _createAssignment(result);
      }
    });
  }

  void _viewDriverDetails(Map<String, dynamic> driver) {
    final driverAssignments =
        assignments.where((a) => a['driver_id'] == driver['id']).toList();

    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.person, color: Color(0xFF2ECC71)),
                const SizedBox(width: 8),
                Text(
                  '${driver['fname']} ${driver['lname']} - Details',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 500,
              height: 400,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Contact: ${driver['contact_number'] ?? 'N/A'}'),
                  Text('Email: ${driver['email'] ?? 'N/A'}'),
                  const SizedBox(height: 16),
                  Text('Assigned Students (${driverAssignments.length}):'),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView.builder(
                      itemCount: driverAssignments.length,
                      itemBuilder: (context, index) {
                        final assignment = driverAssignments[index];
                        final student = assignment['students'];
                        return ListTile(
                          leading: CircleAvatar(
                            child: Text(
                              '${student['fname'][0]}${student['lname'][0]}',
                            ),
                          ),
                          title: Text(
                            '${student['fname']} ${student['lname']}',
                          ),
                          subtitle: Text(
                            '${student['grade_level']} - ${assignment['status']}',
                          ),
                          trailing: Text(
                            '${_displayTime(assignment['pickup_time'])} - ${_displayTime(assignment['dropoff_time'])}',
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
    );
  }

  // Database operations
  Future<void> _createAssignment(Map<String, dynamic> assignmentData) async {
    try {
      setState(() => isLoading = true);

      await supabase.from('driver_assignments').insert({
        'student_id': int.parse(assignmentData['student_id']),
        'driver_id': assignmentData['driver_id'],
        'pickup_time': assignmentData['pickup_time'],
        'dropoff_time': assignmentData['dropoff_time'],
        'pickup_address': assignmentData['pickup_address'],
        'schedule_days': assignmentData['schedule_days'],
        'status': assignmentData['status'],
        'notes': assignmentData['notes'],
      });

      _showSuccessSnackBar('Assignment created successfully');
      await _loadAllData();
    } catch (e) {
      _showErrorSnackBar('Error creating assignment: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _updateAssignment(
    int assignmentId,
    Map<String, dynamic> assignmentData,
  ) async {
    try {
      setState(() => isLoading = true);

      await supabase
          .from('driver_assignments')
          .update({
            'student_id': int.parse(assignmentData['student_id']),
            'driver_id': assignmentData['driver_id'],
            'pickup_time': assignmentData['pickup_time'],
            'dropoff_time': assignmentData['dropoff_time'],
            'pickup_address': assignmentData['pickup_address'],
            'schedule_days': assignmentData['schedule_days'],
            'status': assignmentData['status'],
            'notes': assignmentData['notes'],
          })
          .eq('id', assignmentId);

      _showSuccessSnackBar('Assignment updated successfully');
      await _loadAllData();
    } catch (e) {
      _showErrorSnackBar('Error updating assignment: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _performDeleteAssignment(int assignmentId) async {
    try {
      setState(() => isLoading = true);

      await supabase.from('driver_assignments').delete().eq('id', assignmentId);

      _showSuccessSnackBar('Assignment deleted successfully');
      await _loadAllData();
    } catch (e) {
      _showErrorSnackBar('Error deleting assignment: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _performBulkAssignment(Map<String, dynamic> bulkData) async {
    try {
      setState(() => isLoading = true);

      final studentIds = List<String>.from(bulkData['student_ids']);
      final driverId = bulkData['driver_id'];
      final pickupTime = bulkData['pickup_time'] ?? '07:00';
      final dropoffTime = bulkData['dropoff_time'] ?? '15:00';
      final scheduleDays =
          bulkData['schedule_days'] ??
          ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday'];

      List<Map<String, dynamic>> insertData = [];

      for (String studentId in studentIds) {
        final student = students.firstWhere(
          (s) => s['id'].toString() == studentId,
        );

        insertData.add({
          'student_id': int.parse(studentId),
          'driver_id': driverId,
          'pickup_time': pickupTime,
          'dropoff_time': dropoffTime,
          'pickup_address': student['address'] ?? '',
          'schedule_days': scheduleDays,
          'status': 'active',
          'notes': 'Bulk assignment',
        });
      }

      if (insertData.isNotEmpty) {
        await supabase.from('driver_assignments').insert(insertData);
        _showSuccessSnackBar('Bulk assignment completed successfully');
        await _loadAllData();
      }
    } catch (e) {
      _showErrorSnackBar('Error performing bulk assignment: $e');
    } finally {
      setState(() => isLoading = false);
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

class TableHeaderCell extends StatelessWidget {
  final String text;

  const TableHeaderCell({Key? key, required this.text}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        fontWeight: FontWeight.bold,
        fontSize: 16,
        color: Color(0xFF1A1A1A),
        letterSpacing: 0.3,
      ),
    );
  }
}

class _AssignmentDialog extends StatefulWidget {
  final bool isEdit;
  final Map<String, dynamic>? existingAssignment;
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> drivers;
  final String? preselectedStudentId;
  final Future<List<Map<String, dynamic>>> Function(int sectionId)
  getStudentSchedule;
  final Map<String, String> Function(List<Map<String, dynamic>> schedule)
  calculatePickupDropoffTimes;
  final List<String> Function(List<Map<String, dynamic>> schedule)
  getUniqueDaysFromSchedule;

  const _AssignmentDialog({
    Key? key,
    this.isEdit = false,
    this.existingAssignment,
    required this.students,
    required this.drivers,
    this.preselectedStudentId,
    required this.getStudentSchedule,
    required this.calculatePickupDropoffTimes,
    required this.getUniqueDaysFromSchedule,
  }) : super(key: key);

  @override
  State<_AssignmentDialog> createState() => _AssignmentDialogState();
}

class _AssignmentDialogState extends State<_AssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  String? selectedStudentId;
  String? selectedDriverId;
  // Use TimeOfDay for uniform time picking and to match section_management UI
  TimeOfDay? pickupTimeOfDay = const TimeOfDay(hour: 7, minute: 0);
  TimeOfDay? dropoffTimeOfDay = const TimeOfDay(hour: 15, minute: 0);
  String pickupAddress = '';
  List<String> scheduleDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];
  String status = 'active';
  String notes = '';
  // helper for backward-compatible string representation when editing (if needed)
  String? _initialPickupRaw;
  String? _initialDropoffRaw;

  // For displaying student schedule as reference
  List<Map<String, dynamic>> studentSchedule = [];
  bool isLoadingSchedule = false;

  @override
  void initState() {
    super.initState();
    if (widget.isEdit && widget.existingAssignment != null) {
      _loadExistingData();
    } else if (widget.preselectedStudentId != null) {
      selectedStudentId = widget.preselectedStudentId;
      _loadStudentScheduleReference();
    }
  }

  void _loadExistingData() {
    final assignment = widget.existingAssignment!;
    selectedStudentId = assignment['student_id'].toString();
    selectedDriverId = assignment['driver_id'].toString();
    // Keep raw strings (may be HH:MM:SS) and parse into TimeOfDay
    _initialPickupRaw = assignment['pickup_time']?.toString();
    _initialDropoffRaw = assignment['dropoff_time']?.toString();
    pickupTimeOfDay =
        _parseTimeStringToTimeOfDay(_initialPickupRaw) ??
        const TimeOfDay(hour: 7, minute: 0);
    dropoffTimeOfDay =
        _parseTimeStringToTimeOfDay(_initialDropoffRaw) ??
        const TimeOfDay(hour: 15, minute: 0);
    pickupAddress = assignment['pickup_address'] ?? '';

    // Handle schedule_days - it could be a List or a String
    if (assignment['schedule_days'] != null) {
      if (assignment['schedule_days'] is List) {
        scheduleDays = List<String>.from(assignment['schedule_days']);
      } else if (assignment['schedule_days'] is String) {
        // Handle PostgreSQL array format
        String daysStr = assignment['schedule_days'].toString();
        if (daysStr.startsWith('{') && daysStr.endsWith('}')) {
          daysStr = daysStr.substring(1, daysStr.length - 1);
        }
        scheduleDays =
            daysStr
                .split(',')
                .map((s) => s.trim())
                .where((s) => s.isNotEmpty)
                .toList();
      }
    }

    status = assignment['status'] ?? 'active';
    notes = assignment['notes'] ?? '';

    // Load schedule reference for editing
    _loadStudentScheduleReference();
  }

  TimeOfDay? _parseTimeStringToTimeOfDay(String? timeStr) {
    if (timeStr == null) return null;
    // Accept formats like HH:MM, HH:MM:SS, maybe with trailing timezone - pick first HH:MM
    try {
      final match = RegExp(r'(\d{1,2}):(\d{2})').firstMatch(timeStr);
      if (match != null) {
        final h = int.parse(match.group(1)!);
        final m = int.parse(match.group(2)!);
        if (h >= 0 && h <= 23 && m >= 0 && m <= 59) {
          return TimeOfDay(hour: h, minute: m);
        }
      }
    } catch (e) {
      print('Error parsing time string to TimeOfDay: $e');
    }
    return null;
  }

  String _formatTimeForDB(TimeOfDay? t) {
    if (t == null) return '07:00:00';
    final hh = t.hour.toString().padLeft(2, '0');
    final mm = t.minute.toString().padLeft(2, '0');
    return '$hh:$mm:00'; // store as HH:MM:SS to match backend table format
  }

  String _formatTimeDisplay(TimeOfDay? t) {
    if (t == null) return '';
    return t.format(context);
  }

  Future<void> _loadStudentScheduleReference() async {
    if (selectedStudentId == null) return;

    setState(() => isLoadingSchedule = true);

    try {
      final student = widget.students.firstWhere(
        (s) => s['id'].toString() == selectedStudentId,
      );
      final sectionId = student['section_id'];

      if (sectionId != null) {
        print('Loading schedule reference for section ID: $sectionId');

        final schedule = await widget.getStudentSchedule(sectionId);
        print('Loaded schedule reference: $schedule');

        setState(() {
          studentSchedule = schedule;
          // Set pickup address from student's address if not already set
          if (pickupAddress.isEmpty) {
            pickupAddress = student['address'] ?? '';
          }
        });
      }
    } catch (e) {
      print('Error loading student schedule reference: $e');
      setState(() {
        studentSchedule = [];
      });
    } finally {
      setState(() => isLoadingSchedule = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Adopt section_management style for the modal header
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 20,
      shadowColor: Colors.black.withOpacity(0.2),
      title: Row(
        children: [
          Icon(
            widget.isEdit ? Icons.edit : Icons.add,
            color: const Color(0xFF2ECC71),
            size: 24,
          ),
          const SizedBox(width: 12),
          Text(
            widget.isEdit ? 'Edit Assignment' : 'Create Assignment',
            style: const TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 500,
        height: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Student Dropdown
                DropdownButtonFormField<String>(
                  value: selectedStudentId,
                  decoration: InputDecoration(
                    labelText: 'Student *',
                    prefixIcon: const Icon(
                      Icons.person,
                      size: 22,
                      color: Color(0xFF2ECC71),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    labelStyle: TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  items:
                      widget.students.map((student) {
                        return DropdownMenuItem<String>(
                          value: student['id'].toString(),
                          child: Text(
                            '${student['fname']} ${student['lname']} - ${student['grade_level'] ?? ''}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        );
                      }).toList(),
                  onChanged: (value) {
                    setState(() => selectedStudentId = value);
                    _loadStudentScheduleReference();
                  },
                  validator:
                      (value) =>
                          value == null ? 'Please select a student' : null,
                ),
                const SizedBox(height: 16),

                // Driver Dropdown
                DropdownButtonFormField<String>(
                  value: selectedDriverId,
                  decoration: InputDecoration(
                    labelText: 'Driver *',
                    prefixIcon: const Icon(
                      Icons.drive_eta,
                      size: 22,
                      color: Color(0xFF2ECC71),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    labelStyle: TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  items:
                      widget.drivers.map((driver) {
                        return DropdownMenuItem<String>(
                          value: driver['id'].toString(),
                          child: Text(
                            '${driver['fname']} ${driver['lname']}',
                            style: const TextStyle(fontSize: 16),
                          ),
                        );
                      }).toList(),
                  onChanged:
                      (value) => setState(() => selectedDriverId = value),
                  validator:
                      (value) =>
                          value == null ? 'Please select a driver' : null,
                ),
                const SizedBox(height: 16),

                // Student Schedule Reference (Read-only display)
                if (studentSchedule.isNotEmpty || isLoadingSchedule) ...[
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue[200]!, width: 2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.schedule,
                              color: Colors.blue,
                              size: 20,
                            ),
                            const SizedBox(width: 8),
                            const Text(
                              'Student\'s Academic Schedule (Reference)',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Colors.blue,
                                fontSize: 18,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (isLoadingSchedule)
                          const Center(
                            child: Padding(
                              padding: EdgeInsets.all(16.0),
                              child: CircularProgressIndicator(),
                            ),
                          )
                        else if (studentSchedule.isNotEmpty) ...[
                          ...studentSchedule.map((subject) {
                            final teacher =
                                subject['users']; // Changed from 'teachers' to 'users'
                            final teacherName =
                                teacher != null
                                    ? '${teacher['fname'] ?? ''} ${teacher['lname'] ?? ''}'
                                        .trim()
                                    : 'No teacher assigned';

                            return Padding(
                              padding: const EdgeInsets.only(bottom: 8.0),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      subject['subject'] ?? 'No subject',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 16,
                                        color: Color(0xFF1A1A1A),
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      teacherName,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        color: Color(0xFF555555),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 1,
                                    child: Text(
                                      '${subject['start_time'] ?? ''} - ${subject['end_time'] ?? ''}',
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF555555),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text(
                                      _formatDays(subject['days']),
                                      style: const TextStyle(
                                        fontSize: 14,
                                        color: Color(0xFF555555),
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                          const Divider(),
                          Text(
                            'Earliest class: ${_getEarliestTime()} | Latest class: ${_getLatestTime()}',
                            style: const TextStyle(
                              fontSize: 14,
                              fontStyle: FontStyle.italic,
                              color: Colors.grey,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ] else
                          const Text(
                            'No academic schedule found for this student',
                            style: TextStyle(
                              color: Colors.grey,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Pickup / Dropoff Time (section_management style)
                Row(
                  children: [
                    // Pickup Time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Pickup Time *',
                            style: TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime:
                                    pickupTimeOfDay ??
                                    const TimeOfDay(hour: 7, minute: 0),
                              );
                              if (picked != null) {
                                setState(() => pickupTimeOfDay = picked);
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.grey[50],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 22,
                                    color: Color(0xFF2ECC71),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    pickupTimeOfDay != null
                                        ? _formatTimeDisplay(pickupTimeOfDay)
                                        : 'Select pickup time',
                                    style: TextStyle(
                                      color:
                                          pickupTimeOfDay != null
                                              ? const Color(0xFF1A1A1A)
                                              : Colors.grey[600],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Dropoff Time
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Dropoff Time *',
                            style: TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 0.3,
                            ),
                          ),
                          const SizedBox(height: 8),
                          InkWell(
                            onTap: () async {
                              final picked = await showTimePicker(
                                context: context,
                                initialTime:
                                    dropoffTimeOfDay ??
                                    const TimeOfDay(hour: 15, minute: 0),
                              );
                              if (picked != null) {
                                setState(() => dropoffTimeOfDay = picked);
                              }
                            },
                            child: Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                border: Border.all(
                                  color: Colors.grey[300]!,
                                  width: 2,
                                ),
                                borderRadius: BorderRadius.circular(10),
                                color: Colors.grey[50],
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.access_time,
                                    size: 22,
                                    color: Color(0xFF2ECC71),
                                  ),
                                  const SizedBox(width: 10),
                                  Text(
                                    dropoffTimeOfDay != null
                                        ? _formatTimeDisplay(dropoffTimeOfDay)
                                        : 'Select dropoff time',
                                    style: TextStyle(
                                      color:
                                          dropoffTimeOfDay != null
                                              ? const Color(0xFF1A1A1A)
                                              : Colors.grey[600],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Schedule Days Selection
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Schedule Days *',
                    style: TextStyle(
                      color: Color(0xFF1A1A1A),
                      fontWeight: FontWeight.bold,
                      fontSize: 18,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                  ),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final days = [
                        'Monday',
                        'Tuesday',
                        'Wednesday',
                        'Thursday',
                        'Friday',
                      ];
                      const spacing = 8.0;
                      // Try to fit all buttons in one row when possible; otherwise they wrap.
                      final availableWidth =
                          constraints.maxWidth - 16; // small inset
                      final targetPerRow = days.length;
                      final rawButtonWidth =
                          (availableWidth - (spacing * (targetPerRow - 1))) /
                          targetPerRow;
                      // clamp width so buttons remain readable and responsive
                      final buttonWidth = rawButtonWidth.clamp(80.0, 160.0);

                      return Wrap(
                        alignment: WrapAlignment.center,
                        runAlignment: WrapAlignment.center,
                        spacing: spacing,
                        runSpacing: 8,
                        children:
                            days.map((day) {
                              final selected = scheduleDays.contains(day);
                              return SizedBox(
                                width: buttonWidth,
                                child: ElevatedButton(
                                  onPressed: () {
                                    setState(() {
                                      if (selected) {
                                        scheduleDays.remove(day);
                                      } else {
                                        scheduleDays.add(day);
                                      }
                                    });
                                  },
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        selected
                                            ? const Color(0xFF2ECC71)
                                            : Colors.grey[200],
                                    foregroundColor:
                                        selected
                                            ? Colors.white
                                            : Colors.black87,
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 12,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      side: BorderSide(
                                        color:
                                            selected
                                                ? const Color(0xFF2ECC71)
                                                : Colors.grey[300]!,
                                        width: 2,
                                      ),
                                    ),
                                    elevation: selected ? 4 : 0,
                                    shadowColor:
                                        selected
                                            ? const Color(
                                              0xFF2ECC71,
                                            ).withOpacity(0.3)
                                            : null,
                                  ),
                                  child: Text(
                                    day,
                                    style: TextStyle(
                                      fontWeight:
                                          selected
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                      fontSize: 15,
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                      );
                    },
                  ),
                ),
                if (scheduleDays.isEmpty)
                  const Padding(
                    padding: EdgeInsets.only(top: 4.0),
                    child: Text(
                      'Please select at least one day',
                      style: TextStyle(
                        color: Colors.red,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                const SizedBox(height: 16),

                // Pickup Address
                TextFormField(
                  initialValue: pickupAddress,
                  decoration: InputDecoration(
                    labelText: 'Pickup Address',
                    prefixIcon: const Icon(
                      Icons.location_on,
                      size: 22,
                      color: Color(0xFF2ECC71),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    labelStyle: TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1A1A1A),
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: (value) => pickupAddress = value,
                  maxLines: 2,
                ),
                const SizedBox(height: 16),

                // Status
                DropdownButtonFormField<String>(
                  value: status,
                  decoration: InputDecoration(
                    labelText: 'Status',
                    prefixIcon: const Icon(
                      Icons.info,
                      size: 22,
                      color: Color(0xFF2ECC71),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    labelStyle: TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  items: const [
                    DropdownMenuItem(
                      value: 'active',
                      child: Text(
                        'Active',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'pending',
                      child: Text(
                        'Pending',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: 'inactive',
                      child: Text(
                        'Inactive',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (value) => setState(() => status = value!),
                ),
                const SizedBox(height: 16),

                // Notes
                TextFormField(
                  initialValue: notes,
                  decoration: InputDecoration(
                    labelText: 'Notes',
                    prefixIcon: const Icon(
                      Icons.note,
                      size: 22,
                      color: Color(0xFF2ECC71),
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(vertical: 14),
                    labelStyle: TextStyle(
                      color: Color(0xFF555555),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  style: const TextStyle(
                    fontSize: 16,
                    color: Color(0xFF1A1A1A),
                    fontWeight: FontWeight.w500,
                  ),
                  onChanged: (value) => notes = value,
                  maxLines: 3,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF666666),
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2ECC71),
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () {
            // Validate form and ensure days & times selected
            if (!_formKey.currentState!.validate()) return;
            if (scheduleDays.isEmpty) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select at least one day'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }
            if (pickupTimeOfDay == null || dropoffTimeOfDay == null) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Please select pickup and dropoff times'),
                  backgroundColor: Colors.red,
                ),
              );
              return;
            }

            Navigator.of(context).pop({
              'student_id': selectedStudentId,
              'driver_id': selectedDriverId,
              // format as HH:MM:SS to match backend stored values
              'pickup_time': _formatTimeForDB(pickupTimeOfDay),
              'dropoff_time': _formatTimeForDB(dropoffTimeOfDay),
              'pickup_address': pickupAddress,
              'schedule_days': scheduleDays,
              'status': status,
              'notes': notes,
            });
          },
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(widget.isEdit ? Icons.save : Icons.add, size: 18),
              const SizedBox(width: 10),
              Text(
                widget.isEdit ? 'Update Assignment' : 'Create Assignment',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ],
    );
  }

  String _formatDays(dynamic days) {
    if (days == null) return '';

    if (days is List) {
      return days.cast<String>().join(', ');
    } else if (days is String) {
      // Handle different possible formats
      if (days.startsWith('[') && days.endsWith(']')) {
        // JSON array format: ["Monday", "Tuesday"]
        final cleanDays = days
            .substring(1, days.length - 1)
            .split(',')
            .map((day) => day.trim().replaceAll('"', ''))
            .where((day) => day.isNotEmpty)
            .join(', ');
        return cleanDays;
      } else if (days.startsWith('{') && days.endsWith('}')) {
        // PostgreSQL array format: {Monday,Tuesday}
        final cleanDays = days
            .substring(1, days.length - 1)
            .split(',')
            .map((day) => day.trim())
            .where((day) => day.isNotEmpty)
            .join(', ');
        return cleanDays;
      } else {
        // Comma-separated format: "Monday,Tuesday,Wednesday"
        return days
            .split(',')
            .map((day) => day.trim())
            .where((day) => day.isNotEmpty)
            .join(', ');
      }
    }

    return days.toString();
  }

  String _getEarliestTime() {
    if (studentSchedule.isEmpty) return 'N/A';

    String? earliest;
    for (var subject in studentSchedule) {
      final startTime = subject['start_time'] as String?;
      if (startTime != null) {
        if (earliest == null || startTime.compareTo(earliest) < 0) {
          earliest = startTime;
        }
      }
    }
    return earliest ?? 'N/A';
  }

  String _getLatestTime() {
    if (studentSchedule.isEmpty) return 'N/A';

    String? latest;
    for (var subject in studentSchedule) {
      final endTime = subject['end_time'] as String?;
      if (endTime != null) {
        if (latest == null || endTime.compareTo(latest) > 0) {
          latest = endTime;
        }
      }
    }
    return latest ?? 'N/A';
  }
}

class _BulkAssignmentDialog extends StatefulWidget {
  final List<Map<String, dynamic>> students;
  final List<Map<String, dynamic>> drivers;

  const _BulkAssignmentDialog({
    Key? key,
    required this.students,
    required this.drivers,
  }) : super(key: key);

  @override
  State<_BulkAssignmentDialog> createState() => _BulkAssignmentDialogState();
}

class _BulkAssignmentDialogState extends State<_BulkAssignmentDialog> {
  final _formKey = GlobalKey<FormState>();
  String? selectedDriverId;
  List<String> selectedStudentIds = [];
  String pickupTime = '07:00';
  String dropoffTime = '15:00';
  List<String> scheduleDays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
  ];

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 20,
      shadowColor: Colors.black.withOpacity(0.2),
      title: Row(
        children: [
          const Icon(Icons.group_add, color: Color(0xFF2ECC71), size: 24),
          const SizedBox(width: 12),
          const Text(
            'Bulk Assignment',
            style: TextStyle(
              fontSize: 26,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: 600,
        height: 700,
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Driver Selection
              DropdownButtonFormField<String>(
                value: selectedDriverId,
                decoration: InputDecoration(
                  labelText: 'Select Driver *',
                  prefixIcon: const Icon(
                    Icons.drive_eta,
                    size: 22,
                    color: Color(0xFF2ECC71),
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(vertical: 14),
                  labelStyle: TextStyle(
                    color: Color(0xFF555555),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                items:
                    widget.drivers.map((driver) {
                      return DropdownMenuItem<String>(
                        value: driver['id'].toString(),
                        child: Text(
                          '${driver['fname']} ${driver['lname']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      );
                    }).toList(),
                onChanged: (value) => setState(() => selectedDriverId = value),
                validator:
                    (value) => value == null ? 'Please select a driver' : null,
              ),
              const SizedBox(height: 16),

              // Time inputs
              Row(
                children: [
                  Expanded(
                    child: TextFormField(
                      initialValue: pickupTime,
                      decoration: InputDecoration(
                        labelText: 'Pickup Time *',
                        hintText: 'e.g., 07:00',
                        prefixIcon: const Icon(
                          Icons.access_time,
                          size: 22,
                          color: Color(0xFF2ECC71),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        labelStyle: TextStyle(
                          color: Color(0xFF555555),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w500,
                      ),
                      onChanged: (value) => pickupTime = value,
                      validator: (value) {
                        if (value?.isEmpty == true) return 'Required';
                        final timeRegex = RegExp(
                          r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$',
                        );
                        if (!timeRegex.hasMatch(value!))
                          return 'Invalid format';
                        return null;
                      },
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: TextFormField(
                      initialValue: dropoffTime,
                      decoration: InputDecoration(
                        labelText: 'Dropoff Time *',
                        hintText: 'e.g., 15:30',
                        prefixIcon: const Icon(
                          Icons.access_time,
                          size: 22,
                          color: Color(0xFF2ECC71),
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 14,
                        ),
                        labelStyle: TextStyle(
                          color: Color(0xFF555555),
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: const TextStyle(
                        fontSize: 16,
                        color: Color(0xFF1A1A1A),
                        fontWeight: FontWeight.w500,
                      ),
                      onChanged: (value) => dropoffTime = value,
                      validator: (value) {
                        if (value?.isEmpty == true) return 'Required';
                        final timeRegex = RegExp(
                          r'^([01]?[0-9]|2[0-3]):[0-5][0-9]$',
                        );
                        if (!timeRegex.hasMatch(value!))
                          return 'Invalid format';
                        return null;
                      },
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Schedule Days
              Text(
                'Schedule Days *',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              LayoutBuilder(
                builder: (context, constraints) {
                  final days = [
                    'Monday',
                    'Tuesday',
                    'Wednesday',
                    'Thursday',
                    'Friday',
                  ];
                  const spacing = 8.0;
                  final availableWidth = constraints.maxWidth - 16;
                  final rawButtonWidth =
                      (availableWidth - (spacing * (days.length - 1))) /
                      days.length;
                  final buttonWidth = rawButtonWidth.clamp(80.0, 160.0);

                  return Wrap(
                    spacing: spacing,
                    runSpacing: 8,
                    alignment: WrapAlignment.center,
                    children:
                        days.map((day) {
                          final selected = scheduleDays.contains(day);
                          return SizedBox(
                            width: buttonWidth,
                            child: ElevatedButton(
                              onPressed: () {
                                setState(() {
                                  if (selected) {
                                    scheduleDays.remove(day);
                                  } else {
                                    scheduleDays.add(day);
                                  }
                                });
                              },
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    selected
                                        ? const Color(0xFF2ECC71)
                                        : Colors.grey[200],
                                foregroundColor:
                                    selected ? Colors.white : Colors.black87,
                                padding: const EdgeInsets.symmetric(
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                  side: BorderSide(
                                    color:
                                        selected
                                            ? const Color(0xFF2ECC71)
                                            : Colors.grey[300]!,
                                    width: 2,
                                  ),
                                ),
                                elevation: selected ? 4 : 0,
                                shadowColor:
                                    selected
                                        ? const Color(
                                          0xFF2ECC71,
                                        ).withOpacity(0.3)
                                        : null,
                              ),
                              child: Text(
                                day,
                                style: TextStyle(
                                  fontWeight:
                                      selected
                                          ? FontWeight.w700
                                          : FontWeight.w500,
                                  fontSize: 15,
                                  letterSpacing: 0.3,
                                ),
                              ),
                            ),
                          );
                        }).toList(),
                  );
                },
              ),
              const SizedBox(height: 16),

              // Student Selection
              Text(
                'Select Students:',
                style: TextStyle(
                  color: Color(0xFF1A1A1A),
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[300]!, width: 2),
                    borderRadius: BorderRadius.circular(12),
                    color: Colors.grey[50],
                  ),
                  child: ListView.builder(
                    itemCount: widget.students.length,
                    itemBuilder: (context, index) {
                      final student = widget.students[index];
                      final studentId = student['id'].toString();
                      return CheckboxListTile(
                        value: selectedStudentIds.contains(studentId),
                        onChanged: (bool? value) {
                          setState(() {
                            if (value == true) {
                              selectedStudentIds.add(studentId);
                            } else {
                              selectedStudentIds.remove(studentId);
                            }
                          });
                        },
                        title: Text(
                          '${student['fname']} ${student['lname']}',
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF1A1A1A),
                          ),
                        ),
                        subtitle: Text(
                          'Grade ${student['grade_level'] ?? ''}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        activeColor: const Color(0xFF2ECC71),
                      );
                    },
                  ),
                ),
              ),

              if (selectedStudentIds.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFF2ECC71).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2ECC71).withOpacity(0.3),
                        width: 2,
                      ),
                    ),
                    child: Text(
                      '${selectedStudentIds.length} students selected',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: Color(0xFF2ECC71),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: () => Navigator.of(context).pop(),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF666666),
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF2ECC71),
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed:
              selectedDriverId != null &&
                      selectedStudentIds.isNotEmpty &&
                      scheduleDays.isNotEmpty
                  ? () {
                    if (_formKey.currentState!.validate()) {
                      Navigator.of(context).pop({
                        'driver_id': selectedDriverId,
                        'student_ids': selectedStudentIds,
                        'pickup_time': pickupTime,
                        'dropoff_time': dropoffTime,
                        'schedule_days': scheduleDays,
                      });
                    }
                  }
                  : null,
          child: Text(
            'Assign All',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}

class _DeleteAssignmentDialog extends StatelessWidget {
  final String studentName;
  final String driverName;

  const _DeleteAssignmentDialog({
    Key? key,
    required this.studentName,
    required this.driverName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 20,
      shadowColor: Colors.black.withOpacity(0.2),
      title: Row(
        children: [
          const Icon(Icons.warning, color: Colors.red, size: 24),
          const SizedBox(width: 12),
          const Text(
            'Delete Assignment',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
      content: Text(
        'Are you sure you want to delete the assignment for $studentName with driver $driverName?',
        style: const TextStyle(
          fontSize: 16,
          color: Color(0xFF555555),
          fontWeight: FontWeight.w500,
        ),
      ),
      actions: [
        TextButton(
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          ),
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            'Cancel',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: Color(0xFF666666),
            ),
          ),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            elevation: 4,
            shadowColor: Colors.black.withOpacity(0.2),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            'Delete',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      ],
    );
  }
}
