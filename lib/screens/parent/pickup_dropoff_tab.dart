import 'package:flutter/material.dart';

class PickupDropoffScreen extends StatefulWidget {
  final Color primaryColor;
  final bool isMobile;

  const PickupDropoffScreen({
    required this.primaryColor,
    required this.isMobile,
    Key? key,
  }) : super(key: key);

  @override
  State<PickupDropoffScreen> createState() => _PickupDropoffScreenState();
}

class _PickupDropoffScreenState extends State<PickupDropoffScreen> {
  String _selectedDropoffMode = 'driver'; // 'driver' or 'parent'
  String _selectedPickupMode = 'driver'; // 'driver' or 'parent'
  bool _hasDroppedOff = false;
  bool _hasPickedUp = false;

  // Advanced scheduling variables
  Map<String, Map<String, String>> _weeklySchedule = {
    'Monday': {'dropoff': 'driver', 'pickup': 'driver'},
    'Tuesday': {'dropoff': 'driver', 'pickup': 'driver'},
    'Wednesday': {'dropoff': 'driver', 'pickup': 'driver'},
    'Thursday': {'dropoff': 'driver', 'pickup': 'driver'},
    'Friday': {'dropoff': 'driver', 'pickup': 'driver'},
  };
  bool _hasUnassignedDays = false;

  @override
  void initState() {
    super.initState();
    _checkForUnassignedDays();
  }

