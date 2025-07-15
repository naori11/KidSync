import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kidsync/widgets/role_protection.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/html.dart';
import 'dart:convert';

class StudentManagementPageAdmin extends StatelessWidget {
  const StudentManagementPageAdmin({super.key});

  @override
  Widget build(BuildContext context) {
    return RoleProtected(
      requiredRole: 'Admin',
      child: const StudentManagementPage(),
    );
  }
}

class StudentManagementPage extends StatefulWidget {
  const StudentManagementPage({super.key});

  @override
  State<StudentManagementPage> createState() => _StudentManagementPageState();
}

class _StudentManagementPageState extends State<StudentManagementPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> students = [];
  bool isLoading = false;
  String _searchQuery = '';
  String _sortOption = 'Name (A-Z)';
  String _classFilter = 'All Classes';
  String _statusFilter = 'All Status';

  // For pagination
  int _currentPage = 1;
  int _itemsPerPage = 5;
  int _totalPages = 1;

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() => isLoading = true);
    final response = await supabase
        .from('students')
        .select()
        .order('lname', ascending: true);
    setState(() {
      students = List<Map<String, dynamic>>.from(response);
      isLoading = false;
    });
  }

  void _calculateTotalPages(List<Map<String, dynamic>> filteredStudents) {
    _totalPages = (filteredStudents.length / _itemsPerPage).ceil();
    if (_totalPages == 0) _totalPages = 1;
    if (_currentPage > _totalPages) _currentPage = _totalPages;
  }

  Future<String?> _showRFIDScanDialog(BuildContext context) async {
    String? scannedUID;
    HtmlWebSocketChannel? channel;
    bool isScanning = true;
    bool isConnected = false;
    String connectionStatus = 'Connecting to RFID scanner...';

    return await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            // Initialize WebSocket connection
            if (channel == null && isScanning) {
              try {
                channel = HtmlWebSocketChannel.connect(
                  'wss://rfid-websocket-server.onrender.com',
                );

                channel!.stream.listen(
                  (data) {
                    try {
                      final Map<String, dynamic> message = json.decode(data);
                      if (message['type'] == 'rfid_scan' &&
                          message['uid'] != null) {
                        setDialogState(() {
                          scannedUID = message['uid'];
                          isScanning = false;
                          connectionStatus = 'RFID card detected!';
                        });
                      }
                    } catch (e) {
                      print('Error parsing WebSocket message: $e');
                    }
                  },
                  onError: (error) {
                    setDialogState(() {
                      isConnected = false;
                      connectionStatus =
                          'Connection error. Please check your RFID scanner.';
                    });
                  },
                  onDone: () {
                    setDialogState(() {
                      isConnected = false;
                      if (isScanning) {
                        connectionStatus = 'Connection lost. Please try again.';
                      }
                    });
                  },
                );

                setDialogState(() {
                  isConnected = true;
                  connectionStatus = 'Ready to scan RFID card...';
                });
              } catch (e) {
                setDialogState(() {
                  isConnected = false;
                  connectionStatus = 'Failed to connect to RFID scanner.';
                });
              }
            }

            return AlertDialog(
              title: const Text('Scan RFID Card'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (scannedUID == null) ...[
                    const Icon(
                      Icons.contactless,
                      size: 64,
                      color: Color(0xFF2ECC71),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      connectionStatus,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color:
                            isConnected
                                ? const Color(0xFF2ECC71)
                                : Colors.orange,
                      ),
                    ),
                    if (isConnected && isScanning) ...[
                      const SizedBox(height: 16),
                      const CircularProgressIndicator(color: Color(0xFF2ECC71)),
                      const SizedBox(height: 16),
                      const Text(
                        'Please tap the RFID card on the scanner...',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ] else ...[
                    const Icon(
                      Icons.check_circle,
                      size: 64,
                      color: Color(0xFF2ECC71),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'RFID Card Scanned Successfully!',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF2ECC71),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        'UID: $scannedUID',
                        style: const TextStyle(
                          fontFamily: 'monospace',
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    channel?.sink.close();
                    Navigator.of(context).pop(null);
                  },
                  child: const Text('Cancel'),
                ),
                if (scannedUID != null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      channel?.sink.close();
                      Navigator.of(context).pop(scannedUID);
                    },
                    child: const Text('Use This UID'),
                  ),
                if (scannedUID == null && isConnected)
                  TextButton(
                    onPressed: () {
                      setDialogState(() {
                        isScanning = true;
                        connectionStatus = 'Ready to scan RFID card...';
                      });
                    },
                    child: const Text('Retry'),
                  ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _addOrEditStudent({Map<String, dynamic>? student}) async {
    String? fname = student?['fname'];
    String? mname = student?['mname'];
    String? lname = student?['lname'];
    String? gender = student?['gender'];
    String? address = student?['address'];
    String? birthday = student?['birthday'];
    String? grade = student?['grade_level'];
    String? section = student?['section_id']?.toString();
    String? status = student?['status'] ?? 'Active';
    String? rfidUID = student?['rfid_uid']; // Add RFID UID field

    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text(student == null ? 'Add New Student' : 'Edit Student'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'First Name',
                      ),
                      controller: TextEditingController(text: fname),
                      onChanged: (val) => fname = val,
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Middle Name',
                      ),
                      controller: TextEditingController(text: mname),
                      onChanged: (val) => mname = val,
                    ),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Last Name'),
                      controller: TextEditingController(text: lname),
                      onChanged: (val) => lname = val,
                    ),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Gender'),
                      controller: TextEditingController(text: gender),
                      onChanged: (val) => gender = val,
                    ),
                    TextField(
                      decoration: const InputDecoration(labelText: 'Address'),
                      controller: TextEditingController(text: address),
                      onChanged: (val) => address = val,
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Birthday (YYYY-MM-DD)',
                      ),
                      controller: TextEditingController(text: birthday),
                      onChanged: (val) => birthday = val,
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Grade Level',
                      ),
                      controller: TextEditingController(text: grade),
                      onChanged: (val) => grade = val,
                    ),
                    TextField(
                      decoration: const InputDecoration(
                        labelText: 'Section ID',
                      ),
                      controller: TextEditingController(text: section),
                      onChanged: (val) => section = val,
                    ),
                    const SizedBox(height: 16),
                    // RFID UID Section
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.contactless,
                                color: Color(0xFF2ECC71),
                              ),
                              const SizedBox(width: 8),
                              const Text(
                                'RFID Card',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          if (rfidUID != null && rfidUID!.isNotEmpty) ...[
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.grey[100],
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Current UID:',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: Colors.grey,
                                    ),
                                  ),
                                  Text(
                                    rfidUID!,
                                    style: const TextStyle(
                                      fontFamily: 'monospace',
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                Expanded(
                                  child: OutlinedButton.icon(
                                    icon: const Icon(Icons.contactless),
                                    label: const Text('Scan New Card'),
                                    onPressed: () async {
                                      final newUID = await _showRFIDScanDialog(
                                        context,
                                      );
                                      if (newUID != null) {
                                        setDialogState(() {
                                          rfidUID = newUID;
                                        });
                                      }
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  icon: const Icon(
                                    Icons.clear,
                                    color: Colors.red,
                                  ),
                                  tooltip: 'Remove RFID',
                                  onPressed: () {
                                    setDialogState(() {
                                      rfidUID = null;
                                    });
                                  },
                                ),
                              ],
                            ),
                          ] else ...[
                            const Text(
                              'No RFID card assigned',
                              style: TextStyle(color: Colors.grey),
                            ),
                            const SizedBox(height: 8),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                icon: const Icon(Icons.contactless),
                                label: const Text('Scan RFID Card'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: const Color(0xFF2ECC71),
                                  foregroundColor: Colors.white,
                                ),
                                onPressed: () async {
                                  final newUID = await _showRFIDScanDialog(
                                    context,
                                  );
                                  if (newUID != null) {
                                    setDialogState(() {
                                      rfidUID = newUID;
                                    });
                                  }
                                },
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    DropdownButtonFormField<String>(
                      decoration: const InputDecoration(labelText: 'Status'),
                      value: status,
                      items: const [
                        DropdownMenuItem(
                          value: 'Active',
                          child: Text('Active'),
                        ),
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
                    backgroundColor: const Color(0xFF2ECC71),
                    foregroundColor: Colors.white,
                  ),
                  onPressed: () async {
                    try {
                      final payload = {
                        'fname': fname,
                        'mname': mname,
                        'lname': lname,
                        'gender': gender,
                        'address': address,
                        'birthday': birthday,
                        'grade_level': grade,
                        'section_id': section,
                        'status': status,
                        'rfid_uid': rfidUID,
                      };

                      if (student == null) {
                        await supabase.from('students').insert(payload);
                      } else {
                        await supabase
                            .from('students')
                            .update(payload)
                            .eq('id', student['id']);
                      }

                      Navigator.pop(context);
                      _fetchStudents();

                      // Show success message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(
                              student == null
                                  ? 'Student added successfully!'
                                  : 'Student updated successfully!',
                            ),
                            backgroundColor: const Color(0xFF2ECC71),
                          ),
                        );
                      }
                    } catch (e) {
                      // Show error message
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Error: ${e.toString()}'),
                            backgroundColor: Colors.red,
                          ),
                        );
                      }
                    }
                  },
                  child: Text(student == null ? 'Add' : 'Update'),
                ),
              ],
            );
          },
        );
      },
    );
  }

  Future<void> _deleteStudent(int id) async {
    try {
      await supabase.from('students').delete().eq('id', id);
      _fetchStudents();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Student deleted successfully!'),
            backgroundColor: Color(0xFF2ECC71),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error deleting student: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export functionality would be implemented here'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final isAdmin = user?.userMetadata?['role'] == 'Admin';

    // Apply filters
    var filteredStudents =
        students.where((s) {
          final name = "${s['fname']} ${s['lname']}".toLowerCase();
          final classMatch =
              _classFilter == 'All Classes' ||
              s['grade_level']?.toString() ==
                  _classFilter.replaceAll(RegExp(r'Grade '), '');
          final statusMatch =
              _statusFilter == 'All Status' ||
              (s['status'] ?? 'Active') == _statusFilter;

          return name.contains(_searchQuery.toLowerCase()) &&
              classMatch &&
              statusMatch;
        }).toList();

    // Apply sorting
    if (_sortOption == 'Name (A-Z)') {
      filteredStudents.sort(
        (a, b) => "${a['fname'] ?? ''} ${a['lname'] ?? ''}".compareTo(
          "${b['fname'] ?? ''} ${b['lname'] ?? ''}",
        ),
      );
    } else if (_sortOption == 'Name (Z-A)') {
      filteredStudents.sort(
        (a, b) => "${b['fname'] ?? ''} ${b['lname'] ?? ''}".compareTo(
          "${a['fname'] ?? ''} ${a['lname'] ?? ''}",
        ),
      );
    } else if (_sortOption.contains('Date')) {
      filteredStudents.sort(
        (a, b) => (a['created_at'] ?? '').compareTo(b['created_at'] ?? ''),
      );
      if (_sortOption.contains('(Desc)')) {
        filteredStudents = filteredStudents.reversed.toList();
      }
    }

    // Calculate pages for pagination
    _calculateTotalPages(filteredStudents);

    // Get current page items
    final int startIndex = (_currentPage - 1) * _itemsPerPage;
    final int endIndex =
        startIndex + _itemsPerPage > filteredStudents.length
            ? filteredStudents.length
            : startIndex + _itemsPerPage;

    final List<Map<String, dynamic>> currentPageItems =
        filteredStudents.length > startIndex
            ? filteredStudents.sublist(startIndex, endIndex)
            : [];

    // Get unique class/grade levels for filter dropdown
    final List<String> classOptions = ['All Classes'];
    for (var student in students) {
      final grade = student['grade_level']?.toString();
      if (grade != null && !classOptions.contains('Grade $grade')) {
        classOptions.add('Grade $grade');
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with breadcrumb
            Row(
              children: [
                const Text(
                  "Student Management",
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
                      hintText: 'Search students...',
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
                // Add New Student button
                SizedBox(
                  height: 40,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.add, color: Colors.white),
                    label: const Text(
                      "Add New Student",
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
                    onPressed: isAdmin ? () => _addOrEditStudent() : null,
                  ),
                ),
                const SizedBox(width: 16),
                // Export button
                SizedBox(
                  height: 40,
                  child: OutlinedButton.icon(
                    icon: const Icon(
                      Icons.file_download_outlined,
                      color: Color(0xFF333333),
                    ),
                    label: const Text(
                      "Export",
                      style: TextStyle(color: Color(0xFF333333)),
                    ),
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Color(0xFFE0E0E0)),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: _exportData,
                  ),
                ),
              ],
            ),

            // Breadcrumb / subtitle
            const Padding(
              padding: EdgeInsets.only(top: 4.0, bottom: 20.0),
              child: Text(
                "Home / Student Management",
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
                  // Class filter dropdown
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _classFilter,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        items:
                            classOptions.map((String item) {
                              return DropdownMenuItem(
                                value: item,
                                child: Text(item),
                              );
                            }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _classFilter = newValue!;
                            _currentPage = 1;
                          });
                        },
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  // Status filter dropdown
                  Container(
                    height: 40,
                    padding: const EdgeInsets.symmetric(horizontal: 12.0),
                    decoration: BoxDecoration(
                      border: Border.all(color: const Color(0xFFE0E0E0)),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _statusFilter,
                        icon: const Icon(Icons.keyboard_arrow_down),
                        items:
                            <String>[
                              'All Status',
                              'Active',
                              'Inactive',
                            ].map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(value),
                              );
                            }).toList(),
                        onChanged: (String? newValue) {
                          setState(() {
                            _statusFilter = newValue!;
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
                              'Date (Asc)',
                              'Date (Desc)',
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
                              0: FlexColumnWidth(0.8), // ID
                              1: FlexColumnWidth(1.5), // Name
                              2: FlexColumnWidth(0.8), // Class
                              3: FlexColumnWidth(0.8), // Gender
                              4: FlexColumnWidth(1.2), // Contact
                              5: FlexColumnWidth(1.2), // Email
                              6: FlexColumnWidth(1.0), // Enrollment
                              7: FlexColumnWidth(0.8), // Status
                              8: FlexColumnWidth(0.5), // Actions
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
                                  TableHeaderCell(text: 'Student ID'),
                                  TableHeaderCell(text: 'Student Name'),
                                  TableHeaderCell(text: 'Class'),
                                  TableHeaderCell(text: 'Gender'),
                                  TableHeaderCell(text: 'Contact Number'),
                                  TableHeaderCell(text: 'Email'),
                                  TableHeaderCell(text: 'Enrollment Date'),
                                  TableHeaderCell(text: 'Status'),
                                  TableHeaderCell(text: 'Actions'),
                                ],
                              ),

                              // Table data rows
                              ...currentPageItems.map((student) {
                                final fullName =
                                    "${student['fname'] ?? ''} ${student['lname'] ?? ''}";
                                final String studentId =
                                    "STU${student['id'].toString().padLeft(3, '0')}";
                                final String className =
                                    "Grade ${student['grade_level'] ?? ''}${student['section_id'] != null ? String.fromCharCode(64 + int.parse(student['section_id'])) : ''}";
                                final enrollmentDate =
                                    student['created_at'] != null
                                        ? DateFormat('yyyy-MM-dd').format(
                                          DateTime.parse(student['created_at']),
                                        )
                                        : "N/A";
                                final status = student['status'] ?? 'Active';

                                return TableRow(
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                  ),
                                  children: [
                                    // Student ID
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          studentId,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w500,
                                            color: Color(0xFF555555),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // Student name
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
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

                                    // Class
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16),
                                        child: Text(className),
                                      ),
                                    ),

                                    // Gender
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16),
                                        child: Text(student['gender'] ?? 'N/A'),
                                      ),
                                    ),

                                    // Contact number
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16),
                                        child: Text(
                                          student['contact_number'] ?? 'N/A',
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
                                        child: Text(student['email'] ?? 'N/A'),
                                      ),
                                    ),

                                    // Enrollment date
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16),
                                        child: Text(enrollmentDate),
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
                                            horizontal: 8,
                                            vertical: 4,
                                          ),
                                          decoration: BoxDecoration(
                                            color:
                                                status == 'Active'
                                                    ? const Color(0xFFE8F5E9)
                                                    : const Color(0xFFFFEBEE),
                                            borderRadius: BorderRadius.circular(
                                              4,
                                            ),
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

                                    // Actions
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Center(
                                        child: PopupMenuButton<String>(
                                          icon: const Icon(Icons.more_vert),
                                          onSelected: (value) {
                                            if (value == 'edit') {
                                              _addOrEditStudent(
                                                student: student,
                                              );
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
                                                                    Colors.red,
                                                              ),
                                                          onPressed: () {
                                                            Navigator.pop(ctx);
                                                            _deleteStudent(
                                                              student['id'],
                                                            );
                                                          },
                                                          child: const Text(
                                                            'Delete',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.white,
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
                                              ],
                                        ),
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
                            'Showing ${currentPageItems.isEmpty ? 0 : startIndex + 1} to ${endIndex} of ${filteredStudents.length} entries',
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
