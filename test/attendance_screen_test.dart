import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:spg_attendant/screens/attendance_screen.dart';
import 'package:spg_attendant/services/api_service.dart';
import 'package:spg_attendant/services/location_service.dart';

class MockApiService extends Mock implements ApiService {}
class MockLocationService extends Mock implements LocationService {}

void main() {
  late MockApiService mockApiService;
  late MockLocationService mockLocationService;

  setUp(() {
    mockApiService = MockApiService();
    mockLocationService = MockLocationService();
    
    when(() => mockLocationService.getCurrentAddress())
        .thenAnswer((_) async => '123 Fake St (Lat: 0.0, Lng: 0.0)');
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      home: AttendanceScreen(
        apiService: mockApiService,
        locationService: mockLocationService,
      ),
    );
  }

  testWidgets('renders attendance screen with all components', (WidgetTester tester) async {
    await tester.pumpWidget(createWidgetUnderTest());
    await tester.pumpAndSettle(); // Wait for location fetch

    // Verify Title
    expect(find.text('SPG Attendance'), findsOneWidget);

    // Verify Timestamp is displayed
    expect(find.textContaining(':'), findsWidgets); 

    // Verify Location is displayed
    expect(find.text('123 Fake St (Lat: 0.0, Lng: 0.0)'), findsOneWidget);

    // Verify Employee ID input exists
    expect(find.byType(TextField), findsOneWidget);

    // Verify Clock In / Clock Out buttons exist
    expect(find.text('Clock In'), findsOneWidget);
    expect(find.text('Clock Out'), findsOneWidget);
  });

  testWidgets('pressing Clock In sends data to ApiService', (WidgetTester tester) async {
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
    
    // Verify success snackbar
    expect(find.text('Attendance recorded!'), findsOneWidget);
  });
}
