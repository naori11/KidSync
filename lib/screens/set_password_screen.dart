import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html; // For web-specific URL reading
import 'dart:convert'; // For JWT decoding

class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});

  // Define a route name for easy navigation
  static const String routeName = '/set-password';

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = true;
  String? _errorMessage;
  String? _userEmail;
  bool _isAuthenticated = false;

  @override
  void initState() {
    super.initState();
    print("SetPasswordScreen: initState called");

    // Check if authenticated
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      print("SetPasswordScreen: User authenticated: ${currentUser.email}");
      _isAuthenticated = true;
      _userEmail = currentUser.email;
      setState(() => _isLoading = false);
      return;
    }

    // If not authenticated, check if we're processing an invite
    if (kIsWeb) {
      print("SetPasswordScreen: Not authenticated, checking for invite tokens");
      _processInviteToken();
    } else {
      // Not web platform and not authenticated, redirect to login
      print(
        "SetPasswordScreen: Not web platform and not authenticated, redirecting to login",
      );
      setState(() => _isLoading = false);
      _redirectToLogin();
    }
  }

  Future<void> _processInviteToken() async {
    try {
      final url = html.window.location.href;
      print("SetPasswordScreen: Processing URL: $url");

      // Let Supabase client handle the authentication flow - it already has logic to parse the URL
      final response = await Supabase.instance.client.auth.getSessionFromUrl(
        Uri.parse(url),
      );

      if (response.session != null) {
        print("SetPasswordScreen: Successfully authenticated with URL token");
        _isAuthenticated = true;
        _userEmail = response.session.user.email;
        setState(() => _isLoading = false);
        return;
      }
    } catch (e) {
      print("SetPasswordScreen: Error processing invite token: $e");
    }

    // If we couldn't authenticate with the URL directly, try to extract the email from token
    try {
      String? token;
      String? email;

      // Try to get token from URL
      final url = html.window.location.href;
      if (url.contains('access_token=')) {
        token = url.split('access_token=')[1].split('&')[0];
      } else if (html.window.sessionStorage.containsKey(
        'supabase_access_token',
      )) {
        token = html.window.sessionStorage['supabase_access_token'];
      }

      if (token != null) {
        // Extract email from token
        final parts = token.split('.');
        if (parts.length > 1) {
          final payload = parts[1];
          final normalized = base64Url.normalize(payload);
          final decoded = utf8.decode(base64Url.decode(normalized));
          final json = jsonDecode(decoded);
          email = json['email'];

          if (email != null) {
            print("SetPasswordScreen: Extracted email from token: $email");
            _userEmail = email;
            setState(() => _isLoading = false);
            return;
          }
        }
      }
    } catch (e) {
      print("SetPasswordScreen: Error extracting email from token: $e");
    }

    // If we couldn't authenticate or extract email, show error
    print("SetPasswordScreen: Could not process invite token");
    setState(() {
      _isLoading = false;
      _errorMessage =
          "Could not process the invitation link. Please contact your administrator.";
    });
  }

  void _redirectToLogin() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
      }
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _onSetPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() => _isLoading = true);
      final newPassword = _passwordController.text;

      try {
        if (_isAuthenticated) {
          // For authenticated users, update password directly
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(password: newPassword),
          );

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Password set successfully! Please log in with your new password.",
              ),
            ),
          );

          // Sign out and redirect to login
          await Supabase.instance.client.auth.signOut();
          Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
        } else if (_userEmail != null) {
          // For non-authenticated users where we extracted the email
          // Initiate a password reset flow instead
          await Supabase.instance.client.auth.resetPasswordForEmail(
            _userEmail!,
            redirectTo: 'https://ksync.netlify.app/#/login',
          );

          if (!mounted) return;

          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                "Password reset email sent. Please check your inbox.",
              ),
            ),
          );

          Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = "Cannot set password: No active user session.";
          });
        }
      } on AuthException catch (error) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = "Error setting password: ${error.message}";
        });
      } catch (error) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = "An unexpected error occurred: ${error.toString()}";
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while processing
    if (_isLoading) {
      return Scaffold(
        appBar: AppBar(title: const Text("Set Your Password")),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 20),
              Text("Processing invitation..."),
            ],
          ),
        ),
      );
    }

    // Show error state if there's an error message and no email
    if (_errorMessage != null && _userEmail == null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed:
                    () => Navigator.of(
                      context,
                    ).pushReplacementNamed(LoginScreen.routeName),
                child: const Text("Go to Login"),
              ),
            ],
          ),
        ),
      );
    }

    // Main set password UI
    return Scaffold(
      appBar: AppBar(title: const Text("Set Your Password")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (_userEmail != null) ...[
                Text(
                  "Set password for $_userEmail",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey[800],
                  ),
                  textAlign: TextAlign.center,
                ),
              ] else ...[
                Text(
                  "Welcome! Please set your password to continue.",
                  style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                  textAlign: TextAlign.center,
                ),
              ],

              if (_errorMessage != null) ...[
                const SizedBox(height: 16),
                Text(
                  _errorMessage!,
                  style: const TextStyle(color: Colors.red, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ],

              const SizedBox(height: 30),
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(
                  labelText: "New Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Password cannot be empty";
                  }
                  if (value.length < 6) {
                    return "Password must be at least 6 characters";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(
                  labelText: "Confirm New Password",
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.lock_outline),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Please confirm your password";
                  }
                  if (value != _passwordController.text) {
                    return "Passwords do not match";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: _onSetPassword,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text(
                    "Set Password and Log In",
                    style: TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed:
                    () => Navigator.of(
                      context,
                    ).pushReplacementNamed(LoginScreen.routeName),
                child: const Text("Cancel and go to login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
