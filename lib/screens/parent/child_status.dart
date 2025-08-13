import 'package:flutter/material.dart';
import '../../models/driver_models.dart';

class ChildStatusScreen extends StatefulWidget {
  const ChildStatusScreen({Key? key}) : super(key: key);

  @override
  State<ChildStatusScreen> createState() => _ChildStatusScreenState();
}

class _ChildStatusScreenState extends State<ChildStatusScreen> {
  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 500;
    const Color primaryGreen = Color(0xFF19AE61);
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body: Stack(
        children: [
          Column(
            children: [
              // Top Bar - matching parent_home.dart style
              Container(
                color: white,
                padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: SafeArea(
                  child: Row(
                    children: [
                      IconButton(
                        icon: Icon(Icons.arrow_back, color: black),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                      SizedBox(width: 8),
                      SizedBox(
                        height: 32,
                        width: 32,
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                          errorBuilder:
                              (context, error, stackTrace) => Icon(
                                Icons.school,
                                color: primaryGreen,
                                size: 28,
                              ),
                        ),
                      ),
                      SizedBox(width: 12),
                      Text(
                        'Emma\'s Status',
                        style: TextStyle(
                          color: black,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: greenWithOpacity,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Text(
                          'Grade 2',
                          style: TextStyle(
                            color: primaryGreen,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Main Content
              Expanded(
                child: SingleChildScrollView(
                  child: Padding(
                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // Current Status Card
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 8,
                            shadowColor: primaryGreen.withOpacity(0.3),
                            child: Container(
                              decoration: BoxDecoration(
                                color: white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryGreen.withOpacity(0.15),
                                    blurRadius: 12,
                                    offset: const Offset(0, 6),
                                    spreadRadius: 2,
                                  ),
                                  BoxShadow(
                                    color: const Color(
                                      0xFF000000,
                                    ).withOpacity(0.05),
                                    blurRadius: 4,
                                    offset: const Offset(0, 2),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(isMobile ? 16 : 32),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: greenWithOpacity,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.child_care,
                                            color: primaryGreen,
                                            size: isMobile ? 16 : 18,
                                          ),
                                        ),
                                        SizedBox(width: isMobile ? 8 : 12),
                                        Text(
                                          'Current Status',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: isMobile ? 15 : 16,
                                            color: black,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 16),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.circle,
                                          color: primaryGreen,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          'Present at School',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: primaryGreen,
                                            fontSize: isMobile ? 14 : 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: black.withOpacity(0.6),
                                        ),
                                        const SizedBox(width: 4),
                                        Text(
                                          'Last seen: Math Class, 2:15 PM',
                                          style: TextStyle(
                                            color: black.withOpacity(0.7),
                                            fontSize: isMobile ? 12 : 13,
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

                        SizedBox(height: isMobile ? 10 : 14),

                        // Driver Information Card
                        _buildDriverInfoCard(primaryGreen, isMobile, context),

                        SizedBox(height: isMobile ? 10 : 14),

                        // Today's Schedule Card
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          child: Card(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: 6,
                            shadowColor: primaryGreen.withOpacity(0.2),
                            child: Container(
                              decoration: BoxDecoration(
                                color: white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  BoxShadow(
                                    color: primaryGreen.withOpacity(0.1),
                                    blurRadius: 10,
                                    offset: const Offset(0, 5),
                                    spreadRadius: 1,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: EdgeInsets.all(isMobile ? 12 : 20),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(6),
                                          decoration: BoxDecoration(
                                            color: greenWithOpacity,
                                            borderRadius: BorderRadius.circular(
                                              6,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.schedule,
                                            color: primaryGreen,
                                            size: isMobile ? 16 : 18,
                                          ),
                                        ),
                                        SizedBox(width: isMobile ? 8 : 12),
                                        Text(
                                          "Today's Schedule",
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: isMobile ? 15 : 16,
                                            color: black,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isMobile ? 8 : 12),
                                    _buildTimelineItem(
                                      '8:00 AM',
                                      'Arrived at School',
                                      Icons.school,
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildTimelineItem(
                                      '9:00 AM',
                                      'Reading Class',
                                      Icons.book,
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildTimelineItem(
                                      '10:30 AM',
                                      'Recess & Snack Time',
                                      Icons.sports,
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildTimelineItem(
                                      '11:00 AM',
                                      'Math Class',
                                      Icons.calculate,
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildTimelineItem(
                                      '12:00 PM',
                                      'Lunch Break',
                                      Icons.lunch_dining,
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildTimelineItem(
                                      '1:00 PM',
                                      'Art & Crafts',
                                      Icons.palette,
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildTimelineItem(
                                      '2:15 PM',
                                      'Story Time',
                                      Icons.auto_stories,
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildTimelineItem(
                                      '3:30 PM',
                                      'Pick-up Time',
                                      Icons.directions_car,
                                      false,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                  ],
                                ),
                              ),
                            ),
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

  Widget _buildTimelineItem(
    String time,
    String activity,
    IconData icon,
    bool completed,
    Color primaryGreen,
    Color black,
    bool isMobile,
  ) {
    const Color white = Color(0xFFFFFFFF);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 6 : 8),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryGreen.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Icon(
            completed ? Icons.check_circle : Icons.schedule,
            color: completed ? primaryGreen : black.withOpacity(0.6),
            size: isMobile ? 18 : 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '$time - $activity',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: isMobile ? 14 : 16,
                    color: black,
                  ),
                ),
                if (completed)
                  Text(
                    'Completed',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color: primaryGreen,
                      fontWeight: FontWeight.w500,
                    ),
                  )
                else
                  Text(
                    'Upcoming',
                    style: TextStyle(
                      fontSize: isMobile ? 12 : 14,
                      color: black.withOpacity(0.6),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInfoCard(
    Color primaryColor,
    bool isMobile,
    BuildContext context,
  ) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);
    final driverInfo = StaticDriverData.driverInfo;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: primaryColor.withOpacity(0.2),
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
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
                        Icons.local_shipping,
                        color: primaryColor,
                        size: isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Text(
                      'Your Driver',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 15 : 16,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 2,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                        spreadRadius: 0,
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: greenWithOpacity,
                        radius: isMobile ? 20 : 24,
                        child: Icon(
                          Icons.person,
                          color: primaryColor,
                          size: isMobile ? 20 : 24,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driverInfo.name,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: isMobile ? 16 : 18,
                                color: black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.directions_car,
                                  size: isMobile ? 14 : 16,
                                  color: black.withOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'Vehicle: ${driverInfo.vehicleNumber}',
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 16,
                                    color: black.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: isMobile ? 14 : 16,
                                  color: black.withOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  driverInfo.phoneNumber,
                                  style: TextStyle(
                                    fontSize: isMobile ? 14 : 16,
                                    color: black.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: primaryColor,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ],
                  ),
                ),
                SizedBox(height: isMobile ? 12 : 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: white,
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 10 : 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        icon: Icon(Icons.phone, size: isMobile ? 16 : 18),
                        label: Text(
                          'Call Driver',
                          style: TextStyle(fontSize: isMobile ? 13 : 15),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Calling ${driverInfo.name}...'),
                              backgroundColor: primaryColor,
                            ),
                          );
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: primaryColor,
                          side: BorderSide(color: primaryColor),
                          padding: EdgeInsets.symmetric(
                            vertical: isMobile ? 10 : 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                        icon: Icon(Icons.message, size: isMobile ? 16 : 18),
                        label: Text(
                          'Message',
                          style: TextStyle(fontSize: isMobile ? 13 : 15),
                        ),
                        onPressed: () {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Opening message to ${driverInfo.name}...',
                              ),
                              backgroundColor: primaryColor,
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
    );
  }
}
