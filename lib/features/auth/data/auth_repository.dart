import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auth_repository.g.dart';

class AuthRepository {
  final SupabaseClient _client;

  AuthRepository(this._client);

  Future<AuthResponse> signIn(String email, String password) async {
    return await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<void> signOut() async {
    await _client.auth.signOut();
  }

  Future<AuthResponse> verifyOTP({
    required String token,
    required OtpType type,
    String? email,
  }) async {
    return await _client.auth.verifyOTP(token: token, type: type, email: email);
  }

  Future<UserResponse> updateUser(UserAttributes attributes) async {
    return await _client.auth.updateUser(attributes);
  }

  Future<AuthResponse> setSession(String refreshToken) async {
    return await _client.auth.setSession(refreshToken);
  }

  User? get currentUser => _client.auth.currentUser;
}

@riverpod
AuthRepository authRepository(Ref ref) {
  return AuthRepository(Supabase.instance.client);
}
