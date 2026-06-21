import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final http.Client client;

  ApiService({http.Client? client}) : client = client ?? http.Client();
  
  static const List<String> scriptUrls = [
    'https://script.google.com/macros/s/AKfycbwrTWRTAgn0yIr02fMOdHlXeutTs99VEcB2mP-bmEWcRJqGxUI3al73HayxG5F8YVIFWg/exec', // Testing Link
    'https://script.google.com/macros/s/AKfycbzczkV_PmVmnrAAdXxbQGP5Ymxe70tt8hQOBbLnL8it584vP4IMJruIelFsaRo2siE/exec'  // Final Link
  ];

  Future<bool> recordAttendance({
    required String timestamp,
    required String employeeId,
    required String type,
    required String address,
  }) async {
    try {
      final body = jsonEncode({
        'timestamp': timestamp,
        'employeeId': employeeId,
        'type': type,
        'address': address,
      });

      // Send to all URLs concurrently
      final responses = await Future.wait(
        scriptUrls.map((url) => client.post(
              Uri.parse(url),
              headers: {'Content-Type': 'application/json'},
              body: body,
            )),
      );

      // We consider it a success if at least one of the spreadsheets recorded it successfully.
      bool anySuccess = responses.any((response) => 
        response.statusCode == 200 || response.statusCode == 302);
      
      return anySuccess;
    } catch (e) {
      return false;
    }
  }
}
