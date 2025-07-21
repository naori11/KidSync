import 'package:flutter/material.dart';

class TeacherStudentAttendanceCalendarPage extends StatelessWidget {
  const TeacherStudentAttendanceCalendarPage({super.key});

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
                  // Header
                  const Text(
                    "Mathematics 101 / Attendance",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 20),
                  // Student Info
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey[300],
                        radius: 28,
                        child: const Icon(Icons.person, size: 34, color: Colors.white),
                      ),
                      const SizedBox(width: 18),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: const [
                          Text("James Wilson", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          Text("Grade 8-A", style: TextStyle(fontSize: 14, color: Colors.grey)),
                          Text("Student ID: ST2024001", style: TextStyle(fontSize: 13, color: Colors.grey)),
                        ],
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: const [
                          Text("92% ", style: TextStyle(fontSize: 20, color: Color(0xFF2ECC71), fontWeight: FontWeight.bold)),
                          Text("Present", style: TextStyle(fontSize: 14, color: Color(0xFF2ECC71))),
                          SizedBox(height: 2),
                          Text("5% ", style: TextStyle(fontSize: 14, color: Colors.red, fontWeight: FontWeight.bold)),
                          Text("Absent", style: TextStyle(fontSize: 14, color: Colors.red)),
                          SizedBox(height: 2),
                          Text("3% ", style: TextStyle(fontSize: 14, color: Colors.orange, fontWeight: FontWeight.bold)),
                          Text("Late", style: TextStyle(fontSize: 14, color: Colors.orange)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Calendar controls
                  Row(
                    children: [
                      IconButton(icon: const Icon(Icons.chevron_left), onPressed: () {}),
                      const SizedBox(width: 10),
                      const Text("November 2023", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                      const SizedBox(width: 10),
                      IconButton(icon: const Icon(Icons.chevron_right), onPressed: () {}),
                      const Spacer(),
                      SizedBox(
                        height: 34,
                        child: ElevatedButton(
                          onPressed: () {},
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2563EB),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                            elevation: 0,
                          ),
                          child: const Text("+ Mark Excuse", style: TextStyle(fontSize: 13, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  // Calendar grid
                  Expanded(
                    child: _StaticAttendanceCalendar(),
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

class _StaticAttendanceCalendar extends StatelessWidget {
  // 5 weeks, 7 days per week
  // This can be easily replaced with a dynamic calendar widget with real data
  @override
  Widget build(BuildContext context) {
    return Column(
      children: List.generate(5, (week) {
        return Row(
          children: List.generate(7, (day) {
            final status = (week == 1 && day == 2) ? "absent"
                : (week == 2 && day == 0) ? "late"
                : "present";
            final color = status == "present"
                ? const Color(0xFF2ECC71)
                : status == "absent"
                  ? Colors.red
                  : Colors.orange;
            return Expanded(
              child: Container(
                margin: const EdgeInsets.all(4),
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey[300]!),
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Column(
                  children: [
                    Text(
                      "${week * 7 + day + 1}",
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 8, height: 8,
                          decoration: BoxDecoration(
                            color: color,
                            shape: BoxShape.circle,
                          ),
                        ),
                        const SizedBox(width: 5),
                        Text(
                          status[0].toUpperCase() + status.substring(1),
                          style: TextStyle(
                            color: color,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text("08:30 AM", style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                    Text("03:30 PM", style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                  ],
                ),
              ),
            );
          }),
        );
      }),
    );
  }
}