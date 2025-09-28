import 'package:flutter/material.dart';
import '../services/attendance_ticketing_service.dart';
import '../widgets/custom_notification_modal.dart';
import '../widgets/attendance_notification_button.dart';

class SmartAttendanceButton extends StatefulWidget {
  final int studentId;
  final int sectionId;
  final String studentName;
  final String teacherName;
  final String sectionName;
  final String? teacherId;
  final VoidCallback? onActionComplete;

  const SmartAttendanceButton({
    Key? key,
    required this.studentId,
    required this.sectionId,
    required this.studentName,
    required this.teacherName,
    required this.sectionName,
    this.teacherId,
    this.onActionComplete,
  }) : super(key: key);

  @override
  _SmartAttendanceButtonState createState() => _SmartAttendanceButtonState();
}

class _SmartAttendanceButtonState extends State<SmartAttendanceButton> {
  final AttendanceTicketingService _ticketingService = AttendanceTicketingService();
  bool _isLoading = true;
  bool _isNotifyLoading = false;
  bool _isResolveLoading = false;
  
  // Ticket status
  bool _hasTicket = false;
  bool _isResolved = false;
  bool _canSendNotification = true;
  bool _canMarkResolved = false;

  @override
  void initState() {
    super.initState();
    _loadTicketStatus();
  }

  Future<void> _loadTicketStatus() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final ticketStatus = await _ticketingService.getTicketStatus(
        studentId: widget.studentId,
        sectionId: widget.sectionId,
      );

      if (mounted) {
        setState(() {
          _hasTicket = ticketStatus['hasTicket'];
          _isResolved = ticketStatus['isResolved'];
          _canSendNotification = ticketStatus['canSendNotification'];
          _canMarkResolved = ticketStatus['canMarkResolved'];
        });
      }
    } catch (e) {
      print('Error loading ticket status: $e');
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _showNotificationModal() async {
    setState(() {
      _isNotifyLoading = true;
    });

    try {
      await showCustomNotificationModal(
        context: context,
        studentName: widget.studentName,
        onSendNotification: (String reason) async {
          await _ticketingService.sendNotificationTicket(
            studentId: widget.studentId,
            studentName: widget.studentName,
            customReason: reason,
            teacherName: widget.teacherName,
            sectionName: widget.sectionName,
            teacherId: widget.teacherId,
          );
          
          // Reload ticket status after sending notification (with small delay to ensure DB commit)
          await Future.delayed(const Duration(milliseconds: 1000));
          await _loadTicketStatus();
          widget.onActionComplete?.call();
          
          // Show success message
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Notification ticket sent to ${widget.studentName}\'s parents'),
                backgroundColor: Colors.green,
              ),
            );
          }
        },
      );
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: '),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isNotifyLoading = false;
        });
      }
    }
  }

  Future<void> _markAsResolved() async {
    setState(() {
      _isResolveLoading = true;
    });

    try {
      await _ticketingService.markTicketResolved(
        studentId: widget.studentId,
        resolvedBy: widget.teacherId ?? 'teacher',
        resolutionNotes: 'Teacher manually marked attendance issue as resolved',
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Attendance issue marked as resolved for '),
            backgroundColor: Colors.green,
          ),
        );
        
        // Reload ticket status after resolution
        await _loadTicketStatus();
        widget.onActionComplete?.call();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error: '),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isResolveLoading = false;
        });
      }
    }
  }

  Widget _buildNotifyButton() {
    return AttendanceActionButton(
      text: 'Notify Parent',
      icon: Icons.send,
      color: _canSendNotification ? const Color(0xFFF59E0B) : Colors.grey,
      onPressed: (_canSendNotification && !_isNotifyLoading) ? _showNotificationModal : null,
      isLoading: _isNotifyLoading,
      width: 110,
      height: 32,
    );
  }

  Widget _buildResolveButton() {
    return AttendanceActionButton(
      text: 'Mark Resolved',
      icon: Icons.check_circle,
      color: _canMarkResolved ? const Color(0xFF10B981) : Colors.grey,
      onPressed: (_canMarkResolved && !_isResolveLoading) ? _markAsResolved : null,
      isLoading: _isResolveLoading,
      width: 110,
      height: 32,
    );
  }

  Widget _buildStatusIndicator() {
    if (!_hasTicket) {
      return const SizedBox.shrink();
    }

    String statusText;
    Color statusColor;
    IconData statusIcon;

    if (_isResolved) {
      statusText = 'Resolved';
      statusColor = Colors.green;
      statusIcon = Icons.check_circle;
    } else {
      statusText = 'Pending';
      statusColor = Colors.orange;
      statusIcon = Icons.schedule;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: statusColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: statusColor.withOpacity(0.25), width: 1),
        boxShadow: [
          BoxShadow(
            color: statusColor.withOpacity(0.1),
            blurRadius: 4,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(statusIcon, size: 14, color: statusColor),
          const SizedBox(width: 6),
          Text(
            statusText,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: statusColor,
              letterSpacing: 0.2,
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: AttendanceActionButton(
          text: 'Loading...',
          icon: Icons.hourglass_empty,
          color: Colors.grey,
          isLoading: true,
          width: 110,
          height: 32,
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Determine if we should use vertical layout for very small screens
        final isVerySmall = constraints.maxWidth < 280;
        
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              // Status indicator with improved positioning
              if (_hasTicket) ...[
                Container(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: _buildStatusIndicator(),
                ),
              ],
              
              // Action buttons with responsive layout
              if (isVerySmall)
                // Vertical layout for very small screens
                Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNotifyButton(),
                    const SizedBox(height: 4),
                    _buildResolveButton(),
                  ],
                )
              else
                // Horizontal layout for normal screens
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    _buildNotifyButton(),
                    const SizedBox(width: 6),
                    _buildResolveButton(),
                  ],
                ),
            ],
          ),
        );
      },
    );
  }
}
