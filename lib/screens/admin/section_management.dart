import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

    // Initialize controllers and state variables
    final subjectController = TextEditingController();
    String? selectedSubject;
    dynamic selectedTeacherId;
    List<String> selectedDays = [];
    TimeOfDay? startTime;
    TimeOfDay? endTime;

    final List<String> daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];

    // Populate data if editing existing assignment
    if (assignment != null) {
      // Subject
      selectedSubject = assignment['subject'];
      subjectController.text = selectedSubject ?? '';

      // Teacher ID - handle nested user data
      if (assignment['users'] != null && assignment['users']['id'] != null) {
        selectedTeacherId = assignment['users']['id'];
      } else if (assignment['teacher_id'] != null) {
        selectedTeacherId = assignment['teacher_id'];
      }

      // Days - handle different formats
      if (assignment['days'] != null) {
        final daysData = assignment['days'];
        if (daysData is List) {
          selectedDays = List<String>.from(daysData);
        } else if (daysData is String) {
          try {
            // Remove brackets and quotes, then split
            final cleanedDays =
                daysData
                    .replaceAll(RegExp(r'[\{\}\[\]"]'), '')
                    .split(',')
                    .map((s) => s.trim())
                    .where((s) => s.isNotEmpty)
                    .toList();
            selectedDays = cleanedDays;
          } catch (e) {
            print('Error parsing days: $e');
            selectedDays = [];
          }
        }
      }

      // Start Time
      if (assignment['start_time'] != null) {
        final startTimeStr = assignment['start_time'].toString();
        if (startTimeStr.isNotEmpty && startTimeStr != 'null') {
          try {
            final timeParts = startTimeStr.split(':');
            if (timeParts.length >= 2) {
              final hour = int.parse(timeParts[0]);
              final minute = int.parse(timeParts[1]);
              startTime = TimeOfDay(hour: hour, minute: minute);
            }
          } catch (e) {
            print('Error parsing start time: $e');
          }
        }
      }

      // End Time
      if (assignment['end_time'] != null) {
        final endTimeStr = assignment['end_time'].toString();
        if (endTimeStr.isNotEmpty && endTimeStr != 'null') {
          try {
            final timeParts = endTimeStr.split(':');
            if (timeParts.length >= 2) {
              final hour = int.parse(timeParts[0]);
              final minute = int.parse(timeParts[1]);
              endTime = TimeOfDay(hour: hour, minute: minute);
            }
          } catch (e) {
            print('Error parsing end time: $e');
          }
        }
      }
    }

    // Debug print to see what data we're working with
    print('Assignment data: $assignment');
    print('Selected days: $selectedDays');
    print('Start time: $startTime');
    print('End time: $endTime');
    print('Selected teacher ID: $selectedTeacherId');

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Helper function to format time display
            String formatTimeDisplay(TimeOfDay? time) {
              if (time == null) return '';
              return time.format(context);
            }

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
                width: 400,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Subject Field
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
                        onChanged: (value) => selectedSubject = value,
                      ),
                      const SizedBox(height: 16),

                      // Teacher Dropdown
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
                            teachers.map((teacher) {
                              return DropdownMenuItem(
                                value: teacher['id'],
                                child: Text(
                                  '${teacher['fname']} ${teacher['lname']}',
                                  style: const TextStyle(fontSize: 15),
                                ),
                              );
                            }).toList(),
                        onChanged: (value) {
                          setDialogState(() {
                            selectedTeacherId = value;
                          });
                        },
                        validator:
                            (value) => value == null ? 'Select teacher' : null,
                      ),
                      const SizedBox(height: 20),

                      // Days Section
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Schedule Days *',
                          style: TextStyle(
                            color: Colors.grey[700],
                            fontWeight: FontWeight.w600,
                            fontSize: 14,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey[300]!),
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey[50],
                        ),
                        child: Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children:
                              daysOfWeek.map((day) {
                                final isSelected = selectedDays.contains(day);
                                return InkWell(
                                  onTap: () {
                                    setDialogState(() {
                                      if (isSelected) {
                                        selectedDays.remove(day);
                                      } else {
                                        selectedDays.add(day);
                                      }
                                    });
                                  },
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          isSelected
                                              ? const Color(0xFF2ECC71)
                                              : Colors.white,
                                      border: Border.all(
                                        color:
                                            isSelected
                                                ? const Color(0xFF2ECC71)
                                                : Colors.grey[300]!,
                                      ),
                                      borderRadius: BorderRadius.circular(6),
                                    ),
                                    child: Text(
                                      day,
                                      style: TextStyle(
                                        color:
                                            isSelected
                                                ? Colors.white
                                                : Colors.grey[700],
                                        fontWeight:
                                            isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                        fontSize: 13,
                                      ),
                                    ),
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Time Section
                      Row(
                        children: [
                          // Start Time
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Start Time *',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime:
                                          startTime ??
                                          const TimeOfDay(hour: 8, minute: 0),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        startTime = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.grey[50],
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          startTime != null
                                              ? formatTimeDisplay(startTime)
                                              : 'Select start time',
                                          style: TextStyle(
                                            color:
                                                startTime != null
                                                    ? const Color(0xFF333333)
                                                    : Colors.grey[600],
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // End Time
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'End Time *',
                                  style: TextStyle(
                                    color: Colors.grey[700],
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                InkWell(
                                  onTap: () async {
                                    final picked = await showTimePicker(
                                      context: context,
                                      initialTime:
                                          endTime ??
                                          const TimeOfDay(hour: 9, minute: 0),
                                    );
                                    if (picked != null) {
                                      setDialogState(() {
                                        endTime = picked;
                                      });
                                    }
                                  },
                                  child: Container(
                                    width: double.infinity,
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      border: Border.all(
                                        color: Colors.grey[300]!,
                                      ),
                                      borderRadius: BorderRadius.circular(8),
                                      color: Colors.grey[50],
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.access_time, size: 20),
                                        const SizedBox(width: 8),
                                        Text(
                                          endTime != null
                                              ? formatTimeDisplay(endTime)
                                              : 'Select end time',
                                          style: TextStyle(
                                            color:
                                                endTime != null
                                                    ? const Color(0xFF333333)
                                                    : Colors.grey[600],
                                            fontSize: 15,
                                          ),
                                        ),
                                      ],
                                    ),
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
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Colors.grey),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () async {
                    // Validation
                    if (!formKey.currentState!.validate()) return;

                    if (selectedDays.isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select at least one day.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (startTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select start time.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    if (endTime == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Please select end time.'),
                          backgroundColor: Colors.red,
                        ),
                      );
                      return;
                    }

                    // Check for scheduling conflicts
                    try {
                      final existingAssignments = await supabase
                          .from('section_teachers')
                          .select('id, days, start_time, end_time')
                          .eq('teacher_id', selectedTeacherId)
                          .neq('id', assignment?['id'] ?? 0);

                      bool hasConflict = false;
                      for (final other in existingAssignments) {
                        final otherDays = List<String>.from(
                          other['days'] ?? [],
                        );

                        // Check if there's any day overlap
                        if (otherDays.any((d) => selectedDays.contains(d))) {
                          // Parse other assignment times
                          final otherStartParts = other['start_time'].split(
                            ':',
                          );
                          final otherEndParts = other['end_time'].split(':');

                          final otherStartMinutes =
                              int.parse(otherStartParts[0]) * 60 +
                              int.parse(otherStartParts[1]);
                          final otherEndMinutes =
                              int.parse(otherEndParts[0]) * 60 +
                              int.parse(otherEndParts[1]);

                          final newStartMinutes =
                              startTime!.hour * 60 + startTime!.minute;
                          final newEndMinutes =
                              endTime!.hour * 60 + endTime!.minute;

                          // Check for time overlap
                          if (newStartMinutes < otherEndMinutes &&
                              newEndMinutes > otherStartMinutes) {
                            hasConflict = true;
                            break;
                          }
                        }
                      }

                      if (hasConflict) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Schedule conflict: Teacher is already assigned at that time.',
                            ),
                            backgroundColor: Colors.red,
                          ),
                        );
                        return;
                      }

                      // Format time for database (HH:MM:SS format)
                      String formatTimeForDB(TimeOfDay time) {
                        return '${time.hour.toString().padLeft(2, '0')}:'
                            '${time.minute.toString().padLeft(2, '0')}:00';
                      }

                      // Prepare payload
                      final payload = {
                        'section_id': sectionId,
                        'teacher_id': selectedTeacherId,
                        'subject': subjectController.text.trim(),
                        'days': selectedDays,
                        'start_time': formatTimeForDB(startTime!),
                        'end_time': formatTimeForDB(endTime!),
                      };

                      // Insert or update
                      if (assignment == null) {
                        await supabase.from('section_teachers').insert(payload);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Teacher assignment added successfully!',
                            ),
                            backgroundColor: Color(0xFF2ECC71),
                          ),
                        );
                      } else {
                        await supabase
                            .from('section_teachers')
                            .update(payload)
                            .eq('id', assignment['id']);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Teacher assignment updated successfully!',
                            ),
                            backgroundColor: Color(0xFF2ECC71),
                          ),
                        );
                      }

                      Navigator.pop(context);
                    } catch (e) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Error: ${e.toString()}'),
                          backgroundColor: Colors.red,
                        ),
                      );
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

    // Clean up
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
