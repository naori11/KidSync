import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kidsync/widgets/role_protection.dart';
import 'package:kidsync/services/audit_log_service.dart';
import 'package:image_picker/image_picker.dart';
import 'package:excel/excel.dart' as excel_lib;
import 'dart:html' as html;
import 'dart:convert';

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
  final auditLogService = AuditLogService();
  List<Map<String, dynamic>> users = [];
  bool isLoading = false;
  String _searchQuery = '';
  String _roleFilter = 'All Roles';
  String _sortOption = 'Name (A-Z)';

  // For pagination
  int _currentPage = 1;
  int _itemsPerPage = 5;
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

  // Export users functionality
  Future<void> _exportUsers() async {
    try {
      if (users.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No users available to export'),
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
              Text('Exporting users...'),
            ],
          ),
        ),
      );

      // Apply current filters to determine which users to export
      final query = _searchQuery.trim().toLowerCase();
      List<Map<String, dynamic>> usersToExport = users.where((u) {
        final roleMatch = _roleFilter == 'All Roles' || u['role'] == _roleFilter;
        if (!roleMatch) return false;

        if (query.isEmpty) return true;
        final name = "${u['fname'] ?? ''} ${u['lname'] ?? ''}".toLowerCase();
        final email = (u['email'] ?? '').toString().toLowerCase();
        return name.contains(query) || email.contains(query);
      }).toList();

      // Sort users based on current sort option
      if (_sortOption == 'Name (A-Z)') {
        usersToExport.sort(
          (a, b) => "${a['fname'] ?? ''} ${a['lname'] ?? ''}".compareTo(
            "${b['fname'] ?? ''} ${b['lname'] ?? ''}",
          ),
        );
      } else if (_sortOption == 'Name (Z-A)') {
        usersToExport.sort(
          (a, b) => "${b['fname'] ?? ''} ${b['lname'] ?? ''}".compareTo(
            "${a['fname'] ?? ''} ${a['lname'] ?? ''}",
          ),
        );
      } else if (_sortOption == 'Role') {
        usersToExport.sort(
          (a, b) => (a['role'] ?? '').compareTo(b['role'] ?? ''),
        );
      }

      // Create Excel workbook
      var excel = excel_lib.Excel.createExcel();

      // Create main Users sheet
      var usersSheet = excel['Users'];
      await _createUsersSheet(usersSheet, usersToExport);

      // Create Summary sheet
      var summarySheet = excel['Summary'];
      await _createUsersSummarySheet(summarySheet, usersToExport);

      // Clean up: Remove any default sheets
      final defaultSheetNames = ['Sheet1', 'Sheet', 'Worksheet'];
      for (String defaultName in defaultSheetNames) {
        if (excel.sheets.containsKey(defaultName)) {
          excel.delete(defaultName);
        }
      }

      // Set Users as the default sheet
      excel.setDefaultSheet('Users');

      // Generate and download file
      List<int>? fileBytes = excel.encode();
      if (fileBytes == null) {
        throw Exception('Failed to generate Excel file');
      }

      final timestamp = DateTime.now().toIso8601String().split('T')[0];
      final fileName = 'Users_Export_${timestamp}.xlsx';

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

      // Log audit event for export
      try {
        await auditLogService.logExportOperation(
          exportType: 'Users',
          fileName: fileName,
          recordCount: usersToExport.length,
          filters: _roleFilter != 'All Roles' || _searchQuery.isNotEmpty ? '$_roleFilter, $_searchQuery' : 'No filters',
        );
      } catch (auditError) {
        print('Failed to log audit event: $auditError');
      }

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Users exported successfully: $fileName'),
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

  // Create the main Users sheet
  Future<void> _createUsersSheet(
    excel_lib.Sheet sheet,
    List<Map<String, dynamic>> usersData,
  ) async {
    int rowIndex = 0;

    // Add title
    var titleCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    titleCell.value = excel_lib.TextCellValue('USERS DATA EXPORT');
    titleCell.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 18);
    rowIndex += 2;

    // Add export info
    var dateCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    dateCell.value = excel_lib.TextCellValue('Export Date:');
    dateCell.cellStyle = excel_lib.CellStyle(bold: true);
    
    var dateValueCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
    dateValueCell.value = excel_lib.TextCellValue(DateTime.now().toLocal().toString().split('.')[0]);
    rowIndex += 2;

    // Column headers
    final headers = [
      'User ID',
      'First Name',
      'Middle Name', 
      'Last Name',
      'Suffix',
      'Full Name',
      'Email',
      'Contact Number',
      'Position/Title',
      'Status',
      'Account Created',
    ];

    // Role order as specified
    final roleOrder = ['Admin', 'Teacher', 'Guard', 'Driver', 'Parent'];

    // Group users by role and sort each group by account creation date
    Map<String, List<Map<String, dynamic>>> usersByRole = {};
    for (final role in roleOrder) {
      usersByRole[role] = [];
    }

    // Add users to their respective role groups
    for (final user in usersData) {
      final role = user['role']?.toString() ?? 'Unknown';
      if (usersByRole.containsKey(role)) {
        usersByRole[role]!.add(user);
      } else {
        // Handle unknown roles by adding them to a separate list
        usersByRole.putIfAbsent('Other', () => []).add(user);
      }
    }

    // Sort each role group by account creation date (ascending)
    for (final role in usersByRole.keys) {
      usersByRole[role]!.sort((a, b) {
        final aDate = a['created_at'] != null 
            ? DateTime.parse(a['created_at'].toString()) 
            : DateTime.fromMillisecondsSinceEpoch(0);
        final bDate = b['created_at'] != null 
            ? DateTime.parse(b['created_at'].toString()) 
            : DateTime.fromMillisecondsSinceEpoch(0);
        return aDate.compareTo(bDate);
      });
    }

    // Create tables for each role
    for (final role in roleOrder) {
      if (usersByRole[role]!.isEmpty) continue;

      // Role header - just one cell, no merging
      var roleHeaderCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
      roleHeaderCell.value = excel_lib.TextCellValue(role);
      roleHeaderCell.cellStyle = excel_lib.CellStyle(
        bold: true,
        fontSize: 16,
      );
      rowIndex++;

      // Column headers for this role
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

      // Add user data for this role
      for (int i = 0; i < usersByRole[role]!.length; i++) {
        final user = usersByRole[role]![i];
        final userRole = user['role'] ?? '';
        final userPrefix = _getUserIdPrefix(userRole);
        final userIndex = users.indexWhere((item) => item['id'] == user['id']) + 1;
        final userId = "$userPrefix${userIndex.toString().padLeft(3, '0')}";
        
        final fullName = "${user['fname'] ?? ''} ${user['mname'] ?? ''} ${user['lname'] ?? ''} ${user['suffix'] ?? ''}".trim().replaceAll(RegExp(r'\s+'), ' ');
        final formattedCreatedAt = user['created_at'] != null
            ? DateTime.parse(user['created_at'].toString()).toLocal().toString().split('.')[0]
            : '';

        // Get actual status (default to 'Active' since schema doesn't have status field for users)
        final status = user['status']?.toString() ?? 'Active';

        final rowData = [
          userId,
          user['fname']?.toString() ?? '',
          user['mname']?.toString() ?? '',
          user['lname']?.toString() ?? '',
          user['suffix']?.toString() ?? '',
          fullName,
          user['email']?.toString() ?? '',
          user['contact_number']?.toString() ?? '',
          user['position']?.toString() ?? '',
          status,
          formattedCreatedAt,
        ];

        for (int col = 0; col < rowData.length; col++) {
          var dataCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
          dataCell.value = excel_lib.TextCellValue(rowData[col]);
          dataCell.cellStyle = excel_lib.CellStyle(
            leftBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
            rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
            bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          );
        }
        rowIndex++;
      }

      // Add total row for this role
      var totalLabelCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
      totalLabelCell.value = excel_lib.TextCellValue('TOTAL:');
      totalLabelCell.cellStyle = excel_lib.CellStyle(
        bold: true,
      );

      var totalCountCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      totalCountCell.value = excel_lib.TextCellValue('${usersByRole[role]!.length} users');
      totalCountCell.cellStyle = excel_lib.CellStyle(
        bold: true,
        leftBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        topBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
      );

      rowIndex++;

      // Add spacing between role tables
      rowIndex += 2;
    }

    // Handle any users with unknown roles
    if (usersByRole.containsKey('Other') && usersByRole['Other']!.isNotEmpty) {
      // Other roles header - just one cell, no merging
      var otherHeaderCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
      otherHeaderCell.value = excel_lib.TextCellValue('Other Roles');
      otherHeaderCell.cellStyle = excel_lib.CellStyle(
        bold: true,
        fontSize: 16,
      );
      rowIndex++;

      // Column headers for other roles
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

      // Add other role users
      for (final user in usersByRole['Other']!) {
        final userRole = user['role'] ?? '';
        final userPrefix = _getUserIdPrefix(userRole);
        final userIndex = users.indexWhere((item) => item['id'] == user['id']) + 1;
        final userId = "$userPrefix${userIndex.toString().padLeft(3, '0')}";
        
        final fullName = "${user['fname'] ?? ''} ${user['mname'] ?? ''} ${user['lname'] ?? ''} ${user['suffix'] ?? ''}".trim().replaceAll(RegExp(r'\s+'), ' ');
        final formattedCreatedAt = user['created_at'] != null
            ? DateTime.parse(user['created_at'].toString()).toLocal().toString().split('.')[0]
            : '';

        final status = user['status']?.toString() ?? 'Active';

        final rowData = [
          userId,
          user['fname']?.toString() ?? '',
          user['mname']?.toString() ?? '',
          user['lname']?.toString() ?? '',
          user['suffix']?.toString() ?? '',
          fullName,
          user['email']?.toString() ?? '',
          user['contact_number']?.toString() ?? '',
          user['position']?.toString() ?? '',
          status,
          formattedCreatedAt,
        ];

        for (int col = 0; col < rowData.length; col++) {
          var dataCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: col, rowIndex: rowIndex));
          dataCell.value = excel_lib.TextCellValue(rowData[col]);
          dataCell.cellStyle = excel_lib.CellStyle(
            leftBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
            rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
            bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
          );
        }
        rowIndex++;
      }

      // Add total row for other roles
      var totalLabelCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
      totalLabelCell.value = excel_lib.TextCellValue('TOTAL:');
      totalLabelCell.cellStyle = excel_lib.CellStyle(
        bold: true,
      );

      var totalCountCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      totalCountCell.value = excel_lib.TextCellValue('${usersByRole['Other']!.length} users');
      totalCountCell.cellStyle = excel_lib.CellStyle(
        bold: true,
        leftBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        topBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        rightBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
        bottomBorder: excel_lib.Border(borderStyle: excel_lib.BorderStyle.Thin),
      );
    }

    // Set column widths for better readability
    sheet.setColumnWidth(0, 12.0);  // User ID
    sheet.setColumnWidth(1, 15.0);  // First Name
    sheet.setColumnWidth(2, 15.0);  // Middle Name
    sheet.setColumnWidth(3, 15.0);  // Last Name
    sheet.setColumnWidth(4, 10.0);  // Suffix
    sheet.setColumnWidth(5, 25.0);  // Full Name
    sheet.setColumnWidth(6, 30.0);  // Email
    sheet.setColumnWidth(7, 15.0);  // Contact Number
    sheet.setColumnWidth(8, 20.0);  // Position
    sheet.setColumnWidth(9, 10.0);  // Status
    sheet.setColumnWidth(10, 20.0); // Account Created
  }

  // Create the Summary sheet
  Future<void> _createUsersSummarySheet(
    excel_lib.Sheet sheet,
    List<Map<String, dynamic>> usersData,
  ) async {
    int rowIndex = 0;

    // Get current user info
    final user = supabase.auth.currentUser;
    final userName = user?.userMetadata?['fname'] != null && user?.userMetadata?['lname'] != null
        ? '${user?.userMetadata?['fname']} ${user?.userMetadata?['lname']}'
        : user?.email ?? 'Unknown User';

    // Title
    var titleCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    titleCell.value = excel_lib.TextCellValue('USERS EXPORT SUMMARY');
    titleCell.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 18);
    rowIndex += 2;

    // Generation info
    var dateCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    dateCell.value = excel_lib.TextCellValue('Export Date & Time:');
    dateCell.cellStyle = excel_lib.CellStyle(bold: true);
    
    var dateValueCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
    dateValueCell.value = excel_lib.TextCellValue(DateTime.now().toLocal().toString().split('.')[0]);
    rowIndex++;

    var generatedByCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    generatedByCell.value = excel_lib.TextCellValue('Generated By:');
    generatedByCell.cellStyle = excel_lib.CellStyle(bold: true);
    
    var generatedByValueCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
    generatedByValueCell.value = excel_lib.TextCellValue(userName);
    rowIndex += 2;

    // Overall statistics
    var statsHeaderCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    statsHeaderCell.value = excel_lib.TextCellValue('OVERALL STATISTICS');
    statsHeaderCell.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 16);
    rowIndex += 2;

    // Calculate statistics
    final totalUsers = usersData.length;
    final activeUsers = usersData.where((u) => (u['status'] ?? 'Active') == 'Active').length;
    final inactiveUsers = totalUsers - activeUsers;

    // Role statistics
    Map<String, int> roleStats = {};
    for (final userData in usersData) {
      final role = userData['role']?.toString() ?? 'Unknown';
      roleStats[role] = (roleStats[role] ?? 0) + 1;
    }

    // Display overall stats
    final overallStats = [
      ['Total Users:', totalUsers.toString()],
      ['Active Users:', activeUsers.toString()],
      ['Inactive Users:', inactiveUsers.toString()],
    ];

    for (var stat in overallStats) {
      var labelCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
      labelCell.value = excel_lib.TextCellValue(stat[0]);
      labelCell.cellStyle = excel_lib.CellStyle(bold: true);

      var valueCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      valueCell.value = excel_lib.TextCellValue(stat[1]);

      rowIndex++;
    }

    rowIndex += 2;

    // Role breakdown
    var roleBreakdownHeader = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
    roleBreakdownHeader.value = excel_lib.TextCellValue('USERS BY ROLE');
    roleBreakdownHeader.cellStyle = excel_lib.CellStyle(bold: true, fontSize: 14);
    rowIndex++;

    // Sort role stats by role importance
    final roleOrder = ['Admin', 'Teacher', 'Guard', 'Driver', 'Parent'];
    final sortedRoleEntries = roleStats.entries.toList();
    sortedRoleEntries.sort((a, b) {
      final aIndex = roleOrder.indexOf(a.key);
      final bIndex = roleOrder.indexOf(b.key);
      if (aIndex == -1 && bIndex == -1) return a.key.compareTo(b.key);
      if (aIndex == -1) return 1;
      if (bIndex == -1) return -1;
      return aIndex.compareTo(bIndex);
    });

    for (var entry in sortedRoleEntries) {
      var roleCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 0, rowIndex: rowIndex));
      roleCell.value = excel_lib.TextCellValue('${entry.key}:');
      roleCell.cellStyle = excel_lib.CellStyle(bold: true);

      var countCell = sheet.cell(excel_lib.CellIndex.indexByColumnRow(columnIndex: 1, rowIndex: rowIndex));
      countCell.value = excel_lib.TextCellValue(entry.value.toString());

      rowIndex++;
    }
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

  Future<Map<String, dynamic>> createUserViaEdgeFunction({
    required String email,
    required String role,
    required String fname,
    String? mname,
    required String lname,
    String? suffix,
    String? contactNumber,
    String? position,
    String? profileImageUrl,
  }) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'create_user',
        body: {
          'email': email,
          'role': role,
          'fname': fname,
          'mname': mname,
          'lname': lname,
          'suffix': suffix,
          'contact_number': contactNumber,
          'position': position,
          'profile_image_url': profileImageUrl,
        },
      );

      final int status = res.status;
      dynamic data = res.data ?? res;

      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }

      return {'status': status, 'data': data};
    } catch (e) {
      return _normalizeFunctionException(e);
    }
  }

  Future<Map<String, dynamic>> editUserViaEdgeFunction({
    required String id,
    required String email,
    required String role,
    required String fname,
    String? mname,
    required String lname,
    String? suffix,
    String? contactNumber,
    String? position,
    String? profileImageUrl,
  }) async {
    try {
      final res = await Supabase.instance.client.functions.invoke(
        'edit_user',
        body: {
          'id': id,
          'email': email,
          'role': role,
          'fname': fname,
          'mname': mname,
          'lname': lname,
          'suffix': suffix,
          'contact_number': contactNumber,
          'position': position,
          'profile_image_url': profileImageUrl,
        },
      );

      final int status = res.status;
      dynamic data = res.data ?? res;

      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {}
      }
      return {'status': status, 'data': data};
    } catch (e) {
      return _normalizeFunctionException(e);
    }
  }

  // Helper: normalize FunctionException / thrown errors into {status, data}
  Map<String, dynamic> _normalizeFunctionException(dynamic e) {
    int status = 500;
    dynamic data = {'error': e.toString()};

    try {
      final dyn = e as dynamic;

      // FunctionException often exposes .status and .details or .response
      if (dyn.status != null) status = dyn.status as int;

      if (dyn.details != null) {
        data = dyn.details;
      } else if (dyn.response != null) {
        data = dyn.response;
      } else if (dyn.message != null) {
        data = {'error': dyn.message.toString()};
      }

      // If details/response is a JSON string, decode it
      if (data is String) {
        try {
          data = jsonDecode(data);
        } catch (_) {
          data = {'error': data};
        }
      }

      // Ensure final shape is a Map so _extractFieldErrors can parse it
      if (data is! Map) {
        data = {'error': data.toString()};
      }
    } catch (_) {
      data = {'error': e.toString()};
    }

    return {'status': status, 'data': data};
  }

  Future<void> deleteUserViaEdgeFunction(String id) async {
    try {
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
    } catch (e) {
      // Try to surface a clearer message when invoke throws
      dynamic data = e.toString();
      try {
        final dyn = e as dynamic;
        if (dyn.details != null) data = dyn.details;
        if (dyn.response != null) data = dyn.response;
      } catch (_) {}
      final message =
          (data is Map && data['error'] != null)
              ? data['error'].toString()
              : data.toString();
      throw Exception(message);
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
    final suffixController = TextEditingController(
      text: user?['suffix']?.toString() ?? '',
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
    final roleOptionsBase = ['Guard', 'Teacher', 'Driver', 'Admin'];

    // Build DropdownMenuItem list; insert a disabled 'Parent' item when editing a Parent
    List<DropdownMenuItem<String>> roleItems =
        roleOptionsBase.map((role) {
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
        }).toList();

    // If editing a Parent, include a non-selectable Parent item so the dropdown can show it
    if (selectedRole == 'Parent') {
      roleItems.insert(
        0,
        DropdownMenuItem<String>(
          value: 'Parent',
          enabled: false,
          child: Row(
            children: [
              Icon(Icons.family_restroom, size: 16, color: Colors.grey[600]),
              const SizedBox(width: 8),
              const Text('Parent (manage via Parents page)'),
            ],
          ),
        ),
      );
    }

    print('Debug: selectedRole: $selectedRole'); // Debug print

    // FIELD-LEVEL ERROR MAP used by validators and dialog UI
    Map<String, String?> fieldErrors = {};

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              backgroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 20,
              shadowColor: Colors.black.withOpacity(0.2),
              title: Row(
                children: [
                  Icon(
                    user == null ? Icons.person_add : Icons.edit,
                    color: const Color(0xFF2ECC71),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Text(
                    user == null ? 'Add New User' : 'Edit User',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF1A1A1A),
                      letterSpacing: 0.5,
                    ),
                  ),
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
                        // Show general/server error at top of modal (if any)
                        if (fieldErrors['_general'] != null) ...[
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
                                const Icon(
                                  Icons.error,
                                  color: Colors.red,
                                  size: 16,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    fieldErrors['_general']!,
                                    style: const TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],

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
                                  // server-provided field error takes precedence
                                  if (fieldErrors['fname'] != null) {
                                    return fieldErrors['fname'];
                                  }
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
                                decoration: _buildCompactInputDecoration(
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
                                  if (fieldErrors['lname'] != null)
                                    return fieldErrors['lname'];
                                  if (value?.trim().isEmpty ?? true) {
                                    return 'Last name is required';
                                  }
                                  return null;
                                },
                                textCapitalization: TextCapitalization.words,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: suffixController,
                                decoration: _buildCompactInputDecoration(
                                  'Suffix',
                                  Icons.person_2,
                                ),
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
                            if (fieldErrors['email'] != null)
                              return fieldErrors['email'];
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
                                  FilteringTextInputFormatter.digitsOnly,
                                  LengthLimitingTextInputFormatter(11),
                                ],
                                validator: (value) {
                                  if (fieldErrors['contact_number'] != null)
                                    return fieldErrors['contact_number'];
                                  if (value == null || value.trim().isEmpty) {
                                    return null; // optional
                                  }
                                  final v = value.trim();
                                  if (!RegExp(r'^0\d{10}$').hasMatch(v)) {
                                    return 'Contact must be 11 digits and start with 0';
                                  }
                                  return null;
                                },
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
                                validator: (value) {
                                  if (fieldErrors['position'] != null)
                                    return fieldErrors['position'];
                                  return null;
                                },
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
                                value: selectedRole,
                                items: roleItems,
                                // Disable role changes when editing a user whose role is "Parent"
                                // (keeps the dropdown visible but non-interactive for Parent).
                                onChanged:
                                    (selectedRole == 'Parent')
                                        ? null
                                        : (value) {
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
                                  icon: const Icon(Icons.upload, size: 20),
                                  label: const Text(
                                    'Upload Photo',
                                    style: TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2ECC71),
                                    foregroundColor: Colors.white,
                                    elevation: 4,
                                    shadowColor: const Color(
                                      0xFF2ECC71,
                                    ).withOpacity(0.3),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 20,
                                      vertical: 14,
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
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                  ),
                  child: const Text(
                    'Cancel',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF666666),
                    ),
                  ),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: const Color(0xFF2ECC71).withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 28,
                      vertical: 14,
                    ),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        String? imageUrl =
                            _currentImageUrl ?? user?['profile_image_url'];
                        
                        // helper to set field errors and refresh validators in dialog
                        void _setFieldErrors(Map<String, String?> errs) {
                          setDialogState(() {
                            fieldErrors = errs;
                          });
                          // trigger validators to show errors
                          formKey.currentState!.validate();
                        }

                        // Handle image upload + create/update flows
                        if (_selectedImagePath != null &&
                            _selectedImageBytes != null) {
                          if (user == null) {
                            // Create user first (no image)
                            final createRes = await createUserViaEdgeFunction(
                              email: emailController.text.trim(),
                              role: selectedRole!,
                              fname: fnameController.text.trim(),
                              mname:
                                  mnameController.text.trim().isEmpty
                                      ? null
                                      : mnameController.text.trim(),
                              lname: lnameController.text.trim(),
                              suffix:
                                  suffixController.text.trim().isEmpty
                                      ? null
                                      : suffixController.text.trim(),
                              contactNumber:
                                  contactController.text.trim().isEmpty
                                      ? null
                                      : contactController.text.trim(),
                              position:
                                  positionController.text.trim().isEmpty
                                      ? null
                                      : positionController.text.trim(),
                              profileImageUrl: null,
                            );

                            if (createRes['status'] != 200) {
                              final errs = _extractFieldErrors(
                                createRes['data'],
                              );
                              _setFieldErrors(errs);
                              return; // keep dialog open for correction
                            }

                            // fetch created user id
                            final createdUser =
                                await supabase
                                    .from('users')
                                    .select('id')
                                    .eq('email', emailController.text.trim())
                                    .single();
                            final XFile imageFile = XFile.fromData(
                              _selectedImageBytes!,
                              name: _selectedImagePath!,
                            );
                            final uploadedUrl = await _uploadImageToSupabase(
                              imageFile,
                              createdUser['id'].toString(),
                            );

                            if (uploadedUrl != null) {
                              await supabase
                                  .from('users')
                                  .update({'profile_image_url': uploadedUrl})
                                  .eq('id', createdUser['id']);
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
                            // existing user: upload image then edit
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
                              if (user['profile_image_url'] != null &&
                                  user['profile_image_url']
                                      .toString()
                                      .isNotEmpty) {
                                await _deleteImageFromSupabase(
                                  user['profile_image_url'],
                                );
                              }
                            }

                            final editRes = await editUserViaEdgeFunction(
                              id: user['id'].toString(),
                              email: emailController.text.trim(),
                              role: selectedRole!,
                              fname: fnameController.text.trim(),
                              mname:
                                  mnameController.text.trim().isEmpty
                                      ? null
                                      : mnameController.text.trim(),
                              lname: lnameController.text.trim(),
                              suffix:
                                  suffixController.text.trim().isEmpty
                                      ? null
                                      : suffixController.text.trim(),
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

                            if (editRes['status'] != 200) {
                              final errs = _extractFieldErrors(editRes['data']);
                              _setFieldErrors(errs);
                              return;
                            }

                            // Log user update immediately after successful edit (with image path)
                            try {
                              final userName = '${fnameController.text.trim()} ${lnameController.text.trim()}';
                              await auditLogService.logUserManagement(
                                action: 'update',
                                targetUserId: user['id'].toString(),
                                targetUserName: userName,
                                role: selectedRole,
                                oldValues: {
                                  'email': user['email'],
                                  'fname': user['fname'],
                                  'lname': user['lname'],
                                  'mname': user['mname'],
                                  'role': user['role'],
                                  'position': user['position'],
                                  'contact_number': user['contact_number'],
                                  'profile_image_url': user['profile_image_url'],
                                },
                                newValues: {
                                  'email': emailController.text.trim(),
                                  'fname': fnameController.text.trim(),
                                  'lname': lnameController.text.trim(),
                                  'mname': mnameController.text.trim().isEmpty ? null : mnameController.text.trim(),
                                  'role': selectedRole,
                                  'position': positionController.text.trim().isEmpty ? null : positionController.text.trim(),
                                  'contact_number': contactController.text.trim().isEmpty ? null : contactController.text.trim(),
                                  'profile_image_url': imageUrl,
                                },
                              );
                            } catch (e) {
                              print('Error logging user update audit event: $e');
                            }
                          }
                        } else {
                          // No image selected
                          if (user == null) {
                            final createRes = await createUserViaEdgeFunction(
                              email: emailController.text.trim(),
                              role: selectedRole!,
                              fname: fnameController.text.trim(),
                              mname:
                                  mnameController.text.trim().isEmpty
                                      ? null
                                      : mnameController.text.trim(),
                              lname: lnameController.text.trim(),
                              suffix:
                                  suffixController.text.trim().isEmpty
                                      ? null
                                      : suffixController.text.trim(),
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

                            if (createRes['status'] != 200) {
                              final errs = _extractFieldErrors(
                                createRes['data'],
                              );
                              _setFieldErrors(errs);
                              return;
                            }

                            // Fetch the created user ID for audit logging
                            final createdUser = await supabase
                                .from('users')
                                .select('id')
                                .eq('email', emailController.text.trim())
                                .single();

                            // Log user creation immediately after successful creation
                            try {
                              final userName = '${fnameController.text.trim()} ${lnameController.text.trim()}';
                              await auditLogService.logAccountCreation(
                                targetUserId: createdUser['id'].toString(),
                                targetUserName: userName,
                                role: selectedRole!,
                                userData: {
                                  'email': emailController.text.trim(),
                                  'role': selectedRole,
                                  'fname': fnameController.text.trim(),
                                  'lname': lnameController.text.trim(),
                                  'mname': mnameController.text.trim().isEmpty ? null : mnameController.text.trim(),
                                  'position': positionController.text.trim().isEmpty ? null : positionController.text.trim(),
                                  'contact_number': contactController.text.trim().isEmpty ? null : contactController.text.trim(),
                                },
                              );
                            } catch (e) {
                              print('Error logging user creation audit event: $e');
                            }
                          } else {
                            final editRes = await editUserViaEdgeFunction(
                              id: user['id'].toString(),
                              email: emailController.text.trim(),
                              role: selectedRole!,
                              fname: fnameController.text.trim(),
                              mname:
                                  mnameController.text.trim().isEmpty
                                      ? null
                                      : mnameController.text.trim(),
                              lname: lnameController.text.trim(),
                              suffix:
                                  suffixController.text.trim().isEmpty
                                      ? null
                                      : suffixController.text.trim(),
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

                            if (editRes['status'] != 200) {
                              final errs = _extractFieldErrors(editRes['data']);
                              _setFieldErrors(errs);
                              return;
                            }

                            // Log user update immediately after successful edit (no image path)
                            try {
                              final userName = '${fnameController.text.trim()} ${lnameController.text.trim()}';
                              await auditLogService.logUserManagement(
                                action: 'update',
                                targetUserId: user['id'].toString(),
                                targetUserName: userName,
                                role: selectedRole,
                                oldValues: {
                                  'email': user['email'],
                                  'fname': user['fname'],
                                  'lname': user['lname'],
                                  'mname': user['mname'],
                                  'role': user['role'],
                                  'position': user['position'],
                                  'contact_number': user['contact_number'],
                                },
                                newValues: {
                                  'email': emailController.text.trim(),
                                  'fname': fnameController.text.trim(),
                                  'lname': lnameController.text.trim(),
                                  'mname': mnameController.text.trim().isEmpty ? null : mnameController.text.trim(),
                                  'role': selectedRole,
                                  'position': positionController.text.trim().isEmpty ? null : positionController.text.trim(),
                                  'contact_number': contactController.text.trim().isEmpty ? null : contactController.text.trim(),
                                },
                              );
                            } catch (e) {
                              print('Error logging user update audit event: $e');
                            }
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
                        // Unexpected error: show inline general error in dialog
                        setDialogState(() {
                          final normalized = _normalizeFunctionException(e);
                          final dyn = normalized['data'];
                          String message;
                          if (dyn is Map && dyn['error'] != null) {
                            message = dyn['error'].toString();
                          } else if (dyn is Map && dyn['message'] != null) {
                            message = dyn['message'].toString();
                          } else if (dyn is Map && dyn.values.isNotEmpty) {
                            // pick a sensible fallback if field_errors exist
                            message = dyn.toString();
                          } else {
                            message = e.toString();
                          }
                          fieldErrors = {'_general': message};
                        });
                        formKey.currentState!.validate();
                      }
                    }
                  },
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(user == null ? Icons.add : Icons.save, size: 18),
                      const SizedBox(width: 10),
                      Text(
                        user == null ? 'Create User' : 'Update User',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
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
    suffixController.dispose();
    emailController.dispose();
    contactController.dispose();
    positionController.dispose();
  }

  // Helper method to build section headers
  Widget _buildSectionHeader(String title) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFF2ECC71).withOpacity(0.08),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: const Color(0xFF2ECC71).withOpacity(0.2),
          width: 1,
        ),
      ),
      child: Row(
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
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
              letterSpacing: 0.3,
            ),
          ),
        ],
      ),
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
      prefixIcon: Icon(icon, size: 22, color: const Color(0xFF2ECC71)),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Color(0xFF2ECC71), width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 1),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: const BorderSide(color: Colors.red, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      labelStyle: const TextStyle(
        color: Color(0xFF555555),
        fontSize: 16,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // Compact decoration for tighter/shorter fields (e.g. middle name)
  InputDecoration _buildCompactInputDecoration(
    String label,
    IconData icon, {
    bool isRequired = false,
  }) {
    return InputDecoration(
      labelText: isRequired ? '$label *' : label,
      // use a smaller icon to preserve space, and set isDense to true
      prefixIcon: Icon(icon, size: 20, color: const Color(0xFF2ECC71)),
      isDense: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(10),
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
      fillColor: Colors.white,
      // slightly smaller vertical padding to fit small widths better
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      labelStyle: const TextStyle(
        color: Color(0xFF555555),
        fontSize: 15,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  // helper to extract field-level errors (flexible to common shapes)
  Map<String, String?> _extractFieldErrors(dynamic data) {
    final Map<String, String?> errors = {};
    if (data == null) return errors;

    if (data is String) {
      // try to parse JSON string
      try {
        final parsed = jsonDecode(data);
        return _extractFieldErrors(parsed);
      } catch (_) {
        errors['_general'] = data;
        return errors;
      }
    }

    if (data is Map) {
      // common shapes: { errors: { email: "msg", ... } } or { field_errors: {...} }
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
        // sometimes a single error string
        errors['_general'] = data['error'].toString();
        return errors;
      }
      // If the map itself looks like field->message
      bool looksLikeFields = data.keys.every(
        (k) => k is String && (data[k] is String || data[k] == null),
      );
      if (looksLikeFields) {
        data.forEach((k, v) {
          errors[k.toString()] = v?.toString();
        });
        return errors;
      }
      // fallback
      errors['_general'] = data.toString();
      return errors;
    }

    // fallback for unexpected types
    errors['_general'] = data.toString();
    return errors;
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

      if (_selectedImageBytes != null) {
      } else {
      }

      // Generate unique filename
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String extension = image.name.split('.').last.toLowerCase();
      final String fileName = 'user_${userId}_$timestamp.$extension';

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
            // Standardized Header
            Row(
              children: [
                const Text(
                  "User Management",
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
                      hintText: 'Search users...',
                      hintStyle: TextStyle(fontSize: 14, color: Color(0xFF9E9E9E)),
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
                    onChanged:
                        (val) => setState(() {
                          _searchQuery = val;
                          _currentPage = 1;
                        }),
                  ),
                ),
                const SizedBox(width: 12),
                // Standardized Add New button
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, color: Colors.white, size: 18),
                    label: const Text(
                      "Add New User",
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
                    onPressed: isAdmin ? () => _addOrEditUser() : null,
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
                    onPressed: _exportUsers,
                  ),
                ),
              ],
            ),
            // Standardized Breadcrumb
            const Padding(
              padding: EdgeInsets.only(top: 8.0, bottom: 24.0),
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
                      color: Colors.white,
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
                      color: Colors.white,
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
                            color: Colors.white,
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
                                    "${u['fname'] ?? ''} ${u['lname'] ?? ''} ${u['suffix'] ?? ''}".trim().replaceAll(RegExp(r'\s+'), ' ');
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
                                                          FontWeight.bold,
                                                      color: Color(0xFF1A1A1A),
                                                      fontSize: 18,
                                                      letterSpacing: 0.3,
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
                                                        fontSize: 13,
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
                                                                      
                                                                      // Log audit event for user deletion
                                                                      try {
                                                                        await auditLogService.logAccountDeletion(
                                                                          targetUserId: u['id'].toString(),
                                                                          targetUserName: '${u['fname'] ?? ''} ${u['lname'] ?? ''}'.trim(),
                                                                          role: u['role']?.toString() ?? 'Unknown',
                                                                        );
                                                                      } catch (auditError) {
                                                                        print('Failed to log audit event: $auditError');
                                                                      }
                                                                      
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

                    // Pagination info and controls
                    Padding(
                      padding: const EdgeInsets.only(top: 16.0),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.grey[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.grey[200]!),
                        ),
                        child: Column(
                          children: [
                            // Items per page selector and info
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // Items per page selector
                                Row(
                                  children: [
                                    const Text(
                                      'Show:',
                                      style: TextStyle(
                                        color: Color(0xFF666666),
                                        fontSize: 13,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 12,
                                      ),
                                      decoration: BoxDecoration(
                                        border: Border.all(
                                          color: Colors.grey[300]!,
                                        ),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<int>(
                                          value: _itemsPerPage,
                                          items:
                                              [5, 10, 25, 50, 100].map((
                                                int value,
                                              ) {
                                                return DropdownMenuItem<int>(
                                                  value: value,
                                                  child: Text('$value entries'),
                                                );
                                              }).toList(),
                                          onChanged: (int? newValue) {
                                            setState(() {
                                              _itemsPerPage = newValue!;
                                              _currentPage =
                                                  1; // Reset to first page
                                            });
                                          },
                                          style: const TextStyle(
                                            fontSize: 13,
                                            color: Color(0xFF666666),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),

                                // Total entries info
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(
                                      0xFF2ECC71,
                                    ).withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: const Color(
                                        0xFF2ECC71,
                                      ).withOpacity(0.3),
                                    ),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.people,
                                        size: 16,
                                        color: const Color(0xFF2ECC71),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Total: ${filteredUsers.length} users',
                                        style: const TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF2ECC71),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),

                            // Pagination info and controls
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                // "Showing x to y of z entries"
                                Text(
                                  'Showing ${currentPageItems.isEmpty ? 0 : startIndex + 1} to $endIndex of ${filteredUsers.length} entries',
                                  style: const TextStyle(
                                    color: Color(0xFF666666),
                                    fontSize: 13,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),

                                // Enhanced pagination controls
                                Row(
                                  children: [
                                    // First page button
                                    IconButton(
                                      icon: const Icon(Icons.first_page),
                                      onPressed:
                                          _currentPage > 1
                                              ? () => setState(
                                                () => _currentPage = 1,
                                              )
                                              : null,
                                      color:
                                          _currentPage > 1
                                              ? const Color(0xFF666666)
                                              : const Color(0xFFCCCCCC),
                                      tooltip: 'First page',
                                    ),

                                    // Previous button
                                    IconButton(
                                      icon: const Icon(Icons.chevron_left),
                                      onPressed:
                                          _currentPage > 1
                                              ? () =>
                                                  setState(() => _currentPage--)
                                              : null,
                                      color:
                                          _currentPage > 1
                                              ? const Color(0xFF666666)
                                              : const Color(0xFFCCCCCC),
                                      tooltip: 'Previous page',
                                    ),

                                    // Page input field for quick navigation
                                    Container(
                                      width: 80,
                                      height: 32,
                                      margin: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                      ),
                                      child: TextFormField(
                                        initialValue: _currentPage.toString(),
                                        textAlign: TextAlign.center,
                                        keyboardType: TextInputType.number,
                                        style: const TextStyle(fontSize: 14),
                                        decoration: InputDecoration(
                                          contentPadding:
                                              const EdgeInsets.symmetric(
                                                vertical: 8,
                                              ),
                                          border: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            borderSide: BorderSide(
                                              color: Colors.grey[300]!,
                                            ),
                                          ),
                                          focusedBorder: OutlineInputBorder(
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
                                            borderSide: const BorderSide(
                                              color: Color(0xFF2ECC71),
                                            ),
                                          ),
                                        ),
                                        onFieldSubmitted: (value) {
                                          final page = int.tryParse(value);
                                          if (page != null &&
                                              page >= 1 &&
                                              page <= _totalPages) {
                                            setState(() => _currentPage = page);
                                          }
                                        },
                                      ),
                                    ),

                                    Text(
                                      'of $_totalPages',
                                      style: const TextStyle(
                                        color: Color(0xFF666666),
                                        fontSize: 13,
                                      ),
                                    ),

                                    // Next button
                                    IconButton(
                                      icon: const Icon(Icons.chevron_right),
                                      onPressed:
                                          _currentPage < _totalPages
                                              ? () =>
                                                  setState(() => _currentPage++)
                                              : null,
                                      color:
                                          _currentPage < _totalPages
                                              ? const Color(0xFF666666)
                                              : const Color(0xFFCCCCCC),
                                      tooltip: 'Next page',
                                    ),

                                    // Last page button
                                    IconButton(
                                      icon: const Icon(Icons.last_page),
                                      onPressed:
                                          _currentPage < _totalPages
                                              ? () => setState(
                                                () =>
                                                    _currentPage = _totalPages,
                                              )
                                              : null,
                                      color:
                                          _currentPage < _totalPages
                                              ? const Color(0xFF666666)
                                              : const Color(0xFFCCCCCC),
                                      tooltip: 'Last page',
                                    ),
                                  ],
                                ),
                              ],
                            ),

                            // Quick page jumper (for large datasets)
                            if (_totalPages > 10) ...[
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  const Text(
                                    'Quick jump: ',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Color(0xFF666666),
                                    ),
                                  ),
                                  ...List.generate(
                                    (_totalPages / 10).ceil().clamp(1, 5),
                                    (index) {
                                      final pageGroup = (index + 1) * 10;
                                      final actualPage =
                                          pageGroup > _totalPages
                                              ? _totalPages
                                              : pageGroup;
                                      return Padding(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 2,
                                        ),
                                        child: TextButton(
                                          onPressed:
                                              () => setState(
                                                () => _currentPage = actualPage,
                                              ),
                                          style: TextButton.styleFrom(
                                            padding: const EdgeInsets.symmetric(
                                              horizontal: 8,
                                              vertical: 4,
                                            ),
                                            minimumSize: Size.zero,
                                            foregroundColor: const Color(
                                              0xFF2ECC71,
                                            ),
                                          ),
                                          child: Text(
                                            '$actualPage',
                                            style: const TextStyle(
                                              fontSize: 11,
                                            ),
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
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
          fontWeight: FontWeight.bold,
          fontSize: 16,
          color: Color(0xFF1A1A1A),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
