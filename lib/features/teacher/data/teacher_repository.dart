import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'teacher_repository.g.dart';

class TeacherRepository {
  final SupabaseClient _client;

  TeacherRepository(this._client);

  Future<List<Map<String, dynamic>>> getSectionsForTeacher(String teacherId) async {
    final response = await _client
        .from('sections')
        .select('id, name, grade_level, schedule')
        .eq('teacher_id', teacherId)
        .eq('is_testing', false);

    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> getTeacherInfo(String userId) async {
    return await _client
        .from('users')
        .select('id, fname, lname, email, profile_image_url')
        .eq('id', userId)
        .maybeSingle();
  }

  User? get currentUser => _client.auth.currentUser;
}

@riverpod
TeacherRepository teacherRepository(Ref ref) {
  return TeacherRepository(Supabase.instance.client);
}
