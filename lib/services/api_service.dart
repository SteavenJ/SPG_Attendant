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

  static const List<String> salesScriptUrls = [
    'https://script.google.com/macros/s/AKfycbzUlbSZnHftxcLirQk2ryUQh1_vGLRD5gkPR5jCVfnnPN9osqlBzKylwn48y9cWxKkz/exec'  // Penjualan Master Web App
  ];

  static Map<String, String>? _promotorCache;

  Future<Map<String, String>> fetchPromotorNames({bool forceRefresh = false}) async {
    if (!forceRefresh && _promotorCache != null) {
      return _promotorCache!;
    }
    // 1. Coba ambil langsung dari REKAP ABSEN SPG (scriptUrls[0])
    try {
      final response = await client.get(Uri.parse(scriptUrls[0]));
      if (response.statusCode == 200 || response.statusCode == 302) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic> && decoded.isNotEmpty && !decoded.containsKey('status')) {
          _promotorCache = decoded.map((key, value) => MapEntry(key, value.toString()));
          return _promotorCache!;
        }
      }
    } catch (_) {}

    // 2. Fallback ke reportScriptUrls jika scriptUrls belum ada doGet
    try {
      final response = await client.get(Uri.parse(reportScriptUrls[0]));
      if (response.statusCode == 200 || response.statusCode == 302) {
        final dynamic decoded = jsonDecode(response.body);
        if (decoded is Map<String, dynamic>) {
          _promotorCache = decoded.map((key, value) => MapEntry(key, value.toString()));
          return _promotorCache!;
        }
      }
    } catch (_) {}

    return _promotorCache ?? {};
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

  Future<bool> submitSalesReport(Map<String, dynamic> salesData) async {
    try {
      final body = jsonEncode(salesData);
      final uniqueUrls = salesScriptUrls.toSet().toList();
      final responses = await Future.wait(
        uniqueUrls.map((url) => client.post(
              Uri.parse(url),
              headers: {'Content-Type': 'text/plain'},
              body: body,
            )),
      );

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

  Future<Map<String, dynamic>?> fetchPencapaian(String employeeId) async {
    try {
      // First try POST with action 'pencapaian' (immune to CORS/redirect issues in Flutter Web)
      final body = jsonEncode({
        'action': 'pencapaian',
        'employeeId': employeeId,
      });

      final response = await client.post(
        Uri.parse(salesScriptUrls[0]),
        headers: {'Content-Type': 'text/plain'},
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['status'] == 'success') {
          return data;
        }
      }
    } catch (_) {
      // Fallback to GET if POST fails
      try {
        final uri = Uri.parse(salesScriptUrls[0]).replace(queryParameters: {
          'action': 'pencapaian',
          'employeeId': employeeId,
        });
        final response = await client.get(uri);
        if (response.statusCode == 200 || response.statusCode == 302) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          if (data['status'] == 'success') {
            return data;
          }
        }
      } catch (_) {}
    }
    return null;
  }

  Future<Map<String, dynamic>?> fetchSalesHistory({
    required String employeeId,
    String? toko,
    String? tanggal,
    String? periode,
  }) async {
    try {
      final body = jsonEncode({
        'action': 'daftar_penjualan',
        'employeeId': employeeId,
        if (toko != null && toko.isNotEmpty) 'toko': toko,
        if (tanggal != null && tanggal.isNotEmpty) 'tanggal': tanggal,
        if (periode != null && periode.isNotEmpty) 'periode': periode,
      });

      final response = await client.post(
        Uri.parse(salesScriptUrls[0]),
        headers: {'Content-Type': 'text/plain'},
        body: body,
      );

      if (response.statusCode == 200 || response.statusCode == 302) {
        final Map<String, dynamic> data = jsonDecode(response.body);
        if (data['status'] == 'success' && data['data'] != null) {
          return data;
        }
      }
    } catch (_) {
      try {
        final queryParams = <String, String>{
          'action': 'daftar_penjualan',
          'employeeId': employeeId,
        };
        if (toko != null && toko.isNotEmpty) queryParams['toko'] = toko;
        if (tanggal != null && tanggal.isNotEmpty) queryParams['tanggal'] = tanggal;
        if (periode != null && periode.isNotEmpty) queryParams['periode'] = periode;

        final uri = Uri.parse(salesScriptUrls[0]).replace(queryParameters: queryParams);
        final response = await client.get(uri);
        if (response.statusCode == 200 || response.statusCode == 302) {
          final Map<String, dynamic> data = jsonDecode(response.body);
          if (data['status'] == 'success' && data['data'] != null) {
            return data;
          }
        }
      } catch (_) {}
    }
    return null;
  }
}
