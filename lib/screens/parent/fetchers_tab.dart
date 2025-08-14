import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';
import '../../models/parent_models.dart';

class FetchersScreen extends StatefulWidget {
  final Color primaryColor;
  final bool isMobile;

  const FetchersScreen({
    required this.primaryColor,
    required this.isMobile,
    Key? key,
  }) : super(key: key);

  @override
  State<FetchersScreen> createState() => _FetchersScreenState();
}

class _FetchersScreenState extends State<FetchersScreen> {
  final TextEditingController _fetcherNameController = TextEditingController();
  final supabase = Supabase.instance.client;
  String _currentPin = '8472';
  String? _currentFetcherName;

  // Add these new variables for fetchers data
  List<AuthorizedFetcher> authorizedFetchers = [];
  bool isLoadingFetchers = true;
  String? currentParentName;
  String? childName;

  @override
  void initState() {
    super.initState();
    _loadFetchersData();
  }

  Future<void> _loadFetchersData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Get current parent data
      final parentResponse =
          await supabase
              .from('parents')
              .select('id, fname, mname, lname')
              .eq('user_id', user.id)
              .eq('status', 'active')
              .maybeSingle();

      if (parentResponse == null) {
        setState(() => isLoadingFetchers = false);
        return;
      }

      final parentId = parentResponse['id'];

      // Get the child(ren) of this parent - REMOVED is_primary filter
      final studentResponse = await supabase
          .from('parent_student')
          .select('student_id, students(fname, mname, lname)')
          .eq('parent_id', parentId)
          .limit(1); // Just get the first student relationship

      if (studentResponse.isNotEmpty) {
        final student = studentResponse.first['students'];
        final fname = student['fname'] ?? '';
        final mname = student['mname'] ?? '';
        final lname = student['lname'] ?? '';
        setState(() {
          childName =
              '$fname${mname.isNotEmpty ? ' $mname' : ''} $lname'.trim();
        });

        final studentId = studentResponse.first['student_id'];

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
            .eq('student_id', studentId)
            .eq('parents.status', 'active')
            .eq(
              'parents.users.role',
              'Parent',
            ); // Only get parents with Parent role

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
      } else {
        setState(() => isLoadingFetchers = false);
      }
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

  Future<void> _refreshData() async {
    setState(() {
      isLoadingFetchers = true;
    });
    await _loadFetchersData();
  }

  String _generatePin() {
    final random = Random();
    return (1000 + random.nextInt(9000)).toString();
  }

  @override
  Widget build(BuildContext context) {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.6);

