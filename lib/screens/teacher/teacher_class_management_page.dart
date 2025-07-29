import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

const _avatarImages = [
  "https://randomuser.me/api/portraits/women/1.jpg",
  "https://randomuser.me/api/portraits/men/2.jpg",
  "https://randomuser.me/api/portraits/women/3.jpg",
  "https://randomuser.me/api/portraits/men/4.jpg",
  "https://randomuser.me/api/portraits/women/5.jpg",
];

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
  int currentPage = 1;
  static const int rowsPerPage = 5;
  String searchQuery = "";
  String sortBy = "Last Name";
  bool sortAsc = true;

  @override
  void initState() {
    super.initState();
    _loadAttendanceGrid();
  }

  Future<void> _loadAttendanceGrid() async {
    setState(() => isLoading = true);
    // 1. Fetch all students in this section
    final studentList = await supabase
        .from('students')
        .select('id, fname, lname, rfid_uid')
        .eq('section_id', widget.sectionId);

    // 2. Collect student IDs
    final studentIds = [for (final s in studentList) s['id'] as int];
    if (studentIds.isEmpty) {
      students = [];
      setState(() => isLoading = false);
      return;
    }

    // 3. Fetch scan_records for all students in this section (limit to last 30 days for performance)
    final since = DateTime.now().subtract(const Duration(days: 30));
    final scanRecords = await supabase
        .from('scan_records')
        .select('id, student_id, scan_time, action, status')
        .inFilter('student_id', studentIds)
        .gte('scan_time', since.toIso8601String())
        .order('scan_time', ascending: false);

    // 4. Map studentId to their scanRecords
    final Map<int, List<Map<String, dynamic>>> recordsByStudent = {};
    for (final s in studentIds) {
      recordsByStudent[s] = [];
    }
    for (final record in scanRecords) {
      final sid = record['student_id'] as int;
      recordsByStudent[sid]?.add(record);
    }

    // 5. Today's date
    final now = DateTime.now().toUtc();
    final today = DateTime.utc(now.year, now.month, now.day);

    // 6. Compute attendance info for each student
    students = [];
    int i = 0;
    for (final student in studentList) {
      final sid = student['id'] as int;
      final List<Map<String, dynamic>> scans = recordsByStudent[sid] ?? [];

      // Attendance Days: group by date
      final daysPresent = <String, bool>{};
      String lastAttendance = 'None';
      String status = 'Absent';

      // Get the most recent scan (for lastAttendance)
      if (scans.isNotEmpty) {
        final latestScan = scans.first;
        lastAttendance = DateFormat(
          "MMM d, yyyy",
        ).format(DateTime.tryParse(latestScan['scan_time']) ?? DateTime.now());
      }

      // For attendance rate: count unique days with entry/check-in
      for (final r in scans) {
        final scanTime = DateTime.tryParse(r['scan_time']);
        if (scanTime == null) continue;
        final action = r['action']?.toString().toLowerCase();
        // Accept entry/check-in as present
        if (action == 'entry') {
          final dayStr = DateFormat('yyyy-MM-dd').format(scanTime.toUtc());
          daysPresent[dayStr] = true;
        }
      }

      int attendanceRate =
          scans.isEmpty
              ? 0
              : ((daysPresent.length / 30) * 100).round().clamp(0, 100);

      // Status: Present if entry today, Absent otherwise
      final hasEntryToday = scans.any((r) {
        final scanTime = DateTime.tryParse(r['scan_time']);
        final action = r['action']?.toString().toLowerCase();
        return action == 'entry' &&
            scanTime != null &&
            scanTime.toUtc().year == today.year &&
            scanTime.toUtc().month == today.month &&
            scanTime.toUtc().day == today.day;
      });
      status = hasEntryToday ? 'Present' : 'Absent';

      students.add({
        'id': student['id'],
        'rfid_uid': student['rfid_uid'] ?? 'N/A',
        'fname': student['fname'],
        'lname': student['lname'],
        'avatar': _avatarImages[i % _avatarImages.length],
        'attendanceRate': attendanceRate,
        'lastAttendance': lastAttendance,
        'status': status,
      });
      i++;
    }

    setState(() => isLoading = false);
  }

  List<Map<String, dynamic>> get _filteredSortedStudents {
    List<Map<String, dynamic>> filtered =
        students.where((student) {
          final name = "${student['fname']} ${student['lname']}".toLowerCase();
          return searchQuery.isEmpty ||
              name.contains(searchQuery.toLowerCase());
        }).toList();

    filtered.sort((a, b) {
      int res;
      switch (sortBy) {
        case "Last Name":
          res = (a['lname'] as String).compareTo(b['lname'] as String);
          break;
        case "Attendance Rate":
          res = (b['attendanceRate'] as int).compareTo(
            a['attendanceRate'] as int,
          );
          break;
        default:
          res = (a['lname'] as String).compareTo(b['lname'] as String);
      }
      return sortAsc ? res : -res;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final totalRows = _filteredSortedStudents.length;
    final totalPages = (totalRows / rowsPerPage).ceil();
    final studentsToShow =
        _filteredSortedStudents
            .skip((currentPage - 1) * rowsPerPage)
            .take(rowsPerPage)
            .toList();

    return Scaffold(
      backgroundColor: const Color(0xF7F9FCFF),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Section: Title, Export, Print, X button
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 24, 32, 0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Section name and header
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.sectionName,
                        style: const TextStyle(
                          fontSize: 13,
                          color: Color(0xFF8F9BB3),
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      const Text(
                        "Class Management",
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF222B45),
                        ),
                      ),
                    ],
                  ),
                ),
                // Export/Print
                OutlinedButton.icon(
                  icon: const Icon(Icons.download_outlined, size: 18),
                  label: const Text("Export List"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF2E3A59),
                    side: const BorderSide(color: Color(0xFFE4E9F2)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () {},
                ),
                const SizedBox(width: 10),
                OutlinedButton.icon(
                  icon: const Icon(Icons.print, size: 18),
                  label: const Text("Print Report"),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Color(0xFF2E3A59),
                    side: const BorderSide(color: Color(0xFFE4E9F2)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 10,
                    ),
                    textStyle: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  onPressed: () {},
                ),
                const SizedBox(width: 12),
                IconButton(
                  icon: const Icon(
                    Icons.close_rounded,
                    size: 26,
                    color: Color(0xFF8F9BB3),
                  ),
                  tooltip: 'Close',
                  splashRadius: 22,
                  onPressed:
                      widget.onBack ?? () => Navigator.of(context).maybePop(),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          // Search, Sort, View toggle
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Row(
              children: [
                // Search box
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: Color(0xFFE4E9F2)),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: TextField(
                      onChanged:
                          (v) => setState(() {
                            searchQuery = v;
                            currentPage = 1;
                          }),
                      style: const TextStyle(fontSize: 15),
                      decoration: InputDecoration(
                        prefixIcon: Icon(
                          Icons.search,
                          color: Color(0xFF8F9BB3),
                        ),
                        hintText: "Search students...",
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: 12,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                // Sort by dropdown
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 0,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Color(0xFFE4E9F2)),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: sortBy,
                      borderRadius: BorderRadius.circular(8),
                      style: const TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Color(0xFF2E3A59),
                        fontSize: 13,
                      ),
                      items: const [
                        DropdownMenuItem(
                          value: "Last Name",
                          child: Text("Sort by: Last Name"),
                        ),
                        DropdownMenuItem(
                          value: "Attendance Rate",
                          child: Text("Sort by: Attendance Rate"),
                        ),
                      ],
                      onChanged: (v) {
                        if (v != null) setState(() => sortBy = v);
                      },
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // View toggles (not functional, just for show)
                ToggleButtons(
                  borderRadius: BorderRadius.circular(8),
                  color: Color(0xFF8F9BB3),
                  selectedColor: Color(0xFF222B45),
                  fillColor: Color(0xFFEDF1F7),
                  constraints: const BoxConstraints(
                    minWidth: 38,
                    minHeight: 38,
                  ),
                  isSelected: const [true, false],
                  onPressed: (_) {},
                  children: const [
                    Icon(Icons.table_rows_rounded, size: 20),
                    Icon(Icons.grid_view_rounded, size: 20),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          // Table
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                color: Colors.white,
                margin: EdgeInsets.zero,
                elevation: 0,
                child: Column(
                  children: [
                    // Table Header
                    Padding(
                      padding: const EdgeInsets.only(
                        top: 18,
                        left: 16,
                        right: 16,
                        bottom: 8,
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: const [
                          _TableHeader(
                            "Student ID",
                            flex: 2,
                            alignment: Alignment.centerLeft,
                          ),
                          _TableHeader(
                            "Student Name",
                            flex: 3,
                            alignment: Alignment.centerLeft,
                          ),
                          _TableHeader(
                            "Last Name",
                            flex: 2,
                            alignment: Alignment.centerLeft,
                          ),
                          _TableHeader(
                            "Attendance Rate",
                            flex: 3,
                            alignment: Alignment.centerLeft,
                          ),
                          _TableHeader(
                            "Last Attendance",
                            flex: 3,
                            alignment: Alignment.centerLeft,
                          ),
                          _TableHeader(
                            "Status",
                            flex: 2,
                            alignment: Alignment.centerLeft,
                          ),
                          _TableHeader(
                            "Actions",
                            flex: 2,
                            alignment: Alignment.centerLeft,
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
                      Expanded(
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          itemCount: studentsToShow.length,
                          itemBuilder: (context, index) {
                            final student = studentsToShow[index];
                            return _StudentTableRow(
                              id: student['rfid_uid'],
                              fname: student['fname'],
                              lname: student['lname'],
                              avatar: student['avatar'],
                              attendanceRate: student['attendanceRate'],
                              lastAttendance: student['lastAttendance'],
                              status: student['status'],
                              onView:
                                  () => widget.onStudentView?.call(
                                    student['id'],
                                    "${student['fname']} ${student['lname']}",
                                  ),
                              isEven: index % 2 == 0,
                            );
                          },
                        ),
                      ),
                    // Pagination + entry count
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      child: Row(
                        children: [
                          Text(
                            "Showing ${(totalRows == 0 ? 0 : ((currentPage - 1) * rowsPerPage + 1))} to ${(totalRows == 0 ? 0 : ((currentPage * rowsPerPage).clamp(1, totalRows)))} of $totalRows students",
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8F9BB3),
                            ),
                          ),
                          const Spacer(),
                          _Pagination(
                            totalPages: totalPages,
                            currentPage: currentPage,
                            onPageChanged:
                                (p) => setState(() => currentPage = p),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TableHeader extends StatelessWidget {
  final String text;
  final int flex;
  final Alignment alignment;
  const _TableHeader(
    this.text, {
    this.flex = 1,
    this.alignment = Alignment.centerLeft,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      flex: flex,
      child: Align(
        alignment: alignment,
        child: Text(
          text,
          style: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: Color(0xFF2E3A59),
          ),
        ),
      ),
    );
  }
}

class _StudentTableRow extends StatelessWidget {
  final String id;
  final String fname;
  final String lname;
  final String avatar;
  final int attendanceRate;
  final String lastAttendance;
  final String status;
  final VoidCallback onView;
  final bool isEven;
  const _StudentTableRow({
    required this.id,
    required this.fname,
    required this.lname,
    required this.avatar,
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
      color: isEven ? const Color(0xFFF7F9FC) : Colors.white,
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Student ID
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(id, style: const TextStyle(fontSize: 14)),
            ),
          ),
          // Student Name with avatar
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundImage: NetworkImage(avatar),
                    radius: 18,
                  ),
                  const SizedBox(width: 10),
                  Text(
                    fname,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFF222B45),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Last Name
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                lname,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w400,
                  color: Color(0xFF222B45),
                ),
              ),
            ),
          ),
          // Attendance Rate
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Row(
                children: [
                  Expanded(
                    child: LinearProgressIndicator(
                      value: attendanceRate / 100,
                      minHeight: 7,
                      backgroundColor: Colors.grey[200],
                      color: const Color(0xFF19AE61),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    "$attendanceRate%",
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Last Attendance
          Expanded(
            flex: 3,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(lastAttendance, style: const TextStyle(fontSize: 14)),
            ),
          ),
          // Status
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color:
                      present
                          ? const Color(0xFFD9FBE8)
                          : const Color(0xFFFBE9E9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Text(
                  present ? "Present" : "Absent",
                  style: TextStyle(
                    color:
                        present
                            ? const Color(0xFF19AE61)
                            : const Color(0xFFEB5757),
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ),
          // Actions
          Expanded(
            flex: 2,
            child: Align(
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                onTap: onView,
                child: const Text(
                  "View Details",
                  style: TextStyle(
                    color: Color(0xFF2563EB),
                    decoration: TextDecoration.underline,
                    fontWeight: FontWeight.w500,
                    fontSize: 14,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pagination extends StatelessWidget {
  final int totalPages;
  final int currentPage;
  final void Function(int) onPageChanged;
  const _Pagination({
    required this.totalPages,
    required this.currentPage,
    required this.onPageChanged,
  });

  @override
  Widget build(BuildContext context) {
    if (totalPages <= 1) return const SizedBox();
    List<Widget> pages = [];
    for (int i = 1; i <= totalPages; i++) {
      if (i == 1 ||
          i == totalPages ||
          (i >= currentPage - 1 && i <= currentPage + 1)) {
        pages.add(
          GestureDetector(
            onTap: () => onPageChanged(i),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color:
                    currentPage == i
                        ? const Color(0xFF2563EB)
                        : Colors.transparent,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                "$i",
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color:
                      currentPage == i ? Colors.white : const Color(0xFF222B45),
                  fontSize: 14,
                ),
              ),
            ),
          ),
        );
      } else if (i == currentPage - 2 || i == currentPage + 2) {
        pages.add(
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 2),
            child: Text("...", style: TextStyle(color: Color(0xFF8F9BB3))),
          ),
        );
      }
    }
    return Row(
      children: [
        IconButton(
          onPressed:
              currentPage > 1 ? () => onPageChanged(currentPage - 1) : null,
          icon: const Icon(Icons.chevron_left, size: 20),
          color: const Color(0xFF222B45),
        ),
        ...pages,
        IconButton(
          onPressed:
              currentPage < totalPages
                  ? () => onPageChanged(currentPage + 1)
                  : null,
          icon: const Icon(Icons.chevron_right, size: 20),
          color: const Color(0xFF222B45),
        ),
      ],
    );
  }
}
