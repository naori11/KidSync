import 'package:riverpod_annotation/riverpod_annotation.dart';
import '../../data/teacher_repository.dart';

part 'teacher_home_controller.g.dart';

@riverpod
class TeacherHomeController extends _$TeacherHomeController {
  @override
  FutureOr<Map<String, dynamic>> build() async {
    final repository = ref.read(teacherRepositoryProvider);
    final user = repository.currentUser;

    if (user == null) {
      return {'sections': []};
    }

    final sections = await repository.getSectionsForTeacher(user.id);

    return {
      'user_id': user.id,
      'sections': sections,
    };
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(teacherRepositoryProvider);
      final user = repository.currentUser;

      if (user == null) {
        return {'sections': []};
      }

      final sections = await repository.getSectionsForTeacher(user.id);

      return {
        'user_id': user.id,
        'sections': sections,
      };
    });
  }
}
