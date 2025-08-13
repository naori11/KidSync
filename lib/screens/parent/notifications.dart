import 'package:flutter/material.dart';

class ParentNotificationsScreen extends StatelessWidget {
  const ParentNotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isMobile = MediaQuery.of(context).size.width < 500;
    const Color primaryGreen = Color(0xFF19AE61);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);
    const Color white = Color(0xFFFFFFFF);

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
                        'Notifications',
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
                          Icons.notifications,
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
                        // Today's Notifications Card
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
                                            Icons.notifications_active,
                                            color: primaryGreen,
                                            size: isMobile ? 16 : 18,
                                          ),
                                        ),
                                        SizedBox(width: isMobile ? 8 : 12),
                                        Text(
                                          'Recent Notifications',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: isMobile ? 15 : 16,
                                            color: black,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isMobile ? 12 : 16),
                                    _buildNotificationItem(
                                      'Emma arrived safely at school',
                                      '8:05 AM • Grade 2 Classroom',
                                      Icons.check_circle,
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildNotificationItem(
                                      'Math homework completed in class',
                                      '11:30 AM • Mrs. Johnson\'s classroom',
                                      Icons.assignment_turned_in,
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildNotificationItem(
                                      'Lunch enjoyed - ate 80% of meal',
                                      '12:15 PM • School cafeteria',
                                      Icons.lunch_dining,
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildNotificationItem(
                                      'Art project started: Mother\'s Day card',
                                      '1:45 PM • Art room',
                                      Icons.palette,
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildNotificationItem(
                                      'Pick-up reminder: 3:30 PM today',
                                      'Scheduled in 45 minutes',
                                      Icons.schedule,
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

                        // Earlier Notifications Card
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
                                            Icons.history,
                                            color: primaryGreen,
                                            size: isMobile ? 16 : 18,
                                          ),
                                        ),
                                        SizedBox(width: isMobile ? 8 : 12),
                                        Text(
                                          'Earlier This Week',
                                          style: TextStyle(
                                            fontWeight: FontWeight.w600,
                                            fontSize: isMobile ? 15 : 16,
                                            color: black,
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: isMobile ? 8 : 12),
                                    _buildNotificationItem(
                                      'Great performance in spelling test',
                                      'Yesterday • 9/10 correct answers',
                                      Icons.star,
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildNotificationItem(
                                      'Field trip permission slip required',
                                      'Monday • Zoo visit next Friday',
                                      Icons.description,
                                      true,
                                      primaryGreen,
                                      black,
                                      isMobile,
                                    ),
                                    _buildNotificationItem(
                                      'Show and tell: Emma shared her teddy',
                                      'Monday • Spoke about her favorite toy',
                                      Icons.toys,
                                      true,
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

                        // Action Buttons
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryGreen,
                                  foregroundColor: white,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: isMobile ? 10 : 16,
                                  ),
                                  elevation: 2,
                                ),
                                icon: Icon(Icons.mark_email_read, size: 18),
                                label: Text('Mark All Read'),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(
                                        'All notifications marked as read',
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
                                  side: BorderSide(color: primaryGreen),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  padding: EdgeInsets.symmetric(
                                    vertical: isMobile ? 10 : 16,
                                  ),
                                ),
                                icon: Icon(Icons.settings, size: 18),
                                label: Text('Settings'),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Notification settings'),
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
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationItem(
    String message,
    String details,
    IconData icon,
    bool isRead,
    Color primaryGreen,
    Color black,
    bool isMobile,
  ) {
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 6 : 8),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: isRead ? Colors.white : greenWithOpacity,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color:
              isRead
                  ? primaryGreen.withOpacity(0.1)
                  : primaryGreen.withOpacity(0.3),
          width: 1,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            color: isRead ? primaryGreen : primaryGreen,
            size: isMobile ? 18 : 20,
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontWeight: FontWeight.w500,
                    fontSize: isMobile ? 14 : 16,
                    color: black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  details,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: black.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
          if (!isRead)
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: primaryGreen,
                shape: BoxShape.circle,
              ),
            ),
        ],
      ),
    );
  }
}
