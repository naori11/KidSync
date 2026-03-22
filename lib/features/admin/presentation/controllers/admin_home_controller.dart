import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/admin_repository.dart';

part 'admin_home_controller.g.dart';

@riverpod
class AdminHomeController extends _$AdminHomeController {
  @override
  FutureOr<Map<String, dynamic>> build() async {
    final repository = ref.read(adminRepositoryProvider);
    final user = repository.currentUser;

    if (user == null) {
      return {};
    }

    final adminInfo = await repository.getAdminInfo(user.id);

    return {
      'user_id': user.id,
      'admin_info': adminInfo,
    };
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(adminRepositoryProvider);
      final user = repository.currentUser;

      if (user == null) {
        return {};
      }

      final adminInfo = await repository.getAdminInfo(user.id);

      return {
        'user_id': user.id,
        'admin_info': adminInfo,
      };
    });
  }
}
