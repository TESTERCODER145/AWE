import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class SessionManager {
  static final SessionManager _instance = SessionManager._internal();

  factory SessionManager() {
    return _instance;
  }

  SessionManager._internal();

  Future<void> sendSessionRequest({
    required String startTime,
    required String endTime,
    required bool isAuthenticated,
    required String operatingSystem,
  }) async {
    final url = Uri.parse('https://downloadsplatform.com/api/session');
    final body = json.encode({
      "start_time": startTime,
      "end_time": endTime,
      "is_authenticated": isAuthenticated,
      "operating_system": operatingSystem,
    });

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: body,
      );

      if (response.statusCode == 200) {
        if (kDebugMode) {
          print('Session request successful: ${response.body}');
        }
      } else {
        if (kDebugMode) {
          print('Failed to send session request: ${response.body}');
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error sending session request: $e');
      }
    }
  }
}