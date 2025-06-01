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
  String? _resetCode;
  String? _previousUserEmail;


  @override
  void initState() {
    super.initState();
    print("SetPasswordScreen: initState called");

    // Password reset flow
    if (kIsWeb &&
        html.window.sessionStorage.containsKey('kidsync_reset_code')) {
      _resetCode = html.window.sessionStorage['kidsync_reset_code'];
      _previousUserEmail = html.window.sessionStorage['kidsync_reset_email'];
      print(
        "SetPasswordScreen: Found reset code in session storage: $_resetCode",
      );
      // Log out any current user for security
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        _previousUserEmail = currentUser.email;
        Supabase.instance.client.auth.signOut().then((_) {
          print("SetPasswordScreen: Logged out user $_previousUserEmail");
          setState(() => _isLoading = false);
        });
      } else {
        setState(() => _isLoading = false);
      }
      return;
    }

    // Invite flow
    if (kIsWeb) {
      print("SetPasswordScreen: Checking for invite tokens");
      _processInviteToken();
      return;
    }

    // Authenticated user flow
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      print("SetPasswordScreen: User authenticated: ${currentUser.email}");
      _isAuthenticated = true;
      _userEmail = currentUser.email;
      _userId = currentUser.id;
      setState(() => _isLoading = false);
    } else {
      print("SetPasswordScreen: Not authenticated, redirecting to login");
      setState(() => _isLoading = false);
      _redirectToLogin();
    }
  }

  Future<void> _processInviteToken() async {
    try {
      _accessToken = html.window.sessionStorage['supabase_access_token'];
      if (_accessToken != null) {
        print("SetPasswordScreen: Found token in sessionStorage");
        _extractEmailAndUserIdFromToken(_accessToken);
        if (_userEmail != null) {
          print(
            "SetPasswordScreen: Successfully extracted email from token: $_userEmail",
          );
          setState(() => _isLoading = false);
          return;
        }
      }
      final url = html.window.location.href;
      print("SetPasswordScreen: Checking URL for token: $url");
      if (url.contains('access_token=')) {
        _accessToken = url.split('access_token=')[1].split('&')[0];
        print("SetPasswordScreen: Found token in URL");
        _extractEmailAndUserIdFromToken(_accessToken);
        if (_accessToken != null) {
          html.window.sessionStorage['supabase_access_token'] = _accessToken!;
        }
        if (_userEmail != null) {
          print(
            "SetPasswordScreen: Successfully extracted email from URL token: $_userEmail",
          );
          setState(() => _isLoading = false);
          return;
        }
      }
      setState(() {
        _isLoading = false;
        _errorMessage =
            "Could not process the invitation link. Please contact your administrator.";
      });
    } catch (e) {
      print("SetPasswordScreen: Error processing invite token: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = "Error processing invitation: $e";
      });
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

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
      }
    });
  }

  Future<void> _onSetPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final newPassword = _passwordController.text;

      try {
        // Password Reset Flow
        if (_resetCode != null) {
          print("SetPasswordScreen: Processing password reset with code");
          final response = await Supabase.instance.client.auth.verifyOTP(
            token: _resetCode!,
            type: OtpType.recovery,
            email: _previousUserEmail ?? _userEmail,
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
