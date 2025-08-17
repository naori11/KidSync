import 'package:flutter/material.dart';
import 'package:kidsync/services/pickup_dropoff_service.dart';
import '../../models/pickup_dropoff_models.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class PickupDropoffScreen extends StatefulWidget {
  final Color primaryColor;
  final bool isMobile;
  final int? studentId; // Add this parameter

  const PickupDropoffScreen({
    required this.primaryColor,
    required this.isMobile,
    this.studentId,
    super.key,
  });

  @override
  State<PickupDropoffScreen> createState() => _PickupDropoffScreenState();
}

class _PickupDropoffScreenState extends State<PickupDropoffScreen> {
  final supabase = Supabase.instance.client;

  Map<String, Map<String, String>> _weeklyPattern = {
    'Monday': {'dropoff': 'driver', 'pickup': 'driver'},
    'Tuesday': {'dropoff': 'driver', 'pickup': 'driver'},
    'Wednesday': {'dropoff': 'driver', 'pickup': 'driver'},
    'Thursday': {'dropoff': 'driver', 'pickup': 'driver'},
    'Friday': {'dropoff': 'driver', 'pickup': 'driver'},
  };

  // Exceptions to the pattern (specific dates)
  final Map<String, Map<String, String>> _exceptions = {};

  bool _hasDroppedOff = false;
  bool _hasPickedUp = false;

  // Add these as class variables
  final PickupDropoffService _service = PickupDropoffService();
  StudentSchedule? _studentSchedule;
  List<PickupDropoffPattern> _patterns = [];
  int? _currentStudentId; // You'll need to pass this from parent widget
  bool _isLoading = false;

