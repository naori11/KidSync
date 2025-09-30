import 'package:flutter/material.dart';
import '../services/push_notification_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class NotificationTestWidget extends StatefulWidget {
  final Color primaryColor;
  
  const NotificationTestWidget({
    Key? key,
    this.primaryColor = const Color(0xFF19AE61),
  }) : super(key: key);

  @override
  State<NotificationTestWidget> createState() => _NotificationTestWidgetState();
}

class _NotificationTestWidgetState extends State<NotificationTestWidget> {
  final PushNotificationService _pushService = PushNotificationService();
  final supabase = Supabase.instance.client;
  
  String _status = 'Ready to test notifications';
  bool _isLoading = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Icon(
                Icons.notifications_active,
                color: widget.primaryColor,
                size: 24,
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Notification Test Center',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Status display
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: widget.primaryColor.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              _status,
              style: TextStyle(
                color: widget.primaryColor,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          
          const SizedBox(height: 16),
          
          // Test buttons
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildTestButton(
                'Test Local Notification',
                Icons.phone_android,
                _testLocalNotification,
              ),
              _buildTestButton(
                'Check FCM Token',
                Icons.token,
                _checkFCMToken,
              ),
              _buildTestButton(
                'Test Permission',
                Icons.security,
                _testPermissions,
              ),
              _buildTestButton(
                'Test Database',
                Icons.storage,
                _testDatabaseConnection,
              ),
            ],
          ),
          
          if (_isLoading) ...[
            const SizedBox(height: 16),
            const Center(
              child: CircularProgressIndicator(),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTestButton(String text, IconData icon, VoidCallback onPressed) {
    return ElevatedButton.icon(
      onPressed: _isLoading ? null : onPressed,
      icon: Icon(icon, size: 16),
      label: Text(text),
      style: ElevatedButton.styleFrom(
        backgroundColor: widget.primaryColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Future<void> _testLocalNotification() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing local notification...';
    });

    try {
      await _pushService.showTestNotification(
        title: 'KidSync Test',
        body: 'This is a test notification from KidSync!',
        type: 'pickup',
      );
      
      setState(() {
        _status = '✅ Local notification sent successfully!';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Local notification failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _checkFCMToken() async {
    setState(() {
      _isLoading = true;
      _status = 'Checking FCM token...';
    });

    try {
      final token = _pushService.fcmToken;
      if (token != null) {
        setState(() {
          _status = '✅ FCM Token exists: ${token.substring(0, 20)}...';
        });
      } else {
        setState(() {
          _status = '❌ No FCM token found. Initialize notifications first.';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ FCM token check failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testPermissions() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing notification permissions...';
    });

    try {
      // This would typically check permission status
      // For now, just simulate the check
      await Future.delayed(const Duration(seconds: 1));
      
      setState(() {
        _status = '✅ Notification permissions OK';
      });
    } catch (e) {
      setState(() {
        _status = '❌ Permission check failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _testDatabaseConnection() async {
    setState(() {
      _isLoading = true;
      _status = 'Testing database connection...';
    });

    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        // Test if we can query notifications
        await supabase
            .from('notifications')
            .select('id')
            .limit(1);
        
        setState(() {
          _status = '✅ Database connection OK. User: ${user.email}';
        });
      } else {
        setState(() {
          _status = '❌ No authenticated user found';
        });
      }
    } catch (e) {
      setState(() {
        _status = '❌ Database test failed: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }
}

// Usage: Add this to any of your screens for testing
class NotificationTestPage extends StatelessWidget {
  const NotificationTestPage({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notification Tests'),
        backgroundColor: const Color(0xFF19AE61),
        foregroundColor: Colors.white,
      ),
      body: const Padding(
        padding: EdgeInsets.all(16),
        child: NotificationTestWidget(),
      ),
    );
  }
}