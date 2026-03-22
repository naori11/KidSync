import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../data/auth_repository.dart';
import 'login_screen.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'dart:html' as html;
import 'dart:convert';

class SetPasswordScreen extends ConsumerStatefulWidget {
  const SetPasswordScreen({super.key});
  static const String routeName = '/set-password';

  @override
  ConsumerState<SetPasswordScreen> createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends ConsumerState<SetPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = true;
  String? _errorMessage;
  String? _userEmail;
  String? _userId;
  bool _isAuthenticated = false;
  String? _accessToken;
  String? _refreshToken;
  String? _resetCode;
  String? _resetEmail;
  String? _previousUserEmail;
  String? _targetUserName;
  bool _isSubmitting = false;
  bool _showPassword = false;
  bool _showConfirmPassword = false;
  int _passwordScore = 0; // 0..4
  List<String> _passwordSuggestions = [];

  @override
  void initState() {
    super.initState();
    print("SetPasswordScreen: initState called");

    // Password reset flow
    if (kIsWeb &&
        html.window.sessionStorage.containsKey('kidsync_reset_code')) {
      _resetCode = html.window.sessionStorage['kidsync_reset_code'];
      _resetEmail = html.window.sessionStorage['kidsync_reset_email'];
      print(
        "SetPasswordScreen: Found reset code in session storage: $_resetCode",
      );
      // Log out any current user for security
      final currentUser = ref.read(authRepositoryProvider).currentUser;
      if (currentUser != null) {
        _previousUserEmail = currentUser.email;
        ref.read(authRepositoryProvider).signOut().then((_) {
          print("SetPasswordScreen: Logged out user $_previousUserEmail");
          setState(() {
            // don't set target user to the logged out account
            _isLoading = false;
          });
        });
      } else {
        setState(() => _isLoading = false);
      }
      return;
    }

    // Invite flow
    if (kIsWeb) {
      print("SetPasswordScreen: Checking for invite tokens");
      _processInviteToken();
      return;
    }

    // Authenticated user flow
    final currentUser = ref.read(authRepositoryProvider).currentUser;
    if (currentUser != null) {
      print("SetPasswordScreen: User authenticated: ${currentUser.email}");
      _isAuthenticated = true;
      _userEmail = currentUser.email;
      // Try to extract a friendly name from user metadata
      try {
        final meta = currentUser.userMetadata;
        if (meta != null) {
          _targetUserName =
              meta['full_name'] ??
              meta['name'] ??
              meta['displayName'] ??
              meta['display_name'];
        }
      } catch (_) {}
      _userId = currentUser.id;
      setState(() => _isLoading = false);
    } else {
      print("SetPasswordScreen: Not authenticated, redirecting to login");
      setState(() => _isLoading = false);
      _redirectToLogin();
    }
  }

