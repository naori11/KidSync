import 'package:flutter/material.dart';
import 'dart:math';

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
  bool _showAdvancedScheduling = false;
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

  Widget _buildDayScheduler(String day) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);

    return Container(
      margin: EdgeInsets.only(bottom: widget.isMobile ? 12 : 16),
      padding: EdgeInsets.all(widget.isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: widget.primaryColor.withOpacity(0.2),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: widget.primaryColor.withOpacity(0.1),
            blurRadius: 6,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            day,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: widget.isMobile ? 15 : 17,
              color: black,
            ),
          ),
          SizedBox(height: widget.isMobile ? 12 : 16),

          // Drop-off Options
          Text(
            'Drop-off (8:00 AM)',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: widget.isMobile ? 13 : 15,
              color: black.withOpacity(0.8),
            ),
          ),
          SizedBox(height: widget.isMobile ? 8 : 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _weeklySchedule[day]!['dropoff'] = 'driver';
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: widget.isMobile ? 8 : 10,
                      horizontal: widget.isMobile ? 12 : 16,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _weeklySchedule[day]!['dropoff'] == 'driver'
                              ? widget.primaryColor.withOpacity(0.1)
                              : white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _weeklySchedule[day]!['dropoff'] == 'driver'
                                ? widget.primaryColor
                                : black.withOpacity(0.2),
                        width:
                            _weeklySchedule[day]!['dropoff'] == 'driver'
                                ? 2
                                : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_shipping,
                          color:
                              _weeklySchedule[day]!['dropoff'] == 'driver'
                                  ? widget.primaryColor
                                  : black.withOpacity(0.6),
                          size: widget.isMobile ? 16 : 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Driver',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isMobile ? 12 : 14,
                            color:
                                _weeklySchedule[day]!['dropoff'] == 'driver'
                                    ? widget.primaryColor
                                    : black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _weeklySchedule[day]!['dropoff'] = 'parent';
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: widget.isMobile ? 8 : 10,
                      horizontal: widget.isMobile ? 12 : 16,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _weeklySchedule[day]!['dropoff'] == 'parent'
                              ? widget.primaryColor.withOpacity(0.1)
                              : white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _weeklySchedule[day]!['dropoff'] == 'parent'
                                ? widget.primaryColor
                                : black.withOpacity(0.2),
                        width:
                            _weeklySchedule[day]!['dropoff'] == 'parent'
                                ? 2
                                : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person,
                          color:
                              _weeklySchedule[day]!['dropoff'] == 'parent'
                                  ? widget.primaryColor
                                  : black.withOpacity(0.6),
                          size: widget.isMobile ? 16 : 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Parent',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isMobile ? 12 : 14,
                            color:
                                _weeklySchedule[day]!['dropoff'] == 'parent'
                                    ? widget.primaryColor
                                    : black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          SizedBox(height: widget.isMobile ? 12 : 16),

          // Pick-up Options
          Text(
            'Pick-up (3:30 PM)',
            style: TextStyle(
              fontWeight: FontWeight.w500,
              fontSize: widget.isMobile ? 13 : 15,
              color: black.withOpacity(0.8),
            ),
          ),
          SizedBox(height: widget.isMobile ? 8 : 10),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _weeklySchedule[day]!['pickup'] = 'driver';
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: widget.isMobile ? 8 : 10,
                      horizontal: widget.isMobile ? 12 : 16,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _weeklySchedule[day]!['pickup'] == 'driver'
                              ? widget.primaryColor.withOpacity(0.1)
                              : white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _weeklySchedule[day]!['pickup'] == 'driver'
                                ? widget.primaryColor
                                : black.withOpacity(0.2),
                        width:
                            _weeklySchedule[day]!['pickup'] == 'driver' ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.local_shipping,
                          color:
                              _weeklySchedule[day]!['pickup'] == 'driver'
                                  ? widget.primaryColor
                                  : black.withOpacity(0.6),
                          size: widget.isMobile ? 16 : 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Driver',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isMobile ? 12 : 14,
                            color:
                                _weeklySchedule[day]!['pickup'] == 'driver'
                                    ? widget.primaryColor
                                    : black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(width: 8),
              Expanded(
                child: GestureDetector(
                  onTap: () {
                    setState(() {
                      _weeklySchedule[day]!['pickup'] = 'parent';
                    });
                  },
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      vertical: widget.isMobile ? 8 : 10,
                      horizontal: widget.isMobile ? 12 : 16,
                    ),
                    decoration: BoxDecoration(
                      color:
                          _weeklySchedule[day]!['pickup'] == 'parent'
                              ? widget.primaryColor.withOpacity(0.1)
                              : white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color:
                            _weeklySchedule[day]!['pickup'] == 'parent'
                                ? widget.primaryColor
                                : black.withOpacity(0.2),
                        width:
                            _weeklySchedule[day]!['pickup'] == 'parent' ? 2 : 1,
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.person,
                          color:
                              _weeklySchedule[day]!['pickup'] == 'parent'
                                  ? widget.primaryColor
                                  : black.withOpacity(0.6),
                          size: widget.isMobile ? 16 : 18,
                        ),
                        SizedBox(width: 6),
                        Text(
                          'Parent',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isMobile ? 12 : 14,
                            color:
                                _weeklySchedule[day]!['pickup'] == 'parent'
                                    ? widget.primaryColor
                                    : black,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
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
                              setState(() {
                                _showAdvancedScheduling = true;
                              });
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

          // Advanced Scheduling Panel
          if (_showAdvancedScheduling)
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
                                Icons.event_note,
                                color: widget.primaryColor,
                                size: widget.isMobile ? 16 : 18,
                              ),
                            ),
                            SizedBox(width: widget.isMobile ? 8 : 12),
                            Expanded(
                              child: Text(
                                'Weekly Schedule Planner',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: widget.isMobile ? 15 : 16,
                                  color: black,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                Icons.close,
                                color: black.withOpacity(0.6),
                              ),
                              onPressed: () {
                                setState(() {
                                  _showAdvancedScheduling = false;
                                });
                              },
                            ),
                          ],
                        ),
                        SizedBox(height: widget.isMobile ? 16 : 20),
                        Text(
                          'Set default arrangements for each day of the week:',
                          style: TextStyle(
                            fontSize: widget.isMobile ? 13 : 15,
                            color: black.withOpacity(0.7),
                          ),
                        ),
                        SizedBox(height: widget.isMobile ? 16 : 20),
                        ..._weeklySchedule.keys
                            .map((day) => _buildDayScheduler(day))
                            .toList(),
                        SizedBox(height: widget.isMobile ? 20 : 24),
                        Row(
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
                                icon: Icon(
                                  Icons.auto_awesome,
                                  size: widget.isMobile ? 18 : 20,
                                ),
                                label: Text(
                                  'Set All to Driver',
                                  style: TextStyle(
                                    fontSize: widget.isMobile ? 14 : 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    for (String day in _weeklySchedule.keys) {
                                      _weeklySchedule[day] = {
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
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.primaryColor,
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
                                  Icons.save,
                                  size: widget.isMobile ? 18 : 20,
                                ),
                                label: Text(
                                  'Save Schedule',
                                  style: TextStyle(
                                    fontSize: widget.isMobile ? 14 : 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showAdvancedScheduling = false;
                                    _hasUnassignedDays = false;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'Weekly schedule saved successfully!',
                                      ),
                                      backgroundColor: widget.primaryColor,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          if (_showAdvancedScheduling)
            SizedBox(height: widget.isMobile ? 12 : 16),

          // Quick Schedule Button
          if (!_showAdvancedScheduling && !_hasUnassignedDays)
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
                    setState(() {
                      _showAdvancedScheduling = true;
                    });
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

          if (!_showAdvancedScheduling && !_hasUnassignedDays)
            SizedBox(height: widget.isMobile ? 12 : 16),

          // Drop-off Selection and Action
          if (!_hasDroppedOff) _buildDropoffCard(),

          if (!_hasDroppedOff) SizedBox(height: widget.isMobile ? 12 : 16),

          // Pick-up Selection and Action
          if (!_hasPickedUp) _buildPickupCard(),

          if (!_hasPickedUp) SizedBox(height: widget.isMobile ? 12 : 16),

          // Reset Options (if both completed)
          if (_hasDroppedOff && _hasPickedUp) _buildCompletionCard(),
        ],
      ),
    );
  }

  Widget _buildDropoffCard() {
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
                        Icons.school,
                        color: widget.primaryColor,
                        size: widget.isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: widget.isMobile ? 8 : 12),
                    Text(
                      'Morning Drop-off Options',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: widget.isMobile ? 15 : 16,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: widget.isMobile ? 12 : 16),
                Text(
                  'Who will drop off your child today?',
                  style: TextStyle(
                    fontSize: widget.isMobile ? 13 : 15,
                    color: black.withOpacity(0.7),
                  ),
                ),
                SizedBox(height: widget.isMobile ? 12 : 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDropoffMode = 'driver';
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(widget.isMobile ? 12 : 16),
                          decoration: BoxDecoration(
                            color:
                                _selectedDropoffMode == 'driver'
                                    ? widget.primaryColor.withOpacity(0.1)
                                    : white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  _selectedDropoffMode == 'driver'
                                      ? widget.primaryColor
                                      : black.withOpacity(0.2),
                              width: _selectedDropoffMode == 'driver' ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.local_shipping,
                                color:
                                    _selectedDropoffMode == 'driver'
                                        ? widget.primaryColor
                                        : black.withOpacity(0.6),
                                size: widget.isMobile ? 24 : 30,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Driver Drop-off',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: widget.isMobile ? 13 : 15,
                                  color:
                                      _selectedDropoffMode == 'driver'
                                          ? widget.primaryColor
                                          : black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedDropoffMode = 'parent';
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(widget.isMobile ? 12 : 16),
                          decoration: BoxDecoration(
                            color:
                                _selectedDropoffMode == 'parent'
                                    ? widget.primaryColor.withOpacity(0.1)
                                    : white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  _selectedDropoffMode == 'parent'
                                      ? widget.primaryColor
                                      : black.withOpacity(0.2),
                              width: _selectedDropoffMode == 'parent' ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.person,
                                color:
                                    _selectedDropoffMode == 'parent'
                                        ? widget.primaryColor
                                        : black.withOpacity(0.6),
                                size: widget.isMobile ? 24 : 30,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Parent Drop-off',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: widget.isMobile ? 13 : 15,
                                  color:
                                      _selectedDropoffMode == 'parent'
                                          ? widget.primaryColor
                                          : black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: widget.isMobile ? 16 : 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primaryColor,
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
                      Icons.check_circle,
                      size: widget.isMobile ? 18 : 20,
                    ),
                    label: Text(
                      'Confirm Drop-off by ${_selectedDropoffMode == 'driver' ? 'Driver' : 'Me'}',
                      style: TextStyle(
                        fontSize: widget.isMobile ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _hasDroppedOff = true;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Drop-off confirmed! ${_selectedDropoffMode == 'driver' ? 'Driver will handle the drop-off' : 'You will drop off your child'}',
                          ),
                          backgroundColor: widget.primaryColor,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickupCard() {
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
                        Icons.home,
                        color: widget.primaryColor,
                        size: widget.isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: widget.isMobile ? 8 : 12),
                    Text(
                      'Afternoon Pick-up Options',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: widget.isMobile ? 15 : 16,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: widget.isMobile ? 12 : 16),
                Text(
                  'Who will pick up your child today?',
                  style: TextStyle(
                    fontSize: widget.isMobile ? 13 : 15,
                    color: black.withOpacity(0.7),
                  ),
                ),
                SizedBox(height: widget.isMobile ? 12 : 16),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPickupMode = 'driver';
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(widget.isMobile ? 12 : 16),
                          decoration: BoxDecoration(
                            color:
                                _selectedPickupMode == 'driver'
                                    ? widget.primaryColor.withOpacity(0.1)
                                    : white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  _selectedPickupMode == 'driver'
                                      ? widget.primaryColor
                                      : black.withOpacity(0.2),
                              width: _selectedPickupMode == 'driver' ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.local_shipping,
                                color:
                                    _selectedPickupMode == 'driver'
                                        ? widget.primaryColor
                                        : black.withOpacity(0.6),
                                size: widget.isMobile ? 24 : 30,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Driver Pick-up',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: widget.isMobile ? 13 : 15,
                                  color:
                                      _selectedPickupMode == 'driver'
                                          ? widget.primaryColor
                                          : black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            _selectedPickupMode = 'parent';
                          });
                        },
                        child: Container(
                          padding: EdgeInsets.all(widget.isMobile ? 12 : 16),
                          decoration: BoxDecoration(
                            color:
                                _selectedPickupMode == 'parent'
                                    ? widget.primaryColor.withOpacity(0.1)
                                    : white,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color:
                                  _selectedPickupMode == 'parent'
                                      ? widget.primaryColor
                                      : black.withOpacity(0.2),
                              width: _selectedPickupMode == 'parent' ? 2 : 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.person,
                                color:
                                    _selectedPickupMode == 'parent'
                                        ? widget.primaryColor
                                        : black.withOpacity(0.6),
                                size: widget.isMobile ? 24 : 30,
                              ),
                              SizedBox(height: 8),
                              Text(
                                'Parent Pick-up',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: widget.isMobile ? 13 : 15,
                                  color:
                                      _selectedPickupMode == 'parent'
                                          ? widget.primaryColor
                                          : black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: widget.isMobile ? 16 : 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: widget.primaryColor,
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
                      Icons.check_circle,
                      size: widget.isMobile ? 18 : 20,
                    ),
                    label: Text(
                      'Confirm Pick-up by ${_selectedPickupMode == 'driver' ? 'Driver' : 'Me'}',
                      style: TextStyle(
                        fontSize: widget.isMobile ? 14 : 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _hasPickedUp = true;
                      });
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Pick-up confirmed! ${_selectedPickupMode == 'driver' ? 'Driver will handle the pick-up' : 'You will pick up your child'}',
                          ),
                          backgroundColor: widget.primaryColor,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCompletionCard() {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);

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
            padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
            child: Column(
              children: [
                Icon(
                  Icons.celebration,
                  color: widget.primaryColor,
                  size: widget.isMobile ? 32 : 40,
                ),
                SizedBox(height: 12),
                Text(
                  'All Done for Today!',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: widget.isMobile ? 16 : 18,
                    color: widget.primaryColor,
                  ),
                ),
                SizedBox(height: 8),
                Text(
                  'Both drop-off and pick-up have been completed.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: widget.isMobile ? 13 : 15,
                    color: black.withOpacity(0.7),
                  ),
                ),
                SizedBox(height: 16),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: widget.primaryColor,
                    side: BorderSide(color: widget.primaryColor),
                    padding: EdgeInsets.symmetric(
                      vertical: widget.isMobile ? 12 : 16,
                      horizontal: widget.isMobile ? 16 : 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  icon: Icon(Icons.refresh, size: widget.isMobile ? 18 : 20),
                  label: Text(
                    'Reset for Tomorrow',
                    style: TextStyle(
                      fontSize: widget.isMobile ? 14 : 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () {
                    setState(() {
                      _hasDroppedOff = false;
                      _hasPickedUp = false;
                      _selectedDropoffMode = 'driver';
                      _selectedPickupMode = 'driver';
                    });
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Schedule reset for tomorrow'),
                        backgroundColor: widget.primaryColor,
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
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
