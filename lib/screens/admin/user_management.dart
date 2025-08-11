import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kidsync/widgets/role_protection.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'package:cross_file/cross_file.dart';

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

  // For image uploads
  String? _selectedImagePath;
  String? _currentImageUrl;
  bool _isUploadingImage = false;
  Uint8List? _selectedImageBytes;

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
    String? profileImageUrl,
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
        'profile_image_url': profileImageUrl,
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
    String? profileImageUrl,
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
        'profile_image_url': profileImageUrl,
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
      await supabase.auth.resetPasswordForEmail(email, redirectTo: null);
    } catch (e) {
      throw Exception('Failed to send password reset email: $e');
    }
  }

  Future<void> _addOrEditUser({Map<String, dynamic>? user}) async {
    print('Debug: User data received: $user'); // Debug print

    setState(() {
      _selectedImagePath = null;
      _selectedImageBytes = null;
      _currentImageUrl = user?['profile_image_url']; // Add this line
      _isUploadingImage = false;
    });

    // Form controllers
    final fnameController = TextEditingController(
      text: user?['fname']?.toString() ?? '',
    );
    final mnameController = TextEditingController(
      text: user?['mname']?.toString() ?? '',
    );
    final lnameController = TextEditingController(
      text: user?['lname']?.toString() ?? '',
    );
    final emailController = TextEditingController(
      text: user?['email']?.toString() ?? '',
    );
    final contactController = TextEditingController(
      text: user?['contact_number']?.toString() ?? '',
    );
    final positionController = TextEditingController(
      text: user?['position']?.toString() ?? '',
    );

    // Form state variables - Aligned with schema
    String? selectedRole = user?['role']?.toString();
    String selectedStatus = user?['status']?.toString() ?? 'Active';

    // Form validation key
    final formKey = GlobalKey<FormState>();

    // Role options based on schema constraint
    final roleOptions = ['Parent', 'Guard', 'Teacher', 'Driver', 'Admin'];

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
                            if (!RegExp(
                              r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$',
                            ).hasMatch(value!)) {
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
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'[0-9+\-\(\)\s]'),
                                  ),
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
                        const SizedBox(height: 16),

                        // Role and Status row (moved up before Profile Image)
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: _buildInputDecoration(
                                  'Role',
                                  Icons.admin_panel_settings,
                                  isRequired: true,
                                ),
                                value:
                                    roleOptions.contains(selectedRole)
                                        ? selectedRole
                                        : null,
                                items:
                                    roleOptions.map((role) {
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
                                            Icon(
                                              roleIcon,
                                              size: 16,
                                              color: Colors.grey[600],
                                            ),
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
                                        Icon(
                                          Icons.check_circle,
                                          color: Colors.green,
                                          size: 16,
                                        ),
                                        SizedBox(width: 8),
                                        Text('Active'),
                                      ],
                                    ),
                                  ),
                                  DropdownMenuItem(
                                    value: 'Inactive',
                                    child: Row(
                                      children: [
                                        Icon(
                                          Icons.cancel,
                                          color: Colors.red,
                                          size: 16,
                                        ),
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
                        const SizedBox(height: 24),

                        // Profile Image Section (moved to bottom)
                        _buildSectionHeader('Profile Image'),
                        const SizedBox(height: 16),
                        Center(
                          child: Column(
                            children: [
                              // Display current image or placeholder
                              GestureDetector(
                                onTap: () async {
                                  final ImagePicker picker = ImagePicker();
                                  final XFile? image = await picker.pickImage(
                                    source: ImageSource.gallery,
                                    maxWidth: 800,
                                    maxHeight: 800,
                                    imageQuality: 85,
                                  );

                                  if (image != null) {
                                    final bytes = await image.readAsBytes();

                                    if (bytes.length > 5 * 1024 * 1024) {
                                      if (mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Image size must be less than 5MB',
                                            ),
                                            backgroundColor: Colors.red,
                                          ),
                                        );
                                      }
                                      return;
                                    }

                                    if (_validateImageBytes(
                                      bytes,
                                      image.name,
                                    )) {
                                      setDialogState(() {
                                        _selectedImageBytes = bytes;
                                        _selectedImagePath = image.name;
                                        _currentImageUrl = null;
                                      });
                                    }
                                  }
                                },
                                child: Container(
                                  width: 120,
                                  height: 120,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(60),
                                    border: Border.all(
                                      color: const Color(0xFF2ECC71),
                                      width: 2,
                                    ),
                                  ),
                                  child: ClipOval(
                                    child: _buildImageWidget(user),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Upload/Remove buttons
                              if (_selectedImageBytes != null) ...[
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    ElevatedButton.icon(
                                      onPressed:
                                          _isUploadingImage
                                              ? null
                                              : () async {
                                                final ImagePicker picker =
                                                    ImagePicker();
                                                final XFile? image =
                                                    await picker.pickImage(
                                                      source:
                                                          ImageSource.gallery,
                                                      maxWidth: 800,
                                                      maxHeight: 800,
                                                      imageQuality: 85,
                                                    );

                                                if (image != null) {
                                                  final bytes =
                                                      await image.readAsBytes();

                                                  if (bytes.length >
                                                      5 * 1024 * 1024) {
                                                    if (mounted) {
                                                      ScaffoldMessenger.of(
                                                        context,
                                                      ).showSnackBar(
                                                        const SnackBar(
                                                          content: Text(
                                                            'Image size must be less than 5MB',
                                                          ),
                                                          backgroundColor:
                                                              Colors.red,
                                                        ),
                                                      );
                                                    }
                                                    return;
                                                  }

                                                  if (_validateImageBytes(
                                                    bytes,
                                                    image.name,
                                                  )) {
                                                    setDialogState(() {
                                                      _selectedImageBytes =
                                                          bytes;
                                                      _selectedImagePath =
                                                          image.name;
                                                      _currentImageUrl = null;
                                                    });
                                                  }
                                                }
                                              },
                                      icon: const Icon(Icons.edit, size: 16),
                                      label: const Text('Change'),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.orange,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    ElevatedButton.icon(
                                      onPressed:
                                          _isUploadingImage
                                              ? null
                                              : () {
                                                setDialogState(() {
                                                  _selectedImageBytes = null;
                                                  _selectedImagePath = null;
                                                  _currentImageUrl = null;
                                                });
                                              },
                                      icon:
                                          _isUploadingImage
                                              ? const SizedBox(
                                                width: 16,
                                                height: 16,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: Colors.white,
                                                    ),
                                              )
                                              : const Icon(
                                                Icons.clear,
                                                size: 16,
                                              ),
                                      label: Text(
                                        _isUploadingImage
                                            ? 'Processing...'
                                            : 'Remove',
                                      ),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: Colors.red,
                                        foregroundColor: Colors.white,
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 12,
                                          vertical: 8,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                ElevatedButton.icon(
                                  onPressed: () async {
                                    final ImagePicker picker = ImagePicker();
                                    final XFile? image = await picker.pickImage(
                                      source: ImageSource.gallery,
                                      maxWidth: 800,
                                      maxHeight: 800,
                                      imageQuality: 85,
                                    );

                                    if (image != null) {
                                      final bytes = await image.readAsBytes();

                                      if (bytes.length > 5 * 1024 * 1024) {
                                        if (mounted) {
                                          ScaffoldMessenger.of(
                                            context,
                                          ).showSnackBar(
                                            const SnackBar(
                                              content: Text(
                                                'Image size must be less than 5MB',
                                              ),
                                              backgroundColor: Colors.red,
                                            ),
                                          );
                                        }
                                        return;
                                      }

                                      if (_validateImageBytes(
                                        bytes,
                                        image.name,
                                      )) {
                                        setDialogState(() {
                                          _selectedImageBytes = bytes;
                                          _selectedImagePath = image.name;
                                          _currentImageUrl = null;
                                        });
                                      }
                                    }
                                  },
                                  icon: const Icon(Icons.upload),
                                  label: const Text('Upload Photo'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2ECC71),
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
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
                                Icon(
                                  Icons.info,
                                  color: Colors.blue[600],
                                  size: 16,
                                ),
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
                    backgroundColor: const Color.fromARGB(10, 78, 241, 157),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        String? imageUrl =
                            _currentImageUrl ?? user?['profile_image_url'];

                        // Handle image upload if there's a selected image
                        if (_selectedImagePath != null &&
                            _selectedImageBytes != null) {
                          if (user == null) {
                            // For new users, create user first, then upload image
                            await createUserViaEdgeFunction(
                              email: emailController.text.trim(),
                              role: selectedRole!,
                              fname: fnameController.text.trim(),
                              mname:
                                  mnameController.text.trim().isEmpty
                                      ? null
                                      : mnameController.text.trim(),
                              lname: lnameController.text.trim(),
                              contactNumber:
                                  contactController.text.trim().isEmpty
                                      ? null
                                      : contactController.text.trim(),
                              position:
                                  positionController.text.trim().isEmpty
                                      ? null
                                      : positionController.text.trim(),
                              profileImageUrl:
                                  null, // Create without image first
                            );

                            // Get the created user ID
                            final createdUser =
                                await supabase
                                    .from('users')
                                    .select('id')
                                    .eq('email', emailController.text.trim())
                                    .single();

                            // Now upload image with the correct user ID
                            final XFile imageFile = XFile.fromData(
                              _selectedImageBytes!,
                              name: _selectedImagePath!,
                            );
                            final uploadedUrl = await _uploadImageToSupabase(
                              imageFile,
                              createdUser['id'].toString(),
                            );

                            // Update user with image URL
                            if (uploadedUrl != null) {
                              await supabase
                                  .from('users')
                                  .update({'profile_image_url': uploadedUrl})
                                  .eq('id', createdUser['id']);

                              // Also update auth metadata
                              await supabase.auth.admin.updateUserById(
                                createdUser['id'],
                                attributes: AdminUserAttributes(
                                  userMetadata: {
                                    'profile_image_url': uploadedUrl,
                                  },
                                ),
                              );
                            }
                          } else {
                            // For existing users, upload image first
                            final XFile imageFile = XFile.fromData(
                              _selectedImageBytes!,
                              name: _selectedImagePath!,
                            );
                            final uploadedUrl = await _uploadImageToSupabase(
                              imageFile,
                              user['id'].toString(),
                            );

                            if (uploadedUrl != null) {
                              imageUrl = uploadedUrl;
                              // Delete old image if updating
                              if (user['profile_image_url'] != null &&
                                  user['profile_image_url']
                                      .toString()
                                      .isNotEmpty) {
                                await _deleteImageFromSupabase(
                                  user['profile_image_url'],
                                );
                              }
                            }

                            // Update user with new data
                            await editUserViaEdgeFunction(
                              id: user['id'].toString(),
                              email: emailController.text.trim(),
                              role: selectedRole!,
                              fname: fnameController.text.trim(),
                              mname:
                                  mnameController.text.trim().isEmpty
                                      ? null
                                      : mnameController.text.trim(),
                              lname: lnameController.text.trim(),
                              contactNumber:
                                  contactController.text.trim().isEmpty
                                      ? null
                                      : contactController.text.trim(),
                              position:
                                  positionController.text.trim().isEmpty
                                      ? null
                                      : positionController.text.trim(),
                              profileImageUrl: imageUrl,
                            );
                          }
                        } else {
                          // No image selected
                          if (user == null) {
                            // Create new user without image
                            await createUserViaEdgeFunction(
                              email: emailController.text.trim(),
                              role: selectedRole!,
                              fname: fnameController.text.trim(),
                              mname:
                                  mnameController.text.trim().isEmpty
                                      ? null
                                      : mnameController.text.trim(),
                              lname: lnameController.text.trim(),
                              contactNumber:
                                  contactController.text.trim().isEmpty
                                      ? null
                                      : contactController.text.trim(),
                              position:
                                  positionController.text.trim().isEmpty
                                      ? null
                                      : positionController.text.trim(),
                              profileImageUrl: imageUrl,
                            );
                          } else {
                            // Update existing user
                            await editUserViaEdgeFunction(
                              id: user['id'].toString(),
                              email: emailController.text.trim(),
                              role: selectedRole!,
                              fname: fnameController.text.trim(),
                              mname:
                                  mnameController.text.trim().isEmpty
                                      ? null
                                      : mnameController.text.trim(),
                              lname: lnameController.text.trim(),
                              contactNumber:
                                  contactController.text.trim().isEmpty
                                      ? null
                                      : contactController.text.trim(),
                              position:
                                  positionController.text.trim().isEmpty
                                      ? null
                                      : positionController.text.trim(),
                              profileImageUrl: imageUrl,
                            );
                          }
                        }

                        // Reset image state
                        setState(() {
                          _selectedImagePath = null;
                          _selectedImageBytes = null;
                          _currentImageUrl = null;
                          _isUploadingImage = false;
                        });

                        Navigator.pop(context);
                        await _fetchUsers();

                        // Show success message
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(
                                    Icons.check_circle,
                                    color: Colors.white,
                                  ),
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
                        // Error handling
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Row(
                                children: [
                                  const Icon(Icons.error, color: Colors.white),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text('Error: ${e.toString()}'),
                                  ),
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
  InputDecoration _buildInputDecoration(
    String label,
    IconData icon, {
    bool isRequired = false,
  }) {
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
      labelStyle: TextStyle(color: Colors.grey[600], fontSize: 14),
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

  // Image validation function
  bool _validateImageBytes(Uint8List bytes, String fileName) {
    // Check file extension
    final String extension = fileName.toLowerCase().split('.').last;
    const List<String> allowedExtensions = ['jpg', 'jpeg', 'png', 'webp'];

    if (!allowedExtensions.contains(extension)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Only JPG, PNG, and WebP images are allowed'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    if (bytes.length < 8) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Invalid image file'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return false;
    }

    return true;
  }

  // Upload image to Supabase Storage
  Future<String?> _uploadImageToSupabase(XFile image, String userId) async {
    try {
      setState(() => _isUploadingImage = true);

      Uint8List imageBytes;
      if (_selectedImageBytes != null) {
        imageBytes = _selectedImageBytes!;
      } else {
        imageBytes = await image.readAsBytes();
      }

      // Generate unique filename
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String extension = image.name.split('.').last.toLowerCase();
      final String fileName = 'user_${userId}_$timestamp.$extension';

      // Upload to Supabase Storage
      final String uploadPath = await supabase.storage
          .from('user-profile')
          .uploadBinary(fileName, imageBytes);

      // Get public URL
      final String publicUrl = supabase.storage
          .from('user-profile')
          .getPublicUrl(fileName);

      return publicUrl;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error uploading image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
      return null;
    } finally {
      if (mounted) {
        setState(() => _isUploadingImage = false);
      }
    }
  }

  // Delete image from Supabase Storage
  Future<void> _deleteImageFromSupabase(String imageUrl) async {
    try {
      final Uri uri = Uri.parse(imageUrl);
      final String fileName = uri.pathSegments.last;
      await supabase.storage.from('user-profile').remove([fileName]);
    } catch (e) {
      print('Error deleting image: $e');
    }
  }

  // Build image widget
  Widget _buildImageWidget(Map<String, dynamic>? user) {
    // Priority: selected bytes -> current URL -> user profile URL -> default icon
    if (_selectedImageBytes != null) {
      return Image.memory(
        _selectedImageBytes!,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.person, size: 60, color: Colors.grey);
        },
      );
    } else if (_currentImageUrl != null && _currentImageUrl!.isNotEmpty) {
      return Image.network(
        _currentImageUrl!,
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 120,
            height: 120,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.person, size: 60, color: Colors.grey);
        },
      );
    } else if (user != null &&
        user['profile_image_url'] != null &&
        user['profile_image_url'].toString().isNotEmpty) {
      return Image.network(
        user['profile_image_url'],
        width: 120,
        height: 120,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return Container(
            width: 120,
            height: 120,
            color: Colors.grey[200],
            child: const Center(
              child: CircularProgressIndicator(color: Color(0xFF2ECC71)),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return const Icon(Icons.person, size: 60, color: Colors.grey);
        },
      );
    } else {
      return const Icon(Icons.person, size: 60, color: Colors.grey);
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
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
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
                    onChanged:
                        (val) => setState(() {
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
                      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
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
                              1: FlexColumnWidth(
                                2.0,
                              ), // Name + Image (increased width)
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
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                  ),
                                  children: [
                                    // User ID
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          userId,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF555555),
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Name WITH PROFILE IMAGE (similar to student management)
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            // Profile Image
                                            Container(
                                              width: 40,
                                              height: 40,
                                              decoration: BoxDecoration(
                                                borderRadius:
                                                    BorderRadius.circular(20),
                                                border: Border.all(
                                                  color: const Color(
                                                    0xFF2ECC71,
                                                  ).withOpacity(0.3),
                                                  width: 2,
                                                ),
                                              ),
                                              child: ClipOval(
                                                child:
                                                    (u['profile_image_url'] !=
                                                                null &&
                                                            u['profile_image_url']
                                                                .toString()
                                                                .isNotEmpty)
                                                        ? Image.network(
                                                          u['profile_image_url'],
                                                          width: 40,
                                                          height: 40,
                                                          fit: BoxFit.cover,
                                                          loadingBuilder: (
                                                            context,
                                                            child,
                                                            loadingProgress,
                                                          ) {
                                                            if (loadingProgress ==
                                                                null)
                                                              return child;
                                                            return Container(
                                                              width: 40,
                                                              height: 40,
                                                              color:
                                                                  Colors
                                                                      .grey[200],
                                                              child: const Center(
                                                                child: SizedBox(
                                                                  width: 16,
                                                                  height: 16,
                                                                  child: CircularProgressIndicator(
                                                                    strokeWidth:
                                                                        2,
                                                                    color: Color(
                                                                      0xFF2ECC71,
                                                                    ),
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
                                                            return const Icon(
                                                              Icons.person,
                                                              size: 20,
                                                              color:
                                                                  Colors.grey,
                                                            );
                                                          },
                                                        )
                                                        : const Icon(
                                                          Icons.person,
                                                          size: 20,
                                                          color: Colors.grey,
                                                        ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // User Name and additional info
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                mainAxisAlignment:
                                                    MainAxisAlignment.center,
                                                children: [
                                                  Text(
                                                    fullName,
                                                    style: const TextStyle(
                                                      fontWeight:
                                                          FontWeight.w600,
                                                      color: Color(0xFF333333),
                                                      fontSize: 14,
                                                    ),
                                                  ),
                                                  if (u['position'] != null &&
                                                      u['position']
                                                          .toString()
                                                          .isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Text(
                                                      u['position'].toString(),
                                                      style: TextStyle(
                                                        fontSize: 11,
                                                        color: Colors.grey[600],
                                                        fontStyle:
                                                            FontStyle.italic,
                                                      ),
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Role
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color: _getRoleColor(
                                              role,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Icon(
                                                _getRoleIcon(role),
                                                size: 12,
                                                color: _getRoleColor(role),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                role,
                                                style: TextStyle(
                                                  color: _getRoleColor(role),
                                                  fontWeight: FontWeight.w500,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Email
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Icon(
                                              Icons.email,
                                              size: 14,
                                              color: Colors.grey[600],
                                            ),
                                            const SizedBox(width: 6),
                                            Expanded(
                                              child: Text(
                                                u['email'] ?? 'N/A',
                                                style: const TextStyle(
                                                  fontSize: 13,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // Phone/Contact
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16),
                                        child:
                                            u['contact_number'] != null &&
                                                    u['contact_number']
                                                        .toString()
                                                        .isNotEmpty
                                                ? Row(
                                                  children: [
                                                    Icon(
                                                      Icons.phone,
                                                      size: 14,
                                                      color: Colors.grey[600],
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Text(
                                                      u['contact_number'],
                                                      style: const TextStyle(
                                                        fontSize: 13,
                                                      ),
                                                    ),
                                                  ],
                                                )
                                                : Text(
                                                  'N/A',
                                                  style: TextStyle(
                                                    fontSize: 13,
                                                    color: Colors.grey[500],
                                                    fontStyle: FontStyle.italic,
                                                  ),
                                                ),
                                      ),
                                    ),

                                    // Status
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Padding(
                                        padding: const EdgeInsets.all(16),
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 6,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                status == 'Active'
                                                    ? const Color(0xFFE8F5E9)
                                                    : const Color(0xFFFFEBEE),
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                            border: Border.all(
                                              color:
                                                  status == 'Active'
                                                      ? const Color(0xFF4CAF50)
                                                      : const Color(0xFFE57373),
                                              width: 1,
                                            ),
                                          ),
                                          child: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              Container(
                                                width: 6,
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color:
                                                      status == 'Active'
                                                          ? const Color(
                                                            0xFF4CAF50,
                                                          )
                                                          : const Color(
                                                            0xFFE57373,
                                                          ),
                                                  borderRadius:
                                                      BorderRadius.circular(3),
                                                ),
                                              ),
                                              const SizedBox(width: 6),
                                              Text(
                                                status,
                                                style: TextStyle(
                                                  color:
                                                      status == 'Active'
                                                          ? const Color(
                                                            0xFF2E7D32,
                                                          )
                                                          : const Color(
                                                            0xFFC62828,
                                                          ),
                                                  fontWeight: FontWeight.w600,
                                                  fontSize: 12,
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Actions
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Center(
                                        child:
                                            isAdmin
                                                ? PopupMenuButton<String>(
                                                  icon: Icon(
                                                    Icons.more_vert,
                                                    color: Colors.grey[600],
                                                  ),
                                                  iconSize: 20,
                                                  onSelected: (value) async {
                                                    if (value == 'edit') {
                                                      _addOrEditUser(user: u);
                                                    } else if (value ==
                                                        'delete') {
                                                      showDialog(
                                                        context: context,
                                                        builder:
                                                            (
                                                              ctx,
                                                            ) => AlertDialog(
                                                              title: const Row(
                                                                children: [
                                                                  Icon(
                                                                    Icons
                                                                        .warning,
                                                                    color:
                                                                        Colors
                                                                            .red,
                                                                  ),
                                                                  SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Text(
                                                                    'Confirm Delete',
                                                                  ),
                                                                ],
                                                              ),
                                                              content: Text(
                                                                'Are you sure you want to delete ${u['fname']} ${u['lname']}? This action cannot be undone.',
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed:
                                                                      () =>
                                                                          Navigator.pop(
                                                                            ctx,
                                                                          ),
                                                                  child:
                                                                      const Text(
                                                                        'Cancel',
                                                                      ),
                                                                ),
                                                                ElevatedButton(
                                                                  style: ElevatedButton.styleFrom(
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
                                                                      if (mounted) {
                                                                        ScaffoldMessenger.of(
                                                                          context,
                                                                        ).showSnackBar(
                                                                          const SnackBar(
                                                                            content: Row(
                                                                              children: [
                                                                                Icon(
                                                                                  Icons.check_circle,
                                                                                  color:
                                                                                      Colors.white,
                                                                                ),
                                                                                SizedBox(
                                                                                  width:
                                                                                      8,
                                                                                ),
                                                                                Text(
                                                                                  'User deleted successfully!',
                                                                                ),
                                                                              ],
                                                                            ),
                                                                            backgroundColor: Color(
                                                                              0xFF2ECC71,
                                                                            ),
                                                                            behavior:
                                                                                SnackBarBehavior.floating,
                                                                          ),
                                                                        );
                                                                      }
                                                                    } catch (
                                                                      e
                                                                    ) {
                                                                      if (mounted) {
                                                                        ScaffoldMessenger.of(
                                                                          context,
                                                                        ).showSnackBar(
                                                                          SnackBar(
                                                                            content: Row(
                                                                              children: [
                                                                                const Icon(
                                                                                  Icons.error,
                                                                                  color:
                                                                                      Colors.white,
                                                                                ),
                                                                                const SizedBox(
                                                                                  width:
                                                                                      8,
                                                                                ),
                                                                                Expanded(
                                                                                  child: Text(
                                                                                    'Error: ${e.toString()}',
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                            backgroundColor:
                                                                                Colors.red,
                                                                            behavior:
                                                                                SnackBarBehavior.floating,
                                                                          ),
                                                                        );
                                                                      }
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
                                                            (
                                                              ctx,
                                                            ) => AlertDialog(
                                                              title: const Row(
                                                                children: [
                                                                  Icon(
                                                                    Icons.email,
                                                                    color: Color(
                                                                      0xFF2ECC71,
                                                                    ),
                                                                  ),
                                                                  SizedBox(
                                                                    width: 8,
                                                                  ),
                                                                  Text(
                                                                    'Reset Password',
                                                                  ),
                                                                ],
                                                              ),
                                                              content: Text(
                                                                'Send password reset email to ${u['email']}?',
                                                              ),
                                                              actions: [
                                                                TextButton(
                                                                  onPressed:
                                                                      () =>
                                                                          Navigator.pop(
                                                                            ctx,
                                                                          ),
                                                                  child:
                                                                      const Text(
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
                                                                      if (mounted) {
                                                                        ScaffoldMessenger.of(
                                                                          context,
                                                                        ).showSnackBar(
                                                                          const SnackBar(
                                                                            content: Row(
                                                                              children: [
                                                                                Icon(
                                                                                  Icons.check_circle,
                                                                                  color:
                                                                                      Colors.white,
                                                                                ),
                                                                                SizedBox(
                                                                                  width:
                                                                                      8,
                                                                                ),
                                                                                Text(
                                                                                  'Password reset email sent successfully!',
                                                                                ),
                                                                              ],
                                                                            ),
                                                                            backgroundColor: Color(
                                                                              0xFF2ECC71,
                                                                            ),
                                                                            behavior:
                                                                                SnackBarBehavior.floating,
                                                                          ),
                                                                        );
                                                                      }
                                                                    } catch (
                                                                      e
                                                                    ) {
                                                                      if (mounted) {
                                                                        ScaffoldMessenger.of(
                                                                          context,
                                                                        ).showSnackBar(
                                                                          SnackBar(
                                                                            content: Row(
                                                                              children: [
                                                                                const Icon(
                                                                                  Icons.error,
                                                                                  color:
                                                                                      Colors.white,
                                                                                ),
                                                                                const SizedBox(
                                                                                  width:
                                                                                      8,
                                                                                ),
                                                                                Expanded(
                                                                                  child: Text(
                                                                                    'Error: ${e.toString()}',
                                                                                  ),
                                                                                ),
                                                                              ],
                                                                            ),
                                                                            backgroundColor:
                                                                                Colors.red,
                                                                            behavior:
                                                                                SnackBarBehavior.floating,
                                                                          ),
                                                                        );
                                                                      }
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
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.edit,
                                                                size: 16,
                                                                color: Color(
                                                                  0xFF2ECC71,
                                                                ),
                                                              ),
                                                              SizedBox(
                                                                width: 8,
                                                              ),
                                                              Text('Edit'),
                                                            ],
                                                          ),
                                                        ),
                                                        const PopupMenuItem(
                                                          value:
                                                              'reset_password',
                                                          child: Row(
                                                            children: [
                                                              Icon(
                                                                Icons.email,
                                                                size: 16,
                                                              ),
                                                              SizedBox(
                                                                width: 8,
                                                              ),
                                                              Text(
                                                                'Reset Password',
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
                                                                color:
                                                                    Colors.red,
                                                              ),
                                                              SizedBox(
                                                                width: 8,
                                                              ),
                                                              Text(
                                                                'Delete',
                                                                style: TextStyle(
                                                                  color:
                                                                      Colors
                                                                          .red,
                                                                ),
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
                                onPressed:
                                    _currentPage > 1
                                        ? () => setState(() => _currentPage--)
                                        : null,
                                color:
                                    _currentPage > 1
                                        ? const Color(0xFF666666)
                                        : const Color(0xFFCCCCCC),
                              ),

                              // Page numbers
                              for (int i = 1; i <= _totalPages; i++)
                                if (i == _currentPage ||
                                    i == 1 ||
                                    i == _totalPages ||
                                    (i >= _currentPage - 1 &&
                                        i <= _currentPage + 1))
                                  Container(
                                    margin: const EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
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
                                          () =>
                                              setState(() => _currentPage = i),
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
                                    padding: EdgeInsets.symmetric(
                                      horizontal: 4,
                                    ),
                                    child: Text('...'),
                                  ),

                              // Next button
                              IconButton(
                                icon: const Icon(Icons.chevron_right),
                                onPressed:
                                    _currentPage < _totalPages
                                        ? () => setState(() => _currentPage++)
                                        : null,
                                color:
                                    _currentPage < _totalPages
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
      case 'Teacher':
        return const Color(0xFF1976D2);
      case 'Parent':
        return const Color(0xFF388E3C);
      case 'Guard':
        return const Color(0xFFD32F2F);
      case 'Driver':
        return const Color(0xFFF57C00);
      case 'Admin':
        return const Color(0xFF7B1FA2);
      default:
        return const Color(0xFF616161);
    }
  }

  // Helper method to get role icons
  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'Teacher':
        return Icons.school;
      case 'Parent':
        return Icons.family_restroom;
      case 'Guard':
        return Icons.security;
      case 'Driver':
        return Icons.directions_bus;
      case 'Admin':
        return Icons.admin_panel_settings;
      default:
        return Icons.person;
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
