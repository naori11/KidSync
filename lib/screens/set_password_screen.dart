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
      _userId = currentUser.id;
      setState(() => _isLoading = false);
      return;
    }
    
    // If not authenticated, check if we're processing an invite
    if (kIsWeb) {
      print("SetPasswordScreen: Not authenticated, checking for invite tokens");
      _processInviteToken();
    } else {
      // Not web platform and not authenticated, redirect to login
      print("SetPasswordScreen: Not web platform and not authenticated, redirecting to login");
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
          print("SetPasswordScreen: Successfully extracted email from token: $_userEmail");
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
          print("SetPasswordScreen: Successfully extracted email from URL token: $_userEmail");
          setState(() => _isLoading = false);
          return;
        }
      }
      
      // If we couldn't extract anything useful
      setState(() {
        _isLoading = false;
        _errorMessage = "Could not process the invitation link. Please contact your administrator.";
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
        
        print("SetPasswordScreen: Extracted from token - Email: $_userEmail, User ID: $_userId");
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
        if (_isAuthenticated) {
          // Method 1: Direct password update for authenticated users
          print("SetPasswordScreen: User is authenticated, directly updating password");
          await Supabase.instance.client.auth.updateUser(
            UserAttributes(password: newPassword),
          );
          
          _passwordSetSuccess();
        } else if (_userEmail != null && _accessToken != null) {
          // Method 2: For non-authenticated users with token, manually create a session
          print("SetPasswordScreen: Trying to create a session with the token");
          
          try {
            // This will directly use the access token to make a request
            // without needing a valid refresh token
            final headers = {
              'Authorization': 'Bearer $_accessToken',
              'apikey': 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpvdWl0Z3BxcXVkaHFkY2J1aGJ6Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NDc2NDk5OTUsImV4cCI6MjA2MzIyNTk5NX0.FuWUR1QHFiWzPwZa0HvW0yLhJfHHw0EhBLibA0t0Dsw', // Use the correct API key from Supabase instance
              'Content-Type': 'application/json'
            };
            
            // First verify the token by getting the user profile
            final supabaseUrl = 'https://zouitgpqqudhqdcbuhbz.supabase.co/auth/v1/user';
            
            // We need to use raw HttpRequest because Supabase client methods require refresh tokens
            final response = await html.HttpRequest.request(
              supabaseUrl,
              method: 'GET',
              requestHeaders: headers,
            );
            
            if (response.status == 200) {
              print("SetPasswordScreen: Token is valid, updating password");
              
              // Now send the password update request
              final updateResponse = await html.HttpRequest.request(
                supabaseUrl,
                method: 'PUT',
                requestHeaders: headers,
                sendData: jsonEncode({
                  'password': newPassword
                }),
              );
              
              if (updateResponse.status == 200) {
                print("SetPasswordScreen: Password updated successfully");
                _passwordSetSuccess();
                return;
              } else {
                print("SetPasswordScreen: Failed to update password: ${updateResponse.responseText}");
                throw Exception("Failed to update password: ${updateResponse.status}");
              }
            } else {
              print("SetPasswordScreen: Token validation failed: ${response.responseText}");
              throw Exception("Invalid access token");
            }
          } catch (e) {
            print("SetPasswordScreen: Direct API approach failed: $e");
            
            // Fall back to alternative approach - try with Supabase client
            try {
              // Try to set the session using Supabase's mechanism
              final response = await Supabase.instance.client.auth.setSession(_accessToken!);
              
              if (response.session != null) {
                print("SetPasswordScreen: Successfully set session with token");
                
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
              
              // Final fallback - inform the user they need to contact admin
              setState(() {
                _isLoading = false;
                _errorMessage = "Unable to set password directly. Please contact your administrator.";
              });
            }
          }
        } else {
          setState(() {
            _isLoading = false;
            _errorMessage = "Missing authentication details. Please try again or contact your administrator.";
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
      const SnackBar(content: Text("Password set successfully! Please log in with your new password.")),
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
                onPressed: () => Navigator.of(context).pushReplacementNamed(LoginScreen.routeName),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.grey[800]),
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
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _errorMessage!,
                    style: TextStyle(color: Colors.orange.shade900, fontSize: 14),
                    textAlign: TextAlign.center,
                  ),
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
                  child: const Text("Set Password and Log In", style: TextStyle(fontSize: 16)),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed(LoginScreen.routeName),
                child: const Text("Cancel and go to login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}