import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/driver_repository.dart';
import '../../data/models/driver_models.dart';

part 'driver_dashboard_controller.g.dart';

@riverpod
class DriverDashboardController extends _$DriverDashboardController {
  @override
  FutureOr<Map<String, dynamic>> build() async {
    final repository = ref.read(driverRepositoryProvider);
    final user = repository.currentUser;

    if (user == null) {
      return {
        'assignments': <DriverAssignment>[],
        'todays_logs': <PickupDropoffLog>[],
      };
    }

    final assignments = await repository.getDriverAssignments(user.id);
    final todaysLogs = await repository.getTodaysLogs(user.id);

    return {
      'assignments': assignments,
      'todays_logs': todaysLogs,
    };
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(driverRepositoryProvider);
      final user = repository.currentUser;

      if (user == null) {
        return {
          'assignments': <DriverAssignment>[],
          'todays_logs': <PickupDropoffLog>[],
        };
      }

      final assignments = await repository.getDriverAssignments(user.id);
      final todaysLogs = await repository.getTodaysLogs(user.id);

      return {
        'assignments': assignments,
        'todays_logs': todaysLogs,
      };
    });
  }
}
