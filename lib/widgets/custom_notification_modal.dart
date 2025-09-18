import 'package:flutter/material.dart';

class CustomNotificationModal extends StatefulWidget {
  final String studentName;
  final Function(String reason) onSendNotification;

  const CustomNotificationModal({
    Key? key,
    required this.studentName,
    required this.onSendNotification,
  }) : super(key: key);

  @override
  _CustomNotificationModalState createState() => _CustomNotificationModalState();
}

class _CustomNotificationModalState extends State<CustomNotificationModal> {
  final TextEditingController _reasonController = TextEditingController();
  final List<String> _quickReasons = [
    'Multiple consecutive absences',
    'Excessive tardiness',
    'Irregular attendance pattern',
    'Missing important lessons',
    'Parent conference requested',
    'Academic performance affected',
    'Other (custom reason)',
  ];

  String? _selectedQuickReason;
  bool _isCustomSelected = false;
  bool _isSending = false;

  @override
  void dispose() {
    _reasonController.dispose();
    super.dispose();
  }

  void _onQuickReasonSelected(String reason) {
    setState(() {
      _selectedQuickReason = reason;
      _isCustomSelected = reason == 'Other (custom reason)';
      
      if (!_isCustomSelected) {
        _reasonController.text = reason;
      } else {
        _reasonController.clear();
      }
    });
  }

  Future<void> _sendNotification() async {
    if (_reasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide a reason for the notification'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() {
      _isSending = true;
    });

    try {
      await widget.onSendNotification(_reasonController.text.trim());
      
      if (mounted) {
        Navigator.of(context).pop();
        // Don't show success message here since the smart button will handle it
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isSending = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send notification: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.9,
        constraints: const BoxConstraints(maxWidth: 500),
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Icon(
                  Icons.notification_important,
                  color: Colors.orange,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Send Attendance Notification Ticket',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.of(context).pop(),
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            
            const SizedBox(height: 8),
            
            Text(
              'Student: ',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                color: Colors.grey[600],
              ),
            ),
            
            const SizedBox(height: 8),
            
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.blue[50],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue[200]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 20),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'This will create a notification ticket that can be tracked and resolved.',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.blue[700],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Quick Reason Selection
            Text(
              'Select a reason or enter custom message:',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            
            const SizedBox(height: 12),
            
            Container(
              constraints: const BoxConstraints(maxHeight: 200),
              child: SingleChildScrollView(
                child: Column(
                  children: _quickReasons.map((reason) {
                    final isSelected = _selectedQuickReason == reason;
                    return Container(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        onTap: () => _onQuickReasonSelected(reason),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: isSelected ? Colors.blue : Colors.grey[300]!,
                              width: isSelected ? 2 : 1,
                            ),
                            borderRadius: BorderRadius.circular(8),
                            color: isSelected ? Colors.blue[50] : null,
                          ),
                          child: Row(
                            children: [
                              Icon(
                                isSelected 
                                    ? Icons.radio_button_checked 
                                    : Icons.radio_button_unchecked,
                                color: isSelected ? Colors.blue : Colors.grey,
                                size: 20,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  reason,
                                  style: TextStyle(
                                    color: isSelected ? Colors.blue[800] : null,
                                    fontWeight: isSelected ? FontWeight.w500 : null,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Custom message input
            if (_isCustomSelected || _selectedQuickReason != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _isCustomSelected ? 'Custom message:' : 'Message to parents:',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _reasonController,
                    maxLines: 4,
                    readOnly: !_isCustomSelected && _selectedQuickReason != null,
                    decoration: InputDecoration(
                      hintText: _isCustomSelected 
                          ? 'Enter custom reason for contacting parents...'
                          : 'Review the message that will be sent',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                      filled: true,
                      fillColor: _isCustomSelected ? null : Colors.grey[100],
                    ),
                  ),
                ],
              ),
            
            const SizedBox(height: 24),
            
            // Action buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: _isSending ? null : () => Navigator.of(context).pop(),
                  child: const Text('Cancel'),
                ),
                
                const SizedBox(width: 12),
                
                ElevatedButton(
                  onPressed: _isSending || _reasonController.text.trim().isEmpty 
                      ? null 
                      : _sendNotification,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                  child: _isSending
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                          ),
                        )
                      : const Text('Send Notification Ticket'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Helper function to show the custom notification modal
Future<void> showCustomNotificationModal({
  required BuildContext context,
  required String studentName,
  required Function(String reason) onSendNotification,
}) {
  return showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => CustomNotificationModal(
      studentName: studentName,
      onSendNotification: onSendNotification,
    ),
  );
}
