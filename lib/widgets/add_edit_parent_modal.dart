import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';

class AddEditParentModal extends StatefulWidget {
  final Map<String, dynamic>? parent;
  final Map<String, String?>? serverErrors; // NEW: server-side field errors
  final Map<String, dynamic>?
  initialFormData; // NEW: prefill after server error

  const AddEditParentModal({
    super.key,
    this.parent,
    this.serverErrors,
    this.initialFormData,
  });

  @override
  State<AddEditParentModal> createState() => _AddEditParentModalState();
}

class _AddEditParentModalState extends State<AddEditParentModal> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  // Form controllers
  final _fnameController = TextEditingController();
  final _mnameController = TextEditingController();
  final _lnameController = TextEditingController();
  final _suffixController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _addressController = TextEditingController();
  final _studentSearchController = TextEditingController();

  // State variables
  List<Map<String, dynamic>> _allStudents = [];
  List<Map<String, dynamic>> _filteredStudents = [];
  List<Map<String, dynamic>> _selectedStudents = [];
  bool _isLoadingStudents = false;
  String _studentSearchQuery = '';
  bool _isSubmitting = false;

  // Server-provided errors shown in modal
  Map<String, String?> _serverErrors = {};
  String? _serverGeneral;

  @override
  void initState() {
    super.initState();
    // Load server errors into local state so they are reactive in the dialog
    if (widget.serverErrors != null) {
      _serverErrors = Map<String, String?>.from(widget.serverErrors!);
      _serverGeneral = widget.serverErrors!['_general'];
    }
    _loadStudents();
    _initializeForm();
  }

  // Ensure relationship values coming from import or server are mapped
  // to the limited set used by the UI dropdown. This prevents cases
  // where imported values like 'mother'/'father' would not match the
  // available DropdownMenuItem values and trigger Flutter assertions.
  String _normalizeRelationship(dynamic value) {
    if (value == null) return 'parent';
    final s = value.toString().toLowerCase().trim();
    // Treat common family relations as 'parent'
    if (s == 'parent' || s == 'mother' || s == 'father' || s == 'mom' || s == 'dad') {
      return 'parent';
    }
    if (s == 'guardian' || s == 'caregiver') {
      return 'guardian';
    }
    // Fallback to 'parent' to keep UI consistent
    return 'parent';
  }

  void _initializeForm() {
    // If parent provided (editing) use that
    if (widget.parent != null) {
      _fnameController.text = widget.parent!['first_name'] ?? '';
      _mnameController.text = widget.parent!['middle_name'] ?? '';
      _lnameController.text = widget.parent!['last_name'] ?? '';
      _suffixController.text = widget.parent!['suffix'] ?? '';
      _emailController.text = widget.parent!['email'] ?? '';
      _phoneController.text = widget.parent!['phone'] ?? '';
      _addressController.text = widget.parent!['address'] ?? '';

      final students = widget.parent!['students'] as List? ?? [];
      _selectedStudents = students.map((student) {
        return {
          'student_id': student['id'],
          'relationship_type': _normalizeRelationship(student['relationship_type']),
          'is_primary': student['is_primary'] ?? false,
          'student_data': {
            'id': student['id'],
            'fname': student['first_name'],
            'mname': student['middle_name'],
            'lname': student['last_name'],
            'grade_level': student['grade'],
            'section_id': student['section'],
            'status': 'active',
          },
        };
      }).toList();
      return;
    }

    // If initialFormData provided (re-open after server error), prefill fields
    if (widget.initialFormData != null) {
      final data = widget.initialFormData!;
      _fnameController.text = data['fname']?.toString() ?? '';
      _mnameController.text = data['mname']?.toString() ?? '';
      _lnameController.text = data['lname']?.toString() ?? '';
      _suffixController.text = data['suffix']?.toString() ?? '';
      _emailController.text = data['email']?.toString() ?? '';
      _phoneController.text = data['phone']?.toString() ?? '';
      _addressController.text = data['address']?.toString() ?? '';

      // studentsToLink expected to be list of maps similar to selection format
      final studentsList = data['studentsToLink'] as List? ?? [];
      _selectedStudents = studentsList.map((s) {
        // keep student_data if provided, otherwise minimal
        return {
          'student_id': s['student_id'],
          'relationship_type': _normalizeRelationship(s['relationship_type']),
          'is_primary': s['is_primary'] ?? false,
          'student_data': s['student_data'] ?? {'id': s['student_id']},
        };
      }).toList();
    }
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
    final response = await supabase
      .from('students')
      .select('id, fname, mname, lname, grade_level, section_id, sections(name), status')
      .eq('status', 'active')
      .order('fname');

      setState(() {
        _allStudents = response;
        _filteredStudents = response;
        _isLoadingStudents = false;
      });
    } catch (error) {
      setState(() => _isLoadingStudents = false);
      print('Error loading students: $error');
    }
  }

  void _filterStudents(String query) {
    setState(() {
      _studentSearchQuery = query;
      if (query.isEmpty) {
        _filteredStudents = _allStudents;
      } else {
        _filteredStudents =
            _allStudents.where((student) {
              final fullName =
                  "${student['fname']} ${student['mname'] ?? ''} ${student['lname']}"
                      .toLowerCase();
              final grade = "grade ${student['grade_level']}".toLowerCase();
              return fullName.contains(query.toLowerCase()) ||
                  grade.contains(query.toLowerCase());
            }).toList();
      }
    });
  }

  void _addStudentToSelection(Map<String, dynamic> student) {
    final isAlreadySelected = _selectedStudents.any(
      (selected) => selected['student_id'] == student['id'],
    );

    if (!isAlreadySelected) {
      setState(() {
        _selectedStudents.add({
          'student_id': student['id'],
          'relationship_type': 'parent',
          'is_primary': _selectedStudents.isEmpty,
          'student_data': student,
        });
      });
    }
  }

  void _removeStudentFromSelection(int index) {
    setState(() {
      final wasRemovingPrimary = _selectedStudents[index]['is_primary'] == true;
      _selectedStudents.removeAt(index);

      // If we removed the primary and there are still students, make the first one primary
      if (wasRemovingPrimary && _selectedStudents.isNotEmpty) {
        _selectedStudents[0]['is_primary'] = true;
      }
    });
  }

  void _updateRelationshipType(int index, String relationshipType) {
    setState(() {
      _selectedStudents[index]['relationship_type'] = relationshipType;
    });
  }

  void _updatePrimaryStatus(int index, bool isPrimary) {
    setState(() {
      // If setting as primary, remove primary from others
      if (isPrimary) {
        for (int i = 0; i < _selectedStudents.length; i++) {
          _selectedStudents[i]['is_primary'] = (i == index);
        }
      } else {
        _selectedStudents[index]['is_primary'] = false;
      }
    });
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final result = {
      'fname': _fnameController.text.trim(),
      'mname':
          _mnameController.text.trim().isEmpty
              ? null
              : _mnameController.text.trim(),
      'lname': _lnameController.text.trim(),
      'suffix':
          _suffixController.text.trim().isEmpty
              ? null
              : _suffixController.text.trim(),
      'email': _emailController.text.trim(),
      'phone': _phoneController.text.trim(),
      'address':
          _addressController.text.trim().isEmpty
              ? null
              : _addressController.text.trim(),
      'studentsToLink': _selectedStudents,
    };

    Navigator.of(context).pop(result);
  }

  // Helper function for string dropdown items
  List<DropdownMenuItem<String>> _buildStringDropdownItems({
    required List<String> items,
    required String emptyMessage,
  }) {
    if (items.isEmpty) {
      return [
        DropdownMenuItem<String>(
          value: null,
          enabled: false,
          child: Text(
            emptyMessage,
            style: TextStyle(
              color: Colors.grey[600],
              fontStyle: FontStyle.italic,
            ),
          ),
        ),
      ];
    }

    return items.map((item) {
      return DropdownMenuItem<String>(
        value: item,
        child: Text(
          item.toUpperCase(),
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.parent != null;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 20,
      shadowColor: Colors.black.withOpacity(0.2),
      child: Container(
        width: 1300,
        height: 700,
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  width: 4,
                  height: 24,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2ECC71),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  isEditing
                      ? 'Edit Parent/Guardian'
                      : 'Add New Parent/Guardian',
                  style: const TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(
                      Icons.close,
                      color: Color(0xFF666666),
                      size: 20,
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    padding: const EdgeInsets.all(8),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              isEditing
                  ? 'Update parent information and student assignments'
                  : 'Fill in the parent information and assign students',
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 24),

            // If server general error exists show it here
            if (_serverGeneral != null && _serverGeneral!.isNotEmpty) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  border: Border.all(color: Colors.red[100]!),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.error, color: Colors.red, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _serverGeneral!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Form content
            Expanded(
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Left side - Parent Information
                      Expanded(
                        flex: 2,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.person,
                                        color: Color(0xFF2ECC71),
                                        size: 22,
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'Parent Information',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A1A1A),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Name fields row
                                  Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Expanded(
                                        flex: 3,
                                        child: _buildTextField(
                                          controller: _fnameController,
                                          label: 'First Name *',
                                          fieldKey: 'fname', // NEW
                                          validator:
                                              (val) =>
                                                  val?.trim().isEmpty == true
                                                      ? 'First name is required'
                                                      : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 2,
                                        child: _buildTextField(
                                          controller: _mnameController,
                                          label: 'Middle Name',
                                          fieldKey: 'mname', // NEW
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 3,
                                        child: _buildTextField(
                                          controller: _lnameController,
                                          label: 'Last Name *',
                                          fieldKey: 'lname', // NEW
                                          validator:
                                              (val) =>
                                                  val?.trim().isEmpty == true
                                                      ? 'Last name is required'
                                                      : null,
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        flex: 1,
                                        child: _buildTextField(
                                          controller: _suffixController,
                                          label: 'Suffix',
                                          fieldKey: 'suffix', // NEW
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Contact fields
                                  _buildTextField(
                                    controller: _emailController,
                                    label: 'Email Address *',
                                    fieldKey: 'email', // NEW
                                    validator: (val) {
                                      if (val?.trim().isEmpty == true)
                                        return 'Required';
                                      if (!RegExp(
                                        r'^[^@]+@[^@]+\.[^@]+$',
                                      ).hasMatch(val!)) {
                                        return 'Invalid email format';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  _buildTextField(
                                    controller: _phoneController,
                                    label: 'Phone Number *',
                                    fieldKey: 'phone', // NEW: server error key
                                    keyboardType: TextInputType.number,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    maxLength: 11,
                                    validator: (val) {
                                      if (val == null || val.trim().isEmpty) {
                                        return 'Required';
                                      }
                                      final digits = val.trim();
                                      if (!RegExp(r'^\d+$').hasMatch(digits)) {
                                        return 'Only numbers allowed';
                                      }
                                      if (digits.length != 11) {
                                        return 'Phone number must be 11 digits';
                                      }
                                      if (!digits.startsWith('09')) {
                                        return 'Phone number must start with 09';
                                      }
                                      return null;
                                    },
                                  ),
                                  const SizedBox(height: 16),

                                  _buildTextField(
                                    controller: _addressController,
                                    label: 'Address',
                                    fieldKey: 'address', // NEW
                                    maxLines: 2,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(width: 24),

                      // Right side - Student Assignment
                      Expanded(
                        flex: 3,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[50],
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: Colors.grey[200]!,
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      const Icon(
                                        Icons.people,
                                        color: Color(0xFF2ECC71),
                                        size: 22,
                                      ),
                                      const SizedBox(width: 10),
                                      const Text(
                                        'Student Assignment',
                                        style: TextStyle(
                                          fontSize: 18,
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
                                          borderRadius: BorderRadius.circular(
                                            16,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFF2ECC71),
                                            width: 2,
                                          ),
                                        ),
                                        child: Text(
                                          '${_selectedStudents.length} Selected',
                                          style: const TextStyle(
                                            fontSize: 14,
                                            color: Color(0xFF2ECC71),
                                            fontWeight: FontWeight.w700,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 16),

                                  // Search bar with dropdown-style results
                                  Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      // Search input
                                      Container(
                                        decoration: BoxDecoration(
                                          border: Border.all(
                                            color: const Color(0xFFE0E0E0),
                                            width: 2,
                                          ),
                                          borderRadius: BorderRadius.circular(
                                            10,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.06,
                                              ),
                                              blurRadius: 8,
                                              offset: const Offset(0, 3),
                                            ),
                                          ],
                                        ),
                                        child: TextField(
                                          controller: _studentSearchController,
                                          decoration: InputDecoration(
                                            hintText:
                                                'Search and select students...',
                                            hintStyle: TextStyle(
                                              fontSize: 16,
                                              color: Colors.grey[500],
                                            ),
                                            prefixIcon: const Icon(
                                              Icons.search,
                                              color: Color(0xFF2ECC71),
                                              size: 22,
                                            ),
                                            suffixIcon:
                                                _studentSearchQuery.isNotEmpty
                                                    ? IconButton(
                                                      icon: const Icon(
                                                        Icons.clear,
                                                        color: Color(
                                                          0xFF9E9E9E,
                                                        ),
                                                        size: 20,
                                                      ),
                                                      onPressed: () {
                                                        _studentSearchController
                                                            .clear();
                                                        _filterStudents('');
                                                      },
                                                    )
                                                    : null,
                                            border: InputBorder.none,
                                            contentPadding:
                                                const EdgeInsets.symmetric(
                                                  vertical: 14,
                                                  horizontal: 16,
                                                ),
                                          ),
                                          onChanged: _filterStudents,
                                          style: const TextStyle(
                                            fontSize: 16,
                                            color: Color(0xFF1A1A1A),
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ),

                                      // Search results dropdown
                                      if (_studentSearchQuery.isNotEmpty &&
                                          !_isLoadingStudents)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE0E0E0),
                                              width: 2,
                                            ),
                                            boxShadow: [
                                              BoxShadow(
                                                color: Colors.black.withOpacity(
                                                  0.1,
                                                ),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ],
                                          ),
                                          constraints: const BoxConstraints(
                                            maxHeight: 200,
                                          ),
                                          child:
                                              _filteredStudents.isEmpty
                                                  ? Container(
                                                    padding:
                                                        const EdgeInsets.all(
                                                          16,
                                                        ),
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.search_off,
                                                          color:
                                                              Colors.grey[400],
                                                          size: 20,
                                                        ),
                                                        const SizedBox(
                                                          width: 8,
                                                        ),
                                                        Text(
                                                          'No students match your search',
                                                          style: TextStyle(
                                                            color:
                                                                Colors
                                                                    .grey[600],
                                                            fontSize: 15,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  )
                                                  : ListView.builder(
                                                    shrinkWrap: true,
                                                    itemCount:
                                                        _filteredStudents
                                                            .length,
                                                    itemBuilder: (
                                                      context,
                                                      index,
                                                    ) {
                                                      final student =
                                                          _filteredStudents[index];
                                                      final isSelected =
                                                          _selectedStudents.any(
                                                            (selected) =>
                                                                selected['student_id'] ==
                                                                student['id'],
                                                          );

                                                      return Material(
                                                        color:
                                                            Colors.transparent,
                                                        child: InkWell(
                                                          onTap:
                                                              isSelected
                                                                  ? null
                                                                  : () {
                                                                    _addStudentToSelection(
                                                                      student,
                                                                    );
                                                                    _studentSearchController
                                                                        .clear();
                                                                    _filterStudents(
                                                                      '',
                                                                    );
                                                                  },
                                                          child: Container(
                                                            padding:
                                                                const EdgeInsets.symmetric(
                                                                  horizontal:
                                                                      16,
                                                                  vertical: 12,
                                                                ),
                                                            decoration: BoxDecoration(
                                                              color:
                                                                  isSelected
                                                                      ? const Color(
                                                                        0xFF2ECC71,
                                                                      ).withOpacity(
                                                                        0.1,
                                                                      )
                                                                      : Colors
                                                                          .transparent,
                                                            ),
                                                            child: Row(
                                                              children: [
                                                                CircleAvatar(
                                                                  backgroundColor:
                                                                      isSelected
                                                                          ? const Color(
                                                                            0xFF2ECC71,
                                                                          )
                                                                          : Colors
                                                                              .grey[300],
                                                                  radius: 16,
                                                                  child: Text(
                                                                    student['fname'][0]
                                                                        .toUpperCase(),
                                                                    style: TextStyle(
                                                                      color:
                                                                          isSelected
                                                                              ? Colors.white
                                                                              : Colors.grey[600],
                                                                      fontSize:
                                                                          13,
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .bold,
                                                                    ),
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  width: 12,
                                                                ),
                                                                Expanded(
                                                                  child: Column(
                                                                    crossAxisAlignment:
                                                                        CrossAxisAlignment
                                                                            .start,
                                                                    children: [
                                                                      Text(
                                                                        "${student['fname']} ${student['lname']}",
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              15,
                                                                          fontWeight:
                                                                              FontWeight.w600,
                                                                          color:
                                                                              isSelected
                                                                                  ? const Color(
                                                                                    0xFF2ECC71,
                                                                                  )
                                                                                  : const Color(
                                                                                    0xFF1A1A1A,
                                                                                  ),
                                                                        ),
                                                                      ),
                                                                      Text(
                                                                        "${student['grade_level']} - Section ${student['section']?['name'] ?? student['section_id']}",
                                                                        style: TextStyle(
                                                                          fontSize:
                                                                              13,
                                                                          color:
                                                                              Colors.grey[600],
                                                                          fontWeight:
                                                                              FontWeight.w500,
                                                                        ),
                                                                      ),
                                                                    ],
                                                                  ),
                                                                ),
                                                                if (isSelected)
                                                                  const Icon(
                                                                    Icons
                                                                        .check_circle,
                                                                    color: Color(
                                                                      0xFF2ECC71,
                                                                    ),
                                                                    size: 20,
                                                                  )
                                                                else
                                                                  Icon(
                                                                    Icons
                                                                        .add_circle_outline,
                                                                    color:
                                                                        Colors
                                                                            .grey[400],
                                                                    size: 20,
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                                        ),
                                                      );
                                                    },
                                                  ),
                                        ),

                                      // Loading indicator for search
                                      if (_studentSearchQuery.isNotEmpty &&
                                          _isLoadingStudents)
                                        Container(
                                          margin: const EdgeInsets.only(top: 4),
                                          padding: const EdgeInsets.all(16),
                                          decoration: BoxDecoration(
                                            color: Colors.white,
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                            border: Border.all(
                                              color: const Color(0xFFE0E0E0),
                                              width: 2,
                                            ),
                                          ),
                                          child: const Row(
                                            children: [
                                              SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Color(0xFF2ECC71),
                                                      strokeWidth: 2,
                                                    ),
                                              ),
                                              SizedBox(width: 12),
                                              Text(
                                                'Searching students...',
                                                style: TextStyle(
                                                  color: Color(0xFF666666),
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

                            const SizedBox(height: 16),

                            // Selected students section - REDESIGNED FOR BETTER SPACE MANAGEMENT
                            Container(
                              height: 300, // Fixed height to prevent overflow
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF2ECC71,
                                ).withOpacity(0.05),
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: const Color(
                                    0xFF2ECC71,
                                  ).withOpacity(0.2),
                                  width: 2,
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.06),
                                    blurRadius: 8,
                                    offset: const Offset(0, 3),
                                  ),
                                ],
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.assignment_ind,
                                        color: Color(0xFF2ECC71),
                                        size: 22,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Selected Students & Relationships',
                                        style: TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A1A1A),
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 12),

                                  // Selected students list
                                  Expanded(
                                    child:
                                        _selectedStudents.isEmpty
                                            ? Center(
                                              child: Column(
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Icon(
                                                    Icons.people_outline,
                                                    size: 48,
                                                    color: Colors.grey[400],
                                                  ),
                                                  const SizedBox(height: 12),
                                                  Text(
                                                    'No students selected',
                                                    style: TextStyle(
                                                      color: Colors.grey[600],
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Search and select students above',
                                                    style: TextStyle(
                                                      color: Colors.grey[500],
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            )
                                            : ListView.builder(
                                              itemCount:
                                                  _selectedStudents.length,
                                              itemBuilder: (context, index) {
                                                final selectedStudent =
                                                    _selectedStudents[index];
                                                final student =
                                                    selectedStudent['student_data'];

                                                return Container(
                                                  margin: const EdgeInsets.only(
                                                    bottom: 8,
                                                  ),
                                                  padding: const EdgeInsets.all(
                                                    12,
                                                  ),
                                                  decoration: BoxDecoration(
                                                    color: Colors.white,
                                                    borderRadius:
                                                        BorderRadius.circular(
                                                          10,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.grey[300]!,
                                                      width: 2,
                                                    ),
                                                    boxShadow: [
                                                      BoxShadow(
                                                        color: Colors.black
                                                            .withOpacity(0.06),
                                                        blurRadius: 8,
                                                        offset: const Offset(
                                                          0,
                                                          3,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                  child: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      // Student info row
                                                      Row(
                                                        children: [
                                                          CircleAvatar(
                                                            backgroundColor:
                                                                const Color(
                                                                  0xFF2ECC71,
                                                                ),
                                                            radius: 18,
                                                            child: Text(
                                                              student['fname'][0]
                                                                  .toUpperCase(),
                                                              style: const TextStyle(
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                fontSize: 14,
                                                                fontWeight:
                                                                    FontWeight
                                                                        .bold,
                                                              ),
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            width: 12,
                                                          ),
                                                          Expanded(
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  "${student['fname']} ${student['lname']}",
                                                                  style: const TextStyle(
                                                                    fontSize:
                                                                        16,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color: Color(
                                                                      0xFF1A1A1A,
                                                                    ),
                                                                    letterSpacing:
                                                                        0.3,
                                                                  ),
                                                                ),
                                                                Text(
                                                                  "${student['grade_level']} - Section ${student['section']?['name'] ?? student['section_id']}",
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    color:
                                                                        Colors
                                                                            .grey[600],
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),
                                                          // Remove button
                                                          IconButton(
                                                            onPressed:
                                                                () =>
                                                                    _removeStudentFromSelection(
                                                                      index,
                                                                    ),
                                                            icon: const Icon(
                                                              Icons.close,
                                                              color: Colors.red,
                                                              size: 20,
                                                            ),
                                                            iconSize: 20,
                                                            padding:
                                                                EdgeInsets.zero,
                                                            constraints:
                                                                const BoxConstraints(
                                                                  minWidth: 32,
                                                                  minHeight: 32,
                                                                ),
                                                          ),
                                                        ],
                                                      ),

                                                      const SizedBox(height: 8),

                                                      // Relationship and primary controls row
                                                      Row(
                                                        children: [
                                                          // Relationship dropdown
                                                          Expanded(
                                                            flex: 2,
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                Text(
                                                                  'Relationship',
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        13,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color:
                                                                        Colors
                                                                            .grey[700],
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 4,
                                                                ),
                                                                Container(
                                                                  height: 36,
                                                                  decoration: BoxDecoration(
                                                                    border: Border.all(
                                                                      color:
                                                                          Colors
                                                                              .grey[300]!,
                                                                      width: 2,
                                                                    ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          8,
                                                                        ),
                                                                  ),
                                                                  child: DropdownButtonFormField<
                                                                    String
                                                                  >(
                                                                    value:
                                                                        selectedStudent['relationship_type'],
                                                                    decoration: const InputDecoration(
                                                                      border:
                                                                          InputBorder
                                                                              .none,
                                                                      contentPadding: EdgeInsets.symmetric(
                                                                        horizontal:
                                                                            10,
                                                                        vertical:
                                                                            6,
                                                                      ),
                                                                      isDense:
                                                                          true,
                                                                    ),
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          13,
                                                                      color: Color(
                                                                        0xFF1A1A1A,
                                                                      ),
                                                                      fontWeight:
                                                                          FontWeight
                                                                              .w500,
                                                                    ),
                                                                    items:
                                                                        [
                                                                          'parent',
                                                                          'guardian',
                                                                        ].map((
                                                                          String
                                                                          value,
                                                                        ) {
                                                                          return DropdownMenuItem<
                                                                            String
                                                                          >(
                                                                            value:
                                                                                value,
                                                                            child: Text(
                                                                              value.toUpperCase(),
                                                                              style: const TextStyle(
                                                                                fontSize:
                                                                                    13,
                                                                                fontWeight:
                                                                                    FontWeight.w500,
                                                                              ),
                                                                            ),
                                                                          );
                                                                        }).toList(),
                                                                    onChanged: (
                                                                      String?
                                                                      newValue,
                                                                    ) {
                                                                      if (newValue !=
                                                                          null) {
                                                                        _updateRelationshipType(
                                                                          index,
                                                                          newValue,
                                                                        );
                                                                      }
                                                                    },
                                                                  ),
                                                                ),
                                                              ],
                                                            ),
                                                          ),

                                                          const SizedBox(
                                                            width: 12,
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
              children: [
                const Spacer(),
                OutlinedButton(
                  onPressed:
                      _isSubmitting ? null : () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFFE0E0E0), width: 2),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    elevation: 2,
                    shadowColor: Colors.black.withOpacity(0.1),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      color: Color(0xFF666666),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                    elevation: 4,
                    shadowColor: Colors.black.withOpacity(0.2),
                  ),
                  child:
                      _isSubmitting
                          ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                          : Text(
                            isEditing ? 'Update Parent' : 'Add Parent',
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? Function(String?)? validator,
    int maxLines = 1,
    String? fieldKey, // NEW: name used to show server-side field error
    TextInputType keyboardType = TextInputType.text, // NEW
    List<TextInputFormatter>? inputFormatters, // NEW
    int? maxLength, // NEW
  }) {
    final errorText = fieldKey != null ? _serverErrors[fieldKey] : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: Color(0xFF555555),
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          onChanged: (val) {
            // Clear server-side error for this field as user edits it
            if (fieldKey != null && _serverErrors[fieldKey] != null) {
              setState(() {
                _serverErrors[fieldKey] = null;
                // also clear general server error when editing fields
                _serverGeneral = null;
              });
            }
          },
          decoration: InputDecoration(
            counterText: '', // hide built-in counter if using maxLength
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 2),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0), width: 2),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFF2ECC71), width: 2),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 14,
              vertical: 14,
            ),
            filled: true,
            fillColor: Colors.white,
            prefixIcon:
                label.contains('Email')
                    ? const Icon(
                      Icons.email,
                      color: Color(0xFF2ECC71),
                      size: 20,
                    )
                    : label.contains('Phone')
                    ? const Icon(
                      Icons.phone,
                      color: Color(0xFF2ECC71),
                      size: 20,
                    )
                    : label.contains('Address')
                    ? const Icon(
                      Icons.location_on,
                      color: Color(0xFF2ECC71),
                      size: 20,
                    )
                    : const Icon(
                      Icons.person,
                      color: Color(0xFF2ECC71),
                      size: 20,
                    ),
            errorText: errorText, // show server-side field error inline
          ),
          style: const TextStyle(
            fontSize: 16,
            color: Color(0xFF1A1A1A),
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  @override
  @override
  void dispose() {
    _fnameController.dispose();
    _mnameController.dispose();
    _lnameController.dispose();
    _suffixController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }
}
