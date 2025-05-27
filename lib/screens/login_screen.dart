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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB), // soft gray background
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.school, size: 72, color: Color(0xFF4A90E2)),
                const SizedBox(height: 20),
                const Text(
                  'Welcome to KidSync',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF333333),
                  ),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Login to continue',
                  style: TextStyle(fontSize: 16, color: Color(0xFF777777)),
                ),
                const SizedBox(height: 30),
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(
                    labelText: 'Email Address',
                    prefixIcon: Icon(Icons.email_outlined),
                    border: OutlineInputBorder(),
                  ),
                  validator:
                      (value) =>
                          value == null || !value.contains('@')
                              ? 'Enter a valid email'
                              : null,
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    prefixIcon: Icon(Icons.lock_outline),
                    border: OutlineInputBorder(),
                  ),
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Enter your password'
                              : null,
                ),
                const SizedBox(height: 30),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF4A90E2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: _handleLogin,
                    child: const Text(
                      "Login",
                      style: TextStyle(fontSize: 18, color: Colors.white),
                    ),
                  ),
                ),
                const SizedBox(height: 15),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const SignUpScreen()),
                    );
                  },
                  child: const Text(
                    "Don't have an account? Sign up",
                    style: TextStyle(color: Color(0xFF4A90E2), fontSize: 14),
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