  // Get current week date range
  String _getCurrentWeekRange() {
    final now = DateTime.now();
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(Duration(days: 6));

    final startMonth = _getMonthName(startOfWeek.month);
    final endMonth = _getMonthName(endOfWeek.month);

    if (startOfWeek.month == endOfWeek.month) {
      return '$startMonth ${startOfWeek.day} - ${endOfWeek.day}, ${startOfWeek.year}';
    } else {
      return '$startMonth ${startOfWeek.day} - $endMonth ${endOfWeek.day}, ${startOfWeek.year}';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return months[month - 1];
  }

  @override
  void initState() {
    super.initState();
    // Don't rely on passed studentId - fetch it internally like fetchers_tab does
    _loadData();
  }

  Future<void> _loadData() async {
    setState(() => _isLoading = true);

    try {
      // Get current user (same pattern as fetchers_tab.dart)
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      // Get current parent data (same pattern as fetchers_tab.dart)
      final parentResponse =
          await supabase
              .from('parents')
              .select('id, fname, mname, lname')
              .eq('user_id', user.id)
              .eq('status', 'active')
              .maybeSingle();

      if (parentResponse == null) {
        setState(() => _isLoading = false);
        return;
      }

      final parentId = parentResponse['id'];

      // Get the child(ren) of this parent (same pattern as fetchers_tab.dart)
      final studentResponse = await supabase
          .from('parent_student')
          .select('student_id, students(fname, mname, lname)')
          .eq('parent_id', parentId)
          .limit(1);

      if (studentResponse.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Set the student ID from the query result
      _currentStudentId = studentResponse.first['student_id'];

      // Now load the pickup/dropoff data with the fetched student ID
      await _loadPickupDropoffData();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  // Separate the pickup/dropoff specific data loading
  Future<void> _loadPickupDropoffData() async {
    if (_currentStudentId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      // Load student schedule
      _studentSchedule = await _service.getStudentSchedule(_currentStudentId!);

      // Check if student schedule is valid
      if (_studentSchedule == null) {
        setState(() => _isLoading = false);
        return;
      }

      if (_studentSchedule!.classDays.isEmpty) {
        setState(() => _isLoading = false);
        return;
      }

      // Load patterns
      _patterns = await _service.getPatterns(_currentStudentId!);

      // Load exceptions
      final exceptionsList = await _service.getExceptions(_currentStudentId!);

      // Convert to the format used by the UI
      _weeklyPattern.clear();
      _exceptions.clear();

      for (int dayNum in _studentSchedule!.classDays) {
        String dayName = dayNumToDayName(dayNum);
        if (dayName.isNotEmpty) {
          _weeklyPattern[dayName] = {'dropoff': 'driver', 'pickup': 'driver'};
        }
      }

      // Apply saved patterns
      for (var pattern in _patterns) {
        String dayName = dayNumToDayName(pattern.dayOfWeek);
        if (dayName.isNotEmpty && _weeklyPattern.containsKey(dayName)) {
          _weeklyPattern[dayName] = {
            'dropoff': pattern.dropoffPerson,
            'pickup': pattern.pickupPerson,
          };
        }
      }

      // Apply exceptions
      for (var exception in exceptionsList) {
        String dateKey =
            exception.exceptionDate.toIso8601String().split('T')[0];
        _exceptions[dateKey] = {
          'dropoff': exception.dropoffPerson,
          'pickup': exception.pickupPerson,
        };
      }
    } catch (e) {
      // Handle error silently or show user-friendly message
    } finally {
      setState(() => _isLoading = false);
    }
  }

  // Add this method to get today's schedule
  Map<String, dynamic> _getTodaySchedule() {
    if (_studentSchedule == null || _studentSchedule!.classDays.isEmpty) {
      return {'hasClassToday': false};
    }

    final today = DateTime.now();
    final dayOfWeek = today.weekday;

    // Check if there are classes today
    if (!_studentSchedule!.classDays.contains(dayOfWeek)) {
      // Find next class day - handle empty list case
      int? nextDay;

      // First try to find a day greater than today
      try {
        nextDay = _studentSchedule!.classDays.firstWhere(
          (day) => day > dayOfWeek,
        );
      } catch (e) {
        // If no day greater than today, get the first day of next week
        if (_studentSchedule!.classDays.isNotEmpty) {
          nextDay = _studentSchedule!.classDays.first;
        }
      }

      return {
        'hasClassToday': false,
        'nextClassDay': nextDay,
        'nextClassDate': nextDay != null ? _getNextDateForDay(nextDay) : null,
      };
    }

    // Get schedule for today
    final timeRange = _studentSchedule!.classSchedule[dayOfWeek];
    if (timeRange == null) return {'hasClassToday': false};

    // Check for exceptions first
    final todayKey = today.toIso8601String().split('T')[0];
    final schedule =
        _exceptions[todayKey] ?? _weeklyPattern[dayNumToDayName(dayOfWeek)];

    return {
      'hasClassToday': true,
      'dropoffTime': formatTime(timeRange.startTime),
      'pickupTime': formatTime(timeRange.endTime),
      'dropoffPerson': schedule?['dropoff'] ?? 'driver',
      'pickupPerson': schedule?['pickup'] ?? 'driver',
    };
  }

  DateTime _getNextDateForDay(int dayOfWeek) {
    final today = DateTime.now();
    int daysToAdd = dayOfWeek - today.weekday;
    if (daysToAdd <= 0) daysToAdd += 7;
    return today.add(Duration(days: daysToAdd));
  }

  // Change these methods from private to public (remove underscore)
  int dayNameToDayNum(String dayName) {
    const dayMap = {
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
    };
    return dayMap[dayName.toLowerCase()] ?? 0;
  }

  String dayNumToDayName(int dayNum) {
    const days = [
      '',
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[dayNum];
  }

  String formatTime(String timeString) {
    if (timeString.contains(':')) {
      List<String> parts = timeString.split(':');
      int hour = int.parse(parts[0]);
      int minute = int.parse(parts[1]);

      String period = hour >= 12 ? 'PM' : 'AM';
      hour = hour > 12 ? hour - 12 : (hour == 0 ? 12 : hour);

      return '$hour:${minute.toString().padLeft(2, '0')} $period';
    }
    return timeString;
  }

  @override
  Widget build(BuildContext context) {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: widget.primaryColor),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Today's Status Card
          _buildTodayStatusCard(),

          SizedBox(height: widget.isMobile ? 12 : 16),

          // Weekly Pattern Card
          _buildWeeklyPatternCard(),

          SizedBox(height: widget.isMobile ? 12 : 16),

          // Quick Actions
          _buildQuickActionsCard(),

          if (_exceptions.isNotEmpty) ...[
            SizedBox(height: widget.isMobile ? 12 : 16),
            _buildExceptionsCard(),
          ],
        ],
      ),
    );
  }

  Widget _buildTodayStatusCard() {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    final todaySchedule = _getTodaySchedule();
    final now = DateTime.now();
    final today =
        '${_getDayName(now.weekday)}, ${_getMonthName(now.month)} ${now.day}, ${now.year}';

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: widget.primaryColor.withOpacity(0.2),
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: greenWithOpacity,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.today,
                        color: widget.primaryColor,
                        size: widget.isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: widget.isMobile ? 8 : 12),
                    Text(
                      'Today\'s Schedule',
                      style: TextStyle(
                        fontSize: widget.isMobile ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: widget.isMobile ? 4 : 6),
                Text(
                  today,
                  style: TextStyle(
                    fontSize: widget.isMobile ? 12 : 14,
                    color: black.withOpacity(0.6),
                  ),
                ),
                SizedBox(height: widget.isMobile ? 16 : 20),

                // Check if there are classes today
                if (todaySchedule['hasClassToday'] == true) ...[
                  // Drop-off Status
                  _buildTodayItem(
                    'Drop-off',
                    todaySchedule['dropoffTime'] ?? '8:00 AM',
                    _hasDroppedOff,
                    Icons.arrow_upward,
                    todaySchedule['dropoffPerson'] ?? 'driver',
                  ),
                  SizedBox(height: 12),

                  // Pick-up Status
                  _buildTodayItem(
                    'Pick-up',
                    todaySchedule['pickupTime'] ?? '3:30 PM',
                    _hasPickedUp,
                    Icons.arrow_downward,
                    todaySchedule['pickupPerson'] ?? 'driver',
                  ),
                ] else ...[
                  // No classes today
                  Container(
                    padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
                    decoration: BoxDecoration(
                      color: Colors.blue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.blue.withOpacity(0.3)),
                    ),
                    child: Column(
                      children: [
                        Icon(Icons.event_busy, color: Colors.blue, size: 32),
                        SizedBox(height: 12),
                        Text(
                          'No Classes Today',
                          style: TextStyle(
                            fontSize: widget.isMobile ? 16 : 18,
                            fontWeight: FontWeight.w600,
                            color: black,
                          ),
                        ),
                        // Only show next class date if it exists
                        if (todaySchedule['nextClassDate'] != null) ...[
                          SizedBox(height: 8),
                          Text(
                            'Next class: ${_formatNextClassDate(todaySchedule['nextClassDate'])}',
                            style: TextStyle(
                              fontSize: widget.isMobile ? 14 : 16,
                              color: black.withOpacity(0.7),
                            ),
                          ),
                        ] else ...[
                          SizedBox(height: 8),
                          Text(
                            'No upcoming classes scheduled',
                            style: TextStyle(
                              fontSize: widget.isMobile ? 14 : 16,
                              color: black.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _getDayName(int weekday) {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    return days[weekday - 1];
  }

  String _formatNextClassDate(DateTime date) {
    return '${_getDayName(date.weekday)}, ${_getMonthName(date.month)} ${date.day}';
  }

  Widget _buildTodayItem(
    String title,
    String time,
    bool completed,
    IconData icon,
    String person, // Add this parameter
  ) {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);

    return Container(
      padding: EdgeInsets.all(widget.isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              completed
                  ? widget.primaryColor
                  : widget.primaryColor.withOpacity(0.3),
          width: completed ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color:
                completed
                    ? widget.primaryColor.withOpacity(0.1)
                    : Colors.grey.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color:
                  completed
                      ? widget.primaryColor
                      : Colors.grey.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              completed ? Icons.check : icon,
              color: completed ? white : Colors.grey,
              size: widget.isMobile ? 16 : 18,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$title ($time)',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: widget.isMobile ? 14 : 16,
                    color: black,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  completed
                      ? 'Completed by ${_capitalize(person)}'
                      : 'Scheduled: ${_capitalize(person)}',
                  style: TextStyle(
                    fontSize: widget.isMobile ? 12 : 14,
                    color:
                        completed
                            ? widget.primaryColor
                            : black.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklyPatternCard() {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: widget.primaryColor.withOpacity(0.2),
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: greenWithOpacity,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.repeat,
                        color: widget.primaryColor,
                        size: widget.isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: widget.isMobile ? 8 : 12),
                    Expanded(
                      child: Text(
                        'Weekly Pattern',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 16 : 18,
                          fontWeight: FontWeight.w600,
                          color: black,
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: () => _showWeeklyPatternEditor(),
                      icon: Icon(Icons.edit, size: widget.isMobile ? 16 : 18),
                      label: Text('Edit'),
                      style: TextButton.styleFrom(
                        foregroundColor: widget.primaryColor,
                        padding: EdgeInsets.symmetric(
                          horizontal: widget.isMobile ? 8 : 12,
                          vertical: widget.isMobile ? 4 : 8,
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: widget.isMobile ? 4 : 6),
                Text(
                  _getCurrentWeekRange(),
                  style: TextStyle(
                    fontSize: widget.isMobile ? 12 : 14,
                    color: widget.primaryColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: widget.isMobile ? 8 : 12),
                Text(
                  'This pattern repeats every week unless you set specific exceptions.',
                  style: TextStyle(
                    fontSize: widget.isMobile ? 12 : 14,
                    color: black.withOpacity(0.6),
                  ),
                ),
                SizedBox(height: widget.isMobile ? 16 : 20),

                // Weekly Schedule Grid
                Container(
                  padding: EdgeInsets.all(widget.isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: greenWithOpacity,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: widget.primaryColor.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children:
                        _weeklyPattern.entries
                            .map(
                              (entry) => _buildWeeklyPatternRow(
                                entry.key,
                                entry.value,
                              ),
                            )
                            .toList(),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWeeklyPatternRow(String day, Map<String, String> schedule) {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);

    final bool isToday = _isToday(day);

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(widget.isMobile ? 14 : 18),
      decoration: BoxDecoration(
        color: isToday ? widget.primaryColor.withOpacity(0.08) : white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isToday
                  ? widget.primaryColor
                  : widget.primaryColor.withOpacity(0.15),
          width: isToday ? 2 : 1,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center, // Center vertically
        children: [
          // Day section with consistent width
          SizedBox(
            width:
                widget.isMobile ? 85 : 100, // Slightly wider for better spacing
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.center, // Center the day column
              children: [
                Text(
                  day,
                  style: TextStyle(
                    fontWeight: isToday ? FontWeight.bold : FontWeight.w600,
                    fontSize: widget.isMobile ? 15 : 17,
                    color: isToday ? widget.primaryColor : black,
                  ),
                ),
                if (isToday) ...[
                  SizedBox(height: 2),
                  Container(
                    padding: EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: widget.primaryColor,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Today',
                      style: TextStyle(
                        fontSize: widget.isMobile ? 9 : 10,
                        color: white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),

          // Schedule section
          Expanded(
            child: Column(
              mainAxisAlignment:
                  MainAxisAlignment.center, // Center the actions column
              children: [
                _buildModernPatternItem(
                  'Drop-off',
                  _capitalize(schedule['dropoff'] ?? 'driver'),
                  Icons.directions_car,
                  schedule['dropoff'] == 'parent'
                      ? Colors.orange
                      : widget.primaryColor,
                ),
                SizedBox(height: 10),
                _buildModernPatternItem(
                  'Pick-up',
                  _capitalize(schedule['pickup'] ?? 'driver'),
                  Icons.home,
                  schedule['pickup'] == 'parent'
                      ? Colors.orange
                      : widget.primaryColor,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildModernPatternItem(
    String action,
    String person,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isMobile ? 10 : 12,
        vertical: widget.isMobile ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(
            width: widget.isMobile ? 28 : 32,
            height: widget.isMobile ? 28 : 32,
            decoration: BoxDecoration(
              color: color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Icon(icon, size: widget.isMobile ? 14 : 16, color: color),
          ),
          SizedBox(width: widget.isMobile ? 10 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment:
                  MainAxisAlignment.center, // Center text vertically
              children: [
                Text(
                  action,
                  style: TextStyle(
                    fontSize: widget.isMobile ? 10 : 11,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                SizedBox(height: 1), // Minimal spacing
                Text(
                  person,
                  style: TextStyle(
                    fontSize: widget.isMobile ? 13 : 15,
                    color: color,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPatternChip(String text, IconData icon) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: widget.isMobile ? 8 : 12,
        vertical: widget.isMobile ? 4 : 6,
      ),
      decoration: BoxDecoration(
        color: widget.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: widget.primaryColor.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: widget.isMobile ? 12 : 14,
            color: widget.primaryColor,
          ),
          SizedBox(width: 4),
          Text(
            text,
            style: TextStyle(
              fontSize: widget.isMobile ? 11 : 13,
              color: widget.primaryColor,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionsCard() {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: widget.primaryColor.withOpacity(0.2),
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: greenWithOpacity,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.flash_on,
                        color: widget.primaryColor,
                        size: widget.isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: widget.isMobile ? 8 : 12),
                    Text(
                      'Quick Actions',
                      style: TextStyle(
                        fontSize: widget.isMobile ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: widget.isMobile ? 16 : 20),

                // Actions Grid
                Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: _buildQuickActionButton(
                            'Set Exception',
                            'For specific dates',
                            Icons.event_note,
                            () => _showExceptionDialog(),
                            widget.primaryColor,
                          ),
                        ),
                        SizedBox(width: 12),
                        Expanded(
                          child: _buildQuickActionButton(
                            'Emergency Change',
                            'For today only',
                            Icons.warning,
                            () => _showEmergencyChangeDialog(),
                            Colors.orange,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionButton(
    String title,
    String subtitle,
    IconData icon,
    VoidCallback onTap,
    Color buttonColor,
  ) {
    const Color black = Color(0xFF000000);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.all(widget.isMobile ? 12 : 16),
        decoration: BoxDecoration(
          color: buttonColor.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: buttonColor.withOpacity(0.3), width: 1),
        ),
        child: Column(
          children: [
            Icon(icon, color: buttonColor, size: widget.isMobile ? 24 : 28),
            SizedBox(height: widget.isMobile ? 6 : 8),
            Text(
              title,
              style: TextStyle(
                fontWeight: FontWeight.w600,
                fontSize: widget.isMobile ? 13 : 15,
                color: black,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: 2),
            Text(
              subtitle,
              style: TextStyle(
                fontSize: widget.isMobile ? 10 : 12,
                color: black.withOpacity(0.6),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExceptionsCard() {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: widget.primaryColor.withOpacity(0.2),
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.event_busy,
                        color: Colors.orange,
                        size: widget.isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: widget.isMobile ? 8 : 12),
                    Text(
                      'Scheduled Exceptions',
                      style: TextStyle(
                        fontSize: widget.isMobile ? 16 : 18,
                        fontWeight: FontWeight.w600,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: widget.isMobile ? 16 : 20),
                ..._exceptions.entries
                    .map((entry) => _buildExceptionRow(entry.key, entry.value))
                    .toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExceptionRow(String date, Map<String, String> schedule) {
    const Color black = Color(0xFF000000);

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      padding: EdgeInsets.all(widget.isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatDate(date),
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: widget.isMobile ? 14 : 16,
                    color: black,
                  ),
                ),
                SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  children: [
                    _buildPatternChip(
                      'Drop: ${_capitalize(schedule['dropoff'] ?? 'driver')}',
                      Icons.arrow_upward,
                    ),
                    _buildPatternChip(
                      'Pick: ${_capitalize(schedule['pickup'] ?? 'driver')}',
                      Icons.arrow_downward,
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () async {
              // Call service method to delete from database
              if (_currentStudentId != null) {
                final success = await _service.deleteException(
                  _currentStudentId!,
                  DateTime.parse(date),
                );
                if (success) {
                  setState(() {
                    _exceptions.remove(date);
                  });
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Exception deleted successfully')),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Failed to delete exception')),
                  );
                }
              }
            },
            icon: Icon(
              Icons.delete_outline,
              color: Colors.red,
              size: widget.isMobile ? 20 : 24,
            ),
          ),
        ],
      ),
    );
  }

  bool _isToday(String dayName) {
    final now = DateTime.now();
    final today =
        [
          'Monday',
          'Tuesday',
          'Wednesday',
          'Thursday',
          'Friday',
          'Saturday',
          'Sunday',
        ][now.weekday - 1];
    return dayName == today;
  }

  void _showWeeklyPatternEditor() {
    showDialog(
      context: context,
      builder:
          (context) => WeeklyPatternDialog(
            currentPattern: _weeklyPattern,
            primaryColor: widget.primaryColor,
            isMobile: widget.isMobile,
            onSave: (newPattern) async {
              await _saveWeeklyPattern(newPattern);
            },
          ),
    );
  }

  void _showExceptionDialog() {
    showDialog(
      context: context,
      builder:
          (context) => ExceptionDialog(
            primaryColor: widget.primaryColor,
            isMobile: widget.isMobile,
            onSave: (dateString, schedule) async {
              final date = DateTime.parse(dateString);
              await _saveException(date, schedule);
            },
          ),
    );
  }

  void _showEmergencyChangeDialog() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Emergency change dialog would open here'),
        backgroundColor: widget.primaryColor,
      ),
    );
  }

  String _capitalize(String text) {
    if (text.isEmpty) return text;
    return text[0].toUpperCase() + text.substring(1);
  }

  String _formatDate(String date) {
    // Format date string for display
    return date; // Implement proper date formatting
  }

  // Update the save methods
  Future<void> _saveWeeklyPattern(
    Map<String, Map<String, String>> newPattern,
  ) async {
    if (_currentStudentId == null) return;

    final success = await _service.saveWeeklyPattern(
      _currentStudentId!,
      newPattern,
    );
    if (success) {
      setState(() {
        _weeklyPattern = newPattern;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Weekly pattern saved successfully')),
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save weekly pattern')));
    }
  }

  Future<void> _saveException(
    DateTime date,
    Map<String, String> schedule,
  ) async {
    if (_currentStudentId == null) return;

    final success = await _service.saveException(
      _currentStudentId!,
      date,
      schedule,
    );
    if (success) {
      String dateKey = date.toIso8601String().split('T')[0];
      setState(() {
        _exceptions[dateKey] = schedule;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Exception saved successfully')));
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Failed to save exception')));
    }
  }
}

// Enhanced Weekly Pattern Dialog
class WeeklyPatternDialog extends StatefulWidget {
  final Map<String, Map<String, String>> currentPattern;
  final Color primaryColor;
  final bool isMobile;
  final Function(Map<String, Map<String, String>>) onSave;

  const WeeklyPatternDialog({
    Key? key,
    required this.currentPattern,
    required this.primaryColor,
    required this.isMobile,
    required this.onSave,
  }) : super(key: key);

  @override
  State<WeeklyPatternDialog> createState() => _WeeklyPatternDialogState();
}

class _WeeklyPatternDialogState extends State<WeeklyPatternDialog> {
  late Map<String, Map<String, String>> _pattern;

  @override
  void initState() {
    super.initState();
    _pattern = Map.from(
      widget.currentPattern.map(
        (key, value) => MapEntry(key, Map<String, String>.from(value)),
      ),
    );
  }

  // Add methods to set all dropdowns
  void _setAllToParent() {
    setState(() {
      for (String day in _pattern.keys) {
        _pattern[day]!['dropoff'] = 'parent';
        _pattern[day]!['pickup'] = 'parent';
      }
    });
  }

  void _setAllToDriver() {
    setState(() {
      for (String day in _pattern.keys) {
        _pattern[day]!['dropoff'] = 'driver';
        _pattern[day]!['pickup'] = 'driver';
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: widget.isMobile ? double.infinity : 500,
          maxHeight: MediaQuery.of(context).size.height * 0.8,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: widget.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.edit, color: widget.primaryColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Edit Weekly Pattern',
                      style: TextStyle(
                        fontSize: widget.isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: black,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: black),
                  ),
                ],
              ),
            ),

            // Quick Set Buttons
            Container(
              padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: Colors.grey[50],
                border: Border(
                  bottom: BorderSide(color: Colors.grey[200]!, width: 1),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Quick Set All:',
                    style: TextStyle(
                      fontSize: widget.isMobile ? 14 : 16,
                      fontWeight: FontWeight.w600,
                      color: black,
                    ),
                  ),
                  SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _setAllToParent,
                          icon: Icon(
                            Icons.person,
                            size: widget.isMobile ? 16 : 18,
                          ),
                          label: Text('All Parent'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.orange,
                            foregroundColor: white,
                            padding: EdgeInsets.symmetric(
                              vertical: widget.isMobile ? 8 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _setAllToDriver,
                          icon: Icon(
                            Icons.directions_car,
                            size: widget.isMobile ? 16 : 18,
                          ),
                          label: Text('All Driver'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: widget.primaryColor,
                            foregroundColor: white,
                            padding: EdgeInsets.symmetric(
                              vertical: widget.isMobile ? 8 : 12,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
                child: Column(
                  children:
                      _pattern.entries.map((entry) {
                        return _buildDayEditor(entry.key, entry.value);
                      }).toList(),
                ),
              ),
            ),

            // Actions
            Container(
              padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: widget.primaryColor,
                        side: BorderSide(color: widget.primaryColor),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onSave(_pattern);
                        Navigator.pop(context);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Save Changes'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDayEditor(String day, Map<String, String> schedule) {
    const Color black = Color(0xFF000000);

    return Container(
      margin: EdgeInsets.only(bottom: 16),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border.all(color: widget.primaryColor.withOpacity(0.2)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: widget.isMobile ? 14 : 16,
              color: black,
            ),
          ),
          SizedBox(height: 12),
          if (widget.isMobile) ...[
            // Mobile: Stack vertically to prevent overflow
            _buildDropdownField(
              'Drop-off',
              schedule['dropoff']!,
              (value) =>
                  setState(() => _pattern[day]!['dropoff'] = value ?? 'driver'),
            ),
            SizedBox(height: 12),
            _buildDropdownField(
              'Pick-up',
              schedule['pickup']!,
              (value) =>
                  setState(() => _pattern[day]!['pickup'] = value ?? 'driver'),
            ),
          ] else ...[
            // Desktop: Use Row layout
            Row(
              children: [
                Expanded(
                  child: _buildDropdownField(
                    'Drop-off',
                    schedule['dropoff']!,
                    (value) => setState(
                      () => _pattern[day]!['dropoff'] = value ?? 'driver',
                    ),
                  ),
                ),
                SizedBox(width: 12),
                Expanded(
                  child: _buildDropdownField(
                    'Pick-up',
                    schedule['pickup']!,
                    (value) => setState(
                      () => _pattern[day]!['pickup'] = value ?? 'driver',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdownField(
    String label,
    String value,
    Function(String?) onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: widget.isMobile ? 12 : 14,
            fontWeight: FontWeight.w500,
            color: const Color(0xFF000000),
          ),
        ),
        SizedBox(height: 4),
        DropdownButtonFormField<String>(
          value: value,
          isExpanded:
              true, // Prevent overflow by expanding to fill available width
          decoration: InputDecoration(
            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: widget.primaryColor.withOpacity(0.3),
              ),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: widget.primaryColor.withOpacity(0.3),
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.primaryColor),
            ),
          ),
          items: [
            DropdownMenuItem(value: 'driver', child: Text('Driver')),
            DropdownMenuItem(value: 'parent', child: Text('Parent')),
          ],
          onChanged: onChanged,
        ),
      ],
    );
  }
}

// Enhanced Exception Dialog
class ExceptionDialog extends StatefulWidget {
  final Color primaryColor;
  final bool isMobile;
  final Function(String, Map<String, String>) onSave;

  const ExceptionDialog({
    Key? key,
    required this.primaryColor,
    required this.isMobile,
    required this.onSave,
  }) : super(key: key);

  @override
  State<ExceptionDialog> createState() => _ExceptionDialogState();
}

class _ExceptionDialogState extends State<ExceptionDialog> {
  DateTime? _selectedDate;
  String _dropoffChoice = 'driver';
  String _pickupChoice = 'driver';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: widget.primaryColor),
      );
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: widget.isMobile ? double.infinity : 400,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
              decoration: BoxDecoration(
                color: widget.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(16),
                  topRight: Radius.circular(16),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.event_note, color: widget.primaryColor),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Set Exception',
                      style: TextStyle(
                        fontSize: widget.isMobile ? 16 : 18,
                        fontWeight: FontWeight.bold,
                        color: black,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: Icon(Icons.close, color: black),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Select a specific date that differs from your weekly pattern:',
                    style: TextStyle(
                      fontSize: widget.isMobile ? 14 : 16,
                      color: black.withOpacity(0.7),
                    ),
                  ),
                  SizedBox(height: 16),

                  // Date Picker
                  InkWell(
                    onTap: () async {
                      final date = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now().add(Duration(days: 1)),
                        firstDate: DateTime.now(),
                        lastDate: DateTime.now().add(Duration(days: 365)),
                      );
                      if (date != null) {
                        setState(() => _selectedDate = date);
                      }
                    },
                    child: Container(
                      padding: EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: widget.primaryColor.withOpacity(0.3),
                        ),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            color: widget.primaryColor,
                          ),
                          SizedBox(width: 12),
                          Text(
                            _selectedDate != null
                                ? '${_selectedDate!.day}/${_selectedDate!.month}/${_selectedDate!.year}'
                                : 'Select Date',
                            style: TextStyle(
                              fontSize: widget.isMobile ? 14 : 16,
                              color:
                                  _selectedDate != null
                                      ? black
                                      : black.withOpacity(0.5),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Drop-off Selection
                  Text(
                    'Drop-off:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: widget.isMobile ? 14 : 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildChoiceButtons(
                    _dropoffChoice,
                    (value) => setState(() => _dropoffChoice = value),
                  ),

                  SizedBox(height: 16),

                  // Pick-up Selection
                  Text(
                    'Pick-up:',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: widget.isMobile ? 14 : 16,
                    ),
                  ),
                  SizedBox(height: 8),
                  _buildChoiceButtons(
                    _pickupChoice,
                    (value) => setState(() => _pickupChoice = value),
                  ),
                ],
              ),
            ),

            // Actions
            Container(
              padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey[300]!)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: widget.primaryColor,
                        side: BorderSide(color: widget.primaryColor),
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Cancel'),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed:
                          _selectedDate != null
                              ? () {
                                final dateKey =
                                    _selectedDate!.toIso8601String().split(
                                      'T',
                                    )[0]; // Use proper ISO format
                                widget.onSave(dateKey, {
                                  'dropoff': _dropoffChoice,
                                  'pickup': _pickupChoice,
                                });
                                Navigator.pop(context);
                              }
                              : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: widget.primaryColor,
                        foregroundColor: white,
                        padding: EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: Text('Save Exception'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChoiceButtons(String selectedValue, Function(String) onChanged) {
    return Row(
      children: [
        Expanded(
          child: _buildChoiceButton(
            'Driver',
            'driver',
            selectedValue,
            onChanged,
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: _buildChoiceButton(
            'Parent',
            'parent',
            selectedValue,
            onChanged,
          ),
        ),
      ],
    );
  }

  Widget _buildChoiceButton(
    String label,
    String value,
    String selectedValue,
    Function(String) onChanged,
  ) {
    final bool isSelected = selectedValue == value;

    return InkWell(
      onTap: () => onChanged(value),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color:
              isSelected
                  ? widget.primaryColor.withOpacity(0.1)
                  : Colors.grey[50],
          border: Border.all(
            color: isSelected ? widget.primaryColor : Colors.grey[300]!,
            width: isSelected ? 2 : 1,
          ),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            Icon(
              isSelected ? Icons.radio_button_checked : Icons.radio_button_off,
              color: isSelected ? widget.primaryColor : Colors.grey[400],
              size: widget.isMobile ? 18 : 20,
            ),
            SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? widget.primaryColor : Colors.grey[700],
                fontSize: widget.isMobile ? 14 : 16,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
