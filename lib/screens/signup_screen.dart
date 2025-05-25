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
  // final _fullNameController = TextEditingController();
  final List<String> _roles = ['Parent', 'Guard', 'Teacher', 'Admin', 'Driver'];
  String? _selectedRole;
  final SupabaseClient supabase = Supabase.instance.client;

  bool _loading = false;

  Future<void> _signUp() async {
    setState(() => _loading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final fname = _fnameController.text.trim();
      final mname = _mnameController.text.trim();
      final lname = _lnameController.text.trim();
      // final fullName = _fullNameController.text.trim();
      final role = _selectedRole;

      if (role == null ||
          fname.isEmpty ||
          lname.isEmpty ||
          email.isEmpty ||
          password.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter all fields.")),
        );
        setState(() => _loading = false);
        return;
      }

      // 1. Sign up user with Supabase Auth
      final authResponse = await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'role': role, 'fname': fname, 'mname': mname, 'lname': lname},
      );

      final user = authResponse.user;
      if (user == null) {
        throw Exception('User not created. Please try again.');
      }

      // 2. Insert into your 'users' table
      await supabase.from('users').insert({
        'id': user.id,
        // 'full_name': fullName,
        'fname': fname,
        'mname': mname,
        'lname': lname,
        'email': email,
        'role': role,
        // Add more fields as needed (e.g., contact_number)
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
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              const SizedBox(height: 32),
              const Text(
                'KidSync',
                style: TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _emailController,
                decoration: const InputDecoration(labelText: 'Email'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _passwordController,
                obscureText: true,
                decoration: const InputDecoration(labelText: 'Password'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _fnameController,
                decoration: const InputDecoration(labelText: 'First Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _mnameController,
                decoration: const InputDecoration(labelText: 'Middle Name'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _lnameController,
                decoration: const InputDecoration(labelText: 'Last Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                hint: const Text('Select Role'),
                items:
                    _roles
                        .map(
                          (role) => DropdownMenuItem<String>(
                            value: role,
                            child: Text(role),
                          ),
                        )
                        .toList(),
                onChanged: (value) => setState(() => _selectedRole = value),
              ),
              const SizedBox(height: 20),
              ElevatedButton(
                onPressed: _loading ? null : _signUp,
                child:
                    _loading
                        ? const CircularProgressIndicator()
                        : const Text("Sign Up"),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("Already have an account? Login"),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
