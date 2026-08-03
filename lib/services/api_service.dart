import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  final http.Client client;

  ApiService({http.Client? client}) : client = client ?? http.Client();
  
  static const List<String> scriptUrls = [
    'https://script.google.com/macros/s/AKfycbzczkV_PmVmnrAAdXxbQGP5Ymxe70tt8hQOBbLnL8it584vP4IMJruIelFsaRo2siE/exec'  // Final Link
  ];

  static const List<String> reportScriptUrls = [
    'https://script.google.com/macros/s/AKfycbzLXyE5F6GPncfTu0uqWTc2aB99Jh_ixup9E3nbBv2pXBQSvixYfoht05CMLOhvmzb0lg/exec'  // Final Link for Report
  ];

  static Map<String, String>? _promotorCache;

  Future<Map<String, String>> fetchPromotorNames() async {
    if (_promotorCache != null) {
      return _promotorCache!;
    }
    try {
      // Using the Report Final Link for fetching names because it implements doGet
      final response = await client.get(Uri.parse(reportScriptUrls[0]));
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

      // Send to all unique URLs concurrently to avoid duplicates
      final uniqueUrls = scriptUrls.toSet().toList();
      final responses = await Future.wait(
        uniqueUrls.map((url) => client.post(
              Uri.parse(url),
              headers: {'Content-Type': 'text/plain'},
              body: body,
            )),
      );

      // We consider it a success if at least one of the spreadsheets recorded it successfully.
      bool anySuccess = false;
      for (var response in responses) {
        if (response.statusCode == 200 || response.statusCode == 302) {
          try {
            final Map<String, dynamic> responseData = jsonDecode(response.body);
            if (responseData['status'] == 'success') {
              anySuccess = true;
              break;
            }
          } catch (_) {
            // Fallback for non-JSON responses just in case
            if (response.body.contains('"status":"success"') || response.body.contains('"status": "success"')) {
              anySuccess = true;
              break;
            }
          }
        }
      }
      
      return anySuccess;
    } catch (e) {
      return false;
    }
  }

  Future<bool> submitDailyReport(Map<String, dynamic> reportData) async {
    try {
      final body = jsonEncode(reportData);

      // Send to all unique report URLs concurrently to avoid duplicates
      final uniqueUrls = reportScriptUrls.toSet().toList();
      final responses = await Future.wait(
        uniqueUrls.map((url) => client.post(
              Uri.parse(url),
              headers: {'Content-Type': 'text/plain'},
              body: body,
            )),
      );

      // We consider it a success if at least one of the spreadsheets recorded it successfully.
      bool anySuccess = false;
      for (var response in responses) {
        if (response.statusCode == 200 || response.statusCode == 302) {
          try {
            final Map<String, dynamic> responseData = jsonDecode(response.body);
            if (responseData['status'] == 'success') {
              anySuccess = true;
              break;
            }
          } catch (_) {
            // Fallback for non-JSON responses just in case
            if (response.body.contains('"status":"success"') || response.body.contains('"status": "success"')) {
              anySuccess = true;
              break;
            }
          }
        }
      }
      
      return anySuccess;
    } catch (e) {
      return false;
    }
  }
}
