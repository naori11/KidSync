import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../models/parent_models.dart';
import '../../models/driver_models.dart';
import '../../services/notification_service.dart';
import '../../services/verification_service.dart';
import '../../widgets/verification_modal.dart';
import '../../widgets/verification_status_card.dart';

class ParentDashboardTab extends StatefulWidget {
  final Color primaryColor;
  final bool isMobile;
  final int? selectedStudentId; // ADD THIS

  const ParentDashboardTab({
    required this.primaryColor,
    required this.isMobile,
    this.selectedStudentId, // ADD THIS
    Key? key,
  }) : super(key: key);

  @override
  State<ParentDashboardTab> createState() => _ParentDashboardTabState();
}

class _ParentDashboardTabState extends State<ParentDashboardTab> {
  List<AuthorizedFetcher> dashboardFetchers = [];
  bool isDashboardLoading = true;
  final supabase = Supabase.instance.client;
  final NotificationService _notificationService = NotificationService();
  final VerificationService _verificationService = VerificationService();
  
  // Real-time data
  Map<String, dynamic>? driverInfo;
  Map<String, dynamic> todayStatus = {};
  List<Map<String, dynamic>> recentNotifications = [];
  List<Map<String, dynamic>> pendingVerifications = [];
  Map<String, dynamic> todaySchedule = {};
  Timer? _refreshTimer;

  @override
  void initState() {
    super.initState();
    _initializeData();
  }