  Future<void> _processInviteToken() async {
    try {
      _accessToken = html.window.sessionStorage['supabase_access_token'];
      _refreshToken = html.window.sessionStorage['supabase_refresh_token'];
      // If there's an access token, check if it's expired (JWT "exp" claim)
      if (_accessToken != null && _isJwtExpired(_accessToken!)) {
        // token expired — remove stored tokens and don't show this screen
        if (kIsWeb) {
          html.window.sessionStorage.remove('supabase_access_token');
          html.window.sessionStorage.remove('supabase_refresh_token');
        }
        setState(() {
          _isLoading = false;
          _errorMessage =
              "This invitation link has expired. Please request a new invite or contact your administrator.";
        });
        return;
      }
      if (_accessToken != null && _refreshToken != null) {
        print(
          "SetPasswordScreen: Found access and refresh tokens in sessionStorage",
        );
        _extractEmailAndUserIdFromToken(_accessToken);
        if (_userEmail != null) {
          print(
            "SetPasswordScreen: Successfully extracted email from token: $_userEmail",
          );
          setState(() => _isLoading = false);
          return;
        }
      }
      final url = html.window.location.href;
      print("SetPasswordScreen: Checking URL for token: $url");
      // If the URL contains an error param from the provider (e.g. token expired), treat as expired/used
      if (url.contains('error=') || url.contains('error_description=')) {
        final lower = url.toLowerCase();
        if (lower.contains('expired') ||
            lower.contains('otp_expired') ||
            lower.contains('token has expired')) {
          // clear any reset/session values and avoid showing this screen
          if (kIsWeb) {
            html.window.sessionStorage.remove('supabase_access_token');
            html.window.sessionStorage.remove('supabase_refresh_token');
            html.window.sessionStorage.remove('kidsync_reset_code');
            html.window.sessionStorage.remove('kidsync_reset_email');
          }
          setState(() {
            _isLoading = false;
            _errorMessage =
                "Link expired or already used. Please request a new link.";
          });
          return;
        }
      }
      if (url.contains('access_token=')) {
        _accessToken = url.split('access_token=')[1].split('&')[0];
        if (url.contains('refresh_token=')) {
          _refreshToken = url.split('refresh_token=')[1].split('&')[0];
        }
        print("SetPasswordScreen: Found tokens in URL");
        _extractEmailAndUserIdFromToken(_accessToken);
        if (_accessToken != null) {
          html.window.sessionStorage['supabase_access_token'] = _accessToken!;
        }
        if (_refreshToken != null) {
          html.window.sessionStorage['supabase_refresh_token'] = _refreshToken!;
        }
        if (_userEmail != null) {
          print(
            "SetPasswordScreen: Successfully extracted email from URL token: $_userEmail",
          );
          setState(() => _isLoading = false);
          return;
        }
      }
      setState(() {
        _isLoading = false;
        _errorMessage =
            "Could not process the invitation link. Please contact your administrator.";
      });
    } catch (e) {
      print("SetPasswordScreen: Error processing invite token: $e");
      final friendly = _formatError(e);
      setState(() {
        _isLoading = false;
        _errorMessage = 'Error processing invitation. $friendly';
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
        // Attempt to extract a friendly name if present in the token payload
        if (json is Map && json.containsKey('name')) {
          _targetUserName = json['name'];
        } else if (json is Map && json.containsKey('user_metadata')) {
          final meta = json['user_metadata'];
          if (meta is Map) {
            _targetUserName =
                meta['full_name'] ??
                meta['name'] ??
                meta['displayName'] ??
                meta['display_name'];
          }
        }
        _userId = json['sub'];
        print(
          "SetPasswordScreen: Extracted from token - Email: $_userEmail, User ID: $_userId",
        );
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

  Future<void> _onSetPassword() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    // Extra guard: ensure password strength is acceptable
    if (_passwordScore < 2) {
      _showError(
        'Please choose a stronger password before continuing. See suggestions below.',
      );
      return;
    }

    final newPasswordPreview = _passwordController.text;
    // Prevent trivial reuse of identifiable info
    if (_userEmail != null && newPasswordPreview.contains(_userEmail!)) {
      _showError('Your password should not contain your email address.');
      return;
    }
    if (_targetUserName != null) {
      final nameParts = _targetUserName!.split(RegExp(r"\s+"));
      for (final part in nameParts) {
        if (part.isNotEmpty &&
            newPasswordPreview.toLowerCase().contains(part.toLowerCase())) {
          _showError('Your password should not contain your name.');
          return;
        }
      }
    }

    final newPassword = _passwordController.text;

    // Prevent double submits when UI already shows the form
    if (_isSubmitting) return;

    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });

    try {
      // Password Reset Flow
      if (_resetCode != null) {
        print("SetPasswordScreen: Processing password reset with code");
        try {
          final response = await ref
              .read(authRepositoryProvider)
              .verifyOTP(
                token: _resetCode!,
                type: OtpType.recovery,
                email: _resetEmail,
              );

          print("Verify OTP response: $response");
          if (response.session != null && response.user != null) {
            _userEmail = response.user!.email;
            // try to get a friendly name from returned user metadata
            try {
              final meta = response.user!.userMetadata;
              if (meta != null) {
                _targetUserName =
                    meta['full_name'] ??
                    meta['name'] ??
                    meta['displayName'] ??
                    meta['display_name'];
              }
            } catch (_) {}
            print(
              "SetPasswordScreen: Successfully verified OTP for $_userEmail",
            );
            if (_userEmail != null) {
              await ref
                  .read(authRepositoryProvider)
                  .updateUser(UserAttributes(password: newPassword));
              if (kIsWeb) {
                html.window.sessionStorage.remove('kidsync_reset_code');
                html.window.sessionStorage.remove('kidsync_reset_email');
              }
              _passwordSetSuccess("Your password has been reset successfully!");
              return;
            } else {
              _showError("User email not found in OTP response.");
              return;
            }
          } else {
            _showError(
              "Failed to verify the recovery code. It may be expired or invalid.",
            );
            return;
          }
        } catch (e) {
          // If recovery verification fails (expired/used token), clear stored reset data and redirect
          if (kIsWeb) {
            _clearResetTokens();
          }
          final friendly = _formatError(e);
          // Show error then redirect to login so the user doesn't see this screen again
          _showError(friendly);
          // small delay so SnackBar is visible, then navigate away
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) {
              Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
            }
          });
          return;
        }
      }

