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
  // Search query for sections
  String _searchQuery = '';
  // Filtering / sorting state
  String _gradeFilter = 'All Grades';
  String _sortOption = 'Name (A-Z)';

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
        .select(
          'id, subject, assigned_at, days, start_time, end_time, teacher_id, users(id, fname, lname)',
        )
        .eq('section_id', sectionId)
        .order('subject', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<List<Map<String, dynamic>>> _fetchTeacherAssignments(
    String teacherId,
  ) async {
    final response = await supabase
        .from('section_teachers')
        .select(
          'id, subject, days, start_time, end_time, sections(id, name, grade_level)',
        )
        .eq('teacher_id', teacherId)
        .order('start_time', ascending: true);
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
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 20,
              shadowColor: Colors.black.withOpacity(0.2),
              title: Row(
                children: [
                  Icon(
                    section == null ? Icons.add : Icons.edit,
                    color: const Color(0xFF2ECC71),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    section == null ? 'Add New Section' : 'Edit Section',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: 0.5,
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
                          prefixIcon: const Icon(
                            Icons.class_,
                            size: 22,
                            color: Color(0xFF2ECC71),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          labelStyle: TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: const TextStyle(
                          fontSize: 16,
                          color: Color(0xFF1A1A1A),
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
                          prefixIcon: const Icon(
                            Icons.school,
                            size: 22,
                            color: Color(0xFF2ECC71),
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(10),
                          ),
                          filled: true,
                          fillColor: Colors.white,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 14,
                          ),
                          labelStyle: TextStyle(
                            color: Color(0xFF555555),
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
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
                                      style: const TextStyle(fontSize: 16),
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
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
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
                      Icon(section == null ? Icons.add : Icons.save, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        section == null ? 'Add Section' : 'Update Section',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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

  Color _getGradeColor(String? gradeLevel) {
    switch (gradeLevel) {
      case 'Preschool':
        return Colors.purple;
      case 'Kinder':
        return Colors.pink;
      case 'Grade 1':
        return Colors.blue;
      case 'Grade 2':
        return Colors.green;
      case 'Grade 3':
        return Colors.orange;
      case 'Grade 4':
        return Colors.red;
      case 'Grade 5':
        return Colors.teal;
      case 'Grade 6':
        return Colors.indigo;
      default:
        return Colors.grey;
    }
  }

  Future<bool> _showDeleteConfirmDialog(String sectionName) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 20,
                shadowColor: Colors.black.withOpacity(0.2),
                title: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Confirm Delete',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                content: Text(
                  'Are you sure you want to delete the section "$sectionName"? This action cannot be undone.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;
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
    List<Map<String, dynamic>> teacherSchedule = [];
    bool isLoadingSchedule = false;

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

      // Load teacher schedule if editing
      if (selectedTeacherId != null) {
        teacherSchedule = await _fetchTeacherAssignments(selectedTeacherId);
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
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 20,
              shadowColor: Colors.black.withOpacity(0.2),
              title: Row(
                children: [
                  Icon(
                    assignment == null ? Icons.person_add : Icons.edit,
                    color: const Color(0xFF2ECC71),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    assignment == null
                        ? 'Add Teacher Assignment'
                        : 'Edit Teacher Assignment',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: 0.5,
                    ),
                  ),
                ],
              ),
              content: SizedBox(
                width: 500,
                height: 600,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // Subject Field
                        TextFormField(
                          controller: subjectController,
                          decoration: InputDecoration(
                            labelText: 'Subject *',
                            prefixIcon: const Icon(
                              Icons.book,
                              size: 22,
                              color: Color(0xFF2ECC71),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            labelStyle: TextStyle(
                              color: Color(0xFF555555),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: const TextStyle(
                            fontSize: 16,
                            color: Color(0xFF1A1A1A),
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
                            prefixIcon: const Icon(
                              Icons.person,
                              size: 22,
                              color: Color(0xFF2ECC71),
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            filled: true,
                            fillColor: Colors.white,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 14,
                            ),
                            labelStyle: TextStyle(
                              color: Color(0xFF555555),
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          value: selectedTeacherId,
                          items:
                              teachers.map((teacher) {
                                return DropdownMenuItem(
                                  value: teacher['id'],
                                  child: Text(
                                    '${teacher['fname']} ${teacher['lname']}',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                );
                              }).toList(),
                          onChanged: (value) async {
                            setDialogState(() {
                              selectedTeacherId = value;
                              isLoadingSchedule = true;
                            });

                            if (value != null) {
                              try {
                                final schedule = await _fetchTeacherAssignments(
                                  value,
                                );
                                setDialogState(() {
                                  teacherSchedule = schedule;
                                  isLoadingSchedule = false;
                                });
                              } catch (e) {
                                setDialogState(() {
                                  isLoadingSchedule = false;
                                });
                                print('Error fetching teacher schedule: $e');
                              }
                            } else {
                              setDialogState(() {
                                teacherSchedule = [];
                                isLoadingSchedule = false;
                              });
                            }
                          },
                          validator:
                              (value) =>
                                  value == null ? 'Select teacher' : null,
                        ),
                        const SizedBox(height: 16),

                        // Teacher Schedule Display
                        if (selectedTeacherId != null) ...[
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              border: Border.all(
                                color: Colors.blue[200]!,
                                width: 2,
                              ),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.schedule,
                                      size: 20,
                                      color: Colors.blue[700],
                                    ),
                                    const SizedBox(width: 10),
                                    Text(
                                      'Current Teacher Schedule',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blue[700],
                                        fontSize: 18,
                                        letterSpacing: 0.3,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                if (isLoadingSchedule)
                                  const Center(
                                    child: Padding(
                                      padding: EdgeInsets.all(8.0),
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                      ),
                                    ),
                                  )
                                else if (teacherSchedule.isEmpty)
                                  Text(
                                    'No current assignments',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  )
                                else
                                  Column(
                                    children:
                                        teacherSchedule.map((schedule) {
                                          final section = schedule['sections'];
                                          final sectionName =
                                              section != null
                                                  ? section['name']
                                                  : 'Unknown Section';
                                          final gradeLevel =
                                              section != null
                                                  ? section['grade_level']
                                                  : '';
                                          final subject =
                                              schedule['subject'] ?? '';
                                          final days =
                                              schedule['days'] is List
                                                  ? (schedule['days'] as List)
                                                      .join(', ')
                                                  : schedule['days']
                                                          ?.toString() ??
                                                      '';
                                          final startTimeStr =
                                              schedule['start_time']
                                                  ?.toString() ??
                                              '';
                                          final endTimeStr =
                                              schedule['end_time']
                                                  ?.toString() ??
                                              '';

                                          String timeRange = '';
                                          if (startTimeStr.isNotEmpty &&
                                              endTimeStr.isNotEmpty) {
                                            try {
                                              final startParts = startTimeStr
                                                  .split(':');
                                              final endParts = endTimeStr.split(
                                                ':',
                                              );
                                              if (startParts.length >= 2 &&
                                                  endParts.length >= 2) {
                                                final startHour = int.parse(
                                                  startParts[0],
                                                );
                                                final startMin = int.parse(
                                                  startParts[1],
                                                );
                                                final endHour = int.parse(
                                                  endParts[0],
                                                );
                                                final endMin = int.parse(
                                                  endParts[1],
                                                );

                                                final startTime = TimeOfDay(
                                                  hour: startHour,
                                                  minute: startMin,
                                                );
                                                final endTime = TimeOfDay(
                                                  hour: endHour,
                                                  minute: endMin,
                                                );

                                                timeRange =
                                                    '${startTime.format(context)} - ${endTime.format(context)}';
                                              }
                                            } catch (e) {
                                              timeRange =
                                                  '$startTimeStr - $endTimeStr';
                                            }
                                          }

                                          return Container(
                                            margin: const EdgeInsets.only(
                                              bottom: 8,
                                            ),
                                            padding: const EdgeInsets.all(12),
                                            decoration: BoxDecoration(
                                              color: Colors.white,
                                              borderRadius:
                                                  BorderRadius.circular(10),
                                              border: Border.all(
                                                color: Colors.grey[300]!,
                                                width: 1,
                                              ),
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black
                                                      .withOpacity(0.04),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Row(
                                                  children: [
                                                    Expanded(
                                                      child: Text(
                                                        '$subject - $sectionName ($gradeLevel)',
                                                        style: const TextStyle(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                          fontSize: 15,
                                                          color: Color(
                                                            0xFF1A1A1A,
                                                          ),
                                                          letterSpacing: 0.3,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                                const SizedBox(height: 6),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.access_time,
                                                      size: 16,
                                                      color: Color(0xFF2ECC71),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      timeRange,
                                                      style: TextStyle(
                                                        color: Color(
                                                          0xFF555555,
                                                        ),
                                                        fontSize: 14,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                    const SizedBox(width: 16),
                                                    Icon(
                                                      Icons.calendar_today,
                                                      size: 16,
                                                      color: Color(0xFF2ECC71),
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        days,
                                                        style: TextStyle(
                                                          color: Color(
                                                            0xFF555555,
                                                          ),
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w500,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 20),
                        ],

                        // Days Section
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Schedule Days *',
                            style: TextStyle(
                              color: Color(0xFF1A1A1A),
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          width: double.infinity,
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Colors.grey[300]!,
                              width: 2,
                            ),
                            borderRadius: BorderRadius.circular(12),
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
                                        horizontal: 16,
                                        vertical: 10,
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
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        boxShadow:
                                            isSelected
                                                ? [
                                                  BoxShadow(
                                                    color: const Color(
                                                      0xFF2ECC71,
                                                    ).withOpacity(0.3),
                                                    blurRadius: 8,
                                                    offset: const Offset(0, 2),
                                                  ),
                                                ]
                                                : null,
                                      ),
                                      child: Text(
                                        day,
                                        style: TextStyle(
                                          color:
                                              isSelected
                                                  ? Colors.white
                                                  : Color(0xFF1A1A1A),
                                          fontWeight:
                                              isSelected
                                                  ? FontWeight.w700
                                                  : FontWeight.w500,
                                          fontSize: 15,
                                          letterSpacing: 0.3,
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
                                      color: Color(0xFF1A1A1A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      letterSpacing: 0.3,
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
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        color: Colors.grey[50],
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time,
                                            size: 22,
                                            color: Color(0xFF2ECC71),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            startTime != null
                                                ? formatTimeDisplay(startTime)
                                                : 'Select start time',
                                            style: TextStyle(
                                              color:
                                                  startTime != null
                                                      ? const Color(0xFF1A1A1A)
                                                      : Colors.grey[600],
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
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
                                      color: Color(0xFF1A1A1A),
                                      fontWeight: FontWeight.bold,
                                      fontSize: 18,
                                      letterSpacing: 0.3,
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
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                          width: 2,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                        color: Colors.grey[50],
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            Icons.access_time,
                                            size: 22,
                                            color: Color(0xFF2ECC71),
                                          ),
                                          const SizedBox(width: 10),
                                          Text(
                                            endTime != null
                                                ? formatTimeDisplay(endTime)
                                                : 'Select end time',
                                            style: TextStyle(
                                              color:
                                                  endTime != null
                                                      ? const Color(0xFF1A1A1A)
                                                      : Colors.grey[600],
                                              fontSize: 16,
                                              fontWeight: FontWeight.w500,
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
              ),
              actions: [
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
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
                        size: 18,
                      ),
                      const SizedBox(width: 10),
                      Text(
                        assignment == null
                            ? 'Add Assignment'
                            : 'Update Assignment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
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
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          child: Container(
            width: 600,
            height: 700,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2ECC71).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.group,
                        color: Color(0xFF2ECC71),
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Teacher Management",
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF1A1A1A),
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            "Section: $sectionName",
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Icon(Icons.close, color: Colors.grey[600]),
                      style: IconButton.styleFrom(
                        backgroundColor: Colors.grey[100],
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Section divider
                Container(
                  width: double.infinity,
                  height: 1,
                  color: Colors.grey[200],
                ),
                const SizedBox(height: 24),

                // Teachers list
                Expanded(
                  child: FutureBuilder<List<Map<String, dynamic>>>(
                    future: _fetchSectionTeachers(sectionId),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(
                                color: Color(0xFF2ECC71),
                              ),
                              SizedBox(height: 16),
                              Text(
                                'Loading teacher assignments...',
                                style: TextStyle(color: Colors.grey),
                              ),
                            ],
                          ),
                        );
                      }

                      final assignments = snapshot.data!;

                      if (assignments.isEmpty) {
                        return Center(
                          child: Container(
                            padding: const EdgeInsets.all(32),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.people_outline,
                                  size: 64,
                                  color: Colors.grey[400],
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  "No teachers assigned yet",
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w500,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  "Add your first teacher assignment",
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[500],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      }

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Teacher list header
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.assignment_ind,
                                  color: Color(0xFF2ECC71),
                                  size: 20,
                                ),
                                const SizedBox(width: 8),
                                const Text(
                                  'Teacher Assignments',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                    color: Color(0xFF1A1A1A),
                                    letterSpacing: 0.3,
                                  ),
                                ),
                                const Spacer(),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2ECC71,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF2ECC71,
                                      ).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Text(
                                    '${assignments.length} Assignment${assignments.length == 1 ? '' : 's'}',
                                    style: const TextStyle(
                                      fontSize: 15,
                                      color: Color(0xFF2ECC71),
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Teacher assignment cards
                          Expanded(
                            child: ListView.separated(
                              itemCount: assignments.length,
                              separatorBuilder:
                                  (context, index) =>
                                      const SizedBox(height: 12),
                              itemBuilder: (context, index) {
                                final assignment = assignments[index];
                                final teacher = assignment['users'];
                                final teacherName =
                                    teacher != null
                                        ? "${teacher['fname']} ${teacher['lname']}"
                                        : "Unknown Teacher";
                                final subject =
                                    assignment['subject'] ?? 'No Subject';

                                // Parse schedule
                                final days = assignment['days'] ?? [];
                                final startTime = assignment['start_time'];
                                final endTime = assignment['end_time'];

                                String scheduleText = 'No schedule';
                                if (days.isNotEmpty &&
                                    startTime != null &&
                                    endTime != null) {
                                  final daysStr = (days as List).join(', ');
                                  scheduleText =
                                      '$daysStr • $startTime - $endTime';
                                }

                                return Container(
                                  padding: const EdgeInsets.all(20),
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                      width: 1,
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: Colors.black.withOpacity(0.06),
                                        blurRadius: 8,
                                        offset: const Offset(0, 3),
                                      ),
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      // Teacher avatar
                                      Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          color: const Color(
                                            0xFF2ECC71,
                                          ).withOpacity(0.1),
                                          borderRadius: BorderRadius.circular(
                                            28,
                                          ),
                                          border: Border.all(
                                            color: const Color(
                                              0xFF2ECC71,
                                            ).withOpacity(0.4),
                                            width: 3,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.1,
                                              ),
                                              blurRadius: 4,
                                              offset: const Offset(0, 2),
                                            ),
                                          ],
                                        ),
                                        child: Center(
                                          child: Text(
                                            teacherName.isNotEmpty
                                                ? teacherName[0].toUpperCase()
                                                : 'T',
                                            style: const TextStyle(
                                              fontSize: 22,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2ECC71),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 16),

                                      // Teacher details
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              teacherName,
                                              style: const TextStyle(
                                                fontSize: 18,
                                                fontWeight: FontWeight.bold,
                                                color: Color(0xFF1A1A1A),
                                                letterSpacing: 0.3,
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.book,
                                                  size: 18,
                                                  color: Color(0xFF2ECC71),
                                                ),
                                                const SizedBox(width: 6),
                                                Text(
                                                  subject,
                                                  style: TextStyle(
                                                    fontSize: 15,
                                                    color: Color(0xFF555555),
                                                    fontWeight: FontWeight.w600,
                                                  ),
                                                ),
                                              ],
                                            ),
                                            const SizedBox(height: 6),
                                            Row(
                                              children: [
                                                Icon(
                                                  Icons.schedule,
                                                  size: 18,
                                                  color: Color(0xFF2ECC71),
                                                ),
                                                const SizedBox(width: 6),
                                                Expanded(
                                                  child: Text(
                                                    scheduleText,
                                                    style: TextStyle(
                                                      fontSize: 14,
                                                      color: Color(0xFF555555),
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                    overflow:
                                                        TextOverflow.ellipsis,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),

                                      // Action buttons
                                      PopupMenuButton<String>(
                                        icon: Icon(
                                          Icons.more_vert,
                                          color: Colors.grey[600],
                                          size: 22,
                                        ),
                                        onSelected: (value) async {
                                          if (value == 'edit') {
                                            await _addOrEditTeacherAssignment(
                                              sectionId: sectionId,
                                              assignment: assignment,
                                            );
                                            Navigator.pop(context);
                                            _showManageTeachersDialog(
                                              sectionId,
                                              sectionName,
                                            );
                                          } else if (value == 'delete') {
                                            final confirm =
                                                await _showDeleteTeacherConfirmDialog(
                                                  teacherName,
                                                  subject,
                                                );
                                            if (confirm) {
                                              await _deleteTeacherAssignment(
                                                assignment['id'],
                                              );
                                              Navigator.pop(context);
                                              _showManageTeachersDialog(
                                                sectionId,
                                                sectionName,
                                              );
                                            }
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
                                                      size: 18,
                                                      color: Color(0xFF2ECC71),
                                                    ),
                                                    SizedBox(width: 10),
                                                    Text(
                                                      'Edit Assignment',
                                                      style: TextStyle(
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                              const PopupMenuItem(
                                                value: 'delete',
                                                child: Row(
                                                  children: [
                                                    Icon(
                                                      Icons.delete,
                                                      size: 18,
                                                      color: Colors.red,
                                                    ),
                                                    SizedBox(width: 10),
                                                    Text(
                                                      'Remove Assignment',
                                                      style: TextStyle(
                                                        color: Colors.red,
                                                        fontSize: 15,
                                                        fontWeight:
                                                            FontWeight.w500,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ],
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),

                // Add teacher button
                const SizedBox(height: 24),
                Container(
                  width: double.infinity,
                  height: 1,
                  color: Colors.grey[200],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.person_add, size: 20),
                        label: const Text(
                          'Add Teacher Assignment',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: const Color(0xFF2ECC71),
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          elevation: 4,
                          shadowColor: Colors.black.withOpacity(0.2),
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
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<bool> _showDeleteTeacherConfirmDialog(
    String teacherName,
    String subject,
  ) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 20,
                shadowColor: Colors.black.withOpacity(0.2),
                title: const Row(
                  children: [
                    Icon(Icons.warning, color: Colors.red, size: 24),
                    SizedBox(width: 12),
                    Text(
                      'Remove Teacher Assignment',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: 0.5,
                      ),
                    ),
                  ],
                ),
                content: Text(
                  'Are you sure you want to remove $teacherName from teaching $subject? This action cannot be undone.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () => Navigator.of(context).pop(true),
                    child: const Text('Remove'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  @override
  Widget build(BuildContext context) {
    // Prepare sections for display: apply grade filter, search then sorting
    final query = _searchQuery.trim().toLowerCase();
    List<Map<String, dynamic>> displaySections =
        sections.where((s) {
          final matchesGrade =
              _gradeFilter == 'All Grades' ||
              (s['grade_level']?.toString() ?? '') == _gradeFilter;
          if (!matchesGrade) return false;

          if (query.isEmpty) return true;
          final name = (s['name'] ?? '').toString().toLowerCase();
          final id = s['id']?.toString() ?? '';
          return name.contains(query) || id.contains(query);
        }).toList();

    // Sorting
    if (_sortOption == 'Name (A-Z)') {
      displaySections.sort(
        (a, b) => (a['name'] ?? '').toString().compareTo(
          (b['name'] ?? '').toString(),
        ),
      );
    } else if (_sortOption == 'Name (Z-A)') {
      displaySections.sort(
        (a, b) => (b['name'] ?? '').toString().compareTo(
          (a['name'] ?? '').toString(),
        ),
      );
    } else if (_sortOption == 'Grade Level') {
      displaySections.sort(
        (a, b) => (a['grade_level'] ?? '').toString().compareTo(
          (b['grade_level'] ?? '').toString(),
        ),
      );
    } else if (_sortOption == 'Date Created') {
      displaySections.sort((a, b) {
        final da =
            a['created_at'] != null
                ? DateTime.tryParse(a['created_at'].toString())
                : null;
        final db =
            b['created_at'] != null
                ? DateTime.tryParse(b['created_at'].toString())
                : null;
        if (da == null && db == null) return 0;
        if (da == null) return 1;
        if (db == null) return -1;
        return da.compareTo(db);
      });
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with title and search/add buttons
            Row(
              children: [
                const Text(
                  "Section Management",
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                // Search bar
                Container(
                  width: 280,
                  height: 48,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search sections...',
                      hintStyle: TextStyle(fontSize: 16),
                      prefixIcon: Icon(
                        Icons.search,
                        color: Color(0xFF2ECC71),
                        size: 22,
                      ),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(
                        vertical: 14.0,
                        horizontal: 16.0,
                      ),
                    ),
                    onChanged:
                        (val) => setState(() {
                          _searchQuery = val;
                        }),
                  ),
                ),
                const SizedBox(width: 16),
                // Add New Section button
                SizedBox(
                  height: 48,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, color: Colors.white, size: 22),
                    label: const Text(
                      "Add New Section",
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 4,
                      shadowColor: Colors.black.withOpacity(0.2),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                    onPressed: () => _addOrEditSection(),
                  ),
                ),
                const SizedBox(width: 16),
                // Export button
                SizedBox(
                  height: 48,
                  child: OutlinedButton.icon(
                    icon: const Icon(
                      Icons.file_download_outlined,
                      color: Color(0xFF2ECC71),
                      size: 22,
                    ),
                    label: const Text(
                      "Export",
                      style: TextStyle(
                        color: Color(0xFF2ECC71),
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: const BorderSide(
                        color: Color(0xFF2ECC71),
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 2,
                      shadowColor: Colors.black.withOpacity(0.1),
                    ),
                    onPressed: () {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Export functionality coming soon...'),
                          backgroundColor: Colors.orange,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),

            // Breadcrumb / subtitle
            const Padding(
              padding: EdgeInsets.only(top: 8.0, bottom: 24.0),
              child: Text(
                "Home / Section Management",
                style: TextStyle(
                  fontSize: 16,
                  color: Color(0xFF666666),
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),

            // Filter row
            Container(
              padding: const EdgeInsets.only(bottom: 16.0),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child: Row(
                children: [
                  // Grade filter dropdown
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _gradeFilter,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        items:
                            [
                              'All Grades',
                              'Preschool',
                              'Kinder',
                              'Grade 1',
                              'Grade 2',
                              'Grade 3',
                              'Grade 4',
                              'Grade 5',
                              'Grade 6',
                            ].map((String item) {
                              return DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              );
                            }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue == null) return;
                          setState(() {
                            _gradeFilter = newValue;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Sort by dropdown
                  Container(
                    height: 48,
                    padding: const EdgeInsets.symmetric(horizontal: 16.0),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(10),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 8,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortOption,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        items:
                            <String>[
                              'Name (A-Z)',
                              'Name (Z-A)',
                              'Grade Level',
                              'Date Created',
                            ].map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text('Sort by: $value'),
                              );
                            }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue == null) return;
                          setState(() {
                            _sortOption = newValue;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Stats row
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
              )
            else
              Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFFE0E0E0)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.04),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    // Total sections stat
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2ECC71).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.class_,
                              color: Color(0xFF2ECC71),
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Total Sections',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${sections.length}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Grade levels stat
                    Expanded(
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.school,
                              color: Colors.blue,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 16),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Grade Levels',
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.grey[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              Text(
                                '${sections.map((s) => s['grade_level']).toSet().length}',
                                style: const TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF1A1A1A),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Active sections indicator
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            Icons.check_circle,
                            size: 18,
                            color: Colors.green[600],
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'All Active',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.green[600],
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Enhanced Table with better styling
            Expanded(
              child:
                  isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2ECC71),
                        ),
                      )
                      : displaySections.isEmpty
                      // show friendly "no results" when search/filter yields nothing
                      ? Center(
                        child: Container(
                          padding: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: Colors.grey[200]!),
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.class_outlined,
                                size: 64,
                                color: Colors.grey[400],
                              ),
                              const SizedBox(height: 16),
                              Text(
                                _searchQuery.trim().isEmpty
                                    ? "No sections found"
                                    : "No sections match \"${_searchQuery.trim()}\"",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Try a different search term or clear filters.",
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  // clear search and reset grade filter to show all
                                  setState(() {
                                    _searchQuery = '';
                                    _gradeFilter = 'All Grades';
                                  });
                                },
                                icon: const Icon(Icons.search),
                                label: const Text('Clear Search / Filters'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2ECC71),
                                  foregroundColor: Colors.white,
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 24,
                                    vertical: 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      : Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.04),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Column(
                          children: [
                            // Enhanced table header
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(12),
                                  topRight: Radius.circular(12),
                                ),
                                border: Border(
                                  bottom: BorderSide(
                                    color: Colors.grey[200]!,
                                    width: 2,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.class_,
                                    color: Color(0xFF2ECC71),
                                    size: 24,
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Sections Overview',
                                    style: TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A),
                                      letterSpacing: 0.3,
                                    ),
                                  ),
                                  const Spacer(),
                                  Text(
                                    '${sections.length} section${sections.length == 1 ? '' : 's'}',
                                    style: TextStyle(
                                      fontSize: 16,
                                      color: Colors.grey[600],
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            // Table content
                            Expanded(
                              child: SingleChildScrollView(
                                child: Table(
                                  border: TableBorder(
                                    horizontalInside: BorderSide(
                                      color: Colors.grey[200]!,
                                      width: 1,
                                    ),
                                  ),
                                  columnWidths: const {
                                    0: FlexColumnWidth(0.8), // Section ID
                                    1: FlexColumnWidth(1.5), // Section Name
                                    2: FlexColumnWidth(1.0), // Grade Level
                                    3: FlexColumnWidth(1.2), // Created At
                                    4: FlexColumnWidth(1.5), // Actions
                                  },
                                  defaultVerticalAlignment:
                                      TableCellVerticalAlignment.middle,
                                  children: [
                                    // Table header row
                                    TableRow(
                                      decoration: BoxDecoration(
                                        color: Color(0xFFF8F9FA),
                                        border: Border(
                                          bottom: BorderSide(
                                            color: Colors.grey[200]!,
                                            width: 2,
                                          ),
                                        ),
                                      ),
                                      children: const [
                                        TableHeaderCell(text: 'Section ID'),
                                        TableHeaderCell(text: 'Section Name'),
                                        TableHeaderCell(text: 'Grade Level'),
                                        TableHeaderCell(text: 'Created Date'),
                                        TableHeaderCell(text: 'Actions'),
                                      ],
                                    ),
                                    // Table data rows (use displaySections after filter/sort)
                                    ...displaySections.map((section) {
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
                                          // Section ID with enhanced styling
                                          TableCell(
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 8,
                                                          vertical: 4,
                                                        ),
                                                    decoration: BoxDecoration(
                                                      color: const Color(
                                                        0xFF2ECC71,
                                                      ).withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            6,
                                                          ),
                                                    ),
                                                    child: Text(
                                                      'SEC${section['id'].toString().padLeft(3, '0')}',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.w700,
                                                        color: Color(
                                                          0xFF2ECC71,
                                                        ),
                                                        fontSize: 14,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Section Name with icon
                                          TableCell(
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding:
                                                        const EdgeInsets.all(8),
                                                    decoration: BoxDecoration(
                                                      color: Colors.blue
                                                          .withOpacity(0.1),
                                                      borderRadius:
                                                          BorderRadius.circular(
                                                            8,
                                                          ),
                                                    ),
                                                    child: Icon(
                                                      Icons.class_,
                                                      size: 16,
                                                      color: Colors.blue[600],
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),
                                                  Expanded(
                                                    child: Text(
                                                      section['name'] ?? '',
                                                      style: const TextStyle(
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: Color(
                                                          0xFF1A1A1A,
                                                        ),
                                                        fontSize: 18,
                                                        letterSpacing: 0.3,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Grade Level with badge
                                          TableCell(
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  Flexible(
                                                    child: Container(
                                                      padding:
                                                          const EdgeInsets.symmetric(
                                                            horizontal: 8,
                                                            vertical: 4,
                                                          ),
                                                      decoration: BoxDecoration(
                                                        color: _getGradeColor(
                                                          section['grade_level'],
                                                        ).withOpacity(0.1),
                                                        borderRadius:
                                                            BorderRadius.circular(
                                                              12,
                                                            ),
                                                        border: Border.all(
                                                          color: _getGradeColor(
                                                            section['grade_level'],
                                                          ).withOpacity(0.3),
                                                        ),
                                                      ),
                                                      child: Text(
                                                        section['grade_level'] ??
                                                            'N/A',
                                                        style: TextStyle(
                                                          fontSize: 13,
                                                          fontWeight:
                                                              FontWeight.w700,
                                                          color: _getGradeColor(
                                                            section['grade_level'],
                                                          ),
                                                        ),
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
                                                        maxLines: 1,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Created Date with icon
                                          TableCell(
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  Icon(
                                                    Icons.calendar_today,
                                                    size: 14,
                                                    color: Colors.grey[600],
                                                  ),
                                                  const SizedBox(width: 6),
                                                  Text(
                                                    createdStr,
                                                    style: const TextStyle(
                                                      fontSize: 15,
                                                      color: Color(0xFF555555),
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),

                                          // Enhanced Actions
                                          TableCell(
                                            child: Container(
                                              padding: const EdgeInsets.all(16),
                                              child: Row(
                                                children: [
                                                  // Manage Teachers button
                                                  Expanded(
                                                    child: ElevatedButton.icon(
                                                      icon: const Icon(
                                                        Icons.group,
                                                        size: 18,
                                                      ),
                                                      label: const Text(
                                                        "Teachers",
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight:
                                                              FontWeight.w600,
                                                        ),
                                                      ),
                                                      style: ElevatedButton.styleFrom(
                                                        backgroundColor:
                                                            const Color(
                                                              0xFF2ECC71,
                                                            ),
                                                        foregroundColor:
                                                            Colors.white,
                                                        elevation: 2,
                                                        shadowColor: Colors
                                                            .black
                                                            .withOpacity(0.1),
                                                        padding:
                                                            const EdgeInsets.symmetric(
                                                              horizontal: 12,
                                                              vertical: 8,
                                                            ),
                                                        shape: RoundedRectangleBorder(
                                                          borderRadius:
                                                              BorderRadius.circular(
                                                                8,
                                                              ),
                                                        ),
                                                      ),
                                                      onPressed:
                                                          () =>
                                                              _showManageTeachersDialog(
                                                                section['id'],
                                                                section['name'],
                                                              ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  // More actions menu
                                                  PopupMenuButton<String>(
                                                    icon: Icon(
                                                      Icons.more_vert,
                                                      color: Colors.grey[600],
                                                      size: 20,
                                                    ),
                                                    tooltip: 'More options',
                                                    onSelected: (value) async {
                                                      if (value == 'edit') {
                                                        await _addOrEditSection(
                                                          section: section,
                                                        );
                                                      } else if (value ==
                                                          'delete') {
                                                        final confirm =
                                                            await _showDeleteConfirmDialog(
                                                              section['name'],
                                                            );
                                                        if (confirm) {
                                                          await _deleteSection(
                                                            section['id'],
                                                          );
                                                        }
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
                                                                  size: 18,
                                                                  color: Color(
                                                                    0xFF2ECC71,
                                                                  ),
                                                                ),
                                                                SizedBox(
                                                                  width: 10,
                                                                ),
                                                                Text(
                                                                  'Edit Section',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        15,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          const PopupMenuItem(
                                                            value: 'delete',
                                                            child: Row(
                                                              children: [
                                                                Icon(
                                                                  Icons.delete,
                                                                  size: 18,
                                                                  color:
                                                                      Colors
                                                                          .red,
                                                                ),
                                                                SizedBox(
                                                                  width: 10,
                                                                ),
                                                                Text(
                                                                  'Delete Section',
                                                                  style: TextStyle(
                                                                    color:
                                                                        Colors
                                                                            .red,
                                                                    fontSize:
                                                                        15,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
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
                                        ],
                                      );
                                    }).toList(),
                                  ],
                                ),
                              ),
                            ),
                          ],
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
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 18),
      alignment: Alignment.centerLeft,
      child: Text(
        text,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Color(0xFF1A1A1A),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
