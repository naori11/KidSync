import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kidsync/widgets/role_protection.dart';
import 'package:intl/intl.dart'; // Add this import for date formatting if needed

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
  int _itemsPerPage = 8; // Show 8 items per page like in the image
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

  // New function to send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await supabase.auth.resetPasswordForEmail(
        email,
        redirectTo: null, // You can add a redirect URL if needed
      );
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  Future<void> _addOrEditUser({Map<String, dynamic>? user}) async {
    String? fname = user?['fname'];
    String? mname = user?['mname'];
    String? lname = user?['lname'];
    String? email = user?['email'];
    String? contactNumber = user?['contact_number'];
    String? position = user?['position'];
    String? role = user?['role'];
    String? status = user?['status'] ?? 'Active';

    final List<String> roles = [
      'Admin',
      'Parent',
      'Teacher',
      'Guard',
      'Driver',
    ];

    await showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(user == null ? 'Add New User' : 'Edit User'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextField(
                  decoration: const InputDecoration(labelText: 'First Name'),
                  controller: TextEditingController(text: fname),
                  onChanged: (val) => fname = val,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Middle Name'),
                  controller: TextEditingController(text: mname),
                  onChanged: (val) => mname = val,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Last Name'),
                  controller: TextEditingController(text: lname),
                  onChanged: (val) => lname = val,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Email'),
                  controller: TextEditingController(text: email),
                  onChanged: (val) => email = val,
                ),
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Contact Number',
                  ),
                  controller: TextEditingController(text: contactNumber),
                  onChanged: (val) => contactNumber = val,
                ),
                TextField(
                  decoration: const InputDecoration(labelText: 'Position'),
                  controller: TextEditingController(text: position),
                  onChanged: (val) => position = val,
                ),
                DropdownButtonFormField<String>(
                  value: role,
                  hint: const Text('Select Role'),
                  items:
                      roles.map((r) {
                        return DropdownMenuItem(value: r, child: Text(r));
                      }).toList(),
                  onChanged: (val) => role = val,
                ),
                DropdownButtonFormField<String>(
                  decoration: const InputDecoration(labelText: 'Status'),
                  value: status,
                  items: const [
                    DropdownMenuItem(value: 'Active', child: Text('Active')),
                    DropdownMenuItem(
                      value: 'Inactive',
                      child: Text('Inactive'),
                    ),
                  ],
                  onChanged: (value) => status = value,
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71), // Green color
                foregroundColor: Colors.white,
              ),
              onPressed: () async {
                // Validation
                if ([
                  fname,
                  lname,
                  email,
                  role,
                ].any((e) => e == null || e!.isEmpty)) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Fill all required fields.')),
                  );
                  return;
                }
                try {
                  if (user == null) {
                    await createUserViaEdgeFunction(
                      email: email!,
                      role: role!,
                      fname: fname!,
                      mname: mname,
                      lname: lname!,
                      contactNumber: contactNumber,
                      position: position,
                    );
                  } else {
                    await editUserViaEdgeFunction(
                      id: user['id'].toString(),
                      email: email!,
                      role: role!,
                      fname: fname!,
                      mname: mname,
                      lname: lname!,
                      contactNumber: contactNumber,
                      position: position,
                    );
                  }
                  Navigator.pop(context);
                  await _fetchUsers();
                } catch (e) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(SnackBar(content: Text('Error: $e')));
                }
              },
              child: Text(user == null ? 'Add' : 'Update'),
            ),
          ],
        );
      },
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
    var filteredUsers =
        users.where((u) {
          final name = "${u['fname'] ?? ''} ${u['lname'] ?? ''}".toLowerCase();
          final roleMatch =
              _roleFilter == 'All Roles' || u['role'] == _roleFilter;

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
    final int endIndex =
        startIndex + _itemsPerPage > filteredUsers.length
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
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
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

                // Search box
                Container(
                  width: 240,
                  height: 40,
                  decoration: BoxDecoration(
                    border: Border.all(color: const Color(0xFFE0E0E0)),
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                  ),
                  child: TextField(
                    decoration: const InputDecoration(
                      hintText: 'Search users...',
                      prefixIcon: Icon(Icons.search, color: Color(0xFF9E9E9E)),
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 10.0),
                    ),
                    onChanged:
                        (val) => setState(() {
                          _searchQuery = val;
                          _currentPage = 1; // Reset to first page on new search
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
                      backgroundColor: const Color(0xFF2ECC71), // Green color
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
                        items:
                            roleOptions.map((String item) {
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
                        items:
                            <String>[
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

            // Table
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
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(4),
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        spreadRadius: 1,
                        blurRadius: 5,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: SingleChildScrollView(
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
                      defaultVerticalAlignment:
                          TableCellVerticalAlignment.middle,
                      children: [
                        // Table header row
                        TableRow(
                          decoration: BoxDecoration(color: Colors.grey[50]),
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
                          final int userIndex =
                              users.indexWhere(
                                (item) => item['id'] == u['id'],
                              ) +
                              1;
                          final String userId =
                              "$userPrefix${userIndex.toString().padLeft(3, '0')}";
                          final fullName =
                              "${u['fname'] ?? ''} ${u['lname'] ?? ''}";
                          final status = u['status'] ?? 'Active';

                          return TableRow(
                            children: [
                              // User ID
                              TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Container(
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
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Container(
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
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(role),
                                ),
                              ),

                              // Email
                              TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(u['email'] ?? 'N/A'),
                                ),
                              ),

                              // Phone/Contact
                              TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Text(u['contact_number'] ?? 'N/A'),
                                ),
                              ),

                              // Status
                              TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color:
                                          status == 'Active'
                                              ? const Color(0xFFE8F5E9)
                                              : const Color(0xFFFFEBEE),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(
                                        color:
                                            status == 'Active'
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

                              // Actions with reset password option
                              TableCell(
                                verticalAlignment:
                                    TableCellVerticalAlignment.middle,
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  child:
                                      isAdmin
                                          ? PopupMenuButton<String>(
                                            onSelected: (value) async {
                                              if (value == 'edit') {
                                                _addOrEditUser(user: u);
                                              } else if (value == 'delete') {
                                                showDialog(
                                                  context: context,
                                                  builder:
                                                      (ctx) => AlertDialog(
                                                        title: const Text(
                                                          'Confirm Delete',
                                                        ),
                                                        content: const Text(
                                                          'Are you sure you want to delete this user?',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed:
                                                                () =>
                                                                    Navigator.pop(
                                                                      ctx,
                                                                    ),
                                                            child: const Text(
                                                              'Cancel',
                                                            ),
                                                          ),
                                                          ElevatedButton(
                                                            style:
                                                                ElevatedButton.styleFrom(
                                                                  backgroundColor:
                                                                      Colors
                                                                          .red,
                                                                ),
                                                            onPressed: () async {
                                                              Navigator.pop(
                                                                ctx,
                                                              );
                                                              try {
                                                                await deleteUserViaEdgeFunction(
                                                                  u['id']
                                                                      .toString(),
                                                                );
                                                                await _fetchUsers();
                                                              } catch (e) {
                                                                ScaffoldMessenger.of(
                                                                  context,
                                                                ).showSnackBar(
                                                                  SnackBar(
                                                                    content: Text(
                                                                      'Error: $e',
                                                                    ),
                                                                  ),
                                                                );
                                                              }
                                                            },
                                                            child: const Text(
                                                              'Delete',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors
                                                                        .white,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                );
                                              } else if (value ==
                                                  'reset_password') {
                                                showDialog(
                                                  context: context,
                                                  builder:
                                                      (ctx) => AlertDialog(
                                                        title: const Text(
                                                          'Confirm Reset Password',
                                                        ),
                                                        content: const Text(
                                                          'Send password reset email to this user?',
                                                        ),
                                                        actions: [
                                                          TextButton(
                                                            onPressed:
                                                                () =>
                                                                    Navigator.pop(
                                                                      ctx,
                                                                    ),
                                                            child: const Text(
                                                              'Cancel',
                                                            ),
                                                          ),
                                                          ElevatedButton(
                                                            style: ElevatedButton.styleFrom(
                                                              backgroundColor:
                                                                  const Color(
                                                                    0xFF2ECC71,
                                                                  ),
                                                            ),
                                                            onPressed: () async {
                                                              Navigator.pop(
                                                                ctx,
                                                              );
                                                              try {
                                                                await sendPasswordResetEmail(
                                                                  u['email'],
                                                                );
                                                                ScaffoldMessenger.of(
                                                                  context,
                                                                ).showSnackBar(
                                                                  const SnackBar(
                                                                    content: Text(
                                                                      'Password reset email sent successfully',
                                                                    ),
                                                                  ),
                                                                );
                                                              } catch (e) {
                                                                ScaffoldMessenger.of(
                                                                  context,
                                                                ).showSnackBar(
                                                                  SnackBar(
                                                                    content: Text(
                                                                      'Error: $e',
                                                                    ),
                                                                  ),
                                                                );
                                                              }
                                                            },
                                                            child: const Text(
                                                              'Send Email',
                                                              style: TextStyle(
                                                                color:
                                                                    Colors
                                                                        .white,
                                                              ),
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                );
                                              }
                                            },
                                            itemBuilder:
                                                (context) => [
                                                  const PopupMenuItem(
                                                    value: 'edit',
                                                    child: Text('Edit'),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'delete',
                                                    child: Text('Delete'),
                                                  ),
                                                  const PopupMenuItem(
                                                    value: 'reset_password',
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.email,
                                                          size: 16,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Send Reset Password',
                                                        ),
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
            if (!isLoading && filteredUsers.isNotEmpty)
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
                        TextButton(
                          onPressed:
                              _currentPage > 1
                                  ? () => setState(() => _currentPage--)
                                  : null,
                          style: TextButton.styleFrom(
                            foregroundColor:
                                _currentPage > 1
                                    ? const Color(0xFF666666)
                                    : const Color(0xFFCCCCCC),
                          ),
                          child: const Text('Previous'),
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
                                color:
                                    i == _currentPage
                                        ? const Color(0xFF2ECC71)
                                        : Colors.transparent,
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: TextButton(
                                onPressed:
                                    () => setState(() => _currentPage = i),
                                style: TextButton.styleFrom(
                                  padding: EdgeInsets.zero,
                                  foregroundColor:
                                      i == _currentPage
                                          ? Colors.white
                                          : const Color(0xFF666666),
                                ),
                                child: Text(
                                  i.toString(),
                                  style: const TextStyle(fontSize: 14),
                                ),
                              ),
                            )
                          else if (i == _currentPage - 2 ||
                              i == _currentPage + 2)
                            const Padding(
                              padding: EdgeInsets.symmetric(horizontal: 4),
                              child: Text('...'),
                            ),

                        // Next button
                        TextButton(
                          onPressed:
                              _currentPage < _totalPages
                                  ? () => setState(() => _currentPage++)
                                  : null,
                          style: TextButton.styleFrom(
                            foregroundColor:
                                _currentPage < _totalPages
                                    ? const Color(0xFF666666)
                                    : const Color(0xFFCCCCCC),
                          ),
                          child: const Text('Next'),
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
}

// Custom header cell for table
class TableHeaderCell extends StatelessWidget {
  final String text;

  const TableHeaderCell({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
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
