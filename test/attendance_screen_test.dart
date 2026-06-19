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
    
    when(() => mockStorageService.getWeeklyHours(any()))
        .thenAnswer((_) async => {1: 8.0, 2: 8.0});

    when(() => mockStorageService.getClockStateToday(any()))
        .thenAnswer((_) async => 'Clock In');

    when(() => mockStorageService.saveEvent(any(), any(), any()))
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
    await tester.pumpAndSettle();

    expect(find.text('SPG Attendant'), findsOneWidget);
    expect(find.text('Weekly Summary'), findsOneWidget);
    expect(find.text('123 Fake St (Lat: 0.0, Lng: 0.0)'), findsOneWidget);
    expect(find.byType(TextField), findsOneWidget);
    
    // Only Clock In should be visible initially
    expect(find.text('CLOCK IN'), findsOneWidget);
    expect(find.text('CLOCK OUT'), findsNothing);
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

    await tester.enterText(find.byType(TextField), 'EMP-123');
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('CLOCK IN'));
    await tester.pumpAndSettle();
    
    await tester.tap(find.text('CLOCK IN'), warnIfMissed: false);
    await tester.pump(); 
    await tester.pumpAndSettle(); 

    verify(() => mockApiService.recordAttendance(
      timestamp: any(named: 'timestamp'),
      employeeId: 'EMP-123',
      type: 'Clock In',
      address: '123 Fake St (Lat: 0.0, Lng: 0.0)',
    )).called(1);
    
    verify(() => mockStorageService.saveEvent(any(), 'EMP-123', 'Clock In')).called(1);

    expect(find.text('Attendance recorded!'), findsOneWidget);
  });
}
