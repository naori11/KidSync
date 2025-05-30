import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html; // For web-specific URL reading
import 'dart:convert'; // For JWT decoding
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
  String?
  _previousUserEmail; // To store the email of a previously logged in user

  @override
  void initState() {
    super.initState();
    print("SetPasswordScreen: initState called");

    // Always check for reset token first
    if (kIsWeb) {
      final url = html.window.location.href;
      final hasToken =
          url.contains('access_token=') ||
          html.window.sessionStorage.containsKey('supabase_access_token');

      if (hasToken) {
        print("SetPasswordScreen: Reset token detected - processing");
        _processResetToken();
        return;
      }
    }

    // If no token in URL, check if user is authenticated
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      print("SetPasswordScreen: User authenticated: ${currentUser.email}");
      _isAuthenticated = true;
      _userEmail = currentUser.email;
      _userId = currentUser.id;
      setState(() => _isLoading = false);
    } else {
      // No token and no authenticated user, redirect to login
      print("SetPasswordScreen: Not authenticated, redirecting to login");
      setState(() => _isLoading = false);
      _redirectToLogin();
    }
  }

  Future<void> _processResetToken() async {
    try {
      // Get token from sessionStorage or URL
      _accessToken = html.window.sessionStorage['supabase_access_token'];

      if (_accessToken == null) {
        final url = html.window.location.href;
        if (url.contains('access_token=')) {
          _accessToken = url.split('access_token=')[1].split('&')[0];
          if (_accessToken!.contains('&')) {
            _accessToken = _accessToken!.split('&')[0];
          }
          html.window.sessionStorage['supabase_access_token'] = _accessToken!;
        }
      }

      if (_accessToken != null) {
        // Extract user info from token
        _extractEmailAndUserIdFromToken(_accessToken);

        // Check if another user is logged in
        final currentUser = Supabase.instance.client.auth.currentUser;
        if (currentUser != null &&
            _userEmail != null &&
            currentUser.email != _userEmail) {
          // Store the current user's email before signing out
          _previousUserEmail = currentUser.email;

          // Sign out current user as we're prioritizing the reset token
          print("SetPasswordScreen: Different user logged in, signing out");
          await Supabase.instance.client.auth.signOut();
        }

        // Set state to show the reset password form
        if (_userEmail != null) {
          setState(() {
            _isLoading = false;
            if (_previousUserEmail != null) {
              // Show notification about the session change
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'You were logged in as $_previousUserEmail. Now setting password for $_userEmail',
                      ),
                      duration: const Duration(seconds: 5),
                      backgroundColor: Colors.amber,
                    ),
                  );
                }
              });
            }
          });
          return;
        }
      }

      // If we couldn't process the token
      setState(() {
        _isLoading = false;
        _errorMessage =
            "Could not process the password reset link. It may have expired.";
      });
    } catch (e) {
      print("SetPasswordScreen: Error processing token: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = "Error processing password reset: $e";
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

  Future<void> _onSetPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final newPassword = _passwordController.text;

      try {
        // For password reset with token
        if (_accessToken != null && _userEmail != null) {
          print(
            "SetPasswordScreen: Setting password via token for $_userEmail",
          );

          try {
            // Try the Supabase client approach first
            final response = await Supabase.instance.client.auth.setSession(
              _accessToken!,
            );

            if (response.session != null) {
              print(
                "SetPasswordScreen: Successfully established session with token",
              );

              // Verify we're updating the correct user
              final tokenUser = response.user;
              if (tokenUser?.email != _userEmail) {
                throw Exception(
                  "Token user email mismatch: expected $_userEmail, got ${tokenUser?.email}",
                );
              }

              // Update the password
              await Supabase.instance.client.auth.updateUser(
                UserAttributes(password: newPassword),
              );

              _passwordSetSuccess("Password has been reset successfully!");
              return;
            }
          } catch (e) {
            print("SetPasswordScreen: Supabase client approach failed: $e");

            // Fall back to direct API approach
            try {
              // Direct API call with access token
              final headers = {
                'Authorization': 'Bearer $_accessToken',
                'apikey':
                    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvdWl0Z3BxcXVkaHFkY2J1aGJ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc2NDk5OTUsImV4cCI6MjA2MzIyNTk5NX0.FuWUR1QHFiWzPwZa0HvW0yLhJfHHw0EhBLibA0t0Dsw',
                'Content-Type': 'application/json',
              };

              // Verify token with user profile
              final supabaseUrl =
                  'https://zouitgpqqudhqdcbuhbz.supabase.co/auth/v1/user';

              final response = await html.HttpRequest.request(
                supabaseUrl,
                method: 'GET',
                requestHeaders: headers,
              );

              if (response.status == 200) {
                print("SetPasswordScreen: Token is valid, updating password");

                // Update password
                final updateResponse = await html.HttpRequest.request(
                  supabaseUrl,
                  method: 'PUT',
                  requestHeaders: headers,
                  sendData: jsonEncode({'password': newPassword}),
                );

                if (updateResponse.status == 200) {
                  print(
                    "SetPasswordScreen: Password updated successfully via direct API",
                  );
                  _passwordSetSuccess("Password has been reset successfully!");
                  return;
                } else {
                  print(
                    "SetPasswordScreen: Failed to update password: ${updateResponse.responseText}",
                  );
                  throw Exception(
                    "Failed to update password: ${updateResponse.status}",
                  );
                }
              } else {
                print(
                  "SetPasswordScreen: Token validation failed: ${response.responseText}",
                );
                throw Exception("Invalid access token");
              }
            } catch (e) {
              print("SetPasswordScreen: Direct API approach failed: $e");
              throw Exception("Failed to set password: $e");
            }
          }
        } else if (_isAuthenticated) {
          // For already authenticated user updating their password
          print(
            "SetPasswordScreen: User is authenticated, updating password for $_userEmail",
          );
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(password: newPassword),
          );
          _passwordSetSuccess("Your password has been updated successfully!");
        } else {
          throw Exception(
            "No valid authentication context for password update",
          );
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

  void _passwordSetSuccess(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );

    // Sign out and redirect to login
    Supabase.instance.client.auth.signOut();
    Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Show loading screen
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
                "Processing...",
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

    // Show notification if previous user was signed out
    if (_previousUserEmail != null && _userEmail != null) {
      // Notification is handled via Snackbar in processResetToken
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

                    // Subtitle with email
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

                    // Show previous user warning if applicable
                    if (_previousUserEmail != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.amber[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.amber),
                        ),
                        child: Column(
                          children: [
                            Row(
                              children: [
                                Icon(
                                  Icons.info_outline,
                                  color: Colors.amber[800],
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  "Account Switch",
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.amber[800],
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "You were previously logged in as $_previousUserEmail. "
                              "You have been logged out to set password for $_userEmail.",
                              style: TextStyle(color: Colors.amber[900]),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // Error message if any
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
