import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kidsync/widgets/add_edit_parent_modal.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:html' as html;

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

  // Normalize exceptions coming from Supabase Edge Functions / HTTP responses
  Map<String, dynamic> _normalizeFunctionException(dynamic e) {
    int status = 500;
    dynamic data = {'error': e.toString()};

    try {
      final dyn = e as dynamic;

      if (dyn.status != null) status = dyn.status as int;

      if (dyn.details != null) {
        data = dyn.details;
      } else if (dyn.response != null) {
        data = dyn.response;
      } else if (dyn.message != null) {
        data = {'error': dyn.message.toString()};
      }

      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          data = {'error': data};
        }
      }

      if (data is! Map) {
        data = {'error': data.toString()};
      }
    } catch (_) {
      data = {'error': e.toString()};
    }

    return {'status': status, 'data': data};
  }

  Map<String, String?> _extractFieldErrors(dynamic data) {
    final Map<String, String?> errors = {};
    if (data == null) return errors;

    if (data is String) {
      try {
        final parsed = jsonDecode(data);
        return _extractFieldErrors(parsed);
      } catch (_) {
        errors['_general'] = data;
        return errors;
      }
    }

    if (data is Map) {
      if (data['errors'] is Map) {
        (data['errors'] as Map).forEach((k, v) {
          errors[k.toString()] = v?.toString();
        });
        return errors;
      }
      if (data['field_errors'] is Map) {
        (data['field_errors'] as Map).forEach((k, v) {
          errors[k.toString()] = v?.toString();
        });
        return errors;
      }
      if (data['error'] != null) {
        errors['_general'] = data['error'].toString();
        return errors;
      }
      bool looksLikeFields = data.keys.every(
        (k) => k is String && (data[k] is String || data[k] == null),
      );
      if (looksLikeFields) {
        data.forEach((k, v) {
          errors[k.toString()] = v?.toString();
        });
        return errors;
      }
      errors['_general'] = data.toString();
      return errors;
    }

    errors['_general'] = data.toString();
    return errors;
  }

  Future<void> _openAddEditParentModal({Map<String, dynamic>? parent}) async {
    Map<String, String?>? serverErrors;
    Map<String, dynamic>? initialFormData;

    while (true) {
      final result = await showDialog<Map<String, dynamic>>(
        context: context,
        barrierDismissible: false,
        builder:
            (context) => AddEditParentModal(
              parent: parent,
              serverErrors: serverErrors,
              initialFormData: initialFormData,
            ),
      );

      // User cancelled
      if (result == null) break;

      try {
        if (parent == null) {
          // Create new parent
          await _addParent(
            fname: result['fname'],
            mname: result['mname'],
            lname: result['lname'],
            email: result['email'],
            phone: result['phone'],
            address: result['address'],
            studentsToLink: result['studentsToLink'] ?? [],
          );
        } else {
          // Edit existing parent
          await _editParent(
            userId: parent['user_id']?.toString() ?? '',
            parentId: parent['id'] as int,
            fname: result['fname'],
            mname: result['mname'],
            lname: result['lname'],
            email: result['email'],
            phone: result['phone'],
            address: result['address'],
            studentsToLink: result['studentsToLink'] ?? [],
          );
        }
        // Success: exit loop
        break;
      } catch (e) {
        // Normalize and extract field-level errors (uses your existing helper functions)
        final normalized = _normalizeFunctionException(e);
        final errs = _extractFieldErrors(normalized['data']);

        // Heuristic: if general message mentions email already exists, map it to 'email'
        if ((errs['email'] == null || errs['email']!.isEmpty) &&
            errs['_general'] != null &&
            errs['_general']!.toLowerCase().contains('email') &&
            errs['_general']!.toLowerCase().contains('already')) {
          errs['email'] = errs['_general'];
          errs['_general'] = null;
        }

        serverErrors = errs;
        initialFormData = result;
        // loop continues and re-opens modal with serverErrors displayed inline
      }
    }
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
        throw Exception('Email is already used by another user');
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
      } catch (error) {
        print('Error during parent creation: $error');
        // RETHROW instead of showing SnackBar here so caller (caller loop) can show inline errors
        rethrow;
      }
    } catch (error) {
      print('Error during parent creation: $error');
      rethrow;
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
      rethrow;
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

  // Export parents functionality
  Future<void> _exportParents() async {
    try {
      if (parents.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No parents available to export'),
            backgroundColor: Colors.orange,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const AlertDialog(
          content: Row(
            children: [
              CircularProgressIndicator(color: Color(0xFF2ECC71)),
              SizedBox(width: 16),
              Text('Exporting parents...'),
            ],
          ),
        ),
      );

      // Apply current filters to determine which parents to export
      final query = _searchQuery.trim().toLowerCase();
      List<Map<String, dynamic>> parentsToExport = parents.where((parent) {
        final fullName = "${parent['first_name']} ${parent['last_name']}".toLowerCase();
        final matchesName = fullName.contains(query);
        final status = (parent['status']?.toString() ?? '').toLowerCase();
        final matchesStatus = _statusFilter == 'All Status' || status == _statusFilter.toLowerCase();
        return matchesName && matchesStatus;
      }).toList();

      // Sort parents by account creation date (ascending) - this is the primary sort
      parentsToExport.sort((a, b) {
        final aDate = a['created_at'] != null 
            ? DateTime.parse(a['created_at'].toString()) 
            : DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b['created_at'] != null 
            ? DateTime.parse(b['created_at'].toString()) 
            : DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });

      // Create Excel workbook
      var excel = excel_lib.Excel.createExcel();

      // Create main Parents sheet
      var parentsSheet = excel['Parents'];
      await _createParentsSheet(parentsSheet, parentsToExport);

      // Create Summary sheet
      var summarySheet = excel['Summary'];
      await _createParentsSummarySheet(summarySheet, parentsToExport);

      // Clean up: Remove any default sheets
      final defaultSheetNames = ['Sheet1', 'Sheet', 'Worksheet'];
      for (String defaultName in defaultSheetNames) {
        if (excel.sheets.containsKey(defaultName)) {
          excel.delete(defaultName);
        }
      }

      // Set Parents as the default sheet
      excel.setDefaultSheet('Parents');

      // Generate and download file
      List<int>? fileBytes = excel.encode();
      if (fileBytes == null) {
        throw Exception('Failed to generate Excel file');
      }

      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      final fileName = 'Parents_Export_${timestamp}.xlsx';

      // Download file
      final blob = html.Blob([fileBytes], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
      final url = html.Url.createObjectUrlFromBlob(blob);
      final anchor = html.AnchorElement(href: url)
        ..setAttribute('download', fileName)
        ..style.display = 'none';

      html.document.body?.children.add(anchor);
      anchor.click();
      html.document.body?.children.remove(anchor);
      html.Url.revokeObjectUrl(url);

      // Close loading dialog
      if (mounted) Navigator.of(context).pop();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Parents exported successfully: $fileName'),
            backgroundColor: Colors.green,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      // Close loading dialog if still open
      if (mounted) Navigator.of(context).pop();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Export failed: ${e.toString()}'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // Create the main Parents sheet with user data only
  Future<void> _createParentsSheet(
    excel_lib.Sheet sheet,
    List<Map<String, dynamic>> parentsData,
  ) async {
    int rowIndex = 0;

    // Add title
    var titleCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    titleCell.value = excel_lib.TextCellValue('PARENTS DATA EXPORT');
    titleCell.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 18);
    rowIndex += 2;

    // Add export info
    var dateCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    dateCell.value = excel_lib.TextCellValue('Export Date:');
    dateCell.cellStyle = excel_lib.CellStyle(bold: true);
    
    var dateValueCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
    dateValueCell.value = excel_lib.TextCellValue(DateTime.now().toLocal().toString().split('.')[0]);
    rowIndex += 2;

    // Column headers based on users table schema
    final headers = [
      'User ID',
      'First Name',
      'Middle Name', 
      'Last Name',
      'Full Name',
      'Email',
      'Contact Number',
      'Role',
      'Account Status',
      'Account Created',
      'Students Count',
    ];

    // Track maximum width for each column (including headers)
    List<int> columnWidths = List.filled(headers.length, 0);
    
    // Calculate header widths
    for (int col = 0; col < headers.length; col++) {
      columnWidths[col] = headers[col].length;
    }

    // Calculate maximum content width for each column
    for (int i = 0; i < parentsData.length; i++) {
      final parent = parentsData[i];
      
      // Generate user ID (Parent prefix + index)
      final parentIndex = i + 1;
      final userId = "PAR${parentIndex.toString().padLeft(3, '0')}";
      
      final fullName = "${parent['first_name'] ?? ''} ${parent['middle_name'] ?? ''} ${parent['last_name'] ?? ''}".trim().replaceAll(RegExp(r'\s+'), ' ');
      final formattedCreatedAt = parent['created_at'] != null
          ? DateTime.parse(parent['created_at'].toString()).toLocal().toString().split('.')[0]
          : '';

      final rowData = [
        userId,
        parent['first_name'] ?? '',
        parent['middle_name'] ?? '',
        parent['last_name'] ?? '',
        fullName,
        parent['email'] ?? '',
        parent['phone'] ?? '',
        parent['role'] ?? 'Parent',
        parent['status'] ?? 'active',
        formattedCreatedAt,
        (parent['student_count'] ?? 0).toString(),
      ];

      // Update column widths based on content
      for (int col = 0; col < rowData.length; col++) {
        final contentLength = rowData[col].length;
        if (contentLength > columnWidths[col]) {
          columnWidths[col] = contentLength;
        }
      }
    }

    // Set column widths with some padding (add 2 characters for padding)
    for (int col = 0; col < columnWidths.length; col++) {
      final width = (columnWidths[col] + 2).clamp(8, 50); // Min 8, Max 50 characters
      sheet.setColumnWidth(col, width.toDouble());
    }

    // Add column headers
    for (int col = 0; col < headers.length; col++) {
      var headerCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
      headerCell.value = excel_lib.TextCellValue(headers[col]);
      headerCell.cellStyle = excel_lib.CellStyle(
        bold: true,
        leftBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        topBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
      );
    }
    rowIndex++;

    // Add parent data rows
    for (int i = 0; i < parentsData.length; i++) {
      final parent = parentsData[i];
      
      // Generate user ID (Parent prefix + index)
      final parentIndex = i + 1;
      final userId = "PAR${parentIndex.toString().padLeft(3, '0')}";
      
      final fullName = "${parent['first_name'] ?? ''} ${parent['middle_name'] ?? ''} ${parent['last_name'] ?? ''}".trim().replaceAll(RegExp(r'\s+'), ' ');
      final formattedCreatedAt = parent['created_at'] != null
          ? DateTime.parse(parent['created_at'].toString()).toLocal().toString().split('.')[0]
          : '';

      final rowData = [
        userId,
        parent['first_name'] ?? '',
        parent['middle_name'] ?? '',
        parent['last_name'] ?? '',
        fullName,
        parent['email'] ?? '',
        parent['phone'] ?? '',
        parent['role'] ?? 'Parent',
        parent['status'] ?? 'active',
        formattedCreatedAt,
        (parent['student_count'] ?? 0).toString(),
      ];

      for (int col = 0; col < rowData.length; col++) {
        var cell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
        cell.value = excel_lib.TextCellValue(rowData[col]);
        cell.cellStyle = excel_lib.CellStyle(
          leftBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          topBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        );
      }
      rowIndex++;
    }
  }

  // Create the Summary sheet
  Future<void> _createParentsSummarySheet(
    excel_lib.Sheet sheet,
    List<Map<String, dynamic>> parentsData,
  ) async {
    int rowIndex = 0;
    // Track all column widths for auto-adjustment
    List<int> columnWidths = List.filled(3, 10); // For 3 columns

    // Get current user info
    final user = supabase.auth.currentUser;
    final userName =
        user?.userMetadata?['fname'] != null &&
                user?.userMetadata?['lname'] != null
        ? '${user?.userMetadata?['fname']} ${user?.userMetadata?['lname']}'
        : user?.email ?? 'Unknown User';

    // Add title
    var titleCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    titleCell.value = excel_lib.TextCellValue('PARENTS SUMMARY REPORT');
    titleCell.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 18);
    // Update column width for title
    if ('PARENTS SUMMARY REPORT'.length > columnWidths[0]) {
      columnWidths[0] = 'PARENTS SUMMARY REPORT'.length;
    }
    rowIndex += 2;

    // Add export info
    var dateCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    dateCell.value = excel_lib.TextCellValue('Export Date:');
    dateCell.cellStyle = excel_lib.CellStyle(bold: true);
    
    var dateValueCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
    dateValueCell.value = excel_lib.TextCellValue(DateTime.now().toLocal().toString().split('.')[0]);
    rowIndex += 2;

    var generatedByCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    generatedByCell.value = excel_lib.TextCellValue('Generated By:');
    generatedByCell.cellStyle = excel_lib.CellStyle(bold: true);
    
    var generatedByValueCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
    generatedByValueCell.value = excel_lib.TextCellValue(userName);
    rowIndex += 2;

    // Update column widths for export info
    if ('Export Date:'.length > columnWidths[0]) columnWidths[0] = 'Export Date:'.length;
    if ('Generated By:'.length > columnWidths[0]) columnWidths[0] = 'Generated By:'.length;
    if (DateTime.now().toLocal().toString().split('.')[0].length > columnWidths[1]) {
      columnWidths[1] = DateTime.now().toLocal().toString().split('.')[0].length;
    }
    if (userName.length > columnWidths[1]) columnWidths[1] = userName.length;

    // Calculate statistics
    final totalParents = parentsData.length;
    final activeParents = parentsData.where((p) => p['status'] == 'active').length;
    final inactiveParents = parentsData.where((p) => p['status'] == 'inactive').length;
    final totalStudentsAssigned = parentsData.fold<int>(
      0, (sum, parent) => sum + (parent['student_count'] as int? ?? 0),
    );
    final averageStudentsPerParent = totalParents > 0 ? (totalStudentsAssigned / totalParents).toStringAsFixed(1) : '0';

    // Statistics section
    final stats = [
      ['Total Parents:', totalParents.toString()],
      ['Active Parents:', activeParents.toString()],
      ['Inactive Parents:', inactiveParents.toString()],
      ['Total Students Assigned:', totalStudentsAssigned.toString()],
      ['Average Students per Parent:', averageStudentsPerParent],
    ];

    // Update column widths for statistics and add data
    for (final stat in stats) {
      if (stat[0].length > columnWidths[0]) {
        columnWidths[0] = stat[0].length;
      }
      if (stat[1].length > columnWidths[1]) {
        columnWidths[1] = stat[1].length;
      }

      var labelCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
      labelCell.value = excel_lib.TextCellValue(stat[0]);
      labelCell.cellStyle = excel_lib.CellStyle(bold: true);
      
      var valueCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      valueCell.value = excel_lib.TextCellValue(stat[1]);
      
      rowIndex++;
    }

    rowIndex += 2;

    // Status breakdown table
    var statusHeaderCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    statusHeaderCell.value = excel_lib.TextCellValue('STATUS BREAKDOWN');
    statusHeaderCell.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 14);
    rowIndex += 2;

    // Status table headers
    final statusHeaders = ['Status', 'Count', 'Percentage'];
    
    // Status data for width calculation
    final statusBreakdown = [      
      ['Active', activeParents.toString(), totalParents > 0 ? '${((activeParents / totalParents) * 100).toStringAsFixed(1)}%' : '0%'],
      ['Inactive', inactiveParents.toString(), totalParents > 0 ? '${((inactiveParents / totalParents) * 100).toStringAsFixed(1)}%' : '0%'],
    ];

    // Update column widths for status table headers
    for (int col = 0; col < statusHeaders.length; col++) {
      if (statusHeaders[col].length > columnWidths[col]) {
        columnWidths[col] = statusHeaders[col].length;
      }
    }
    
    // Update column widths for status table data
    for (final statusRow in statusBreakdown) {
      for (int col = 0; col < statusRow.length; col++) {
        if (statusRow[col].length > columnWidths[col]) {
          columnWidths[col] = statusRow[col].length;
        }
      }
    }

    // Status table headers
    for (int col = 0; col < statusHeaders.length; col++) {
      var headerCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
      headerCell.value = excel_lib.TextCellValue(statusHeaders[col]);
      headerCell.cellStyle = excel_lib.CellStyle(
        bold: true,
        leftBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        topBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
      );
    }
    rowIndex++;

    // Status data rows
    for (final statusRow in statusBreakdown) {
      for (int col = 0; col < statusRow.length; col++) {
        var cell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
        cell.value = excel_lib.TextCellValue(statusRow[col]);
        cell.cellStyle = excel_lib.CellStyle(
          leftBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          topBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        );
      }
      rowIndex++;
    }

    // Apply auto-adjusted column widths with padding and constraints at the end
    for (int col = 0; col < columnWidths.length; col++) {
      final width = (columnWidths[col] + 2).clamp(8, 50).toDouble();
      sheet.setColumnWidth(col, width);
    }
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
                // Standardized Header
                Row(
                  children: [
                    const Text(
                      "Parent/Guardian",
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A1A),
                        letterSpacing: 0.5,
                      ),
                    ),
                    const Spacer(),
                    // Standardized Search bar
                    Container(
                      width: 260,
                      height: 44,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: const Color(0xFFE0E0E0)),
                        borderRadius: BorderRadius.circular(8),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: TextField(
                        decoration: const InputDecoration(
                          hintText: 'Search parents...',
                          hintStyle: TextStyle(
                            fontSize: 14,
                            color: Color(0xFF9E9E9E),
                          ),
                          prefixIcon: Icon(
                            Icons.search,
                            color: Color(0xFF2ECC71),
                            size: 20,
                          ),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            vertical: 12.0,
                            horizontal: 16.0,
                          ),
                        ),
                        onChanged: (val) => setState(() => _searchQuery = val),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Standardized Add New button
                    SizedBox(
                      height: 44,
                      child: ElevatedButton.icon(
                        icon: const Icon(
                          Icons.add,
                          color: Colors.white,
                          size: 18,
                        ),
                        label: const Text(
                          "Add New Parent",
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
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
                          shadowColor: Colors.black.withOpacity(0.1),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onPressed: () async {
                          await _openAddEditParentModal();
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Standardized Export button
                    SizedBox(
                      height: 44,
                      child: OutlinedButton.icon(
                        icon: const Icon(
                          Icons.file_download_outlined,
                          color: Color(0xFF2ECC71),
                          size: 18,
                        ),
                        label: const Text(
                          "Export",
                          style: TextStyle(
                            color: Color(0xFF2ECC71),
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          backgroundColor: Colors.white,
                          side: const BorderSide(
                            color: Color(0xFF2ECC71),
                            width: 1.5,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 1,
                          shadowColor: Colors.black.withOpacity(0.05),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 10,
                          ),
                        ),
                        onPressed: () async {
                          await _exportParents();
                        },
                      ),
                    ),
                  ],
                ),

                // Standardized Breadcrumb
                const Padding(
                  padding: EdgeInsets.only(top: 8.0, bottom: 24.0),
                  child: Text(
                    "Home / Parent/Guardian",
                    style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
                  ),
                ),

                // Filter row
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.grey[200]!),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    children: [
                      // Status filter dropdown
                      Container(
                        height: 42,
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE0E0E0)),
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
                        padding: const EdgeInsets.symmetric(horizontal: 16.0),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          border: Border.all(color: const Color(0xFFE0E0E0)),
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

                              if (constraints.maxWidth > 1600) {
                                crossAxisCount = 5;
                                childAspectRatio = 0.85;
                              } else if (constraints.maxWidth > 1200) {
                                crossAxisCount = 4;
                                childAspectRatio = 0.9;
                              } else if (constraints.maxWidth > 900) {
                                crossAxisCount = 3;
                                childAspectRatio = 0.95;
                              } else if (constraints.maxWidth > 600) {
                                crossAxisCount = 2;
                                childAspectRatio = 1.0;
                              } else {
                                crossAxisCount = 1;
                                childAspectRatio = 1.1;
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
                              await _openAddEditParentModal(parent: parent);
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