import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class ParentLoginScreen extends StatefulWidget {
  const ParentLoginScreen({Key? key}) : super(key: key);

  @override
  State<ParentLoginScreen> createState() => _ParentLoginScreenState();
}

class _ParentLoginScreenState extends State<ParentLoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  bool _isLoading = false;
  String? _errorMessage;

  // Demo credentials
  final String demoEmail = 'parent@example.com';
  final String demoPassword = 'parent123';

  void _login() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final email = _emailController.text.trim();
    final password = _passwordController.text;

    try {
      final response =
          await Supabase.instance.client
              .from('mobileparents') // updated table name
              .select()
              .eq('email', email)
              .eq(
                'password',
                password,
              ) // For demo only! Use hashed passwords in production.
              .maybeSingle();

      if (response != null) {
        // Login success, navigate to parent dashboard
        Navigator.pushReplacementNamed(context, '/parent');
      } else {
        setState(() {
          _errorMessage = 'Invalid email or password';
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = 'Login failed: $e';
      });
    }

    setState(() {
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Parent Login')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextFormField(
                  controller: _emailController,
                  decoration: const InputDecoration(labelText: 'Email'),
                  keyboardType: TextInputType.emailAddress,
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Enter your email'
                              : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _passwordController,
                  decoration: const InputDecoration(labelText: 'Password'),
                  obscureText: true,
                  validator:
                      (value) =>
                          value == null || value.isEmpty
                              ? 'Enter your password'
                              : null,
                ),
                const SizedBox(height: 24),
                if (_errorMessage != null)
                  Text(
                    _errorMessage!,
                    style: const TextStyle(color: Colors.red),
                  ),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed:
                        _isLoading
                            ? null
                            : () {
                              if (_formKey.currentState!.validate()) {
                                _login();
                              }
                            },
                    child:
                        _isLoading
                            ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                            : const Text('Login'),
                  ),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Demo login:\nEmail: parent@example.com\nPassword: parent123',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
