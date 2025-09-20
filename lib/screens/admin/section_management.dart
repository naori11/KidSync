import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:html' as html;
import 'package:kidsync/services/audit_log_service.dart';

class SectionManagementPage extends StatefulWidget {
  const SectionManagementPage({super.key});

  @override
  State<SectionManagementPage> createState() => _SectionManagementPageState();
}

class _SectionManagementPageState extends State<SectionManagementPage> {
  final supabase = Supabase.instance.client;
  final auditLogService = AuditLogService();
  List<Map<String, dynamic>> sections = [];
  List<Map<String, dynamic>> teachers = [];
  bool isLoading = false;
  // Search query for sections
  String _searchQuery = '';
  // Filtering / sorting state
  String _gradeFilter = 'All Grades';
  String _sortOption = 'Name (A-Z)';

  // Responsive breakpoints
  bool get isMobile => MediaQuery.of(context).size.width < 768;
  bool get isTablet =>
      MediaQuery.of(context).size.width >= 768 &&
      MediaQuery.of(context).size.width < 1200;
  bool get isDesktop => MediaQuery.of(context).size.width >= 1200;
  bool get isSmallMobile => MediaQuery.of(context).size.width < 480;

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
                      
                      try {
                        if (section == null) {
                          // Create new section
                          final result = await supabase.from('sections').insert(payload).select('id').single();
                          
                          // Log section creation
                          await auditLogService.logSectionManagement(
                            action: 'create',
                            sectionId: result['id'].toString(),
                            sectionName: nameController.text.trim(),
                            gradeLevel: selectedGradeLevel,
                          );
                        } else {
                          // Update existing section
                          await supabase
                              .from('sections')
                              .update(payload)
                              .eq('id', section['id']);
                          
                          // Log section update
                          await auditLogService.logSectionManagement(
                            action: 'update',
                            sectionId: section['id'].toString(),
                            sectionName: nameController.text.trim(),
                            gradeLevel: selectedGradeLevel,
                            oldValues: {
                              'name': section['name'],
                              'grade_level': section['grade_level'],
                            },
                            newValues: payload,
                          );
                        }
                        
                        Navigator.pop(context);
                        await _fetchSections();
                      } catch (e) {
                        print('Error in section operation: $e');
                        // Show error to user but don't prevent navigation
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
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
      // Get section info before deletion for audit logging
      final sectionResponse = await supabase
          .from('sections')
          .select('name, grade_level')
          .eq('id', id)
          .single();
      
      final sectionName = sectionResponse['name'];
      final gradeLevel = sectionResponse['grade_level'];
      
      await supabase.from('sections').delete().eq('id', id);
      
      // Log section deletion
      await auditLogService.logSectionManagement(
        action: 'delete',
        sectionId: id.toString(),
        sectionName: sectionName,
        gradeLevel: gradeLevel,
      );
      
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

    final List<String> daysOfWeek = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];

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
                        final result = await supabase.from('section_teachers').insert(payload).select('id').single();
                        
                        // Get teacher and section names for audit logging
                        final teacherResponse = await supabase
                            .from('users')
                            .select('fname, lname')
                            .eq('id', selectedTeacherId)
                            .single();
                        final sectionResponse = await supabase
                            .from('sections')
                            .select('name')
                            .eq('id', sectionId)
                            .single();
                        
                        final teacherName = '${teacherResponse['fname']} ${teacherResponse['lname']}';
                        final sectionName = sectionResponse['name'];
                        
                        // Log teacher assignment creation
                        await auditLogService.logTeacherSectionAssignment(
                          action: 'assign',
                          teacherId: selectedTeacherId,
                          teacherName: teacherName,
                          sectionId: sectionId.toString(),
                          sectionName: sectionName,
                          subject: subjectController.text.trim(),
                        );
                        
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
                        
                        // Get teacher and section names for audit logging
                        final teacherResponse = await supabase
                            .from('users')
                            .select('fname, lname')
                            .eq('id', selectedTeacherId)
                            .single();
                        final sectionResponse = await supabase
                            .from('sections')
                            .select('name')
                            .eq('id', sectionId)
                            .single();
                        
                        final teacherName = '${teacherResponse['fname']} ${teacherResponse['lname']}';
                        final sectionName = sectionResponse['name'];
                        
                        // Log teacher assignment update
                        await auditLogService.logTeacherSectionAssignment(
                          action: 'update',
                          teacherId: selectedTeacherId,
                          teacherName: teacherName,
                          sectionId: sectionId.toString(),
                          sectionName: sectionName,
                          subject: subjectController.text.trim(),
                        );
                        
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
      // Get assignment details before deletion for audit logging
      final assignmentResponse = await supabase
          .from('section_teachers')
          .select('''
            teacher_id,
            section_id,
            subject,
            users!inner(fname, lname),
            sections!inner(name)
          ''')
          .eq('id', assignmentId)
          .single();
      
      final teacherId = assignmentResponse['teacher_id'];
      final sectionId = assignmentResponse['section_id'];
      final subject = assignmentResponse['subject'];
      final teacherName = '${assignmentResponse['users']['fname']} ${assignmentResponse['users']['lname']}';
      final sectionName = assignmentResponse['sections']['name'];
      
      await supabase.from('section_teachers').delete().eq('id', assignmentId);
      
