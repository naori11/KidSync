import 'package:flutter/material.dart';

class TeacherClassListPage extends StatelessWidget {
  const TeacherClassListPage({super.key});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F5),
      body: Row(
        children: [
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "My Classes",
                    style: TextStyle(
                      fontSize: 23,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Column(
                    children: [
                      _ClassListCard(
                        title: "Mathematics 101",
                        time: "09:00 AM - 10:30 AM",
                        students: 25,
                        status: "Ongoing",
                        statusColor: const Color(0xFF2ECC71),
                        onPressed: () {},
                      ),
                      const SizedBox(height: 12),
                      _ClassListCard(
                        title: "Physics Advanced",
                        time: "11:00 AM - 12:30 PM",
                        students: 20,
                        status: "Ongoing",
                        statusColor: const Color(0xFF2ECC71),
                        onPressed: () {},
                      ),
                      const SizedBox(height: 12),
                      _ClassListCard(
                        title: "Chemistry Lab",
                        time: "01:30 PM - 03:30 PM",
                        students: 22,
                        status: "Upcoming",
                        statusColor: Colors.orange,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _ClassListCard extends StatelessWidget {
  final String title;
  final String time;
  final int students;
  final String status;
  final Color statusColor;
  final VoidCallback onPressed;
  const _ClassListCard({
    required this.title,
    required this.time,
    required this.students,
    required this.status,
    required this.statusColor,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 18),
        width: double.infinity,
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    time,
                    style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    "Total Students: $students",
                    style: TextStyle(fontSize: 13, color: Colors.grey[700]),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.13),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                status,
                style: TextStyle(
                  color: statusColor,
                  fontWeight: FontWeight.w500,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(width: 20),
            SizedBox(
              height: 34,
              child: ElevatedButton(
                onPressed: onPressed,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(6),
                  ),
                  elevation: 0,
                ),
                child: const Text("View Details", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}