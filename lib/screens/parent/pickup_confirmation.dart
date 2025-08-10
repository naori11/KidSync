import 'package:flutter/material.dart';

class PickupConfirmationScreen extends StatelessWidget {
  final Color primaryColor;
  final Color backgroundColor;

  const PickupConfirmationScreen({
    Key? key,
    required this.primaryColor,
    required this.backgroundColor,
  }) : super(key: key);

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
                        'Pickup Status',
                        style: TextStyle(
                          color: black,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                      Spacer(),
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: greenWithOpacity,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.directions_car,
                          color: primaryGreen,
                          size: 20,
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
                        // Pick-up Status Card
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
                                            Icons.directions_car,
                                            color: primaryGreen,
                                            size: isMobile ? 16 : 18,
                                          ),
                                        ),
                                        SizedBox(width: isMobile ? 8 : 12),
                                        Text(
                                          'Pick-up Status',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: isMobile ? 15 : 16,
                                            color: black,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isMobile ? 12 : 16),
                                    Row(
                                      children: [
                                        Container(
                                          padding: EdgeInsets.all(4),
                                          decoration: BoxDecoration(
                                            color: primaryGreen,
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Icon(
                                            Icons.circle,
                                            color: white,
                                            size: 8,
                                          ),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Waiting for Pick-up',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: primaryGreen,
                                            fontSize: isMobile ? 14 : 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Icon(
                                          Icons.access_time,
                                          size: 16,
                                          color: black.withOpacity(0.6),
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'Today, 3:30 PM',
                                          style: TextStyle(
                                            color: black.withOpacity(0.7),
                                            fontSize: isMobile ? 12 : 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isMobile ? 12 : 16),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: ElevatedButton.icon(
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: primaryGreen,
                                              foregroundColor: white,
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                vertical: isMobile ? 10 : 16,
                                              ),
                                              elevation: 2,
                                            ),
                                            icon: Icon(
                                              Icons.check_circle,
                                              size: 18,
                                            ),
                                            label: Text('Confirm Pickup'),
                                            onPressed: () {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Pickup confirmed',
                                                  ),
                                                  backgroundColor: primaryGreen,
                                                ),
                                              );
                                            },
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: OutlinedButton.icon(
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: primaryGreen,
                                              side: BorderSide(
                                                color: primaryGreen,
                                              ),
                                              shape: RoundedRectangleBorder(
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                              ),
                                              padding: EdgeInsets.symmetric(
                                                vertical: isMobile ? 10 : 16,
                                              ),
                                            ),
                                            icon: Icon(
                                              Icons.directions_car,
                                              size: 18,
                                            ),
                                            label: Text('Confirm Drop-off'),
                                            onPressed: () {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Drop-off confirmed',
                                                  ),
                                                  backgroundColor: primaryGreen,
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
                                            Icons.calendar_today,
                                            color: primaryGreen,
                                            size: isMobile ? 16 : 18,
                                          ),
                                        ),
                                        SizedBox(width: isMobile ? 8 : 12),
                                        Text(
                                          'Today\'s Schedule',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: isMobile ? 15 : 16,
                                            color: black,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isMobile ? 8 : 12),
                                    _buildScheduleItem(
                                      '8:00 AM',
                                      'Drop-off',
                                      'Completed',
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildScheduleItem(
                                      '3:30 PM',
                                      'Pick-up',
                                      'Pending',
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

                        SizedBox(height: isMobile ? 10 : 14),

                        // Authorized Fetchers Card
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
                                            Icons.verified_user,
                                            color: primaryGreen,
                                            size: isMobile ? 16 : 18,
                                          ),
                                        ),
                                        SizedBox(width: isMobile ? 8 : 12),
                                        Text(
                                          'Authorized Fetchers',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: isMobile ? 15 : 16,
                                            color: black,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isMobile ? 8 : 12),
                                    _buildFetcherItem(
                                      'John Smith',
                                      'Father',
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildFetcherItem(
                                      'Sarah Johnson',
                                      'Grandmother',
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildFetcherItem(
                                      'Mike Wilson',
                                      'Driver',
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

  Widget _buildScheduleItem(
    String time,
    String activity,
    String status,
    bool completed,
    Color primaryGreen,
    Color black,
    bool isMobile,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 6 : 8),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
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
                  '$time $activity',
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: isMobile ? 14 : 16,
                    color: black,
                  ),
                ),
              ],
            ),
          ),
          Text(
            status,
            style: TextStyle(
              fontSize: isMobile ? 12 : 14,
              color: completed ? primaryGreen : black.withOpacity(0.6),
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFetcherItem(
    String name,
    String role,
    bool active,
    Color primaryGreen,
    Color black,
    bool isMobile,
  ) {
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: primaryGreen.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: primaryGreen.withOpacity(0.1),
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
              color: primaryGreen,
              size: isMobile ? 20 : 24,
            ),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 16 : 18,
                    color: black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  role,
                  style: TextStyle(
                    fontSize: isMobile ? 14 : 16,
                    color: black.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          Container(
            width: 12,
            height: 12,
            decoration: BoxDecoration(
              color: active ? primaryGreen : Colors.grey.withOpacity(0.5),
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}
