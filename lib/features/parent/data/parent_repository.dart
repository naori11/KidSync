import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'parent_repository.g.dart';

class ParentRepository {
  final SupabaseClient _client;

  ParentRepository(this._client);

  Future<List<Map<String, dynamic>>> getStudentsForParent(String parentId) async {
    final response = await _client
        .from('parent_student')
        .select('''
          students!inner(
            id, fname, mname, lname, grade_level, section_id, profile_image_url,
            sections(name, grade_level)
          )
        ''')
        .eq('parent_id', parentId);

    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> getParentInfo(String userId) async {
    return await _client
        .from('parents')
        .select('id, fname, lname, phone, email, user_id')
        .eq('user_id', userId)
        .maybeSingle();
  }

  Future<void> logPickupDropoff({
    required int studentId,
    required String parentId,
    required String eventType,
    String? notes,
  }) async {
    await _client.from('pickup_dropoff_logs').insert({
      'student_id': studentId,
      'parent_id': parentId,
      'event_type': eventType,
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<List<Map<String, dynamic>>> getPickupDropoffLogs({
    required int studentId,
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    var query = _client
        .from('pickup_dropoff_logs')
        .select('*')
        .eq('student_id', studentId);

    if (startDate != null) {
      query = query.gte('created_at', startDate.toIso8601String());
    }
    if (endDate != null) {
      query = query.lt('created_at', endDate.toIso8601String());
    }

    final response = await query.order('created_at', ascending: false);
    return (response as List).cast<Map<String, dynamic>>();
  }

  User? get currentUser => _client.auth.currentUser;
}

@riverpod
ParentRepository parentRepository(Ref ref) {
  return ParentRepository(Supabase.instance.client);
}
