import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kidsync/widgets/role_protection.dart';

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
  String _sortOption = 'Alphabetical';

  @override
  void initState() {
    super.initState();
    _fetchUsers();
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
      // Optionally, parse for error message in JSON
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

  Future<void> _addOrEditUser({Map<String, dynamic>? user}) async {
    String? fname = user?['fname'];
    String? mname = user?['mname'];
    String? lname = user?['lname'];
    String? email = user?['email'];
    String? contactNumber = user?['contact_number'];
    String? position = user?['position'];
    String? role = user?['role'];

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
          title: Text(user == null ? 'Add User' : 'Edit User'),
          content: SingleChildScrollView(
            child: Column(
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
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
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

  Future<void> _deleteUser(int id) async {
    await supabase.from('users').delete().eq('id', id);
    _fetchUsers();
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isAdmin = user?.userMetadata?['role'] == 'Admin';

    // Filter and sort logic
    var filteredUsers =
        users.where((u) {
          final name = "${u['fname']} ${u['lname']}".toLowerCase();
          return name.contains(_searchQuery.toLowerCase());
        }).toList();

    if (_sortOption == 'Alphabetical') {
      filteredUsers.sort(
        (a, b) => (a['lname'] ?? '').compareTo(b['lname'] ?? ''),
      );
    } else if (_sortOption == 'Per Class') {
      filteredUsers.sort(
        (a, b) => (a['position'] ?? '').compareTo(b['position'] ?? ''),
      );
    }

    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  "User Management",
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                ),
                ElevatedButton(
                  onPressed: isAdmin ? () => _addOrEditUser() : null,
                  child: const Text("+ Add User"),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: const InputDecoration(
                      prefixIcon: Icon(Icons.search),
                      hintText: 'Search users...',
                    ),
                    onChanged: (val) => setState(() => _searchQuery = val),
                  ),
                ),
                const SizedBox(width: 16),
                DropdownButton<String>(
                  value: _sortOption,
                  onChanged: (val) => setState(() => _sortOption = val!),
                  items:
                      ['Alphabetical', 'Per Class']
                          .map(
                            (e) => DropdownMenuItem(value: e, child: Text(e)),
                          )
                          .toList(),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (isLoading)
              const Center(child: CircularProgressIndicator())
            else if (filteredUsers.isEmpty)
              const Center(child: Text("No users yet."))
            else
              Expanded(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: DataTable(
                    columns: const [
                      DataColumn(label: Text('Employee ID')),
                      DataColumn(label: Text('Name')),
                      DataColumn(label: Text('Role')),
                      DataColumn(label: Text('Position')),
                      DataColumn(label: Text('Email')),
                      DataColumn(label: Text('Contact Number')),
                      DataColumn(label: Text('Actions')),
                    ],
                    rows:
                        filteredUsers.map((u) {
                          final fullName =
                              "${u['fname'] ?? ''} ${u['lname'] ?? ''}";
                          return DataRow(
                            cells: [
                              DataCell(Text(u['employee_id'] ?? '-')),
                              DataCell(Text(fullName)),
                              DataCell(Text(u['role'] ?? '-')),
                              DataCell(Text(u['position'] ?? '-')),
                              DataCell(Text(u['email'] ?? '-')),
                              DataCell(Text(u['contact_number'] ?? '-')),
                              DataCell(
                                isAdmin
                                    ? PopupMenuButton<String>(
                                      onSelected: (value) {
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
                                                    'Are you sure you want to delete this student?',
                                                  ),
                                                  actions: [
                                                    TextButton(
                                                      onPressed:
                                                          () => Navigator.pop(
                                                            ctx,
                                                          ),
                                                      child: const Text(
                                                        'Cancel',
                                                      ),
                                                    ),
                                                    ElevatedButton(
                                                      onPressed: () async {
                                                        Navigator.pop(ctx);
                                                        try {
                                                          await deleteUserViaEdgeFunction(
                                                            u['id'].toString(),
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
                                          ],
                                    )
                                    : const Text('-'),
                              ),
                            ],
                          );
                        }).toList(),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
