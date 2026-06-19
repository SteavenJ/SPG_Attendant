import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spg_attendant/services/storage_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Calculates weekly hours correctly and gets clock state', () async {
    final storageService = StorageService();
    
    // Initial state
    expect(await storageService.getClockStateToday('EMP1'), 'Clock In');

    // Simulate events from this week
    DateTime today = DateTime.now();
    DateTime clockIn = DateTime(today.year, today.month, today.day, 8, 0, 0);
    DateTime clockOut = DateTime(today.year, today.month, today.day, 16, 30, 0); // 8.5 hours
    
    await storageService.saveEvent(clockIn.toString(), 'EMP1', 'Clock In');
    expect(await storageService.getClockStateToday('EMP1'), 'Clock Out');

    await storageService.saveEvent(clockOut.toString(), 'EMP1', 'Clock Out');
    expect(await storageService.getClockStateToday('EMP1'), 'Clock In');
    
    final weeklyHours = await storageService.getWeeklyHours('EMP1');
    expect(weeklyHours[today.weekday], 8.5);

    // Another employee has empty hours and 'Clock In' state
    expect(await storageService.getClockStateToday('EMP2'), 'Clock In');
    final weeklyHoursEmp2 = await storageService.getWeeklyHours('EMP2');
    expect(weeklyHoursEmp2[today.weekday], 0);
  });
}
