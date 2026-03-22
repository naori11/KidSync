import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter/services.dart';
import 'dart:math';
import '../../models/parent_models.dart';
import '../../services/parent_audit_service.dart';

class FetchersScreen extends StatefulWidget {
  final Color primaryColor;
  final bool isMobile;
  final int? selectedStudentId; // Add this parameter

  const FetchersScreen({
    required this.primaryColor,
    required this.isMobile,
    this.selectedStudentId, // Add this parameter
    super.key,
  });

  @override
  State<FetchersScreen> createState() => _FetchersScreenState();
}

class _FetchersScreenState extends State<FetchersScreen> {
  // Enhanced controllers for all fields
  final TextEditingController _fetcherNameController = TextEditingController();
  final TextEditingController _contactNumberController =
      TextEditingController();
  final TextEditingController _idNumberController = TextEditingController();
  final TextEditingController _emergencyContactController =
      TextEditingController();
  final TextEditingController _notesController = TextEditingController();

  final supabase = Supabase.instance.client;
  final ParentAuditService _auditService = ParentAuditService();
  String _currentPin = '';
  String? _currentFetcherName;

  // Form validation and dropdown values
  final _formKey = GlobalKey<FormState>();
  String? _selectedRelationship;
  String? _selectedIdType;
  bool _isGeneratingPin = false;

  // Dropdown options
  final List<String> _relationships = [
    'Parent',
    'Guardian',
    'Grandparent',
    'Uncle',
    'Aunt',
    'Sibling',
    'Family Friend',
    'Relative',
    'Other',
  ];

  final List<String> _idTypes = [
    'Driver\'s License',
    'Government ID',
    'Passport',
    'Senior Citizen ID',
    'PWD ID',
    'Company ID',
    'Other Valid ID',
  ];

  // Add these new variables for fetchers data
  List<AuthorizedFetcher> authorizedFetchers = [];
  List<Map<String, dynamic>> temporaryFetchers = [];
  bool isLoadingFetchers = true;
  bool isLoadingTempFetchers = false;
  String? currentParentName;
  String? childName;
  int? currentStudentId; // Internal tracking

  @override
  void initState() {
    super.initState();
    // Use the passed selectedStudentId from parent
    currentStudentId = widget.selectedStudentId;
    _loadFetchersData();
    _loadTemporaryFetchers();
  }

  @override
  void didUpdateWidget(FetchersScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when selectedStudentId changes
    if (widget.selectedStudentId != oldWidget.selectedStudentId) {
      currentStudentId = widget.selectedStudentId;
      _loadFetchersData();
      _loadTemporaryFetchers();
    }
  }

