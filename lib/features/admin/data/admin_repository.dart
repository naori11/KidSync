import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'admin_repository.g.dart';

class AdminRepository {
  final SupabaseClient _client;

  AdminRepository(this._client);

  Future<List<Map<String, dynamic>>> getAllUsers() async {
    final response = await _client
        .from('users')
        .select('id, fname, lname, email, role, status, created_at')
        .order('created_at', ascending: false);

    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<List<Map<String, dynamic>>> getAllStudents() async {
    final response = await _client
        .from('students')
        .select('''
          id, fname, mname, lname, grade_level, section_id, status,
          sections(name, grade_level)
        ''')
        .order('fname', ascending: true);

    return (response as List).cast<Map<String, dynamic>>();
  }

  Future<Map<String, dynamic>?> getAdminInfo(String userId) async {
    return await _client
        .from('users')
        .select('id, fname, lname, email, profile_image_url')
        .eq('id', userId)
        .maybeSingle();
  }

  User? get currentUser => _client.auth.currentUser;
}

@riverpod
AdminRepository adminRepository(Ref ref) {
  return AdminRepository(Supabase.instance.client);
}
