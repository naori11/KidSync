import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/pickup_dropoff_models.dart';

class PickupDropoffService {
  final supabase = Supabase.instance.client;

  Future<StudentSchedule?> getStudentSchedule(int studentId) async {
    try {
      // First, get the student's section
      final studentResponse =
          await supabase
              .from('students')
              .select('section_id')
              .eq('id', studentId)
              .maybeSingle();

      if (studentResponse == null || studentResponse['section_id'] == null) {
        return null;
      }

      final sectionId = studentResponse['section_id'];

      // Get the schedule from section_teachers table
      final scheduleResponse =
          await supabase
              .from('section_teachers')
              .select('days, start_time, end_time')
              .eq('section_id', sectionId)
              .limit(1)
              .maybeSingle();

      if (scheduleResponse == null) {
        return null;
      }

      // Parse the days array and times
      final days = List<String>.from(scheduleResponse['days'] ?? []);
      final startTime = scheduleResponse['start_time'] ?? '';
      final endTime = scheduleResponse['end_time'] ?? '';

      // Convert day names to day numbers
      final classDays = <int>[];
      final classSchedule = <int, TimeRange>{};

      for (String day in days) {
        int dayNum = _dayNameToNumber(day.trim());
        if (dayNum > 0) {
          classDays.add(dayNum);
          classSchedule[dayNum] = TimeRange(
            startTime: startTime,
            endTime: endTime,
          );
        }
      }

      return StudentSchedule(
        studentId: studentId,
        classDays: classDays,
        classSchedule: classSchedule,
      );
    } catch (e) {
      return null;
    }
  }

  // Helper method to convert day names to numbers - handles both full and abbreviated names
  int _dayNameToNumber(String dayName) {
    final cleanDay = dayName.toLowerCase().trim();

    // Handle both abbreviated and full day names
    const dayMap = {
      // Full names
      'monday': 1,
      'tuesday': 2,
      'wednesday': 3,
      'thursday': 4,
      'friday': 5,
      'saturday': 6,
      'sunday': 7,
      // Abbreviated names
      'mon': 1,
      'tue': 2,
      'wed': 3,
      'thu': 4,
      'fri': 5,
      'sat': 6,
      'sun': 7,
    };

    return dayMap[cleanDay] ?? 0;
  }

  // Rest of your existing methods...
  Future<List<PickupDropoffPattern>> getPatterns(int studentId) async {
    try {
      final response = await supabase
          .from('pickup_dropoff_patterns')
          .select('*')
          .eq('student_id', studentId);

      return response
          .map<PickupDropoffPattern>(
            (json) => PickupDropoffPattern.fromJson(json),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<List<PickupDropoffException>> getExceptions(int studentId) async {
    try {
      final response = await supabase
          .from('pickup_dropoff_exceptions')
          .select('*')
          .eq('student_id', studentId);

      return response
          .map<PickupDropoffException>(
            (json) => PickupDropoffException.fromJson(json),
          )
          .toList();
    } catch (e) {
      return [];
    }
  }

  Future<bool> saveWeeklyPattern(
    int studentId,
    Map<String, Map<String, String>> pattern,
  ) async {
    try {
      // Delete existing patterns
      await supabase
          .from('pickup_dropoff_patterns')
          .delete()
          .eq('student_id', studentId);

      // Insert new patterns
      for (var entry in pattern.entries) {
        int dayNum = _dayNameToNumber(entry.key);
        if (dayNum > 0) {
          await supabase.from('pickup_dropoff_patterns').insert({
            'student_id': studentId,
            'day_of_week': dayNum,
            'dropoff_person': entry.value['dropoff'],
            'pickup_person': entry.value['pickup'],
          });
        }
      }
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> saveException(
    int studentId,
    DateTime date,
    Map<String, String> schedule,
  ) async {
    try {
      await supabase.from('pickup_dropoff_exceptions').insert({
        'student_id': studentId,
        'exception_date': date.toIso8601String(),
        'dropoff_person': schedule['dropoff'],
        'pickup_person': schedule['pickup'],
      });
      return true;
    } catch (e) {
      return false;
    }
  }

  Future<bool> deleteException(int studentId, DateTime date) async {
    try {
      await supabase
          .from('pickup_dropoff_exceptions')
          .delete()
          .eq('student_id', studentId)
          .eq('exception_date', date.toIso8601String().split('T')[0]);
      return true;
    } catch (e) {
      return false;
    }
  }
}