import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class DailyAttendanceLog {
  final DateTime date;
  final int weekday; // 1 = Monday, 7 = Sunday
  final String? clockInTime;
  final String? clockOutTime;
  final String? address;
  final double hours;
  final String status;
  final bool isOngoing;
  final bool missedClockOut;

  const DailyAttendanceLog({
    required this.date,
    required this.weekday,
    this.clockInTime,
    this.clockOutTime,
    this.address,
    required this.hours,
    required this.status,
    this.isOngoing = false,
    this.missedClockOut = false,
  });
}

class TodayAttendanceStatus {
  final String nextState; // 'Clock In' or 'Clock Out'
  final bool hasClockedIn;
  final bool hasClockedOut;
  final bool isOngoing;
  final String? firstClockInTime;
  final String? lastClockOutTime;
  final String? clockInAddress;
  final String? clockOutAddress;
  final double todayHours;
  final int eventCount;

  const TodayAttendanceStatus({
    required this.nextState,
    required this.hasClockedIn,
    required this.hasClockedOut,
    required this.isOngoing,
    this.firstClockInTime,
    this.lastClockOutTime,
    this.clockInAddress,
    this.clockOutAddress,
    required this.todayHours,
    required this.eventCount,
  });

  factory TodayAttendanceStatus.empty() {
    return const TodayAttendanceStatus(
      nextState: 'Clock In',
      hasClockedIn: false,
      hasClockedOut: false,
      isOngoing: false,
      todayHours: 0.0,
      eventCount: 0,
    );
  }
}

class WeeklyAttendanceSummary {
  final Map<int, double> hoursPerDay; // 1=Mon, ..., 7=Sun
  final double totalHours;
  final int daysPresent;
  final double avgHoursPerDay;
  final DateTime startOfWeek;
  final DateTime endOfWeek;
  final List<DailyAttendanceLog> dailyLogs;

  const WeeklyAttendanceSummary({
    required this.hoursPerDay,
    required this.totalHours,
    required this.daysPresent,
    required this.avgHoursPerDay,
    required this.startOfWeek,
    required this.endOfWeek,
    required this.dailyLogs,
  });

  factory WeeklyAttendanceSummary.empty() {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day).subtract(Duration(days: now.weekday - 1));
    final end = start.add(const Duration(days: 6));
    final emptyLogs = List.generate(7, (index) {
      final d = start.add(Duration(days: index));
      return DailyAttendanceLog(
        date: d,
        weekday: index + 1,
        hours: 0.0,
        status: 'Belum Ada Absen',
      );
    });
    return WeeklyAttendanceSummary(
      hoursPerDay: {1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0},
      totalHours: 0.0,
      daysPresent: 0,
      avgHoursPerDay: 0.0,
      startOfWeek: start,
      endOfWeek: end,
      dailyLogs: emptyLogs,
    );
  }
}

class MonthlyAttendanceSummary {
  final String period; // e.g. '2026-11'
  final int year;
  final int month;
  final int totalDaysInMonth;
  final int standardWorkingDays; // perkiraan hari kerja non-Minggu dalam bulan
  final double totalHours;
  final int daysPresent;
  final double avgHoursPerDay;
  final double attendancePercentage; // (daysPresent / standardWorkingDays) * 100
  final List<DailyAttendanceLog> dailyLogs;

  const MonthlyAttendanceSummary({
    required this.period,
    required this.year,
    required this.month,
    required this.totalDaysInMonth,
    required this.standardWorkingDays,
    required this.totalHours,
    required this.daysPresent,
    required this.avgHoursPerDay,
    required this.attendancePercentage,
    required this.dailyLogs,
  });

