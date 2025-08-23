import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AddEditParentModal extends StatefulWidget {
  final Map<String, dynamic>? parent;

  const AddEditParentModal({super.key, this.parent});

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

  @override
  void initState() {
    super.initState();
    _loadStudents();
    _initializeForm();
  }

  void _initializeForm() {
    if (widget.parent != null) {
      _fnameController.text = widget.parent!['first_name'] ?? '';
      _mnameController.text = widget.parent!['middle_name'] ?? '';
      _lnameController.text = widget.parent!['last_name'] ?? '';
      _emailController.text = widget.parent!['email'] ?? '';
      _phoneController.text = widget.parent!['phone'] ?? '';
      _addressController.text = widget.parent!['address'] ?? '';

      // Initialize selected students
      final students = widget.parent!['students'] as List? ?? [];
      _selectedStudents =
          students
              .map(
                (student) => {
                  'student_id': student['id'],
                  'relationship_type': student['relationship_type'] ?? 'parent',
                  'is_primary': student['is_primary'] ?? false,
                  'student_data': {
                    'id': student['id'],
                    'fname': student['first_name'],
                    'mname': student['middle_name'],
                    'lname': student['last_name'],
                    'grade_level': student['grade'],
                    'section_id': student['section'],
                    'status': 'Active', // Assume active since it's from the parent's students
                  },
                },
              )
              .toList();
    }
  }

  Future<void> _loadStudents() async {
    setState(() => _isLoadingStudents = true);
    try {
      final response = await supabase
          .from('students')
          .select('id, fname, mname, lname, grade_level, section_id, status')
          .eq('status', 'Active')
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

  @override
  Widget build(BuildContext context) {
    final isEditing = widget.parent != null;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        width: 900,
        height: 700,
        padding: const EdgeInsets.all(32),
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
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const Spacer(),
                Container(
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Color(0xFF666666)),
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
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),

            // Form content
            Expanded(
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
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.person,
                                      color: Color(0xFF2ECC71),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Parent Information',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Name fields row
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildTextField(
                                        controller: _fnameController,
                                        label: 'First Name *',
                                        validator:
                                            (val) =>
                                                val?.trim().isEmpty == true
                                                    ? 'Required'
                                                    : null,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex:
                                          2, // Changed from flex: 1 to flex: 2
                                      child: _buildTextField(
                                        controller: _mnameController,
                                        label: 'Middle Name',
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      flex: 2,
                                      child: _buildTextField(
                                        controller: _lnameController,
                                        label: 'Last Name *',
                                        validator:
                                            (val) =>
                                                val?.trim().isEmpty == true
                                                    ? 'Required'
                                                    : null,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Contact fields
                                _buildTextField(
                                  controller: _emailController,
                                  label: 'Email Address *',
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
                                  validator:
                                      (val) =>
                                          val?.trim().isEmpty == true
                                              ? 'Required'
                                              : null,
                                ),
                                const SizedBox(height: 16),

                                _buildTextField(
                                  controller: _addressController,
                                  label: 'Address',
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
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(
                                      Icons.people,
                                      color: Color(0xFF2ECC71),
                                      size: 20,
                                    ),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Student Assignment',
                                      style: TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF333333),
                                      ),
                                    ),
                                    const Spacer(),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: const Color(
                                          0xFF2ECC71,
                                        ).withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      child: Text(
                                        '${_selectedStudents.length} Selected',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          color: Color(0xFF2ECC71),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),

                                // Search bar with dropdown-style results
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Search input
                                    Container(
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: const Color(0xFFE0E0E0),
                                        ),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: TextField(
                                        controller: _studentSearchController,
                                        decoration: InputDecoration(
                                          hintText:
                                              'Search and select students...',
                                          prefixIcon: const Icon(
                                            Icons.search,
                                            color: Color(0xFF9E9E9E),
                                          ),
                                          suffixIcon:
                                              _studentSearchQuery.isNotEmpty
                                                  ? IconButton(
                                                    icon: const Icon(
                                                      Icons.clear,
                                                      color: Color(0xFF9E9E9E),
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
                                                vertical: 12,
                                                horizontal: 16,
                                              ),
                                        ),
                                        onChanged: _filterStudents,
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
                                            8,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE0E0E0),
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
                                                  padding: const EdgeInsets.all(
                                                    16,
                                                  ),
                                                  child: Row(
                                                    children: [
                                                      Icon(
                                                        Icons.search_off,
                                                        color: Colors.grey[400],
                                                        size: 20,
                                                      ),
                                                      const SizedBox(width: 8),
                                                      Text(
                                                        'No students match your search',
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[600],
                                                          fontSize: 13,
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                )
                                                : ListView.builder(
                                                  shrinkWrap: true,
                                                  itemCount:
                                                      _filteredStudents.length,
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
                                                      color: Colors.transparent,
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
                                                                horizontal: 16,
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
                                                                radius: 14,
                                                                child: Text(
                                                                  student['fname'][0]
                                                                      .toUpperCase(),
                                                                  style: TextStyle(
                                                                    color:
                                                                        isSelected
                                                                            ? Colors.white
                                                                            : Colors.grey[600],
                                                                    fontSize:
                                                                        11,
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
                                                                            13,
                                                                        fontWeight:
                                                                            FontWeight.w500,
                                                                        color:
                                                                            isSelected
                                                                                ? const Color(
                                                                                  0xFF2ECC71,
                                                                                )
                                                                                : const Color(
                                                                                  0xFF333333,
                                                                                ),
                                                                      ),
                                                                    ),
                                                                    Text(
                                                                      "Grade ${student['grade_level']} - Section ${student['section_id']}",
                                                                      style: TextStyle(
                                                                        fontSize:
                                                                            11,
                                                                        color:
                                                                            Colors.grey[600],
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
                                                                  size: 18,
                                                                )
                                                              else
                                                                Icon(
                                                                  Icons
                                                                      .add_circle_outline,
                                                                  color:
                                                                      Colors
                                                                          .grey[400],
                                                                  size: 18,
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
                                            8,
                                          ),
                                          border: Border.all(
                                            color: const Color(0xFFE0E0E0),
                                          ),
                                        ),
                                        child: const Row(
                                          children: [
                                            SizedBox(
                                              width: 16,
                                              height: 16,
                                              child: CircularProgressIndicator(
                                                color: Color(0xFF2ECC71),
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            SizedBox(width: 12),
                                            Text(
                                              'Searching students...',
                                              style: TextStyle(
                                                color: Color(0xFF666666),
                                                fontSize: 13,
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
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: const Color(
                                  0xFF2ECC71,
                                ).withOpacity(0.05),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                  color: const Color(
                                    0xFF2ECC71,
                                  ).withOpacity(0.2),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Row(
                                    children: [
                                      Icon(
                                        Icons.assignment_ind,
                                        color: Color(0xFF2ECC71),
                                        size: 20,
                                      ),
                                      SizedBox(width: 8),
                                      Text(
                                        'Selected Students & Relationships',
                                        style: TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF333333),
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
                                                      fontSize: 14,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                    ),
                                                  ),
                                                  const SizedBox(height: 4),
                                                  Text(
                                                    'Search and select students above',
                                                    style: TextStyle(
                                                      color: Colors.grey[500],
                                                      fontSize: 12,
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
                                                          8,
                                                        ),
                                                    border: Border.all(
                                                      color: Colors.grey[300]!,
                                                    ),
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
                                                            radius: 16,
                                                            child: Text(
                                                              student['fname'][0]
                                                                  .toUpperCase(),
                                                              style: const TextStyle(
                                                                color:
                                                                    Colors
                                                                        .white,
                                                                fontSize: 12,
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
                                                                        14,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w600,
                                                                    color: Color(
                                                                      0xFF333333,
                                                                    ),
                                                                  ),
                                                                ),
                                                                Text(
                                                                  "Grade ${student['grade_level']} - Section ${student['section_id']}",
                                                                  style: TextStyle(
                                                                    fontSize:
                                                                        11,
                                                                    color:
                                                                        Colors
                                                                            .grey[600],
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
                                                            ),
                                                            iconSize: 18,
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
                                                                        11,
                                                                    fontWeight:
                                                                        FontWeight
                                                                            .w500,
                                                                    color:
                                                                        Colors
                                                                            .grey[700],
                                                                  ),
                                                                ),
                                                                const SizedBox(
                                                                  height: 4,
                                                                ),
                                                                Container(
                                                                  height: 32,
                                                                  decoration: BoxDecoration(
                                                                    border: Border.all(
                                                                      color:
                                                                          Colors
                                                                              .grey[300]!,
                                                                    ),
                                                                    borderRadius:
                                                                        BorderRadius.circular(
                                                                          6,
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
                                                                            8,
                                                                        vertical:
                                                                            4,
                                                                      ),
                                                                      isDense:
                                                                          true,
                                                                    ),
                                                                    style: const TextStyle(
                                                                      fontSize:
                                                                          11,
                                                                      color: Color(
                                                                        0xFF333333,
                                                                      ),
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
                          ),
                        ],
                      ),
                    ),
                  ],
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
                    side: const BorderSide(color: Color(0xFFE0E0E0)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(color: Color(0xFF666666)),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
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
                          : Text(isEditing ? 'Update Parent' : 'Add Parent'),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            color: Color(0xFF333333),
          ),
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          validator: validator,
          maxLines: maxLines,
          decoration: InputDecoration(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: const BorderSide(color: Color(0xFF2ECC71)),
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
            filled: true,
            fillColor: Colors.white,
          ),
          style: const TextStyle(fontSize: 14),
        ),
      ],
    );
  }

  @override
  void dispose() {
    _fnameController.dispose();
    _mnameController.dispose();
    _lnameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _addressController.dispose();
    _studentSearchController.dispose();
    super.dispose();
  }
}
