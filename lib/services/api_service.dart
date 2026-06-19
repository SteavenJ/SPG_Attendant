import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final http.Client client;

  ApiService({http.Client? client}) : client = client ?? http.Client();

  static const String scriptUrl = 'https://script.google.com/macros/s/AKfycbwrTWRTAgn0yIr02fMOdHlXeutTs99VEcB2mP-bmEWcRJqGxUI3al73HayxG5F8YVIFWg/exec';

  Future<bool> recordAttendance({
    required String timestamp,
    required String employeeId,
    required String type,
    required String address,
  }) async {
    try {
      final response = await client.post(
        Uri.parse(scriptUrl),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'timestamp': timestamp,
          'employeeId': employeeId,
          'type': type,
          'address': address,
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        return true;
      }
      return false;
    } catch (e) {
      return false;
    }
  }
}
