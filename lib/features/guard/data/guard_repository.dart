import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'models/guard_models.dart';

part 'guard_repository.g.dart';

class GuardRepository {
  final SupabaseClient _client;

  GuardRepository(this._client);

  Future<List<Activity>> fetchRecentActivities({
    required DateTime start,
    required DateTime end,
    int limit = 50,
  }) async {
    final response = await _client
        .from('scan_records')
        .select('''
        scan_time, action, verified_by, status, notes,
        students(id, fname, mname, lname, grade_level, section_id)
      ''')
        .gte('scan_time', start.toIso8601String())
        .lt('scan_time', end.toIso8601String())
        .order('scan_time', ascending: false)
        .limit(limit);

    return (response as List).map((record) => Activity.fromJson(record)).toList();
  }

  Future<Map<String, dynamic>?> fetchGuardData(String guardId) async {
    return await _client
        .from('users')
        .select('fname, lname, profile_image_url')
        .eq('id', guardId)
        .maybeSingle();
  }

  Future<bool> checkIfStudentAlreadyEntered(int studentId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(Duration(days: 1));

    final response = await _client
        .from('scan_records')
        .select('action, scan_time')
        .eq('student_id', studentId)
        .gte('scan_time', startOfDay.toIso8601String())
        .lt('scan_time', endOfDay.toIso8601String())
        .order('scan_time', ascending: true);

    if (response.isEmpty) {
      return false;
    }

    final records = response as List;
    final latestRecord = records.last;
    final latestAction = latestRecord['action'];

    return latestAction == 'entry';
  }

  Future<String> checkTodayAttendanceStatus(int studentId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(Duration(days: 1));

    final response = await _client
        .from('scan_records')
        .select('action, scan_time')
        .eq('student_id', studentId)
        .gte('scan_time', startOfDay.toIso8601String())
        .lt('scan_time', endOfDay.toIso8601String())
        .order('scan_time', ascending: true);

    if (response.isEmpty) {
      return 'entry';
    }

    final records = response as List;
    final latestRecord = records.last;
    final latestAction = latestRecord['action'];

    if (latestAction == 'entry') {
      return 'exit';
    } else if (latestAction == 'exit') {
      return 'entry';
    } else {
      return 'exit';
    }
  }

  User? get currentUser => _client.auth.currentUser;
}

@riverpod
GuardRepository guardRepository(Ref ref) {
  return GuardRepository(Supabase.instance.client);
}
