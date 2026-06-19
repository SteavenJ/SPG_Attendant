import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class StorageService {
  static const String keyEvents = 'attendance_events';

  // Save an event locally
  Future<void> saveEvent(String timestamp, String type) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> eventsList = prefs.getStringList(keyEvents) ?? [];
    
    eventsList.add(jsonEncode({
      'timestamp': timestamp,
      'type': type,
    }));
    
    await prefs.setStringList(keyEvents, eventsList);
  }

  // Get hours worked per day this week
  Future<Map<int, double>> getWeeklyHours() async {
    final prefs = await SharedPreferences.getInstance();
    List<String> eventsList = prefs.getStringList(keyEvents) ?? [];
    
    List<Map<String, dynamic>> events = eventsList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();
    
    // Process events to calculate hours per day
    Map<int, double> hoursPerDay = {
      1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0 // Mon-Sun
    };
    
    DateTime now = DateTime.now();
    int currentWeekday = now.weekday;
    DateTime startOfWeek = now.subtract(Duration(days: currentWeekday - 1));
    startOfWeek = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);

    Map<String, DateTime> lastClockIn = {};

    for (var event in events) {
      DateTime time = DateTime.parse(event['timestamp']);
      
      // Only consider events this week
      if (time.isAfter(startOfWeek) || time.isAtSameMomentAs(startOfWeek)) {
        String dateStr = '${time.year}-${time.month}-${time.day}';
        int weekday = time.weekday;

        if (event['type'] == 'Clock In') {
          lastClockIn[dateStr] = time;
        } else if (event['type'] == 'Clock Out' && lastClockIn.containsKey(dateStr)) {
          Duration diff = time.difference(lastClockIn[dateStr]!);
          hoursPerDay[weekday] = (hoursPerDay[weekday] ?? 0) + diff.inMinutes / 60.0;
          lastClockIn.remove(dateStr); // clear after pairing
        }
      }
    }

    return hoursPerDay;
  }
}
