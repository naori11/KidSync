import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SectionManagementPage extends StatefulWidget {
  const SectionManagementPage({super.key});

  @override
  State<SectionManagementPage> createState() => _SectionManagementPageState();
}

class _SectionManagementPageState extends State<SectionManagementPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> sections = [];
  List<Map<String, dynamic>> teachers = [];
  bool isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchSections();
    _fetchTeachers();
  }

  Future<void> _fetchSections() async {
    setState(() => isLoading = true);
    final response = await supabase
        .from('sections')
        .select('id, name, grade_level, created_at')
        .order('grade_level', ascending: true)
        .order('name', ascending: true);
    setState(() {
      sections = List<Map<String, dynamic>>.from(response);
      isLoading = false;
    });
  }

  Future<void> _fetchTeachers() async {
    final response = await supabase
        .from('users')
        .select('id, fname, lname')
        .eq('role', 'Teacher')
        .order('lname', ascending: true);
    setState(() {
      teachers = List<Map<String, dynamic>>.from(response);
    });
  }

  Future<List<Map<String, dynamic>>> _fetchSectionTeachers(
    int sectionId,
  ) async {
    final response = await supabase
        .from('section_teachers')
        .select('id, subject, assigned_at, users(id, fname, lname)')
        .eq('section_id', sectionId)
        .order('subject', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> _addOrEditSection({Map<String, dynamic>? section}) async {
    final nameController = TextEditingController(text: section?['name'] ?? '');
    String? selectedGradeLevel = section?['grade_level'];
    final formKey = GlobalKey<FormState>();
    final gradeOptions = [
      'Preschool',
      'Kinder',
      'Grade 1',
      'Grade 2',
      'Grade 3',
      'Grade 4',
      'Grade 5',
      'Grade 6',
    ];
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    section == null ? Icons.add : Icons.edit,
                    color: const Color(0xFF2ECC71),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    section == null ? 'Add New Section' : 'Edit Section',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 400,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: nameController,
                        decoration: InputDecoration(
                          labelText: 'Section Name *',
                          prefixIcon: const Icon(Icons.class_, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          labelStyle: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF333333),
                        ),
                        validator:
                            (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Section name required'
                                    : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<String>(
                        decoration: InputDecoration(
                          labelText: 'Grade Level *',
                          prefixIcon: const Icon(Icons.school, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          labelStyle: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        value: selectedGradeLevel,
                        items:
                            gradeOptions
                                .map(
                                  (grade) => DropdownMenuItem<String>(
                                    value: grade,
                                    child: Text(
                                      grade,
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (value) => setDialogState(
                              () => selectedGradeLevel = value,
                            ),
                        validator:
                            (value) =>
                                value == null ? 'Select grade level' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final payload = {
                        'name': nameController.text.trim(),
                        'grade_level': selectedGradeLevel,
                      };
                      if (section == null) {
                        await supabase.from('sections').insert(payload);
                      } else {
                        await supabase
                            .from('sections')
                            .update(payload)
                            .eq('id', section['id']);
                      }
                      Navigator.pop(context);
                      await _fetchSections();
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(section == null ? Icons.add : Icons.save, size: 16),
                      const SizedBox(width: 8),
                      Text(section == null ? 'Add Section' : 'Update Section'),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    nameController.dispose();
  }

  Future<void> _deleteSection(int id) async {
    try {
      await supabase.from('sections').delete().eq('id', id);
      await _fetchSections();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Section deleted successfully!'),
            ],
          ),
          backgroundColor: Color(0xFF2ECC71),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(child: Text('Error deleting section: ${e.toString()}')),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _addOrEditTeacherAssignment({
    required int sectionId,
    Map<String, dynamic>? assignment,
  }) async {
    final formKey = GlobalKey<FormState>();
    String? selectedSubject = assignment?['subject'];
    dynamic selectedTeacherId =
        assignment?['users']?['id'] ?? assignment?['teacher_id'];
    final subjectController = TextEditingController(
      text: selectedSubject ?? '',
    );

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    assignment == null ? Icons.person_add : Icons.edit,
                    color: const Color(0xFF2ECC71),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    assignment == null
                        ? 'Add Teacher Assignment'
                        : 'Edit Teacher Assignment',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 350,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextFormField(
                        controller: subjectController,
                        decoration: InputDecoration(
                          labelText: 'Subject *',
                          prefixIcon: const Icon(Icons.book, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          labelStyle: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF333333),
                        ),
                        validator:
                            (value) =>
                                (value == null || value.trim().isEmpty)
                                    ? 'Subject required'
                                    : null,
                      ),
                      const SizedBox(height: 16),
                      DropdownButtonFormField<dynamic>(
                        decoration: InputDecoration(
                          labelText: 'Teacher *',
                          prefixIcon: const Icon(Icons.person, size: 20),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          filled: true,
                          fillColor: Colors.grey[50],
                          labelStyle: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                        value: selectedTeacherId,
                        items:
                            teachers
                                .map(
                                  (t) => DropdownMenuItem(
                                    value: t['id'],
                                    child: Text(
                                      '${t['fname']} ${t['lname']}',
                                      style: const TextStyle(fontSize: 15),
                                    ),
                                  ),
                                )
                                .toList(),
                        onChanged:
                            (value) =>
                                setDialogState(() => selectedTeacherId = value),
                        validator:
                            (value) => value == null ? 'Select teacher' : null,
                      ),
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      final payload = {
                        'section_id': sectionId,
                        'teacher_id': selectedTeacherId,
                        'subject': subjectController.text.trim(),
                      };
                      if (assignment == null) {
                        await supabase.from('section_teachers').insert(payload);
                      } else {
                        await supabase
                            .from('section_teachers')
                            .update(payload)
                            .eq('id', assignment['id']);
                      }
                      Navigator.pop(context);
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        assignment == null ? Icons.add : Icons.save,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        assignment == null
                            ? 'Add Assignment'
                            : 'Update Assignment',
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );
    subjectController.dispose();
  }

  Future<void> _deleteTeacherAssignment(int assignmentId) async {
    try {
      await supabase.from('section_teachers').delete().eq('id', assignmentId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Row(
            children: [
              Icon(Icons.check_circle, color: Colors.white),
              SizedBox(width: 8),
              Text('Teacher assignment deleted!'),
            ],
          ),
          backgroundColor: Color(0xFF2ECC71),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.error, color: Colors.white),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Error deleting assignment: ${e.toString()}'),
              ),
            ],
          ),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _showManageTeachersDialog(
    int sectionId,
    String sectionName,
  ) async {
    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Row(
            children: [
              const Icon(Icons.group, color: Color(0xFF2ECC71)),
              const SizedBox(width: 8),
              Text(
                "Teachers for $sectionName",
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF333333),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 420,
            child: FutureBuilder<List<Map<String, dynamic>>>(
              future: _fetchSectionTeachers(sectionId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
                  );
                }
                final assignments = snapshot.data!;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    assignments.isEmpty
                        ? const Padding(
                          padding: EdgeInsets.symmetric(vertical: 8.0),
                          child: Text(
                            "No teacher assignments yet.",
                            style: TextStyle(fontSize: 14),
                          ),
                        )
                        : SingleChildScrollView(
                          child: Table(
                            columnWidths: const {
                              0: FlexColumnWidth(1.3),
                              1: FlexColumnWidth(1.3),
                              2: FlexColumnWidth(1.0),
                              3: FlexColumnWidth(0.6),
                            },
                            defaultVerticalAlignment:
                                TableCellVerticalAlignment.middle,
                            children: [
                              TableRow(
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                ),
                                children: const [
                                  TableHeaderCell(text: 'Teacher'),
                                  TableHeaderCell(text: 'Subject'),
                                  TableHeaderCell(text: 'Assigned At'),
                                  TableHeaderCell(text: ''),
                                ],
                              ),
                              ...assignments.map((assignment) {
                                final teacher = assignment['users'];
                                final assignedAt =
                                    assignment['assigned_at'] != null
                                        ? assignment['assigned_at']
                                        : "";
                                final assignedDate =
                                    assignedAt != ""
                                        ? DateTime.tryParse(assignedAt)
                                        : null;
                                final assignedStr =
                                    assignedDate != null
                                        ? "${assignedDate.year}-${assignedDate.month.toString().padLeft(2, '0')}-${assignedDate.day.toString().padLeft(2, '0')}"
                                        : "";
                                return TableRow(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                  ),
                                  children: [
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          teacher != null
                                              ? "${teacher['fname']} ${teacher['lname']}"
                                              : "N/A",
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF333333),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          assignment['subject'],
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(8.0),
                                        child: Text(
                                          assignedStr,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF666666),
                                          ),
                                        ),
                                      ),
                                    ),
                                    TableCell(
                                      child: PopupMenuButton<String>(
                                        icon: const Icon(Icons.more_vert),
                                        onSelected: (value) async {
                                          if (value == 'edit') {
                                            await _addOrEditTeacherAssignment(
                                              sectionId: sectionId,
                                              assignment: assignment,
                                            );
                                            // Force refresh by popping and reopening the dialog
                                            Navigator.pop(context);
                                            _showManageTeachersDialog(
                                              sectionId,
                                              sectionName,
                                            );
                                          } else if (value == 'delete') {
                                            await _deleteTeacherAssignment(
                                              assignment['id'],
                                            );
                                            Navigator.pop(context);
                                            _showManageTeachersDialog(
                                              sectionId,
                                              sectionName,
                                            );
                                          }
                                        },
                                        itemBuilder:
                                            (context) => [
                                              const PopupMenuItem(
                                                value: 'edit',
                                                child: Row(
                                                  children: [
                                                    Icon(Icons.edit, size: 16),
                                                    SizedBox(width: 8),
                                                    Text('Edit'),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.delete,
                                                      size: 16,
                                                      color: Colors.red,
                                                    ),
                                                    SizedBox(width: 8),
                                                    Text(
                                                      'Delete',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.person_add, size: 16),
                        label: const Text(
                          'Add Teacher Assignment',
                          style: TextStyle(fontSize: 14),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 8),
                        ),
                        onPressed: () async {
                          if (teachers.isEmpty) {
                            await _fetchTeachers();
                          }
                          await _addOrEditTeacherAssignment(
                            sectionId: sectionId,
                          );
                          Navigator.pop(context);
                          _showManageTeachersDialog(sectionId, sectionName);
                        },
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  "Section Management",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      "Add New Section",
                      style: TextStyle(color: Colors.white),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                    ),
                    onPressed: () => _addOrEditSection(),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.only(top: 4.0, bottom: 20.0),
              child: Text(
                "Home / Section Management",
                style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child:
                  isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2ECC71),
                        ),
                      )
                      : sections.isEmpty
                      ? const Center(
                        child: Text(
                          "No sections found.",
                          style: TextStyle(
                            color: Color(0xFF666666),
                            fontSize: 16,
                          ),
                        ),
                      )
                      : SingleChildScrollView(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFFEEEEEE)),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Table(
                            border: TableBorder(
                              horizontalInside: BorderSide(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                            columnWidths: const {
                              0: FlexColumnWidth(0.8), // ID
                              1: FlexColumnWidth(1.5), // Name
                              2: FlexColumnWidth(0.8), // Grade
                              3: FlexColumnWidth(1.0), // Created At
                              4: FlexColumnWidth(0.8), // Actions
                            },
                            defaultVerticalAlignment:
                                TableCellVerticalAlignment.middle,
                            children: [
                              TableRow(
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                ),
                                children: const [
                                  TableHeaderCell(text: 'Section ID'),
                                  TableHeaderCell(text: 'Section Name'),
                                  TableHeaderCell(text: 'Grade Level'),
                                  TableHeaderCell(text: 'Created At'),
                                  TableHeaderCell(text: 'Actions'),
                                ],
                              ),
                              ...sections.map((section) {
                                final createdAt =
                                    section['created_at'] != null
                                        ? DateTime.tryParse(
                                          section['created_at'],
                                        )
                                        : null;
                                final createdStr =
                                    createdAt != null
                                        ? "${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}"
                                        : "N/A";
                                return TableRow(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                  ),
                                  children: [
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          'SEC${section['id'].toString().padLeft(3, '0')}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF555555),
                                            fontSize: 14,
                                          ),
                                        ),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          section['name'] ?? '',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF333333),
                                            fontSize: 15,
                                          ),
                                        ),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          '${section['grade_level'] ?? 'N/A'}',
                                          style: const TextStyle(fontSize: 14),
                                        ),
                                      ),
                                    ),
                                    TableCell(
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          createdStr,
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF666666),
                                          ),
                                        ),
                                      ),
                                    ),
                                    TableCell(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          ElevatedButton.icon(
                                            icon: const Icon(
                                              Icons.group,
                                              color: Color(0xFF2ECC71),
                                            ),
                                            label: const Text(
                                              "Manage Teachers",
                                              style: TextStyle(
                                                color: Color(0xFF333333),
                                                fontSize: 13,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: Colors.grey[100],
                                              foregroundColor: const Color(
                                                0xFF333333,
                                              ),
                                              elevation: 0,
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 10,
                                                    vertical: 8,
                                                  ),
                                            ),
                                            onPressed:
                                                () => _showManageTeachersDialog(
                                                  section['id'],
                                                  section['name'],
                                                ),
                                          ),
                                          const SizedBox(width: 4),
                                          PopupMenuButton<String>(
                                            icon: const Icon(Icons.more_vert),
                                            onSelected: (value) async {
                                              if (value == 'edit') {
                                                await _addOrEditSection(
                                                  section: section,
                                                );
                                              } else if (value == 'delete') {
                                                await _deleteSection(
                                                  section['id'],
                                                );
                                              }
                                            },
                                            itemBuilder:
                                                (context) => [
                                                  const PopupMenuItem(
                                                    value: 'edit',
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.edit,
                                                          size: 16,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text('Edit'),
                                                      ],
                                                    ),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'delete',
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.delete,
                                                          size: 16,
                                                          color: Colors.red,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Delete',
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                );
                              }).toList(),
                            ],
                          ),
                        ),
                      ),
            ),
          ],
        ),
      ),
    );
  }
}

class TableHeaderCell extends StatelessWidget {
  final String text;
  const TableHeaderCell({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          fontSize: 13,
          color: Color(0xFF666666),
        ),
      ),
    );
  }
}
