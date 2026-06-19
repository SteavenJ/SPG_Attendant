import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spg_attendant/services/storage_service.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  test('Calculates weekly hours correctly', () async {
    final storageService = StorageService();
    
    // Simulate events from this week
    DateTime today = DateTime.now();
    DateTime clockIn = DateTime(today.year, today.month, today.day, 8, 0, 0);
    DateTime clockOut = DateTime(today.year, today.month, today.day, 16, 30, 0); // 8.5 hours
    
    await storageService.saveEvent(clockIn.toString(), 'Clock In');
    await storageService.saveEvent(clockOut.toString(), 'Clock Out');
    
    final weeklyHours = await storageService.getWeeklyHours();
    
    expect(weeklyHours[today.weekday], 8.5);
  });
}
