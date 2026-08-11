import 'dart:convert';
import 'dart:io';

/// Debug logger for troubleshooting
class DebugLogger {
  static const String _serverUrl = 'http://127.0.0.1:7777/event';
  static const String _defaultSessionId = 'login-failure';

  static void log({
    required String hypothesisId,
    required String location,
    required String message,
    Map<String, dynamic>? data,
    String runId = 'pre-fix',
    String sessionId = _defaultSessionId,
  }) async {
    try {
      final payload = {
        'sessionId': sessionId,
        'runId': runId,
        'hypothesisId': hypothesisId,
        'location': location,
        'msg': '[DEBUG] $message',
        'data': data ?? {},
        'ts': DateTime.now().millisecondsSinceEpoch,
      };

      final client = HttpClient();
      final request = await client.postUrl(Uri.parse(_serverUrl));
      request.headers.set('Content-Type', 'application/json');
      request.write(jsonEncode(payload));
      await request.close();
      client.close();
    } catch (_) {
      // Silently fail to avoid affecting app behavior
    }
  }
}
