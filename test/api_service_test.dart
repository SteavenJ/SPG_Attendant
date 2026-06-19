import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';
import 'package:spg_attendant/services/api_service.dart';

class MockHttpClient extends Mock implements http.Client {}

void main() {
  setUpAll(() {
    registerFallbackValue(Uri.parse('http://localhost'));
  });

  group('ApiService', () {
    late ApiService apiService;
    late MockHttpClient mockHttpClient;

    setUp(() {
      mockHttpClient = MockHttpClient();
      apiService = ApiService(client: mockHttpClient);
    });

    test('recordAttendance sends correct data and returns true on success', () async {
      // Arrange
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('{"status": "success"}', 200));

      // Act
      final result = await apiService.recordAttendance(
        timestamp: '2023-10-27 10:00:00',
        employeeId: 'EMP001',
        type: 'Clock In',
        address: '123 Test St',
      );

      // Assert
      expect(result, true);
      verify(() => mockHttpClient.post(
            Uri.parse(ApiService.scriptUrl),
            headers: {'Content-Type': 'application/json'},
            body: '{"timestamp":"2023-10-27 10:00:00","employeeId":"EMP001","type":"Clock In","address":"123 Test St"}',
          )).called(1);
    });

    test('recordAttendance returns false on HTTP error', () async {
      // Arrange
      when(() => mockHttpClient.post(
            any(),
            headers: any(named: 'headers'),
            body: any(named: 'body'),
          )).thenAnswer((_) async => http.Response('Error', 500));

      // Act
      final result = await apiService.recordAttendance(
        timestamp: '2023-10-27 10:00:00',
        employeeId: 'EMP001',
        type: 'Clock In',
        address: '123 Test St',
      );

      // Assert
      expect(result, false);
    });
  });
}