    return SingleChildScrollView(
      padding: EdgeInsets.all(widget.isMobile ? 8 : 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Add Temporary Fetcher
          AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            child: Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
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
                    BoxShadow(
                      color: const Color(0xFF000000).withOpacity(0.05),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
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
                      SizedBox(height: widget.isMobile ? 16 : 20),
                      Container(
                        padding: EdgeInsets.all(widget.isMobile ? 12 : 16),
                        decoration: BoxDecoration(
                          color: greenWithOpacity,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: widget.primaryColor.withOpacity(0.3),
                            width: 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Temporary Access',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: widget.isMobile ? 14 : 16,
                                color: widget.primaryColor,
                              ),
                            ),
                            SizedBox(height: widget.isMobile ? 8 : 10),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Fetcher Name',
                                  style: TextStyle(
                                    fontSize: widget.isMobile ? 13 : 15,
                                    fontWeight: FontWeight.w600,
                                    color: black,
                                  ),
                                ),
                                SizedBox(height: widget.isMobile ? 6 : 8),
                                TextField(
                                  controller: _fetcherNameController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter full name',
                                    filled: true,
                                    fillColor: white,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide.none,
                                    ),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: widget.primaryColor.withOpacity(
                                          0.2,
                                        ),
                                        width: 1,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(8),
                                      borderSide: BorderSide(
                                        color: widget.primaryColor,
                                        width: 2,
                                      ),
                                    ),
                                    contentPadding: EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: widget.isMobile ? 12 : 16,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            SizedBox(height: widget.isMobile ? 12 : 16),
                            SizedBox(
                              width: double.infinity,
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.primaryColor,
                                  foregroundColor: white,
                                  padding: EdgeInsets.symmetric(
                                    vertical: widget.isMobile ? 12 : 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  elevation: 2,
                                ),
                                icon: Icon(
                                  Icons.security,
                                  size: widget.isMobile ? 18 : 20,
                                ),
                                label: Text(
                                  'Generate Secure PIN',
                                  style: TextStyle(
                                    fontSize: widget.isMobile ? 14 : 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                onPressed: () {
                                  if (_fetcherNameController.text
                                      .trim()
                                      .isNotEmpty) {
                                    setState(() {
                                      _currentFetcherName =
                                          _fetcherNameController.text.trim();
                                      _currentPin = _generatePin();
                                    });
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          title: Row(
                                            children: [
                                              Icon(
                                                Icons.check_circle,
                                                color: widget.primaryColor,
                                                size: 24,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'PIN Generated',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: black,
                                                ),
                                              ),
                                            ],
                                          ),
                                          content: Text(
                                            'PIN generated successfully for ${_currentFetcherName}',
                                            style: TextStyle(
                                              color: black.withOpacity(0.7),
                                            ),
                                          ),
                                          actions: [
                                            ElevatedButton(
                                              onPressed:
                                                  () =>
                                                      Navigator.of(
                                                        context,
                                                      ).pop(),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    widget.primaryColor,
                                                foregroundColor: white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: Text('OK'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  } else {
                                    // Show error in center with better styling
                                    showDialog(
                                      context: context,
                                      builder: (BuildContext context) {
                                        return AlertDialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              16,
                                            ),
                                          ),
                                          title: Row(
                                            children: [
                                              Icon(
                                                Icons.error_outline,
                                                color: Colors.red,
                                                size: 24,
                                              ),
                                              SizedBox(width: 8),
                                              Text(
                                                'Input Required',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  color: black,
                                                ),
                                              ),
                                            ],
                                          ),
                                          content: Text(
                                            'Please enter a fetcher name to generate a PIN.',
                                            style: TextStyle(
                                              color: black.withOpacity(0.7),
                                            ),
                                          ),
                                          actions: [
                                            ElevatedButton(
                                              onPressed:
                                                  () =>
                                                      Navigator.of(
                                                        context,
                                                      ).pop(),
                                              style: ElevatedButton.styleFrom(
                                                backgroundColor:
                                                    widget.primaryColor,
                                                foregroundColor: white,
                                                shape: RoundedRectangleBorder(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
                                                ),
                                              ),
                                              child: Text('OK'),
                                            ),
                                          ],
                                        );
                                      },
                                    );
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          SizedBox(height: widget.isMobile ? 12 : 16),

          // Current Temporary Fetcher PIN
          if (_currentFetcherName != null)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              child: Card(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
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
                      BoxShadow(
                        color: const Color(0xFF000000).withOpacity(0.05),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
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
                                Icons.person_pin,
                                color: widget.primaryColor,
                                size: widget.isMobile ? 16 : 18,
                              ),
                            ),
                            SizedBox(width: widget.isMobile ? 8 : 12),
                            Text(
                              'Active Temporary Access',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: widget.isMobile ? 15 : 16,
                                color: black,
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: widget.isMobile ? 16 : 20),
                        Container(
                          padding: EdgeInsets.all(widget.isMobile ? 16 : 20),
                          decoration: BoxDecoration(
                            color: greenWithOpacity,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: widget.primaryColor,
                              width: 2,
                            ),
                          ),
                          child: Column(
                            children: [
                              Text(
                                _currentFetcherName!,
                                style: TextStyle(
                                  fontSize: widget.isMobile ? 16 : 18,
                                  fontWeight: FontWeight.w600,
                                  color: black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'PIN Code',
                                style: TextStyle(
                                  fontSize: widget.isMobile ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: black,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: widget.isMobile ? 20 : 24,
                                  vertical: widget.isMobile ? 12 : 16,
                                ),
                                decoration: BoxDecoration(
                                  color: white,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: widget.primaryColor,
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  _currentPin,
                                  style: TextStyle(
                                    fontSize: widget.isMobile ? 24 : 32,
                                    fontWeight: FontWeight.bold,
                                    color: widget.primaryColor,
                                    letterSpacing: 4,
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Valid for today only',
                                style: TextStyle(
                                  fontSize: widget.isMobile ? 12 : 14,
                                  color: black.withOpacity(0.6),
                                ),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(height: widget.isMobile ? 16 : 20),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: widget.primaryColor,
                                  foregroundColor: white,
                                  padding: EdgeInsets.symmetric(
                                    vertical: widget.isMobile ? 12 : 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: Icon(
                                  Icons.copy,
                                  size: widget.isMobile ? 18 : 20,
                                ),
                                label: Text(
                                  'Copy PIN',
                                  style: TextStyle(
                                    fontSize: widget.isMobile ? 14 : 16,
                                  ),
                                ),
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('PIN copied to clipboard'),
                                      backgroundColor: widget.primaryColor,
                                    ),
                                  );
                                },
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: widget.primaryColor,
                                  side: BorderSide(color: widget.primaryColor),
                                  padding: EdgeInsets.symmetric(
                                    vertical: widget.isMobile ? 12 : 16,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                ),
                                icon: Icon(
                                  Icons.refresh,
                                  size: widget.isMobile ? 18 : 20,
                                ),
                                label: Text(
                                  'Regenerate',
                                  style: TextStyle(
                                    fontSize: widget.isMobile ? 14 : 16,
                                  ),
                                ),
                                onPressed: () {
                                  setState(() {
                                    _currentPin = _generatePin();
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('New PIN generated'),
                                      backgroundColor: widget.primaryColor,
                                    ),
                                  );
                                },
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

          SizedBox(height: widget.isMobile ? 12 : 16),

          // Authorized Fetchers List
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
                          // Add refresh button
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
                                    profileImageUrl:
                                        fetcher
                                            .profileImageUrl, // Add this line
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
    String? profileImageUrl, // Add this parameter
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
