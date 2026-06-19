import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spg_attendant/screens/attendance_screen.dart';
import 'package:spg_attendant/services/api_service.dart';
import 'package:spg_attendant/services/location_service.dart';
import 'package:spg_attendant/services/storage_service.dart';

class MockApiService extends Mock implements ApiService {}
class MockLocationService extends Mock implements LocationService {}
class MockStorageService extends Mock implements StorageService {}

void main() {
  late MockApiService mockApiService;
  late MockLocationService mockLocationService;
  late MockStorageService mockStorageService;

  setUp(() {
    mockApiService = MockApiService();
    mockLocationService = MockLocationService();
    mockStorageService = MockStorageService();
    
    when(() => mockLocationService.getCurrentAddress())
        .thenAnswer((_) async => '123 Fake St (Lat: 0.0, Lng: 0.0)');
    
    when(() => mockStorageService.getWeeklyHours())
        .thenAnswer((_) async => {1: 8.0, 2: 8.0});

    when(() => mockStorageService.saveEvent(any(), any()))
        .thenAnswer((_) async {});
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: AttendanceScreen(
        apiService: mockApiService,
        locationService: mockLocationService,
        storageService: mockStorageService,
      ),
    );
  }

  testWidgets('renders attendance screen with all components and graph', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle(); // Wait for location fetch

    // Verify Title
    expect(find.text('SPG Attendance'), findsOneWidget);

    // Verify Graph
    expect(find.text('Weekly Hours'), findsOneWidget);

    // Verify Location is displayed
    expect(find.text('123 Fake St (Lat: 0.0, Lng: 0.0)'), findsOneWidget);

    // Verify Employee ID input exists
    expect(find.byType(TextField), findsOneWidget);
  });

  testWidgets('pressing Clock In sends data to ApiService and saves to Storage', (WidgetTester tester) async {
    when(() => mockApiService.recordAttendance(
      timestamp: any(named: 'timestamp'),
      employeeId: any(named: 'employeeId'),
      type: any(named: 'type'),
      address: any(named: 'address'),
    )).thenAnswer((_) async => true);

    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle();

    // Enter Employee ID
    await tester.enterText(find.byType(TextField), 'EMP-123');
    
    // Tap Clock In
    await tester.tap(find.text('Clock In'));
    await tester.pump(); // Start loading
    await tester.pumpAndSettle(); // Finish loading

    // Verify API called
    verify(() => mockApiService.recordAttendance(
      timestamp: any(named: 'timestamp'),
      employeeId: 'EMP-123',
      type: 'Clock In',
      address: '123 Fake St (Lat: 0.0, Lng: 0.0)',
    )).called(1);
    
    // Verify Storage called
    verify(() => mockStorageService.saveEvent(any(), 'Clock In')).called(1);

    // Verify success snackbar
    expect(find.text('Attendance recorded!'), findsOneWidget);
  });
}
