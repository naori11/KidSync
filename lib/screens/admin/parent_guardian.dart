import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kidsync/widgets/add_edit_parent_modal.dart';

class ParentGuardianPage extends StatefulWidget {
  const ParentGuardianPage({super.key});

  @override
  State<ParentGuardianPage> createState() => _ParentGuardianPageState();
}

class _ParentGuardianPageState extends State<ParentGuardianPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> parents = [];
  bool isLoading = false;
  String _searchQuery = '';

  String _statusFilter = 'All Status';
  String _sortOption = 'Name (A-Z)';

  Map<String, dynamic>? _selectedParent;
  bool _showDetailModal = false;
  bool _showAddEditModal = false;
  Map<String, dynamic>? _editingParent;

  @override
  void initState() {
    super.initState();
    _fetchParents();
  }

  Future<void> _fetchParents() async {
    setState(() => isLoading = true);

    try {
      // Fetch all active parents with user data
      final parentsResponse = await supabase
          .from('parents')
          .select('''
            *,
            users!parents_user_id_fkey(
              id,
              fname,
              mname,
              lname,
              email,
              contact_number,
              profile_image_url,
              role,
              created_at
            )
          ''')
          .eq('status', 'active');


      if (parentsResponse.isEmpty) {
        setState(() {
          parents = [];
          isLoading = false;
        });
        return;
      }

      // Transform parents data and get student relationships
      final List<Map<String, dynamic>> transformedParents = [];

      for (final parentData in parentsResponse) {

        // Get students for this parent
        final studentsResponse = await supabase
            .from('parent_student')
            .select('''
              relationship_type,
              is_primary,
              students!inner(
                id,
                fname,
                mname,
                lname,
                grade_level,
                section_id,
                sections(
                  id,
                  name
                )
              )
            ''')
            .eq('parent_id', parentData['id']);

        List<Map<String, dynamic>> studentsList = [];

        if (studentsResponse.isNotEmpty) {
          for (final studentRelation in studentsResponse) {
            final student = studentRelation['students'];
            if (student != null) {
              final sectionName =
                  (student['sections'] != null &&
                          student['sections']['name'] != null)
                      ? student['sections']['name']
                      : (student['section_id']?.toString() ?? 'N/A');
              studentsList.add({
                'id': student['id'],
                'first_name': student['fname'],
                'middle_name': student['mname'],
                'last_name': student['lname'],
                'grade': student['grade_level'],
                'section': sectionName,
                'relationship_type': studentRelation['relationship_type'],
                'is_primary': studentRelation['is_primary'],
              });
            }
          }
        }

        // Use user data if available, otherwise fall back to parent data
        final userData = parentData['users'];

        // Create parent object with synchronized data
        final transformedParent = {
          'id': parentData['id'],
          'user_id': parentData['user_id'],
          // Prioritize user table data over parent table data for sync
          'first_name': userData?['fname'] ?? parentData['fname'],
          'middle_name': userData?['mname'] ?? parentData['mname'],
          'last_name': userData?['lname'] ?? parentData['lname'],
          'phone': userData?['contact_number'] ?? parentData['phone'],
          'email': userData?['email'] ?? parentData['email'],
          'address': parentData['address'], // This remains in parent table only
          'status': parentData['status'],
          'profile_image_url': userData?['profile_image_url'],
          'role': userData?['role'],
          'created_at': userData?['created_at'] ?? parentData['created_at'],
          'students': studentsList,
          'student_count': studentsList.length,
          // Keep original parent table data for reference
          'parent_data': {
            'fname': parentData['fname'],
            'mname': parentData['mname'],
            'lname': parentData['lname'],
            'phone': parentData['phone'],
            'email': parentData['email'],
          },
          'user_data': userData,
        };

        transformedParents.add(transformedParent);
      }


      setState(() {
        parents = transformedParents;
        isLoading = false;
      });
    } catch (error) {
      setState(() => isLoading = false);
      _showErrorSnackBar('Error fetching parents: $error');
    }
  }

  void _showParentDetails(Map<String, dynamic> parent) {
    setState(() {
      _selectedParent = parent;
      _showDetailModal = true;
    });
  }

  void _closeDetailModal() {
    setState(() {
      _showDetailModal = false;
      _selectedParent = null;
    });
  }

  // Updated: Create parent account via Edge Function, then insert to parents table and parent_student
  Future<void> _addParent({
    required String fname,
    String? mname,
    required String lname,
    required String email,
    required String phone,
    String? address,
    required List<Map<String, dynamic>> studentsToLink,
  }) async {
    try {
      // STEP 1: VALIDATE ALL DATA BEFORE CREATING USER ACCOUNT

      // 1.1 Basic validation
      if (fname.trim().isEmpty) {
        throw Exception('First name is required');
      }
      if (lname.trim().isEmpty) {
        throw Exception('Last name is required');
      }
      if (email.trim().isEmpty) {
        throw Exception('Email is required');
      }
      if (phone.trim().isEmpty) {
        throw Exception('Phone number is required');
      }

      // 1.2 Email format validation
      final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
      if (!emailRegex.hasMatch(email.trim())) {
        throw Exception('Please enter a valid email address');
      }

      // 1.3 Phone number validation (basic)
      final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]+$');
      if (!phoneRegex.hasMatch(phone.trim())) {
        throw Exception('Please enter a valid phone number');
      }

      // 1.4 Check if email already exists in users table
      final existingUser =
          await supabase
              .from('users')
              .select('id, email, role')
              .eq('email', email.trim())
              .maybeSingle();

      if (existingUser != null) {
        throw Exception('Email "$email" is already registered by another user');
      }

      // 1.5 Check if email already exists in parents table
      final existingParentsList = await supabase
          .from('parents')
          .select('id, email, status, user_id')
          .eq('email', email.trim())
          .limit(2); // fetch up to 2 rows so we can detect duplicates

      if (existingParentsList.isNotEmpty) {
        if (existingParentsList.length > 1) {
          // Duplicate data found in DB — surface a clear error and stop
          throw Exception(
            'Multiple parent records found with email "$email". Please resolve duplicate parent rows in the database before adding a new parent.',
          );
        } else {
          // Exactly one existing parent found -> treat as conflict
          final existingParentRow = existingParentsList.first;
          throw Exception(
            'Email "$email" is already registered to a parent (status: ${existingParentRow['status']}).',
          );
        }
      }

      // 1.6 Check if phone number already exists in users table
      final existingUserPhone =
          await supabase
              .from('users')
              .select('id, contact_number, role')
              .eq('contact_number', phone.trim())
              .maybeSingle();

      if (existingUserPhone != null) {
        throw Exception(
          'Phone number "$phone" is already registered by another user',
        );
      }

      // 1.7 Check if phone number already exists in parents table
      final existingParentPhone =
          await supabase
              .from('parents')
              .select('id, phone, status')
              .eq('phone', phone.trim())
              .eq('status', 'active')
              .maybeSingle();

      if (existingParentPhone != null) {
        throw Exception(
          'Phone number "$phone" is already used by another parent',
        );
      }

      // 1.8 Validate student links if any
      for (int i = 0; i < studentsToLink.length; i++) {
        final studentLink = studentsToLink[i];
        final studentId = studentLink['student_id'];
        if (studentId == null) {
          throw Exception('Invalid student selection at position ${i + 1}');
        }

        // First attempt: check if student exists AND status = 'active' (current behaviour)
        final studentExistsActive =
            await supabase
                .from('students')
                .select('id, fname, lname, status')
                .eq('id', studentId)
                .eq('status', 'active')
                .maybeSingle();

        if (studentExistsActive != null) {
          // Found an active student -> OK
          continue;
        }

        // If not found as 'active', query WITHOUT status filter to inspect actual row / status
        final studentRow =
            await supabase
                .from('students')
                .select('id, fname, lname, status')
                .eq('id', studentId)
                .maybeSingle();

        if (studentRow == null) {
          // Could be: non-existent id, RLS/permission blocking, wrong schema, or type mismatch
          throw Exception(
            'Selected student at position ${i + 1} is not available (studentId: $studentId). Row not found or permission denied.',
          );
        }

        // Inspect the status value (log exact string so we can see case / whitespace)
        final statusRaw = studentRow['status'];
        final statusStr = statusRaw == null ? '<NULL>' : statusRaw.toString();

        // Accept case-insensitive 'active'
        if (statusRaw == null || statusStr.toLowerCase() != 'active') {
          throw Exception(
            'Selected student at position ${i + 1} is not available (studentId: $studentId, status: $statusStr).',
          );
        }
      }

      // STEP 2: ALL VALIDATIONS PASSED - NOW CREATE USER ACCOUNT

      final res = await supabase.functions.invoke(
        'create_user',
        body: {
          'email': email.trim(),
          'role': 'Parent',
          'fname': fname.trim(),
          'mname': mname?.trim(),
          'lname': lname.trim(),
          'contact_number': phone.trim(),
          'position': null,
        },
      );

      final status = res.status;
      final data = res.data;

      if (status != 200) {
        final errorMsg =
            (data is Map && data['error'] != null)
                ? data['error']
                : data.toString();
        throw Exception('Failed to create user account: $errorMsg');
      }

      final userId = data['id'];
      if (userId == null) {
        throw Exception('No user ID returned from user creation');
      }

      int? parentId;
      try {
        final parentInsert =
            await supabase
                .from('parents')
                .insert({
                  'fname': fname.trim(),
                  'mname': mname?.trim(),
                  'lname': lname.trim(),
                  'phone': phone.trim(),
                  'email': email.trim(),
                  'address': address?.trim(),
                  'status': 'active',
                  'user_id': userId,
                })
                .select()
                .single();

        parentId = parentInsert['id'];

        // STEP 4: LINK STUDENTS
        for (final studentLink in studentsToLink) {
          final payload = {
            'parent_id': parentId,
            'student_id': studentLink['student_id'],
            'relationship_type': studentLink['relationship_type'] ?? 'parent',
            'is_primary': studentLink['is_primary'] ?? false,
          };
          final insertRes = await supabase
              .from('parent_student')
              .insert(payload);
          // DEBUG: log insert result
          print('DEBUG: parent_student insert result: $insertRes');
        }

        _showSuccessSnackBar('Parent added successfully');
        _fetchParents();
      } catch (parentError) {
        // Rollback: remove any parent_student rows created and delete parent record
        if (parentId != null) {
          try {
            await supabase
                .from('parent_student')
                .delete()
                .eq('parent_id', parentId);
          } catch (e) {
            print(
              'DEBUG: Failed to delete parent_student entries during rollback: $e',
            );
          }

          try {
            await supabase.from('parents').delete().eq('id', parentId);
          } catch (e) {
            print('DEBUG: Failed to delete parent record during rollback: $e');
          }
        }

        // If parent creation fails, clean up the created user account
        try {
          final cleanupRes = await supabase.functions.invoke(
            'delete_user',
            body: {'id': userId},
          );
          print(
            'DEBUG: delete_user cleanup response: status=${cleanupRes.status}, data=${cleanupRes.data}',
          );
          print('User account cleaned up successfully');
        } catch (cleanupError) {
          print('Failed to cleanup user account: $cleanupError');
        }

        // Re-throw the original parent creation error with context
        throw Exception('Failed to create parent record: $parentError');
      }
    } catch (error) {
      print('Error during parent creation: $error');
      _showErrorSnackBar('Error adding parent: $error');
    }
  }

  // Updated: Edit parent with proper synchronization - now syncs BOTH directions
  // Updated: Edit parent - now relies on database trigger for sync
  Future<void> _editParent({
    required String userId,
    required int parentId,
    required String fname,
    String? mname,
    required String lname,
    required String email,
    required String phone,
    String? address,
    required List<Map<String, dynamic>> studentsToLink,
  }) async {
    try {
      // 1. Update Auth user and users table via Edge Function
      // The database trigger will automatically sync to parents table
      final res = await supabase.functions.invoke(
        'edit_user',
        body: {
          'id': userId,
          'email': email,
          'role': 'Parent',
          'fname': fname,
          'mname': mname,
          'lname': lname,
          'contact_number': phone,
          'position': null,
        },
      );

      if (res.status != 200) {
        final errorMsg =
            (res.data is Map && res.data['error'] != null)
                ? res.data['error']
                : res.data.toString();
        throw Exception('Failed to update user account: $errorMsg');
      }

      print('User account updated successfully');

      // 2. Only update parent-specific fields that don't exist in users table
      // The trigger will handle the common fields (fname, mname, lname, phone, email)
      if (address != null) {
        await supabase
            .from('parents')
            .update({'address': address})
            .eq('id', parentId);
        print('Parent address updated successfully');
      }

      // 3. Update student relationships: delete all and re-add
      await supabase.from('parent_student').delete().eq('parent_id', parentId);
      for (final studentLink in studentsToLink) {
        await supabase.from('parent_student').insert({
          'parent_id': parentId,
          'student_id': studentLink['student_id'],
          'relationship_type': studentLink['relationship_type'] ?? 'parent',
          'is_primary': studentLink['is_primary'] ?? false,
        });
      }

      print('Student relationships updated successfully');

      _showSuccessSnackBar('Parent and user account updated successfully');
      _fetchParents();
    } catch (error) {
      print('Error during parent edit: $error');
      _showErrorSnackBar('Error updating parent: $error');
    }
  }

  // Updated: Delete parent with proper cleanup
  Future<void> _deleteParent(Map<String, dynamic> parent) async {
    final confirm = await _showConfirmDialog(
      'Delete Parent',
      'Are you sure you want to delete ${parent['first_name']} ${parent['last_name']}? This will remove their login and parent record.',
    );

    if (!confirm) return;

    try {
      // 1. Delete user from Auth and users table via edge function
      final userId = parent['user_id'];
      if (userId != null && userId.toString().isNotEmpty) {
        final res = await supabase.functions.invoke(
          'delete_user',
          body: {'id': userId},
        );
        if (res.status != 200) {
          final errorMsg =
              (res.data is Map && res.data['error'] != null)
                  ? res.data['error']
                  : res.data.toString();
          throw Exception(errorMsg);
        }
      }

      // 2. Set parent record as deleted (user_id will be set to null due to FK constraint)
      await supabase
          .from('parents')
          .update({'status': 'deleted'})
          .eq('id', parent['id']);

      _showSuccessSnackBar('Parent deleted successfully');
      _fetchParents();
    } catch (error) {
      _showErrorSnackBar('Error deleting parent: $error');
    }
  }

  Future<bool> _showConfirmDialog(String title, String content) async {
    return await showDialog<bool>(
          context: context,
          builder:
              (context) => AlertDialog(
                title: Text(title),
                content: Text(content),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(false),
                    child: const Text('Cancel'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(true),
                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                    child: const Text('Delete'),
                  ),
                ],
              ),
        ) ??
        false;
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF2ECC71),
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Filter parents by search query and status, then apply sorting
    List<Map<String, dynamic>> filteredParents =
        parents.where((parent) {
          final fullName =
              "${parent['first_name']} ${parent['last_name']}".toLowerCase();
          final matchesName = fullName.contains(_searchQuery.toLowerCase());
          final status = (parent['status']?.toString() ?? '').toLowerCase();
          final matchesStatus =
              _statusFilter == 'All Status' ||
              status == _statusFilter.toLowerCase();
          return matchesName && matchesStatus;
        }).toList();

    // Sorting
    if (_sortOption == 'Name (A-Z)') {
      filteredParents.sort(
        (a, b) => ("${a['first_name']} ${a['last_name']}")
            .toLowerCase()
            .compareTo(("${b['first_name']} ${b['last_name']}").toLowerCase()),
      );
    } else if (_sortOption == 'Name (Z-A)') {
      filteredParents.sort(
        (a, b) => ("${b['first_name']} ${b['last_name']}")
            .toLowerCase()
            .compareTo(("${a['first_name']} ${a['last_name']}").toLowerCase()),
      );
    } else if (_sortOption == 'Status') {
      filteredParents.sort(
        (a, b) => (a['status'] ?? '').toString().compareTo(
          (b['status'] ?? '').toString(),
        ),
      );
    } else if (_sortOption == 'Students Count') {
      filteredParents.sort(
        (a, b) =>
            (b['student_count'] ?? 0).compareTo((a['student_count'] ?? 0)),
      );
    }

    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body: Stack(
        // Changed from just Padding to Stack to overlay modals
        children: [
          // Main content
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Enhanced Header Container with white background
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header row with title and search/add buttons
                      Row(
                        children: [
                          const Text(
                            "Parent & Guardian Management",
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF333333),
                            ),
                          ),
                          const Spacer(),
                          // Enhanced Search bar
                          Container(
                            width: 280,
                            height: 45,
                            decoration: BoxDecoration(
                              color: Colors.grey[50],
                              border: Border.all(
                                color: const Color(0xFFE0E0E0),
                              ),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: TextField(
                              decoration: const InputDecoration(
                                hintText: 'Search parents...',
                                prefixIcon: Icon(
                                  Icons.search,
                                  color: Color(0xFF9E9E9E),
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.symmetric(
                                  vertical: 12.0,
                                ),
                              ),
                              onChanged:
                                  (val) => setState(() => _searchQuery = val),
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Enhanced Add New Parent button
                          SizedBox(
                            height: 45,
                            child: ElevatedButton.icon(
                              icon: const Icon(
                                Icons.add,
                                color: Colors.white,
                                size: 20,
                              ),
                              label: const Text(
                                "Add New Parent",
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
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                elevation: 2,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () async {
                                final result =
                                    await showDialog<Map<String, dynamic>>(
                                      context: context,
                                      barrierDismissible: false,
                                      builder:
                                          (context) =>
                                              AddEditParentModal(parent: null),
                                    );
                                // DEBUG: log dialog payload returned from modal
                                print('DEBUG: Add dialog result: $result');

                                if (result != null &&
                                    result['fname'] != null &&
                                    result['lname'] != null &&
                                    result['email'] != null &&
                                    result['phone'] != null) {
                                  await _addParent(
                                    fname: result['fname'],
                                    mname: result['mname'],
                                    lname: result['lname'],
                                    email: result['email'],
                                    phone: result['phone'],
                                    address: result['address'],
                                    studentsToLink:
                                        result['studentsToLink'] ?? [],
                                  );
                                }
                              },
                            ),
                          ),
                          const SizedBox(width: 16),
                          // Enhanced Export button
                          SizedBox(
                            height: 45,
                            child: OutlinedButton.icon(
                              icon: const Icon(
                                Icons.file_download_outlined,
                                color: Color(0xFF333333),
                                size: 20,
                              ),
                              label: const Text(
                                "Export",
                                style: TextStyle(
                                  color: Color(0xFF333333),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              style: OutlinedButton.styleFrom(
                                side: const BorderSide(
                                  color: Color(0xFFE0E0E0),
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                              ),
                              onPressed: () {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      'Export functionality coming soon...',
                                    ),
                                    backgroundColor: Colors.orange,
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),

                      // Enhanced Breadcrumb / subtitle
                      const Padding(
                        padding: EdgeInsets.only(top: 8.0, bottom: 20.0),
                        child: Text(
                          "Home / Parent & Guardian Management",
                          style: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9E9E9E),
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),

                      // Enhanced Filter row with better visibility
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Row(
                          children: [
                            // Status filter dropdown
                            Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFE0E0E0),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _statusFilter,
                                  icon: const Icon(Icons.keyboard_arrow_down),
                                  items: [
                                    const DropdownMenuItem(
                                      value: 'All Status',
                                      child: Text('All Status'),
                                    ),
                                    const DropdownMenuItem(
                                      value: 'Active',
                                      child: Text('Active'),
                                    ),
                                    const DropdownMenuItem(
                                      value: 'Inactive',
                                      child: Text('Inactive'),
                                    ),
                                  ],
                                  onChanged: (String? newValue) {
                                    if (newValue == null) return;
                                    setState(() {
                                      _statusFilter = newValue;
                                    });
                                  },
                                ),
                              ),
                            ),
                            const SizedBox(width: 16),
                            // Sort by dropdown
                            Container(
                              height: 42,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 16.0,
                              ),
                              decoration: BoxDecoration(
                                color: Colors.white,
                                border: Border.all(
                                  color: const Color(0xFFE0E0E0),
                                ),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _sortOption,
                                  icon: const Icon(Icons.keyboard_arrow_down),
                                  items: [
                                    const DropdownMenuItem(
                                      value: 'Name (A-Z)',
                                      child: Text('Sort by: Name (A-Z)'),
                                    ),
                                    const DropdownMenuItem(
                                      value: 'Name (Z-A)',
                                      child: Text('Sort by: Name (Z-A)'),
                                    ),
                                    const DropdownMenuItem(
                                      value: 'Status',
                                      child: Text('Sort by: Status'),
                                    ),
                                    const DropdownMenuItem(
                                      value: 'Students Count',
                                      child: Text('Sort by: Students Count'),
                                    ),
                                  ],
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
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Stats row - NEW ADDITION
                if (isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                    ),
                    child: Row(
                      children: [
                        // Total parents stat
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: const Color(
                                    0xFF2ECC71,
                                  ).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.people,
                                  color: Color(0xFF2ECC71),
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Total Parents',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    '${parents.length}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Filtered results stat
                        Expanded(
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: const Icon(
                                  Icons.filter_list,
                                  color: Colors.blue,
                                  size: 24,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    'Filtered Results',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey[600],
                                    ),
                                  ),
                                  Text(
                                    '${filteredParents.length}',
                                    style: const TextStyle(
                                      fontSize: 24,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF333333),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        // Data sync indicator
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.blue[50],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.blue[200]!),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.sync,
                                size: 16,
                                color: Colors.blue[600],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Synced with User Accounts',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Colors.blue[600],
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                // Parent Cards Grid
                Expanded(
                  child:
                      isLoading
                          ? const Center(
                            child: CircularProgressIndicator(
                              color: Color(0xFF2ECC71),
                            ),
                          )
                          : filteredParents.isEmpty
                          ? Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(32),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[50],
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(
                                      color: Colors.grey[200]!,
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.people_outline,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        parents.isEmpty
                                            ? "No parents found in database"
                                            : "No parents match your search",
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      if (parents.isEmpty) ...[
                                        const SizedBox(height: 16),
                                        ElevatedButton.icon(
                                          onPressed: () async {
                                            final result = await showDialog<
                                              Map<String, dynamic>
                                            >(
                                              context: context,
                                              barrierDismissible: false,
                                              builder:
                                                  (context) =>
                                                      AddEditParentModal(
                                                        parent: null,
                                                      ),
                                            );
                                            if (result != null &&
                                                result['fname'] != null &&
                                                result['lname'] != null &&
                                                result['email'] != null &&
                                                result['phone'] != null) {
                                              await _addParent(
                                                fname: result['fname'],
                                                mname: result['mname'],
                                                lname: result['lname'],
                                                email: result['email'],
                                                phone: result['phone'],
                                                address: result['address'],
                                                studentsToLink:
                                                    result['studentsToLink'] ??
                                                    [],
                                              );
                                            }
                                          },
                                          icon: const Icon(Icons.add),
                                          label: const Text('Add First Parent'),
                                          style: ElevatedButton.styleFrom(
                                            backgroundColor: const Color(
                                              0xFF2ECC71,
                                            ),
                                            foregroundColor: Colors.white,
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 24,
                                              vertical: 12,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          )
                          : LayoutBuilder(
                            builder: (context, constraints) {
                              // Calculate responsive grid parameters
                              int crossAxisCount;
                              double childAspectRatio;

                              if (constraints.maxWidth > 1400) {
                                crossAxisCount = 4;
                                childAspectRatio = 1.1;
                              } else if (constraints.maxWidth > 1000) {
                                crossAxisCount = 3;
                                childAspectRatio = 1.15;
                              } else if (constraints.maxWidth > 600) {
                                crossAxisCount = 2;
                                childAspectRatio = 1.25;
                              } else {
                                crossAxisCount = 1;
                                childAspectRatio = 1.4;
                              }

                              return GridView.builder(
                                gridDelegate:
                                    SliverGridDelegateWithFixedCrossAxisCount(
                                      crossAxisCount: crossAxisCount,
                                      crossAxisSpacing: 16.0,
                                      mainAxisSpacing: 16.0,
                                      childAspectRatio: childAspectRatio,
                                    ),
                                itemCount: filteredParents.length,
                                itemBuilder: (context, index) {
                                  final parent = filteredParents[index];
                                  return _buildParentCard(parent);
                                },
                              );
                            },
                          ),
                ),
              ],
            ),
          ),

          // Parent Detail Modal - KEEP THIS
          if (_showDetailModal && _selectedParent != null)
            _buildParentDetailModal(),
        ],
      ),
    );
  }

  Widget _buildParentCard(Map<String, dynamic> parent) {
    final fullName = "${parent['first_name']} ${parent['last_name']}";
    final initial = parent['first_name'][0].toUpperCase();
    final profileImageUrl = parent['profile_image_url'];

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Colors.white, Colors.grey[50]!],
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFF2ECC71).withOpacity(0.15),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF2ECC71).withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 8),
            spreadRadius: 0,
          ),
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background pattern
            Positioned(
              top: -20,
              right: -20,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF2ECC71).withOpacity(0.03),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with avatar and status
                  Row(
                    children: [
                      // Avatar with enhanced design
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(28),
                          gradient: LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              const Color(0xFF2ECC71).withOpacity(0.1),
                              const Color(0xFF27AE60).withOpacity(0.05),
                            ],
                          ),
                          border: Border.all(
                            color: const Color(0xFF2ECC71).withOpacity(0.3),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFF2ECC71).withOpacity(0.2),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: ClipOval(
                          child:
                              profileImageUrl != null &&
                                      profileImageUrl.toString().isNotEmpty
                                  ? Image.network(
                                    profileImageUrl,
                                    width: 56,
                                    height: 56,
                                    fit: BoxFit.cover,
                                    loadingBuilder: (
                                      context,
                                      child,
                                      loadingProgress,
                                    ) {
                                      if (loadingProgress == null) return child;
                                      return Container(
                                        width: 56,
                                        height: 56,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(
                                                0xFF2ECC71,
                                              ).withOpacity(0.1),
                                              const Color(
                                                0xFF27AE60,
                                              ).withOpacity(0.05),
                                            ],
                                          ),
                                        ),
                                        child: const Center(
                                          child: SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: Color(0xFF2ECC71),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: 56,
                                        height: 56,
                                        child: Center(
                                          child: Text(
                                            initial,
                                            style: const TextStyle(
                                              fontSize: 20,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2ECC71),
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  )
                                  : Container(
                                    width: 56,
                                    height: 56,
                                    child: Center(
                                      child: Text(
                                        initial,
                                        style: const TextStyle(
                                          fontSize: 20,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF2ECC71),
                                        ),
                                      ),
                                    ),
                                  ),
                        ),
                      ),
                      const Spacer(),
                      // Enhanced status indicators
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFF2ECC71).withOpacity(0.15),
                                  const Color(0xFF27AE60).withOpacity(0.1),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: const Color(0xFF2ECC71).withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Container(
                                  width: 6,
                                  height: 6,
                                  decoration: const BoxDecoration(
                                    color: Color(0xFF2ECC71),
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                const Text(
                                  'Active',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.w600,
                                    color: Color(0xFF1E8449),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          if (parent['user_id'] != null) ...[
                            const SizedBox(height: 4),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 3,
                              ),
                              decoration: BoxDecoration(
                                gradient: LinearGradient(
                                  colors: [Colors.blue[100]!, Colors.blue[50]!],
                                ),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.blue[300]!),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.sync,
                                    size: 8,
                                    color: Colors.blue[700],
                                  ),
                                  const SizedBox(width: 3),
                                  Text(
                                    'Synced',
                                    style: TextStyle(
                                      fontSize: 8,
                                      color: Colors.blue[700],
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Name - Enhanced visibility
                  Text(
                    fullName,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: 0.2,
                      height: 1.2,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 6),

                  // Contact info - Enhanced design
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [Colors.grey[50]!, Colors.white],
                      ),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: const Color(0xFF2ECC71).withOpacity(0.1),
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.02),
                          blurRadius: 4,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2ECC71).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.phone_rounded,
                                size: 14,
                                color: Color(0xFF2ECC71),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                parent['phone'] ?? 'No phone',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF2C3E50),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: const Color(0xFF2ECC71).withOpacity(0.1),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: const Icon(
                                Icons.email_rounded,
                                size: 14,
                                color: Color(0xFF2ECC71),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                parent['email'] ?? 'No email',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: Color(0xFF2C3E50),
                                  fontWeight: FontWeight.w500,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 6),

                  // Student count
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFF2ECC71).withOpacity(0.15),
                          const Color(0xFF27AE60).withOpacity(0.1),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: const Color(0xFF2ECC71).withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            color: const Color(0xFF2ECC71).withOpacity(0.2),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: const Icon(
                            Icons.people_rounded,
                            size: 12,
                            color: Color(0xFF1E8449),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          "${parent['student_count']} Student${parent['student_count'] == 1 ? '' : 's'}",
                          style: const TextStyle(
                            fontSize: 12,
                            color: Color(0xFF1E8449),
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Action buttons row - Enhanced design
                  Row(
                    children: [
                      // View Details button - Enhanced styling
                      Expanded(
                        flex: 3,
                        child: Container(
                          height: 40,
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF2ECC71), Color(0xFF27AE60)],
                            ),
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF2ECC71).withOpacity(0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                          child: ElevatedButton(
                            onPressed: () => _showParentDetails(parent),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.transparent,
                              shadowColor: Colors.transparent,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                            ),
                            child: const Text(
                              'View Details',
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // More actions menu - Enhanced styling
                      Container(
                        width: 40,
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: PopupMenuButton<String>(
                          icon: Icon(
                            Icons.more_vert_rounded,
                            color: Colors.grey[600],
                            size: 18,
                          ),
                          padding: EdgeInsets.zero,
                          constraints: const BoxConstraints(
                            minWidth: 40,
                            minHeight: 40,
                          ),
                          onSelected: (value) async {
                            if (value == 'edit') {
                              final result =
                                  await showDialog<Map<String, dynamic>>(
                                    context: context,
                                    barrierDismissible: false,
                                    builder:
                                        (context) =>
                                            AddEditParentModal(parent: parent),
                                  );
                              // DEBUG: log edit dialog payload
                              print('DEBUG: Edit dialog result: $result');

                              if (result != null &&
                                  result['fname'] != null &&
                                  result['lname'] != null &&
                                  result['email'] != null &&
                                  result['phone'] != null) {
                                await _editParent(
                                  userId: parent['user_id'],
                                  parentId: parent['id'],
                                  fname: result['fname'],
                                  mname: result['mname'],
                                  lname: result['lname'],
                                  email: result['email'],
                                  phone: result['phone'],
                                  address: result['address'],
                                  studentsToLink:
                                      result['studentsToLink'] ?? [],
                                );
                              }
                            } else if (value == 'delete') {
                              await _deleteParent(parent);
                            }
                          },
                          itemBuilder:
                              (context) => [
                                const PopupMenuItem(
                                  value: 'edit',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.edit,
                                        size: 14,
                                        color: Color(0xFF2ECC71),
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Edit',
                                        style: TextStyle(fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem(
                                  value: 'delete',
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.delete,
                                        size: 14,
                                        color: Colors.red,
                                      ),
                                      SizedBox(width: 6),
                                      Text(
                                        'Delete',
                                        style: TextStyle(
                                          color: Colors.red,
                                          fontSize: 12,
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
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParentDetailModal() {
    final parent = _selectedParent!;
    final students = parent['students'] as List;
    final fullName = "${parent['first_name']} ${parent['last_name']}";
    final initial = parent['first_name'][0].toUpperCase();
    final profileImageUrl = parent['profile_image_url'];

    return Container(
      color: Colors.black.withOpacity(0.5),
      child: Center(
        child: Card(
          margin: const EdgeInsets.all(32),
          color: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 20,
          shadowColor: Colors.black.withOpacity(0.2),
          child: Container(
            width: 700,
            height: 600,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with close button - UPDATED STYLING
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Parent info section
                    Expanded(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Avatar - Enhanced Size and Styling
                          Container(
                            width: 90,
                            height: 90,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(45),
                              border: Border.all(
                                color: const Color(0xFF2ECC71).withOpacity(0.4),
                                width: 4,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(
                                    0xFF2ECC71,
                                  ).withOpacity(0.2),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ClipOval(
                              child:
                                  profileImageUrl != null &&
                                          profileImageUrl.toString().isNotEmpty
                                      ? Image.network(
                                        profileImageUrl,
                                        width: 90,
                                        height: 90,
                                        fit: BoxFit.cover,
                                        loadingBuilder: (
                                          context,
                                          child,
                                          loadingProgress,
                                        ) {
                                          if (loadingProgress == null)
                                            return child;
                                          return Container(
                                            width: 90,
                                            height: 90,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  const Color(
                                                    0xFF2ECC71,
                                                  ).withOpacity(0.1),
                                                  const Color(
                                                    0xFF2ECC71,
                                                  ).withOpacity(0.05),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                            child: const Center(
                                              child: SizedBox(
                                                width: 24,
                                                height: 24,
                                                child:
                                                    CircularProgressIndicator(
                                                      color: Color(0xFF2ECC71),
                                                      strokeWidth: 3,
                                                    ),
                                              ),
                                            ),
                                          );
                                        },
                                        errorBuilder: (
                                          context,
                                          error,
                                          stackTrace,
                                        ) {
                                          return Container(
                                            width: 90,
                                            height: 90,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  const Color(
                                                    0xFF2ECC71,
                                                  ).withOpacity(0.15),
                                                  const Color(
                                                    0xFF2ECC71,
                                                  ).withOpacity(0.08),
                                                ],
                                                begin: Alignment.topLeft,
                                                end: Alignment.bottomRight,
                                              ),
                                            ),
                                            child: Center(
                                              child: Text(
                                                initial,
                                                style: const TextStyle(
                                                  fontSize: 36,
                                                  fontWeight: FontWeight.bold,
                                                  color: Color(0xFF2ECC71),
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      )
                                      : Container(
                                        width: 90,
                                        height: 90,
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            colors: [
                                              const Color(
                                                0xFF2ECC71,
                                              ).withOpacity(0.15),
                                              const Color(
                                                0xFF2ECC71,
                                              ).withOpacity(0.08),
                                            ],
                                            begin: Alignment.topLeft,
                                            end: Alignment.bottomRight,
                                          ),
                                        ),
                                        child: Center(
                                          child: Text(
                                            initial,
                                            style: const TextStyle(
                                              fontSize: 36,
                                              fontWeight: FontWeight.bold,
                                              color: Color(0xFF2ECC71),
                                            ),
                                          ),
                                        ),
                                      ),
                            ),
                          ),
                          const SizedBox(width: 20),

                          // Parent details - UPDATED LAYOUT
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Name and badges
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        fullName,
                                        style: const TextStyle(
                                          fontSize: 28,
                                          fontWeight: FontWeight.bold,
                                          color: Color(0xFF1A1A1A),
                                          letterSpacing: 0.5,
                                        ),
                                      ),
                                    ),
                                    if (parent['user_id'] != null) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: Colors.green[50],
                                          borderRadius: BorderRadius.circular(
                                            12,
                                          ),
                                          border: Border.all(
                                            color: Colors.green[200]!,
                                          ),
                                        ),
                                        child: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.sync,
                                              size: 12,
                                              color: Colors.green[600],
                                            ),
                                            const SizedBox(width: 4),
                                            Text(
                                              'Synced Account',
                                              style: TextStyle(
                                                fontSize: 11,
                                                color: Colors.green[600],
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 8),

                                // Role badge - Enhanced
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 16,
                                    vertical: 8,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2ECC71,
                                    ).withOpacity(0.12),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF2ECC71,
                                      ).withOpacity(0.3),
                                      width: 1,
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      const Icon(
                                        Icons.family_restroom,
                                        size: 20,
                                        color: Color(0xFF2ECC71),
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'Parent/Guardian',
                                        style: TextStyle(
                                          fontSize: 15,
                                          color: Color(0xFF2ECC71),
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Contact information - Enhanced spacing
                                _buildContactInfo(
                                  Icons.email,
                                  'Email',
                                  parent['email'] ?? 'No email',
                                ),
                                const SizedBox(height: 12),
                                _buildContactInfo(
                                  Icons.phone,
                                  'Phone',
                                  parent['phone'] ?? 'No phone',
                                ),
                                const SizedBox(height: 12),
                                _buildContactInfo(
                                  Icons.home,
                                  'Address',
                                  parent['address'] ?? 'No address',
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    // Close button - UPDATED STYLING
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.close, color: Color(0xFF666666)),
                        onPressed: _closeDetailModal,
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Associated Students Section - UPDATED STYLING
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
                    const Text(
                      'Associated Students',
                      style: TextStyle(
                        fontSize: 22,
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
                        color: const Color(0xFF2ECC71).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        '${students.length} Student${students.length == 1 ? '' : 's'}',
                        style: const TextStyle(
                          fontSize: 15,
                          color: Color(0xFF2ECC71),
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Student list - UPDATED STYLING
                Expanded(
                  child:
                      students.isEmpty
                          ? Center(
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
                                    size: 48,
                                    color: Colors.grey[400],
                                  ),
                                  const SizedBox(height: 12),
                                  Text(
                                    'No students assigned',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          : ListView.separated(
                            itemCount: students.length,
                            separatorBuilder:
                                (context, index) => const Divider(height: 1),
                            itemBuilder: (context, index) {
                              final student = students[index];
                              final studentName =
                                  "${student['first_name']} ${student['last_name']}";
                              final studentInitial =
                                  student['first_name'][0].toUpperCase();
                              final grade = student['grade'];
                              final section = student['section'];

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: Colors.grey[200]!),
                                ),
                                margin: const EdgeInsets.only(bottom: 8),
                                child: Row(
                                  children: [
                                    // Student avatar - Enhanced
                                    Container(
                                      width: 56,
                                      height: 56,
                                      decoration: BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            const Color(
                                              0xFF2ECC71,
                                            ).withOpacity(0.15),
                                            const Color(
                                              0xFF2ECC71,
                                            ).withOpacity(0.08),
                                          ],
                                          begin: Alignment.topLeft,
                                          end: Alignment.bottomRight,
                                        ),
                                        borderRadius: BorderRadius.circular(28),
                                        border: Border.all(
                                          color: const Color(
                                            0xFF2ECC71,
                                          ).withOpacity(0.4),
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(
                                              0xFF2ECC71,
                                            ).withOpacity(0.15),
                                            blurRadius: 6,
                                            offset: const Offset(0, 2),
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Text(
                                          studentInitial,
                                          style: const TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Color(0xFF2ECC71),
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),

                                    // Student details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            studentName,
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
                                                Icons.school,
                                                size: 18,
                                                color: const Color(0xFF2ECC71),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                '$grade - Section $section',
                                                style: const TextStyle(
                                                  fontSize: 15,
                                                  color: Color(0xFF555555),
                                                  fontWeight: FontWeight.w500,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Relationship badge
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color:
                                            student['is_primary'] == true
                                                ? Colors.blue[50]
                                                : Colors.grey[100],
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              student['is_primary'] == true
                                                  ? Colors.blue[200]!
                                                  : Colors.grey[300]!,
                                        ),
                                      ),
                                      child: Text(
                                        student['relationship_type'] ??
                                            'guardian',
                                        style: TextStyle(
                                          fontSize: 13,
                                          color:
                                              student['is_primary'] == true
                                                  ? Colors.blue[700]
                                                  : Colors.grey[700],
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
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
      ),
    );
  }

  // Helper method for contact information display - Enhanced
  Widget _buildContactInfo(IconData icon, String label, String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: const Color(0xFF2ECC71)),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: const TextStyle(
              fontSize: 15,
              color: Color(0xFF666666),
              fontWeight: FontWeight.w600,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF1A1A1A),
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