  void _checkForUnassignedDays() {
    DateTime now = DateTime.now();

    // Check if tomorrow or next few days are unassigned
    bool hasUnassigned = false;
    for (int i = 1; i <= 3; i++) {
      DateTime futureDate = now.add(Duration(days: i));
      String dayName = _getDayName(futureDate.weekday);
      if (_weeklySchedule[dayName] == null ||
          _weeklySchedule[dayName]!['dropoff'] == null ||
          _weeklySchedule[dayName]!['pickup'] == null) {
        hasUnassigned = true;
        break;
      }
    }

    setState(() {
      _hasUnassignedDays = hasUnassigned;
    });
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      default:
        return '';
    }
  }

  void _showTabularSchedulingModal() {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return TabularSchedulingModal(
          weeklySchedule: _weeklySchedule,
          onScheduleUpdate: (updatedSchedule) {
            setState(() {
              _weeklySchedule = updatedSchedule;
              _hasUnassignedDays = false;
            });
          },
          primaryColor: widget.primaryColor,
          isMobile: widget.isMobile,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Today's Pickup/Dropoff Status
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              shadowColor: widget.primaryColor.withOpacity(0.3),
              child: Container(
                decoration: BoxDecoration(
                  color: white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.primaryColor.withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 6),
                      spreadRadius: 2,
                    ),
                    BoxShadow(
                      color: const Color(0xFF000000).withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
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
                              Icons.schedule,
                              color: widget.primaryColor,
                              size: widget.isMobile ? 16 : 18,
                            ),
                          ),
                          SizedBox(width: widget.isMobile ? 8 : 12),
                          Text(
                            'Today\'s Schedule',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: widget.isMobile ? 15 : 16,
                              color: black,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: widget.isMobile ? 16 : 20),
                      _buildScheduleItem(
                        '8:00 AM',
                        'Drop-off',
                        _hasDroppedOff
                            ? 'Completed by ${_selectedDropoffMode == 'driver' ? 'Driver' : 'Parent'}'
                            : 'Pending',
                        _hasDroppedOff,
                        widget.isMobile,
                        widget.primaryColor,
                        black,
                      ),
                      SizedBox(height: widget.isMobile ? 8 : 12),
                      _buildScheduleItem(
                        '3:30 PM',
                        'Pick-up',
                        _hasPickedUp
                            ? 'Completed by ${_selectedPickupMode == 'driver' ? 'Driver' : 'Parent'}'
                            : 'Pending',
                        _hasPickedUp,
                        widget.isMobile,
                        widget.primaryColor,
                        black,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: widget.isMobile ? 12 : 16),

          // Unassigned Days Alert
          if (_hasUnassignedDays)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 6,
                shadowColor: Colors.orange.withOpacity(0.3),
                child: Container(
                  decoration: BoxDecoration(
                    color: Colors.orange.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: Colors.orange, width: 2),
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
                    child: Column(
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.orange.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Icon(
                                Icons.warning_amber,
                                color: Colors.orange,
                                size: widget.isMobile ? 16 : 18,
                              ),
                            ),
                            SizedBox(width: widget.isMobile ? 8 : 12),
                            Expanded(
                              child: Text(
                                'Upcoming Days Need Assignment',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: widget.isMobile ? 15 : 16,
                                  color: Colors.orange.shade800,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: widget.isMobile ? 12 : 16),
                        Text(
                          'You have upcoming school days without pickup/dropoff assignments. Please schedule them to avoid last-minute confusion.',
                          style: TextStyle(
                            fontSize: widget.isMobile ? 13 : 15,
                            color: Colors.orange.shade700,
                          ),
                        ),
                        SizedBox(height: widget.isMobile ? 12 : 16),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.orange,
                              foregroundColor: white,
                              padding: EdgeInsets.symmetric(
                                vertical: widget.isMobile ? 12 : 16,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                            ),
                            icon: Icon(
                              Icons.calendar_month,
                              size: widget.isMobile ? 18 : 20,
                            ),
                            label: Text(
                              'Schedule Future Days',
                              style: TextStyle(
                                fontSize: widget.isMobile ? 14 : 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            onPressed: () {
                              _showTabularSchedulingModal();
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_hasUnassignedDays) SizedBox(height: widget.isMobile ? 12 : 16),

          // Quick Schedule Button
          if (!_hasUnassignedDays)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: widget.primaryColor.withOpacity(0.2),
                child: InkWell(
                  borderRadius: BorderRadius.circular(16),
                  onTap: () {
                    _showTabularSchedulingModal();
                  },
                  child: Container(
                    padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: greenWithOpacity,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Icon(
                            Icons.schedule,
                            color: widget.primaryColor,
                            size: widget.isMobile ? 20 : 24,
                          ),
                        ),
                        SizedBox(width: widget.isMobile ? 12 : 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Advanced Scheduling',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: widget.isMobile ? 15 : 16,
                                  color: black,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                'Plan your weekly pickup & dropoff schedule',
                                style: TextStyle(
                                  fontSize: widget.isMobile ? 12 : 14,
                                  color: black.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Icon(
                          Icons.arrow_forward_ios,
                          color: widget.primaryColor,
                          size: widget.isMobile ? 16 : 18,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (!_hasUnassignedDays) SizedBox(height: widget.isMobile ? 12 : 16),
        ],
      ),
    );
  }

  Widget _buildScheduleItem(
    String time,
    String action,
    String status,
    bool completed,
    bool isMobile,
    Color primaryColor,
    Color black,
  ) {
    const Color white = Color(0xFFFFFFFF);

    return Container(
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: completed ? primaryColor : primaryColor.withOpacity(0.3),
          width: completed ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: completed ? primaryColor : black.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              completed ? Icons.check_circle : Icons.schedule,
              color: completed ? white : black.withOpacity(0.6),
              size: isMobile ? 16 : 18,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$time - $action',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 14 : 16,
                    color: black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: completed ? primaryColor : black.withOpacity(0.6),
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
}

class TabularSchedulingModal extends StatefulWidget {
  final Map<String, Map<String, String>> weeklySchedule;
  final Function(Map<String, Map<String, String>>) onScheduleUpdate;
  final Color primaryColor;
  final bool isMobile;

  const TabularSchedulingModal({
    Key? key,
    required this.weeklySchedule,
    required this.onScheduleUpdate,
    required this.primaryColor,
    required this.isMobile,
  }) : super(key: key);

  @override
  State<TabularSchedulingModal> createState() => _TabularSchedulingModalState();
}

class _TabularSchedulingModalState extends State<TabularSchedulingModal> {
  late Map<String, Map<String, String>> _localSchedule;
  DateTime _selectedMonth = DateTime.now();

  // Generate dates for the current month
  List<DateTime> _generateMonthDates() {
    final lastDay = DateTime(_selectedMonth.year, _selectedMonth.month + 1, 0);

    List<DateTime> dates = [];
    for (int i = 0; i < lastDay.day; i++) {
      final date = DateTime(_selectedMonth.year, _selectedMonth.month, i + 1);
      // Only include weekdays (Monday to Friday)
      if (date.weekday >= 1 && date.weekday <= 5) {
        dates.add(date);
      }
    }
    return dates;
  }

  String _getDayName(int weekday) {
    switch (weekday) {
      case 1:
        return 'Monday';
      case 2:
        return 'Tuesday';
      case 3:
        return 'Wednesday';
      case 4:
        return 'Thursday';
      case 5:
        return 'Friday';
      default:
        return '';
    }
  }

  String _getMonthName(int month) {
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    return months[month - 1];
  }

  @override
  void initState() {
    super.initState();
    _localSchedule = Map.from(
      widget.weeklySchedule.map(
        (key, value) => MapEntry(key, Map<String, String>.from(value)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    final screenSize = MediaQuery.of(context).size;
    final isTablet = screenSize.width > 600 && screenSize.width < 1024;

    // Better responsive sizing - made wider for better text fitting
    double dialogWidth;
    if (widget.isMobile) {
      dialogWidth = screenSize.width * 0.98; // Increased from 0.95
    } else if (isTablet) {
      dialogWidth = screenSize.width * 0.90; // Increased from 0.85
    } else {
      dialogWidth =
          screenSize.width > 1200
              ? 1000.0
              : screenSize.width * 0.80; // Increased
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: widget.isMobile ? 8 : 20,
        vertical: widget.isMobile ? 20 : 40,
      ),
      child: Container(
        width: dialogWidth,
        constraints: BoxConstraints(
          maxHeight: screenSize.height * 0.9,
          minHeight: widget.isMobile ? screenSize.height * 0.6 : 400,
        ),
        decoration: BoxDecoration(
          color: white,
          borderRadius: BorderRadius.circular(widget.isMobile ? 16 : 24),
          boxShadow: [
            BoxShadow(
              color: widget.primaryColor.withOpacity(0.1),
              blurRadius: 24,
              offset: const Offset(0, 12),
              spreadRadius: 0,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with Month Navigation
            Container(
              padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
              decoration: BoxDecoration(
                color: widget.primaryColor.withOpacity(0.05),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(widget.isMobile ? 16 : 24),
                  topRight: Radius.circular(widget.isMobile ? 16 : 24),
                ),
              ),
              child: Column(
                children: [
                  // Title Row
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: greenWithOpacity,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.calendar_month,
                          color: widget.primaryColor,
                          size: widget.isMobile ? 20 : 24,
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Monthly Schedule Planner',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: widget.isMobile ? 16 : 20,
                            color: black,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: Icon(Icons.close, color: black.withOpacity(0.6)),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),

                  SizedBox(height: 16),

                  // Month Navigation
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month - 1,
                            );
                          });
                        },
                        icon: Icon(
                          Icons.chevron_left,
                          color: widget.primaryColor,
                          size: widget.isMobile ? 24 : 28,
                        ),
                      ),
                      Text(
                        '${_getMonthName(_selectedMonth.month)} ${_selectedMonth.year}',
                        style: TextStyle(
                          fontSize: widget.isMobile ? 18 : 22,
                          fontWeight: FontWeight.w600,
                          color: black,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _selectedMonth = DateTime(
                              _selectedMonth.year,
                              _selectedMonth.month + 1,
                            );
                          });
                        },
                        icon: Icon(
                          Icons.chevron_right,
                          color: widget.primaryColor,
                          size: widget.isMobile ? 24 : 28,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Set pickup and drop-off arrangements for each school day in ${_getMonthName(_selectedMonth.month)}:',
                      style: TextStyle(
                        fontSize: widget.isMobile ? 14 : 16,
                        color: black.withOpacity(0.7),
                      ),
                    ),
                    SizedBox(height: widget.isMobile ? 16 : 24),

                    // Responsive Schedule Interface
                    _buildResponsiveScheduleInterface(),

                    SizedBox(height: widget.isMobile ? 20 : 32),

                    // Quick Action Buttons
                    _buildQuickActionButtons(),

                    SizedBox(height: 16),

                    // Save Button
                    _buildSaveButton(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildResponsiveScheduleInterface() {
    final monthDates = _generateMonthDates();
    return _buildResponsiveMonthlyTable(monthDates);
  }

  Widget _buildResponsiveMonthlyTable(List<DateTime> dates) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);

    return Container(
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.primaryColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.primaryColor.withOpacity(0.05),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: [
          // Header Row
          Container(
            padding: EdgeInsets.symmetric(
              vertical: widget.isMobile ? 12 : 16,
              horizontal: widget.isMobile ? 8 : 16,
            ),
            decoration: BoxDecoration(
              color: widget.primaryColor.withOpacity(0.05),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Row(
              children: [
                // Date & Day Column Header
                Expanded(
                  flex: widget.isMobile ? 3 : 4,
                  child: Text(
                    'Date & Day',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: widget.isMobile ? 12 : 14,
                      color: black,
                    ),
                  ),
                ),
                // Drop-off Column Header
                Expanded(
                  flex: widget.isMobile ? 3 : 4,
                  child: Text(
                    'Drop-off\n(8:00 AM)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: widget.isMobile ? 10 : 12,
                      color: black,
                      height: 1.2,
                    ),
                  ),
                ),
                // Pick-up Column Header
                Expanded(
                  flex: widget.isMobile ? 3 : 4,
                  child: Text(
                    'Pick-up\n(3:30 PM)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: widget.isMobile ? 10 : 12,
                      color: black,
                      height: 1.2,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Data Rows
          ...dates.asMap().entries.map((entry) {
            final index = entry.key;
            final date = entry.value;
            final dayKey = _getDayName(date.weekday);
            final dateKey =
                '${date.year}-${date.month}-${date.day}'; // Unique date key
            final isEvenRow = index % 2 == 0;

            return Container(
              padding: EdgeInsets.symmetric(
                vertical: widget.isMobile ? 8 : 12,
                horizontal: widget.isMobile ? 8 : 16,
              ),
              decoration: BoxDecoration(
                color:
                    isEvenRow ? white : widget.primaryColor.withOpacity(0.02),
                border: Border(
                  bottom: BorderSide(
                    color: widget.primaryColor.withOpacity(0.1),
                    width: 0.5,
                  ),
                ),
              ),
              child: Row(
                children: [
                  // Date & Day Column
                  Expanded(
                    flex: widget.isMobile ? 3 : 4,
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: widget.isMobile ? 6 : 8,
                            vertical: widget.isMobile ? 2 : 4,
                          ),
                          decoration: BoxDecoration(
                            color: widget.primaryColor,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            '${date.day}',
                            style: TextStyle(
                              color: white,
                              fontWeight: FontWeight.bold,
                              fontSize: widget.isMobile ? 10 : 12,
                            ),
                          ),
                        ),
                        SizedBox(width: widget.isMobile ? 4 : 8),
                        Expanded(
                          child: Text(
                            widget.isMobile
                                ? dayKey.substring(0, 3) // Mon, Tue, etc.
                                : dayKey,
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: widget.isMobile ? 11 : 14,
                              color: black,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Drop-off Column
                  Expanded(
                    flex: widget.isMobile ? 3 : 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _buildTabularOptionButton(
                            'driver',
                            'dropoff',
                            dateKey,
                            Icons.local_shipping,
                            isFirst: true,
                          ),
                        ),
                        SizedBox(width: widget.isMobile ? 2 : 4),
                        Expanded(
                          child: _buildTabularOptionButton(
                            'parent',
                            'dropoff',
                            dateKey,
                            Icons.person,
                            isFirst: false,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Pick-up Column
                  Expanded(
                    flex: widget.isMobile ? 3 : 4,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Expanded(
                          child: _buildTabularOptionButton(
                            'driver',
                            'pickup',
                            dateKey,
                            Icons.local_shipping,
                            isFirst: true,
                          ),
                        ),
                        SizedBox(width: widget.isMobile ? 2 : 4),
                        Expanded(
                          child: _buildTabularOptionButton(
                            'parent',
                            'pickup',
                            dateKey,
                            Icons.person,
                            isFirst: false,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildTabularOptionButton(
    String value,
    String type,
    String dateKey,
    IconData icon, {
    required bool isFirst,
  }) {
    const Color white = Color(0xFFFFFFFF);

    final isSelected = _localSchedule[dateKey]?[type] == value;

    return GestureDetector(
      onTap: () {
        setState(() {
          if (_localSchedule[dateKey] == null) {
            _localSchedule[dateKey] = {};
          }
          _localSchedule[dateKey]![type] = value;
        });
      },
      child: AnimatedContainer(
        duration: Duration(milliseconds: 200),
        padding: EdgeInsets.symmetric(
          vertical: widget.isMobile ? 6 : 8,
          horizontal: widget.isMobile ? 4 : 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? widget.primaryColor : white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(isFirst ? 6 : 0),
            bottomLeft: Radius.circular(isFirst ? 6 : 0),
            topRight: Radius.circular(!isFirst ? 6 : 0),
            bottomRight: Radius.circular(!isFirst ? 6 : 0),
          ),
          border: Border.all(color: widget.primaryColor, width: 1),
        ),
        child: Icon(
          icon,
          color: isSelected ? white : widget.primaryColor,
          size: widget.isMobile ? 14 : 16,
        ),
      ),
    );
  }

  Widget _buildQuickActionButtons() {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.primaryColor,
              side: BorderSide(color: widget.primaryColor),
              padding: EdgeInsets.symmetric(
                vertical: widget.isMobile ? 12 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(Icons.local_shipping),
            label: Text('All Driver'),
            onPressed: () {
              setState(() {
                final monthDates = _generateMonthDates();
                for (DateTime date in monthDates) {
                  final dateKey = '${date.year}-${date.month}-${date.day}';
                  _localSchedule[dateKey] = {
                    'dropoff': 'driver',
                    'pickup': 'driver',
                  };
                }
              });
            },
          ),
        ),
        SizedBox(width: 12),
        Expanded(
          child: OutlinedButton.icon(
            style: OutlinedButton.styleFrom(
              foregroundColor: widget.primaryColor,
              side: BorderSide(color: widget.primaryColor),
              padding: EdgeInsets.symmetric(
                vertical: widget.isMobile ? 12 : 16,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            icon: Icon(Icons.person),
            label: Text('All Parent'),
            onPressed: () {
              setState(() {
                final monthDates = _generateMonthDates();
                for (DateTime date in monthDates) {
                  final dateKey = '${date.year}-${date.month}-${date.day}';
                  _localSchedule[dateKey] = {
                    'dropoff': 'parent',
                    'pickup': 'parent',
                  };
                }
              });
            },
          ),
        ),
      ],
    );
  }

  Widget _buildSaveButton() {
    const Color white = Color(0xFFFFFFFF);

    return SizedBox(
      width: double.infinity,
      child: ElevatedButton.icon(
        style: ElevatedButton.styleFrom(
          backgroundColor: widget.primaryColor,
          foregroundColor: white,
          padding: EdgeInsets.symmetric(vertical: widget.isMobile ? 16 : 20),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 4,
        ),
        icon: Icon(Icons.save, size: widget.isMobile ? 20 : 24),
        label: Text(
          'Save Monthly Schedule',
          style: TextStyle(
            fontSize: widget.isMobile ? 16 : 18,
            fontWeight: FontWeight.w600,
          ),
        ),
        onPressed: () {
          widget.onScheduleUpdate(_localSchedule);
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Monthly schedule for ${_getMonthName(_selectedMonth.month)} saved successfully!',
              ),
              backgroundColor: widget.primaryColor,
            ),
          );
        },
      ),
    );
  }
}
