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
  bool _isProcessingAuth = false;

  @override
  void initState() {
    super.initState();
    print("SetPasswordScreen: initState called");

    if (kIsWeb) {
      print("SetPasswordScreen: Running on web platform");

      // Check for stored token in sessionStorage first
      String? accessToken = _getStoredAccessToken();
      if (accessToken != null) {
        print("SetPasswordScreen: Found stored access token in sessionStorage");
        _processAuthWithToken(accessToken);
        return;
      }

      // Check URL directly
      final currentUrl = html.window.location.href;
      print("SetPasswordScreen: Current URL: $currentUrl");

      if (currentUrl.contains('access_token=')) {
        print("SetPasswordScreen: Found access_token in URL directly");
        final tokenPart = currentUrl.split('access_token=')[1].split('&')[0];
        _processAuthWithToken(tokenPart);
        return;
      }
    }

    // Check for an already authenticated user
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser != null) {
      print(
        "SetPasswordScreen: User already authenticated: ${currentUser.email}",
      );
      setState(() {
        _userEmail = currentUser.email;
        _isLoading = false;
      });
      return;
    }

    // No auth source found, redirect to login
    print(
      "SetPasswordScreen: No authentication source found, redirecting to login",
    );
    setState(() => _isLoading = false);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
      }
    });
  }

  // Get access token from session storage
  String? _getStoredAccessToken() {
    if (kIsWeb) {
      final accessToken = html.window.sessionStorage['supabase_access_token'];
      if (accessToken != null && accessToken.isNotEmpty) {
        return accessToken;
      }
    }
    return null;
  }

  // Process authentication with token
  Future<void> _processAuthWithToken(String token) async {
    if (_isProcessingAuth) return; // Prevent multiple processing attempts
    _isProcessingAuth = true;

    try {
      print("SetPasswordScreen: Processing authentication with token");

      // Try to extract email from token for a better UX even if auth fails
      _extractEmailFromToken(token);

      // First approach: Try to set session with token
      final sessionResponse = await Supabase.instance.client.auth.setSession(
        token,
      );

      if (sessionResponse.session != null && sessionResponse.user != null) {
        print("SetPasswordScreen: Successfully authenticated with token");
        setState(() {
          _isLoading = false;
          _userEmail = sessionResponse.user!.email;
        });
        return;
      }

      // Second approach: Try to get session from URL
      try {
        print("SetPasswordScreen: Trying getSessionFromUrl approach");

        // Construct a URL that Supabase can parse
        final fullUrl = 'https://ksync.netlify.app/#access_token=$token';
        final uri = Uri.parse(fullUrl);
        final urlResponse = await Supabase.instance.client.auth
            .getSessionFromUrl(uri);

        if (urlResponse.session != null && urlResponse.session!.user != null) {
          print("SetPasswordScreen: Successfully got session from URL");
          setState(() {
            _isLoading = false;
            _userEmail = urlResponse.session!.user!.email;
          });
          return;
        }
      } catch (e) {
        print("SetPasswordScreen: Error getting session from URL: $e");
      }

      // If we get here, authentication failed
      print("SetPasswordScreen: All authentication attempts failed");
      setState(() {
        _isLoading = false;
        _errorMessage =
            "Failed to authenticate with invitation link. If you already set your password, please go to the login page.";
      });
    } catch (e) {
      print("SetPasswordScreen: Error during authentication: $e");
      setState(() {
        _isLoading = false;
        _errorMessage = "Error processing invitation: ${e.toString()}";
      });
    } finally {
      _isProcessingAuth = false;
    }
  }

  // Extract email from JWT token for better user experience
  void _extractEmailFromToken(String token) {
    try {
      final parts = token.split('.');
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
    } catch (e) {
      print("SetPasswordScreen: Error extracting email from token: $e");
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
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24.0),
                child: Text(
                  _errorMessage!,
                  style: const TextStyle(fontSize: 16),
                  textAlign: TextAlign.center,
                ),
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
