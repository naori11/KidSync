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

  Future<List<Map<String, dynamic>>> getStudentsInSection(int sectionId) async {
    final response = await _client
        .from('students')
        .select('*')
        .eq('section_id', sectionId)
        .order('lname', ascending: true);
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getSectionAttendance({
    required int sectionId,
    required DateTime date,
  }) async {
    final startOfDay = DateTime(date.year, date.month, date.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final response = await _client
        .from('section_attendance')
        .select('*')
        .eq('section_id', sectionId)
        .gte('attendance_date', startOfDay.toIso8601String())
        .lt('attendance_date', endOfDay.toIso8601String());
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<void> markAttendance({
    required int studentId,
    required int sectionId,
    required DateTime date,
    required String status,
    String? notes,
  }) async {
    await _client.from('section_attendance').upsert({
      'student_id': studentId,
      'section_id': sectionId,
      'attendance_date': date.toIso8601String(),
      'status': status,
      'notes': notes,
      'marked_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getEarlyDismissals(int sectionId) async {
    final response = await _client
        .from('early_dismissals')
        .select('*, early_dismissal_students(*)')
        .eq('section_id', sectionId);
    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<void> addEarlyDismissalStudent({
    required int dismissalId,
    required int studentId,
  }) async {
    await _client.from('early_dismissal_students').insert({
      'early_dismissal_id': dismissalId,
      'student_id': studentId,
    });
  }

  User? get currentUser => _client.auth.currentUser;
}

@riverpod
TeacherRepository teacherRepository(Ref ref) {
  return TeacherRepository(Supabase.instance.client);
}