      // Log teacher assignment deletion
      await auditLogService.logTeacherSectionAssignment(
        action: 'unassign',
        teacherId: teacherId,
        teacherName: teacherName,
        sectionId: sectionId.toString(),
        sectionName: sectionName,
        subject: subject,
      );
      
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

  // Fetch students for a specific section
  Future<List<Map<String, dynamic>>> _fetchStudentsForSection(int sectionId) async {
    final response = await supabase
        .from('students')
        .select('''
          id,
          fname,
          mname,
          lname,
          gender
        ''')
        .eq('section_id', sectionId)
        .order('gender', ascending: false) // Female first, then Male
        .order('lname', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  // Export sections functionality
  Future<void> _exportSections() async {
    try {
      if (sections.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No sections available to export'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFF2ECC71)),
              SizedBox(width: 16),
              Text('Exporting sections...'),
            ],
          ),
        ),
      );

      // Create Excel workbook
      var excel = excel_lib.Excel.createExcel();

      // Sort sections by grade level and section name
      final sortedSections = _sortSectionsByGradeAndName(sections);

      // Create summary sheet first
      var summarySheet = excel['Summary'];
      await _createSummarySheet(summarySheet, sortedSections);

      // Process each section
      for (final section in sortedSections) {
        final sectionId = section['id'];
        final sectionName = section['name'] ?? 'Unknown Section';
        final gradeLevel = section['grade_level'] ?? 'Unknown Grade';

        // Fetch students for this section
        final studentsInSection = await _fetchStudentsForSection(sectionId);
        
        // Fetch teacher assignments for this section
        final teacherAssignments = await _fetchSectionTeachers(sectionId);

        // Create sheet for this section with grade level in name
        final sanitizedSheetName = _sanitizeSheetName('$gradeLevel - $sectionName');
        var sheet = excel[sanitizedSheetName];

        // Populate the sheet
        await _populateSectionSheet(
          sheet,
          sectionName,
          gradeLevel,
          studentsInSection,
          teacherAssignments,
        );
      }

      // Clean up: Remove any default sheets
      final defaultSheetNames = ['Sheet1', 'Sheet', 'Worksheet'];
      for (String defaultName in defaultSheetNames) {
        if (excel.sheets.containsKey(defaultName)) {
          excel.delete(defaultName);
        }
      }

      // Set Summary as the default sheet
      excel.setDefaultSheet('Summary');

      // Generate and download file
      List<int>? fileBytes = excel.encode();
      if (fileBytes == null) {
        throw Exception('Failed to generate Excel file');
      }

      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      final fileName = 'Sections_Export_${timestamp}.xlsx';

      // Download file
      final blob = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';

      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Sections exported successfully: $fileName'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Sort sections by grade level hierarchy and then by section name
  List<Map<String, dynamic>> _sortSectionsByGradeAndName(List<Map<String, dynamic>> sections) {
    final gradeOrder = [
      'Preschool',
      'Kinder',
      'Grade 1',
      'Grade 2',
      'Grade 3',
      'Grade 4',
      'Grade 5',
      'Grade 6',
    ];

    int gradeIndex(String? grade) {
      if (grade == null) return gradeOrder.length + 1;
      final idx = gradeOrder.indexOf(grade);
      return idx >= 0 ? idx : gradeOrder.length + 1;
    }

    List<Map<String, dynamic>> sortedSections = List.from(sections);
    sortedSections.sort((a, b) {
      final aGradeIndex = gradeIndex(a['grade_level']?.toString());
      final bGradeIndex = gradeIndex(b['grade_level']?.toString());
      
      if (aGradeIndex != bGradeIndex) {
        return aGradeIndex.compareTo(bGradeIndex);
      }
      
      // If same grade, sort by section name alphabetically
      final aName = a['name']?.toString() ?? '';
      final bName = b['name']?.toString() ?? '';
      return aName.compareTo(bName);
    });

    return sortedSections;
  }

  // Create summary sheet with statistics and generation info
  Future<void> _createSummarySheet(
    excel_lib.Sheet sheet,
    List<Map<String, dynamic>> sections,
  ) async {
    int rowIndex = 0;

    // Get current user info
    final user = supabase.auth.currentUser;
    final userName = user?.userMetadata?['fname'] != null && user?.userMetadata?['lname'] != null
        ? '${user?.userMetadata?['fname']} ${user?.userMetadata?['lname']}'
        : user?.email ?? 'Unknown User';

    // Title
    var titleCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    titleCell.value = excel_lib.TextCellValue('SECTIONS EXPORT SUMMARY');
    titleCell.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 18);
    rowIndex += 2;

    // Generation info
    var dateCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    dateCell.value = excel_lib.TextCellValue('Export Date & Time:');
    dateCell.cellStyle = excel_lib.CellStyle(bold: true);
    
    var dateValueCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
    dateValueCell.value = excel_lib.TextCellValue(DateTime.now().toLocal().toString().split('.')[0]);
    rowIndex++;

    var generatedByCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    generatedByCell.value = excel_lib.TextCellValue('Generated By:');
    generatedByCell.cellStyle = excel_lib.CellStyle(bold: true);
    
    var generatedByValueCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
    generatedByValueCell.value = excel_lib.TextCellValue(userName);
    rowIndex += 2;

    // Overall statistics
    var statsHeaderCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    statsHeaderCell.value = excel_lib.TextCellValue('OVERALL STATISTICS');
    statsHeaderCell.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 16);
    rowIndex += 2;