      // Invite (access_token) Flow
      if (_userEmail != null && _accessToken != null && _refreshToken != null) {
        print("SetPasswordScreen: Setting password via token for $_userEmail");
        try {
          final response = await ref
              .read(authRepositoryProvider)
              .setSession(_refreshToken!);
          if (response.session != null) {
            final tokenUser = response.user;
            if (tokenUser?.email != _userEmail) {
              // Clear tokens to avoid repeated failures
              if (kIsWeb) {
                html.window.sessionStorage.remove('supabase_access_token');
                html.window.sessionStorage.remove('supabase_refresh_token');
              }
              _showError("Token email doesn't match expected user.");
              return;
            }
            await ref
                .read(authRepositoryProvider)
                .updateUser(UserAttributes(password: newPassword));
            _passwordSetSuccess("Your account has been set up successfully!");
            return;
          } else {
            _showError("Could not establish a session from the invite token.");
            return;
          }
        } catch (e) {
          // If token flow fails, clear stored tokens to avoid stale state
          if (kIsWeb) {
            html.window.sessionStorage.remove('supabase_access_token');
            html.window.sessionStorage.remove('supabase_refresh_token');
          }
          _showError(_formatError(e));
          return;
        }
      }

      // Authenticated user changing password
      if (_isAuthenticated && _userEmail != null) {
        try {
          print(
            "SetPasswordScreen: User is authenticated, directly updating password for $_userEmail",
          );
          await ref
              .read(authRepositoryProvider)
              .updateUser(UserAttributes(password: newPassword));
          _passwordSetSuccess("Your password has been updated successfully!");
          return;
        } catch (e) {
          _showError(_formatError(e));
          return;
        }
      }

      _showError(
        "Missing authentication details. Please try again or contact your administrator.",
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    print("SetPasswordScreen: $_errorMessage");
    setState(() {
      _isLoading = false;
      _errorMessage = message;
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red.shade700),
    );
  }

  String _formatError(Object? e) {
    final raw = e?.toString() ?? '';
    final lower = raw.toLowerCase();

    // Common OTP / token expiry
    if (lower.contains('otp_expired') ||
        (lower.contains('token') && lower.contains('expired')) ||
        lower.contains('expired')) {
      return 'This link has expired or is invalid. Please request a new password reset link.';
    }

    // Common auth/forbidden
    if (lower.contains('403') ||
        lower.contains('forbidden') ||
        lower.contains('not authorized')) {
      return 'Unable to use this link. It may have already been used or is not valid.';
    }

    // Password same as current
    if (lower.contains('same') && lower.contains('password') ||
        lower.contains('current password')) {
      return 'Your new password must be different from your current password.';
    }

    // Generic known messages
    if (lower.contains('invalid') ||
        lower.contains('invalid code') ||
        lower.contains('invalid token')) {
      return 'The code or link appears to be invalid. Please request a new link.';
    }

    // Fallback: avoid showing raw exception to users
    return 'An error occurred while processing your request. Please try again or contact support.';
  }

  void _clearResetTokens() {
    try {
      html.window.sessionStorage.remove('kidsync_reset_code');
      html.window.sessionStorage.remove('kidsync_reset_email');
      // clear in-progress flag as well
      html.window.sessionStorage.remove('kidsync_reset_in_progress');
    } catch (_) {}
  }

