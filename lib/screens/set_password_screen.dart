import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html; // For web-specific URL reading

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
  bool _isLoading = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();

    // Check if this is an invite link via URL or sessionStorage
    bool isInviteFlow = false;
    if (kIsWeb) {
      final currentUrl = html.window.location.href;

      // First check the URL directly
      isInviteFlow =
          currentUrl.contains('access_token=') ||
          currentUrl.contains('type=invite');

      // If not found in URL, check sessionStorage (from our script in index.html)
      if (!isInviteFlow) {
        final token = html.window.sessionStorage['supabase_invite_token'];
        isInviteFlow = token != null && token.isNotEmpty;

        if (isInviteFlow) {
          print("SetPasswordScreen: Found invite token in sessionStorage");
        }
      }

      print("SetPasswordScreen: URL check - $currentUrl");
      print("SetPasswordScreen: Is invite flow - $isInviteFlow");
    }

    // If it's an invite link, try to process the token
    if (isInviteFlow) {
      setState(() => _isLoading = true);

      print(
        "SetPasswordScreen: Processing invite flow, waiting for token processing...",
      );

      // Process the token
      _processInviteToken()
          .then((_) {
            // Check if user is now logged in
            final currentUser = Supabase.instance.client.auth.currentUser;
            if (currentUser != null) {
              print(
                "SetPasswordScreen: User ${currentUser.email} is now active after token processing.",
              );
              if (mounted) setState(() => _isLoading = false);
            } else {
              print("SetPasswordScreen: Failed to authenticate with token.");
              if (mounted) {
                setState(() {
                  _isLoading = false;
                  _errorMessage =
                      "Failed to process invitation. Please contact administrator.";
                });
              }
            }
          })
          .catchError((e) {
            print("SetPasswordScreen: Error processing invite token: $e");
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = "Error processing invitation: ${e.toString()}";
              });
            }
          });
    } else {
      // Regular flow for non-invite links
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            print(
              "SetPasswordScreen: No active user and not an invite flow. Redirecting to login.",
            );
            Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
          }
        });
      } else {
        print(
          "SetPasswordScreen: User ${currentUser.email} is setting password.",
        );
      }
    }
  }

  // Updated function to process the invite token from URL or sessionStorage
  Future<void> _processInviteToken() async {
    if (!kIsWeb) return;

    String? accessToken;
    final currentUrl = html.window.location.href;

    // First try to get token from the URL
    if (currentUrl.contains('#/set-password#access_token=')) {
      final tokenPart = currentUrl.split('#access_token=')[1];
      accessToken = tokenPart.split('&')[0];
      print("SetPasswordScreen: Extracted token from URL double hash");
    } else if (currentUrl.contains('access_token=')) {
      final tokenPart = currentUrl.split('access_token=')[1];
      accessToken = tokenPart.split('&')[0];
      print("SetPasswordScreen: Extracted token from URL standard format");
    } else {
      // Try to get token from sessionStorage
      accessToken = html.window.sessionStorage['supabase_invite_token'];
      if (accessToken != null && accessToken.contains('&')) {
        accessToken = accessToken.split('&')[0];
      }
      print("SetPasswordScreen: Using token from sessionStorage");
    }

    if (accessToken != null) {
      try {
        print("SetPasswordScreen: Attempting to authenticate with token");

        // Try to establish a session with the token
        final response = await Supabase.instance.client.auth.setSession(
          accessToken,
        );

        if (response.session != null) {
          print("SetPasswordScreen: Successfully authenticated with token");
          return; // Success
        } else {
          print("SetPasswordScreen: Failed to authenticate with token");
          throw Exception("Failed to process invitation token");
        }
      } catch (e) {
        print("SetPasswordScreen: Error setting session: $e");
        throw e;
      }
    } else {
      throw Exception("No token found");
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

    // If currentUser is null and we're not in loading or error state, redirect to login
    if (Supabase.instance.client.auth.currentUser == null && mounted) {
      // This is a safety check in case our initState logic didn't handle all cases
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
              Text(
                "Welcome! Please set your password to continue.",
                style: TextStyle(fontSize: 16, color: Colors.grey[700]),
                textAlign: TextAlign.center,
              ),
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
