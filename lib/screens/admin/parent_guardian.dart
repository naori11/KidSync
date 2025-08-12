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
      print('Fetching parents from database...');

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

      print('Parents response: $parentsResponse');

      if (parentsResponse.isEmpty) {
        print('No parents found in database');
        setState(() {
          parents = [];
          isLoading = false;
        });
        return;
      }

      // Transform parents data and get student relationships
      final List<Map<String, dynamic>> transformedParents = [];

      for (final parentData in parentsResponse) {
        print(
          'Processing parent: ${parentData['fname']} ${parentData['lname']}',
        );

        // Get students for this parent
        final studentsResponse = await supabase
            .from('parent_student')
            .select('''
              relationship_type,
              is_primary,
              students!inner(
                id, fname, mname, lname, grade_level, section_id
              )
            ''')
            .eq('parent_id', parentData['id']);

        print('Students for parent ${parentData['id']}: $studentsResponse');

        List<Map<String, dynamic>> studentsList = [];

        if (studentsResponse.isNotEmpty) {
          for (final studentRelation in studentsResponse) {
            final student = studentRelation['students'];
            if (student != null) {
              studentsList.add({
                'id': student['id'],
                'first_name': student['fname'],
                'middle_name': student['mname'],
                'last_name': student['lname'],
                'grade': student['grade_level'],
                'section': student['section_id'],
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

      print('Transformed parents: ${transformedParents.length}');

      setState(() {
        parents = transformedParents;
        isLoading = false;
      });
    } catch (error) {
      print('Error fetching parents: $error');
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

  void _showAddParentModal() {
    setState(() {
      _editingParent = null;
      _showAddEditModal = true;
    });
  }

  void _showEditParentModal(Map<String, dynamic> parent) {
    setState(() {
      _editingParent = parent;
      _showAddEditModal = true;
    });
  }

  void _closeAddEditModal() {
    setState(() {
      _showAddEditModal = false;
      _editingParent = null;
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
      print('Starting parent creation with validation...');

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

      print('Basic validation passed');

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

      print('Email availability check passed');

      // 1.5 Check if email already exists in parents table
      final existingParent =
          await supabase
              .from('parents')
              .select('id, email, status')
              .eq('email', email.trim())
              .eq('status', 'active')
              .maybeSingle();

      if (existingParent != null) {
        throw Exception('Email "$email" is already used by another parent');
      }

      print('Parent email check passed');

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

      print('User phone check passed');

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

      print('Parent phone check passed');

      // 1.8 Validate student links if any
      for (int i = 0; i < studentsToLink.length; i++) {
        final studentLink = studentsToLink[i];
        final studentId = studentLink['student_id'];

        if (studentId == null) {
          throw Exception('Invalid student selection at position ${i + 1}');
        }

        // Check if student exists and is active
        final studentExists =
            await supabase
                .from('students')
                .select('id, fname, lname, status')
                .eq('id', studentId)
                .eq('status', 'active')
                .maybeSingle();

        if (studentExists == null) {
          throw Exception(
            'Selected student at position ${i + 1} is not available',
          );
        }
      }

      print('Student validation passed');

      // STEP 2: ALL VALIDATIONS PASSED - NOW CREATE USER ACCOUNT
      print('All validations passed, creating user account...');

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

      print('User created successfully with ID: $userId');

      // STEP 3: INSERT TO PARENTS TABLE
      print('Creating parent record...');

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

        final parentId = parentInsert['id'];
        print('Parent created successfully with ID: $parentId');

        // STEP 4: LINK STUDENTS
        print('Linking ${studentsToLink.length} students...');
        for (final studentLink in studentsToLink) {
          await supabase.from('parent_student').insert({
            'parent_id': parentId,
            'student_id': studentLink['student_id'],
            'relationship_type': studentLink['relationship_type'] ?? 'parent',
            'is_primary': studentLink['is_primary'] ?? false,
          });
        }

        print('Parent creation process completed successfully');
        _showSuccessSnackBar('Parent added successfully');
        _fetchParents();
      } catch (parentError) {
        // If parent creation fails, clean up the created user account
        print('Parent creation failed, cleaning up user account...');
        try {
          await supabase.functions.invoke('delete_user', body: {'id': userId});
          print('User account cleaned up successfully');
        } catch (cleanupError) {
          print('Failed to cleanup user account: $cleanupError');
        }

        // Re-throw the original parent creation error
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
      print('Starting parent edit synchronization...');

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

  // New: Direct parent-only edit function (for cases where you only want to update parent table)
  Future<void> _editParentOnly({
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
      print('Updating parent table only...');

      // Update only the parents table
      await supabase
          .from('parents')
          .update({
            'fname': fname,
            'mname': mname,
            'lname': lname,
            'phone': phone,
            'email': email,
            'address': address,
          })
          .eq('id', parentId);

      // Update student relationships
      await supabase.from('parent_student').delete().eq('parent_id', parentId);
      for (final studentLink in studentsToLink) {
        await supabase.from('parent_student').insert({
          'parent_id': parentId,
          'student_id': studentLink['student_id'],
          'relationship_type': studentLink['relationship_type'] ?? 'parent',
          'is_primary': studentLink['is_primary'] ?? false,
        });
      }

      _showSuccessSnackBar('Parent updated successfully (parent data only)');
      _fetchParents();
    } catch (error) {
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
    // Filter parents by search query
    final filteredParents =
        parents.where((parent) {
          final fullName =
              "${parent['first_name']} ${parent['last_name']}".toLowerCase();
          return fullName.contains(_searchQuery.toLowerCase());
        }).toList();

    return Scaffold(
      backgroundColor: const Color(0xFFF5F8F5),
      body: Stack(
        children: [
          // Main Content
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Search and Add button row
                Row(
                  children: [
                    // Search bar
                    Expanded(
                      child: Container(
                        height: 40,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: const Color(0xFFE0E0E0)),
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
                              vertical: 10.0,
                            ),
                          ),
                          onChanged:
                              (val) => setState(() => _searchQuery = val),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Add New Parent button
                    SizedBox(
                      height: 40,
                      child: ElevatedButton.icon(
                        icon: const Icon(Icons.add, color: Colors.white),
                        label: const Text(
                          "Add New Parent",
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
                        onPressed: () async {
                          // Show Add/Edit Modal using a custom widget
                          final result = await showDialog<Map<String, dynamic>>(
                            context: context,
                            barrierDismissible: false,
                            builder:
                                (context) => AddEditParentModal(parent: null),
                          );
                          // If result is not null and has required fields, proceed to add
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
                              studentsToLink: result['studentsToLink'] ?? [],
                            );
                          }
                        },
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 24),

                if (isLoading)
                  const Center(
                    child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
                  )
                else
                  Row(
                    children: [
                      Text(
                        'Total parents: ${parents.length}, Filtered: ${filteredParents.length}',
                        style: TextStyle(color: Colors.grey[600], fontSize: 12),
                      ),
                      const Spacer(),
                      // Data source indicator
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.blue[50],
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.blue[200]!),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.sync, size: 12, color: Colors.blue[600]),
                            const SizedBox(width: 4),
                            Text(
                              'Parent profiles are synced with their user accounts',
                              style: TextStyle(
                                fontSize: 10,
                                color: Colors.blue[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),

                const SizedBox(height: 8),

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
                                  ),
                                ),
                                if (parents.isEmpty) ...[
                                  const SizedBox(height: 8),
                                  TextButton(
                                    onPressed: _showAddParentModal,
                                    child: const Text('Add your first parent'),
                                  ),
                                ],
                              ],
                            ),
                          )
                          : GridView.builder(
                            gridDelegate:
                                const SliverGridDelegateWithFixedCrossAxisCount(
                                  crossAxisCount: 3,
                                  crossAxisSpacing: 16.0,
                                  mainAxisSpacing: 16.0,
                                  childAspectRatio: 1.3,
                                ),
                            itemCount: filteredParents.length,
                            itemBuilder: (context, index) {
                              final parent = filteredParents[index];
                              final fullName =
                                  "${parent['first_name']} ${parent['last_name']}";
                              final initial =
                                  parent['first_name'][0].toUpperCase();
                              final profileImageUrl =
                                  parent['profile_image_url'];

                              return Container(
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: const Color(0xFFE0E0E0),
                                    width: 1,
                                  ),
                                ),
                                child: Padding(
                                  padding: const EdgeInsets.all(16.0),
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      // Avatar with initial or profile image
                                      CircleAvatar(
                                        radius: 24,
                                        backgroundColor: Colors.grey[300],
                                        backgroundImage:
                                            profileImageUrl != null &&
                                                    profileImageUrl
                                                        .toString()
                                                        .isNotEmpty
                                                ? NetworkImage(profileImageUrl)
                                                : null,
                                        child:
                                            profileImageUrl == null ||
                                                    profileImageUrl
                                                        .toString()
                                                        .isEmpty
                                                ? Text(
                                                  initial,
                                                  style: const TextStyle(
                                                    fontSize: 20,
                                                    fontWeight: FontWeight.bold,
                                                    color: Colors.black87,
                                                  ),
                                                )
                                                : null,
                                      ),
                                      const SizedBox(height: 12),

                                      // Name
                                      Text(
                                        fullName,
                                        style: const TextStyle(
                                          fontSize: 14,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.black87,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),

                                      // Phone
                                      Text(
                                        parent['phone'] ?? 'No phone',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),

                                      // Student count
                                      Text(
                                        "${parent['student_count']} Students",
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.grey[600],
                                        ),
                                      ),
                                      const SizedBox(height: 8),

                                      // Action buttons row
                                      Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.spaceEvenly,
                                        children: [
                                          // View Details button
                                          Expanded(
                                            child: OutlinedButton(
                                              onPressed:
                                                  () => _showParentDetails(
                                                    parent,
                                                  ),
                                              style: OutlinedButton.styleFrom(
                                                side: const BorderSide(
                                                  color: Color(0xFF2ECC71),
                                                ),
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(4),
                                                ),
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                              ),
                                              child: const Text(
                                                'View',
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Color(0xFF2ECC71),
                                                ),
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 4),
                                          // Edit button
                                          IconButton(
                                            onPressed: () async {
                                              // Show Add/Edit Modal with parent data
                                              final result = await showDialog<
                                                Map<String, dynamic>
                                              >(
                                                context: context,
                                                barrierDismissible: false,
                                                builder:
                                                    (context) =>
                                                        AddEditParentModal(
                                                          parent: parent,
                                                        ),
                                              );
                                              if (result != null &&
                                                  result['fname'] != null &&
                                                  result['lname'] != null &&
                                                  result['email'] != null &&
                                                  result['phone'] != null) {
                                                // Use the bidirectional sync method
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
                                                      result['studentsToLink'] ??
                                                      [],
                                                );
                                              }
                                            },
                                            icon: const Icon(
                                              Icons.edit,
                                              size: 16,
                                              color: Colors.blue,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                          // Delete button
                                          IconButton(
                                            onPressed:
                                                () => _deleteParent(parent),
                                            icon: const Icon(
                                              Icons.delete,
                                              size: 16,
                                              color: Colors.red,
                                            ),
                                            padding: EdgeInsets.zero,
                                            constraints: const BoxConstraints(),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                ),
              ],
            ),
          ),

          // Parent Details Modal
          if (_showDetailModal && _selectedParent != null)
            _buildParentDetailModal(),
        ],
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          child: Container(
            width: 600,
            height: 500,
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header with close button
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Parent info
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Avatar with initial or profile image
                        CircleAvatar(
                          radius: 24,
                          backgroundColor: Colors.grey[300],
                          backgroundImage:
                              profileImageUrl != null &&
                                      profileImageUrl.toString().isNotEmpty
                                  ? NetworkImage(profileImageUrl)
                                  : null,
                          child:
                              profileImageUrl == null ||
                                      profileImageUrl.toString().isEmpty
                                  ? Text(
                                    initial,
                                    style: const TextStyle(
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                      color: Colors.black87,
                                    ),
                                  )
                                  : null,
                        ),
                        const SizedBox(width: 16),

                        // Name and details
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              fullName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: Colors.black87,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Text(
                                  'Parent',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.grey[600],
                                  ),
                                ),
                                if (parent['user_id'] != null) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green[50],
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: Colors.green[200]!,
                                      ),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.sync,
                                          size: 8,
                                          color: Colors.green[600],
                                        ),
                                        const SizedBox(width: 2),
                                        Text(
                                          'Bi-sync',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.green[600],
                                            fontWeight: FontWeight.w500,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              parent['email'] ?? 'No email',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              parent['phone'] ?? 'No phone',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Close button
                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: _closeDetailModal,
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                // Associated Students Section
                const Text(
                  'Associated Students',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 16),

                // Student list
                Expanded(
                  child:
                      students.isEmpty
                          ? const Center(
                            child: Text(
                              'No students assigned',
                              style: TextStyle(color: Colors.grey),
                            ),
                          )
                          : ListView.separated(
                            itemCount: students.length,
                            separatorBuilder:
                                (context, index) => const Divider(height: 32),
                            itemBuilder: (context, index) {
                              final student = students[index];
                              final studentName =
                                  "${student['first_name']} ${student['last_name']}";
                              final studentInitial =
                                  student['first_name'][0].toUpperCase();
                              final grade = student['grade'];
                              final section = student['section'];

                              return Row(
                                children: [
                                  // Student initial
                                  CircleAvatar(
                                    radius: 18,
                                    backgroundColor: const Color(0xFFE8F5E9),
                                    child: Text(
                                      studentInitial,
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.black87,
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
                                            fontSize: 16,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.black87,
                                          ),
                                        ),
                                        const SizedBox(height: 4),
                                        Text(
                                          'Grade $grade - Section $section',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                        Text(
                                          'Relationship: ${student['relationship_type']}',
                                          style: TextStyle(
                                            fontSize: 13,
                                            color: Colors.grey[600],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
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
}
