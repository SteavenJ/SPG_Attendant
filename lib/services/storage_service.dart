import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String keyEvents = 'attendance_events';

  // Save an event locally
  Future<void> saveEvent(String timestamp, String employeeId, String type) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> eventsList = prefs.getStringList(keyEvents) ?? [];
    
    eventsList.add(jsonEncode({
      'timestamp': timestamp,
      'employeeId': employeeId,
      'type': type,
    }));
    
    await prefs.setStringList(keyEvents, eventsList);
  }

  // Check the state for a specific employee today
  Future<String> getClockStateToday(String employeeId) async {
    if (employeeId.trim().isEmpty) return 'Clock In';

    final prefs = await SharedPreferences.getInstance();
    List<String> eventsList = prefs.getStringList(keyEvents) ?? [];
    List<Map<String, dynamic>> events = eventsList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    DateTime now = DateTime.now();
    
    List<Map<String, dynamic>> todayEvents = events.where((event) {
      if (event['employeeId'] != employeeId) return false;
      DateTime time = DateTime.parse(event['timestamp']);
      return time.year == now.year && time.month == now.month && time.day == now.day;
    }).toList();

    todayEvents.sort((a, b) => DateTime.parse(a['timestamp']).compareTo(DateTime.parse(b['timestamp'])));

    if (todayEvents.isEmpty) return 'Clock In';
    
    String lastType = todayEvents.last['type'];
    if (lastType == 'Clock In') return 'Clock Out';
    
    return 'Clock In'; // Allow clocking in again after clocking out
  }

  // Get hours worked per day this week for a specific employee
  Future<Map<int, double>> getWeeklyHours(String employeeId) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> eventsList = prefs.getStringList(keyEvents) ?? [];
    
    List<Map<String, dynamic>> events = eventsList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    
    Map<int, double> hoursPerDay = {
      1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0
    };
    
    if (employeeId.trim().isEmpty) return hoursPerDay;

    DateTime now = DateTime.now();
    int currentWeekday = now.weekday;
    DateTime startOfWeek = now.subtract(Duration(days: currentWeekday - 1));
    startOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    Map<String, DateTime> lastClockIn = {};

    for (var event in events) {
      if (event['employeeId'] != employeeId) continue;

      DateTime time = DateTime.parse(event['timestamp']);
      
      if (time.isAfter(startOfWeek) || time.isAtSameMomentAs(startOfWeek)) {
        String dateStr = '${time.year}-${time.month}-${time.day}';
        int weekday = time.weekday;

        if (event['type'] == 'Clock In') {
          lastClockIn[dateStr] = time;
        } else if (event['type'] == 'Clock Out' && lastClockIn.containsKey(dateStr)) {
          Duration diff = time.difference(lastClockIn[dateStr]!);
          hoursPerDay[weekday] = (hoursPerDay[weekday] ?? 0) + diff.inMinutes / 60.0;
          lastClockIn.remove(dateStr); 
        }
      }
    }

    return hoursPerDay;
  }
}
