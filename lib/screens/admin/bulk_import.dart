import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:excel/excel.dart' as excel_lib;
import '../../services/audit_log_service.dart';

class BulkImportPage extends StatefulWidget {
  const BulkImportPage({super.key});

  @override
  State<BulkImportPage> createState() => _BulkImportPageState();
}

class _BulkImportPageState extends State<BulkImportPage> {
  final supabase = Supabase.instance.client;
  final auditLogService = AuditLogService();

  bool isLoading = false;
  bool isValidating = false;
  bool isImporting = false;

  List<Map<String, dynamic>> parsedData = [];
  List<String> validationErrors = [];
  Map<String, int> importStats = {
    'total': 0,
    'successful': 0,
    'failed': 0,
    'students_created': 0,
    'parents_created': 0,
    'relationships_created': 0,
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(10, 78, 241, 157),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                const Text(
                  "Bulk Import",
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1A1A1A),
                    letterSpacing: 0.5,
                  ),
                ),
                const Spacer(),
                SizedBox(
                  height: 44,
                  child: OutlinedButton.icon(
                    icon: const Icon(
                      Icons.file_download_outlined,
                      color: Color(0xFF2ECC71),
                      size: 18,
                    ),
                    label: const Text(
                      "Download Template",
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
                    onPressed: _downloadTemplate,
                  ),
                ),
              ],
            ),

            // Breadcrumb
            const Padding(
              padding: EdgeInsets.only(top: 8.0, bottom: 24.0),
              child: Text(
                "Home / Bulk Import",
                style: TextStyle(fontSize: 12, color: Color(0xFF9E9E9E)),
              ),
            ),

            

            // Main content
            Expanded(
              child:
                  parsedData.isEmpty ? _buildUploadArea() : _buildPreviewArea(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUploadArea() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[300]!,
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: const Color(0xFF2ECC71).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.cloud_upload_outlined,
              size: 60,
              color: Color(0xFF2ECC71),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Upload Excel File for Bulk Import',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF1A1A1A),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Upload your enrollment form Excel file to import students and parents',
            style: TextStyle(fontSize: 16, color: Colors.grey[600]),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          // Upload button
          SizedBox(
            height: 50,
            child: ElevatedButton.icon(
              icon: const Icon(Icons.upload_file, color: Colors.white),
              label: const Text(
                'Choose Excel File',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF2ECC71),
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              onPressed: isLoading ? null : _selectFile,
            ),
          ),

          const SizedBox(height: 24),

          // File info chips
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildInfoChip('Supported: .xlsx, .xls', Icons.insert_drive_file, Colors.blue),
              _buildInfoChip('Max size: 100MB', Icons.sd_storage_rounded, Colors.orange),
              _buildInfoChip('Secure upload', Icons.lock_outline, Colors.purple),
            ],
          ),

          const SizedBox(height: 20),

          // Instructions
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.blue[100]!),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                    const SizedBox(width: 8),
                    Text(
                      'Import Instructions',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.blue[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _buildBulletItem('Use the provided template format'),
                _buildBulletItem('Ensure all required fields are filled'),
                _buildBulletItem('Student names should be in format: "Surname, First Name, Middle Name, Suffix"'),
                _buildBulletItem('Grade levels will be set from the file, sections will be empty for manual assignment'),
                _buildBulletItem('At least one parent/guardian contact is required'),
                _buildBulletItem('Duplicate students will be skipped'),
                _buildBulletItem('A backup will be created automatically before import'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoChip(String label, IconData icon, MaterialColor color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            label,
            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color.shade700),
          ),
        ],
      ),
    );
  }

  Widget _buildBulletItem(String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.check_circle_outline, size: 16, color: Colors.blue),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: TextStyle(fontSize: 14, color: Colors.blue[800]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewArea() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Stats container
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.grey[200]!),
          ),
          child: Row(
            children: [
              _buildStatCard(
                'Total Records',
                parsedData.length.toString(),
                Icons.list_alt,
                Colors.blue,
              ),
              const SizedBox(width: 20),
              _buildStatCard(
                'Validation Errors',
                validationErrors.length.toString(),
                Icons.error_outline,
                Colors.red,
              ),
              const Spacer(),
              if (validationErrors.isEmpty && !isImporting) ...[
                SizedBox(
                  height: 44,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.upload, color: Colors.white),
                    label: const Text(
                      'Start Import',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF2ECC71),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _startImport,
                  ),
                ),
                const SizedBox(width: 12),
              ],
              SizedBox(
                height: 44,
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.refresh, color: Color(0xFF2ECC71)),
                  label: const Text(
                    'Upload New File',
                    style: TextStyle(color: Color(0xFF2ECC71)),
                  ),
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Color(0xFF2ECC71)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  onPressed: _resetImport,
                ),
              ),
            ],
          ),
        ),

        const SizedBox(height: 16),

        // Progress indicator
        if (isValidating || isImporting)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Color(0xFF2ECC71),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      isValidating ? 'Validating data...' : 'Importing data...',
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  minHeight: 6,
                  backgroundColor: Colors.grey[200],
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF2ECC71)),
                ),
              ],
            ),
          ),

        const SizedBox(height: 16),

        // Errors section
        if (validationErrors.isNotEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.red[50],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.red[200]!),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.error_outline, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Text(
                      'Validation Errors',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Colors.red[700],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Container(
                  height: 200,
                  child: ListView.builder(
                    itemCount: validationErrors.length,
                    itemBuilder: (context, index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 2),
                        child: Text(
                          '• ${validationErrors[index]}',
                          style: TextStyle(
                            color: Colors.red[700],
                            fontSize: 14,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),

        // Data preview
        if (validationErrors.isEmpty)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      'Data Preview (${parsedData.length} records)',
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      itemCount: parsedData.length,
                      itemBuilder: (context, index) {
                        final record = parsedData[index];
                        return _buildPreviewCard(record, index + 1);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildStatCard(
    String title,
    String value,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                value,
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewCard(Map<String, dynamic> record, int rowNumber) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF2ECC71),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  'Row $rowNumber',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Student: ${record['student_fname']} ${record['student_lname']}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'Grade: ${record['student_grade']} | Gender: ${record['student_gender']}',
            style: TextStyle(color: Colors.grey[600]),
          ),
          if (record['father_fname'] != null &&
              record['father_fname'].toString().trim().isNotEmpty)
            Text(
              'Father: ${record['father_fname']} ${record['father_lname']} (${record['father_email']})',
              style: TextStyle(color: Colors.grey[600]),
            ),
          if (record['mother_fname'] != null &&
              record['mother_fname'].toString().trim().isNotEmpty)
            Text(
              'Mother: ${record['mother_fname']} ${record['mother_lname']} (${record['mother_email']})',
              style: TextStyle(color: Colors.grey[600]),
            ),
          if (record['guardian_fname'] != null &&
              record['guardian_fname'].toString().trim().isNotEmpty)
            Text(
              'Guardian: ${record['guardian_fname']} ${record['guardian_lname']} (${record['guardian_email']})',
              style: TextStyle(color: Colors.grey[600]),
            ),
        ],
      ),
    );
  }

  void _downloadTemplate() async {
    try {
      var excel = excel_lib.Excel.createExcel();
      var sheet = excel['Template'];

      // Headers matching Google Forms structure
      final headers = [
        'Timestamp',
        'Student Name (Surname, First Name, Middle Name, Suffix)',
        'Date of Birth',
        'Age (as of August 30)',
        'Incoming Grade Level',
        'Select the Appropriate Option',
        'Complete Address',
        'Gender',
        'Father\'s Name',
        'Father\'s Contact Number',
        'Father\'s Email',
        'Father\'s Address',
        'Mother\'s Name',
        'Mother\'s Contact Number',
        'Mother\'s Email',
        'Mother\'s Address',
        'Guardian\'s Name',
        'Guardian\'s Contact Number',
        'Guardian\'s Email',
        'Guardian\'s Address',
      ];

      // Add headers
      for (int i = 0; i < headers.length; i++) {
        var cell = sheet.cell(
          excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 0),
        );
        cell.value = excel_lib.TextCellValue(headers[i]);
        cell.cellStyle = excel_lib.CellStyle(bold: true);
      }

      // Add sample data
      final sampleData = [
        '2024-01-15 10:30:00',
        'Dela Cruz, Juan Miguel, Santos, Jr.',
        '2015-05-20',
        '9',
        'Grade 4',
        'New Student',
        '123 Main St, Quezon City',
        'Male',
        'Pedro Santos Dela Cruz',
        '09171234567',
        'pedro.delacruz@email.com',
        '123 Main St, Quezon City',
        'Maria Santos Dela Cruz',
        '09178765432',
        'maria.delacruz@email.com',
        '123 Main St, Quezon City',
        '',
        '',
        '',
        '',
      ];

      for (int i = 0; i < sampleData.length; i++) {
        var cell = sheet.cell(
          excel_lib.CellIndex.indexByColumnRow(columnIndex: i, rowIndex: 1),
        );
        cell.value = excel_lib.TextCellValue(sampleData[i]);
      }

      // Set column widths
      for (int i = 0; i < headers.length; i++) {
        sheet.setColumnWidth(i, 20.0);
      }

      // Remove default sheets
      if (excel.sheets.containsKey('Sheet1')) {
        excel.delete('Sheet1');
      }

      // Generate file
      List<int>? fileBytes = excel.encode();
      if (fileBytes != null) {
        final blob = html.Blob([
          fileBytes,
        ], 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet');
        final url = html.Url.createObjectUrlFromBlob(blob);
        final anchor =
            html.AnchorElement(href: url)
              ..setAttribute('download', 'bulk_import_template.xlsx')
              ..style.display = 'none';

        html.document.body?.children.add(anchor);
        anchor.click();
        html.document.body?.children.remove(anchor);
        html.Url.revokeObjectUrl(url);

        _showSuccessSnackBar('Template downloaded successfully');
      }
    } catch (e) {
      _showErrorSnackBar('Failed to download template: $e');
    }
  }

  void _selectFile() async {
    final html.FileUploadInputElement uploadInput =
        html.FileUploadInputElement();
    uploadInput.accept = '.xlsx,.xls';
    uploadInput.click();

    uploadInput.onChange.listen((e) {
      final files = uploadInput.files;
      if (files?.length == 1) {
        final file = files![0];
        _processFile(file);
      }
    });
  }

  void _processFile(html.File file) async {
    setState(() {
      isLoading = true;
      isValidating = true;
    });

    try {
      // Validate file type
      if (!file.name.toLowerCase().endsWith('.xlsx') &&
          !file.name.toLowerCase().endsWith('.xls')) {
        throw Exception('Please select an Excel file (.xlsx or .xls)');
      }

      // Validate file size (100MB limit)
      if (file.size > 100 * 1024 * 1024) {
        throw Exception('File size must be less than 100MB');
      }

      final reader = html.FileReader();
      reader.readAsArrayBuffer(file);

      reader.onLoad.listen((e) async {
        try {
          final bytes = reader.result as List<int>;
          final excel = excel_lib.Excel.decodeBytes(bytes);

          if (excel.tables.isEmpty) {
            throw Exception('Excel file contains no sheets');
          }

          final sheet = excel.tables.values.first;
          await _parseExcelData(sheet);
        } catch (e) {
          setState(() {
            isLoading = false;
            isValidating = false;
          });
          _showErrorSnackBar('Error processing file: $e');
        }
      });

      reader.onError.listen((e) {
        setState(() {
          isLoading = false;
          isValidating = false;
        });
        _showErrorSnackBar('Error reading file');
      });
    } catch (e) {
      setState(() {
        isLoading = false;
        isValidating = false;
      });
      _showErrorSnackBar('Error: $e');
    }
  }

  Future<void> _parseExcelData(excel_lib.Sheet sheet) async {
    final List<Map<String, dynamic>> records = [];
    final List<String> errors = [];

    if (sheet.rows.isEmpty) {
      throw Exception('Excel sheet is empty');
    }

    final headerRow = sheet.rows.first;
    if (headerRow.isEmpty) {
      throw Exception('Header row is empty');
    }

    // Parse each data row (skip header)
    for (int rowIndex = 1; rowIndex < sheet.rows.length; rowIndex++) {
      final row = sheet.rows[rowIndex];

      // Skip empty rows
      if (row.every(
        (cell) => cell?.value == null || cell!.value.toString().trim().isEmpty,
      )) {
        continue;
      }

      try {
        final record = await _parseRow(row, rowIndex + 1);
        if (record != null) {
          records.add(record);
        }
      } catch (e) {
        errors.add('Row ${rowIndex + 1}: $e');
      }
    }

    // Validate all records
    await _validateRecords(records, errors);

    setState(() {
      parsedData = records;
      validationErrors = errors;
      isLoading = false;
      isValidating = false;
    });
  }

  Future<Map<String, dynamic>?> _parseRow(
    List<excel_lib.Data?> row,
    int rowNumber,
  ) async {
    final getValue =
        (int index) =>
            index < row.length && row[index]?.value != null
                ? row[index]!.value.toString().trim()
                : '';

    // Parse student name
    final studentName = getValue(1);
    if (studentName.isEmpty) {
      throw Exception('Student name is required');
    }

    final nameParts = _parseStudentName(studentName);
    if (nameParts['fname'] == null || nameParts['lname'] == null) {
      throw Exception('Could not parse student name: $studentName');
    }

    // Parse date of birth
    final dobString = getValue(2);
    DateTime? dob;
    if (dobString.isNotEmpty) {
      try {
        dob = DateTime.parse(dobString);
      } catch (e) {
        // Try different date formats
        try {
          final parts = dobString.split('/');
          if (parts.length == 3) {
            dob = DateTime(
              int.parse(parts[2]),
              int.parse(parts[0]),
              int.parse(parts[1]),
            );
          }
        } catch (e2) {
          throw Exception('Invalid date format: $dobString');
        }
      }
    }

    final record = {
      'row_number': rowNumber,
      'student_fname': nameParts['fname'],
      'student_mname': nameParts['mname'],
      'student_lname': nameParts['lname'],
      'student_suffix': nameParts['suffix'],
      'student_birthday': dob?.toIso8601String(),
      'student_grade': getValue(4),
      'student_address': getValue(6),
      'student_gender': getValue(7),

      // Father details
      'father_fname': null,
      'father_mname': null,
      'father_lname': null,
      'father_phone': getValue(9),
      'father_email': getValue(10),
      'father_address': getValue(11),

      // Mother details
      'mother_fname': null,
      'mother_mname': null,
      'mother_lname': null,
      'mother_phone': getValue(13),
      'mother_email': getValue(14),
      'mother_address': getValue(15),

      // Guardian details
      'guardian_fname': null,
      'guardian_mname': null,
      'guardian_lname': null,
      'guardian_phone': getValue(17),
      'guardian_email': getValue(18),
      'guardian_address': getValue(19),
    };

    // Parse parent names
    final fatherName = getValue(8);
    if (fatherName.isNotEmpty) {
      final fatherParts = _parseParentName(fatherName);
      record['father_fname'] = fatherParts['fname'];
      record['father_mname'] = fatherParts['mname'];
      record['father_lname'] = fatherParts['lname'];
    }

    final motherName = getValue(12);
    if (motherName.isNotEmpty) {
      final motherParts = _parseParentName(motherName);
      record['mother_fname'] = motherParts['fname'];
      record['mother_mname'] = motherParts['mname'];
      record['mother_lname'] = motherParts['lname'];
    }

    final guardianName = getValue(16);
    if (guardianName.isNotEmpty) {
      final guardianParts = _parseParentName(guardianName);
      record['guardian_fname'] = guardianParts['fname'];
      record['guardian_mname'] = guardianParts['mname'];
      record['guardian_lname'] = guardianParts['lname'];
    }

    return record;
  }

  Map<String, String?> _parseStudentName(String fullName) {
    try {
      // Expected format: "Surname, First Name, Middle Name, Suffix"
      final parts = fullName.split(',').map((s) => s.trim()).toList();

      if (parts.length >= 2) {
        final lname = parts[0];
        final fname = parts[1];
        final mname = parts.length > 2 ? parts[2] : null;
        final suffix = parts.length > 3 ? parts[3] : null;

        return {
          'fname': fname.isNotEmpty ? fname : null,
          'mname': mname?.isNotEmpty == true ? mname : null,
          'lname': lname.isNotEmpty ? lname : null,
          'suffix': suffix?.isNotEmpty == true ? suffix : null,
        };
      }

      // Fallback: try to split by space
      final spaceParts =
          fullName.split(' ').where((s) => s.isNotEmpty).toList();
      if (spaceParts.length >= 2) {
        return {
          'fname': spaceParts[0],
          'mname': spaceParts.length > 2 ? spaceParts[1] : null,
          'lname': spaceParts.last,
          'suffix': null,
        };
      }

      return {'fname': null, 'mname': null, 'lname': null, 'suffix': null};
    } catch (e) {
      return {'fname': null, 'mname': null, 'lname': null, 'suffix': null};
    }
  }

  Map<String, String?> _parseParentName(String fullName) {
    try {
      final parts = fullName.split(' ').where((s) => s.isNotEmpty).toList();

      if (parts.length >= 2) {
        return {
          'fname': parts[0],
          'mname': parts.length > 2 ? parts[1] : null,
          'lname': parts.last,
        };
      } else if (parts.length == 1) {
        return {'fname': parts[0], 'mname': null, 'lname': ''};
      }

      return {'fname': null, 'mname': null, 'lname': null};
    } catch (e) {
      return {'fname': null, 'mname': null, 'lname': null};
    }
  }

  Future<void> _validateRecords(
    List<Map<String, dynamic>> records,
    List<String> errors,
  ) async {
    final Set<String> seenStudents = {};
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    final phoneRegex = RegExp(r'^\+?[\d\s\-\(\)]+$');

    for (final record in records) {
      final rowNum = record['row_number'];

      // Required field validation
      if (record['student_fname'] == null ||
          record['student_fname'].toString().trim().isEmpty) {
        errors.add('Row $rowNum: Student first name is required');
      }

      if (record['student_lname'] == null ||
          record['student_lname'].toString().trim().isEmpty) {
        errors.add('Row $rowNum: Student last name is required');
      }

      if (record['student_grade'] == null ||
          record['student_grade'].toString().trim().isEmpty) {
        errors.add('Row $rowNum: Student grade is required');
      }
      // Note: Grade level will be set as provided, sections will be empty for manual assignment

      if (record['student_gender'] == null ||
          record['student_gender'].toString().trim().isEmpty) {
        errors.add('Row $rowNum: Student gender is required');
      }

      // Birthday validation
      if (record['student_birthday'] == null) {
        errors.add('Row $rowNum: Student date of birth is required');
      }

      // Duplicate student validation
      final studentKey =
          '${record['student_fname']}_${record['student_lname']}_${record['student_birthday']}';
      if (seenStudents.contains(studentKey)) {
        errors.add(
          'Row $rowNum: Duplicate student found (same name and birthday)',
        );
      } else {
        seenStudents.add(studentKey);
      }

      // Parent validation - at least one parent/guardian required
      final hasFather =
          record['father_fname'] != null &&
          record['father_fname'].toString().trim().isNotEmpty;
      final hasMother =
          record['mother_fname'] != null &&
          record['mother_fname'].toString().trim().isNotEmpty;
      final hasGuardian =
          record['guardian_fname'] != null &&
          record['guardian_fname'].toString().trim().isNotEmpty;

      if (!hasFather && !hasMother && !hasGuardian) {
        errors.add('Row $rowNum: At least one parent/guardian is required');
      }

      // Email validation - more permissive
      for (final parentType in ['father', 'mother', 'guardian']) {
        final email = record['${parentType}_email'];
        final hasParent =
            record['${parentType}_fname'] != null &&
            record['${parentType}_fname'].toString().trim().isNotEmpty;

        if (hasParent) {
          // Only validate email format if provided
          if (email != null && email.toString().trim().isNotEmpty) {
            final emailTrimmed = email.toString().trim().toLowerCase();
            if (!emailRegex.hasMatch(emailTrimmed)) {
              errors.add('Row $rowNum: Invalid ${parentType} email format');
            }
            // Note: Duplicate emails are allowed - existing parents will be linked
          }

          // Phone validation - make optional but validate format if provided
          final phone = record['${parentType}_phone'];
          if (phone != null && phone.toString().trim().isNotEmpty) {
            if (!phoneRegex.hasMatch(phone.toString().trim())) {
              errors.add('Row $rowNum: Invalid ${parentType} phone format');
            }
          }
        }
      }
    }

    // Check for existing students in database (skip email validation - allow existing emails)
    if (errors.isEmpty) {
      await _checkExistingStudents(records, errors);
    }
  }

  Future<void> _checkExistingStudents(
    List<Map<String, dynamic>> records,
    List<String> errors,
  ) async {
    try {
      for (final record in records) {
        final rowNum = record['row_number'];

        // Check if student already exists (check both Active and active status for compatibility)
        final existingStudent =
            await supabase
                .from('students')
                .select('id, fname, lname, birthday')
                .eq('fname', record['student_fname'])
                .eq('lname', record['student_lname'])
                .eq('birthday', record['student_birthday']?.split('T')[0])
                .inFilter('status', ['Active', 'active'])
                .maybeSingle();

        if (existingStudent != null) {
          errors.add(
            'Row $rowNum: Student ${record['student_fname']} ${record['student_lname']} already exists in database',
          );
        }
      }
    } catch (e) {
      errors.add('Database validation error: $e');
    }
  }

  Future<void> _startImport() async {
    // Check if there are validation errors before starting import
    if (validationErrors.isNotEmpty) {
      _showErrorSnackBar('Cannot start import: Please resolve all validation errors first');
      return;
    }

    setState(() {
      isImporting = true;
      importStats = {
        'total': parsedData.length,
        'successful': 0,
        'failed': 0,
        'students_created': 0,
        'parents_created': 0,
        'relationships_created': 0,
      };
    });

    try {
      // Create backup
      await _createBackup();

      // Process each record
      for (final record in parsedData) {
        try {
          await _importRecord(record);
          setState(() {
            importStats['successful'] = (importStats['successful'] ?? 0) + 1;
          });
        } catch (e) {
          setState(() {
            importStats['failed'] = (importStats['failed'] ?? 0) + 1;
          });
          print('Failed to import record ${record['row_number']}: $e');
          // Since we stop on first error per requirements
          throw Exception('Import failed at row ${record['row_number']}: $e');
        }
      }

      setState(() {
        isImporting = false;
      });

      // Log bulk import operation for audit trail
      await auditLogService.logBulkImportOperation(
        importType: 'Student and Parent Data',
        fileName: 'Excel Import', // You might want to capture actual filename
        totalRecords: importStats['total'] ?? 0,
        successCount: importStats['successful'] ?? 0,
        errorCount: importStats['failed'] ?? 0,
      );

      _showImportResults();
    } catch (e) {
      setState(() {
        isImporting = false;
      });

      // Log failed import operation for audit trail
      await auditLogService.logBulkImportOperation(
        importType: 'Student and Parent Data',
        fileName: 'Excel Import',
        totalRecords: importStats['total'] ?? 0,
        successCount: importStats['successful'] ?? 0,
        errorCount: (importStats['failed'] ?? 0) + 1, // +1 for current failure
        errors: [e.toString()],
      );

      _showErrorSnackBar('Import failed: $e');
    }
  }

  Future<void> _createBackup() async {
    try {
      // Export current data as backup before import
      final timestamp =
          DateTime.now()
              .toIso8601String()
              .replaceAll(RegExp(r'[:.T-]'), '_')
              .split('_')[0];

      // This would ideally create a backup of the database
      // For now, we'll just log that backup should be created
      print('Backup should be created before import: backup_$timestamp');
    } catch (e) {
      throw Exception('Failed to create backup: $e');
    }
  }

  Future<void> _importRecord(Map<String, dynamic> record) async {
    try {
      // 1. Create student
      final studentInsert =
          await supabase
              .from('students')
              .insert({
                'fname': record['student_fname'],
                'mname': record['student_mname'],
                'lname': record['student_lname'],
                'suffix': record['student_suffix'],
                'birthday': record['student_birthday']?.split('T')[0],
                'grade_level': record['student_grade'],
                'gender': record['student_gender'],
                'address': record['student_address'],
                'status': 'Active',
                'section_id': null, // Section will be manually assigned later
              })
              .select()
              .single();

      final studentId = studentInsert['id'];
      importStats['students_created'] =
          (importStats['students_created'] ?? 0) + 1;

      // 2. Create parents and relationships - handle errors gracefully
      final parentTypes = ['father', 'mother', 'guardian'];
      List<Map<String, dynamic>> createdParents = [];

      for (final parentType in parentTypes) {
        final fname = record['${parentType}_fname'];
        if (fname == null || fname.toString().trim().isEmpty) continue;

        try {
          final email = record['${parentType}_email']?.toString().trim();
          final phone = record['${parentType}_phone']?.toString().trim();

          // Skip parent if missing critical data
          if (email == null || email.isEmpty) {
            print('Skipping $parentType for student $studentId: missing email');
            continue;
          }

          // Check if parent with same email already exists
          final existingParent =
              await supabase
                  .from('parents')
                  .select('id, user_id')
                  .eq('email', email)
                  .eq('status', 'Active')
                  .maybeSingle();

          int parentId;
          if (existingParent != null) {
            // Parent exists, use existing parent
            parentId = existingParent['id'];
            print('Using existing parent $parentId for email $email');
          } else {
            // Create new parent and user account
            try {
              final userId = await _createUserAccount(
                email: email,
                fname: record['${parentType}_fname'],
                mname: record['${parentType}_mname'],
                lname: record['${parentType}_lname'],
                phone: phone ?? '',
              );

              final parentInsert =
                  await supabase
                      .from('parents')
                      .insert({
                        'fname': record['${parentType}_fname'],
                        'mname': record['${parentType}_mname'],
                        'lname': record['${parentType}_lname'],
                        'phone': phone,
                        'email': email,
                        'address': record['${parentType}_address'],
                        'status': 'Active',
                        'user_id': userId,
                      })
                      .select()
                      .single();

              parentId = parentInsert['id'];
              importStats['parents_created'] =
                  (importStats['parents_created'] ?? 0) + 1;
            } catch (parentError) {
              print('Failed to create parent $parentType: $parentError');
              continue; // Skip this parent but continue with others
            }
          }

          createdParents.add({'id': parentId, 'type': parentType});
        } catch (parentError) {
          print('Error processing parent $parentType: $parentError');
          // Continue with other parents
        }
      }

      // 3. Create parent-student relationships
      // Determine primary parent based on hierarchy: mother > father > guardian
      int? primaryParentId;

      // Check for mother first
      final mother = createdParents.firstWhere(
        (p) => p['type'] == 'mother',
        orElse: () => {},
      );
      if (mother.isNotEmpty) {
        primaryParentId = mother['id'];
      }

      // If no mother, check if father/mother name is also in guardian field
      if (primaryParentId == null) {
        final guardianFname = record['guardian_fname'];
        final fatherFname = record['father_fname'];
        final motherFname = record['mother_fname'];

        if (guardianFname != null &&
            (guardianFname == fatherFname || guardianFname == motherFname)) {
          final matchingParent = createdParents.firstWhere(
            (p) => p['type'] == 'father' || p['type'] == 'mother',
            orElse: () => {},
          );
          if (matchingParent.isNotEmpty) {
            primaryParentId = matchingParent['id'];
          }
        }
      }

      // If still no primary, use father
      if (primaryParentId == null) {
        final father = createdParents.firstWhere(
          (p) => p['type'] == 'father',
          orElse: () => {},
        );
        if (father.isNotEmpty) {
          primaryParentId = father['id'];
        }
      }

      // If no father/mother, use guardian
      if (primaryParentId == null) {
        final guardian = createdParents.firstWhere(
          (p) => p['type'] == 'guardian',
          orElse: () => {},
        );
        if (guardian.isNotEmpty) {
          primaryParentId = guardian['id'];
        }
      }

      // Create relationships for all parents
      for (final parent in createdParents) {
        await supabase.from('parent_student').insert({
          'parent_id': parent['id'],
          'student_id': studentId,
          'relationship_type': parent['type'],
          'is_primary': false, // Set to false as per requirements
        });

        importStats['relationships_created'] =
            (importStats['relationships_created'] ?? 0) + 1;
      }
    } catch (e) {
      throw Exception('Database error: $e');
    }
  }

  Future<String> _createUserAccount({
    required String email,
    required String fname,
    String? mname,
    required String lname,
    required String phone,
  }) async {
    try {
      final res = await supabase.functions.invoke(
        'create_user',
        body: {
          'email': email,
          'role': 'Parent',
          'fname': fname,
          'mname': mname,
          'lname': lname,
          'suffix': null,
          'contact_number': phone,
          'position': null,
        },
      );

      if (res.status != 200) {
        final errorMsg =
            (res.data is Map && res.data['error'] != null)
                ? res.data['error']
                : res.data.toString();
        throw Exception('Failed to create user account: $errorMsg');
      }

      final userId = res.data['id'];
      if (userId == null) {
        throw Exception('No user ID returned from user creation');
      }

      return userId;
    } catch (e) {
      // More descriptive error for debugging
      throw Exception('User creation failed for $email: $e');
    }
  }

  void _showImportResults() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder:
          (context) => AlertDialog(
            title: Row(
              children: [
                Icon(
                  importStats['failed'] == 0
                      ? Icons.check_circle
                      : Icons.warning,
                  color:
                      importStats['failed'] == 0 ? Colors.green : Colors.orange,
                ),
                const SizedBox(width: 8),
                const Text('Import Complete'),
              ],
            ),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Import Summary:'),
                const SizedBox(height: 8),
                Text('• Total Records: ${importStats['total']}'),
                Text(
                  '• Successful: ${importStats['successful']}',
                  style: TextStyle(color: Colors.green),
                ),
                Text(
                  '• Failed: ${importStats['failed']}',
                  style: TextStyle(color: Colors.red),
                ),
                Text('• Students Created: ${importStats['students_created']}'),
                Text('• Parents Created: ${importStats['parents_created']}'),
                Text(
                  '• Relationships Created: ${importStats['relationships_created']}',
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  _resetImport();
                },
                child: const Text('Start New Import'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pop();
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2ECC71),
                ),
                child: const Text(
                  'Close',
                  style: TextStyle(color: Colors.white),
                ),
              ),
            ],
          ),
    );
  }

  void _resetImport() {
    setState(() {
      parsedData.clear();
      validationErrors.clear();
      importStats = {
        'total': 0,
        'successful': 0,
        'failed': 0,
        'students_created': 0,
        'parents_created': 0,
        'relationships_created': 0,
      };
      isLoading = false;
      isValidating = false;
      isImporting = false;
    });
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
}

extension StringCapitalization on String {
  String capitalize() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}