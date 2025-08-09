import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:kidsync/widgets/role_protection.dart';
import 'package:intl/intl.dart';
import 'package:web_socket_channel/html.dart';
import 'dart:convert';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import 'dart:html' as html; // Add this for web file handling

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
  List<Map<String, dynamic>> sections = [];
  bool isLoading = false;
  bool isLoadingSections = false;
  String _searchQuery = '';
  String _sortOption = 'Name (A-Z)';
  String _classFilter = 'All Classes';
  String _statusFilter = 'All Status';
  Set<int> _selectedStudents = <int>{};
  bool _selectAll = false;
  Uint8List? _selectedImageBytes;

  // For pagination
  int _currentPage = 1;
  int _itemsPerPage = 5;
  int _totalPages = 1;

  // For image uploads
  String? _selectedImagePath;
  String? _currentImageUrl;
  bool _isUploadingImage = false;

  @override
  void initState() {
    super.initState();
    _fetchSections();
    _fetchStudents();
  }

  Future<void> _fetchSections() async {
    setState(() => isLoadingSections = true);
    final response = await supabase
        .from('sections')
        .select('id, name, grade_level');
    setState(() {
      sections = List<Map<String, dynamic>>.from(response);
      isLoadingSections = false;
    });
  }

  Future<void> _fetchStudents() async {
    setState(() => isLoading = true);
    // Fetch students with joined section info
    final response = await supabase
        .from('students')
        .select('*, sections(id, name, grade_level)')
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

  Future<String?> _showRFIDScanDialog(
    BuildContext context, {
    int? excludeStudentId,
  }) async {
    String? scannedUID;
    HtmlWebSocketChannel? channel;
    bool isScanning = true;
    bool isConnected = false;
    String connectionStatus = 'Connecting to RFID scanner...';
    bool isValidating = false;
    String? validationError;

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
                  (data) async {
                    try {
                      final Map<String, dynamic> message = json.decode(data);
                      if (message['type'] == 'rfid_scan' &&
                          message['uid'] != null) {
                        final uid = message['uid'];

                        setDialogState(() {
                          isScanning = false;
                          isValidating = true;
                          connectionStatus = 'Validating RFID card...';
                          validationError = null;
                        });

                        // Validate RFID uniqueness
                        final isUnique = await _validateRFIDUniqueness(
                          uid,
                          excludeStudentId: excludeStudentId,
                        );

                        if (isUnique) {
                          setDialogState(() {
                            scannedUID = uid;
                            isValidating = false;
                            connectionStatus =
                                'RFID card validated successfully!';
                          });
                        } else {
                          final existingStudent = await _checkRFIDExists(
                            uid,
                            excludeStudentId: excludeStudentId,
                          );
                          final studentName =
                              "${existingStudent?['fname'] ?? ''} ${existingStudent?['lname'] ?? ''}";
                          final sectionInfo = existingStudent?['sections'];
                          final classInfo =
                              sectionInfo != null
                                  ? "${sectionInfo['name']} (${sectionInfo['grade_level']})"
                                  : "Unknown Class";

                          setDialogState(() {
                            isValidating = false;
                            validationError =
                                'This RFID card is already assigned to $studentName in $classInfo';
                            connectionStatus = 'RFID validation failed';
                            isScanning = true; // Allow scanning again
                          });
                        }
                      }
                    } catch (e) {
                      print('Error parsing WebSocket message: $e');
                      setDialogState(() {
                        isValidating = false;
                        validationError = 'Error processing RFID scan';
                        isScanning = true;
                      });
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
              content: Container(
                width: 400,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (scannedUID == null) ...[
                      if (validationError == null) ...[
                        Icon(
                          isValidating
                              ? Icons.hourglass_empty
                              : Icons.contactless,
                          size: 64,
                          color:
                              isValidating
                                  ? Colors.orange
                                  : const Color(0xFF2ECC71),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          connectionStatus,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            color:
                                isConnected && !isValidating
                                    ? const Color(0xFF2ECC71)
                                    : isValidating
                                    ? Colors.orange
                                    : Colors.orange,
                          ),
                        ),
                        if (isValidating) ...[
                          const SizedBox(height: 16),
                          const CircularProgressIndicator(color: Colors.orange),
                          const SizedBox(height: 16),
                          const Text(
                            'Checking RFID card availability...',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 13),
                          ),
                        ] else if (isConnected && isScanning) ...[
                          const SizedBox(height: 16),
                          const CircularProgressIndicator(
                            color: Color(0xFF2ECC71),
                          ),
                          const SizedBox(height: 16),
                          const Text(
                            'Please tap the RFID card on the scanner...',
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ] else ...[
                        // Show validation error
                        const Icon(Icons.error, size: 64, color: Colors.red),
                        const SizedBox(height: 16),
                        const Text(
                          'RFID Card Already Assigned',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.red,
                            fontSize: 16,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: Colors.red[50],
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.red[200]!),
                          ),
                          child: Column(
                            children: [
                              Icon(
                                Icons.warning,
                                color: Colors.red[600],
                                size: 20,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                validationError!,
                                style: TextStyle(
                                  color: Colors.red[700],
                                  fontSize: 13,
                                  fontWeight: FontWeight.w500,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        const Text(
                          'Please use a different RFID card or remove the assignment from the other student first.',
                          style: TextStyle(fontSize: 12, color: Colors.grey),
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
                        'RFID Card Validated Successfully!',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF2ECC71),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.green[50],
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: Colors.green[200]!),
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.check_circle,
                                  color: Colors.green[600],
                                  size: 16,
                                ),
                                const SizedBox(width: 6),
                                const Text(
                                  'Available for assignment',
                                  style: TextStyle(
                                    color: Colors.green,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'UID: $scannedUID',
                              style: const TextStyle(
                                fontFamily: 'monospace',
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
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
                if (validationError != null)
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.orange,
                      foregroundColor: Colors.white,
                    ),
                    onPressed: () {
                      setDialogState(() {
                        validationError = null;
                        isScanning = true;
                        connectionStatus = 'Ready to scan RFID card...';
                      });
                    },
                    child: const Text('Scan Different Card'),
                  ),
                if (scannedUID == null &&
                    isConnected &&
                    !isValidating &&
                    validationError == null)
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
    // Reset image state when opening dialog
    setState(() {
      _selectedImagePath = null;
      _selectedImageBytes = null;
      _currentImageUrl = null;
      _isUploadingImage = false;
    });

    // Load sections if not loaded
    if (sections.isEmpty) await _fetchSections();

    // Form controllers
    final fnameController = TextEditingController(
      text: student?['fname']?.toString() ?? '',
    );
    final mnameController = TextEditingController(
      text: student?['mname']?.toString() ?? '',
    );
    final lnameController = TextEditingController(
      text: student?['lname']?.toString() ?? '',
    );
    final addressController = TextEditingController(
      text: student?['address']?.toString() ?? '',
    );
    final birthdayController = TextEditingController(
      text:
          student?['birthday'] != null
              ? DateFormat(
                'yyyy-MM-dd',
              ).format(DateTime.parse(student!['birthday'].toString()))
              : '',
    );

    // Form state variables - Aligned with schema
    String? selectedGender = student?['gender']?.toString();

    String? selectedGradeLevel = student?['grade_level']?.toString();

    // Now section_id is BIGINT, must select from sections list
    int? selectedSectionId;
    if (student?['section_id'] != null) {
      if (student!['section_id'] is int) {
        selectedSectionId = student['section_id'];
      } else if (student['section_id'] is String) {
        selectedSectionId = int.tryParse(student['section_id']);
      }
    }

    String selectedStatus = student?['status']?.toString() ?? 'Active';
    String? rfidUID = student?['rfid_uid']?.toString();

    DateTime? selectedBirthday;
    if (student?['birthday'] != null) {
      try {
        selectedBirthday = DateTime.parse(student!['birthday'].toString());
      } catch (e) {
        print('Error parsing birthday: $e');
      }
    }

    // Form validation key
    final formKey = GlobalKey<FormState>();

    // Gender options
    final genderOptions = ['Male', 'Female', 'Other'];

    // Grade level options (integers to match database)
    final gradeOptions = [
      'Preschool',
      'Kinder',
      'Grade 1',
      'Grade 2',
      'Grade 3',
      'Grade 4',
      'Grade 5',
      'Grade 6',
    ];
    await showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Row(
                children: [
                  Icon(
                    student == null ? Icons.person_add : Icons.edit,
                    color: const Color(0xFF2ECC71),
                  ),
                  const SizedBox(width: 8),
                  Text(student == null ? 'Add New Student' : 'Edit Student'),
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

                        // Gender and Birthday row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: _buildInputDecoration(
                                  'Gender',
                                  Icons.wc,
                                  isRequired: true,
                                ),
                                value:
                                    genderOptions.contains(selectedGender)
                                        ? selectedGender
                                        : null,
                                items:
                                    genderOptions.map((gender) {
                                      return DropdownMenuItem(
                                        value: gender,
                                        child: Text(gender),
                                      );
                                    }).toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedGender = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Please select gender';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: TextFormField(
                                controller: birthdayController,
                                decoration: _buildInputDecoration(
                                  'Birthday',
                                  Icons.calendar_today,
                                ).copyWith(
                                  suffixIcon: IconButton(
                                    icon: const Icon(Icons.calendar_today),
                                    onPressed: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate:
                                            selectedBirthday ??
                                            DateTime.now().subtract(
                                              const Duration(days: 365 * 10),
                                            ),
                                        firstDate: DateTime(1990),
                                        lastDate: DateTime.now(),
                                        builder: (context, child) {
                                          return Theme(
                                            data: Theme.of(context).copyWith(
                                              colorScheme: Theme.of(
                                                context,
                                              ).colorScheme.copyWith(
                                                primary: const Color(
                                                  0xFF2ECC71,
                                                ),
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (picked != null) {
                                        setDialogState(() {
                                          selectedBirthday = picked;
                                          birthdayController.text = DateFormat(
                                            'yyyy-MM-dd',
                                          ).format(picked);
                                        });
                                      }
                                    },
                                  ),
                                ),
                                readOnly: true,
                                validator: (value) {
                                  if (value?.trim().isEmpty ?? true) {
                                    return 'Birthday is required';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Address field
                        TextFormField(
                          controller: addressController,
                          decoration: _buildInputDecoration(
                            'Address',
                            Icons.home,
                            isRequired: true,
                          ),
                          maxLines: 2,
                          validator: (value) {
                            if (value?.trim().isEmpty ?? true) {
                              return 'Address is required';
                            }
                            return null;
                          },
                          textCapitalization: TextCapitalization.words,
                        ),
                        const SizedBox(height: 24),

                        // Academic Information Section
                        _buildSectionHeader('Academic Information'),
                        const SizedBox(height: 16),

                        // Grade and Section row
                        Row(
                          children: [
                            Expanded(
                              child: DropdownButtonFormField<String>(
                                decoration: _buildInputDecoration(
                                  'Grade Level',
                                  Icons.school,
                                  isRequired: true,
                                ),
                                value:
                                    gradeOptions.contains(selectedGradeLevel)
                                        ? selectedGradeLevel
                                        : null,
                                items:
                                    gradeOptions.map((grade) {
                                      return DropdownMenuItem(
                                        value: grade,
                                        child: Text(grade),
                                      );
                                    }).toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedGradeLevel = value;
                                    selectedSectionId =
                                        null; // Reset section when grade changes
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Please select grade level';
                                  }
                                  return null;
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: DropdownButtonFormField<int>(
                                decoration: _buildInputDecoration(
                                  'Section',
                                  Icons.class_,
                                  isRequired: true,
                                ),
                                value: selectedSectionId,
                                items:
                                    sections
                                        .where(
                                          (s) =>
                                              selectedGradeLevel == null ||
                                              s['grade_level'] ==
                                                  selectedGradeLevel,
                                        )
                                        .map((section) {
                                          return DropdownMenuItem<int>(
                                            value: section['id'],
                                            child: Text(
                                              '${section['name']} (${section['grade_level']})',
                                            ),
                                          );
                                        })
                                        .toList(),
                                onChanged: (value) {
                                  setDialogState(() {
                                    selectedSectionId = value;
                                  });
                                },
                                validator: (value) {
                                  if (value == null) {
                                    return 'Please select section';
                                  }
                                  return null;
                                },
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),

                        // Status dropdown
                        DropdownButtonFormField<String>(
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
                        const SizedBox(height: 24),

                        // RFID Section
                        _buildSectionHeader('RFID Card'),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[50],
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
                                    size: 20,
                                  ),
                                  const SizedBox(width: 8),
                                  const Text(
                                    'RFID Card Assignment',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 14,
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 12),
                              if (rfidUID != null && rfidUID!.isNotEmpty) ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.green[50],
                                    border: Border.all(
                                      color: Colors.green[200]!,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.check_circle,
                                            color: Colors.green[600],
                                            size: 16,
                                          ),
                                          const SizedBox(width: 6),
                                          const Text(
                                            'RFID Card Assigned',
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.green,
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        'UID: $rfidUID',
                                        style: const TextStyle(
                                          fontFamily: 'monospace',
                                          fontWeight: FontWeight.bold,
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        icon: const Icon(
                                          Icons.contactless,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          'Scan New Card',
                                          style: TextStyle(fontSize: 12),
                                        ),
                                        onPressed: () async {
                                          final newUID =
                                              await _showRFIDScanDialog(
                                                context,
                                                excludeStudentId:
                                                    student?['id'],
                                              );
                                          if (newUID != null) {
                                            setDialogState(() {
                                              rfidUID = newUID;
                                            });
                                          }
                                        },
                                        style: OutlinedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 12,
                                            vertical: 8,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 8),
                                    IconButton(
                                      icon: const Icon(
                                        Icons.clear,
                                        color: Colors.red,
                                        size: 18,
                                      ),
                                      tooltip: 'Remove RFID',
                                      onPressed: () {
                                        setDialogState(() {
                                          rfidUID = null;
                                        });
                                      },
                                      padding: const EdgeInsets.all(8),
                                    ),
                                  ],
                                ),
                              ] else ...[
                                Container(
                                  width: double.infinity,
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.orange[50],
                                    border: Border.all(
                                      color: Colors.orange[200]!,
                                    ),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(
                                        Icons.warning,
                                        color: Colors.orange[600],
                                        size: 16,
                                      ),
                                      const SizedBox(width: 8),
                                      const Text(
                                        'No RFID card assigned',
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: Colors.orange,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 12),
                                SizedBox(
                                  width: double.infinity,
                                  child: ElevatedButton.icon(
                                    icon: const Icon(
                                      Icons.contactless,
                                      size: 16,
                                    ),
                                    label: const Text(
                                      'Scan RFID Card',
                                      style: TextStyle(fontSize: 12),
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: const Color(0xFF2ECC71),
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 12,
                                      ),
                                    ),
                                    onPressed: () async {
                                      final newUID = await _showRFIDScanDialog(
                                        context,
                                        excludeStudentId: student?['id'],
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
                        const SizedBox(height: 24),

                        // Profile Image Section - CORRECTED
                        _buildSectionHeader('Profile Image'),
                        const SizedBox(height: 16),
                        Center(
                          child: Column(
                            children: [
                              // Display current image or placeholder
                              GestureDetector(
                                onTap: _pickImage,
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
                                  child:
                                      _selectedImagePath != null
                                          ? Image.network(
                                            _selectedImagePath!,
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                            errorBuilder: (
                                              context,
                                              error,
                                              stackTrace,
                                            ) {
                                              // If selected image fails to load, try to load it as a file path for web
                                              return FutureBuilder<Uint8List>(
                                                future: () async {
                                                  final response = await html
                                                      .HttpRequest.request(
                                                    _selectedImagePath!,
                                                  );
                                                  return Uint8List.fromList(
                                                    response.response.codeUnits,
                                                  );
                                                }(),
                                                builder: (context, snapshot) {
                                                  if (snapshot.hasData) {
                                                    return Image.memory(
                                                      snapshot.data!,
                                                      width: 120,
                                                      height: 120,
                                                      fit: BoxFit.cover,
                                                    );
                                                  }
                                                  return const Icon(
                                                    Icons.person,
                                                    size: 60,
                                                    color: Colors.grey,
                                                  );
                                                },
                                              );
                                            },
                                          )
                                          : (student?['profile_image_url'] !=
                                                  null &&
                                              student!['profile_image_url']
                                                  .toString()
                                                  .isNotEmpty)
                                          ? Image.network(
                                            student!['profile_image_url'],
                                            width: 120,
                                            height: 120,
                                            fit: BoxFit.cover,
                                            errorBuilder: (
                                              context,
                                              error,
                                              stackTrace,
                                            ) {
                                              return const Icon(
                                                Icons.person,
                                                size: 60,
                                                color: Colors.grey,
                                              );
                                            },
                                          )
                                          : const Icon(
                                            Icons.person,
                                            size: 60,
                                            color: Colors.grey,
                                          ),
                                ),
                              ),
                              const SizedBox(height: 12),
                              // Upload/Remove buttons
                              if (_selectedImagePath != null) ...[
                                ElevatedButton.icon(
                                  onPressed:
                                      _isUploadingImage
                                          ? null
                                          : () {
                                            _clearSelectedImage();
                                          },
                                  icon:
                                      _isUploadingImage
                                          ? const SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                            ),
                                          )
                                          : const Icon(Icons.clear),
                                  label: Text(
                                    _isUploadingImage
                                        ? 'Processing...'
                                        : 'Remove Image',
                                  ),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: Colors.red,
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 12,
                                    ),
                                  ),
                                ),
                              ] else ...[
                                ElevatedButton.icon(
                                  onPressed: _pickImage,
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
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                  ),
                  onPressed: () async {
                    if (formKey.currentState!.validate()) {
                      try {
                        // Validate RFID if provided
                        if (rfidUID != null && rfidUID!.isNotEmpty) {
                          setDialogState(() {
                            _isUploadingImage = true;
                          });

                          final isRFIDUnique = await _validateRFIDUniqueness(
                            rfidUID!,
                            excludeStudentId: student?['id'],
                          );

                          if (!isRFIDUnique) {
                            final existingStudent = await _checkRFIDExists(
                              rfidUID!,
                              excludeStudentId: student?['id'],
                            );
                            final studentName =
                                "${existingStudent?['fname'] ?? ''} ${existingStudent?['lname'] ?? ''}";

                            setDialogState(() {
                              _isUploadingImage = false;
                            });

                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Row(
                                    children: [
                                      const Icon(
                                        Icons.error,
                                        color: Colors.white,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          'RFID card is already assigned to $studentName',
                                        ),
                                      ),
                                    ],
                                  ),
                                  backgroundColor: Colors.red,
                                  behavior: SnackBarBehavior.floating,
                                  action: SnackBarAction(
                                    label: 'SCAN NEW',
                                    textColor: Colors.white,
                                    onPressed: () async {
                                      final newUID = await _showRFIDScanDialog(
                                        context,
                                        excludeStudentId: student?['id'],
                                      );
                                      if (newUID != null) {
                                        setDialogState(() {
                                          rfidUID = newUID;
                                        });
                                      }
                                    },
                                  ),
                                ),
                              );
                            }
                            return; // Stop execution if RFID is not unique
                          }
                        }
                        String? imageUrl =
                            _currentImageUrl ?? student?['profile_image_url'];

                        // Handle image upload if there's a selected image
                        if (_selectedImagePath != null) {
                          // First, create/update the student to get the ID for image naming
                          final tempPayload = {
                            'fname': fnameController.text.trim(),
                            'mname':
                                mnameController.text.trim().isEmpty
                                    ? null
                                    : mnameController.text.trim(),
                            'lname': lnameController.text.trim(),
                            'gender': selectedGender,
                            'address': addressController.text.trim(),
                            'birthday':
                                birthdayController.text.isEmpty
                                    ? null
                                    : birthdayController.text,
                            'grade_level': selectedGradeLevel,
                            'section_id': selectedSectionId,
                            'status': selectedStatus,
                            'rfid_uid':
                                rfidUID?.isEmpty == true ? null : rfidUID,
                            'profile_image_url':
                                student?['profile_image_url'], // Keep existing for now
                          };

                          int studentId;
                          if (student == null) {
                            // Insert new student first to get ID
                            final response =
                                await supabase
                                    .from('students')
                                    .insert(tempPayload)
                                    .select('id')
                                    .single();
                            studentId = response['id'];
                          } else {
                            studentId = student['id'];
                          }

                          // Now upload the image with the student ID
                          final XFile imageFile = XFile(_selectedImagePath!);
                          final uploadedUrl = await _uploadImageToSupabase(
                            imageFile,
                            studentId,
                          );

                          if (uploadedUrl != null) {
                            imageUrl = uploadedUrl;

                            // Delete old image if updating and there was a previous image
                            if (student != null &&
                                student['profile_image_url'] != null &&
                                student['profile_image_url']
                                    .toString()
                                    .isNotEmpty) {
                              await _deleteImageFromSupabase(
                                student['profile_image_url'],
                              );
                            }
                          } else {
                            // Upload failed, show error but don't prevent saving
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Image upload failed, but student data was saved',
                                  ),
                                  backgroundColor: Colors.orange,
                                ),
                              );
                            }
                          }
                        }

                        // Final payload with image URL
                        final payload = {
                          'fname': fnameController.text.trim(),
                          'mname':
                              mnameController.text.trim().isEmpty
                                  ? null
                                  : mnameController.text.trim(),
                          'lname': lnameController.text.trim(),
                          'gender': selectedGender,
                          'address': addressController.text.trim(),
                          'birthday':
                              birthdayController.text.isEmpty
                                  ? null
                                  : birthdayController.text,
                          'grade_level': selectedGradeLevel,
                          'section_id': selectedSectionId,
                          'status': selectedStatus,
                          'rfid_uid': rfidUID?.isEmpty == true ? null : rfidUID,
                          'profile_image_url': imageUrl,
                        };

                        if (student == null) {
                          // If we already inserted above (for image upload), update with image URL
                          if (_selectedImagePath != null) {
                            final response =
                                await supabase
                                    .from('students')
                                    .select('id')
                                    .eq('fname', payload['fname'] ?? '')
                                    .eq('lname', payload['lname'] ?? '')
                                    .single();
                            await supabase
                                .from('students')
                                .update(payload)
                                .eq('id', response['id']);
                          } else {
                            // No image, just insert normally
                            await supabase.from('students').insert(payload);
                          }
                        } else {
                          // Update existing student
                          await supabase
                              .from('students')
                              .update(payload)
                              .eq('id', student['id']);
                        }

                        // Reset state variables
                        setState(() {
                          _selectedImagePath = null;
                          _selectedImageBytes = null;
                          _currentImageUrl = null;
                          _isUploadingImage = false;
                        });

                        Navigator.pop(context);
                        _fetchStudents();

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
                                    student == null
                                        ? 'Student added successfully!'
                                        : 'Student updated successfully!',
                                  ),
                                ],
                              ),
                              backgroundColor: const Color(0xFF2ECC71),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      } catch (e) {
                        // Reset upload state on error
                        setDialogState(() {
                          _isUploadingImage = false;
                        });

                        // Show error message
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
                      Icon(student == null ? Icons.add : Icons.save, size: 16),
                      const SizedBox(width: 8),
                      Text(student == null ? 'Add Student' : 'Update Student'),
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
    addressController.dispose();
    birthdayController.dispose();
  }

  Future<Map<String, dynamic>?> _checkRFIDExists(
    String rfidUID, {
    int? excludeStudentId,
  }) async {
    try {
      var query = supabase
          .from('students')
          .select('id, fname, lname, grade_level, sections(name, grade_level)')
          .eq('rfid_uid', rfidUID);

      // If we're editing an existing student, exclude their current record
      if (excludeStudentId != null) {
        query = query.neq('id', excludeStudentId);
      }

      final response = await query.maybeSingle();
      return response;
    } catch (e) {
      print('Error checking RFID: $e');
      return null;
    }
  }

  Future<bool> _validateRFIDUniqueness(
    String rfidUID, {
    int? excludeStudentId,
  }) async {
    final existingStudent = await _checkRFIDExists(
      rfidUID,
      excludeStudentId: excludeStudentId,
    );
    return existingStudent == null;
  }

  void _toggleSelectAll(List<Map<String, dynamic>> currentPageItems) {
    setState(() {
      if (_selectAll) {
        _selectedStudents.clear();
      } else {
        _selectedStudents = currentPageItems.map((s) => s['id'] as int).toSet();
      }
      _selectAll = !_selectAll;
    });
  }

  void _toggleStudentSelection(
    int studentId,
    List<Map<String, dynamic>> currentPageItems,
  ) {
    setState(() {
      if (_selectedStudents.contains(studentId)) {
        _selectedStudents.remove(studentId);
      } else {
        _selectedStudents.add(studentId);
      }

      // Update select all state
      _selectAll = _selectedStudents.length == currentPageItems.length;
    });
  }

  void _exportSelectedStudents() {
    final selectedData =
        students.where((s) => _selectedStudents.contains(s['id'])).toList();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Exporting ${selectedData.length} selected students...'),
        backgroundColor: const Color(0xFF2ECC71),
      ),
    );

    // TODO: Implement actual export functionality
  }

  void _showBulkEditDialog() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                const Icon(Icons.edit, color: Color(0xFF2ECC71)),
                const SizedBox(width: 8),
                Text('Bulk Edit ${_selectedStudents.length} Students'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Select fields to update for ${_selectedStudents.length} selected students:',
                ),
                const SizedBox(height: 16),
                // Add bulk edit options here
                CheckboxListTile(
                  title: const Text('Grade Level'),
                  value: false,
                  onChanged: (value) {},
                ),
                CheckboxListTile(
                  title: const Text('Status'),
                  value: false,
                  onChanged: (value) {},
                ),
                CheckboxListTile(
                  title: const Text('Section'),
                  value: false,
                  onChanged: (value) {},
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // TODO: Implement bulk edit
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Bulk edit functionality coming soon...'),
                      backgroundColor: Colors.orange,
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                  foregroundColor: Colors.white,
                ),
                child: const Text('Apply Changes'),
              ),
            ],
          ),
    );
  }

  void _confirmBulkDelete() {
    showDialog(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.warning, color: Colors.red),
                SizedBox(width: 8),
                Text('Confirm Bulk Delete'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Are you sure you want to delete ${_selectedStudents.length} selected students?',
                  style: const TextStyle(fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 8),
                const Text(
                  'This action cannot be undone and will permanently remove all selected student records, including:',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.only(left: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '• Student profiles and data',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text(
                        '• Attendance records',
                        style: TextStyle(fontSize: 12),
                      ),
                      Text('• Profile images', style: TextStyle(fontSize: 12)),
                      Text(
                        '• RFID card assignments',
                        style: TextStyle(fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                ),
                onPressed: () async {
                  Navigator.pop(context);
                  await _performBulkDelete();
                },
                child: Text('Delete ${_selectedStudents.length} Students'),
              ),
            ],
          ),
    );
  }

  Future<void> _performBulkDelete() async {
    try {
      // Delete in batches to avoid overwhelming the database
      final selectedIds = _selectedStudents.toList();

      for (int i = 0; i < selectedIds.length; i += 10) {
        final batch = selectedIds.skip(i).take(10).toList();
        await supabase.from('students').delete().inFilter('id', batch);
      }

      setState(() {
        _selectedStudents.clear();
        _selectAll = false;
      });

      _fetchStudents(); // Refresh the list

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully deleted ${selectedIds.length} students'),
          backgroundColor: const Color(0xFF2ECC71),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error deleting students: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
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

  Future<void> _deleteStudent(int id) async {
    try {
      await supabase.from('students').delete().eq('id', id);
      _fetchStudents();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                Icon(Icons.check_circle, color: Colors.white),
                SizedBox(width: 8),
                Text('Student deleted successfully!'),
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
                Expanded(
                  child: Text('Error deleting student: ${e.toString()}'),
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

  void _exportData() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Export functionality would be implemented here'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  // Image picker function - CORRECTED
  Future<void> _pickImage() async {
    try {
      final ImagePicker picker = ImagePicker();
      final XFile? image = await picker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (image != null) {
        // For web, we need to read the bytes immediately
        final bytes = await image.readAsBytes();

        // Validate file size (max 5MB)
        if (bytes.length > 5 * 1024 * 1024) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Image size must be less than 5MB'),
                backgroundColor: Colors.red,
              ),
            );
          }
          return;
        }

        // Validate file type
        if (_validateImageBytes(bytes, image.name)) {
          setState(() {
            _selectedImagePath = image.name; // Store the name for reference
            _selectedImageBytes = bytes; // Store the actual bytes
          });
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error picking image: ${e.toString()}'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Image validation function - CORRECTED
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

    // Basic file signature validation for common formats
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

  // Upload image to Supabase Storage - CORRECTED
  Future<String?> _uploadImageToSupabase(XFile image, int studentId) async {
    try {
      setState(() => _isUploadingImage = true);

      // Use the stored bytes instead of reading from path
      Uint8List imageBytes;
      if (_selectedImageBytes != null) {
        imageBytes = _selectedImageBytes!;
      } else {
        imageBytes = await image.readAsBytes();
      }

      // Generate unique filename
      final String timestamp = DateTime.now().millisecondsSinceEpoch.toString();
      final String extension = image.name.split('.').last.toLowerCase();
      final String fileName = 'student_${studentId}_$timestamp.$extension';

      print('Uploading image: $fileName, Size: ${imageBytes.length} bytes');

      // Upload to Supabase Storage
      final String uploadPath = await supabase.storage
          .from('student-profiles')
          .uploadBinary(fileName, imageBytes);

      print('Upload successful: $uploadPath');

      // Get public URL
      final String publicUrl = supabase.storage
          .from('student-profiles')
          .getPublicUrl(fileName);

      print('Public URL: $publicUrl');

      return publicUrl;
    } catch (e) {
      print('Upload error: $e');
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

  // Delete image from Supabase Storage - CORRECTED
  Future<void> _deleteImageFromSupabase(String imageUrl) async {
    try {
      // Extract filename from URL
      final Uri uri = Uri.parse(imageUrl);
      final String fileName = uri.pathSegments.last;

      await supabase.storage.from('student-profiles').remove([fileName]);
    } catch (e) {
      print('Error deleting image: $e');
      // Don't show error to user as this is a cleanup operation
    }
  }

  // Clear selected image
  void _clearSelectedImage() {
    setState(() {
      _selectedImagePath = null;
      _selectedImageBytes = null;
    });
  }

  // Helper method to calculate time ago from enrollment date
  String _getTimeAgo(String enrollmentDate) {
    try {
      final enrollmentDateTime = DateTime.parse(enrollmentDate);
      final now = DateTime.now();
      final difference = now.difference(enrollmentDateTime);

      if (difference.inDays >= 365) {
        final years = (difference.inDays / 365).floor();
        return '$years year${years > 1 ? 's' : ''} ago';
      } else if (difference.inDays >= 30) {
        final months = (difference.inDays / 30).floor();
        return '$months month${months > 1 ? 's' : ''} ago';
      } else if (difference.inDays > 0) {
        return '${difference.inDays} day${difference.inDays > 1 ? 's' : ''} ago';
      } else if (difference.inHours > 0) {
        return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
      } else if (difference.inMinutes > 0) {
        return '${difference.inMinutes} minute${difference.inMinutes > 1 ? 's' : ''} ago';
      } else {
        return 'Just now';
      }
    } catch (e) {
      return '';
    }
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
              s['grade_level']?.toString() == _classFilter;
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
      if (grade != null && !classOptions.contains(grade)) {
        classOptions.add(grade);
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

            // Add this right before your table (after the filter row and SizedBox)

            // Bulk Actions Bar (show when students are selected)
            if (_selectedStudents.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(16),
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: const Color(0xFF2ECC71).withOpacity(0.3),
                  ),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle,
                      color: const Color(0xFF2ECC71),
                      size: 20,
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${_selectedStudents.length} student${_selectedStudents.length == 1 ? '' : 's'} selected',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF2ECC71),
                      ),
                    ),
                    const Spacer(),

                    // Bulk action buttons
                    TextButton.icon(
                      icon: const Icon(Icons.download, size: 16),
                      label: const Text('Export Selected'),
                      onPressed: _exportSelectedStudents,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2ECC71),
                      ),
                    ),
                    const SizedBox(width: 8),

                    TextButton.icon(
                      icon: const Icon(Icons.edit, size: 16),
                      label: const Text('Bulk Edit'),
                      onPressed: _showBulkEditDialog,
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2ECC71),
                      ),
                    ),
                    const SizedBox(width: 8),

                    if (isAdmin) ...[
                      TextButton.icon(
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('Delete Selected'),
                        onPressed: _confirmBulkDelete,
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                      const SizedBox(width: 8),
                    ],

                    TextButton(
                      onPressed:
                          () => setState(() => _selectedStudents.clear()),
                      child: const Text('Clear Selection'),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.grey[600],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // Table content
            if (isLoading || isLoadingSections)
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
                          child:
                          // Replace your entire Table widget (around line 2080) with this corrected version:
                          Table(
                            border: TableBorder(
                              horizontalInside: BorderSide(
                                color: Colors.grey[200]!,
                                width: 1,
                              ),
                            ),
                            columnWidths: const {
                              0: FlexColumnWidth(0.5), // Checkbox
                              1: FlexColumnWidth(0.8), // Student ID
                              2: FlexColumnWidth(2.0), // Name + Image
                              3: FlexColumnWidth(1.0), // Class
                              4: FlexColumnWidth(0.8), // Gender
                              5: FlexColumnWidth(1.2), // Contact
                              6: FlexColumnWidth(1.4), // Email
                              7: FlexColumnWidth(1.0), // Enrollment
                              8: FlexColumnWidth(0.8), // Status
                              9: FlexColumnWidth(0.6), // Actions
                            },
                            defaultVerticalAlignment:
                                TableCellVerticalAlignment.middle,
                            children: [
                              // Table header row
                              TableRow(
                                decoration: BoxDecoration(
                                  color: Colors.grey[50],
                                ),
                                children: [
                                  // Select all checkbox
                                  TableCell(
                                    child: Container(
                                      padding: const EdgeInsets.all(16),
                                      child: Checkbox(
                                        value: _selectAll,
                                        onChanged:
                                            (value) => _toggleSelectAll(
                                              currentPageItems,
                                            ),
                                        activeColor: const Color(0xFF2ECC71),
                                      ),
                                    ),
                                  ),
                                  const TableHeaderCell(text: 'Student ID'),
                                  const TableHeaderCell(text: 'Student Name'),
                                  const TableHeaderCell(text: 'Class'),
                                  const TableHeaderCell(text: 'Gender'),
                                  const TableHeaderCell(text: 'Contact Number'),
                                  const TableHeaderCell(text: 'Email'),
                                  const TableHeaderCell(
                                    text: 'Enrollment Date',
                                  ),
                                  const TableHeaderCell(text: 'Status'),
                                  const TableHeaderCell(text: 'Actions'),
                                ],
                              ),

                              // Table data rows - CORRECTED STRUCTURE
                              ...currentPageItems.map((student) {
                                final fullName =
                                    "${student['fname'] ?? ''} ${student['lname'] ?? ''}";
                                final String studentId =
                                    "STU${student['id'].toString().padLeft(3, '0')}";
                                final section = student['sections'];
                                final String className =
                                    section != null
                                        ? "${section['name']} (${section['grade_level']})"
                                        : "N/A";
                                final enrollmentDate =
                                    student['created_at'] != null
                                        ? DateFormat('yyyy-MM-dd').format(
                                          DateTime.parse(student['created_at']),
                                        )
                                        : "N/A";
                                final status = student['status'] ?? 'Active';
                                final profileImageUrl =
                                    student['profile_image_url']?.toString();

                                return TableRow(
                                  decoration: BoxDecoration(
                                    color:
                                        _selectedStudents.contains(
                                              student['id'],
                                            )
                                            ? const Color(
                                              0xFF2ECC71,
                                            ).withOpacity(0.1)
                                            : Colors.white,
                                  ),
                                  children: [
                                    // 1. Selection checkbox
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Container(
                                        padding: const EdgeInsets.all(16),
                                        child: Checkbox(
                                          value: _selectedStudents.contains(
                                            student['id'],
                                          ),
                                          onChanged:
                                              (value) =>
                                                  _toggleStudentSelection(
                                                    student['id'],
                                                    currentPageItems,
                                                  ),
                                          activeColor: const Color(0xFF2ECC71),
                                        ),
                                      ),
                                    ),

                                    // 2. Student ID
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
                                            fontSize: 13,
                                          ),
                                        ),
                                      ),
                                    ),

                                    // 3. Student name WITH PROFILE IMAGE
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
                                                    _selectedImageBytes != null
                                                        ? Image.memory(
                                                          _selectedImageBytes!,
                                                          width: 120,
                                                          height: 120,
                                                          fit: BoxFit.cover,
                                                        )
                                                        : (student?['profile_image_url'] !=
                                                                null &&
                                                            student!['profile_image_url']
                                                                .toString()
                                                                .isNotEmpty)
                                                        ? Image.network(
                                                          student!['profile_image_url'],
                                                          width: 120,
                                                          height: 120,
                                                          fit: BoxFit.cover,
                                                          errorBuilder: (
                                                            context,
                                                            error,
                                                            stackTrace,
                                                          ) {
                                                            return const Icon(
                                                              Icons.person,
                                                              size: 60,
                                                              color:
                                                                  Colors.grey,
                                                            );
                                                          },
                                                          loadingBuilder: (
                                                            context,
                                                            child,
                                                            loadingProgress,
                                                          ) {
                                                            if (loadingProgress ==
                                                                null)
                                                              return child;
                                                            return Container(
                                                              width: 120,
                                                              height: 120,
                                                              color:
                                                                  Colors
                                                                      .grey[200],
                                                              child: const Center(
                                                                child: CircularProgressIndicator(
                                                                  color: Color(
                                                                    0xFF2ECC71,
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          },
                                                        )
                                                        : const Icon(
                                                          Icons.person,
                                                          size: 60,
                                                          color: Colors.grey,
                                                        ),
                                              ),
                                            ),
                                            const SizedBox(width: 12),
                                            // Student Name
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
                                                  if (student['rfid_uid'] !=
                                                          null &&
                                                      student['rfid_uid']
                                                          .toString()
                                                          .isNotEmpty) ...[
                                                    const SizedBox(height: 2),
                                                    Row(
                                                      children: [
                                                        Icon(
                                                          Icons.contactless,
                                                          size: 12,
                                                          color:
                                                              Colors.green[600],
                                                        ),
                                                        const SizedBox(
                                                          width: 4,
                                                        ),
                                                        Text(
                                                          'RFID: ${student['rfid_uid'].toString().substring(0, 8)}...',
                                                          style: TextStyle(
                                                            fontSize: 11,
                                                            color:
                                                                Colors
                                                                    .green[600],
                                                            fontWeight:
                                                                FontWeight.w500,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
                                                  ],
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // 4. Class
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
                                            color: const Color(
                                              0xFF2ECC71,
                                            ).withOpacity(0.1),
                                            borderRadius: BorderRadius.circular(
                                              12,
                                            ),
                                          ),
                                          child: Text(
                                            className,
                                            style: const TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF2ECC71),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),

                                    // 5. Gender
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16),
                                        child: Row(
                                          children: [
                                            Icon(
                                              student['gender'] == 'Male'
                                                  ? Icons.male
                                                  : student['gender'] ==
                                                      'Female'
                                                  ? Icons.female
                                                  : Icons.person,
                                              size: 16,
                                              color:
                                                  student['gender'] == 'Male'
                                                      ? Colors.blue[600]
                                                      : student['gender'] ==
                                                          'Female'
                                                      ? Colors.pink[600]
                                                      : Colors.grey[600],
                                            ),
                                            const SizedBox(width: 6),
                                            Text(
                                              student['gender'] ?? 'N/A',
                                              style: const TextStyle(
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),

                                    // 6. Contact number
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16),
                                        child:
                                            student['contact_number'] != null &&
                                                    student['contact_number']
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
                                                      student['contact_number'],
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

                                    // 7. Email
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16),
                                        child:
                                            student['email'] != null &&
                                                    student['email']
                                                        .toString()
                                                        .isNotEmpty
                                                ? Row(
                                                  children: [
                                                    Icon(
                                                      Icons.email,
                                                      size: 14,
                                                      color: Colors.grey[600],
                                                    ),
                                                    const SizedBox(width: 6),
                                                    Expanded(
                                                      child: Text(
                                                        student['email'],
                                                        style: const TextStyle(
                                                          fontSize: 13,
                                                        ),
                                                        overflow:
                                                            TextOverflow
                                                                .ellipsis,
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

                                    // 8. Enrollment date
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Container(
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.all(16),
                                        child: Column(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.center,
                                          children: [
                                            Text(
                                              enrollmentDate,
                                              style: const TextStyle(
                                                fontSize: 13,
                                                fontWeight: FontWeight.w500,
                                              ),
                                            ),
                                            if (enrollmentDate != 'N/A') ...[
                                              const SizedBox(height: 2),
                                              Text(
                                                _getTimeAgo(enrollmentDate),
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  color: Colors.grey[600],
                                                ),
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                    ),

                                    // 9. Status
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

                                    // 10. Actions
                                    TableCell(
                                      verticalAlignment:
                                          TableCellVerticalAlignment.middle,
                                      child: Center(
                                        child: PopupMenuButton<String>(
                                          icon: Icon(
                                            Icons.more_vert,
                                            color: Colors.grey[600],
                                          ),
                                          iconSize: 20,
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
                                                      title: const Row(
                                                        children: [
                                                          Icon(
                                                            Icons.warning,
                                                            color: Colors.red,
                                                          ),
                                                          SizedBox(width: 8),
                                                          Text(
                                                            'Confirm Delete',
                                                          ),
                                                        ],
                                                      ),
                                                      content: Column(
                                                        mainAxisSize:
                                                            MainAxisSize.min,
                                                        crossAxisAlignment:
                                                            CrossAxisAlignment
                                                                .start,
                                                        children: [
                                                          Text(
                                                            'Are you sure you want to delete ${student['fname']} ${student['lname']}?',
                                                            style:
                                                                const TextStyle(
                                                                  fontWeight:
                                                                      FontWeight
                                                                          .w500,
                                                                ),
                                                          ),
                                                          const SizedBox(
                                                            height: 8,
                                                          ),
                                                          const Text(
                                                            'This action cannot be undone and will permanently remove:',
                                                            style: TextStyle(
                                                              fontSize: 13,
                                                            ),
                                                          ),
                                                          const SizedBox(
                                                            height: 8,
                                                          ),
                                                          Padding(
                                                            padding:
                                                                const EdgeInsets.only(
                                                                  left: 16,
                                                                ),
                                                            child: Column(
                                                              crossAxisAlignment:
                                                                  CrossAxisAlignment
                                                                      .start,
                                                              children: [
                                                                const Text(
                                                                  '• Student profile and data',
                                                                  style:
                                                                      TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                      ),
                                                                ),
                                                                const Text(
                                                                  '• Attendance records',
                                                                  style:
                                                                      TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                      ),
                                                                ),
                                                                const Text(
                                                                  '• Profile image',
                                                                  style:
                                                                      TextStyle(
                                                                        fontSize:
                                                                            12,
                                                                      ),
                                                                ),
                                                                if (student['rfid_uid'] !=
                                                                    null)
                                                                  const Text(
                                                                    '• RFID card assignment',
                                                                    style: TextStyle(
                                                                      fontSize:
                                                                          12,
                                                                    ),
                                                                  ),
                                                              ],
                                                            ),
                                                          ),
                                                        ],
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
                                                                foregroundColor:
                                                                    Colors
                                                                        .white,
                                                              ),
                                                          onPressed: () {
                                                            Navigator.pop(ctx);
                                                            _deleteStudent(
                                                              student['id'],
                                                            );
                                                          },
                                                          child: const Text(
                                                            'Delete Student',
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
                                                      SizedBox(width: 8),
                                                      Text('Edit Student'),
                                                    ],
                                                  ),
                                                ),
                                                if (isAdmin)
                                                  const PopupMenuItem(
                                                    value: 'delete',
                                                    child: Row(
                                                      children: [
                                                        Icon(
                                                          Icons.delete,
                                                          size: 16,
                                                          color: Colors.red,
                                                        ),
                                                        SizedBox(width: 8),
                                                        Text(
                                                          'Delete Student',
                                                          style: TextStyle(
                                                            color: Colors.red,
                                                          ),
                                                        ),
                                                      ],
                                                    ),
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

                    // Enhanced Pagination with more controls
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
                                        'Total: ${filteredStudents.length} students',
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
                                  'Showing ${currentPageItems.isEmpty ? 0 : startIndex + 1} to $endIndex of ${filteredStudents.length} entries',
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
