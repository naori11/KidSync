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
      backgroundColor: Colors.white,
      body: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 8),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          if (widget.onBack != null)
                            Padding(
                              padding: const EdgeInsets.only(right: 12.0),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.arrow_back_ios_new_rounded,
                                  size: 20,
                                  color: Color(0xFF7C8DB5),
                                ),
                                onPressed: widget.onBack,
                                tooltip: 'Back',
                                splashRadius: 20,
                                alignment: Alignment.center,
                              ),
                            ),
                          Text(
                            "${widget.sectionName} / Class Management",
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF222B45),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                        border: Border.all(color: Color(0xFFF1F1F4)),
                      ),
                      child: Column(
                        children: [
                          Container(
                            decoration: const BoxDecoration(
                              color: Color(0xFFF9FAFB),
                              borderRadius: BorderRadius.vertical(
                                top: Radius.circular(14),
                              ),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 28,
                              vertical: 18,
                            ),
                            child: Row(
                              children: const [
                                SizedBox(
                                  width: 90,
                                  child: Text(
                                    "Student ID",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Color(0xFF222B45),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 160,
                                  child: Text(
                                    "Student Name",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Color(0xFF222B45),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 120,
                                  child: Text(
                                    "Attendance Rate",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Color(0xFF222B45),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 140,
                                  child: Text(
                                    "Last Attendance",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Color(0xFF222B45),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    "Status",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Color(0xFF222B45),
                                    ),
                                  ),
                                ),
                                SizedBox(
                                  width: 100,
                                  child: Text(
                                    "Actions",
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 15,
                                      color: Color(0xFF222B45),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (isLoading)
                            const Padding(
                              padding: EdgeInsets.all(32),
                              child: Center(child: CircularProgressIndicator()),
                            )
                          else
                            ...List.generate(students.length, (index) {
                              final student = students[index];
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
                                isEven: index % 2 == 0,
                              );
                            }),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
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
  final bool isEven;
  const _StudentTableRow({
    required this.id,
    required this.name,
    required this.attendanceRate,
    required this.lastAttendance,
    required this.status,
    required this.onView,
    this.isEven = false,
  });

  @override
  Widget build(BuildContext context) {
    final present = status == "Present";
    return Container(
      decoration: BoxDecoration(
        color: isEven ? const Color(0xFFF9FAFB) : Colors.white,
        border: const Border(
          bottom: BorderSide(color: Color(0xFFF1F1F4), width: 1),
        ),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 18),
      margin: EdgeInsets.zero,
      child: Row(
        children: [
          SizedBox(
            width: 90,
            child: Text(id, style: const TextStyle(fontSize: 13)),
          ),
          SizedBox(
            width: 160,
            child: Text(
              name,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Color(0xFF222B45),
              ),
            ),
          ),
          SizedBox(
            width: 120,
            child: Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: attendanceRate / 100,
                    minHeight: 6,
                    backgroundColor: Colors.grey[200],
                    color: present ? Color(0xFF19AE61) : Colors.red,
                  ),
                ),
                const SizedBox(width: 5),
                Text("$attendanceRate%", style: const TextStyle(fontSize: 13)),
              ],
            ),
          ),
          SizedBox(
            width: 140,
            child: Text(lastAttendance, style: const TextStyle(fontSize: 13)),
          ),
          SizedBox(
            width: 100,
            child: Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: present ? Color(0xFF19AE61) : Colors.red,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 5),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color:
                        present
                            ? const Color(0xFF19AE61).withOpacity(0.12)
                            : Colors.red.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    status,
                    style: TextStyle(
                      color: present ? Color(0xFF19AE61) : Colors.red,
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      letterSpacing: 0.1,
                    ),
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 100,
            child: TextButton(
              onPressed: onView,
              child: Text(
                "View Details",
                style: TextStyle(color: Color(0xFF19AE61), fontSize: 13),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
