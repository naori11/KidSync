import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _fnameController = TextEditingController();
  final _mnameController = TextEditingController();
  final _lnameController = TextEditingController();
  final SupabaseClient supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;

  Future<void> _signUp() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final fname = _fnameController.text.trim();
      final mname = _mnameController.text.trim();
      final lname = _lnameController.text.trim();

      // 1. Sign up user with Supabase Auth
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {
          'role': 'Parent',
          'fname': fname,
          'mname': mname,
          'lname': lname,
        },
      );

      final user = authResponse.user;
      if (user == null) {
        throw Exception('User not created. Please try again.');
      }

      // 2. Insert into your 'users' table
      await supabase.from('users').insert({
        'id': user.id,
        'fname': fname,
        'mname': mname,
        'lname': lname,
        'email': email,
        'role': 'Parent',
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Signup successful! Please verify your email."),
        ),
      );

      Navigator.pop(context); // Return to login screen
    } catch (e) {
      debugPrint("Signup exception: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Sign up failed: ${e.toString()}")),
      );
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(
        0xFFF0F2F4,
      ), // Light grayish background like login
      body: Center(
        child: Container(
          width: 450, // Slightly wider to accommodate more fields
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
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Logo or App name section
                  const Center(
                    child: Text(
                      'KidSync',
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
                      'Create your parent account',
                      style: TextStyle(fontSize: 14, color: Color(0xFF777777)),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Email field
                  const Text(
                    'Email Address',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF555555),
                    ),
                  ),
                  const SizedBox(height: 8),
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
                  const SizedBox(height: 16),

                  // Password field
                  const Text(
                    'Password',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF555555),
                    ),
                  ),
                  const SizedBox(height: 8),
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
                                ? 'Enter a password'
                                : value.length < 6
                                ? 'Password must be at least 6 characters'
                                : null,
                  ),
                  const SizedBox(height: 16),

                  // First Name field
                  const Text(
                    'First Name',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF555555),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _fnameController,
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
                                ? 'Enter your first name'
                                : null,
                  ),
                  const SizedBox(height: 16),

                  // Middle Name field
                  const Text(
                    'Middle Name',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF555555),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _mnameController,
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
                    // Middle name can be optional
                  ),
                  const SizedBox(height: 16),

                  // Last Name field
                  const Text(
                    'Last Name',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF555555),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextFormField(
                    controller: _lnameController,
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
                                ? 'Enter your last name'
                                : null,
                  ),
                  const SizedBox(height: 24),

                  // Sign Up button
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(
                          0xFF2ECC71,
                        ), // Green color from login design
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                        elevation: 0,
                      ),
                      onPressed: _loading ? null : _signUp,
                      child:
                          _loading
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : const Text(
                                "Sign Up",
                                style: TextStyle(
                                  fontSize: 16,
                                  color: Colors.white,
                                ),
                              ),
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Login link
                  Center(
                    child: TextButton(
                      onPressed: () => Navigator.pop(context),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF2ECC71),
                      ),
                      child: const Text(
                        "Already have an account? Login",
                        style: TextStyle(fontSize: 14),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
