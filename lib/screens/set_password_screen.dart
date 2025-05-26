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
    
    // Check if this is an invite link via URL
    bool isInviteFlow = false;
    if (kIsWeb) {
      final currentUrl = html.window.location.href;
      isInviteFlow = currentUrl.contains('access_token=') || 
                      currentUrl.contains('type=invite');
      
      print("SetPasswordScreen: URL check - $currentUrl");
      print("SetPasswordScreen: Is invite flow - $isInviteFlow");
    }
    
    // If it's an invite link, try to process the token before checking for a user
    if (isInviteFlow) {
      setState(() => _isLoading = true);
      
      print("SetPasswordScreen: Processing invite flow, waiting for token processing...");
      
      // Wait a moment to allow Supabase client to process the token
      Future.delayed(const Duration(seconds: 2), () async {
        // Check if the user is logged in after waiting
        final currentUser = Supabase.instance.client.auth.currentUser;
        
        if (currentUser != null) {
          print("SetPasswordScreen: User ${currentUser.email} is now active after token processing.");
          if (mounted) setState(() => _isLoading = false);
        } else {
          print("SetPasswordScreen: No user after token processing, attempting manual authentication...");
          
          // Try to manually authenticate using the token from the URL
          try {
            await _processInviteToken();
          } catch (e) {
            print("SetPasswordScreen: Error processing invite token: $e");
            if (mounted) {
              setState(() {
                _isLoading = false;
                _errorMessage = "Failed to process invitation link. Please contact administrator.";
              });
            }
          }
        }
      });
    } else {
      // For regular access (not via invite link), check for logged in user
      final currentUser = Supabase.instance.client.auth.currentUser;
      if (currentUser == null) {
        // It's important to schedule navigation after the build phase.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            print("SetPasswordScreen: No active user and not an invite flow. Redirecting to login.");
            Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
          }
        });
      } else {
        print("SetPasswordScreen: User ${currentUser.email} is setting password.");
      }
    }
  }

  // Function to process the invite token from URL
  Future<void> _processInviteToken() async {
    if (!kIsWeb) return;
    
    final currentUrl = html.window.location.href;
    
    // Handle both URL formats to extract the token
    String? accessToken;
    
    if (currentUrl.contains('#/set-password#access_token=')) {
      // Handle double hash format
      final tokenPart = currentUrl.split('#access_token=')[1];
      accessToken = tokenPart.split('&')[0];
    } else if (currentUrl.contains('access_token=')) {
      // Handle normal format
      final tokenPart = currentUrl.split('access_token=')[1];
      accessToken = tokenPart.split('&')[0];
    }
    
    if (accessToken != null) {
      try {
        print("SetPasswordScreen: Attempting to set session with extracted token");
        final response = await Supabase.instance.client.auth.setSession(accessToken);
        
        if (response.session != null) {
          print("SetPasswordScreen: Successfully set session with token");
          if (mounted) setState(() => _isLoading = false);
        } else {
          print("SetPasswordScreen: Failed to set session with token");
          if (mounted) {
            setState(() {
              _isLoading = false;
              _errorMessage = "Failed to process invitation. Please try again or contact administrator.";
            });
            
            // Only redirect to login after a delay so the user can see the error
            Future.delayed(const Duration(seconds: 3), () {
              if (mounted) Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
            });
          }
        }
      } catch (e) {
        print("SetPasswordScreen: Error setting session: $e");
        if (mounted) {
          setState(() {
            _isLoading = false;
            _errorMessage = "Error processing invitation: ${e.toString()}";
          });
          
          // Only redirect to login after a delay so the user can see the error
          Future.delayed(const Duration(seconds: 3), () {
            if (mounted) Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
          });
        }
      }
    } else {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _errorMessage = "No valid token found in invitation link";
        });
        
        // Only redirect to login after a delay so the user can see the error
        Future.delayed(const Duration(seconds: 3), () {
          if (mounted) Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
        });
      }
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
          const SnackBar(content: Text("Password set successfully! Please log in.")),
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
                onPressed: () => Navigator.of(context).pushReplacementNamed(LoginScreen.routeName),
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
                  child: const Text("Set Password and Log In", style: TextStyle(fontSize: 16)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}