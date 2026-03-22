import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'models/driver_models.dart';

part 'driver_repository.g.dart';

class DriverRepository {
  final SupabaseClient _client;

  DriverRepository(this._client);

  Future<List<DriverAssignment>> getDriverAssignments(String driverId) async {
    final response = await _client
        .from('driver_assignments')
        .select('''
          *,
          students!driver_assignments_student_id_fkey (
            id,
            fname,
            mname,
            lname,
            grade_level,
            section_id,
            rfid_uid,
            profile_image_url,
            sections!students_section_id_fkey (
              id,
              name,
              grade_level
            )
          )
        ''')
        .eq('driver_id', driverId)
        .eq('status', 'active');

    return (response as List)
        .map((json) => DriverAssignment.fromJson(json))
        .toList();
  }

  Future<List<PickupDropoffLog>> getTodaysLogs(String driverId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final response = await _client
        .from('pickup_dropoff_logs')
        .select('''
          *,
          students!pickup_dropoff_logs_student_id_fkey (
            id,
            fname,
            mname,
            lname,
            grade_level
          )
        ''')
        .eq('driver_id', driverId)
        .gte('created_at', startOfDay.toIso8601String())
        .lt('created_at', endOfDay.toIso8601String())
        .order('created_at', ascending: false);

    return (response as List)
        .map((json) => PickupDropoffLog.fromJson(json))
        .toList();
  }

  Future<Map<String, dynamic>?> getDriverInfo(String driverId) async {
    return await _client
        .from('users')
        .select('fname, lname, phone, profile_image_url')
        .eq('id', driverId)
        .maybeSingle();
  }

  Future<bool> wasStudentPickedUpToday(int studentId, String driverId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final pickupResponse = await _client
        .from('pickup_dropoff_logs')
        .select('id, created_at')
        .eq('student_id', studentId)
        .eq('driver_id', driverId)
        .eq('event_type', 'pickup')
        .gte('created_at', startOfDay.toIso8601String())
        .lt('created_at', endOfDay.toIso8601String())
        .order('created_at', ascending: false)
        .limit(1);

    if (pickupResponse.isEmpty) return false;

    final pickupTime = pickupResponse.first['created_at'];
    final cancellationResponse = await _client
        .from('pickup_dropoff_logs')
        .select('id')
        .eq('student_id', studentId)
        .eq('driver_id', driverId)
        .eq('event_type', 'pickup_cancelled')
        .gte('created_at', pickupTime)
        .lt('created_at', endOfDay.toIso8601String())
        .limit(1);

    return cancellationResponse.isEmpty;
  }

  Future<bool> wasStudentDroppedOffToday(int studentId, String driverId) async {
    final today = DateTime.now();
    final startOfDay = DateTime(today.year, today.month, today.day);
    final endOfDay = startOfDay.add(const Duration(days: 1));

    final dropoffResponse = await _client
        .from('pickup_dropoff_logs')
        .select('id, created_at')
        .eq('student_id', studentId)
        .eq('driver_id', driverId)
        .eq('event_type', 'dropoff')
        .gte('created_at', startOfDay.toIso8601String())
        .lt('created_at', endOfDay.toIso8601String())
        .order('created_at', ascending: false)
        .limit(1);

    if (dropoffResponse.isEmpty) return false;

    final dropoffTime = dropoffResponse.first['created_at'];
    final cancellationResponse = await _client
        .from('pickup_dropoff_logs')
        .select('id')
        .eq('student_id', studentId)
        .eq('driver_id', driverId)
        .eq('event_type', 'dropoff_cancelled')
        .gte('created_at', dropoffTime)
        .lt('created_at', endOfDay.toIso8601String())
        .limit(1);

    return cancellationResponse.isEmpty;
  }

  Future<void> logPickupDropoff({
    required int studentId,
    required String driverId,
    required String eventType,
    String? notes,
  }) async {
    await _client.from('pickup_dropoff_logs').insert({
      'student_id': studentId,
      'driver_id': driverId,
      'event_type': eventType,
      'notes': notes,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<void> sendNotification({
    required String recipientId,
    required String title,
    required String message,
    String? type,
  }) async {
    await _client.from('notifications').insert({
      'recipient_id': recipientId,
      'title': title,
      'message': message,
      'type': type,
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  Future<Map<String, dynamic>?> getStudentDetails(int studentId) async {
    return await _client
        .from('students')
        .select('*, sections(*)')
        .eq('id', studentId)
        .maybeSingle();
  }

  Future<List<Map<String, dynamic>>> getParentsForStudent(int studentId) async {
    final response = await _client
        .from('parent_student')
        .select('parents!inner(*, users!inner(*))')
        .eq('student_id', studentId);
    return (response as List).cast<Map<String, dynamic>>();
  }

  User? get currentUser => _client.auth.currentUser;
}

@riverpod
DriverRepository driverRepository(Ref ref) {
  return DriverRepository(Supabase.instance.client);
}
