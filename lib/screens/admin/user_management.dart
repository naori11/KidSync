import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kidsync/widgets/role_protection.dart';
import 'package:intl/intl.dart';

class UserManagementPageAdmin extends StatelessWidget {
  const UserManagementPageAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleProtected(
      requiredRole: 'Admin',
      child: const UserManagementPage(),
    );
  }
}

class UserManagementPage extends StatefulWidget {
  const UserManagementPage({super.key});

  @override
  State<UserManagementPage> createState() => _UserManagementPageState();
}

class _UserManagementPageState extends State<UserManagementPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> users = [];
  bool isLoading = false;
  String _searchQuery = '';
  String _roleFilter = 'All Roles';
  String _sortOption = 'Name (A-Z)';

  // For pagination
  int _currentPage = 1;
  int _itemsPerPage = 8;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  void _calculateTotalPages(List<Map<String, dynamic>> filteredUsers) {
    _totalPages = (filteredUsers.length / _itemsPerPage).ceil();
    if (_totalPages == 0) _totalPages = 1;
    if (_currentPage > _totalPages) _currentPage = _totalPages;
  }

  Future<void> _fetchUsers() async {
    setState(() => isLoading = true);
    final response = await supabase
        .from('users')
        .select()
        .neq('role', 'Admin'); // Exclude Admin
    setState(() {
      users = List<Map<String, dynamic>>.from(response);
      isLoading = false;
    });
  }

  Future<void> createUserViaEdgeFunction({
    required String email,
    required String role,
    required String fname,
    String? mname,
    required String lname,
    String? contactNumber,
    String? position,
  }) async {
    final res = await Supabase.instance.client.functions.invoke(
      'create_user',
      body: {
        'email': email,
        'role': role,
        'fname': fname,
        'mname': mname,
        'lname': lname,
        'contact_number': contactNumber,
        'position': position,
      },
    );
    if (res.status != 200) {
      final errorMsg =
          res.data is Map && res.data['error'] != null
              ? res.data['error']
              : res.data.toString();
      throw Exception(errorMsg);
    }
  }

  Future<void> editUserViaEdgeFunction({
    required String id,
    required String email,
    required String role,
    required String fname,
    String? mname,
    required String lname,
    String? contactNumber,
    String? position,
  }) async {
    final res = await Supabase.instance.client.functions.invoke(
      'edit_user',
      body: {
        'id': id,
        'email': email,
        'role': role,
        'fname': fname,
        'mname': mname,
        'lname': lname,
        'contact_number': contactNumber,
        'position': position,
      },
    );
    if (res.status != 200) {
      final errorMsg =
          res.data is Map && res.data['error'] != null
              ? res.data['error']
              : res.data.toString();
      throw Exception(errorMsg);
    }
  }

  Future<void> deleteUserViaEdgeFunction(String id) async {
    final res = await Supabase.instance.client.functions.invoke(
      'delete_user',
      body: {'id': id},
    );
    if (res.status != 200) {
      final errorMsg =
          res.data is Map && res.data['error'] != null
              ? res.data['error']
              : res.data.toString();
      throw Exception(errorMsg);
    }
  }

  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: null,
      );
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  Future<void> _addOrEditUser({Map<String, dynamic>? user}) async {
    print('Debug: User data received: $user'); // Debug print

    // Form controllers
    final fnameController = TextEditingController(text: user?['fname']?.toString() ?? '');
    final mnameController = TextEditingController(text: user?['mname']?.toString() ?? '');
    final lnameController = TextEditingController(text: user?['lname']?.toString() ?? '');
    final emailController = TextEditingController(text: user?['email']?.toString() ?? '');
    final contactController = TextEditingController(text: user?['contact_number']?.toString() ?? '');
    final positionController = TextEditingController(text: user?['position']?.toString() ?? '');

    // Form state variables - Aligned with schema
    String? selectedRole = user?['role']?.toString();
    String selectedStatus = user?['status']?.toString() ?? 'Active';

    // Form validation key
    final formKey = GlobalKey<FormState>();

    // Role options based on schema constraint
    final roleOptions = ['Parent', 'Guard', 'Driver', 'Admin'];

    print('Debug: selectedRole: $selectedRole'); // Debug print

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    user == null ? Icons.person_add : Icons.edit,
                    color: const Color(0xFF2ECC71),
                  ),
                  const SizedBox(width: 8),
                  Text(user == null ? 'Add New User' : 'Edit User'),
                ],
              ),
              content: Container(
                width: 500,
                child: Form(
                  key: formKey,
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Personal Information Section
                        _buildSectionHeader('Personal Information'),
                        const SizedBox(height: 16),
                        
                        // Name fields row
                        Row(
                          children: [
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: fnameController,
                                decoration: _buildInputDecoration(
                                  'First Name',
                                  Icons.person,
                                  isRequired: true,
                                ),
                                validator: (value) {
                                  if (value?.trim().isEmpty ?? true) {
                                    return 'First name is required';
                                  }
                                  return null;
                                },
                                textCapitalization: TextCapitalization.words,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: mnameController,
                                decoration: _buildInputDecoration(
                                  'Middle Name',
                                  Icons.person_outline,
                                ),
                                textCapitalization: TextCapitalization.words,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              flex: 2,
                              child: TextFormField(
                                controller: lnameController,
                                decoration: _buildInputDecoration(
                                  'Last Name',
                                  Icons.person,
                                  isRequired: true,
                                ),
                                validator: (value) {
                                  if (value?.trim().isEmpty ?? true) {
                                    return 'Last name is required';
                                  }
                                  return null;
                                },
                                textCapitalization: TextCapitalization.words,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Email field
                        TextFormField(
                          controller: emailController,
                          decoration: _buildInputDecoration(
                            'Email Address',
                            Icons.email,
                            isRequired: true,
                          ),
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return 'Email is required';
                            }
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value!)) {
                              return 'Please enter a valid email address';
                            }
                            return null;
                          },
                          keyboardType: TextInputType.emailAddress,
                        ),
                        const SizedBox(height: 16),

                        // Contact and Position row
                        Row(
                          children: [
                            Expanded(
                              child: TextFormField(
                                controller: contactController,
                                decoration: _buildInputDecoration(
                                  'Contact Number',
                                  Icons.phone,
                                ),
                                keyboardType: TextInputType.phone,
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(RegExp(r'[0-9+\-\(\)\s]')),
                                ],
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: positionController,
                                decoration: _buildInputDecoration(
                                  'Position/Title',
                                  Icons.work,
                                ),
                                textCapitalization: TextCapitalization.words,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // System Information Section
                        _buildSectionHeader('System Information'),
                        const SizedBox(height: 16),

                        // Role and Status row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: _buildInputDecoration(
                                  'Role',
                                  Icons.admin_panel_settings,
                                  isRequired: true,
                                ),
                                value: roleOptions.contains(selectedRole) ? selectedRole : null,
                                items: roleOptions.map((role) {
                                  IconData roleIcon;
                                  switch (role) {
                                    case 'Teacher':
                                      roleIcon = Icons.school;
                                      break;
                                    case 'Guard':
                                      roleIcon = Icons.security;
                                      break;
                                    case 'Driver':
                                      roleIcon = Icons.directions_bus;
                                      break;
                                    default:
                                      roleIcon = Icons.person;
                                  }
                                  return DropdownMenuItem(
                                    value: role,
                                    child: Row(
                                      children: [
                                        Icon(roleIcon, size: 16, color: Colors.grey[600]),
                                        const SizedBox(width: 8),
                                        Text(role),
                                      ],
                                    ),
                                  );
                                }).toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedRole = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Please select a role';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: _buildInputDecoration(
                                  'Status',
                                  Icons.info,
                                ),
                                value: selectedStatus,
                                items: const [
                                  DropdownMenuItem(
                                    value: 'Active',
                                    child: Row(
                                      children: [
                                        Icon(Icons.check_circle, color: Colors.green, size: 16),
                                        SizedBox(width: 8),
                                        Text('Active'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Inactive',
                                    child: Row(
                                      children: [
                                        Icon(Icons.cancel, color: Colors.red, size: 16),
                                        SizedBox(width: 8),
                                        Text('Inactive'),
                                      ],
                                    ),
                                  ),
                                ],
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedStatus = value!;
                                  });
                                },
                              ),
                            ),
                          ],
                        ),
                        
                        if (user == null) ...[
                          const SizedBox(height: 16),
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: Colors.blue[50],
                              border: Border.all(color: Colors.blue[200]!),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              children: [
                                Icon(Icons.info, color: Colors.blue[600], size: 16),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'A temporary password will be generated and sent to the user\'s email address.',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.blue[800],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ],
                    ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        print('Debug: Attempting to save user...'); // Debug print
                        
                        if (user == null) {
                          await createUserViaEdgeFunction(
                            email: emailController.text.trim(),
                            role: selectedRole!,
                            fname: fnameController.text.trim(),
                            mname: mnameController.text.trim().isEmpty ? null : mnameController.text.trim(),
                            lname: lnameController.text.trim(),
                            contactNumber: contactController.text.trim().isEmpty ? null : contactController.text.trim(),
                            position: positionController.text.trim().isEmpty ? null : positionController.text.trim(),
                          );
                        } else {
                          await editUserViaEdgeFunction(
                            id: user['id'].toString(),
                            email: emailController.text.trim(),
                            role: selectedRole!,
                            fname: fnameController.text.trim(),
                            mname: mnameController.text.trim().isEmpty ? null : mnameController.text.trim(),
                            lname: lnameController.text.trim(),
                            contactNumber: contactController.text.trim().isEmpty ? null : contactController.text.trim(),
                            position: positionController.text.trim().isEmpty ? null : positionController.text.trim(),
                          );
                        }

                        Navigator.pop(context);
                        await _fetchUsers();

                        // Show success message
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.check_circle, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Text(
                                    user == null
                                        ? 'User created successfully!'
                                        : 'User updated successfully!',
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF2ECC71),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        print('Debug: Error saving user: $e'); // Debug print
                        // Show error message
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.error, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text('Error: ${e.toString()}')),
                                ],
                              ),
                              backgroundColor: Colors.red,
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(user == null ? Icons.add : Icons.save, size: 16),
                      const SizedBox(width: 8),
                      Text(user == null ? 'Create User' : 'Update User'),
                    ],
                  ),
                ),
              ],
            );
          },
        );
      },
    );

    // Dispose controllers
    fnameController.dispose();
    mnameController.dispose();
    lnameController.dispose();
    emailController.dispose();
    contactController.dispose();
    positionController.dispose();
  }

  // Helper method to build section headers
  Widget _buildSectionHeader(String title) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 20,
          decoration: BoxDecoration(
            color: const Color(0xFF2ECC71),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF333333),
          ),
        ),
      ],
    );
  }

  // Helper method to build consistent input decoration
  InputDecoration _buildInputDecoration(String label, IconData icon, {bool isRequired = false}) {
    return InputDecoration(
      labelText: isRequired ? '$label *' : label,
      prefixIcon: Icon(icon, size: 20),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Color(0xFF2ECC71), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(8),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      filled: true,
      fillColor: Colors.grey[50],
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      labelStyle: TextStyle(
        color: Colors.grey[600],
        fontSize: 14,
      ),
    );
  }

  String _getUserIdPrefix(String role) {
    switch (role) {
      case 'Teacher':
        return 'T';
      case 'Parent':
        return 'P';
      case 'Driver':
        return 'D';
      case 'Guard':
        return 'G';
      default:
        return 'U';
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isAdmin = user?.userMetadata?['role'] == 'Admin';

    // Filter and sort logic
    var filteredUsers = users.where((u) {
      final name = "${u['fname'] ?? ''} ${u['lname'] ?? ''}".toLowerCase();
      final roleMatch = _roleFilter == 'All Roles' || u['role'] == _roleFilter;

      return name.contains(_searchQuery.toLowerCase()) && roleMatch;
    }).toList();

    // Apply sorting
    if (_sortOption == 'Name (A-Z)') {
      filteredUsers.sort(
        (a, b) => "${a['fname'] ?? ''} ${a['lname'] ?? ''}".compareTo(
          "${b['fname'] ?? ''} ${b['lname'] ?? ''}",
        ),
      );
    } else if (_sortOption == 'Name (Z-A)') {
      filteredUsers.sort(
        (a, b) => "${b['fname'] ?? ''} ${b['lname'] ?? ''}".compareTo(
          "${a['fname'] ?? ''} ${a['lname'] ?? ''}",
        ),
      );
    } else if (_sortOption == 'Role') {
      filteredUsers.sort(
        (a, b) => (a['role'] ?? '').compareTo(b['role'] ?? ''),
      );
    }

    // Calculate pages for pagination
    _calculateTotalPages(filteredUsers);

    // Get current page items
    final int startIndex = (_currentPage - 1) * _itemsPerPage;
    final int endIndex = startIndex + _itemsPerPage > filteredUsers.length
        ? filteredUsers.length
        : startIndex + _itemsPerPage;

    final List<Map<String, dynamic>> currentPageItems =
        filteredUsers.length > startIndex
            ? filteredUsers.sublist(startIndex, endIndex)
            : [];

    // Get unique roles for filter dropdown
    final List<String> roleOptions = ['All Roles'];
    for (var user in users) {
      final role = user['role']?.toString();
      if (role != null && !roleOptions.contains(role)) {
        roleOptions.add(role);
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header row with title and search/add user buttons
            Row(
              children: [
                const Text(
                  "User Management",
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const Spacer(),
                // Search bar
                Container(
                  width: 240,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: Icon(Icons.search, color: Color(0xFF9E9E9E)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10.0),
                    ),
                    onChanged: (val) => setState(() {
                      _searchQuery = val;
                      _currentPage = 1;
                    }),
                  ),
                ),
                const SizedBox(width: 16),
                // Add New User button
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      "Add New User",
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
                    onPressed: isAdmin ? () => _addOrEditUser() : null,
                  ),
                ),
              ],
            ),

            // Breadcrumb / subtitle
            const Padding(
              padding: EdgeInsets.only(top: 4.0, bottom: 20.0),
              child: Text(
                "Home / User Management",
                style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
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
                  // Role filter dropdown
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _roleFilter,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        items: roleOptions.map((String item) {
                          return DropdownMenuItem(
                            value: item,
                            child: Text(item),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _roleFilter = newValue!;
                            _currentPage = 1;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Sort by dropdown
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _sortOption,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        items: <String>[
                          'Name (A-Z)',
                          'Name (Z-A)',
                          'Role',
                        ].map<DropdownMenuItem<String>>((String value) {
                          return DropdownMenuItem<String>(
                            value: value,
                            child: Text("Sort by: $value"),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _sortOption = newValue!;
                          });
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 16),

            // Table content
            if (isLoading)
              const Expanded(
                child: Center(
                  child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
                ),
              )
            else if (currentPageItems.isEmpty)
              const Expanded(child: Center(child: Text("No users found.")))
            else
              Expanded(
                child: Column(
                  children: [
                    // Table
                    Expanded(
                      child: SingleChildScrollView(
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
                              0: FlexColumnWidth(0.7), // ID
                              1: FlexColumnWidth(1.4), // Name
                              2: FlexColumnWidth(0.9), // Role
                              3: FlexColumnWidth(1.8), // Email
                              4: FlexColumnWidth(1.2), // Phone
                              5: FlexColumnWidth(0.8), // Status
                              6: FlexColumnWidth(0.8), // Actions
                            },
                            defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                            children: [
                              // Table header row
                              TableRow(
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                ),
                                children: const [
                                  TableHeaderCell(text: 'User ID'),
                                  TableHeaderCell(text: 'Name'),
                                  TableHeaderCell(text: 'Role'),
                                  TableHeaderCell(text: 'Email'),
                                  TableHeaderCell(text: 'Phone'),
                                  TableHeaderCell(text: 'Status'),
                                  TableHeaderCell(text: 'Actions'),
                                ],
                              ),

                              // Table data rows
                              ...currentPageItems.map((u) {
                                final role = u['role'] ?? '';
                                final userPrefix = _getUserIdPrefix(role);
                                final int userIndex = users.indexWhere(
                                      (item) => item['id'] == u['id'],
                                    ) + 1;
                                final String userId = "$userPrefix${userIndex.toString().padLeft(3, '0')}";
                                final fullName = "${u['fname'] ?? ''} ${u['lname'] ?? ''}";
                                final status = u['status'] ?? 'Active';

                                return TableRow(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                  ),
                                  children: [
                                    // User ID
                                    TableCell(
                                      verticalAlignment: TableCellVerticalAlignment.middle,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          userId,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF555555),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Name
                                    TableCell(
                                      verticalAlignment: TableCellVerticalAlignment.middle,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          fullName,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF333333),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Role
                                    TableCell(
                                      verticalAlignment: TableCellVerticalAlignment.middle,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: _getRoleColor(role).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            role,
                                            style: TextStyle(
                                              color: _getRoleColor(role),
                                              fontWeight: FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Email
                                    TableCell(
                                      verticalAlignment: TableCellVerticalAlignment.middle,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16),
                                        child: Text(u['email'] ?? 'N/A'),
                                      ),
                                    ),

                                    // Phone/Contact
                                    TableCell(
                                      verticalAlignment: TableCellVerticalAlignment.middle,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16),
                                        child: Text(u['contact_number'] ?? 'N/A'),
                                      ),
                                    ),

                                    // Status
                                    TableCell(
                                      verticalAlignment: TableCellVerticalAlignment.middle,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: status == 'Active'
                                                ? const Color(0xFFE8F5E9)
                                                : const Color(0xFFFFEBEE),
                                            borderRadius: BorderRadius.circular(4),
                                          ),
                                          child: Text(
                                            status,
                                            style: TextStyle(
                                              color: status == 'Active'
                                                  ? const Color(0xFF2E7D32)
                                                  : const Color(0xFFC62828),
                                              fontWeight: FontWeight.w500,
                                              fontSize: 12,
                                            ),
                                            textAlign: TextAlign.center,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Actions
                                    TableCell(
                                      verticalAlignment: TableCellVerticalAlignment.middle,
                                      child: Center(
                                        child: isAdmin
                                            ? PopupMenuButton<String>(
                                                icon: const Icon(Icons.more_vert),
                                                onSelected: (value) async {
                                                  if (value == 'edit') {
                                                    _addOrEditUser(user: u);
                                                  } else if (value == 'delete') {
                                                    showDialog(
                                                      context: context,
                                                      builder: (ctx) => AlertDialog(
                                                        title: const Row(
                                                          children: [
                                                            Icon(Icons.warning, color: Colors.red),
                                                            SizedBox(width: 8),
                                                            Text('Confirm Delete'),
                                                          ],
                                                        ),
                                                        content: Text(
                                                          'Are you sure you want to delete ${u['fname']} ${u['lname']}? This action cannot be undone.',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(ctx),
                                                            child: const Text('Cancel'),
                                                          ),
                                                          ElevatedButton(
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: Colors.red,
                                                            ),
                                                            onPressed: () async {
                                                              Navigator.pop(ctx);
                                                              try {
                                                                await deleteUserViaEdgeFunction(
                                                                  u['id'].toString(),
                                                                );
                                                                await _fetchUsers();
                                                                if (mounted) {
                                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                                    const SnackBar(
                                                                      content: Row(
                                                                        children: [
                                                                          Icon(Icons.check_circle, color: Colors.white),
                                                                          SizedBox(width: 8),
                                                                          Text('User deleted successfully!'),
                                                                        ],
                                                                      ),
                                                                      backgroundColor: Color(0xFF2ECC71),
                                                                      behavior: SnackBarBehavior.floating,
                                                                    ),
                                                                  );
                                                                }
                                                              } catch (e) {
                                                                if (mounted) {
                                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                                    SnackBar(
                                                                      content: Row(
                                                                        children: [
                                                                          const Icon(Icons.error, color: Colors.white),
                                                                          const SizedBox(width: 8),
                                                                          Expanded(child: Text('Error: ${e.toString()}')),
                                                                        ],
                                                                      ),
                                                                      backgroundColor: Colors.red,
                                                                      behavior: SnackBarBehavior.floating,
                                                                    ),
                                                                  );
                                                                }
                                                              }
                                                            },
                                                            child: const Text(
                                                              'Delete',
                                                              style: TextStyle(color: Colors.white),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  } else if (value == 'reset_password') {
                                                    showDialog(
                                                      context: context,
                                                      builder: (ctx) => AlertDialog(
                                                        title: const Row(
                                                          children: [
                                                            Icon(Icons.email, color: Color(0xFF2ECC71)),
                                                            SizedBox(width: 8),
                                                            Text('Reset Password'),
                                                          ],
                                                        ),
                                                        content: Text(
                                                          'Send password reset email to ${u['email']}?',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed: () => Navigator.pop(ctx),
                                                            child: const Text('Cancel'),
                                                          ),
                                                          ElevatedButton(
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor: const Color(0xFF2ECC71),
                                                            ),
                                                            onPressed: () async {
                                                              Navigator.pop(ctx);
                                                              try {
                                                                await sendPasswordResetEmail(u['email']);
                                                                if (mounted) {
                                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                                    const SnackBar(
                                                                      content: Row(
                                                                        children: [
                                                                          Icon(Icons.check_circle, color: Colors.white),
                                                                          SizedBox(width: 8),
                                                                          Text('Password reset email sent successfully!'),
                                                                        ],
                                                                      ),
                                                                      backgroundColor: Color(0xFF2ECC71),
                                                                      behavior: SnackBarBehavior.floating,
                                                                    ),
                                                                  );
                                                                }
                                                              } catch (e) {
                                                                if (mounted) {
                                                                  ScaffoldMessenger.of(context).showSnackBar(
                                                                    SnackBar(
                                                                      content: Row(
                                                                        children: [
                                                                          const Icon(Icons.error, color: Colors.white),
                                                                          const SizedBox(width: 8),
                                                                          Expanded(child: Text('Error: ${e.toString()}')),
                                                                        ],
                                                                      ),
                                                                      backgroundColor: Colors.red,
                                                                      behavior: SnackBarBehavior.floating,
                                                                    ),
                                                                  );
                                                                }
                                                              }
                                                            },
                                                            child: const Text(
                                                              'Send Email',
                                                              style: TextStyle(color: Colors.white),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  }
                                                },
                                                itemBuilder: (context) => [
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
                                                    value: 'reset_password',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.email, size: 16),
                                                        SizedBox(width: 8),
                                                        Text('Reset Password'),
                                                      ],
                                                    ),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'delete',
                                                    child: Row(
                                                      children: [
                                                        Icon(Icons.delete, size: 16, color: Colors.red),
                                                        SizedBox(width: 8),
                                                        Text('Delete', style: TextStyle(color: Colors.red)),
                                                      ],
                                                    ),
                                                  ),
                                                ],
                                              )
                                            : const Text('-'),
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

                    // Pagination
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          // "Showing x to y of z entries"
                          Text(
                            'Showing ${currentPageItems.isEmpty ? 0 : startIndex + 1} to ${endIndex} of ${filteredUsers.length} entries',
                            style: const TextStyle(
                              color: Color(0xFF666666),
                              fontSize: 12,
                            ),
                          ),

                          // Pagination controls
                          Row(
                            children: [
                              // Previous button
                              IconButton(
                                icon: const Icon(Icons.chevron_left),
                                onPressed: _currentPage > 1
                                    ? () => setState(() => _currentPage--)
                                    : null,
                                color: _currentPage > 1
                                    ? const Color(0xFF666666)
                                    : const Color(0xFFCCCCCC),
                              ),

                              // Page numbers
                              for (int i = 1; i <= _totalPages; i++)
                                if (i == _currentPage ||
                                    i == 1 ||
                                    i == _totalPages ||
                                    (i >= _currentPage - 1 && i <= _currentPage + 1))
                                  Container(
                                    margin: const EdgeInsets.symmetric(horizontal: 4),
                                    width: 32,
                                    height: 32,
                                    decoration: BoxDecoration(
                                      color: i == _currentPage
                                          ? const Color(0xFF2ECC71)
                                          : Colors.transparent,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: TextButton(
                                      onPressed: () => setState(() => _currentPage = i),
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        foregroundColor: i == _currentPage
                                            ? Colors.white
                                            : const Color(0xFF666666),
                                      ),
                                      child: Text(
                                        i.toString(),
                                        style: const TextStyle(fontSize: 14),
                                      ),
                                    ),
                                  )
                                else if (i == _currentPage - 2 || i == _currentPage + 2)
                                  const Padding(
                                    padding: EdgeInsets.symmetric(horizontal: 4),
                                    child: Text('...'),
                                  ),

                              // Next button
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed: _currentPage < _totalPages
                                    ? () => setState(() => _currentPage++)
                                    : null,
                                color: _currentPage < _totalPages
                                    ? const Color(0xFF666666)
                                    : const Color(0xFFCCCCCC),
                              ),
                            ],
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
    );
  }

  // Helper method to get role colors
  Color _getRoleColor(String role) {
    switch (role) {
      case 'Parent':
        return Colors.blue;
      case 'Teacher':
        return Colors.purple;
      case 'Guard':
        return Colors.orange;
      case 'Driver':
        return Colors.teal;
      default:
        return Colors.grey;
    }
  }
}

// Custom header cell for table
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