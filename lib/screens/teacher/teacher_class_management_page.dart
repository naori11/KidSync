import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class TeacherClassManagementPage extends StatefulWidget {
  final int sectionId;
  final String sectionName;
  final void Function(int studentId, String studentName)? onStudentView;
  final VoidCallback? onBack;

  const TeacherClassManagementPage({
    Key? key,
    required this.sectionId,
    required this.sectionName,
    this.onStudentView,
    this.onBack,
  }) : super(key: key);

  @override
  State<TeacherClassManagementPage> createState() =>
      _TeacherClassManagementPageState();
}

class _TeacherClassManagementPageState
    extends State<TeacherClassManagementPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> students = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAttendanceGrid();
  }

  Future<void> _loadAttendanceGrid() async {
    setState(() => isLoading = true);

    final studentList = await supabase
        .from('students')
        .select('id, fname, lname, rfid_uid')
        .eq('section_id', widget.sectionId);

    students = [];
    for (final student in studentList) {
      final scanRecords = await supabase
          .from('scan_records')
          .select('scan_time, status')
          .eq('student_id', student['id'])
          .order('scan_time', ascending: false)
          .limit(30);

      int presentDays =
          scanRecords.where((r) => r['status'] == 'Present').length;
      int absentDays = scanRecords.where((r) => r['status'] == 'Absent').length;
      int lateDays = scanRecords.where((r) => r['status'] == 'Late').length;
      int totalDays = scanRecords.length > 0 ? scanRecords.length : 1;
      int attendanceRate = ((presentDays / totalDays) * 100).round();
      String lastAttendance =
          scanRecords.isNotEmpty
              ? scanRecords.first['scan_time'].toString().split(' ')[0]
              : 'None';
      String status =
          scanRecords.isNotEmpty
              ? scanRecords.first['status'] ?? 'Absent'
              : 'Absent';

      students.add({
        'id': student['id'],
        'rfid_uid': student['rfid_uid'] ?? 'N/A',
        'name': "${student['fname']} ${student['lname']}",
        'attendanceRate': attendanceRate,
        'lastAttendance': lastAttendance,
        'status': status,
      });
    }

    setState(() => isLoading = false);
  }

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
                  Row(
                    children: [
                      if (widget.onBack != null)
                        TextButton.icon(
                          icon: const Icon(Icons.arrow_back),
                          label: const Text("Back"),
                          onPressed: widget.onBack,
                        ),
                      Text(
                        "${widget.sectionName} / Class Management",
                        style: const TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Container(
                    color: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      children: const [
                        SizedBox(
                          width: 90,
                          child: Text(
                            "Student ID",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Text(
                            "Student Name",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 100,
                          child: Text(
                            "Attendance Rate",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 110,
                          child: Text(
                            "Last Attendance",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 80,
                          child: Text(
                            "Status",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                        SizedBox(
                          width: 75,
                          child: Text(
                            "Actions",
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    child:
                        isLoading
                            ? const Center(child: CircularProgressIndicator())
                            : ListView(
                              children:
                                  students.map((student) {
                                    return _StudentTableRow(
                                      id: student['rfid_uid'],
                                      name: student['name'],
                                      attendanceRate: student['attendanceRate'],
                                      lastAttendance: student['lastAttendance'],
                                      status: student['status'],
                                      onView:
                                          () => widget.onStudentView?.call(
                                            student['id'],
                                            student['name'],
                                          ),
                                    );
                                  }).toList(),
                            ),
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
          SizedBox(
            width: 90,
            child: Text(id, style: const TextStyle(fontSize: 13)),
          ),
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
          SizedBox(
            width: 110,
            child: Text(lastAttendance, style: const TextStyle(fontSize: 13)),
          ),
          SizedBox(
            width: 80,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: present ? const Color(0xFF2ECC71) : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Text(
                  status,
                  style: TextStyle(
                    color: present ? const Color(0xFF2ECC71) : Colors.red,
                    fontWeight: FontWeight.w500,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 75,
            child: TextButton(
              onPressed: onView,
              child: const Text(
                "View Details",
                style: TextStyle(color: Color(0xFF2563EB), fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
