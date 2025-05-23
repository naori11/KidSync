import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kidsync/widgets/role_protection.dart';

class StudentManagementPageAdmin extends StatelessWidget {
  const StudentManagementPageAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleProtected(
      requiredRole: 'Admin',
      child: const StudentManagementPage(),
    );
  }
}

class StudentManagementPage extends StatefulWidget {
  const StudentManagementPage({super.key});

  @override
  State<StudentManagementPage> createState() => _StudentManagementPageState();
}

class _StudentManagementPageState extends State<StudentManagementPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> students = [];
  bool isLoading = false;
  String _searchQuery = '';
  String _sortOption = 'Alphabetical';

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() => isLoading = true);
    final response = await supabase
        .from('students')
        .select()
        .order('lname', ascending: true);
    setState(() {
      students = List<Map<String, dynamic>>.from(response);
      isLoading = false;
    });
  }

  Future<void> _addOrEditStudent({Map<String, dynamic>? student}) async {
    String? fname = student?['fname'];
    String? mname = student?['mname'];
    String? lname = student?['lname'];
    String? gender = student?['gender'];
    String? address = student?['address'];
    String? birthday = student?['birthday'];
    String? grade = student?['grade_level'];
    String? section = student?['section_id']?.toString();

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(student == null ? 'Add Student' : 'Edit Student'),
          content: SingleChildScrollView(
            child: Column(
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'First Name'),
                  controller: TextEditingController(text: fname),
                  onChanged: (val) => fname = val,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Middle Name'),
                  controller: TextEditingController(text: mname),
                  onChanged: (val) => mname = val,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  controller: TextEditingController(text: lname),
                  onChanged: (val) => lname = val,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Gender'),
                  controller: TextEditingController(text: gender),
                  onChanged: (val) => gender = val,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Address'),
                  controller: TextEditingController(text: address),
                  onChanged: (val) => address = val,
                ),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Birthday (YYYY-MM-DD)',
                  ),
                  controller: TextEditingController(text: birthday),
                  onChanged: (val) => birthday = val,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Grade Level'),
                  controller: TextEditingController(text: grade),
                  onChanged: (val) => grade = val,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Section ID'),
                  controller: TextEditingController(text: section),
                  onChanged: (val) => section = val,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () async {
                final payload = {
                  'fname': fname,
                  'mname': mname,
                  'lname': lname,
                  'gender': gender,
                  'address': address,
                  'birthday': birthday,
                  'grade_level': grade,
                  'section_id': section,
                };
                if (student == null) {
                  await supabase.from('students').insert(payload);
                } else {
                  await supabase
                      .from('students')
                      .update(payload)
                      .eq('id', student['id']);
                }
                Navigator.pop(context);
                _fetchStudents();
              },
              child: Text(student == null ? 'Add' : 'Update'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _deleteStudent(int id) async {
    await supabase.from('students').delete().eq('id', id);
    _fetchStudents();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isAdmin =
        user?.userMetadata?['role'] == 'Admin';

    // Filtering & sorting
    var filteredStudents =
        students.where((s) {
          final name = "${s['fname']} ${s['lname']}".toLowerCase();
          return name.contains(_searchQuery.toLowerCase());
        }).toList();

    if (_sortOption == 'Alphabetical') {
      filteredStudents.sort(
        (a, b) => (a['lname'] ?? '').compareTo(b['lname'] ?? ''),
      );
    } else if (_sortOption == 'Per Class') {
      filteredStudents.sort(
        (a, b) => (a['grade_level'] ?? '').compareTo(b['grade_level'] ?? ''),
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "Student Management",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: isAdmin ? () => _addOrEditStudent() : null,
                  child: const Text("+ Add Student"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search students...',
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _sortOption,
                  onChanged: (val) => setState(() => _sortOption = val!),
                  items:
                      ['Alphabetical', 'Per Class']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('ID')),
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Gender')),
                      DataColumn(label: Text('Class')),
                      DataColumn(label: Text('Birthday')),
                      DataColumn(label: Text('Address')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows:
                        filteredStudents.map((s) {
                          final fullName =
                              "${s['fname'] ?? ''} ${s['mname'] ?? ''} ${s['lname'] ?? ''}";
                          return DataRow(
                            cells: [
                              DataCell(Text(s['id'].toString())),
                              DataCell(Text(fullName)),
                              DataCell(Text(s['gender'] ?? '')),
                              DataCell(
                                Text(
                                  'Grade ${s['grade_level'] ?? '-'} Sec. ${s['section_id'] ?? '-'}',
                                ),
                              ),
                              DataCell(
                                Text(
                                  s['birthday']?.toString()?.substring(0, 10) ??
                                      '',
                                ),
                              ),
                              DataCell(Text(s['address'] ?? '')),
                              DataCell(
                                isAdmin
                                    ? PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          _addOrEditStudent(student: s);
                                        } else if (value == 'delete') {
                                          showDialog(
                                            context: context,
                                            builder:
                                                (ctx) => AlertDialog(
                                                  title: const Text(
                                                    'Confirm Delete',
                                                  ),
                                                  content: const Text(
                                                    'Are you sure you want to delete this student?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            ctx,
                                                          ),
                                                      child: const Text(
                                                        'Cancel',
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () {
                                                        Navigator.pop(ctx);
                                                        _deleteStudent(s['id']);
                                                      },
                                                      child: const Text(
                                                        'Delete',
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                          );
                                        }
                                      },
                                      itemBuilder:
                                          (context) => [
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: Text('Edit'),
                                            ),
                                            const PopupMenuItem(
                                              value: 'delete',
                                              child: Text('Delete'),
                                            ),
                                          ],
                                    )
                                    : const Text('-'),
                              ),
                            ],
                          );
                        }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
