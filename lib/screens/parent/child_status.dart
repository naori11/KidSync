import 'package:flutter/material.dart';

class ChildStatusScreen extends StatelessWidget {
  const ChildStatusScreen({Key? key}) : super(key: key);

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
          'Child Status',
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
            // Status Overview Card
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: greenWithOpacity,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: primaryGreen, width: 1),
              ),
              child: Column(
                children: [
                  Icon(Icons.school, size: 48, color: primaryGreen),
                  const SizedBox(height: 16),
                  Text(
                    'Current Status',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: black,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: primaryGreen,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      'Present',
                      style: TextStyle(
                        color: white,
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // Today's Timeline
            Text(
              "Today's Timeline",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: black,
              ),
            ),

            const SizedBox(height: 16),

            // Timeline Items
            Expanded(
              child: ListView(
                children: [
                  _buildTimelineItem(
                    '8:00 AM',
                    'Arrived at School',
                    Icons.login,
                    true,
                    primaryGreen,
                    black,
                    greenWithOpacity,
                    white,
                  ),
                  const SizedBox(height: 12),
                  _buildTimelineItem(
                    '9:00 AM',
                    'Class Started',
                    Icons.class_,
                    true,
                    primaryGreen,
                    black,
                    greenWithOpacity,
                    white,
                  ),
                  const SizedBox(height: 12),
                  _buildTimelineItem(
                    '12:00 PM',
                    'Lunch Break',
                    Icons.restaurant,
                    true,
                    primaryGreen,
                    black,
                    greenWithOpacity,
                    white,
                  ),
                  const SizedBox(height: 12),
                  _buildTimelineItem(
                    '3:30 PM',
                    'Pick-up Time',
                    Icons.directions_car,
                    false,
                    primaryGreen,
                    black,
                    greenWithOpacity,
                    white,
                  ),
                ],
              ),
            ),

            // Refresh Button
            ElevatedButton.icon(
              onPressed: () {
                // TODO: Implement refresh status
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Status refreshed'),
                    backgroundColor: primaryGreen,
                  ),
                );
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Refresh Status'),
              style: ElevatedButton.styleFrom(
                backgroundColor: primaryGreen,
                foregroundColor: white,
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

  Widget _buildTimelineItem(
    String time,
    String event,
    IconData icon,
    bool completed,
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
              color: completed ? primaryGreen : greenWithOpacity,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: completed ? white : primaryGreen,
              size: 20,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  time,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: black,
                  ),
                ),
                Text(
                  event,
                  style: TextStyle(fontSize: 12, color: black.withOpacity(0.7)),
                ),
              ],
            ),
          ),
          Icon(
            completed ? Icons.check_circle : Icons.schedule,
            color: completed ? primaryGreen : black.withOpacity(0.3),
            size: 20,
          ),
        ],
      ),
    );
  }
}
