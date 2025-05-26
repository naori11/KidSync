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

  @override
  void initState() {
    super.initState();

    // First check if we have an active session
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      setState(() {
        _isLoading = false;
        _userEmail = currentUser.email;
      });
      print(
        "SetPasswordScreen: User ${currentUser.email} already authenticated",
      );
      return;
    }

    // If no active session, check if this is an invite flow
    if (kIsWeb) {
      _processInviteFlow();
    } else {
      // Not web and no user, redirect to login
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print(
            "SetPasswordScreen: Not web platform and no active user. Redirecting to login.",
          );
          Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
        }
      });
    }
  }

  Future<void> _processInviteFlow() async {
    final currentUrl = html.window.location.href;
    print("SetPasswordScreen: URL check - $currentUrl");

    // Check if this is an invite URL by examining both URL and sessionStorage
    bool isInviteUrl =
        currentUrl.contains('access_token=') ||
        currentUrl.contains('type=invite');

    String? accessToken = html.window.sessionStorage['supabase_access_token'];
    bool hasStoredToken = accessToken != null && accessToken.isNotEmpty;

    bool isInviteFlow = isInviteUrl || hasStoredToken;
    print("SetPasswordScreen: Is invite flow - $isInviteFlow");

    if (!isInviteFlow) {
      // Not an invite flow, redirect to login
      setState(() => _isLoading = false);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          print("SetPasswordScreen: Not an invite flow. Redirecting to login.");
          Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
        }
      });
      return;
    }

    print("SetPasswordScreen: Processing invite flow...");

    // Try to extract and process the token
    try {
      // First try to use the URL parameters directly if they're available
      final response = await _tryAuthenticate();

      if (response) {
        // Get the current user after authentication
        final user = Supabase.instance.client.auth.currentUser;
        if (user != null) {
          setState(() {
            _isLoading = false;
            _userEmail = user.email;
          });
          print("SetPasswordScreen: User ${user.email} authenticated");
          return;
        }
      }

      // If we got here, authentication failed
      setState(() {
        _isLoading = false;
        _errorMessage =
            "Failed to authenticate with invitation link. Please contact administrator.";
      });
      print("SetPasswordScreen: Authentication failed");

      // Optional: Extract email from token for a better user experience
      _tryExtractEmailFromToken();
    } catch (e) {
      setState(() {
        _isLoading = false;
        _errorMessage = "Error processing invitation: ${e.toString()}";
      });
      print("SetPasswordScreen: Error processing invitation: $e");

      // Optional: Extract email from token for a better user experience
      _tryExtractEmailFromToken();
    }
  }

  // Try to extract email from JWT token for better UX
  void _tryExtractEmailFromToken() {
    try {
      final accessToken = html.window.sessionStorage['supabase_access_token'];
      if (accessToken != null && accessToken.isNotEmpty) {
        // JWT tokens have three parts separated by dots
        final parts = accessToken.split('.');
        if (parts.length > 1) {
          // Decode the payload (middle part)
          final payload = parts[1];
          // Base64 decode and parse as JSON
          final normalized = base64Url.normalize(payload);
          final decoded = utf8.decode(base64Url.decode(normalized));
          final json = jsonDecode(decoded);

          if (json['email'] != null) {
            setState(() {
              _userEmail = json['email'];
            });
            print("SetPasswordScreen: Extracted email from token: $_userEmail");
          }
        }
      }
    } catch (e) {
      print("SetPasswordScreen: Error extracting email from token: $e");
    }
  }

  // Try different authentication approaches
  Future<bool> _tryAuthenticate() async {
    // First, try to use signInWithPassword with the email from the token
    try {
      // Extract access_token from different sources
      String? accessToken;

      // 1. Try session storage first (from our script)
      accessToken = html.window.sessionStorage['supabase_access_token'];

      if (accessToken == null || accessToken.isEmpty) {
        // 2. Try URL params if session storage didn't work
        final url = html.window.location.href;
        if (url.contains('access_token=')) {
          accessToken = url.split('access_token=')[1].split('&')[0];
        }
      }

      if (accessToken != null && accessToken.isNotEmpty) {
        print(
          "SetPasswordScreen: Found access token, attempting to authenticate",
        );

        // Try to extract email from JWT token
        try {
          final parts = accessToken.split('.');
          if (parts.length > 1) {
            final payload = parts[1];
            final normalized = base64Url.normalize(payload);
            final decoded = utf8.decode(base64Url.decode(normalized));
            final json = jsonDecode(decoded);
            final email = json['email'];

            if (email != null) {
              print(
                "SetPasswordScreen: Trying to sign in with email: $email and OTP",
              );

              // Use signInWithOtp to start a passwordless login flow
              await Supabase.instance.client.auth.signInWithOtp(email: email);

              print("SetPasswordScreen: OTP sign-in initiated.");

              // At this point, we don't have the user yet, but we've started the flow
              // The user will need to set their password to complete it
              return true;
            }
          }
        } catch (e) {
          print("SetPasswordScreen: Error during token processing: $e");
        }

        // If we couldn't extract email, try with the token directly
        try {
          final response = await Supabase.instance.client.auth.getSessionFromUrl(
            Uri.parse(
              'https://ksync.netlify.app/#/set-password#access_token=$accessToken',
            ),
          );

          if (response.session != null) {
            print("SetPasswordScreen: Got session from URL");
            return true;
          }
        } catch (e) {
          print("SetPasswordScreen: Error getting session from URL: $e");
        }
      }

      return false;
    } catch (e) {
      print("SetPasswordScreen: All authentication attempts failed: $e");
      return false;
    }
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
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: newPassword),
        );

        if (!mounted) return;
        setState(() => _isLoading = false);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Password set successfully! Please log in."),
          ),
        );

        // Navigate to login screen after successful password set
        Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
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

    // Show error state if there's an error message
    if (_errorMessage != null) {
      return Scaffold(
        appBar: AppBar(title: const Text("Error")),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 60),
              const SizedBox(height: 20),
              Text(
                _errorMessage!,
                style: const TextStyle(fontSize: 16),
                textAlign: TextAlign.center,
              ),
              if (_userEmail != null) ...[
                const SizedBox(height: 10),
                Text(
                  "Email: $_userEmail",
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ],
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

    // Main set password UI - user is either authenticated or we've extracted their email
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
            ],
          ),
        ),
      ),
    );
  }
}
