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
  final _fullNameController = TextEditingController();
  final List<String> _roles = ['Parent', 'Guard', 'Teacher', 'Admin', 'Driver'];
  String? _selectedRole;
  final SupabaseClient supabase = Supabase.instance.client;

  bool _loading = false;

  Future<void> _signUp() async {
    setState(() => _loading = true);

    try {
      final email = _emailController.text.trim();
      final password = _passwordController.text;
      final fullName = _fullNameController.text.trim();

      if (_selectedRole == null || fullName.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Please enter all fields.")),
        );
        return;
      }

      await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'role': _selectedRole, 'full_name': fullName},
      );

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
                controller: _fullNameController,
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                hint: const Text('Select Role'),
                items:
                    _roles.map((role) {
                      return DropdownMenuItem<String>(
                        value: role,
                        child: Text(role),
                      );
                    }).toList(),
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
