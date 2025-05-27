import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  static const String routeName = '/login';

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  void _handleLogin() async {
    if (_formKey.currentState!.validate()) {
      try {
        final response = await supabase.auth.signInWithPassword(
          email: _emailController.text.trim(),
          password: _passwordController.text.trim(),
        );

        final user = response.user;
        if (user == null) {
          throw Exception("User not found");
        }

        final role = user.userMetadata?['role'];

        if (role == null) {
          throw Exception("User role not found in metadata");
        }

        switch (role) {
          case 'Admin':
            Navigator.pushReplacementNamed(context, '/admin');
            break;
          case 'Parent':
            Navigator.pushReplacementNamed(context, '/parent');
            break;
          case 'Teacher':
            Navigator.pushReplacementNamed(context, '/teacher');
            break;
          case 'Guard':
            Navigator.pushReplacementNamed(context, '/guard');
            break;
          case 'Driver':
            Navigator.pushReplacementNamed(context, '/driver');
            break;
          default:
            throw Exception("Unknown role: $role");
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Login failed: ${e.toString()}")),
        );
      }
    }
  }

  void _showForgotPasswordModal() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
          backgroundColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              shape: BoxShape.rectangle,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 10.0,
                  offset: const Offset(0.0, 10.0),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.lock_reset,
                  size: 64,
                  color: Color(0xFF2ECC71), // Changed to green to match design
                ),
                const SizedBox(height: 20),
                const Text(
                  'Forgot Password',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 15),
                const Text(
                  'Contact the System Administrator for Password Reset',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Color(0xFF777777)),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF2ECC71,
                      ), // Green color from design
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text(
                      'OK',
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF0F2F4,
      ), // Light grayish background like in the image
      body: Center(
        child: Container(
          width: 400, // Width of the white card
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                spreadRadius: 1,
                blurRadius: 10,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Logo or App name section
                const Center(
                  child: Text(
                    'KidSync', // Replacing "Logo" from image with your app name
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.bold,
                      color: Color(0xFF333333),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Instructions text
                const Center(
                  child: Text(
                    'Enter your email ID and password to login',
                    style: TextStyle(fontSize: 14, color: Color(0xFF777777)),
                  ),
                ),
                const SizedBox(height: 24),
                // Username/Email field label
                const Text(
                  'Username',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF555555),
                  ),
                ),
                const SizedBox(height: 8),
                // Email textfield
                TextFormField(
                  controller: _emailController,
                  decoration: InputDecoration(
                    hintText: '--',
                    hintStyle: TextStyle(color: Colors.grey[300]),
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
                      borderSide: const BorderSide(color: Color(0xFF2ECC71)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                  validator:
                      (value) =>
                          value == null || !value.contains('@')
                              ? 'Enter a valid email'
                              : null,
                ),
                const SizedBox(height: 20),
                // Password field label
                const Text(
                  'Password',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: Color(0xFF555555),
                  ),
                ),
                const SizedBox(height: 8),
                // Password textfield
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: InputDecoration(
                    hintText: '--',
                    hintStyle: TextStyle(color: Colors.grey[300]),
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
                      borderSide: const BorderSide(color: Color(0xFF2ECC71)),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 16,
                    ),
                  ),
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Enter your password'
                              : null,
                ),
                const SizedBox(height: 24),
                // Login button
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(
                        0xFF2ECC71,
                      ), // Green color from design
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _handleLogin,
                    child: const Text(
                      "Sign In",
                      style: TextStyle(fontSize: 16, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Forgot password link
                Center(
                  child: TextButton(
                    onPressed: _showForgotPasswordModal,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2ECC71),
                    ),
                    child: const Text(
                      "Forgot Password? Get Help",
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                // Sign up option (kept from original functionality)
                Center(
                  child: TextButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const SignUpScreen()),
                      );
                    },
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF2ECC71),
                    ),
                    child: const Text(
                      "Are you a parent? Sign Up",
                      style: TextStyle(fontSize: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
