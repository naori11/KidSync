import 'package:supabase_flutter/supabase_flutter.dart';

/// Returns the phone number for the currently authenticated user.
/// It first checks the `parents` table for a record where user_id = auth.currentUser.id
/// and returns `parents.phone`. If not found, it falls back to `users.contact_number`.
Future<String?> getCurrentUserPhone() async {
  final supabase = Supabase.instance.client;
  final user = supabase.auth.currentUser;
  if (user == null) return null;

  try {
    final parentRes =
        await supabase
            .from('parents')
            .select('phone')
            .eq('user_id', user.id)
            .limit(1)
            .maybeSingle();
    if (parentRes != null && parentRes['phone'] != null) {
      final phone = parentRes['phone'] as String;
      print(
        'user_contact_helper: found parent phone=$phone for user=${user.id}',
      );
      return phone;
    }

    final userRes =
        await supabase
            .from('users')
            .select('contact_number')
            .eq('id', user.id)
            .limit(1)
            .maybeSingle();
    if (userRes != null && userRes['contact_number'] != null) {
      final phone = userRes['contact_number'] as String;
      print(
        'user_contact_helper: found user.contact_number=$phone for user=${user.id}',
      );
      return phone;
    }
  } catch (e) {
    // ignore and return null
  }
  return null;
}
