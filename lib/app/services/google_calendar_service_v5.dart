import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_sign_in/google_sign_in.dart';

class GoogleCalendarServiceV5 {
  final GoogleSignIn _googleSignIn = GoogleSignIn(
    scopes: ['https://www.googleapis.com/auth/calendar'],
  );

  Future<String?> signInAndGetAccessToken() async {
    final account = await _googleSignIn.signIn();
    final auth = await account?.authentication;
    return auth?.accessToken;
  }

  Future<Map<String, String>?> createEvent({
    required String accessToken,
    required DateTime startUtc,
    required DateTime endUtc,
    required String title,
    required String description,
  }) async {
    final url = Uri.parse('https://www.googleapis.com/calendar/v3/calendars/primary/events');
    final headers = {
      'Authorization': 'Bearer $accessToken',
      'Content-Type': 'application/json',
    };
    final body = {
      'summary': title,
      'description': description,
      'start': {
        'dateTime': startUtc.toIso8601String(),
        'timeZone': 'Asia/Ho_Chi_Minh',
      },
      'end': {
        'dateTime': endUtc.toIso8601String(),
        'timeZone': 'Asia/Ho_Chi_Minh',
      },
    };

    try {
      final response = await http.post(url, headers: headers, body: jsonEncode(body));
      print('Calendar API response: ${response.statusCode} ${response.body}');
      if (response.statusCode == 200 || response.statusCode == 201) {
        final json = jsonDecode(response.body);
        return {
          'eventId': json['id'],
          'htmlLink': json['htmlLink'],
        };
      }
      return null;
    } catch (e) {
      print('Calendar API error: $e');
      return null;
    }
  }
}