  @override
  void didUpdateWidget(ParentDashboardTab oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Reload data when selectedStudentId changes
    if (widget.selectedStudentId != oldWidget.selectedStudentId) {
      _refreshTimer?.cancel();
      _initializeData();
    }
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _initializeData() async {
    if (widget.selectedStudentId == null) {
      setState(() => isDashboardLoading = false);
      return;
    }

    setState(() => isDashboardLoading = true);

    try {
      await _loadAllData();
      _setupPeriodicRefresh();
    } catch (e) {
      print('Error initializing data: $e');
    } finally {
      setState(() => isDashboardLoading = false);
    }
  }

  Future<void> _loadAllData() async {
    if (widget.selectedStudentId == null) return;

    final studentId = widget.selectedStudentId!;

    // Load all data concurrently
    final results = await Future.wait([
      _notificationService.getStudentDriver(studentId),
      _notificationService.getTodayStatus(studentId),
      _loadTodaySchedule(studentId),
      _loadDashboardFetchers(),
      _loadRecentNotifications(),
      _loadPendingVerifications(),
    ]);

    setState(() {
      driverInfo = results[0] as Map<String, dynamic>?;
      todayStatus = results[1] as Map<String, dynamic>;
      todaySchedule = results[2] as Map<String, dynamic>;
    });
  }

  Future<void> _loadRecentNotifications() async {
    if (widget.selectedStudentId == null) return;

    try {
      // Get current user (parent)
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Get parent ID from user metadata or database
      final parentResponse = await supabase
          .from('parents')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (parentResponse != null) {
        final parentId = parentResponse['id'];
        // Get notifications for the selected student, today only
        final notifications = await _notificationService.getParentNotifications(
          parentId, 
          studentId: widget.selectedStudentId!,
          todayOnly: true,
          limit: 5,
        );
        setState(() {
          recentNotifications = notifications;
        });
      }
    } catch (e) {
      print('Error loading recent notifications: $e');
    }
  }

  Future<void> _loadPendingVerifications() async {
    try {
      // Get current user (parent)
      final user = supabase.auth.currentUser;
      if (user == null) return;

      // Get parent ID from user metadata or database
      final parentResponse = await supabase
          .from('parents')
          .select('id')
          .eq('user_id', user.id)
          .maybeSingle();

      if (parentResponse != null) {
        final parentId = parentResponse['id'];
        // Get pending verifications for this parent
        final verifications = await _verificationService.getPendingVerifications(parentId);
        setState(() {
          pendingVerifications = verifications;
        });

        // Show verification modal if there are pending verifications
        if (verifications.isNotEmpty && mounted) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            _showVerificationModal();
          });
        }
      }
    } catch (e) {
      print('Error loading pending verifications: $e');
    }
  }

  void _showVerificationModal() {
    showDialog(
      context: context,
      barrierDismissible: false, // Require user action
      builder: (BuildContext context) {
        return VerificationModal(
          pendingVerifications: pendingVerifications,
          onVerificationUpdated: () {
            // Reload pending verifications after update
            _loadPendingVerifications();
            // Refresh other data
            _refreshData();
          },
        );
      },
    );
  }

  void _setupPeriodicRefresh() {
    // Refresh data every 30 seconds
    _refreshTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      if (widget.selectedStudentId != null) {
        _refreshData();
      }
    });
  }

  Future<void> _refreshData() async {
    if (widget.selectedStudentId == null) return;

    try {
      final studentId = widget.selectedStudentId!;
      
      // Refresh today's status, schedule, notifications, and pending verifications
      final newTodayStatus = await _notificationService.getTodayStatus(studentId);
      final newTodaySchedule = await _loadTodaySchedule(studentId);
      await _loadRecentNotifications();
      await _loadPendingVerifications();
      
      setState(() {
        todayStatus = newTodayStatus;
        todaySchedule = newTodaySchedule;
      });
    } catch (e) {
      print('Error refreshing data: $e');
    }
  }

  Future<Map<String, dynamic>> _loadTodaySchedule(int studentId) async {
    try {
      final today = DateTime.now();
      final dayOfWeek = today.weekday; // 1 = Monday, 7 = Sunday
      final todayStr = '${today.year}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}';

      // Check for exceptions first (specific date overrides)
      final exceptionResponse = await supabase
          .from('pickup_dropoff_exceptions')
          .select('dropoff_person, pickup_person, reason')
          .eq('student_id', studentId)
          .eq('exception_date', todayStr)
          .maybeSingle();

      if (exceptionResponse != null) {
        // Exception found for today
        return {
          'dropoff_person': exceptionResponse['dropoff_person'],
          'pickup_person': exceptionResponse['pickup_person'],
          'reason': exceptionResponse['reason'],
          'is_exception': true,
        };
      }

      // No exception, check regular pattern
      final patternResponse = await supabase
          .from('pickup_dropoff_patterns')
          .select('dropoff_person, pickup_person')
          .eq('student_id', studentId)
          .eq('day_of_week', dayOfWeek)
          .maybeSingle();

      if (patternResponse != null) {
        return {
          'dropoff_person': patternResponse['dropoff_person'],
          'pickup_person': patternResponse['pickup_person'],
          'is_exception': false,
        };
      }

      // No pattern found, default to driver
      return {
        'dropoff_person': 'driver',
        'pickup_person': 'driver',
        'is_exception': false,
      };
    } catch (e) {
      print('Error loading today schedule: $e');
      return {
        'dropoff_person': 'driver',
        'pickup_person': 'driver',
        'is_exception': false,
      };
    }
  }

  Future<void> _loadDashboardFetchers() async {
    if (widget.selectedStudentId == null) {
      return;
    }

    try {
      // Use the provided student ID directly
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
          .eq('student_id', widget.selectedStudentId!)
          .eq('parents.status', 'active')
          .eq('parents.users.role', 'Parent')
          .limit(3);

      final List<AuthorizedFetcher> fetchers =
          fetchersResponse
              .map((data) => AuthorizedFetcher.fromJson(data))
              .toList();

      dashboardFetchers = fetchers;
    } catch (error) {
      print('Error loading dashboard fetchers: $error');
    }
  }

  Widget _fetcherRow(
    String name,
    String role,
    bool active,
    Color primaryColor, [
    bool isMobile = false,
    String? profileImageUrl, // Add this parameter
  ]) {
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      margin: EdgeInsets.only(
        bottom: isMobile ? 6 : 8,
      ), // Add margin for spacing
      padding: EdgeInsets.symmetric(
        vertical: isMobile ? 8 : 10,
        horizontal: isMobile ? 8 : 12,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFFFF),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: primaryColor.withOpacity(0.08),
            blurRadius: 6,
            offset: const Offset(0, 3),
            spreadRadius: 1,
          ),
          BoxShadow(
            color: const Color(0xFF000000).withOpacity(0.03),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
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
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 13 : 15,
                    color: black,
                  ),
                ),
                Text(
                  role,
                  style: TextStyle(
                    color: black.withOpacity(0.6),
                    fontSize: isMobile ? 11 : 13,
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.circle,
            color: active ? primaryColor : black.withOpacity(0.3),
            size: isMobile ? 10 : 12,
          ),
        ],
      ),
    );
  }

  Widget _buildDriverInfoCard(Color primaryColor, bool isMobile) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);
    
    // Use real driver data or show loading/no driver state
    if (driverInfo == null) {
      return _buildNoDriverCard(primaryColor, isMobile);
    }
    
    final driver = driverInfo!['drivers'];
    final driverName = '${driver['fname']} ${driver['lname']}';
    final driverPhone = driver['phone'] ?? 'No phone';
    final profileImageUrl = driver['users']?['profile_image_url'];

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: primaryColor.withOpacity(0.2),
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
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
                        Icons.local_shipping,
                        color: primaryColor,
                        size: isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Text(
                      'School Service',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 15 : 16,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: white,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: primaryColor.withOpacity(0.3),
                      width: 2,
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
                      CircleAvatar(
                        backgroundColor: greenWithOpacity,
                        radius: isMobile ? 24 : 30,
                        backgroundImage: profileImageUrl != null && profileImageUrl.isNotEmpty
                            ? NetworkImage(profileImageUrl)
                            : null,
                        child: profileImageUrl == null || profileImageUrl.isEmpty
                            ? Icon(
                                Icons.person,
                                color: primaryColor,
                                size: isMobile ? 24 : 30,
                              )
                            : null,
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              driverName,
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: isMobile ? 16 : 18,
                                color: black,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                Icon(
                                  Icons.directions_car,
                                  size: isMobile ? 14 : 16,
                                  color: black.withOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  'License: ${driver['license_number'] ?? 'N/A'}',
                                  style: TextStyle(
                                    fontSize: isMobile ? 13 : 15,
                                    color: black.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Row(
                              children: [
                                Icon(
                                  Icons.phone,
                                  size: isMobile ? 14 : 16,
                                  color: black.withOpacity(0.6),
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  driverPhone,
                                  style: TextStyle(
                                    fontSize: isMobile ? 13 : 15,
                                    color: black.withOpacity(0.6),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      // Removed the call/message buttons per request
                    ],
                  ),
                ),
                SizedBox(height: isMobile ? 12 : 16),
                // Call & Message buttons removed
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPickupSummaryCard(Color primaryColor, bool isMobile) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: primaryColor.withOpacity(0.2),
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
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
                        Icons.assignment_turned_in,
                        color: primaryColor,
                        size: isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Text(
                      'Today\'s Pickup Summary',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 15 : 16,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                ..._buildRealTimeSummaryItems(primaryColor, black, isMobile),
                SizedBox(height: isMobile ? 12 : 16),
                Container(
                  padding: EdgeInsets.all(isMobile ? 10 : 12),
                  decoration: BoxDecoration(
                    color: greenWithOpacity,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: primaryColor.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.info,
                        color: primaryColor,
                        size: isMobile ? 16 : 18,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Real-time updates will appear here when your child is picked up',
                          style: TextStyle(
                            fontSize: isMobile ? 12 : 14,
                            color: black.withOpacity(0.7),
                            fontStyle: FontStyle.italic,
                          ),
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
    );
  }

  Widget _buildNoDriverCard(Color primaryColor, bool isMobile) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: primaryColor.withOpacity(0.2),
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
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
                        Icons.local_shipping,
                        color: primaryColor,
                        size: isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Text(
                      'Driver Information',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 15 : 16,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                Container(
                  padding: EdgeInsets.all(isMobile ? 12 : 16),
                  decoration: BoxDecoration(
                    color: Colors.grey.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: Colors.grey.withOpacity(0.3),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.grey.withOpacity(0.2),
                        radius: isMobile ? 24 : 30,
                        child: Icon(
                          Icons.person_off,
                          color: Colors.grey,
                          size: isMobile ? 24 : 30,
                        ),
                      ),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'No Driver Assigned',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: isMobile ? 16 : 18,
                                color: Colors.grey[600],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Please contact school administration',
                              style: TextStyle(
                                fontSize: isMobile ? 13 : 15,
                                color: Colors.grey[500],
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
          ),
        ),
      ),
    );
  }

  List<Widget> _buildRealTimeSummaryItems(Color primaryColor, Color black, bool isMobile) {
    final List<Widget> items = [];
    
    // Get who is responsible for pickup/dropoff today
    final dropoffPerson = todaySchedule['dropoff_person'] ?? 'driver';
    final pickupPerson = todaySchedule['pickup_person'] ?? 'driver';
    
    // Morning pickup status (picking up from home to school)
    final pickup = todayStatus['pickup']; // DB event_type 'pickup' = morning trip
    if (pickup != null) {
      final pickupTime = pickup['pickup_time'];
      final driverName = pickup['drivers'] != null 
          ? '${pickup['drivers']['fname']} ${pickup['drivers']['lname']}'
          : 'Driver';
      
      items.add(_buildSummaryItem(
        Icons.school,
        'Morning Pick-up',
        '${_formatTimeFromString(pickupTime)} - Picked up from home',
        dropoffPerson == 'parent' 
            ? 'You confirmed pick-up'
            : 'Driver: $driverName confirmed pick-up',
        true,
        primaryColor,
        black,
        isMobile,
      ));
      items.add(const SizedBox(height: 8));
    }
    
    // Afternoon dropoff status (dropping off from school to home)
    final dropoff = todayStatus['dropoff']; // DB event_type 'dropoff' = afternoon trip
    if (dropoff != null) {
      final dropoffTime = dropoff['dropoff_time'];
      final driverName = dropoff['drivers'] != null 
          ? '${dropoff['drivers']['fname']} ${dropoff['drivers']['lname']}'
          : 'Driver';
      
      items.add(_buildSummaryItem(
        Icons.home,
        'Afternoon Drop-off',
        '${_formatTimeFromString(dropoffTime)} - Dropped off at home',
        pickupPerson == 'parent' 
            ? 'You confirmed drop-off'
            : 'Driver: $driverName confirmed drop-off',
        true,
        primaryColor,
        black,
        isMobile,
      ));
      items.add(const SizedBox(height: 8));
    }
    
    // Current status based on what's happened and who's responsible
    if (pickup != null && dropoff == null) {
      // Child has been picked up from home, now at school, waiting for dropoff
      if (pickupPerson == 'parent') {
        items.add(_buildSummaryItem(
          Icons.school,
          'Current Status',
          'At school - You need to drop off',
          'You are responsible for drop-off today',
          true,
          primaryColor,
          black,
          isMobile,
        ));
      } else {
        items.add(_buildSummaryItem(
          Icons.school,
          'Current Status',
          'At school - Waiting for drop-off',
          'Driver will drop off student',
          true,
          primaryColor,
          black,
          isMobile,
        ));
      }
      items.add(const SizedBox(height: 8));
    } else if (dropoff != null) {
      // Child has been dropped off from school and is home
      items.add(_buildSummaryItem(
        Icons.home,
        'Current Status',
        'At home - Day completed',
        'Student has been safely dropped off',
        true,
        primaryColor,
        black,
        isMobile,
      ));
      items.add(const SizedBox(height: 8));
    } else {
      // No morning pickup yet - show scheduled time and responsible person
      final scheduledPickupTime = driverInfo?['pickup_time'] ?? '8:00:00';
      final formattedTime = _formatScheduledTime(scheduledPickupTime);
      
      if (dropoffPerson == 'parent') {
        items.add(_buildSummaryItem(
          Icons.schedule,
          'Scheduled Pick-up',
          '$formattedTime - You will pick up',
          'You are responsible for pick-up today',
          false,
          primaryColor,
          black,
          isMobile,
        ));
      } else {
        final driverName = driverInfo != null 
            ? '${driverInfo!['drivers']['fname']} ${driverInfo!['drivers']['lname']}'
            : 'Driver';
        
        items.add(_buildSummaryItem(
          Icons.schedule,
          'Scheduled Pick-up',
          '$formattedTime - Waiting for pick-up',
          'Driver: $driverName will pick up',
          false,
          primaryColor,
          black,
          isMobile,
        ));
      }
      items.add(const SizedBox(height: 8));
    }
    
    return items;
  }

  String _formatTimeFromString(String? timeString) {
    if (timeString == null) return 'Unknown time';
    
    try {
      final dateTime = DateTime.parse(timeString);
      return DateFormat('h:mm a').format(dateTime);
    } catch (e) {
      return timeString;
    }
  }

  List<Widget> _buildTodayScheduleItems() {
    final List<Widget> items = [];
    
    // Get scheduled times from driver assignment
    // pickup_time = morning pickup from home (first event of the day)
    // dropoff_time = afternoon dropoff at home (second event of the day)
    final scheduledPickupTime = driverInfo?['pickup_time'] ?? '8:00:00';
    final scheduledDropoffTime = driverInfo?['dropoff_time'] ?? '15:30:00';
    
    // Format times
    final pickupTimeFormatted = _formatScheduledTime(scheduledPickupTime);
    final dropoffTimeFormatted = _formatScheduledTime(scheduledDropoffTime);
    
    // Get who is responsible for pickup/dropoff today
    final dropoffPerson = todaySchedule['dropoff_person'] ?? 'driver';
    final pickupPerson = todaySchedule['pickup_person'] ?? 'driver';
    final isException = todaySchedule['is_exception'] ?? false;
    
    // Check actual status from logs
    // pickup = morning trip (parent perspective: drop-off at school)
    // dropoff = afternoon trip (parent perspective: pick-up from school)
    final pickup = todayStatus['pickup'];
    final dropoff = todayStatus['dropoff'];
    
    // Build pickup item first (morning - pick up from home to school)
    items.add(_buildScheduleItem(
      pickupTimeFormatted, // Morning pickup time
      'Pick-up',
      dropoffPerson == 'parent' ? 'You' : 'Driver',
      pickup != null, // pickup event = morning pickup completed
      isException && dropoffPerson == 'parent',
    ));
    
    items.add(SizedBox(height: widget.isMobile ? 4 : 8));
    
    // Build dropoff item second (afternoon - drop off from school to home)
    items.add(_buildScheduleItem(
      dropoffTimeFormatted, // Afternoon dropoff time
      'Drop-off',
      pickupPerson == 'parent' ? 'You' : 'Driver',
      dropoff != null, // dropoff event = afternoon dropoff completed
      isException && pickupPerson == 'parent',
    ));
    
    // Add exception note if applicable
    if (isException && todaySchedule['reason'] != null) {
      items.add(SizedBox(height: widget.isMobile ? 8 : 12));
      items.add(Container(
        padding: EdgeInsets.all(widget.isMobile ? 8 : 10),
        decoration: BoxDecoration(
          color: Colors.orange.withOpacity(0.1),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: Colors.orange.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Icon(
              Icons.info_outline,
              color: Colors.orange[700],
              size: widget.isMobile ? 14 : 16,
            ),
            SizedBox(width: 8),
            Expanded(
              child: Text(
                'Schedule Exception: ${todaySchedule['reason']}',
                style: TextStyle(
                  fontSize: widget.isMobile ? 11 : 13,
                  color: Colors.orange[700],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ));
    }
    
    return items;
  }

  Widget _buildScheduleItem(String time, String event, String person, bool completed, bool isException) {
    return Row(
      children: [
        Icon(
          completed ? Icons.check_circle : Icons.radio_button_unchecked,
          size: 18,
          color: completed 
              ? widget.primaryColor 
              : const Color(0xFF000000).withOpacity(0.6),
        ),
        const SizedBox(width: 8),
        Text(
          time,
          style: TextStyle(
            fontWeight: FontWeight.w500,
            fontSize: widget.isMobile ? 13 : 15,
            color: const Color(0xFF000000),
          ),
        ),
        const SizedBox(width: 8),
        Text(
          event,
          style: TextStyle(
            color: const Color(0xFF000000).withOpacity(0.6),
            fontSize: widget.isMobile ? 12 : 14,
          ),
        ),
        if (isException) ...[
          const SizedBox(width: 4),
          Icon(
            Icons.warning_amber_rounded,
            size: 14,
            color: Colors.orange[600],
          ),
        ],
        const Spacer(),
        Text(
          completed ? 'Completed' : person,
          style: TextStyle(
            color: completed ? widget.primaryColor : const Color(0xFF000000).withOpacity(0.8),
            fontWeight: FontWeight.w600,
            fontSize: widget.isMobile ? 13 : 15,
          ),
        ),
      ],
    );
  }

  String _formatScheduledTime(String timeString) {
    try {
      // Parse time string (format: HH:mm:ss)
      final parts = timeString.split(':');
      final hour = int.parse(parts[0]);
      final minute = int.parse(parts[1]);
      
      // Create DateTime for formatting
      final now = DateTime.now();
      final time = DateTime(now.year, now.month, now.day, hour, minute);
      
      return DateFormat('h:mm a').format(time);
    } catch (e) {
      return timeString;
    }
  }

  Widget _buildNotificationsCard(Color primaryColor, bool isMobile) {
    const Color white = Color(0xFFFFFFFF);
    const Color black = Color(0xFF000000);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      child: Card(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 6,
        shadowColor: primaryColor.withOpacity(0.2),
        child: Container(
          decoration: BoxDecoration(
            color: white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: primaryColor.withOpacity(0.1),
                blurRadius: 10,
                offset: const Offset(0, 5),
                spreadRadius: 1,
              ),
            ],
          ),
          child: Padding(
            padding: EdgeInsets.all(isMobile ? 12 : 20),
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
                        Icons.notifications,
                        color: primaryColor,
                        size: isMobile ? 16 : 18,
                      ),
                    ),
                    SizedBox(width: isMobile ? 8 : 12),
                    Text(
                      'Recent Notifications',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: isMobile ? 15 : 16,
                        color: black,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: isMobile ? 12 : 16),
                if (recentNotifications.isEmpty)
                  Container(
                    padding: EdgeInsets.all(isMobile ? 12 : 16),
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          color: Colors.grey[600],
                          size: isMobile ? 16 : 18,
                        ),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'No recent notifications. You\'ll see pickup/dropoff updates here.',
                            style: TextStyle(
                              fontSize: isMobile ? 13 : 15,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                else
                  ...recentNotifications.take(3).map((notification) {
                    final type = notification['type'] ?? '';
                    final title = notification['title'] ?? 'Notification';
                    final message = notification['message'] ?? '';
                    
                    IconData icon;
                    Color iconColor;
                    
                    switch (type) {
                      case 'pickup':
                        icon = Icons.school;
                        iconColor = Colors.blue;
                        break;
                      case 'dropoff':
                        icon = Icons.home;
                        iconColor = Colors.green;
                        break;
                      default:
                        icon = Icons.info;
                        iconColor = primaryColor;
                    }

                    return Container(
                      margin: EdgeInsets.only(bottom: isMobile ? 8 : 12),
                      padding: EdgeInsets.all(isMobile ? 10 : 12),
                      decoration: BoxDecoration(
                        color: iconColor.withOpacity(0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: iconColor.withOpacity(0.2)),
                      ),
                      child: Row(
                        children: [
                          Icon(icon, color: iconColor, size: isMobile ? 16 : 18),
                          SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  title,
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: isMobile ? 14 : 16,
                                    color: black,
                                  ),
                                ),
                                SizedBox(height: 4),
                                Text(
                                  message,
                                  style: TextStyle(
                                    fontSize: isMobile ? 12 : 14,
                                    color: black.withOpacity(0.7),
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  }).toList(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryItem(
    IconData icon,
    String title,
    String time,
    String description,
    bool completed,
    Color primaryColor,
    Color black,
    bool isMobile,
  ) {
    const Color white = Color(0xFFFFFFFF);

    return Container(
      padding: EdgeInsets.all(isMobile ? 10 : 12),
      decoration: BoxDecoration(
        color: white,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: primaryColor.withOpacity(0.1), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: completed ? primaryColor : black.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(
              completed ? Icons.check : icon,
              color: completed ? white : black.withOpacity(0.6),
              size: isMobile ? 14 : 16,
            ),
          ),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: isMobile ? 13 : 15,
                    color: black,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  time,
                  style: TextStyle(
                    fontSize: isMobile ? 12 : 14,
                    color: completed ? primaryColor : black.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  description,
                  style: TextStyle(
                    fontSize: isMobile ? 11 : 13,
                    color: black.withOpacity(0.6),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    // Show message if no student selected
    if (widget.selectedStudentId == null) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // 1. Today's Schedule Card - TOP PRIORITY (moved to top)
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
                padding: EdgeInsets.all(widget.isMobile ? 12 : 20),
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
                            Icons.calendar_today,
                            color: widget.primaryColor,
                            size: widget.isMobile ? 16 : 18,
                          ),
                        ),
                        SizedBox(width: widget.isMobile ? 8 : 12),
                        Text(
                          "Today's Schedule",
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isMobile ? 15 : 16,
                            color: const Color(0xFF000000),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: widget.isMobile ? 8 : 12),
                    ..._buildTodayScheduleItems(),
                  ],
                ),
              ),
            ),
          ),
        ),
        SizedBox(height: widget.isMobile ? 10 : 14),
        
        // 2. Verification Status Card - CRITICAL ACTIONS (when pending)
        if (pendingVerifications.isNotEmpty)
          Padding(
            padding: EdgeInsets.only(bottom: widget.isMobile ? 10 : 14),
            child: VerificationStatusCard(
              pendingVerifications: pendingVerifications,
              onTap: _showVerificationModal,
              primaryColor: widget.primaryColor,
              isMobile: widget.isMobile,
            ),
          ),
        
        // 3. Pickup Summary Card - REAL-TIME STATUS
        _buildPickupSummaryCard(widget.primaryColor, widget.isMobile),
        SizedBox(height: widget.isMobile ? 10 : 14),
        
        // 4. Recent Notifications Card - COMMUNICATION
        _buildNotificationsCard(widget.primaryColor, widget.isMobile),
        SizedBox(height: widget.isMobile ? 10 : 14),
        
        // 5. Driver Information Card - SUPPORT & CONTACT
        _buildDriverInfoCard(widget.primaryColor, widget.isMobile),
        SizedBox(height: widget.isMobile ? 10 : 14),
        
        // 6. Authorized Fetchers Card - REFERENCE INFORMATION
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
                padding: EdgeInsets.all(widget.isMobile ? 12 : 20),
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
                        Text(
                          'Authorized Fetchers',
                          style: TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: widget.isMobile ? 15 : 16,
                            color: const Color(0xFF000000),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: widget.isMobile ? 6 : 10),
                    isDashboardLoading
                        ? Center(
                          child: Padding(
                            padding: EdgeInsets.symmetric(vertical: 10),
                            child: CircularProgressIndicator(
                              color: widget.primaryColor,
                              strokeWidth: 2,
                            ),
                          ),
                        )
                        : dashboardFetchers.isEmpty
                        ? Padding(
                          padding: EdgeInsets.symmetric(vertical: 10),
                          child: Text(
                            'No authorized fetchers found',
                            style: TextStyle(
                              color: const Color(0xFF000000).withOpacity(0.6),
                              fontSize: widget.isMobile ? 12 : 14,
                            ),
                          ),
                        )
                        : Column(
                          children:
                              dashboardFetchers.map((fetcher) {
                                return _fetcherRow(
                                  fetcher.name,
                                  fetcher.relationship,
                                  fetcher.isActive,
                                  widget.primaryColor,
                                  widget.isMobile,
                                  fetcher.profileImageUrl,
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
    );
  }
}
