import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'dart:convert';

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
  final _userEmailController = TextEditingController(); // NEW: For email input
  bool _isLoading = true;
  String? _errorMessage;
  String? _userEmail;
  String? _userId;
  bool _isAuthenticated = false;
  String? _accessToken;
  String? _resetCode;
  String? _previousUserEmail;
  bool _showEmailInput = false; // NEW: To show email input when needed

  @override
  void initState() {
    super.initState();
    print("SetPasswordScreen: initState called");

    // Check for reset code (password reset flow)
    if (kIsWeb &&
        html.window.sessionStorage.containsKey('kidsync_reset_code')) {
      _resetCode = html.window.sessionStorage['kidsync_reset_code'];
      print(
        "SetPasswordScreen: Found reset code in session storage: $_resetCode",
      );

      // Check if we have the email too
      if (html.window.sessionStorage.containsKey('kidsync_reset_email')) {
        _userEmail = html.window.sessionStorage['kidsync_reset_email'];
        _userEmailController.text = _userEmail ?? '';
        print("SetPasswordScreen: Found email in session storage: $_userEmail");
      }

      // Check if another user is logged in
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser != null) {
        _previousUserEmail = currentUser.email;
        // Sign out the current user for security
        Supabase.instance.client.auth.signOut().then((_) {
          print("SetPasswordScreen: Logged out user $_previousUserEmail");
          setState(() => _isLoading = false);
        });
      } else {
        setState(() => _isLoading = false);
      }
      return;
    }

    // Process the invite token
    if (kIsWeb) {
      print("SetPasswordScreen: Checking for reset tokens");

      _processInviteToken();
      return;
    }

    // Check if authenticated
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

  Future<void> _onSetPassword() async {
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      final newPassword = _passwordController.text;

      try {
        // Handle password reset with reset code
        if (_resetCode != null) {
          print("SetPasswordScreen: Processing password reset with code");

          // Get email from input field or state
          String? email;

          // Check if we have an email already
          if (_userEmailController.text.isNotEmpty) {
            email = _userEmailController.text;
          } else if (_userEmail != null && _userEmail!.isNotEmpty) {
            email = _userEmail;
          }

          // If we don't have an email, ask for it
          if (email == null || email.isEmpty) {
            setState(() {
              _isLoading = false;
              _showEmailInput = true;
              _errorMessage =
                  "Please enter your email to complete the password reset";
            });
            return;
          }

          try {
            print(
              "SetPasswordScreen: Verifying OTP with code: $_resetCode and email: $email",
            );

            final response = await Supabase.instance.client.auth.verifyOTP(
              token: _resetCode!,
              type: OtpType.recovery,
              email: email, // Include the email with the verification
            );

            if (response.session != null && response.user != null) {
              _userEmail = response.user!.email;
              print(
                "SetPasswordScreen: Successfully verified OTP for $_userEmail",
              );

              // Update password now that we have a session
              await Supabase.instance.client.auth.updateUser(
                UserAttributes(password: newPassword),
              );

              // Clear the reset code
              if (kIsWeb) {
                html.window.sessionStorage.remove('kidsync_reset_code');
                html.window.sessionStorage.remove('kidsync_reset_email');
              }

              _passwordSetSuccess("Your password has been reset successfully!");
              return;
            } else {
              throw Exception("Failed to verify the recovery code");
            }
          } catch (e) {
            print("SetPasswordScreen: Error verifying reset code: $e");
            throw Exception(
              "Invalid or expired reset link. Please request a new one.",
            );
          }
        }

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

              _passwordSetSuccess("Your account has been set up successfully!");
              return;
            } else {
              throw Exception("Could not establish session with token");
            }
          } catch (e) {
            print("SetPasswordScreen: Supabase client approach failed: $e");

            // Fall back to direct API approach
            try {
              final headers = {
                'Authorization': 'Bearer $_accessToken',
                'apikey':
                    'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvdWl0Z3BxcXVkaHFkY2J1aGJ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc2NDk5OTUsImV4cCI6MjA2MzIyNTk5NX0.FuWUR1QHFiWzPwZa0HvW0yLhJfHHw0EhBLibA0t0Dsw',
                'Content-Type': 'application/json',
              };

              // First verify the token by getting the user profile
              final supabaseUrl =
                  'https://zouitgpqqudhqdcbuhbz.supabase.co/auth/v1/user';

              final response = await html.HttpRequest.request(
                supabaseUrl,
                method: 'GET',
                requestHeaders: headers,
              );

              if (response.status == 200) {
                print("SetPasswordScreen: Token is valid, updating password");

                final updateResponse = await html.HttpRequest.request(
                  supabaseUrl,
                  method: 'PUT',
                  requestHeaders: headers,
                  sendData: jsonEncode({'password': newPassword}),
                );

                if (updateResponse.status == 200) {
                  print("SetPasswordScreen: Password updated successfully");
                  _passwordSetSuccess(
                    "Your account has been set up successfully!",
                  );
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

              setState(() {
                _isLoading = false;
                _errorMessage =
                    "Unable to set password. The token may have expired. Please contact your administrator.";
              });
            }
          }
        } else if (_isAuthenticated && _userEmail != null) {
          // Direct password update for authenticated users
          print(
            "SetPasswordScreen: User is authenticated, directly updating password for $_userEmail",
          );
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(password: newPassword),
          );

          _passwordSetSuccess("Your password has been updated successfully!");
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
    _userEmailController.dispose();
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

    // Show error state if there's an error message and no valid token
    if (_errorMessage != null &&
        _accessToken == null &&
        _resetCode == null &&
        !_isAuthenticated &&
        !_showEmailInput) {
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

                    // Subtitle with context message
                    Text(
                      _resetCode != null
                          ? "Set your new password"
                          : (_accessToken != null
                              ? "Set your password to activate your account"
                              : "Update your password"),
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),

                    // Show user email if available
                    if (_userEmail != null && !_showEmailInput) ...[
                      const SizedBox(height: 4),
                      Text(
                        _userEmail!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
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
                              "You have been logged out to process this password reset.",
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

                    const SizedBox(height: 16),

                    // Email input field (only shown when needed)
                    if (_showEmailInput ||
                        (_resetCode != null && _userEmail == null)) ...[
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            "Email Address",
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: FontWeight.normal,
                            ),
                          ),
                          const SizedBox(height: 8),
                          TextFormField(
                            controller: _userEmailController,
                            decoration: InputDecoration(
                              hintText: "Enter your email address",
                              contentPadding: const EdgeInsets.symmetric(
                                vertical: 15,
                                horizontal: 16,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: BorderSide(
                                  color: Colors.grey[300]!,
                                ),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(4),
                                borderSide: const BorderSide(
                                  color: Colors.green,
                                ),
                              ),
                            ),
                            keyboardType: TextInputType.emailAddress,
                            validator: (value) {
                              if (value == null || value.isEmpty) {
                                return "Email address cannot be empty";
                              }
                              if (!value.contains('@') ||
                                  !value.contains('.')) {
                                return "Please enter a valid email address";
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                    ],

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
                        child: Text(
                          _resetCode != null
                              ? "Reset Password"
                              : (_accessToken != null
                                  ? "Create Account"
                                  : "Update Password"),
                          style: const TextStyle(fontSize: 16),
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