  factory MonthlyAttendanceSummary.empty({String? period}) {
    final now = DateTime.now();
    int y = now.year;
    int m = now.month;
    if (period != null && period.contains('-')) {
      final parts = period.split('-');
      y = int.tryParse(parts[0]) ?? now.year;
      m = int.tryParse(parts[1]) ?? now.month;
    }
    final daysInMonth = DateTime(y, m + 1, 0).day;
    int workingDays = 0;
    final emptyLogs = List.generate(daysInMonth, (index) {
      final d = DateTime(y, m, index + 1);
      if (d.weekday != DateTime.sunday) workingDays++;
      return DailyAttendanceLog(
        date: d,
        weekday: d.weekday,
        hours: 0.0,
        status: 'Belum Ada Absen',
      );
    });

    final pStr = '$y-${m.toString().padLeft(2, '0')}';
    return MonthlyAttendanceSummary(
      period: pStr,
      year: y,
      month: m,
      totalDaysInMonth: daysInMonth,
      standardWorkingDays: workingDays > 0 ? workingDays : 26,
      totalHours: 0.0,
      daysPresent: 0,
      avgHoursPerDay: 0.0,
      attendancePercentage: 0.0,
      dailyLogs: emptyLogs,
    );
  }
}

class StorageService {
  static const String keyEvents = 'attendance_events';
  static const String keySavedEmployeeId = 'saved_employee_id';

  // Helper untuk mem-parsing berbagai format tanggal (ISO maupun format Google Sheet)
  static DateTime? parseTimestamp(String? raw) {
    if (raw == null || raw.trim().isEmpty) return null;
    final trimmed = raw.trim();

    // 1. Direct ISO parse (e.g. "2026-11-20 08:30:15" or "2026-11-20T08:30:15")
    final direct = DateTime.tryParse(trimmed);
    if (direct != null) return direct;

    // 2. Format from Google Sheet: "Wed Nov 18 2026 11:04:30 GMT+0800 (Waktu Indonesia Tengah)"
    try {
      final clean = trimmed.replaceAll(RegExp(r'\s*\([^)]*\)$'), '').trim();
      final parts = clean.split(' ');
      if (parts.length >= 5) {
        const monthMap = {
          'Jan': 1, 'Feb': 2, 'Mar': 3, 'Apr': 4, 'May': 5, 'Jun': 6,
          'Jul': 7, 'Aug': 8, 'Sep': 9, 'Oct': 10, 'Nov': 11, 'Dec': 12
        };
        final m = monthMap[parts[1]];
        final d = int.tryParse(parts[2]);
        final y = int.tryParse(parts[3]);
        final timeParts = parts[4].split(':');
        if (m != null && d != null && y != null && timeParts.length >= 2) {
          final hour = int.tryParse(timeParts[0]) ?? 0;
          final minute = int.tryParse(timeParts[1]) ?? 0;
          final second = timeParts.length >= 3 ? (int.tryParse(timeParts[2]) ?? 0) : 0;
          return DateTime(y, m, d, hour, minute, second);
        }
      }
    } catch (_) {}
    return null;
  }

  // Normalisasi timestamp ke format standar 'yyyy-MM-dd HH:mm:ss'
  static String normalizeTimestamp(String? raw) {
    final dt = parseTimestamp(raw);
    if (dt == null) return raw ?? '';
    final y = dt.year.toString().padLeft(4, '0');
    final m = dt.month.toString().padLeft(2, '0');
    final d = dt.day.toString().padLeft(2, '0');
    final hh = dt.hour.toString().padLeft(2, '0');
    final mm = dt.minute.toString().padLeft(2, '0');
    final ss = dt.second.toString().padLeft(2, '0');
    return '$y-$m-$d $hh:$mm:$ss';
  }

  // Save the remembered employee ID
  Future<void> setSavedEmployeeId(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final trimmed = id.trim();
    // Jangan pernah simpan ID 101 (Admin) secara permanen di storage
    if (trimmed.isEmpty || trimmed == '101') {
      await prefs.remove(keySavedEmployeeId);
    } else {
      await prefs.setString(keySavedEmployeeId, trimmed);
    }
  }