  @override
  void dispose() {
    _fetcherNameController.dispose();
    _contactNumberController.dispose();
    _idNumberController.dispose();
    _emergencyContactController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  // Updated _loadFetchersData method
  Future<void> _loadFetchersData() async {
    if (currentStudentId == null) {
      setState(() => isLoadingFetchers = false);
      return;
    }

    try {
      setState(() => isLoadingFetchers = true);

      // Get student name for display
      final studentResponse =
          await supabase
              .from('students')
              .select('fname, mname, lname')
              .eq('id', currentStudentId!)
              .maybeSingle();

      if (studentResponse != null) {
        final fname = studentResponse['fname'] ?? '';
        final mname = studentResponse['mname'] ?? '';
        final lname = studentResponse['lname'] ?? '';
        setState(() {
          childName =
              '$fname${mname.isNotEmpty ? ' $mname' : ''} $lname'.trim();
        });
      }

      // Get all authorized fetchers for this student with profile images
      final fetchersResponse = await supabase
          .from('parent_student')
          .select('''
            relationship_type,
            is_primary,
            parents!inner(
              id, fname, mname, lname, phone, email, status, user_id,
              users!inner(
                profile_image_url, role
              )
            )
          ''')
          .eq('student_id', currentStudentId!)
          .eq('parents.status', 'active')
          .eq('parents.users.role', 'Parent');

      final List<AuthorizedFetcher> fetchers =
          fetchersResponse
              .map((data) => AuthorizedFetcher.fromJson(data))
              .toList();

      // Sort: primary first, then by relationship type
      fetchers.sort((a, b) {
        if (a.isPrimary && !b.isPrimary) return -1;
        if (!a.isPrimary && b.isPrimary) return 1;
        return a.relationship.compareTo(b.relationship);
      });

      setState(() {
        authorizedFetchers = fetchers;
        isLoadingFetchers = false;
      });
    } catch (error) {
      print('Error loading fetchers data: $error');
      setState(() => isLoadingFetchers = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error loading data: $error'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  // Updated _loadTemporaryFetchers method
  Future<void> _loadTemporaryFetchers() async {
    if (currentStudentId == null) {
      setState(() => isLoadingTempFetchers = false);
      return;
    }

    setState(() => isLoadingTempFetchers = true);

    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await supabase
          .from('temporary_fetchers')
          .select('*')
          .eq('student_id', currentStudentId!)
          .eq('valid_date', today)
          .eq('status', 'active')
          .order('created_at', ascending: false);

      setState(() {
        temporaryFetchers = List<Map<String, dynamic>>.from(response);
        isLoadingTempFetchers = false;
      });
    } catch (error) {
      print('Error loading temporary fetchers: $error');
      setState(() => isLoadingTempFetchers = false);
    }
  }

  // Add this to get temporary fetcher statistics
  Future<Map<String, dynamic>> getTemporaryFetcherStats(int studentId) async {
    try {
      final response = await supabase
          .from('temporary_fetchers')
          .select('status, is_used, created_at')
          .eq('student_id', studentId)
          .gte(
            'created_at',
            DateTime.now().subtract(Duration(days: 30)).toIso8601String(),
          );

      final total = response.length;
      final used = response.where((r) => r['is_used'] == true).length;
      final active =
          response
              .where((r) => r['status'] == 'active' && r['is_used'] != true)
              .length;

      return {
        'total': total,
        'used': used,
        'active': active,
        'usage_rate': total > 0 ? (used / total * 100).round() : 0,
      };
    } catch (e) {
      print('Error getting temporary fetcher stats: $e');
      return {'total': 0, 'used': 0, 'active': 0, 'usage_rate': 0};
    }
  }

  Future<void> _refreshData() async {
    setState(() {
      isLoadingFetchers = true;
      isLoadingTempFetchers = true;
    });
    await _loadFetchersData();
    await _loadTemporaryFetchers();
  }

  // Add this check before generating PIN
  Future<bool> _checkDailyLimit(int parentId, int studentId) async {
    try {
      final today = DateTime.now().toIso8601String().split('T')[0];
      final response = await supabase
          .from('temporary_fetchers')
          .select('id')
          .eq('parent_id', parentId)
          .eq('student_id', studentId)
          .eq('valid_date', today)
          .eq('status', 'active');

      // Limit to 3 temporary fetchers per day per student
      return response.length < 3;
    } catch (e) {
      print('Error checking daily limit: $e');
      return false;
    }
  }

  String _generatePin() {
    final random = Random();
    return (100000 + random.nextInt(900000)).toString(); // 6-digit PIN
  }

  // Enhanced PIN generation with database storage
  Future<void> _generateAndSaveTemporaryFetcher() async {
    if (!_formKey.currentState!.validate()) return;

    if (currentStudentId == null) {
      _showErrorDialog(
        'Error',
        'Student information not found. Please try again.',
      );
      return;
    }

    setState(() => _isGeneratingPin = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) throw Exception('User not authenticated');

      final parentResponse =
          await supabase
              .from('parents')
              .select('id')
              .eq('user_id', user.id)
              .single();

      final parentId = parentResponse['id'];

      // Check daily limit
      final canCreate = await _checkDailyLimit(parentId, currentStudentId!);
      if (!canCreate) {
        throw Exception(
          'Daily limit reached. You can only create 3 temporary fetchers per day.',
        );
      }

      // Generate unique PIN
      String pin;
      bool isUnique = false;
      int attempts = 0;

      do {
        pin = _generatePin();
        final today = DateTime.now().toIso8601String().split('T')[0];

        final existingPin =
            await supabase
                .from('temporary_fetchers')
                .select('id')
                .eq('pin_code', pin)
                .eq('valid_date', today)
                .eq('status', 'active')
                .maybeSingle();

        isUnique = existingPin == null;
        attempts++;
      } while (!isUnique && attempts < 10);

      if (!isUnique) {
        throw Exception('Unable to generate unique PIN. Please try again.');
      }

      // Save to database
      final tempFetcherData = {
        'student_id': currentStudentId,
        'parent_id': parentId,
        'fetcher_name': _fetcherNameController.text.trim(),
        'relationship': _selectedRelationship!,
        'contact_number': _contactNumberController.text.trim(),
        'id_type': _selectedIdType,
        'id_number': _idNumberController.text.trim(),
        'pin_code': pin,
        'emergency_contact':
            _emergencyContactController.text.trim().isEmpty
                ? null
                : _emergencyContactController.text.trim(),
        'notes':
            _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
        'valid_date': DateTime.now().toIso8601String().split('T')[0],
        'status': 'active',
      };

      await supabase.from('temporary_fetchers').insert(tempFetcherData);

      setState(() {
        _currentFetcherName = _fetcherNameController.text.trim();
        _currentPin = pin;
        _isGeneratingPin = false;
      });

      // Log the temporary fetcher creation
      await _auditService.logTemporaryFetcherCreation(
        childId: currentStudentId!.toString(),
        childName: childName ?? 'Unknown Child',
        fetcherName: _fetcherNameController.text.trim(),
        relationship: _selectedRelationship!,
        pinCode: pin,
        validDate: DateTime.now().toIso8601String().split('T')[0],
        contactNumber: _contactNumberController.text.trim(),
        idType: _selectedIdType,
        idNumber: _idNumberController.text.trim(),
        emergencyContact:
            _emergencyContactController.text.trim().isEmpty
                ? null
                : _emergencyContactController.text.trim(),
        notes:
            _notesController.text.trim().isEmpty
                ? null
                : _notesController.text.trim(),
      );

      // Refresh the temporary fetchers list
      await _loadTemporaryFetchers();

      // Clear form
      _clearForm();

      // Show success dialog
      _showSuccessDialog(
        'PIN Generated Successfully',
        'Temporary fetcher access has been created for $_currentFetcherName',
      );
    } catch (error) {
      setState(() => _isGeneratingPin = false);
      print('Error saving temporary fetcher: $error');
      _showErrorDialog('Error', 'Failed to generate PIN: ${error.toString()}');
    }
  }

  // ...rest of existing methods remain the same...
  void _clearForm() {
    _fetcherNameController.clear();
    _contactNumberController.clear();
    _idNumberController.clear();
    _emergencyContactController.clear();
    _notesController.clear();
    setState(() {
      _selectedRelationship = null;
      _selectedIdType = null;
    });
  }

  void _showSuccessDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.check_circle, color: widget.primaryColor, size: 24),
              SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  void _showErrorDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          title: Row(
            children: [
              Icon(Icons.error_outline, color: Colors.red, size: 24),
              SizedBox(width: 8),
              Text(title, style: TextStyle(fontWeight: FontWeight.bold)),
            ],
          ),
          content: Text(message),
          actions: [
            ElevatedButton(
              onPressed: () => Navigator.of(context).pop(),
              style: ElevatedButton.styleFrom(
                backgroundColor: widget.primaryColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
              ),
              child: Text('OK'),
            ),
          ],
        );
      },
    );
  }

  // Enhanced form validation
  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Fetcher name is required';
    }
    if (value.trim().length < 2) {
      return 'Name must be at least 2 characters';
    }
    return null;
  }

  String? _validatePhoneNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Contact number is required';
    }
    final phoneRegex = RegExp(r'^[0-9+\-\s\(\)]{10,15}$');
    if (!phoneRegex.hasMatch(value.trim())) {
      return 'Please enter a valid phone number';
    }
    return null;
  }

  String? _validateIdNumber(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'ID number is required';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.6);

    // Show message if no student selected
    if (currentStudentId == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.person_search,
              size: 64,
              color: widget.primaryColor.withOpacity(0.5),
            ),
            SizedBox(height: 16),
            Text(
              'Please select a student',
              style: TextStyle(
                fontSize: 18,
                color: Color(0xFF000000).withOpacity(0.6),
              ),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Enhanced Add Temporary Fetcher Form (refactored to match app cards)
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 8,
              shadowColor: widget.primaryColor.withOpacity(0.18),
              child: Container(
                decoration: BoxDecoration(
                  color: white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.primaryColor.withOpacity(0.08),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(widget.isMobile ? 12 : 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: greenWithOpacity,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.person_add_alt_1,
                              color: widget.primaryColor,
                              size: widget.isMobile ? 16 : 18,
                            ),
                          ),
                          SizedBox(width: widget.isMobile ? 8 : 12),
                          Text(
                            'Add Temporary Fetcher',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: widget.isMobile ? 15 : 16,
                              color: black,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: widget.isMobile ? 10 : 12),

                      // Inner form area with subtle border to match other cards
                      Container(
                        padding: EdgeInsets.all(widget.isMobile ? 12 : 16),
                        decoration: BoxDecoration(
                          color: white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.primaryColor.withOpacity(0.06),
                            width: 2,
                          ),
                        ),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Temporary Access Information',
                                style: TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: widget.isMobile ? 14 : 15,
                                  color: widget.primaryColor,
                                ),
                              ),
                              SizedBox(height: widget.isMobile ? 12 : 14),

                              // Row 1: Fetcher Name and Relationship
                              if (widget.isMobile) ...[
                                _buildTextFormField(
                                  controller: _fetcherNameController,
                                  label: 'Fetcher Name *',
                                  hint: 'Enter full name',
                                  validator: _validateName,
                                ),
                                SizedBox(height: 12),
                                _buildDropdownField(
                                  value: _selectedRelationship,
                                  label: 'Relationship *',
                                  hint: 'Select relationship',
                                  items: _relationships,
                                  onChanged:
                                      (value) => setState(
                                        () => _selectedRelationship = value,
                                      ),
                                  validator:
                                      (value) =>
                                          value == null
                                              ? 'Relationship is required'
                                              : null,
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Expanded(
                                      flex: 2,
                                      child: _buildTextFormField(
                                        controller: _fetcherNameController,
                                        label: 'Fetcher Name *',
                                        hint: 'Enter full name',
                                        validator: _validateName,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _buildDropdownField(
                                        value: _selectedRelationship,
                                        label: 'Relationship *',
                                        hint: 'Select relationship',
                                        items: _relationships,
                                        onChanged:
                                            (value) => setState(
                                              () =>
                                                  _selectedRelationship = value,
                                            ),
                                        validator:
                                            (value) =>
                                                value == null
                                                    ? 'Relationship is required'
                                                    : null,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              SizedBox(height: 12),

                              // Row 2: Contact Number and Emergency Contact
                              if (widget.isMobile) ...[
                                _buildTextFormField(
                                  controller: _contactNumberController,
                                  label: 'Contact Number *',
                                  hint: 'e.g. 09123456789',
                                  validator: _validatePhoneNumber,
                                  keyboardType: TextInputType.phone,
                                ),
                                SizedBox(height: 12),
                                _buildTextFormField(
                                  controller: _emergencyContactController,
                                  label: 'Emergency Contact',
                                  hint: 'Optional backup contact',
                                  keyboardType: TextInputType.phone,
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildTextFormField(
                                        controller: _contactNumberController,
                                        label: 'Contact Number *',
                                        hint: 'e.g. 09123456789',
                                        validator: _validatePhoneNumber,
                                        keyboardType: TextInputType.phone,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _buildTextFormField(
                                        controller: _emergencyContactController,
                                        label: 'Emergency Contact',
                                        hint: 'Optional backup contact',
                                        keyboardType: TextInputType.phone,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              SizedBox(height: 12),

                              // Row 3: ID Type and ID Number
                              if (widget.isMobile) ...[
                                _buildDropdownField(
                                  value: _selectedIdType,
                                  label: 'Valid ID Type *',
                                  hint: 'Select ID type',
                                  items: _idTypes,
                                  onChanged:
                                      (value) => setState(
                                        () => _selectedIdType = value,
                                      ),
                                  validator:
                                      (value) =>
                                          value == null
                                              ? 'ID type is required'
                                              : null,
                                ),
                                SizedBox(height: 12),
                                _buildTextFormField(
                                  controller: _idNumberController,
                                  label: 'ID Number *',
                                  hint: 'Enter ID number',
                                  validator: _validateIdNumber,
                                ),
                              ] else ...[
                                Row(
                                  children: [
                                    Expanded(
                                      child: _buildDropdownField(
                                        value: _selectedIdType,
                                        label: 'Valid ID Type *',
                                        hint: 'Select ID type',
                                        items: _idTypes,
                                        onChanged:
                                            (value) => setState(
                                              () => _selectedIdType = value,
                                            ),
                                        validator:
                                            (value) =>
                                                value == null
                                                    ? 'ID type is required'
                                                    : null,
                                      ),
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: _buildTextFormField(
                                        controller: _idNumberController,
                                        label: 'ID Number *',
                                        hint: 'Enter ID number',
                                        validator: _validateIdNumber,
                                      ),
                                    ),
                                  ],
                                ),
                              ],

                              SizedBox(height: 12),

                              // Notes field
                              _buildTextFormField(
                                controller: _notesController,
                                label: 'Additional Notes',
                                hint: 'Any special instructions or notes',
                                maxLines: 2,
                              ),

                              SizedBox(height: widget.isMobile ? 12 : 14),

                              // Generate PIN Button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: widget.primaryColor,
                                    foregroundColor: white,
                                    padding: EdgeInsets.symmetric(
                                      vertical: widget.isMobile ? 12 : 14,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    elevation: 2,
                                  ),
                                  icon:
                                      _isGeneratingPin
                                          ? SizedBox(
                                            width: 20,
                                            height: 20,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              valueColor:
                                                  AlwaysStoppedAnimation<Color>(
                                                    white,
                                                  ),
                                            ),
                                          )
                                          : Icon(
                                            Icons.security,
                                            size: widget.isMobile ? 18 : 20,
                                          ),
                                  label: Text(
                                    _isGeneratingPin
                                        ? 'Generating...'
                                        : 'Generate Secure PIN',
                                    style: TextStyle(
                                      fontSize: widget.isMobile ? 14 : 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onPressed:
                                      _isGeneratingPin
                                          ? null
                                          : _generateAndSaveTemporaryFetcher,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: widget.isMobile ? 12 : 16),

          // Current/Recent Temporary Fetchers
          if (temporaryFetchers.isNotEmpty) _buildCurrentTemporaryFetchers(),
          SizedBox(height: widget.isMobile ? 12 : 16),

          // Existing Authorized Fetchers List (keep your existing code)
          // ...existing authorized fetchers code...
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              elevation: 6,
              shadowColor: widget.primaryColor.withOpacity(0.2),
              child: Container(
                decoration: BoxDecoration(
                  color: white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: widget.primaryColor.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                      spreadRadius: 1,
                    ),
                  ],
                ),
                child: Padding(
                  padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: greenWithOpacity,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Icon(
                              Icons.verified_user,
                              color: widget.primaryColor,
                              size: widget.isMobile ? 16 : 18,
                            ),
                          ),
                          SizedBox(width: widget.isMobile ? 8 : 12),
                          Expanded(
                            child: Text(
                              'Authorized Fetchers',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: widget.isMobile ? 15 : 16,
                                color: black,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.refresh,
                              color: widget.primaryColor,
                              size: widget.isMobile ? 20 : 24,
                            ),
                            onPressed: _refreshData,
                          ),
                        ],
                      ),
                      SizedBox(height: widget.isMobile ? 12 : 16),
                      isLoadingFetchers
                          ? Center(
                            child: Padding(
                              padding: EdgeInsets.symmetric(vertical: 20),
                              child: CircularProgressIndicator(
                                color: widget.primaryColor,
                              ),
                            ),
                          )
                          : authorizedFetchers.isEmpty
                          ? Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.people_outline,
                                    size: 48,
                                    color: black.withOpacity(0.3),
                                  ),
                                  SizedBox(height: 8),
                                  Text(
                                    'No authorized fetchers found',
                                    style: TextStyle(
                                      color: black.withOpacity(0.6),
                                      fontSize: widget.isMobile ? 14 : 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          : Column(
                            children:
                                authorizedFetchers.map((fetcher) {
                                  return _buildFetcherItem(
                                    fetcher.name,
                                    fetcher.relationship,
                                    'Contact: Available',
                                    fetcher.isActive,
                                    widget.isMobile,
                                    widget.primaryColor,
                                    black,
                                    greenWithOpacity,
                                    isPrimary: fetcher.isPrimary,
                                    profileImageUrl: fetcher.profileImageUrl,
                                  );
                                }).toList(),
                          ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Helper widget for text form fields
  Widget _buildTextFormField({
    required TextEditingController controller,
    required String label,
    required String hint,
    String? Function(String?)? validator,
    TextInputType? keyboardType,
    int maxLines = 1,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: widget.isMobile ? 13 : 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF000000),
          ),
        ),
        SizedBox(height: widget.isMobile ? 6 : 8),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: widget.primaryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red, width: 1),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: widget.isMobile ? 12 : 16,
            ),
          ),
        ),
      ],
    );
  }

  // Helper widget for dropdown fields
  Widget _buildDropdownField({
    required String? value,
    required String label,
    required String hint,
    required List<String> items,
    required void Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: widget.isMobile ? 13 : 15,
            fontWeight: FontWeight.w600,
            color: const Color(0xFF000000),
          ),
        ),
        SizedBox(height: widget.isMobile ? 6 : 8),
        DropdownButtonFormField<String>(
          value: value,
          validator: validator,
          isExpanded:
              true, // Prevent overflow by expanding to fill available width
          decoration: InputDecoration(
            hintText: hint,
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(
                color: widget.primaryColor.withOpacity(0.2),
                width: 1,
              ),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: widget.primaryColor, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(8),
              borderSide: BorderSide(color: Colors.red, width: 2),
            ),
            contentPadding: EdgeInsets.symmetric(
              horizontal: 12,
              vertical: widget.isMobile ? 12 : 16,
            ),
          ),
          items:
              items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(
                    item,
                    overflow:
                        TextOverflow.ellipsis, // Handle long text gracefully
                    maxLines: 1,
                  ),
                );
              }).toList(),
          onChanged: onChanged,
        ),
      ],
    );
  }

  // New widget to display current temporary fetchers
  Widget _buildCurrentTemporaryFetchers() {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.6);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 8,
        shadowColor: widget.primaryColor.withOpacity(0.3),
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: widget.primaryColor.withOpacity(0.15),
                blurRadius: 12,
                offset: const Offset(0, 6),
                spreadRadius: 2,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(widget.isMobile ? 16 : 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: greenWithOpacity,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Icon(
                        Icons.access_time,
                        color: widget.primaryColor,
                        size: widget.isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: widget.isMobile ? 8 : 12),
                    Text(
                      'Today\'s Temporary Fetchers',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: widget.isMobile ? 15 : 16,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: widget.isMobile ? 16 : 20),
                isLoadingTempFetchers
                    ? Center(
                      child: CircularProgressIndicator(
                        color: widget.primaryColor,
                      ),
                    )
                    : Column(
                      children:
                          temporaryFetchers
                              .map(
                                (fetcher) =>
                                    _buildTemporaryFetcherCard(fetcher),
                              )
                              .toList(),
                    ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTemporaryFetcherCard(Map<String, dynamic> fetcher) {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);

    final bool isUsed = fetcher['is_used'] == true;

    return Container(
      margin: EdgeInsets.only(bottom: 12),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isUsed ? Colors.grey[50] : white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color:
              isUsed ? Colors.grey[300]! : widget.primaryColor.withOpacity(0.3),
          width: 1,
        ),
        boxShadow: [
          if (!isUsed)
            BoxShadow(
              color: widget.primaryColor.withOpacity(0.1),
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
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fetcher['fetcher_name'] ?? 'Unknown',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 16,
                        color: isUsed ? Colors.grey[600] : black,
                      ),
                    ),
                    Text(
                      fetcher['relationship'] ?? 'Unknown',
                      style: TextStyle(
                        color:
                            isUsed ? Colors.grey[500] : black.withOpacity(0.6),
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color:
                      isUsed
                          ? Colors.grey[200]
                          : widget.primaryColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: isUsed ? Colors.grey[400]! : widget.primaryColor,
                  ),
                ),
                child: Text(
                  fetcher['pin_code'] ?? '',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    color: isUsed ? Colors.grey[600] : widget.primaryColor,
                    fontSize: 16,
                    letterSpacing: 2,
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 8),
          Row(
            children: [
              Icon(
                isUsed ? Icons.check_circle : Icons.access_time,
                size: 16,
                color: isUsed ? Colors.green : widget.primaryColor,
              ),
              SizedBox(width: 4),
              Text(
                isUsed ? 'Used' : 'Active',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: isUsed ? Colors.green : widget.primaryColor,
                ),
              ),
              Spacer(),
              if (!isUsed)
                IconButton(
                  icon: Icon(Icons.copy, size: 16),
                  onPressed: () async {
                    await Clipboard.setData(
                      ClipboardData(text: fetcher['pin_code']),
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('PIN copied to clipboard'),
                        backgroundColor: widget.primaryColor,
                      ),
                    );
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  // Keep your existing _buildFetcherItem method...
  Widget _buildFetcherItem(
    String name,
    String role,
    String contact,
    bool active,
    bool isMobile,
    Color primaryColor,
    Color black,
    Color greenWithOpacity, {
    bool isPrimary = false,
    String? profileImageUrl,
  }) {
    return Container(
      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
      padding: EdgeInsets.all(isMobile ? 12 : 16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isPrimary ? primaryColor : primaryColor.withOpacity(0.3),
          width: isPrimary ? 2 : 1,
        ),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(4),
            decoration: BoxDecoration(
              color:
                  active
                      ? primaryColor.withOpacity(0.1)
                      : black.withOpacity(0.05),
              shape: BoxShape.circle,
            ),
            child: CircleAvatar(
              backgroundColor: greenWithOpacity,
              radius: isMobile ? 16 : 20,
              backgroundImage:
                  profileImageUrl != null && profileImageUrl.isNotEmpty
                      ? NetworkImage(profileImageUrl)
                      : null,
              child:
                  profileImageUrl == null || profileImageUrl.isEmpty
                      ? Icon(
                        Icons.person,
                        color: primaryColor,
                        size: isMobile ? 18 : 22,
                      )
                      : null,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        name,
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: isMobile ? 15 : 17,
                          color: black,
                        ),
                      ),
                    ),
                    if (isPrimary)
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: primaryColor, width: 1),
                        ),
                        child: Text(
                          'PRIMARY',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: primaryColor,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  role,
                  style: TextStyle(
                    color: black.withOpacity(0.6),
                    fontSize: isMobile ? 13 : 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  contact,
                  style: TextStyle(
                    color: black.withOpacity(0.6),
                    fontSize: isMobile ? 11 : 13,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Icon(
                      active ? Icons.check_circle : Icons.circle_outlined,
                      color: active ? primaryColor : black.withOpacity(0.4),
                      size: isMobile ? 14 : 16,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      active ? 'Active' : 'Inactive',
                      style: TextStyle(
                        color: active ? primaryColor : black.withOpacity(0.6),
                        fontSize: isMobile ? 12 : 14,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color:
                  active
                      ? primaryColor.withOpacity(0.1)
                      : black.withOpacity(0.05),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              active ? Icons.security : Icons.security_outlined,
              color: active ? primaryColor : black.withOpacity(0.4),
              size: isMobile ? 16 : 18,
            ),
          ),
        ],
      ),
    );
  }
}
