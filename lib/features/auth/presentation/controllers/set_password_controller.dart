import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../data/auth_repository.dart';

part 'set_password_controller.g.dart';

@riverpod
class SetPasswordController extends _$SetPasswordController {
  @override
  FutureOr<void> build() {}

  Future<void> verifyOTPAndSetPassword({
    required String email,
    required String token,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);

      // Verify OTP
      await repository.verifyOTP(
        token: token,
        type: OtpType.recovery,
        email: email,
      );

      // Update password
      await repository.updateUser(UserAttributes(password: password));
    });
  }

  Future<void> setSessionAndPassword({
    required String accessToken,
    required String refreshToken,
    required String password,
  }) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);

      // Set session - Supabase's setSession typically just needs the refresh token or both.
      // Our repository currently only takes refreshToken.
      await repository.setSession(refreshToken);

      // Update password
      await repository.updateUser(UserAttributes(password: password));
    });
  }

  Future<void> updatePassword(String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(authRepositoryProvider);
      await repository.updateUser(UserAttributes(password: password));
    });
  }
}
