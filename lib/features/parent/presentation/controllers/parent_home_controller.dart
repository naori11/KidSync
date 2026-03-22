import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/parent_repository.dart';

part 'parent_home_controller.g.dart';

@riverpod
class ParentHomeController extends _$ParentHomeController {
  @override
  FutureOr<Map<String, dynamic>> build() async {
    final repository = ref.read(parentRepositoryProvider);
    final user = repository.currentUser;

    if (user == null) {
      return {'students': []};
    }

    final students = await repository.getStudentsForParent(user.id);

    return {
      'user_id': user.id,
      'students': students,
    };
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(parentRepositoryProvider);
      final user = repository.currentUser;

      if (user == null) {
        return {'students': []};
      }

      final students = await repository.getStudentsForParent(user.id);

      return {
        'user_id': user.id,
        'students': students,
      };
    });
  }
}