  void _passwordSetSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
    // After successfully setting the password, remove any invite/reset tokens so they are considered used
    if (kIsWeb) {
      html.window.sessionStorage.remove('supabase_access_token');
      html.window.sessionStorage.remove('supabase_refresh_token');
      html.window.sessionStorage.remove('kidsync_reset_code');
      html.window.sessionStorage.remove('kidsync_reset_email');
      try {
        html.window.sessionStorage.remove('kidsync_reset_in_progress');
      } catch (_) {}
    }
    // Make sure we sign out any temporary session established earlier
    try {
      ref.read(authRepositoryProvider).signOut();
    } catch (_) {}
    Navigator.of(context).pushReplacementNamed(LoginScreen.routeName);
  }

  bool _isJwtExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length < 2) return false;
      final payload = parts[1];
      final normalized = base64Url.normalize(payload);
      final decoded = utf8.decode(base64Url.decode(normalized));
      final json = jsonDecode(decoded);
      if (json.containsKey('exp')) {
        final exp = json['exp'];
        if (exp is int) {
          final expiry = DateTime.fromMillisecondsSinceEpoch(exp * 1000);
          return DateTime.now().isAfter(expiry);
        }
        if (exp is String) {
          final expInt = int.tryParse(exp);
          if (expInt != null) {
            final expiry = DateTime.fromMillisecondsSinceEpoch(expInt * 1000);
            return DateTime.now().isAfter(expiry);
          }
        }
      }
    } catch (e) {
      // if parsing fails, assume not expired (so we don't accidentally hide valid flows)
      print("_isJwtExpired: failed to parse token: $e");
    }
    return false;
  }

  void _onPasswordChanged(String pwd) {
    // Simple scoring rules (0..4)
    int score = 0;
    final suggestions = <String>[];
    if (pwd.length >= 8) {
      score++;
    } else {
      suggestions.add('Use at least 8 characters');
    }
    if (RegExp(r'[A-Z]').hasMatch(pwd) && RegExp(r'[a-z]').hasMatch(pwd)) {
      score++;
    } else {
      suggestions.add('Mix upper and lower case letters');
    }
    if (RegExp(r'\d').hasMatch(pwd)) {
      score++;
    } else {
      suggestions.add('Include numbers');
    }
    if (RegExp(r'[!@#\$%\^&\*\(\)_\+\-=`~\[\]{};:\\"\|,<.>/?]').hasMatch(pwd)) {
      score++;
    } else {
      suggestions.add('Add a symbol like !@#%');
    }

    // If password contains email or name parts, reduce score and add suggestion
    final low = pwd.toLowerCase();
    if (_userEmail != null &&
        _userEmail!.isNotEmpty &&
        low.contains(_userEmail!.toLowerCase())) {
      suggestions.add('Do not include your email address');
      score = (score - 1).clamp(0, 4);
    }
    if (_targetUserName != null && _targetUserName!.isNotEmpty) {
      for (final part in _targetUserName!.split(RegExp(r"\s+"))) {
        if (part.isNotEmpty && low.contains(part.toLowerCase())) {
          suggestions.add('Avoid using parts of your name');
          score = (score - 1).clamp(0, 4);
          break;
        }
      }
    }

    setState(() {
      _passwordScore = score;
      _passwordSuggestions = suggestions;
    });
  }

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    // ensure any in-progress flag is cleared if the screen is disposed
    try {
      if (kIsWeb)
        html.window.sessionStorage.remove('kidsync_reset_in_progress');
    } catch (_) {}
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Colors.green),
              ),
              SizedBox(height: 20),
              Text(
                "Processing...",
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null &&
        _accessToken == null &&
        _resetCode == null &&
        !_isAuthenticated) {
      return Scaffold(
        backgroundColor: Colors.grey[50],
        body: Center(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    "KidSync",
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.black87,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Icon(Icons.error_outline, color: Colors.red, size: 60),
                  const SizedBox(height: 20),
                  Text(
                    _errorMessage!,
                    style: const TextStyle(fontSize: 16),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          () => Navigator.of(
                            context,
                          ).pushReplacementNamed(LoginScreen.routeName),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                      child: const Text("Go to Login"),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      body: Center(
        child: SingleChildScrollView(
          child: Card(
            margin: const EdgeInsets.symmetric(horizontal: 24.0),
            elevation: 2,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "KidSync",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _resetCode != null
                          ? "Set your new password"
                          : (_accessToken != null
                              ? "Set your password to activate your account"
                              : "Update your password"),
                      style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                      textAlign: TextAlign.center,
                    ),
                    if (_userEmail != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        _userEmail!,
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ],
                    // Display the target user (the account for which the password will be set)
                    if (_userEmail != null) ...[
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.green[200],
                            child: Text(
                              _targetUserName != null &&
                                      _targetUserName!.isNotEmpty
                                  ? (_targetUserName!
                                          .split(' ')
                                          .map((s) => s.isNotEmpty ? s[0] : '')
                                          .take(2)
                                          .join())
                                      .toUpperCase()
                                  : (_userEmail != null
                                      ? _userEmail![0].toUpperCase()
                                      : '?'),
                              style: const TextStyle(color: Colors.white),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (_targetUserName != null) ...[
                                Text(
                                  _targetUserName!,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                              Text(
                                _userEmail!,
                                style: const TextStyle(fontSize: 13),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.red[50],
                          borderRadius: BorderRadius.circular(4),
                          border: Border.all(color: Colors.red.shade200),
                        ),
                        child: Text(
                          _errorMessage!,
                          style: TextStyle(
                            color: Colors.red.shade900,
                            fontSize: 14,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                    const SizedBox(height: 24),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "New Password",
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _passwordController,
                          onChanged: (v) => _onPasswordChanged(v),
                          decoration: InputDecoration(
                            hintText: "Enter your password",
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed:
                                  () => setState(
                                    () => _showPassword = !_showPassword,
                                  ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 16,
                            ),
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
                              borderSide: const BorderSide(color: Colors.green),
                            ),
                          ),
                          obscureText: !_showPassword,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return "Password cannot be empty";
                            }
                            if (value.length < 6) {
                              return "Password must be at least 6 characters";
                            }
                            if (_passwordScore < 2) {
                              return "Password is too weak. See suggestions below.";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 8),
                        // Strength meter
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            LinearProgressIndicator(
                              value: (_passwordScore / 4).clamp(0.0, 1.0),
                              color:
                                  _passwordScore >= 3
                                      ? Colors.green
                                      : (_passwordScore == 2
                                          ? Colors.orange
                                          : Colors.red),
                              backgroundColor: Colors.grey[200],
                              minHeight: 6,
                            ),
                            const SizedBox(height: 6),
                            Text(
                              _passwordScore >= 3
                                  ? 'Strong password'
                                  : (_passwordScore == 2
                                      ? 'Medium strength'
                                      : 'Weak password'),
                              style: TextStyle(
                                fontSize: 12,
                                color:
                                    _passwordScore >= 3
                                        ? Colors.green[700]
                                        : (_passwordScore == 2
                                            ? Colors.orange[700]
                                            : Colors.red[700]),
                              ),
                            ),
                            if (_passwordSuggestions.isNotEmpty) ...[
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 8,
                                runSpacing: 6,
                                children:
                                    _passwordSuggestions
                                        .map(
                                          (s) => Chip(
                                            label: Text(s),
                                            backgroundColor: Colors.grey[100],
                                          ),
                                        )
                                        .toList(),
                              ),
                            ],
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          "Confirm New Password",
                          style: TextStyle(fontSize: 14),
                        ),
                        const SizedBox(height: 8),
                        TextFormField(
                          controller: _confirmPasswordController,
                          onChanged: (v) => setState(() {}),
                          decoration: InputDecoration(
                            hintText: "Confirm your password",
                            suffixIcon: IconButton(
                              icon: Icon(
                                _showConfirmPassword
                                    ? Icons.visibility_off
                                    : Icons.visibility,
                              ),
                              onPressed:
                                  () => setState(
                                    () =>
                                        _showConfirmPassword =
                                            !_showConfirmPassword,
                                  ),
                            ),
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 15,
                              horizontal: 16,
                            ),
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
                              borderSide: const BorderSide(color: Colors.green),
                            ),
                          ),
                          obscureText: !_showConfirmPassword,
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
                      ],
                    ),
                    const SizedBox(height: 24),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _onSetPassword,
                        style: ElevatedButton.styleFrom(
                          backgroundColor:
                              _isSubmitting ? Colors.grey : Colors.green,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 15),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        child:
                            _isSubmitting
                                ? Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    Text(
                                      _resetCode != null
                                          ? "Resetting..."
                                          : (_accessToken != null
                                              ? "Creating..."
                                              : "Updating..."),
                                      style: const TextStyle(fontSize: 16),
                                    ),
                                  ],
                                )
                                : Text(
                                  _resetCode != null
                                      ? "Reset Password"
                                      : (_accessToken != null
                                          ? "Create Account"
                                          : "Update Password"),
                                  style: const TextStyle(fontSize: 16),
                                ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed:
                          _isSubmitting
                              ? null
                              : () => Navigator.of(
                                context,
                              ).pushReplacementNamed(LoginScreen.routeName),
                      style: TextButton.styleFrom(
                        foregroundColor:
                            _isSubmitting ? Colors.grey : Colors.green,
                      ),
                      child: const Text("Cancel and go to login"),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
