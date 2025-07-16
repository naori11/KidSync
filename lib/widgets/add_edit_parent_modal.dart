import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddEditParentModal extends StatefulWidget {
  final Map<String, dynamic>? parent;
  final VoidCallback onClose;
  final Function(Map<String, dynamic>) onSave;

  const AddEditParentModal({
    super.key,
    this.parent,
    required this.onClose,
    required this.onSave,
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
      print('Fetching available students...');
      
      // Fetch ALL students without status filter since status can be null
      // Only exclude students with status = 'deleted' if that exists
      final response = await supabase
          .from('students')
          .select('id, fname, mname, lname, grade_level, section_id, status')
          .neq('status', 'deleted'); // Only exclude deleted students

      print('Raw students response: $response');
      print('Number of students found: ${response.length}');

      if (response.isEmpty) {
        print('No students found in database');
        setState(() {
          availableStudents = [];
          isLoadingStudents = false;
        });
        return;
      }

      // Process all students (including those with null status)
      final processedStudents = response.map<Map<String, dynamic>>((student) {
        print('Processing student: ${student['fname']} ${student['lname']} (ID: ${student['id']})');
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

      print('Processed students: ${processedStudents.length}');
      for (var student in processedStudents) {
        print('Student: ${student['first_name']} ${student['last_name']} - Grade: ${student['grade']} - Section: ${student['section']}');
      }
      
      setState(() {
        availableStudents = processedStudents;
        isLoadingStudents = false;
      });

      print('Available students set in state: ${availableStudents.length}');
    } catch (error) {
      print('Error fetching students: $error');
      print('Error type: ${error.runtimeType}');
      setState(() => isLoadingStudents = false);
      _showErrorSnackBar('Error fetching students: $error');
    }
  }

  Future<void> _saveParent() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() => isLoading = true);
    
    try {
      final parentData = {
        'fname': _firstNameController.text.trim(),
        'mname': _middleNameController.text.trim().isEmpty ? null : _middleNameController.text.trim(),
        'lname': _lastNameController.text.trim(),
        'phone': _phoneController.text.trim(),
        'email': _emailController.text.trim(),
        'address': _addressController.text.trim().isEmpty ? null : _addressController.text.trim(),
        'status': 'active',
      };

      print('Saving parent data: $parentData');

      Map<String, dynamic> savedParent;
      
      if (widget.parent == null) {
        // Create new parent
        final response = await supabase
            .from('parents')
            .insert(parentData)
            .select()
            .single();
        savedParent = response;
        print('Created new parent: $savedParent');
      } else {
        // Update existing parent
        final response = await supabase
            .from('parents')
            .update(parentData)
            .eq('id', widget.parent!['id'])
            .select()
            .single();
        savedParent = response;
        print('Updated parent: $savedParent');
      }

      // Handle student relationships
      final parentId = savedParent['id'];
      
      // Delete existing relationships if editing
      if (widget.parent != null) {
        await supabase
            .from('parent_student')
            .delete()
            .eq('parent_id', parentId);
        print('Deleted existing relationships for parent $parentId');
      }
      
      // Insert new relationships
      if (selectedStudents.isNotEmpty) {
        final relationships = selectedStudents.map((student) => {
          'parent_id': parentId,
          'student_id': student['id'],
          'relationship_type': student['relationship_type'] ?? 'parent',
          'is_primary': student['is_primary'] ?? false,
        }).toList();
        
        print('Inserting relationships: $relationships');
        await supabase.from('parent_student').insert(relationships);
        print('Inserted ${relationships.length} relationships');
      }
      
      setState(() => isLoading = false);
      widget.onSave(savedParent);
    } catch (error) {
      print('Error saving parent: $error');
      setState(() => isLoading = false);
      _showErrorSnackBar('Error saving parent: $error');
    }
  }

  void _toggleStudentSelection(Map<String, dynamic> student) {
    setState(() {
      final existingIndex = selectedStudents.indexWhere((s) => s['id'] == student['id']);
      if (existingIndex >= 0) {
        selectedStudents.removeAt(existingIndex);
        print('Removed student: ${student['first_name']} ${student['last_name']}');
      } else {
        selectedStudents.add({
          ...student,
          'relationship_type': 'parent',
          'is_primary': false,
        });
        print('Added student: ${student['first_name']} ${student['last_name']}');
      }
      print('Selected students count: ${selectedStudents.length}');
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
                      onPressed: widget.onClose,
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
                          
                          // Debug info for students
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Debug Info:',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.grey[800],
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  'Loading: $isLoadingStudents',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                                ),
                                Text(
                                  'Available students: ${availableStudents.length}',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                                ),
                                Text(
                                  'Selected students: ${selectedStudents.length}',
                                  style: TextStyle(color: Colors.grey[600], fontSize: 10),
                                ),
                              ],
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
                      onPressed: widget.onClose,
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