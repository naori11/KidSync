import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/driver_repository.dart';
import '../../data/models/driver_models.dart';

part 'driver_assignments_controller.g.dart';

@riverpod
class DriverAssignmentsController extends _$DriverAssignmentsController {
  @override
  FutureOr<List<DriverAssignment>> build() async {
    final repository = ref.read(driverRepositoryProvider);
    final user = repository.currentUser;

    if (user == null) return [];

    return await repository.getDriverAssignments(user.id);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(driverRepositoryProvider);
      final user = repository.currentUser;

      if (user == null) return [];

      return await repository.getDriverAssignments(user.id);
    });
  }
}
