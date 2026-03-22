import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/guard_repository.dart';

part 'guard_dashboard_controller.g.dart';

@riverpod
class GuardDashboardController extends _$GuardDashboardController {
  @override
  FutureOr<Map<String, dynamic>> build() async {
    final repository = ref.read(guardRepositoryProvider);
    final user = repository.currentUser;

    if (user?.id == null) {
      return {
        'guardId': null,
        'guardName': 'Guard',
        'profileImageUrl': null,
      };
    }

    final guardData = await repository.fetchGuardData(user!.id);

    return {
      'guardId': user.id,
      'guardName': guardData != null
          ? '${guardData['fname'] ?? ''} ${guardData['lname'] ?? ''}'.trim()
          : user.email ?? 'Guard',
      'profileImageUrl': guardData?['profile_image_url'],
    };
  }
}
