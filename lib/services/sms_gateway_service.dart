import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

/// Simple client-side SMS sender for SMSGate cloud API.
/// Client-side SMS sender for SMSGate cloud API.
/// Sends JSON payload matching SMSGate: { textMessage: { text }, phoneNumbers: [...] }
/// Do NOT hardcode credentials in production; use secure storage or environment config.
class SmsGatewayService {
  final String baseUrl;

  /// Optional: when provided, the client will call this server-side function URL
  /// which proxies to the SMS provider. This avoids CORS and keeps credentials
  /// server-side. When set, username/password are not used.
  final String? supabaseFunctionUrl;
  final String username;
  final String password;
  final http.Client _http;

  final List<_SmsJob> _queue = [];
  Timer? _workerTimer;
  bool _sending = false;

  SmsGatewayService({
    this.baseUrl = 'https://api.sms-gate.app/3rdparty/v1/message',
    this.supabaseFunctionUrl,
    required this.username,
    required this.password,
    http.Client? httpClient,
  }) : _http = httpClient ?? http.Client();

  /// Queue SMS for sending. `recipients` is a list of E.164 numbers.
  Future<bool> sendSms({
    required List<String> recipients,
    required String message,
  }) async {
    if (recipients.isEmpty || message.trim().isEmpty) return false;
    final job = _SmsJob(
      recipients: List<String>.from(recipients),
      message: message,
      attempts: 0,
    );
    _queue.add(job);
    // DEBUG: log queue enqueue for tracing
    try {
      print(
        'SmsGatewayService: queued SMS job -> recipients=${job.recipients.length}, preview="${job.message.length} chars"',
      );
    } catch (_) {}
    _ensureWorker();
    return true;
  }

  void _ensureWorker() {
    _workerTimer ??= Timer.periodic(
      const Duration(seconds: 2),
      (_) => _processQueue(),
    );
  }

  Future<void> _processQueue() async {
    if (_sending || _queue.isEmpty) return;
    _sending = true;
    final job = _queue.first;
    try {
      final ok = await _doSend(job);
      if (ok) {
        _queue.removeAt(0);
      } else {
        job.attempts += 1;
        if (job.attempts >= 5) {
          _queue.removeAt(0);
        } else {
          await Future.delayed(Duration(seconds: 2 * job.attempts));
        }
      }
    } catch (_) {
      job.attempts += 1;
    } finally {
      _sending = false;
      if (_queue.isEmpty) {
        _workerTimer?.cancel();
        _workerTimer = null;
      }
    }
  }

  Future<bool> _doSend(_SmsJob job) async {
    final useFunction =
        (supabaseFunctionUrl != null && supabaseFunctionUrl!.isNotEmpty);
    final uri = Uri.parse(useFunction ? supabaseFunctionUrl! : baseUrl);
    final headers = <String, String>{'Content-Type': 'application/json'};
    if (useFunction) {
      // Attach current user's access token as Bearer if available so the Edge Function
      // can authenticate the request. This keeps the function protected and avoids
      // requiring an anonymous open endpoint.
      try {
        final session = Supabase.instance.client.auth.currentSession;
        final token = session?.accessToken;
        if (token != null && token.isNotEmpty) {
          headers['Authorization'] = 'Bearer $token';
        }
      } catch (e) {
        // If Supabase isn't initialized or session missing, continue without token.
        print('SmsGatewayService: could not attach supabase token: $e');
      }
    } else {
      final auth = base64Encode(utf8.encode('${username}:${password}'));
      headers['Authorization'] = 'Basic $auth';
    }

    // DEBUG: indicate which transport is used and whether Authorization header is present
    try {
      print(
        'SmsGatewayService: sending via ${useFunction ? 'function-mode' : 'direct-mode'}; Authorization header present=${headers.containsKey('Authorization')}',
      );
    } catch (_) {}

    // Normalize recipients into E.164-like format expected by SMSGate
    final normalized =
        job.recipients
            .map((r) => _normalizeNumber(r))
            .where((r) => r.isNotEmpty)
            .toList();
    print('SMS Gateway: normalized recipients=$normalized');

    final Map<String, dynamic> payload = {
      'textMessage': {'text': job.message},
      'phoneNumbers': normalized,
    };

    try {
      final body = jsonEncode(payload);
      // DEBUG: show payload (do not include credentials)
      print('SMS Gateway: POST $uri');
      print('SMS Gateway: payload=${body}');

      final resp = await _http
          .post(uri, headers: headers, body: body)
          .timeout(const Duration(seconds: 10));

      print('SMS Gateway: response status=${resp.statusCode}');
      if (resp.body.isNotEmpty) {
        print('SMS Gateway: response body=${resp.body}');
      }

      if (resp.statusCode >= 200 && resp.statusCode < 300) {
        return true;
      }
      return false;
    } catch (e) {
      print('SMS Gateway: send exception: $e');
      return false;
    }
  }

  String _normalizeNumber(String raw) {
    var s = raw.trim();
    // Remove common separators
    s = s.replaceAll(RegExp(r'[\s\-\(\)]'), '');

    // If already has leading + and digits, keep as-is (but ensure only digits after plus)
    if (s.startsWith('+')) {
      final digits = s.substring(1).replaceAll(RegExp(r'[^0-9]'), '');
      return '+$digits';
    }

    // Remove any non-digit characters
    s = s.replaceAll(RegExp(r'[^0-9]'), '');

    // Philippines: convert 0XXXXXXXXXX (11 digits starting with 0) to +63XXXXXXXXX
    if (s.length == 11 && s.startsWith('0')) {
      return '+63' + s.substring(1);
    }

    // If it starts with 63 (without +), add +
    if (s.length >= 11 && s.startsWith('63')) {
      return '+$s';
    }

    // If mobile formatted as 9XXXXXXXXX (10 digits), assume missing leading 0 -> +63
    if (s.length == 10 && s.startsWith('9')) {
      return '+63$s';
    }

    // Fallback: return digits as-is (could be international already)
    return s;
  }

  Future<void> dispose() async {
    _workerTimer?.cancel();
    _workerTimer = null;
    _http.close();
  }
}

class _SmsJob {
  final List<String> recipients;
  final String message;
  int attempts;
  _SmsJob({
    required this.recipients,
    required this.message,
    required this.attempts,
  });
}
