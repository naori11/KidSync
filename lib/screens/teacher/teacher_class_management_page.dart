import 'package:flutter/material.dart';

class TeacherClassManagementPage extends StatelessWidget {
  const TeacherClassManagementPage({super.key});

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
                    "Mathematics 101 / Class Management",
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 18),
                  // Search and sort
                  Row(
                    children: [
                      Container(
                        width: 300,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Row(
                          children: [
                            Icon(Icons.search, color: Colors.grey.shade600, size: 20),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: TextField(
                                decoration: InputDecoration(
                                  hintText: 'Search students…',
                                  hintStyle: TextStyle(color: Colors.grey),
                                  border: InputBorder.none,
                                  isDense: true,
                                ),
                                style: TextStyle(fontSize: 14),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 16),
                      SizedBox(
                        height: 40,
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.import_export, size: 18),
                          label: const Text("Export List"),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 40,
                        child: OutlinedButton.icon(
                          onPressed: () {},
                          icon: const Icon(Icons.print, size: 18),
                          label: const Text("Print Report"),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        height: 40,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: Colors.grey.shade300),
                        ),
                        child: Row(
                          children: [
                            Text("Sort by: Last Name", style: TextStyle(fontSize: 14, color: Colors.grey.shade700)),
                            const Icon(Icons.arrow_drop_down, color: Colors.grey),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      IconButton(
                        icon: const Icon(Icons.view_list),
                        onPressed: () {},
                      ),
                      IconButton(
                        icon: const Icon(Icons.grid_view_rounded),
                        onPressed: () {},
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  // Table header
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    child: Row(
                      children: const [
                        SizedBox(width: 90, child: Text("Student ID", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                        Expanded(child: Text("Student Name", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                        SizedBox(width: 100, child: Text("Attendance Rate", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                        SizedBox(width: 110, child: Text("Last Attendance", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                        SizedBox(width: 80, child: Text("Status", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                        SizedBox(width: 75, child: Text("Actions", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                      ],
                    ),
                  ),
                  // Table rows
                  Expanded(
                    child: ListView(
                      children: [
                        _StudentTableRow(
                          id: "STU001",
                          name: "Alice Johnson",
                          attendanceRate: 95,
                          lastAttendance: "Feb 15, 2024",
                          status: "Present",
                          onView: () {},
                        ),
                        _StudentTableRow(
                          id: "STU002",
                          name: "Bob Smith",
                          attendanceRate: 88,
                          lastAttendance: "Feb 15, 2024",
                          status: "Absent",
                          onView: () {},
                        ),
                        _StudentTableRow(
                          id: "STU003",
                          name: "Carol Williams",
                          attendanceRate: 92,
                          lastAttendance: "Feb 15, 2024",
                          status: "Present",
                          onView: () {},
                        ),
                        _StudentTableRow(
                          id: "STU004",
                          name: "David Brown",
                          attendanceRate: 85,
                          lastAttendance: "Feb 15, 2024",
                          status: "Present",
                          onView: () {},
                        ),
                        _StudentTableRow(
                          id: "STU005",
                          name: "Emma Davis",
                          attendanceRate: 98,
                          lastAttendance: "Feb 15, 2024",
                          status: "Present",
                          onView: () {},
                        ),
                      ],
                    ),
                  ),
                  // Pagination
                  Row(
                    children: [
                      Text(
                        "Showing 1 to 5 of 25 students",
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                      const Spacer(),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_left, size: 18)),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF2ECC71),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: const Text("1", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        child: const Text("2", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.normal, fontSize: 13)),
                      ),
                      const SizedBox(width: 5),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                        child: const Text("3", style: TextStyle(color: Colors.black87, fontWeight: FontWeight.normal, fontSize: 13)),
                      ),
                      IconButton(onPressed: () {}, icon: const Icon(Icons.chevron_right, size: 18)),
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

class _StudentTableRow extends StatelessWidget {
  final String id;
  final String name;
  final int attendanceRate;
  final String lastAttendance;
  final String status;
  final VoidCallback onView;
  const _StudentTableRow({
    required this.id,
    required this.name,
    required this.attendanceRate,
    required this.lastAttendance,
    required this.status,
    required this.onView,
  });

  @override
  Widget build(BuildContext context) {
    final present = status == "Present";
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      child: Row(
        children: [
          SizedBox(width: 90, child: Text(id, style: const TextStyle(fontSize: 13))),
          Expanded(child: Text(name, style: const TextStyle(fontSize: 13))),
          SizedBox(
            width: 100,
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: attendanceRate / 100,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    color: present ? const Color(0xFF2ECC71) : Colors.red,
                  ),
                ),
                const SizedBox(width: 5),
                Text("$attendanceRate%", style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          SizedBox(width: 110, child: Text(lastAttendance, style: const TextStyle(fontSize: 13))),
          SizedBox(
            width: 80,
            child: Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(
                    color: present ? const Color(0xFF2ECC71) : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(status, style: TextStyle(color: present ? const Color(0xFF2ECC71) : Colors.red, fontWeight: FontWeight.w500, fontSize: 13)),
              ],
            ),
          ),
          SizedBox(
            width: 75,
            child: TextButton(
              onPressed: onView,
              child: const Text("View Details", style: TextStyle(color: Color(0xFF2563EB), fontSize: 13)),
            ),
          ),
        ],
      ),
    );
  }
}