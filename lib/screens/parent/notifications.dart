import 'package:flutter/material.dart';

class ParentNotificationsScreen extends StatelessWidget {
  const ParentNotificationsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF19AE61);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.6);
    const Color white = Color(0xFFFFFFFF);

    return Scaffold(
      backgroundColor: white,
      appBar: AppBar(
        title: const Text(
          'Notifications',
          style: TextStyle(color: white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryGreen,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: greenWithOpacity,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(Icons.notifications, color: primaryGreen, size: 24),
                  const SizedBox(width: 12),
                  Text(
                    'Recent Notifications',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: black,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Notifications List
            Expanded(
              child: ListView(
                children: [
                  _buildNotificationCard(
                    'Student arrived safely at school',
                    '2h ago',
                    Icons.check_circle,
                    primaryGreen,
                    black,
                    greenWithOpacity,
                    white,
                  ),
                  const SizedBox(height: 12),
                  _buildNotificationCard(
                    'Pick-up will be at 3:30 PM today',
                    '1h ago',
                    Icons.schedule,
                    primaryGreen,
                    black,
                    greenWithOpacity,
                    white,
                  ),
                  const SizedBox(height: 12),
                  _buildNotificationCard(
                    'New fetcher added to authorized list',
                    '30m ago',
                    Icons.person_add,
                    primaryGreen,
                    black,
                    greenWithOpacity,
                    white,
                  ),
                  const SizedBox(height: 12),
                  _buildNotificationCard(
                    'Drop-off confirmed for today',
                    '15m ago',
                    Icons.directions_car,
                    primaryGreen,
                    black,
                    greenWithOpacity,
                    white,
                  ),
                ],
              ),
            ),

            // Clear All Button
            OutlinedButton.icon(
              onPressed: () {
                // TODO: Implement clear all notifications
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('All notifications cleared'),
                    backgroundColor: primaryGreen,
                  ),
                );
              },
              icon: const Icon(Icons.clear_all),
              label: const Text('Clear All'),
              style: OutlinedButton.styleFrom(
                foregroundColor: primaryGreen,
                side: BorderSide(color: primaryGreen),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildNotificationCard(
    String message,
    String time,
    IconData icon,
    Color primaryGreen,
    Color black,
    Color greenWithOpacity,
    Color white,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryGreen, width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: greenWithOpacity,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: primaryGreen, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: black,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  time,
                  style: TextStyle(fontSize: 12, color: black.withOpacity(0.6)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
