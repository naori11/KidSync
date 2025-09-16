import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class DriverNotificationsTab extends StatefulWidget {
  final Color primaryColor;
  final bool isMobile;

  const DriverNotificationsTab({
    required this.primaryColor,
    required this.isMobile,
    Key? key,
  }) : super(key: key);

  @override
  State<DriverNotificationsTab> createState() => _DriverNotificationsTabState();
}

class _DriverNotificationsTabState extends State<DriverNotificationsTab> {
  final supabase = Supabase.instance.client;
  bool _isLoading = true;
  List<Map<String, dynamic>> _logs = [];

  @override
  void initState() {
    super.initState();
    _loadRecentActivity();
  }

  Future<void> _loadRecentActivity() async {
    try {
      setState(() => _isLoading = true);
      final user = supabase.auth.currentUser;
      if (user == null) {
        setState(() => _isLoading = false);
        return;
      }

      final response = await supabase
          .from('pickup_dropoff_logs')
          .select('''
            id,
            event_type,
            pickup_time,
            dropoff_time,
            created_at,
            students!inner(fname, lname)
          ''')
          .eq('driver_id', user.id)
          .order('created_at', ascending: false)
          .limit(25);

      setState(() {
        _logs = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      // ignore errors and keep UI responsive
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatTime(dynamic time) {
    try {
      final dt = DateTime.parse((time ?? '').toString());
      return DateFormat('h:mm a').format(dt);
    } catch (_) {
      return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    const Color black = Color(0xFF000000);
    const Color white = Color(0xFFFFFFFF);
    const Color greenWithOpacity = Color.fromRGBO(25, 174, 97, 0.1);

    if (_isLoading) {
      return Center(
        child: CircularProgressIndicator(color: widget.primaryColor),
      );
    }

    return RefreshIndicator(
      color: widget.primaryColor,
      onRefresh: _loadRecentActivity,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(8),
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
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: greenWithOpacity,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Icon(
                          Icons.update,
                          color: widget.primaryColor,
                          size: widget.isMobile ? 16 : 18,
                        ),
                      ),
                      SizedBox(width: widget.isMobile ? 8 : 12),
                      Text(
                        'Recent Activity',
                        style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: widget.isMobile ? 15 : 16,
                          color: black,
                        ),
                      ),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.refresh),
                        color: widget.primaryColor,
                        onPressed: _loadRecentActivity,
                        tooltip: 'Refresh',
                      ),
                    ],
                  ),
                  SizedBox(height: widget.isMobile ? 12 : 16),
                  if (_logs.isEmpty)
                    Container(
                      padding: EdgeInsets.all(widget.isMobile ? 12 : 16),
                      decoration: BoxDecoration(
                        color: Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.info_outline,
                            color: Colors.grey[600],
                            size: widget.isMobile ? 16 : 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'No recent activity yet.',
                              style: TextStyle(
                                fontSize: widget.isMobile ? 13 : 15,
                                color: Colors.grey[600],
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    ..._logs.map((n) {
                      final String type = (n['event_type'] ?? '').toString();
                      final student = n['students'] ?? {};
                      final String studentName =
                          '${student['fname'] ?? ''} ${student['lname'] ?? ''}'
                              .trim();
                      final dynamic time =
                          type == 'pickup'
                              ? n['pickup_time']
                              : n['dropoff_time'];
                      final bool isPickup = type == 'pickup';
                      final Color chipColor =
                          isPickup ? widget.primaryColor : Colors.green;
                      final IconData icon =
                          isPickup ? Icons.directions_car : Icons.home;
                      final String title =
                          isPickup
                              ? 'Picked up $studentName'
                              : 'Dropped off $studentName';

                      return Container(
                        margin: EdgeInsets.only(
                          bottom: widget.isMobile ? 8 : 12,
                        ),
                        padding: EdgeInsets.all(widget.isMobile ? 10 : 12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey.shade300),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.03),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 14,
                              backgroundColor: chipColor.withOpacity(0.1),
                              child: Icon(icon, color: chipColor, size: 16),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    title,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: widget.isMobile ? 14 : 15,
                                      color: black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Time: ${_formatTime(time)}',
                                    style: TextStyle(
                                      fontSize: widget.isMobile ? 12 : 13,
                                      color: Colors.grey[700],
                                    ),
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
      ),
    );
  }
}
