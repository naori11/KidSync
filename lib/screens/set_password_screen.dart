import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'dart:convert';
import 'dart:async';

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
  String? _userId;
  bool _isAuthenticated = false;
  String? _accessToken;

  @override
  void initState() {
    super.initState();
    print("SetPasswordScreen: initState called");

    // Check if we're processing a password reset
    if (kIsWeb) {
      print("SetPasswordScreen: Checking for reset tokens");

      // Check if we have a password reset token in the URL or session storage
      final url = html.window.location.href;
      final hasResetToken =
          url.contains('access_token=') ||
          html.window.sessionStorage.containsKey('supabase_access_token');

      // If this is a password reset flow, sign out any current user
      if (hasResetToken) {
        print(
          "SetPasswordScreen: Reset token detected, signing out any current user",
        );
        // Sign out the current user first to avoid security issues
        Supabase.instance.client.auth.signOut();

        // Process the reset token
        _processInviteToken();
        return;
      }
    }

    // Check if authenticated (only if we didn't find a reset token)
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      print("SetPasswordScreen: User authenticated: ${currentUser.email}");
      _isAuthenticated = true;
      _userEmail = currentUser.email;
      _userId = currentUser.id;
      setState(() => _isLoading = false);
      return;
    } else {
      print("SetPasswordScreen: Not authenticated and no reset token found");
      setState(() => _isLoading = false);
      _redirectToLogin();
    }
  }

  void _processInviteToken() async {
    try {
      // First try to extract token from sessionStorage (from our script)
      _accessToken = html.window.sessionStorage['supabase_access_token'];

      if (_accessToken != null) {
        print("SetPasswordScreen: Found token in sessionStorage");

        // Extract information from token without authenticating
        _extractEmailAndUserIdFromToken(_accessToken);

        // If we have enough info, show the set password form
        if (_userEmail != null) {
          print(
            "SetPasswordScreen: Successfully extracted email from token: $_userEmail",
          );
          setState(() => _isLoading = false);
          return;
        }
      }

      // If no token in sessionStorage, try URL
      final url = html.window.location.href;
      print("SetPasswordScreen: Checking URL for token: $url");

      if (url.contains('access_token=')) {
        // Extract token from URL
        _accessToken = url.split('access_token=')[1].split('&')[0];
        print("SetPasswordScreen: Found token in URL");

        // Extract information from token without authenticating
        _extractEmailAndUserIdFromToken(_accessToken);

        // Store token in sessionStorage for later use
        if (_accessToken != null) {
          html.window.sessionStorage['supabase_access_token'] = _accessToken!;
        }

        if (_userEmail != null) {
          print(
            "SetPasswordScreen: Successfully extracted email from URL token: $_userEmail",
          );
          setState(() => _isLoading = false);

          // Show a message if a different user was previously logged in
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Setting password for account: $_userEmail'),
                  duration: const Duration(seconds: 5),
                ),
              );
            }
          });
          return;
        }
      }

      // If we couldn't extract anything useful
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

  void _extractEmailAndUserIdFromToken(String? token) {
    if (token == null) return;

    try {
      final parts = token.split('.');
      if (parts.length > 1) {
        final payload = parts[1];
        final normalized = base64Url.normalize(payload);
        final decoded = utf8.decode(base64Url.decode(normalized));
        final json = jsonDecode(decoded);

        _userEmail = json['email'];
        _userId = json['sub']; // 'sub' contains the user ID in JWT

        print(
          "SetPasswordScreen: Extracted from token - Email: $_userEmail, User ID: $_userId",
        );
      }
    } catch (e) {
      print("SetPasswordScreen: Error extracting data from token: $e");
    }
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
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final newPassword = _passwordController.text;

      try {
        // Check if we're using a reset token with a specific user email
        if (_userEmail != null && _accessToken != null) {
          print(
            "SetPasswordScreen: Setting password via token for $_userEmail",
          );

          try {
            // Try to set the session using Supabase's mechanism
            final response = await Supabase.instance.client.auth.setSession(
              _accessToken!,
            );

            if (response.session != null) {
              print("SetPasswordScreen: Successfully set session with token");

              // Double-check that we're updating the right user
              final tokenUser = response.user;
              if (tokenUser?.email != _userEmail) {
                throw Exception("Token email doesn't match expected user!");
              }

              // Now update the password
              await Supabase.instance.client.auth.updateUser(
                UserAttributes(password: newPassword),
              );

              _passwordSetSuccess();
              return;
            } else {
              throw Exception("Could not establish session with token");
            }
          } catch (e) {
            print("SetPasswordScreen: Supabase client approach failed: $e");

            // Fall back to direct API approach if available
            // (keeping your current direct API implementation here)
            // ...

            setState(() {
              _isLoading = false;
              _errorMessage =
                  "Unable to set password. The reset link may have expired. Please request a new reset link.";
            });
          }
        } else if (_isAuthenticated && _userEmail != null) {
          // Direct password update for authenticated users
          print(
            "SetPasswordScreen: User is authenticated, directly updating password for $_userEmail",
          );
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(password: newPassword),
          );

          _passwordSetSuccess();
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage =
                "Missing authentication details. Please try again or contact your administrator.";
          });
        }
      } catch (e) {
        print("SetPasswordScreen: Error setting password: $e");
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = "Error setting password: $e";
        });
      }
    }
  }

  void _passwordSetSuccess() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          "Password set successfully! Please log in with your new password.",
        ),
      ),
    );

    // Sign out and redirect to login
    Supabase.instance.client.auth.signOut();
    Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen while processing
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              SizedBox(height: 20),
              Text(
                "Processing invitation...",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    // Show error state if there's an error message and no email
    if (_errorMessage != null && _userEmail == null) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "KidSync",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 20),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          () => Navigator.of(
                            context,
                          ).pushReplacementNamed(LoginScreen.routeName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text("Go to Login"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Main set password UI
    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Title
                    const Text(
                      "KidSync",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Subtitle
                    if (_userEmail != null) ...[
                      Text(
                        "Set password for $_userEmail",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ] else ...[
                      Text(
                        "Welcome! Please set your password to continue.",
                        style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                        textAlign: TextAlign.center,
                      ),
                    ],

                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],

                    const SizedBox(height: 24),

                    // New Password field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "New Password",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          decoration: InputDecoration(
                            hintText: "Enter your password",
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(color: Colors.green),
                            ),
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
                      ],
                    ),

                    const SizedBox(height: 16),

                    // Confirm Password field
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Confirm New Password",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                          ),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _confirmPasswordController,
                          decoration: InputDecoration(
                            hintText: "Confirm your password",
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 16,
                            ),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            enabledBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: BorderSide(color: Colors.grey[300]!),
                            ),
                            focusedBorder: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(4),
                              borderSide: const BorderSide(color: Colors.green),
                            ),
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
                      ],
                    ),

                    const SizedBox(height: 24),

                    // Set Password Button
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _onSetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child: const Text(
                          "Set Password",
                          style: TextStyle(fontSize: 16),
                        ),
                      ),
                    ),

                    const SizedBox(height: 16),

                    // Cancel link
                    TextButton(
                      onPressed:
                          () => Navigator.of(
                            context,
                          ).pushReplacementNamed(LoginScreen.routeName),
                      style: TextButton.styleFrom(
                        foregroundColor: Colors.green,
                      ),
                      child: const Text("Cancel and go to login"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
