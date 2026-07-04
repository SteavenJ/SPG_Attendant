import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final http.Client client;

  ApiService({http.Client? client}) : client = client ?? http.Client();
  
  static const List<String> scriptUrls = [
    'Place Your Link In Here', // Testing Link
    'Place Your Link In Here'  // Final Link
  ];

  static const List<String> reportScriptUrls = [
    'https://script.google.com/macros/s/AKfycbzLXyE5F6GPncfTu0uqWTc2aB99Jh_ixup9E3nbBv2pXBQSvixYfoht05CMLOhvmzb0lg/exec', // Testing Link for Report
    'https://script.google.com/macros/s/AKfycbzLXyE5F6GPncfTu0uqWTc2aB99Jh_ixup9E3nbBv2pXBQSvixYfoht05CMLOhvmzb0lg/exec'  // Final Link for Report
  ];

  static Map<String, String>? _promotorCache;

  Future<Map<String, String>> fetchPromotorNames() async {
    if (_promotorCache != null) {
      return _promotorCache!;
    }
    try {
      // Using the Final Link for fetching data
      final response = await client.get(Uri.parse(scriptUrls[1]));
      if (response.statusCode == 200 || response.statusCode == 302) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        _promotorCache = data.map((key, value) => MapEntry(key, value.toString()));
        return _promotorCache!;
      }
    } catch (e) {
      // Return empty map on error
    }
    return {};
  }

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
              headers: {'Content-Type': 'text/plain'},
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

  Future<bool> submitDailyReport(Map<String, dynamic> reportData) async {
    try {
      final body = jsonEncode(reportData);

      // Send to all report URLs concurrently
      final responses = await Future.wait(
        reportScriptUrls.map((url) => client.post(
              Uri.parse(url),
              headers: {'Content-Type': 'text/plain'},
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