  // Get the remembered employee ID
  Future<String?> getSavedEmployeeId() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(keySavedEmployeeId);
  }

  // Clear remembered employee ID
  Future<void> clearSavedEmployeeId() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(keySavedEmployeeId);
  }

  // Save an event locally with optional address
  Future<void> saveEvent(
    String timestamp,
    String employeeId,
    String type, {
    String? address,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    List<String> eventsList = prefs.getStringList(keyEvents) ?? [];
    final normalizedTs = normalizeTimestamp(timestamp);
    
    eventsList.add(jsonEncode({
      'timestamp': normalizedTs,
      'employeeId': employeeId,
      'type': type,
      if (address != null && address.isNotEmpty) 'address': address,
    }));
    
    await prefs.setStringList(keyEvents, eventsList);
  }

  // Dapatkan status detail kehadiran hari ini
  Future<TodayAttendanceStatus> getTodayAttendanceStatus(String employeeId) async {
    if (employeeId.trim().isEmpty) {
      return TodayAttendanceStatus.empty();
    }

    final prefs = await SharedPreferences.getInstance();
    List<String> eventsList = prefs.getStringList(keyEvents) ?? [];
    List<Map<String, dynamic>> events = eventsList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    DateTime now = DateTime.now();

    List<Map<String, dynamic>> todayEvents = events.where((event) {
      if (event['employeeId'] != employeeId) return false;
      final time = parseTimestamp(event['timestamp']?.toString());
      if (time == null) return false;
      return time.year == now.year && time.month == now.month && time.day == now.day;
    }).toList();

    todayEvents.sort((a, b) {
      final tA = parseTimestamp(a['timestamp']?.toString()) ?? DateTime(0);
      final tB = parseTimestamp(b['timestamp']?.toString()) ?? DateTime(0);
      return tA.compareTo(tB);
    });

    if (todayEvents.isEmpty) {
      return TodayAttendanceStatus.empty();
    }

    Map<String, dynamic>? firstClockIn;
    Map<String, dynamic>? lastClockOut;
    double totalHours = 0.0;
    DateTime? tempIn;

    for (var ev in todayEvents) {
      final type = ev['type'];
      final time = parseTimestamp(ev['timestamp']?.toString());
      if (time == null) continue;

      if (type == 'Clock In') {
        firstClockIn ??= ev;
        tempIn = time;
      } else if (type == 'Clock Out' && tempIn != null) {
        lastClockOut = ev;
        totalHours += time.difference(tempIn).inMinutes / 60.0;
        tempIn = null;
      }
    }

    final bool isOngoing = tempIn != null;
    if (isOngoing) {
      final elapsedMins = now.difference(tempIn).inMinutes;
      if (elapsedMins > 0) {
        totalHours += elapsedMins / 60.0;
      }
    }

    final String lastType = todayEvents.last['type'] ?? 'Clock Out';
    final String nextState = lastType == 'Clock In' ? 'Clock Out' : 'Clock In';

    return TodayAttendanceStatus(
      nextState: nextState,
      hasClockedIn: firstClockIn != null,
      hasClockedOut: lastClockOut != null,
      isOngoing: isOngoing,
      firstClockInTime: firstClockIn?['timestamp'],
      lastClockOutTime: lastClockOut?['timestamp'],
      clockInAddress: firstClockIn?['address'],
      clockOutAddress: lastClockOut?['address'],
      todayHours: totalHours,
      eventCount: todayEvents.length,
    );
  }

  // Check the state for a specific employee today
  Future<String> getClockStateToday(String employeeId) async {
    final status = await getTodayAttendanceStatus(employeeId);
    return status.nextState;
  }

  // Dapatkan ringkasan lengkap kehadiran minggu ini (Senin - Minggu)
  Future<WeeklyAttendanceSummary> getWeeklyAttendanceSummary(String employeeId) async {
    final now = DateTime.now();
    final todayZero = DateTime(now.year, now.month, now.day);
    final startOfWeek = todayZero.subtract(Duration(days: now.weekday - 1));
    final endOfWeek = startOfWeek.add(const Duration(days: 6));

    if (employeeId.trim().isEmpty) {
      return WeeklyAttendanceSummary.empty();
    }

    final prefs = await SharedPreferences.getInstance();
    List<String> eventsList = prefs.getStringList(keyEvents) ?? [];
    List<Map<String, dynamic>> events = eventsList.map((e) => jsonDecode(e) as Map<String, dynamic>).toList();

    final Map<int, double> hoursPerDay = {
      1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 0, 7: 0,
    };
    final List<DailyAttendanceLog> dailyLogs = [];

    for (int dayIndex = 0; dayIndex < 7; dayIndex++) {
      final weekday = dayIndex + 1;
      final targetDay = startOfWeek.add(Duration(days: dayIndex));

      final dayEvents = events.where((ev) {
        if (ev['employeeId'] != employeeId) return false;
        final t = parseTimestamp(ev['timestamp']?.toString());
        if (t == null) return false;
        return t.year == targetDay.year && t.month == targetDay.month && t.day == targetDay.day;
      }).toList();

      dayEvents.sort((a, b) {
        final tA = parseTimestamp(a['timestamp']?.toString()) ?? DateTime(0);
        final tB = parseTimestamp(b['timestamp']?.toString()) ?? DateTime(0);
        return tA.compareTo(tB);
      });

      if (dayEvents.isEmpty) {
        final bool isFuture = targetDay.isAfter(todayZero);
        dailyLogs.add(DailyAttendanceLog(
          date: targetDay,
          weekday: weekday,
          hours: 0.0,
          status: isFuture ? 'Mendatang' : 'Libur / Tidak Ada Absen',
        ));
        continue;
      }

      String? firstInTime;
      String? lastOutTime;
      String? recordedAddress;
      DateTime? openClockIn;
      double workedMinutes = 0.0;

      for (var ev in dayEvents) {
        final type = ev['type'];
        final t = parseTimestamp(ev['timestamp']?.toString());
        if (t == null) continue;

        recordedAddress ??= ev['address']?.toString();

        if (type == 'Clock In') {
          firstInTime ??= ev['timestamp'];
          openClockIn = t;
        } else if (type == 'Clock Out' && openClockIn != null) {
          lastOutTime = ev['timestamp'];
          recordedAddress = ev['address']?.toString() ?? recordedAddress;
          workedMinutes += t.difference(openClockIn).inMinutes;
          openClockIn = null;
        }
      }

      bool isOngoing = false;
      bool missedClockOut = false;
      String status = 'Hadir (Selesai)';

      if (openClockIn != null) {
        final bool isToday = targetDay.year == todayZero.year &&
            targetDay.month == todayZero.month &&
            targetDay.day == todayZero.day;

        if (isToday) {
          isOngoing = true;
          final elapsed = now.difference(openClockIn).inMinutes;
          workedMinutes += elapsed > 0 ? elapsed : 0;
          status = 'Sedang Aktif';
        } else {
          missedClockOut = true;
          // Asumsi jam kerja standar 8 jam jika SPG lupa clock out saat pulang
          if (workedMinutes <= 0) {
            workedMinutes = 8 * 60.0;
          }
          status = 'Lupa Clock Out (Estimasi 8h)';
        }
      }

      final dayHours = double.parse((workedMinutes / 60.0).toStringAsFixed(1));
      hoursPerDay[weekday] = dayHours;

      dailyLogs.add(DailyAttendanceLog(
        date: targetDay,
        weekday: weekday,
        clockInTime: firstInTime,
        clockOutTime: lastOutTime,
        address: recordedAddress,
        hours: dayHours,
        status: status,
        isOngoing: isOngoing,
        missedClockOut: missedClockOut,
      ));
    }

    final totalHours = double.parse(
      hoursPerDay.values.fold(0.0, (sum, h) => sum + h).toStringAsFixed(1),
    );
    final daysPresent = dailyLogs.where((l) => l.hours > 0 || l.clockInTime != null).length;
    final avgHours = daysPresent > 0
        ? double.parse((totalHours / daysPresent).toStringAsFixed(1))
        : 0.0;

    return WeeklyAttendanceSummary(
      hoursPerDay: hoursPerDay,
      totalHours: totalHours,
      daysPresent: daysPresent,
      avgHoursPerDay: avgHours,
      startOfWeek: startOfWeek,
      endOfWeek: endOfWeek,
      dailyLogs: dailyLogs,
    );
  }

  // Get hours worked per day this week for a specific employee
  Future<Map<int, double>> getWeeklyHours(String employeeId) async {
    final summary = await getWeeklyAttendanceSummary(employeeId);
    return summary.hoursPerDay;
  }

  // Dapatkan ringkasan lengkap kehadiran bulanan (tanggal 1 s/d akhir bulan)
  Future<MonthlyAttendanceSummary> getMonthlyAttendanceSummary(
    String employeeId, {
    String? targetMonth,
  }) async {
    final now = DateTime.now();
    final todayZero = DateTime(now.year, now.month, now.day);

    int year = now.year;
    int month = now.month;
    if (targetMonth != null && targetMonth.contains('-')) {
      final parts = targetMonth.split('-');
      year = int.tryParse(parts[0]) ?? now.year;
      month = int.tryParse(parts[1]) ?? now.month;
    }
    final String periodKey = '$year-${month.toString().padLeft(2, '0')}';
    final int daysInMonth = DateTime(year, month + 1, 0).day;

    if (employeeId.trim().isEmpty) {
      return MonthlyAttendanceSummary.empty(period: periodKey);
    }

    final prefs = await SharedPreferences.getInstance();
    List<String> eventsList = prefs.getStringList(keyEvents) ?? [];
    List<Map<String, dynamic>> events = eventsList
        .map((e) => jsonDecode(e) as Map<String, dynamic>)
        .toList();

    int standardWorkingDays = 0;
    final List<DailyAttendanceLog> dailyLogs = [];

    for (int day = 1; day <= daysInMonth; day++) {
      final targetDay = DateTime(year, month, day);
      if (targetDay.weekday != DateTime.sunday) {
        standardWorkingDays++;
      }

      final dayEvents = events.where((ev) {
        if (ev['employeeId'] != employeeId) return false;
        final t = parseTimestamp(ev['timestamp']?.toString());
        if (t == null) return false;
        return t.year == year && t.month == month && t.day == day;
      }).toList();

      dayEvents.sort((a, b) {
        final tA = parseTimestamp(a['timestamp']?.toString()) ?? DateTime(0);
        final tB = parseTimestamp(b['timestamp']?.toString()) ?? DateTime(0);
        return tA.compareTo(tB);
      });

      if (dayEvents.isEmpty) {
        final bool isFuture = targetDay.isAfter(todayZero);
        final bool isSunday = targetDay.weekday == DateTime.sunday;
        dailyLogs.add(DailyAttendanceLog(
          date: targetDay,
          weekday: targetDay.weekday,
          hours: 0.0,
          status: isFuture
              ? 'Mendatang'
              : (isSunday ? 'Libur Hari Minggu' : 'Tidak Ada Absen'),
        ));
        continue;
      }

      String? firstInTime;
      String? lastOutTime;
      String? recordedAddress;
      DateTime? openClockIn;
      double workedMinutes = 0.0;

      for (var ev in dayEvents) {
        final type = ev['type'];
        final t = parseTimestamp(ev['timestamp']?.toString());
        if (t == null) continue;

        recordedAddress ??= ev['address']?.toString();

        if (type == 'Clock In') {
          firstInTime ??= ev['timestamp'];
          openClockIn = t;
        } else if (type == 'Clock Out' && openClockIn != null) {
          lastOutTime = ev['timestamp'];
          recordedAddress = ev['address']?.toString() ?? recordedAddress;
          workedMinutes += t.difference(openClockIn).inMinutes;
          openClockIn = null;
        }
      }

      bool isOngoing = false;
      bool missedClockOut = false;
      String status = 'Hadir (Selesai)';

      if (openClockIn != null) {
        final bool isToday = targetDay.year == todayZero.year &&
            targetDay.month == todayZero.month &&
            targetDay.day == todayZero.day;

        if (isToday) {
          isOngoing = true;
          final elapsed = now.difference(openClockIn).inMinutes;
          workedMinutes += elapsed > 0 ? elapsed : 0;
          status = 'Sedang Aktif';
        } else {
          missedClockOut = true;
          if (workedMinutes <= 0) {
            workedMinutes = 8 * 60.0;
          }
          status = 'Lupa Clock Out (Estimasi 8h)';
        }
      }

      final dayHours = double.parse((workedMinutes / 60.0).toStringAsFixed(1));

      dailyLogs.add(DailyAttendanceLog(
        date: targetDay,
        weekday: targetDay.weekday,
        clockInTime: firstInTime,
        clockOutTime: lastOutTime,
        address: recordedAddress,
        hours: dayHours,
        status: status,
        isOngoing: isOngoing,
        missedClockOut: missedClockOut,
      ));
    }

    final totalHours = double.parse(
      dailyLogs.fold(0.0, (sum, l) => sum + l.hours).toStringAsFixed(1),
    );
    final daysPresent = dailyLogs.where((l) => l.hours > 0 || l.clockInTime != null).length;
    final avgHours = daysPresent > 0
        ? double.parse((totalHours / daysPresent).toStringAsFixed(1))
        : 0.0;
    final attendancePct = standardWorkingDays > 0
        ? double.parse(((daysPresent / standardWorkingDays) * 100.0).clamp(0.0, 100.0).toStringAsFixed(1))
        : 0.0;

    return MonthlyAttendanceSummary(
      period: periodKey,
      year: year,
      month: month,
      totalDaysInMonth: daysInMonth,
      standardWorkingDays: standardWorkingDays > 0 ? standardWorkingDays : 26,
      totalHours: totalHours,
      daysPresent: daysPresent,
      avgHoursPerDay: avgHours,
      attendancePercentage: attendancePct,
      dailyLogs: dailyLogs,
    );
  }

  // Menggabungkan data event absensi dari server (Google Sheet) ke local cache tanpa duplikasi
  Future<void> mergeExternalAttendanceEvents(List<dynamic> rawExternalList) async {
    if (rawExternalList.isEmpty) return;

    final prefs = await SharedPreferences.getInstance();
    List<String> eventsList = prefs.getStringList(keyEvents) ?? [];
    Set<String> existingSignatures = {};

    for (var str in eventsList) {
      try {
        final map = jsonDecode(str) as Map<String, dynamic>;
        final empId = map['employeeId']?.toString().trim() ?? '';
        final normTs = normalizeTimestamp(map['timestamp']?.toString());
        final type = map['type']?.toString().trim() ?? '';
        final sig = '${empId}_${normTs}_$type';
        existingSignatures.add(sig);
      } catch (_) {}
    }

    bool addedAny = false;
    for (var raw in rawExternalList) {
      if (raw is! Map) continue;
      final map = Map<String, dynamic>.from(raw);
      final empId = map['employeeId']?.toString().trim() ?? '';
      final ts = map['timestamp']?.toString().trim() ?? '';
      final type = map['type']?.toString().trim() ?? '';
      final addr = map['address']?.toString().trim() ?? '';

      if (empId.isEmpty || ts.isEmpty || type.isEmpty) continue;
      final normTs = normalizeTimestamp(ts);
      final sig = '${empId}_${normTs}_$type';

      if (!existingSignatures.contains(sig)) {
        existingSignatures.add(sig);
        eventsList.add(jsonEncode({
          'timestamp': normTs,
          'employeeId': empId,
          'type': type,
          if (addr.isNotEmpty) 'address': addr,
        }));
        addedAny = true;
      }
    }

    if (addedAny) {
      await prefs.setStringList(keyEvents, eventsList);
    }
  }
}
