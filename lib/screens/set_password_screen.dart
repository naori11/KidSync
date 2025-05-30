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
  String? _oneTimeCode;
  bool _isNewUser = false; // Flag to track if this is a new user invite
  String? _previousUserEmail;

  @override
  void initState() {
    super.initState();
    print("SetPasswordScreen: initState called");

    // Check if we have a code in the URL (could be reset or invite)
    if (kIsWeb) {
      final url = html.window.location.href;
      // Check for code parameter in URL
      if (url.contains('?code=') || url.contains('&code=')) {
        print("SetPasswordScreen: One-time code detected");
        _processOneTimeCode(url);
        return;
      }
    }

    // If no code, check if user is authenticated
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      print("SetPasswordScreen: User authenticated: ${currentUser.email}");
      _isAuthenticated = true;
      _userEmail = currentUser.email;
      _userId = currentUser.id;
      setState(() => _isLoading = false);
    } else {
      // No code and no authenticated user, redirect to login
      print("SetPasswordScreen: Not authenticated, redirecting to login");
      setState(() => _isLoading = false);
      _redirectToLogin();
    }
  }

  Future<void> _processOneTimeCode(String url) async {
    try {
      // Extract the code from URL
      String code = "";
      if (url.contains('?code=')) {
        code = url.split('?code=')[1];
      } else if (url.contains('&code=')) {
        code = url.split('&code=')[1];
      }

      if (code.contains('&')) {
        code = code.split('&')[0];
      }

      _oneTimeCode = code;
      print("SetPasswordScreen: Extracted one-time code: $_oneTimeCode");

      // Check if a user is logged in
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        // Store the current user's email before proceeding
        _previousUserEmail = currentUser.email;

        // For security, sign out the current user
        print("SetPasswordScreen: User logged in, signing out for security");
        await Supabase.instance.client.auth.signOut();
      }

      // Since we can't verify the type without setting the password,
      // We'll just assume it's valid and show the form
      // The actual verification will happen when setting the password
      setState(() => _isLoading = false);
    } catch (e) {
      print("SetPasswordScreen: Error processing one-time code: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = "Error processing link: $e";
      });
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
        // Case 1: Using a one-time code (either signup or reset)
        if (_oneTimeCode != null) {
          print(
            "SetPasswordScreen: Using one-time code to set/update password",
          );

          // Try as signup first
          try {
            print("SetPasswordScreen: Trying code as signup (new user)");
            final response = await Supabase.instance.client.auth.verifyOTP(
              token: _oneTimeCode!,
              type: OtpType.signup,
            );

            if (response.session != null) {
              // Successfully verified as signup
              _isNewUser = true;
              _userEmail = response.user?.email;

              // Now update the password
              await Supabase.instance.client.auth.updateUser(
                UserAttributes(password: newPassword),
              );

              print("SetPasswordScreen: Password set successful for new user");
              _passwordSetSuccess(
                "Your account has been created successfully!",
              );
              return;
            }
          } catch (e) {
            print(
              "SetPasswordScreen: Not a signup code, trying as password reset: $e",
            );

            // Try as recovery
            try {
              final recoveryResponse = await Supabase.instance.client.auth
                  .verifyOTP(token: _oneTimeCode!, type: OtpType.recovery);

              if (recoveryResponse.session != null) {
                // Successfully verified as password reset
                _isNewUser = false;
                _userEmail = recoveryResponse.user?.email;

                // Now update the password
                await Supabase.instance.client.auth.updateUser(
                  UserAttributes(password: newPassword),
                );

                print("SetPasswordScreen: Password reset successful");
                _passwordSetSuccess(
                  "Your password has been reset successfully!",
                );
                return;
              }
            } catch (e2) {
              print("SetPasswordScreen: Not a valid reset code either: $e2");
              throw Exception(
                "Invalid or expired link. Please request a new one.",
              );
            }
          }
        }
        // Case 2: For already authenticated user updating their password
        else if (_isAuthenticated) {
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

    // Show error state if there's an error message and no code
    if (_errorMessage != null && _oneTimeCode == null && !_isAuthenticated) {
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

                    // Subtitle with context
                    if (_oneTimeCode != null) ...[
                      if (_userEmail != null) ...[
                        Text(
                          "Set password for $_userEmail",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ] else ...[
                        Text(
                          "Set your password",
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ] else ...[
                      Text(
                        "Update your password",
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
                              "You have been logged out to process this password action.",
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
                          "Confirm Password",
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
