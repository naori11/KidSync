import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddEditParentModal extends StatefulWidget {
  final Map<String, dynamic>? parent;
  // onClose: Close the modal (Navigator.pop(context) in parent recommended)
  // onSave: Returns a Map<String, dynamic> containing all parent fields and studentsToLink
  const AddEditParentModal({
    super.key,
    this.parent,
  });

  @override
  State<AddEditParentModal> createState() => _AddEditParentModalState();
}

class _AddEditParentModalState extends State<AddEditParentModal> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  late TextEditingController _firstNameController;
  late TextEditingController _middleNameController;
  late TextEditingController _lastNameController;
  late TextEditingController _phoneController;
  late TextEditingController _emailController;
  late TextEditingController _addressController;

  List<Map<String, dynamic>> availableStudents = [];
  List<Map<String, dynamic>> selectedStudents = [];
  bool isLoading = false;
  bool isLoadingStudents = false;

  @override
  void initState() {
    super.initState();
    _initializeControllers();
    _fetchAvailableStudents();
  }

  void _initializeControllers() {
    _firstNameController = TextEditingController(text: widget.parent?['first_name'] ?? '');
    _middleNameController = TextEditingController(text: widget.parent?['middle_name'] ?? '');
    _lastNameController = TextEditingController(text: widget.parent?['last_name'] ?? '');
    _phoneController = TextEditingController(text: widget.parent?['phone'] ?? '');
    _emailController = TextEditingController(text: widget.parent?['email'] ?? '');
    _addressController = TextEditingController(text: widget.parent?['address'] ?? '');

    // Initialize selected students if editing
    if (widget.parent != null && widget.parent!['students'] != null) {
      selectedStudents = List<Map<String, dynamic>>.from(widget.parent!['students']);
    }
  }

  Future<void> _fetchAvailableStudents() async {
    setState(() => isLoadingStudents = true);

    try {
      // Fetch students that are not deleted (status != 'deleted')
      final response = await supabase
          .from('students')
          .select('id, fname, mname, lname, grade_level, section_id, status')
          .neq('status', 'deleted');

      // If no students, set empty list
      if (response == null || (response is List && response.isEmpty)) {
        setState(() {
          availableStudents = [];
          isLoadingStudents = false;
        });
        return;
      }

      // Map response to expected student structure
      final processedStudents = (response as List).map<Map<String, dynamic>>((student) {
        return {
          'id': student['id'],
          'first_name': student['fname'] ?? '',
          'middle_name': student['mname'] ?? '',
          'last_name': student['lname'] ?? '',
          'grade': student['grade_level']?.toString() ?? 'N/A',
          'section': student['section_id'] ?? 'N/A',
          'status': student['status'],
        };
      }).toList();

      setState(() {
        availableStudents = processedStudents;
        isLoadingStudents = false;
      });
    } catch (error) {
      setState(() => isLoadingStudents = false);
      _showErrorSnackBar('Error fetching students: $error');
    }
  }

  void _toggleStudentSelection(Map<String, dynamic> student) {
    setState(() {
      final existingIndex = selectedStudents.indexWhere((s) => s['id'] == student['id']);
      if (existingIndex >= 0) {
        selectedStudents.removeAt(existingIndex);
      } else {
        selectedStudents.add({
          ...student,
          'relationship_type': 'parent',
          'is_primary': false,
        });
      }
    });
  }

  void _updateStudentRelationship(int index, String relationshipType) {
    setState(() {
      selectedStudents[index]['relationship_type'] = relationshipType;
    });
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  void _saveParent() {
    if (!_formKey.currentState!.validate()) return;
    // Return to parent: all form fields, plus selectedStudents as studentsToLink
    Navigator.of(context).pop({
      'fname': _firstNameController.text.trim(),
      'mname': _middleNameController.text.trim().isEmpty ? null : _middleNameController.text.trim(),
      'lname': _lastNameController.text.trim(),
      'phone': _phoneController.text.trim(),
      'email': _emailController.text.trim(),
      'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
      'studentsToLink': selectedStudents.map((student) => {
        'student_id': student['id'],
        'relationship_type': student['relationship_type'] ?? 'parent',
        'is_primary': student['is_primary'] ?? false,
      }).toList(),
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            width: 800,
            height: 700,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      widget.parent == null ? 'Add New Parent' : 'Edit Parent',
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                // Form
                Expanded(
                  child: Form(
                    key: _formKey,
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Parent Information Section
                          const Text(
                            'Parent Information',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Name fields row
                          Row(
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _firstNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'First Name *',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value?.trim().isEmpty ?? true) {
                                      return 'First name is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _middleNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Middle Name',
                                    border: OutlineInputBorder(),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _lastNameController,
                                  decoration: const InputDecoration(
                                    labelText: 'Last Name *',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value?.trim().isEmpty ?? true) {
                                      return 'Last name is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Contact fields row
                          Row(
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _phoneController,
                                  decoration: const InputDecoration(
                                    labelText: 'Phone Number *',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value?.trim().isEmpty ?? true) {
                                      return 'Phone number is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: TextFormField(
                                  controller: _emailController,
                                  decoration: const InputDecoration(
                                    labelText: 'Email Address *',
                                    border: OutlineInputBorder(),
                                  ),
                                  validator: (value) {
                                    if (value?.trim().isEmpty ?? true) {
                                      return 'Email is required';
                                    }
                                    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                                      return 'Enter a valid email';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                            ],
                          ),

                          const SizedBox(height: 16),

                          // Address field
                          TextFormField(
                            controller: _addressController,
                            decoration: const InputDecoration(
                              labelText: 'Address',
                              border: OutlineInputBorder(),
                            ),
                            maxLines: 2,
                          ),

                          const SizedBox(height: 32),

                          // Student Selection Section
                          const Text(
                            'Select Students',
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 16),

                          // Available Students
                          if (isLoadingStudents)
                            const Center(
                              child: Column(
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 8),
                                  Text('Loading students...'),
                                ],
                              ),
                            )
                          else if (availableStudents.isEmpty)
                            Container(
                              height: 100,
                              decoration: BoxDecoration(
                                border: Border.all(color: Colors.grey.shade300),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: const Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.school_outlined, size: 32, color: Colors.grey),
                                    SizedBox(height: 8),
                                    Text(
                                      'No students found in database.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Please add students first.',
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: Colors.grey, fontSize: 12),
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else
                            SizedBox(
                              height: 250,
                              child: Column(
                                children: [
                                  // Selected Students
                                  if (selectedStudents.isNotEmpty) ...[
                                    Container(
                                      alignment: Alignment.centerLeft,
                                      child: const Text(
                                        'Selected Students:',
                                        style: TextStyle(fontWeight: FontWeight.w500),
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      height: 80,
                                      child: ListView.builder(
                                        itemCount: selectedStudents.length,
                                        itemBuilder: (context, index) {
                                          final student = selectedStudents[index];
                                          return Card(
                                            child: ListTile(
                                              dense: true,
                                              leading: CircleAvatar(
                                                radius: 16,
                                                backgroundColor: const Color(0xFF2ECC71),
                                                child: Text(
                                                  (student['first_name'] ?? 'N')[0].toUpperCase(),
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              title: Text(
                                                '${student['first_name'] ?? 'Unknown'} ${student['last_name'] ?? 'Student'}',
                                                style: const TextStyle(fontSize: 14),
                                              ),
                                              subtitle: Text(
                                                'Grade ${student['grade']} - Section ${student['section']}',
                                                style: const TextStyle(fontSize: 12),
                                              ),
                                              trailing: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  SizedBox(
                                                    width: 100,
                                                    child: DropdownButton<String>(
                                                      value: student['relationship_type'],
                                                      isExpanded: true,
                                                      items: const [
                                                        DropdownMenuItem(value: 'parent', child: Text('Parent')),
                                                        DropdownMenuItem(value: 'guardian', child: Text('Guardian')),
                                                        DropdownMenuItem(value: 'emergency_contact', child: Text('Emergency')),
                                                      ],
                                                      onChanged: (value) {
                                                        if (value != null) {
                                                          _updateStudentRelationship(index, value);
                                                        }
                                                      },
                                                    ),
                                                  ),
                                                  IconButton(
                                                    icon: const Icon(Icons.remove_circle, color: Colors.red),
                                                    onPressed: () => _toggleStudentSelection(student),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                    const SizedBox(height: 16),
                                  ],

                                  // Available Students Header
                                  Container(
                                    alignment: Alignment.centerLeft,
                                    child: Text(
                                      'Available Students (${availableStudents.length}):',
                                      style: const TextStyle(fontWeight: FontWeight.w500),
                                    ),
                                  ),
                                  const SizedBox(height: 8),

                                  // Available Students List
                                  Expanded(
                                    child: Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(color: Colors.grey.shade300),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: availableStudents.isEmpty
                                          ? const Center(
                                              child: Text(
                                                'No students available',
                                                style: TextStyle(color: Colors.grey),
                                              ),
                                            )
                                          : ListView.builder(
                                              itemCount: availableStudents.length,
                                              itemBuilder: (context, index) {
                                                final student = availableStudents[index];
                                                final isSelected = selectedStudents.any((s) => s['id'] == student['id']);

                                                return ListTile(
                                                  dense: true,
                                                  leading: CircleAvatar(
                                                    radius: 16,
                                                    backgroundColor: isSelected
                                                        ? const Color(0xFF2ECC71)
                                                        : Colors.grey.shade300,
                                                    child: Text(
                                                      (student['first_name'] ?? 'N')[0].toUpperCase(),
                                                      style: TextStyle(
                                                        color: isSelected ? Colors.white : Colors.black87,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  title: Text(
                                                    '${student['first_name'] ?? 'Unknown'} ${student['last_name'] ?? 'Student'}',
                                                    style: const TextStyle(fontSize: 14),
                                                  ),
                                                  subtitle: Text(
                                                    'Grade ${student['grade']} - Section ${student['section']}',
                                                    style: const TextStyle(fontSize: 12),
                                                  ),
                                                  trailing: isSelected
                                                      ? const Icon(Icons.check_circle, color: Color(0xFF2ECC71))
                                                      : const Icon(Icons.add_circle_outline, color: Colors.grey),
                                                  onTap: () => _toggleStudentSelection(student),
                                                );
                                              },
                                            ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),

                // Action buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 16),
                    ElevatedButton(
                      onPressed: isLoading ? null : _saveParent,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF2ECC71),
                        foregroundColor: Colors.white,
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            )
                          : Text(widget.parent == null ? 'Add Parent' : 'Update Parent'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _addressController.dispose();
    super.dispose();
  }
}