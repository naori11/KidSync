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

  User? get currentUser => _client.auth.currentUser;
}

@riverpod
ParentRepository parentRepository(Ref ref) {
  return ParentRepository(Supabase.instance.client);
}
