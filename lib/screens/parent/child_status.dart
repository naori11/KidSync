import 'package:flutter/material.dart';

class ChildStatusScreen extends StatelessWidget {
  const ChildStatusScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    const Color primaryGreen = Color(0xFF19AE61);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);
    const Color white = Color(0xFFFFFFFF);

    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      appBar: AppBar(
        title: const Text(
          'Child Status',
          style: TextStyle(color: white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: primaryGreen,
        elevation: 0,
        shadowColor: const Color(0xFF000000).withOpacity(0.1),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Overview Card
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 4,
                shadowColor: const Color(0xFF000000).withOpacity(0.1),
                child: Container(
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFF000000).withOpacity(0.08),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(20),
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
                            boxShadow: [
                              BoxShadow(
                                color: primaryGreen.withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
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
                ),
              ),
            ),

            const SizedBox(height: 24),

            // Today's Timeline
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: greenWithOpacity,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(Icons.timeline, color: primaryGreen, size: 20),
                ),
                SizedBox(width: 8),
                Text(
                  "Today's Timeline",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: black,
                  ),
                ),
              ],
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
          ],
        ),
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
    Color greenWithOpacity,
    Color white,
  ) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 2,
        shadowColor: const Color(0xFF000000).withOpacity(0.05),
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFF000000).withOpacity(0.04),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color:
                        completed ? greenWithOpacity : const Color(0xFFF0F0F0),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: completed ? primaryGreen : black.withOpacity(0.5),
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
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: black,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activity,
                        style: TextStyle(
                          fontSize: 12,
                          color: black.withOpacity(0.7),
                        ),
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
          ),
        ),
      ),
    );
  }
}
