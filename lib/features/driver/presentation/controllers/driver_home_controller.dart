import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/driver_repository.dart';

part 'driver_home_controller.g.dart';

@riverpod
class DriverHomeController extends _$DriverHomeController {
  @override
  FutureOr<Map<String, dynamic>> build() async {
    final repository = ref.read(driverRepositoryProvider);
    final user = repository.currentUser;

    if (user == null) {
      return {};
    }

    final driverInfo = await repository.getDriverInfo(user.id);

    return {
      'user_id': user.id,
      'driver_info': driverInfo,
    };
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(driverRepositoryProvider);
      final user = repository.currentUser;

      if (user == null) {
        return {};
      }

      final driverInfo = await repository.getDriverInfo(user.id);

      return {
        'user_id': user.id,
        'driver_info': driverInfo,
      };
    });
  }
}
