import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ResetPasswordPage extends StatefulWidget {
  const ResetPasswordPage({Key? key}) : super(key: key);

  @override
  State<ResetPasswordPage> createState() => _ResetPasswordPageState();
}

class _ResetPasswordPageState extends State<ResetPasswordPage> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _codeController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  String? _accessToken;
  String? _userEmail;

  @override
  void initState() {
    super.initState();
    _extractTokenAndEmailFromUrl();
  }

  void _extractTokenAndEmailFromUrl() {
    final url = html.window.location.href;

    // Check if URL contains an access token (recovery link)
    if (url.contains('access_token=')) {
      try {
        _accessToken =
            Uri.parse(url).fragment
                .split('&')
                .firstWhere((part) => part.startsWith('access_token='))
                .split('=')[1];

        _extractEmailFromToken(_accessToken!);
      } catch (e) {
        print('Failed to extract access token: $e');
      }
    }
  }

  void _extractEmailFromToken(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) throw Exception('Invalid token format');
      final payload = base64Url.normalize(parts[1]);
      final decoded = utf8.decode(base64Url.decode(payload));
      final payloadMap = json.decode(decoded);

      setState(() {
        _userEmail = payloadMap['email'];
      });

      print('Extracted email: $_userEmail');
    } catch (e) {
      print('Failed to extract email from token: $e');
    }
  }

  Future<void> _resetPassword() async {
    if (_formKey.currentState?.validate() != true) return;

    final code = _codeController.text.trim();
    final newPassword = _newPasswordController.text.trim();

    final email = _userEmail;
    if (email == null) {
      _showSnackbar(
        'Email could not be found. Please use a valid recovery link.',
      );
      return;
    }

    try {
      final response = await Supabase.instance.client.auth.verifyOTP(
        email: email,
        token: code,
        type: OtpType.recovery,
      );

      if (response.user != null) {
        final updateResponse = await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: newPassword),
        );

        if (updateResponse.user != null) {
          _showSnackbar('Password reset successful. Please log in again.');
        } else {
          _showSnackbar('Failed to update password. Try again.');
        }
      } else {
        _showSnackbar('Invalid or expired code.');
      }
    } catch (e) {
      _showSnackbar('Error: ${e.toString()}');
    }
  }

  void _showSnackbar(String message) {
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  void dispose() {
    _codeController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Reset Password')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (_userEmail != null)
                    Text(
                      'Resetting password for $_userEmail',
                      style: const TextStyle(fontSize: 16),
                    ),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _codeController,
                    decoration: const InputDecoration(
                      labelText: 'Recovery Code',
                    ),
                    validator:
                        (value) =>
                            value == null || value.isEmpty
                                ? 'Enter the recovery code'
                                : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _newPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'New Password',
                    ),
                    obscureText: true,
                    validator:
                        (value) =>
                            value == null || value.length < 6
                                ? 'Password must be at least 6 characters'
                                : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmPasswordController,
                    decoration: const InputDecoration(
                      labelText: 'Confirm New Password',
                    ),
                    obscureText: true,
                    validator:
                        (value) =>
                            value != _newPasswordController.text
                                ? 'Passwords do not match'
                                : null,
                  ),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: _resetPassword,
                    child: const Text('Reset Password'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
