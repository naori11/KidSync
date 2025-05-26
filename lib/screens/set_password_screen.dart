import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'login_screen.dart'; 

class SetPasswordScreen extends StatefulWidget {
  const SetPasswordScreen({super.key});

  // Define a route name for easy navigation
  static const String routeName = '/set-password';

  @override
  State<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

// In your set_password_screen.dart

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  // Add other necessary controllers and state variables

  @override
  void initState() {
    super.initState();
    // Crucial check: Ensure a user is logged in.
    final currentUser = Supabase.instance.client.auth.currentUser;
    if (currentUser == null) {
      // It's important to schedule navigation after the build phase.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) { // Check if the widget is still in the tree
          print("SetPasswordScreen: No active user. Redirecting to login.");
          Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
        }
      });
    } else {
      // Optional: You could prefill the email if your design requires it,
      // though for a set password screen, it's often not shown or is read-only.
      // For example: _emailController.text = currentUser.email ?? '';
      print("SetPasswordScreen: User ${currentUser.email} is setting password.");
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
      final newPassword = _passwordController.text;
      // Show loading indicator
      // ...

      try {
        await Supabase.instance.client.auth.updateUser(
          UserAttributes(password: newPassword),
        );

        if (!mounted) return;
        // Hide loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password set successfully! Please log in.")),
        );
        // Navigate to login screen after successful password set
        Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);

      } on AuthException catch (error) {
        if (!mounted) return;
        // Hide loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error setting password: ${error.message}")),
        );
      } catch (error) {
        if (!mounted) return;
        // Hide loading indicator
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("An unexpected error occurred: ${error.toString()}")),
        );
      }
    }
  }

  // ... rest of your SetPasswordScreen UI (build method with Form, TextFormFields, Button to call _onSetPassword)
  // Example for the build method structure:
  @override
  Widget build(BuildContext context) {
    // If currentUser was null in initState, we might be in the process of redirecting.
    // You could show a loading indicator or an empty container until redirection happens.
    if (Supabase.instance.client.auth.currentUser == null && mounted) { // Re-check, though initState should handle it
       // This check in build is a secondary safety, initState is primary.
       // If redirection is already posted, this build might run once.
       return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Set Your Password")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextFormField(
                controller: _passwordController,
                decoration: const InputDecoration(labelText: "New Password"),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return "Password cannot be empty";
                  }
                  if (value.length < 6) { // Example: Supabase default min length
                    return "Password must be at least 6 characters";
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: const InputDecoration(labelText: "Confirm New Password"),
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
              ElevatedButton(
                onPressed: _onSetPassword,
                child: const Text("Set Password and Log In"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}