    // Calculate total students across all sections
    int totalStudents = 0;
    int totalMaleStudents = 0;
    int totalFemaleStudents = 0;
    Map<String, int> gradeStats = {};
    
    for (final section in sections) {
      final studentsInSection = await _fetchStudentsForSection(section['id']);
      totalStudents += studentsInSection.length;
      
      final maleCount = studentsInSection.where((s) => s['gender']?.toString().toLowerCase() == 'male').length;
      final femaleCount = studentsInSection.where((s) => s['gender']?.toString().toLowerCase() == 'female').length;
      
      totalMaleStudents += maleCount;
      totalFemaleStudents += femaleCount;
      
      // Grade level statistics
      final gradeLevel = section['grade_level']?.toString() ?? 'Unknown';
      gradeStats[gradeLevel] = (gradeStats[gradeLevel] ?? 0) + studentsInSection.length;
    }

    // Display overall stats
    final overallStats = [
      ['Total Sections:', sections.length.toString()],
      ['Total Students:', totalStudents.toString()],
      ['Male Students:', totalMaleStudents.toString()],
      ['Female Students:', totalFemaleStudents.toString()],
    ];

    for (var stat in overallStats) {
      var labelCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
      labelCell.value = excel_lib.TextCellValue(stat[0]);
      labelCell.cellStyle = excel_lib.CellStyle(bold: true);

      var valueCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      valueCell.value = excel_lib.TextCellValue(stat[1]);

      rowIndex++;
    }

    rowIndex += 2;

    // Grade level breakdown
    var gradeBreakdownHeader = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    gradeBreakdownHeader.value = excel_lib.TextCellValue('STUDENTS BY GRADE LEVEL');
    gradeBreakdownHeader.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 14);
    rowIndex++;

    // Sort grade stats by grade order
    final gradeOrder = ['Preschool', 'Kinder', 'Grade 1', 'Grade 2', 'Grade 3', 'Grade 4', 'Grade 5', 'Grade 6'];
    final sortedGradeEntries = gradeStats.entries.toList();
    sortedGradeEntries.sort((a, b) {
      final aIndex = gradeOrder.indexOf(a.key);
      final bIndex = gradeOrder.indexOf(b.key);
      if (aIndex == -1 && bIndex == -1) return a.key.compareTo(b.key);
      if (aIndex == -1) return 1;
      if (bIndex == -1) return -1;
      return aIndex.compareTo(bIndex);
    });

    for (var entry in sortedGradeEntries) {
      var gradeCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
      gradeCell.value = excel_lib.TextCellValue('${entry.key}:');
      gradeCell.cellStyle = excel_lib.CellStyle(bold: true);

      var countCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      countCell.value = excel_lib.TextCellValue(entry.value.toString());

      rowIndex++;
    }

    rowIndex += 2;

    // Detailed section breakdown
    var sectionBreakdownHeader = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    sectionBreakdownHeader.value = excel_lib.TextCellValue('SECTION DETAILS');
    sectionBreakdownHeader.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 14);
    rowIndex++;

    // Column headers
    var headerRow = ['Section Name', 'Grade Level', 'Total Students', 'Male Students', 'Female Students', 'Teachers'];
    for (int col = 0; col < headerRow.length; col++) {
      var headerCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
      headerCell.value = excel_lib.TextCellValue(headerRow[col]);
      headerCell.cellStyle = excel_lib.CellStyle(bold: true);
    }
    rowIndex++;

    // Section data
    for (final section in sections) {
      final sectionName = section['name'] ?? 'Unknown Section';
      final gradeLevel = section['grade_level'] ?? 'Unknown Grade';
      
      final studentsInSection = await _fetchStudentsForSection(section['id']);
      final teacherAssignments = await _fetchSectionTeachers(section['id']);
      
      final maleCount = studentsInSection.where((s) => s['gender']?.toString().toLowerCase() == 'male').length;
      final femaleCount = studentsInSection.where((s) => s['gender']?.toString().toLowerCase() == 'female').length;
      
      final sectionData = [
        sectionName,
        gradeLevel,
        studentsInSection.length.toString(),
        maleCount.toString(),
        femaleCount.toString(),
        teacherAssignments.length.toString(),
      ];

      for (int col = 0; col < sectionData.length; col++) {
        var dataCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
        dataCell.value = excel_lib.TextCellValue(sectionData[col]);
      }
      rowIndex++;
    }

    // Set column widths for better readability
    sheet.setColumnWidth(0, 25.0);  // Section Name
    sheet.setColumnWidth(1, 15.0);  // Grade Level
    sheet.setColumnWidth(2, 15.0);  // Total Students
    sheet.setColumnWidth(3, 15.0);  // Male Students
    sheet.setColumnWidth(4, 15.0);  // Female Students
    sheet.setColumnWidth(5, 12.0);  // Teachers
  }

  // Sanitize sheet name for Excel compatibility
  String _sanitizeSheetName(String name) {
    // Excel sheet names can't contain these characters: / \ ? * [ ] :
    String sanitized = name.replaceAll(RegExp(r'[/\\?*\[\]:]+'), '_');
    // Excel sheet names can't be longer than 31 characters
    if (sanitized.length > 31) {
      sanitized = sanitized.substring(0, 31);
    }
    return sanitized;
  }

  // Populate individual section sheet
  Future<void> _populateSectionSheet(
    excel_lib.Sheet sheet,
    String sectionName,
    String gradeLevel,
    List<Map<String, dynamic>> students,
    List<Map<String, dynamic>> teacherAssignments,
  ) async {
    int rowIndex = 0;

    // Section Header Information
    var headerCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    headerCell.value = excel_lib.TextCellValue('SECTION: $sectionName');
    headerCell.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 16);
    rowIndex++;

    var gradeCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    gradeCell.value = excel_lib.TextCellValue('GRADE LEVEL: $gradeLevel');
    gradeCell.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 14);
    rowIndex += 2; // Add extra space

    // Add Name of Adviser, Male Students, Female Students labels
    var adviserCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    adviserCell.value = excel_lib.TextCellValue('Name of Adviser:');
    adviserCell.cellStyle = excel_lib.CellStyle(bold: true);
    rowIndex++;

    // Separate students by gender
    final maleStudents = students.where((s) => s['gender']?.toString().toLowerCase() == 'male').toList();
    final femaleStudents = students.where((s) => s['gender']?.toString().toLowerCase() == 'female').toList();

    var maleStudentsCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    maleStudentsCell.value = excel_lib.TextCellValue('Male Students: ${maleStudents.length}');
    maleStudentsCell.cellStyle = excel_lib.CellStyle(bold: true);
    rowIndex++;

    var femaleStudentsCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    femaleStudentsCell.value = excel_lib.TextCellValue('Female Students: ${femaleStudents.length}');
    femaleStudentsCell.cellStyle = excel_lib.CellStyle(bold: true);
    rowIndex += 2;

    // Calculate starting positions for columns
    const int maleStartCol = 0;
    const int femaleStartCol = 2;
    const int teacherStartCol = 7; // 3 columns gap after female students (columns 5, 6, 7 are empty)

    // Create headers with borders
    var maleHeaderCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: maleStartCol, rowIndex: rowIndex));
    maleHeaderCell.value = excel_lib.TextCellValue('No.');
    maleHeaderCell.cellStyle = excel_lib.CellStyle(
      bold: true,
      leftBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
      topBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
      rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
      bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
    );

    var maleNameHeaderCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: maleStartCol + 1, rowIndex: rowIndex));
    maleNameHeaderCell.value = excel_lib.TextCellValue('MALE');
    maleNameHeaderCell.cellStyle = excel_lib.CellStyle(
      bold: true,
      topBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
      rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
      bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
    );

    var femaleHeaderCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: femaleStartCol, rowIndex: rowIndex));
    femaleHeaderCell.value = excel_lib.TextCellValue('No.');
    femaleHeaderCell.cellStyle = excel_lib.CellStyle(
      bold: true,
      leftBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
      topBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
      rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
      bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
    );

    var femaleNameHeaderCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: femaleStartCol + 1, rowIndex: rowIndex));
    femaleNameHeaderCell.value = excel_lib.TextCellValue('FEMALE');
    femaleNameHeaderCell.cellStyle = excel_lib.CellStyle(
      bold: true,
      topBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
      rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
      bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
    );

    // Add teacher assignment headers if there are any teacher assignments
    if (teacherAssignments.isNotEmpty) {
      var teacherNameHeader = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: teacherStartCol, rowIndex: rowIndex));
      teacherNameHeader.value = excel_lib.TextCellValue('Teacher Name');
      teacherNameHeader.cellStyle = excel_lib.CellStyle(
        bold: true,
        leftBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        topBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
      );

      var subjectHeader = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: teacherStartCol + 1, rowIndex: rowIndex));
      subjectHeader.value = excel_lib.TextCellValue('Subject');
      subjectHeader.cellStyle = excel_lib.CellStyle(
        bold: true,
        topBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
      );

      var scheduleHeader = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: teacherStartCol + 2, rowIndex: rowIndex));
      scheduleHeader.value = excel_lib.TextCellValue('Schedule');
      scheduleHeader.cellStyle = excel_lib.CellStyle(
        bold: true,
        topBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
      );
    }

    rowIndex++;

    // Find the maximum count to determine how many rows we need (students vs teachers)
    final maxCount = [maleStudents.length, femaleStudents.length, teacherAssignments.length].reduce((a, b) => a > b ? a : b);

    // Populate student lists and teacher assignments simultaneously
    for (int i = 0; i < maxCount; i++) {
      // Male students column
      if (i < maleStudents.length) {
        final student = maleStudents[i];
        final fullName = '${student['fname'] ?? ''} ${student['mname'] ?? ''} ${student['lname'] ?? ''}'.trim();
        
        // Number column for male
        var numCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: maleStartCol, rowIndex: rowIndex + i));
        numCell.value = excel_lib.TextCellValue((i + 1).toString());
        numCell.cellStyle = excel_lib.CellStyle(
          leftBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        );
        
        // Name column for male
        var maleNameCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: maleStartCol + 1, rowIndex: rowIndex + i));
        maleNameCell.value = excel_lib.TextCellValue(fullName);
        maleNameCell.cellStyle = excel_lib.CellStyle(
          rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        );
      } else {
        // Empty cells with borders for male section
        var maleEmptyNumCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: maleStartCol, rowIndex: rowIndex + i));
        maleEmptyNumCell.value = excel_lib.TextCellValue('');
        maleEmptyNumCell.cellStyle = excel_lib.CellStyle(
          leftBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        );
        
        var maleEmptyNameCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: maleStartCol + 1, rowIndex: rowIndex + i));
        maleEmptyNameCell.value = excel_lib.TextCellValue('');
        maleEmptyNameCell.cellStyle = excel_lib.CellStyle(
          rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        );
      }

      // Female students column
      if (i < femaleStudents.length) {
        final student = femaleStudents[i];
        final fullName = '${student['fname'] ?? ''} ${student['mname'] ?? ''} ${student['lname'] ?? ''}'.trim();
        
        // Number column for female
        var femaleNumCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: femaleStartCol, rowIndex: rowIndex + i));
        femaleNumCell.value = excel_lib.TextCellValue((i + 1).toString());
        femaleNumCell.cellStyle = excel_lib.CellStyle(
          leftBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        );
        
        // Name column for female
        var femaleNameCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: femaleStartCol + 1, rowIndex: rowIndex + i));
        femaleNameCell.value = excel_lib.TextCellValue(fullName);
        femaleNameCell.cellStyle = excel_lib.CellStyle(
          rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        );
      } else {
        // Empty cells with borders for female section
        var femaleEmptyNumCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: femaleStartCol, rowIndex: rowIndex + i));
        femaleEmptyNumCell.value = excel_lib.TextCellValue('');
        femaleEmptyNumCell.cellStyle = excel_lib.CellStyle(
          leftBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        );
        
        var femaleEmptyNameCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: femaleStartCol + 1, rowIndex: rowIndex + i));
        femaleEmptyNameCell.value = excel_lib.TextCellValue('');
        femaleEmptyNameCell.cellStyle = excel_lib.CellStyle(
          rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        );
        
        var nameCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: femaleStartCol + 1, rowIndex: rowIndex + i));
        nameCell.value = excel_lib.TextCellValue('');
        nameCell.cellStyle = excel_lib.CellStyle(
          rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        );
      }

      // Teacher assignments data (populate alongside student data)
      if (i < teacherAssignments.length) {
        final assignment = teacherAssignments[i];
        final teacher = assignment['users'];
        final teacherName = teacher != null 
            ? '${teacher['fname']} ${teacher['lname']}'
            : 'Unknown Teacher';
        final subject = assignment['subject'] ?? 'No Subject';
        final days = assignment['days'] != null ? (assignment['days'] as List) : [];
        final startTime = assignment['start_time'] ?? '';
        final endTime = assignment['end_time'] ?? '';
        
        // Format days into ranges if possible
        String formattedDays = _formatDaysAsRanges(days);
        final schedule = '$formattedDays ${startTime.isNotEmpty && endTime.isNotEmpty ? '$startTime - $endTime' : ''}'.trim();

        var teacherNameCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: teacherStartCol, rowIndex: rowIndex + i));
        teacherNameCell.value = excel_lib.TextCellValue(teacherName);
        teacherNameCell.cellStyle = excel_lib.CellStyle(
          leftBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        );

        var subjectCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: teacherStartCol + 1, rowIndex: rowIndex + i));
        subjectCell.value = excel_lib.TextCellValue(subject);
        subjectCell.cellStyle = excel_lib.CellStyle(
          rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        );

        var scheduleCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: teacherStartCol + 2, rowIndex: rowIndex + i));
        scheduleCell.value = excel_lib.TextCellValue(schedule);
        scheduleCell.cellStyle = excel_lib.CellStyle(
          rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        );
      } else if (teacherAssignments.isNotEmpty) {
        // Empty cells with borders for teacher section when no more teachers
        var teacherEmptyNameCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: teacherStartCol, rowIndex: rowIndex + i));
        teacherEmptyNameCell.value = excel_lib.TextCellValue('');
        teacherEmptyNameCell.cellStyle = excel_lib.CellStyle(
          leftBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        );
        
        var teacherEmptySubjectCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: teacherStartCol + 1, rowIndex: rowIndex + i));
        teacherEmptySubjectCell.value = excel_lib.TextCellValue('');
        teacherEmptySubjectCell.cellStyle = excel_lib.CellStyle(
          rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        );
        
        var teacherEmptyScheduleCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: teacherStartCol + 2, rowIndex: rowIndex + i));
        teacherEmptyScheduleCell.value = excel_lib.TextCellValue('');
        teacherEmptyScheduleCell.cellStyle = excel_lib.CellStyle(
          rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        );
      }
    }

    rowIndex += maxCount + 2; // Move past all lists with spacing

    // Set column widths for better readability and auto-fit content
    sheet.setColumnWidth(0, 8.0);   // Number columns (male)
    sheet.setColumnWidth(1, 30.0);  // Male names (increased for auto-fit)
    sheet.setColumnWidth(2, 4.0);   // Gap between male and female
    sheet.setColumnWidth(3, 8.0);   // Female number column  
    sheet.setColumnWidth(4, 30.0);  // Female names (increased for auto-fit)
    sheet.setColumnWidth(5, 4.0);   // Gap column
    sheet.setColumnWidth(6, 4.0);   // Gap column
    sheet.setColumnWidth(7, 4.0);   // Gap column
    sheet.setColumnWidth(8, 25.0);  // Teacher names
    sheet.setColumnWidth(9, 20.0);  // Subject
    sheet.setColumnWidth(10, 30.0); // Schedule (increased for auto-fit)
  }

  // Helper method to format days as ranges
  String _formatDaysAsRanges(List days) {
    if (days.isEmpty) return '';
    
    // Convert to list of strings and sort by day order
    final dayNames = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri'];
    List<String> sortedDays = [];
    
    for (String dayName in dayNames) {
      if (days.contains(dayName)) {
        sortedDays.add(dayName);
      }
    }
    
    if (sortedDays.isEmpty) return days.join(', ');
    
    // Group consecutive days into ranges
    List<String> ranges = [];
    int start = 0;
    
    while (start < sortedDays.length) {
      int end = start;
      
      // Find consecutive days
      while (end + 1 < sortedDays.length && 
             dayNames.indexOf(sortedDays[end + 1]) == dayNames.indexOf(sortedDays[end]) + 1) {
        end++;
      }
      
      // Create range string
      if (start == end) {
        ranges.add(sortedDays[start]);
      } else if (end - start == 1) {
        ranges.add('${sortedDays[start]}, ${sortedDays[end]}');
      } else {
        ranges.add('${sortedDays[start]}-${sortedDays[end]}');
      }
      
      start = end + 1;
    }
    
    return ranges.join(', ');
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
      // Custom grade order so Preschool and Kinder appear first
      final gradeOrder = [
        'Preschool',
        'Kinder',
        'Grade 1',
        'Grade 2',
        'Grade 3',
        'Grade 4',
        'Grade 5',
        'Grade 6',
      ];

      int gradeIndex(String? grade) {
        if (grade == null) return gradeOrder.length + 1;
        final idx = gradeOrder.indexOf(grade);
        // If grade not in predefined list, push it after known grades
        return idx >= 0 ? idx : gradeOrder.length + 1;
      }

      displaySections.sort((a, b) {
        final ai = gradeIndex((a['grade_level'] ?? '').toString());
        final bi = gradeIndex((b['grade_level'] ?? '').toString());
        if (ai != bi) return ai.compareTo(bi);
        // If same order, fallback to name comparison
        return (a['name'] ?? '').toString().compareTo(
          (b['name'] ?? '').toString(),
        );
      });
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
        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Responsive Header
            if (isMobile) ...[
              // Mobile: Stacked layout
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Section Management",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Mobile search bar
                  Container(
                    width: double.infinity,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search sections...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9E9E9E),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Color(0xFF2ECC71),
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 12.0,
                          horizontal: 16.0,
                        ),
                      ),
                      onChanged:
                          (val) => setState(() {
                            _searchQuery = val;
                          }),
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Mobile action buttons
                  Row(
                    children: [
                      Expanded(
                        child: SizedBox(
                          height: 44,
                          child: ElevatedButton.icon(
                            icon: const Icon(
                              Icons.add,
                              color: Colors.white,
                              size: 18,
                            ),
                            label: Text(
                              isSmallMobile ? "Add" : "Add New Section",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF2ECC71),
                              foregroundColor: Colors.white,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              elevation: 2,
                              shadowColor: Colors.black.withOpacity(0.1),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                            onPressed: () => _addOrEditSection(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        height: 44,
                        child: OutlinedButton.icon(
                          icon: const Icon(
                            Icons.file_download_outlined,
                            color: Color(0xFF2ECC71),
                            size: 18,
                          ),
                          label: Text(
                            isSmallMobile ? "Export" : "Export",
                            style: const TextStyle(
                              color: Color(0xFF2ECC71),
                              fontSize: 14,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          style: OutlinedButton.styleFrom(
                            backgroundColor: Colors.white,
                            side: const BorderSide(
                              color: Color(0xFF2ECC71),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                            elevation: 1,
                            shadowColor: Colors.black.withOpacity(0.05),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 10,
                            ),
                          ),
                          onPressed: _exportSections,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ] else ...[
              // Desktop/Tablet: Horizontal layout
              Row(
                children: [
                  const Text(
                    "Section Management",
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: 0.5,
                    ),
                  ),
                  const Spacer(),
                  // Responsive search bar
                  Container(
                    width: isTablet ? 240 : 260,
                    height: 44,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: TextField(
                      decoration: const InputDecoration(
                        hintText: 'Search sections...',
                        hintStyle: TextStyle(
                          fontSize: 14,
                          color: Color(0xFF9E9E9E),
                        ),
                        prefixIcon: Icon(
                          Icons.search,
                          color: Color(0xFF2ECC71),
                          size: 20,
                        ),
                        border: InputBorder.none,
                        contentPadding: EdgeInsets.symmetric(
                          vertical: 12.0,
                          horizontal: 16.0,
                        ),
                      ),
                      onChanged:
                          (val) => setState(() {
                            _searchQuery = val;
                          }),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Responsive Add New button
                  SizedBox(
                    height: 44,
                    child: ElevatedButton.icon(
                      icon: const Icon(
                        Icons.add,
                        color: Colors.white,
                        size: 18,
                      ),
                      label: Text(
                        isTablet ? "Add Section" : "Add New Section",
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2ECC71),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 2,
                        shadowColor: Colors.black.withOpacity(0.1),
                        padding: EdgeInsets.symmetric(
                          horizontal: isTablet ? 12 : 16,
                          vertical: 10,
                        ),
                      ),
                      onPressed: () => _addOrEditSection(),
                    ),
                  ),
                  const SizedBox(width: 12),
                  // Responsive Export button
                  SizedBox(
                    height: 44,
                    child: OutlinedButton.icon(
                      icon: const Icon(
                        Icons.file_download_outlined,
                        color: Color(0xFF2ECC71),
                        size: 18,
                      ),
                      label: const Text(
                        "Export",
                        style: TextStyle(
                          color: Color(0xFF2ECC71),
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.white,
                        side: const BorderSide(
                          color: Color(0xFF2ECC71),
                          width: 1.5,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                        elevation: 1,
                        shadowColor: Colors.black.withOpacity(0.05),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                      ),
                      onPressed: _exportSections,
                    ),
                  ),
                ],
              ),
            ],

            // Responsive Breadcrumb
            Padding(
              padding: EdgeInsets.only(
                top: 8.0,
                bottom: isMobile ? 16.0 : 24.0,
              ),
              child: Text(
                "Home / Section Management",
                style: TextStyle(
                  fontSize: isMobile ? 11 : 12,
                  color: const Color(0xFF9E9E9E),
                ),
              ),
            ),

            // Responsive Filter row
            Container(
              padding: const EdgeInsets.only(bottom: 16.0),
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFEEEEEE))),
              ),
              child:
                  isMobile
                      ? Column(
                        children: [
                          // Mobile: Stacked filters
                          Container(
                            width: double.infinity,
                            height: 48,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                              ),
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
                          const SizedBox(height: 12),
                          Container(
                            width: double.infinity,
                            height: 48,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                              ),
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
                                    ].map<DropdownMenuItem<String>>((
                                      String value,
                                    ) {
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
                      )
                      : Row(
                        children: [
                          // Desktop/Tablet: Horizontal filters
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                              ),
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
                          Container(
                            height: 48,
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16.0,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                              ),
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
                                    ].map<DropdownMenuItem<String>>((
                                      String value,
                                    ) {
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

            // Responsive Stats row
            if (isLoading)
              const Center(
                child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
              )
            else
              Container(
                padding: EdgeInsets.all(isMobile ? 16 : 20),
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
                child:
                    isMobile
                        ? Column(
                          children: [
                            // Mobile: Stacked stats
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(16),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2ECC71,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: const Icon(
                                    Icons.class_,
                                    color: Color(0xFF2ECC71),
                                    size: 28,
                                  ),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            Row(
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
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Mobile: Centered active indicator
                            Center(
                              child: Container(
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
                            ),
                          ],
                        )
                        : Row(
                          children: [
                            // Desktop/Tablet: Horizontal stats
                            Expanded(
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: const Color(
                                        0xFF2ECC71,
                                      ).withOpacity(0.1),
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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

            // Responsive Table
            Expanded(
              child:
                  isLoading
                      ? const Center(
                        child: CircularProgressIndicator(
                          color: Color(0xFF2ECC71),
                        ),
                      )
                      : displaySections.isEmpty
                      ? Center(
                        child: Container(
                          padding: EdgeInsets.all(isMobile ? 24 : 32),
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
                                size: isMobile ? 48 : 64,
                                color: Colors.grey[400],
                              ),
                              SizedBox(height: isMobile ? 12 : 16),
                              Text(
                                _searchQuery.trim().isEmpty
                                    ? "No sections found"
                                    : "No sections match \"${_searchQuery.trim()}\"",
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: isMobile ? 14 : 16,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                "Try a different search term or clear filters.",
                                style: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: isMobile ? 12 : 13,
                                ),
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  setState(() {
                                    _searchQuery = '';
                                    _gradeFilter = 'All Grades';
                                  });
                                },
                                icon: const Icon(Icons.search),
                                label: Text(
                                  isMobile
                                      ? 'Clear Filters'
                                      : 'Clear Search / Filters',
                                  style: TextStyle(
                                    fontSize: isMobile ? 13 : 14,
                                  ),
                                ),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2ECC71),
                                  foregroundColor: Colors.white,
                                  padding: EdgeInsets.symmetric(
                                    horizontal: isMobile ? 20 : 24,
                                    vertical: isMobile ? 10 : 12,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                      : isMobile
                      ? _buildMobileTable(displaySections)
                      : _buildDesktopTable(displaySections),
            ),
          ],
        ),
      ),
    );
  }

  // Mobile table layout
  Widget _buildMobileTable(List<Map<String, dynamic>> displaySections) {
    return Container(
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
          // Mobile table header
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
              border: Border(
                bottom: BorderSide(color: Colors.grey[200]!, width: 2),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.class_, color: Color(0xFF2ECC71), size: 20),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Sections Overview',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
                Text(
                  '${sections.length} section${sections.length == 1 ? '' : 's'}',
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
          // Mobile table content - card layout
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: displaySections.length,
              separatorBuilder: (context, index) => const SizedBox(height: 12),
              itemBuilder: (context, index) {
                final section = displaySections[index];
                final createdAt =
                    section['created_at'] != null
                        ? DateTime.tryParse(section['created_at'])
                        : null;
                final createdStr =
                    createdAt != null
                        ? "${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}"
                        : "N/A";

                return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Section header
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2ECC71).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'SEC${section['id'].toString().padLeft(3, '0')}',
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF2ECC71),
                                fontSize: 12,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _getGradeColor(
                                section['grade_level'],
                              ).withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _getGradeColor(
                                  section['grade_level'],
                                ).withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              section['grade_level'] ?? 'N/A',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: _getGradeColor(section['grade_level']),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),

                      // Section name
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: Colors.blue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.class_,
                              size: 14,
                              color: Colors.blue[600],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              section['name'] ?? '',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1A1A1A),
                                fontSize: 16,
                                letterSpacing: 0.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      // Created date
                      Row(
                        children: [
                          Icon(
                            Icons.calendar_today,
                            size: 12,
                            color: Colors.grey[600],
                          ),
                          const SizedBox(width: 4),
                          Text(
                            createdStr,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[600],
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Action buttons
                      Row(
                        children: [
                          Expanded(
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.group, size: 16),
                              label: const Text(
                                "Teachers",
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: const Color(0xFF2ECC71),
                                foregroundColor: Colors.white,
                                elevation: 2,
                                shadowColor: Colors.black.withOpacity(0.1),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 12,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed:
                                  () => _showManageTeachersDialog(
                                    section['id'],
                                    section['name'],
                                  ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          PopupMenuButton<String>(
                            icon: Icon(
                              Icons.more_vert,
                              color: Colors.grey[600],
                              size: 18,
                            ),
                            tooltip: 'More options',
                            onSelected: (value) async {
                              if (value == 'edit') {
                                await _addOrEditSection(section: section);
                              } else if (value == 'delete') {
                                final confirm = await _showDeleteConfirmDialog(
                                  section['name'],
                                );
                                if (confirm) {
                                  await _deleteSection(section['id']);
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
                                          size: 16,
                                          color: Color(0xFF2ECC71),
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Edit Section',
                                          style: TextStyle(fontSize: 13),
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
                                          size: 16,
                                          color: Colors.red,
                                        ),
                                        SizedBox(width: 8),
                                        Text(
                                          'Delete Section',
                                          style: TextStyle(
                                            fontSize: 13,
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
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // Desktop/Tablet table layout
  Widget _buildDesktopTable(List<Map<String, dynamic>> displaySections) {
    return Container(
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
                bottom: BorderSide(color: Colors.grey[200]!, width: 2),
              ),
            ),
            child: Row(
              children: [
                const Icon(Icons.class_, color: Color(0xFF2ECC71), size: 24),
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
                columnWidths:
                    isTablet
                        ? const {
                          0: FlexColumnWidth(0.7), // Section ID
                          1: FlexColumnWidth(1.3), // Section Name
                          2: FlexColumnWidth(0.9), // Grade Level
                          3: FlexColumnWidth(1.1), // Created At
                          4: FlexColumnWidth(1.3), // Actions
                        }
                        : const {
                          0: FlexColumnWidth(0.8), // Section ID
                          1: FlexColumnWidth(1.5), // Section Name
                          2: FlexColumnWidth(1.0), // Grade Level
                          3: FlexColumnWidth(1.2), // Created At
                          4: FlexColumnWidth(1.5), // Actions
                        },
                defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                children: [
                  // Table header row
                  TableRow(
                    decoration: BoxDecoration(
                      color: Color(0xFFF8F9FA),
                      border: Border(
                        bottom: BorderSide(color: Colors.grey[200]!, width: 2),
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
                  // Table data rows
                  ...displaySections.map((section) {
                    final createdAt =
                        section['created_at'] != null
                            ? DateTime.tryParse(section['created_at'])
                            : null;
                    final createdStr =
                        createdAt != null
                            ? "${createdAt.year}-${createdAt.month.toString().padLeft(2, '0')}-${createdAt.day.toString().padLeft(2, '0')}"
                            : "N/A";

                    return TableRow(
                      decoration: const BoxDecoration(color: Colors.white),
                      children: [
                        // Section ID with enhanced styling
                        TableCell(
                          child: Container(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2ECC71,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'SEC${section['id'].toString().padLeft(3, '0')}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFF2ECC71),
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
                                  padding: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: Colors.blue.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(8),
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
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF1A1A1A),
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
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _getGradeColor(
                                        section['grade_level'],
                                      ).withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: _getGradeColor(
                                          section['grade_level'],
                                        ).withOpacity(0.3),
                                      ),
                                    ),
                                    child: Text(
                                      section['grade_level'] ?? 'N/A',
                                      style: TextStyle(
                                        fontSize: 13,
                                        fontWeight: FontWeight.w700,
                                        color: _getGradeColor(
                                          section['grade_level'],
                                        ),
                                      ),
                                      overflow: TextOverflow.ellipsis,
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
                                    fontWeight: FontWeight.w500,
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
                                    icon: const Icon(Icons.group, size: 18),
                                    label: Text(
                                      "Teachers",
                                      style: TextStyle(
                                        fontSize: isTablet ? 13 : 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2ECC71),
                                      foregroundColor: Colors.white,
                                      elevation: 2,
                                      shadowColor: Colors.black.withOpacity(
                                        0.1,
                                      ),
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isTablet ? 10 : 12,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    onPressed:
                                        () => _showManageTeachersDialog(
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
                                      await _addOrEditSection(section: section);
                                    } else if (value == 'delete') {
                                      final confirm =
                                          await _showDeleteConfirmDialog(
                                            section['name'],
                                          );
                                      if (confirm) {
                                        await _deleteSection(section['id']);
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
                                                'Edit Section',
                                                style: TextStyle(
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
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
                                                'Delete Section',
                                                style: TextStyle(
                                                  color: Colors.red,
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
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
