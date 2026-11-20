import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:spg_attendant/main.dart';
import 'package:spg_attendant/services/api_service.dart';
import 'package:spg_attendant/services/location_service.dart';
import 'package:spg_attendant/services/storage_service.dart';
import 'package:spg_attendant/widgets/attendance_graph.dart';
import 'package:ntp/ntp.dart';

enum AttendanceViewMode { mingguan, bulanan }

class AttendanceScreen extends StatefulWidget {
  final ApiService apiService;
  final LocationService locationService;
  final StorageService storageService;

  const AttendanceScreen({
    super.key,
    required this.apiService,
    required this.locationService,
    required this.storageService,
  });

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  String _currentAddress = 'Fetching location...';
  String _currentTime = '';
  String _currentGreeting = 'Morning';
  final TextEditingController _employeeIdController = TextEditingController();
  Timer? _timer;
  bool _isLoading = false;
  Map<int, double> _weeklyHours = {};
  String _clockState = 'Clock In';
  Duration _timeOffset = Duration.zero;
  Map<String, String> _promotorNames = {};
  TodayAttendanceStatus _todayStatus = TodayAttendanceStatus.empty();
  WeeklyAttendanceSummary _weeklySummary = WeeklyAttendanceSummary.empty();
  MonthlyAttendanceSummary _monthlySummary = MonthlyAttendanceSummary.empty();
  bool _showWeeklyBreakdown = false;
  AttendanceViewMode _viewMode = AttendanceViewMode.mingguan;
  String _selectedMonthPeriod = DateFormat('yyyy-MM').format(DateTime.now());
  List<String> _availableMonthPeriods = [];
  String _monthlyFilterStatus = 'all'; // 'all', 'hadir', 'libur'

  @override
  void initState() {
    super.initState();
    _initMonthPeriods();
    _syncNetworkTime();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
    _fetchLocation();
    _fetchPromotors();
    _loadSavedEmployeeId();
  }

  void _initMonthPeriods() {
    final now = DateTime.now();
    final List<String> periods = [];
    for (int i = 0; i < 12; i++) {
      final d = DateTime(now.year, now.month - i, 1);
      periods.add(DateFormat('yyyy-MM').format(d));
    }
    _availableMonthPeriods = periods;
    _selectedMonthPeriod = DateFormat('yyyy-MM').format(now);
  }

  Future<void> _loadSavedEmployeeId() async {
    final savedId = await widget.storageService.getSavedEmployeeId();
    if (savedId != null && savedId.isNotEmpty && mounted) {
      _employeeIdController.text = savedId;
    }
    _onEmployeeIdChanged();
  }

  Future<void> _fetchPromotors() async {
    final names = await widget.apiService.fetchPromotorNames();
    if (mounted) {
      setState(() {
        _promotorNames = names;
      });
    }
  }

  Future<void> _syncNetworkTime() async {
    try {
      DateTime deviceTime = DateTime.now();
      DateTime networkTime = await NTP.now();
      if (mounted) {
        setState(() {
          _timeOffset = networkTime.difference(deviceTime);
        });
      }
    } catch (e) {
      // Fallback to device time if network fails
    }
  }

  void _updateTime() {
    DateTime now = DateTime.now().add(_timeOffset);
    if (mounted) {
      setState(() {
        _currentTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(now);
        
        if (now.hour < 12) {
          _currentGreeting = 'Morning';
        } else if (now.hour < 17) {
          _currentGreeting = 'Afternoon';
        } else {
          _currentGreeting = 'Evening';
        }
      });
    }
  }

  String _t(String key) {
    if (!mounted) return key;
    final myApp = MyApp.of(context);
    bool isIndo = myApp?.isIndonesian ?? false;
    if (!isIndo) return key;

    const dict = {
      'Good Morning,': 'Selamat Pagi,',
      'Good Afternoon,': 'Selamat Siang,',
      'Good Evening,': 'Selamat Malam,',
      'SPG Attendant': 'Absensi SPG',
      'Fetching location...': 'Mengambil lokasi...',
      'Employee ID': 'ID Karyawan',
      'Enter your ID': 'Masukkan ID',
      'Clock In': 'Masuk',
      'Clock Out': 'Keluar',
      'Weekly Summary': 'Ringkasan Mingguan',
      'Monthly Summary': 'Rekap Bulanan',
      'Weekly View': 'Mingguan',
      'Monthly View': 'Bulanan',
      'Monthly Attendance Summary': 'Rekap Kehadiran Bulanan',
      'Total Monthly Hours': 'Total Jam Bulan Ini',
      'Attendance Rate': 'Tingkat Kehadiran',
      'Working Days': 'Hari Kerja',
      'All Days': 'Semua Hari',
      'Attended Days': 'Hadir',
      'Days Off / Absent': 'Libur / Tidak Hadir',
      'Select Month': 'Pilih Bulan',
      'Monthly Working Target': 'Pencapaian Hari Kerja Bulan Ini',
      'No data for this filter.': 'Tidak ada data untuk filter ini.',
      'Please enter an Employee ID': 'Harap masukkan ID Karyawan',
      'Attendance recorded!': 'Kehadiran dicatat!',
      'Failed to record attendance': 'Gagal mencatat kehadiran',
      'Today\'s Attendance Status': 'Status Kehadiran Hari Ini',
      'Currently Working': 'Sedang Aktif Bekerja',
      'Shift Completed': 'Shift Selesai',
      'Not Clocked In Yet': 'Belum Absen Masuk',
      'Clock In Time': 'Jam Masuk',
      'Clock Out Time': 'Jam Pulang',
      'Work Duration Today': 'Durasi Hari Ini',
      'Location': 'Lokasi',
      'Total Weekly Hours': 'Total Jam Minggu Ini',
      'Days Present': 'Hari Masuk',
      'Daily Average': 'Rata-rata Harian',
      'Show Daily Details': 'Lihat Rincian Harian',
      'Hide Daily Details': 'Tutup Rincian Harian',
      'Today': 'Hari Ini',
      'Standard 8 Hours': 'Standar 8 Jam',
      'Active': 'Aktif',
      'Off / No Attendance': 'Libur / Tidak Hadir',
      'Missed Clock Out': 'Lupa Clock Out',
      'Hours': 'Jam',
      'Hours/Day': 'Jam/Hari',
      'Days': 'Hari',
    };
    return dict[key] ?? key;
  }

  String _formatMonthLabel(String period, bool isIndo) {
    try {
      final parts = period.split('-');
      if (parts.length == 2) {
        final y = int.parse(parts[0]);
        final m = int.parse(parts[1]);
        if (isIndo) {
          const mNames = ['', 'Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni', 'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
          return '${mNames[m]} $y';
        } else {
          const mNames = ['', 'January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
          return '${mNames[m]} $y';
        }
      }
    } catch (_) {}
    return period;
  }

  String _formatTimeSnippet(String? rawTs) {
    if (rawTs == null || rawTs.isEmpty) return '-';
    final dt = StorageService.parseTimestamp(rawTs);
    if (dt != null) {
      final h = dt.hour.toString().padLeft(2, '0');
      final m = dt.minute.toString().padLeft(2, '0');
      return '$h:$m';
    }
    return rawTs;
  }

  Future<void> _fetchLocation() async {
    final address = await widget.locationService.getCurrentAddress();
    if (mounted) {
      setState(() {
        _currentAddress = address;
      });
    }
  }

  Future<void> _onEmployeeIdChanged({bool reloadServer = true}) async {
    final empId = _employeeIdController.text.trim();
    if (empId.isNotEmpty) {
      await widget.storageService.setSavedEmployeeId(empId);
    }
    final todayStatus = await widget.storageService.getTodayAttendanceStatus(empId);
    final weeklySummary = await widget.storageService.getWeeklyAttendanceSummary(empId);
    final monthlySummary = await widget.storageService.getMonthlyAttendanceSummary(
      empId,
      targetMonth: _selectedMonthPeriod,
    );
    
    if (mounted) {
      setState(() {
        _clockState = todayStatus.nextState;
        _todayStatus = todayStatus;
        _weeklySummary = weeklySummary;
        _weeklyHours = weeklySummary.hoursPerDay;
        _monthlySummary = monthlySummary;
      });
    }

    if (reloadServer && empId.isNotEmpty) {
      _fetchServerAttendanceHistory(empId);
    }
  }

  Future<void> _fetchServerAttendanceHistory(String empId) async {
    try {
      final serverData = await widget.apiService.fetchAttendanceHistory(
        employeeId: empId,
        periode: _selectedMonthPeriod,
      );
      if (serverData != null && serverData['status'] == 'success' && serverData['data'] is List) {
        await widget.storageService.mergeExternalAttendanceEvents(serverData['data'] as List<dynamic>);
        final updatedWeekly = await widget.storageService.getWeeklyAttendanceSummary(empId);
        final updatedMonthly = await widget.storageService.getMonthlyAttendanceSummary(
          empId,
          targetMonth: _selectedMonthPeriod,
        );
        if (mounted) {
          setState(() {
            _weeklySummary = updatedWeekly;
            _weeklyHours = updatedWeekly.hoursPerDay;
            _monthlySummary = updatedMonthly;
          });
        }
      }
    } catch (_) {}
  }

  void _onMonthPeriodChanged(String newPeriod) async {
    setState(() {
      _selectedMonthPeriod = newPeriod;
    });
    final empId = _employeeIdController.text.trim();
    final summary = await widget.storageService.getMonthlyAttendanceSummary(
      empId,
      targetMonth: newPeriod,
    );
    if (mounted) {
      setState(() {
        _monthlySummary = summary;
      });
    }
    if (empId.isNotEmpty) {
      _fetchServerAttendanceHistory(empId);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _employeeIdController.dispose();
    super.dispose();
  }

  Future<void> _handleClock() async {
    final empId = _employeeIdController.text.trim();
    if (empId.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_t('Please enter an Employee ID'))),
      );
      return;
    }

    if (_promotorNames.isNotEmpty && !_promotorNames.containsKey(empId)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('ID Tidak Ditemukan!')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await widget.apiService.recordAttendance(
      timestamp: _currentTime,
      employeeId: empId,
      type: _clockState,
      address: _currentAddress,
    );

    if (success) {
      await widget.storageService.saveEvent(
        _currentTime,
        empId,
        _clockState,
        address: _currentAddress,
      );
      await _onEmployeeIdChanged(); // Refresh state
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });

      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('Attendance recorded!'))),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(_t('Failed to record attendance'))),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    Color textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    Color subTextColor = isDark ? Colors.grey.shade400 : Colors.grey.shade600;

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 20.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header Toggle Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _t('Good $_currentGreeting,'),
                    style: TextStyle(fontSize: 16, color: subTextColor),
                  ).animate().fade().slideY(begin: 0.2),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => MyApp.of(context)?.toggleLanguage(),
                        child: Text(
                          MyApp.of(context)?.isIndonesian == true ? 'IND' : 'ENG', 
                          style: TextStyle(fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)
                        ),
                      ),
                      IconButton(
                        icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: textColor),
                        onPressed: () => MyApp.of(context)?.toggleTheme(),
                      ),
                    ],
                  ).animate().fade(),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                _t('SPG Attendant'),
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
              ).animate().fade().slideY(begin: 0.2, delay: 100.ms),
              const SizedBox(height: 32),
              
              _buildClockCard().animate().fade(delay: 200.ms).scale(begin: const Offset(0.95, 0.95)),
              const SizedBox(height: 24),
              
              _buildLocationCard(cardColor, textColor, subTextColor).animate().fade(delay: 300.ms).slideY(begin: 0.1),
              const SizedBox(height: 32),
              
              _buildInputField(cardColor, textColor, subTextColor).animate().fade(delay: 400.ms).slideY(begin: 0.1),
              const SizedBox(height: 32),
              
              _buildActionButton().animate().fade(delay: 500.ms).scale(begin: const Offset(0.9, 0.9)),
              const SizedBox(height: 24),
              
              _buildTodayShiftCard(cardColor, textColor, subTextColor).animate().fade(delay: 550.ms).slideY(begin: 0.1),
              const SizedBox(height: 28),

              // Segmented Toggle: Mingguan vs Bulanan
              _buildViewModeToggle(cardColor, textColor, subTextColor).animate().fade(delay: 580.ms),
              const SizedBox(height: 20),

              if (_viewMode == AttendanceViewMode.mingguan)
                _buildWeeklySummarySection(cardColor, textColor, subTextColor).animate().fade(delay: 600.ms).slideY(begin: 0.1)
              else
                _buildMonthlySummarySection(cardColor, textColor, subTextColor).animate().fade(delay: 600.ms).slideY(begin: 0.1),
              
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildClockCard() {
    String dateStr = _currentTime.isNotEmpty ? _currentTime.split(' ')[0] : '';
    String timeStr = _currentTime.isNotEmpty ? _currentTime.split(' ')[1] : '';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        children: [
          const Icon(Icons.access_time, color: Colors.white70, size: 28),
          const SizedBox(height: 8),
          Text(
            timeStr,
            style: const TextStyle(fontSize: 48, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 2),
          ),
          Text(
            dateStr,
            style: const TextStyle(fontSize: 16, color: Colors.white70),
          ),
        ],
      ),
    );
  }

  Widget _buildLocationCard(Color cardColor, Color textColor, Color subTextColor) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: isDark ? Colors.black54 : Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
            child: const Icon(Icons.location_on, color: Colors.redAccent),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _currentAddress == 'Fetching location...' ? _t('Fetching location...') : _currentAddress,
              style: TextStyle(fontSize: 14, color: subTextColor, height: 1.5),
            ),
          ),
          IconButton(
            icon: Icon(Icons.refresh, color: Theme.of(context).colorScheme.primary),
            onPressed: _fetchLocation,
          )
        ],
      ),
    );
  }

  Widget _buildInputField(Color cardColor, Color textColor, Color subTextColor) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    
    String empId = _employeeIdController.text.trim();
    String? promotorName = empId.isEmpty ? null : _promotorNames[empId];
    bool isInvalid = empId.isNotEmpty && promotorName == null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(_t('Employee ID'), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: subTextColor)),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(color: isDark ? Colors.black54 : Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: TextField(
            controller: _employeeIdController,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) => _onEmployeeIdChanged(),
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
            decoration: InputDecoration(
              hintText: _t('Enter your ID'),
              hintStyle: TextStyle(color: Colors.grey.shade500),
              prefixIcon: Icon(Icons.badge, color: Theme.of(context).colorScheme.primary),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
              filled: true,
              fillColor: cardColor,
              contentPadding: const EdgeInsets.symmetric(vertical: 20),
            ),
          ),
        ),
        if (empId.isNotEmpty && _promotorNames.isNotEmpty) ...[
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              isInvalid ? "ID Tidak Ditemukan!" : promotorName!,
              style: TextStyle(
                color: isInvalid ? Colors.red : (isDark ? Colors.greenAccent : Colors.green.shade700),
                fontWeight: FontWeight.bold,
                fontSize: 15,
              ),
            ),
          ),
        ]
      ],
    );
  }

  Widget _buildActionButton() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    bool isClockIn = _clockState == 'Clock In';
    Color btnColor = isClockIn ? const Color(0xFF10B981) : const Color(0xFFEF4444); // Emerald or Red

    return Container(
      width: double.infinity,
      height: 64,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: btnColor.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, 8)),
        ],
      ),
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: btnColor,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          elevation: 0,
        ),
        onPressed: _handleClock,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(isClockIn ? Icons.login : Icons.logout, color: Colors.white),
            const SizedBox(width: 12),
            Text(
              _t(_clockState).toUpperCase(),
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white, letterSpacing: 1.5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTodayShiftCard(Color cardColor, Color textColor, Color subTextColor) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final empId = _employeeIdController.text.trim();

    if (empId.isEmpty) {
      return const SizedBox.shrink();
    }

    final bool isOngoing = _todayStatus.isOngoing;
    final bool hasClockedOut = _todayStatus.hasClockedOut;
    final bool hasClockedIn = _todayStatus.hasClockedIn;

    Color badgeBg;
    Color badgeFg;
    Color borderColor;
    String statusLabel;
    IconData statusIcon;

    if (isOngoing) {
      badgeFg = const Color(0xFF10B981);
      badgeBg = badgeFg.withValues(alpha: isDark ? 0.2 : 0.12);
      borderColor = badgeFg.withValues(alpha: 0.4);
      statusLabel = _t('Currently Working');
      statusIcon = Icons.radio_button_checked_rounded;
    } else if (hasClockedOut) {
      badgeFg = const Color(0xFF3B82F6);
      badgeBg = badgeFg.withValues(alpha: isDark ? 0.2 : 0.12);
      borderColor = badgeFg.withValues(alpha: 0.4);
      statusLabel = _t('Shift Completed');
      statusIcon = Icons.check_circle_outline_rounded;
    } else if (hasClockedIn) {
      badgeFg = const Color(0xFFF59E0B);
      badgeBg = badgeFg.withValues(alpha: isDark ? 0.2 : 0.12);
      borderColor = badgeFg.withValues(alpha: 0.4);
      statusLabel = _t('Clock In');
      statusIcon = Icons.login_rounded;
    } else {
      badgeFg = Colors.grey;
      badgeBg = badgeFg.withValues(alpha: isDark ? 0.15 : 0.1);
      borderColor = isDark ? Colors.white12 : Colors.grey.shade300;
      statusLabel = _t('Not Clocked In Yet');
      statusIcon = Icons.access_time_rounded;
    }

    String durationText = '-';
    if (_todayStatus.todayHours > 0) {
      final totalMins = (_todayStatus.todayHours * 60).round();
      final h = totalMins ~/ 60;
      final m = totalMins % 60;
      durationText = h > 0 ? '$h Jam $m Mnt' : '$m Menit';
      if (isOngoing) {
        durationText = '$durationText (${_t('Active')})';
      }
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOngoing
              ? const Color(0xFF10B981).withValues(alpha: 0.35)
              : (isDark ? Colors.white12 : Colors.grey.shade200),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black54 : Colors.black.withValues(alpha: 0.02),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.badge_outlined,
                    size: 20,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _t('Today\'s Attendance Status'),
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: badgeBg,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: borderColor, width: 1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(statusIcon, size: 13, color: badgeFg),
                    const SizedBox(width: 5),
                    Text(
                      statusLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: badgeFg,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (!hasClockedIn)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: Colors.blueAccent, size: 20),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Tekan tombol MASUK di atas saat Anda tiba di toko untuk mencatat kehadiran hari ini.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: subTextColor,
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            )
          else ...[
            Row(
              children: [
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.login_rounded, size: 14, color: Color(0xFF10B981)),
                            const SizedBox(width: 6),
                            Text(
                              _t('Clock In Time'),
                              style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          _formatTimeSnippet(_todayStatus.firstClockInTime),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.logout_rounded,
                              size: 14,
                              color: isOngoing ? const Color(0xFFF59E0B) : const Color(0xFF3B82F6),
                            ),
                            const SizedBox(width: 6),
                            Text(
                              _t('Clock Out Time'),
                              style: TextStyle(fontSize: 11, color: subTextColor, fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          isOngoing ? _t('Active') : _formatTimeSnippet(_todayStatus.lastClockOutTime),
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.bold,
                            color: isOngoing ? const Color(0xFFF59E0B) : textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: isDark ? 0.14 : 0.06),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFF3B82F6).withValues(alpha: 0.25)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timer_outlined, size: 16, color: Color(0xFF2563EB)),
                      const SizedBox(width: 8),
                      Text(
                        _t('Work Duration Today'),
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: textColor,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    durationText,
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2563EB),
                    ),
                  ),
                ],
              ),
            ),
            if (_todayStatus.clockInAddress != null && _todayStatus.clockInAddress!.isNotEmpty) ...[
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.location_on_outlined, size: 15, color: Colors.redAccent),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      _todayStatus.clockInAddress!,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: subTextColor,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildMetricMiniCard({
    required Color cardColor,
    required Color textColor,
    required Color subTextColor,
    required IconData icon,
    required Color accentColor,
    required String title,
    required String value,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.grey.shade200,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black45 : Colors.black.withValues(alpha: 0.02),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: accentColor),
          const SizedBox(height: 6),
          Text(
            title,
            style: TextStyle(fontSize: 10.5, color: subTextColor, fontWeight: FontWeight.w600),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: FontWeight.w800,
              color: textColor,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildDailyLogCard({
    required DailyAttendanceLog log,
    required Color cardColor,
    required Color textColor,
    required Color subTextColor,
    required bool isDark,
    required bool isIndo,
  }) {
    final now = DateTime.now();
    final bool isToday = log.date.year == now.year &&
        log.date.month == now.month &&
        log.date.day == now.day;

    String dayName;
    if (isIndo) {
      const days = ['', 'Senin', 'Selasa', 'Rabu', 'Kamis', 'Jumat', 'Sabtu', 'Minggu'];
      dayName = days[log.weekday];
    } else {
      const days = ['', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'];
      dayName = days[log.weekday];
    }

    final dateStr = DateFormat('d MMM').format(log.date);

    Color badgeColor;
    Color badgeBg;
    if (log.isOngoing) {
      badgeColor = const Color(0xFF10B981);
      badgeBg = badgeColor.withValues(alpha: isDark ? 0.2 : 0.12);
    } else if (log.hours > 0 && !log.missedClockOut) {
      badgeColor = const Color(0xFF2563EB);
      badgeBg = badgeColor.withValues(alpha: isDark ? 0.2 : 0.12);
    } else if (log.missedClockOut) {
      badgeColor = const Color(0xFFF59E0B);
      badgeBg = badgeColor.withValues(alpha: isDark ? 0.2 : 0.12);
    } else {
      badgeColor = Colors.grey;
      badgeBg = badgeColor.withValues(alpha: isDark ? 0.15 : 0.08);
    }

    String timeSnippet = '-';
    if (log.clockInTime != null) {
      final inShort = _formatTimeSnippet(log.clockInTime);
      if (log.clockOutTime != null) {
        final outShort = _formatTimeSnippet(log.clockOutTime);
        timeSnippet = '$inShort - $outShort';
      } else if (log.isOngoing) {
        timeSnippet = '$inShort - ${_t('Active')}';
      } else {
        timeSnippet = '$inShort - (${_t('Missed Clock Out')})';
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isToday
              ? const Color(0xFF10B981).withValues(alpha: 0.4)
              : (isDark ? Colors.white10 : Colors.grey.shade200),
          width: isToday ? 1.4 : 1.0,
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        '$dayName, $dateStr',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: textColor,
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: const Color(0xFF10B981).withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            _t('Today'),
                            style: const TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF10B981),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    timeSnippet,
                    style: TextStyle(fontSize: 11.5, color: subTextColor),
                  ),
                ],
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: badgeBg,
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: badgeColor.withValues(alpha: 0.3)),
            ),
            child: Text(
              log.hours > 0 ? '${log.hours} ${_t('Hours')}' : (log.status == 'Mendatang' ? '-' : _t('Off / No Attendance')),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: badgeColor,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWeeklySummarySection(Color cardColor, Color textColor, Color subTextColor) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isIndo = MyApp.of(context)?.isIndonesian ?? false;

    final startStr = DateFormat('d MMM').format(_weeklySummary.startOfWeek);
    final endStr = DateFormat('d MMM').format(_weeklySummary.endOfWeek);
    final rangeText = '$startStr - $endStr';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  Icons.insights_rounded,
                  size: 22,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  _t('Weekly Summary'),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                ),
              ],
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: isDark ? Colors.white10 : Colors.grey.shade200,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                rangeText,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.grey.shade300 : Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 3 METRICS MINI CARDS
        Row(
          children: [
            Expanded(
              child: _buildMetricMiniCard(
                cardColor: cardColor,
                textColor: textColor,
                subTextColor: subTextColor,
                icon: Icons.timer_outlined,
                accentColor: const Color(0xFF2563EB),
                title: _t('Total Weekly Hours'),
                value: '${_weeklySummary.totalHours} ${_t('Hours')}',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricMiniCard(
                cardColor: cardColor,
                textColor: textColor,
                subTextColor: subTextColor,
                icon: Icons.event_available_outlined,
                accentColor: const Color(0xFF10B981),
                title: _t('Days Present'),
                value: '${_weeklySummary.daysPresent} ${_t('Days')}',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _buildMetricMiniCard(
                cardColor: cardColor,
                textColor: textColor,
                subTextColor: subTextColor,
                icon: Icons.speed_outlined,
                accentColor: const Color(0xFFF59E0B),
                title: _t('Daily Average'),
                value: '${_weeklySummary.avgHoursPerDay}h',
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // BAR CHART
        AttendanceGraph(
          weeklyHours: _weeklyHours,
          cardColor: cardColor,
          textColor: textColor,
          todayWeekday: DateTime.now().weekday,
          isIndonesian: isIndo,
        ),
        const SizedBox(height: 10),

        // LEGEND ROW
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: const Color(0xFF10B981),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _t('Today'),
                    style: TextStyle(fontSize: 11, color: subTextColor),
                  ),
                  const SizedBox(width: 14),
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    _t('Active'),
                    style: TextStyle(fontSize: 11, color: subTextColor),
                  ),
                ],
              ),
              Row(
                children: [
                  Text(
                    '--- ${_t('Standard 8 Hours')}',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.blue.shade300 : const Color(0xFF2563EB),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),

        // TOGGLE BUTTON RINCIAN HARIAN
        Center(
          child: TextButton.icon(
            onPressed: () {
              setState(() {
                _showWeeklyBreakdown = !_showWeeklyBreakdown;
              });
            },
            icon: Icon(
              _showWeeklyBreakdown
                  ? Icons.keyboard_arrow_up_rounded
                  : Icons.keyboard_arrow_down_rounded,
              color: Theme.of(context).colorScheme.primary,
            ),
            label: Text(
              _showWeeklyBreakdown
                  ? _t('Hide Daily Details')
                  : _t('Show Daily Details'),
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ),

        // LIST RINCIAN HARIAN (EXPANDED)
        if (_showWeeklyBreakdown) ...[
          const SizedBox(height: 8),
          ..._weeklySummary.dailyLogs.map((log) => _buildDailyLogCard(
                log: log,
                cardColor: cardColor,
                textColor: textColor,
                subTextColor: subTextColor,
                isDark: isDark,
                isIndo: isIndo,
              )),
        ],
      ],
    );
  }

  Widget _buildViewModeToggle(Color cardColor, Color textColor, Color subTextColor) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF0F172A) : Colors.grey.shade200,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_viewMode != AttendanceViewMode.mingguan) {
                  setState(() {
                    _viewMode = AttendanceViewMode.mingguan;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _viewMode == AttendanceViewMode.mingguan
                      ? cardColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: _viewMode == AttendanceViewMode.mingguan
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.view_week_rounded,
                      size: 16,
                      color: _viewMode == AttendanceViewMode.mingguan
                          ? primaryColor
                          : subTextColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _t('Weekly View'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _viewMode == AttendanceViewMode.mingguan
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: _viewMode == AttendanceViewMode.mingguan
                            ? textColor
                            : subTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () {
                if (_viewMode != AttendanceViewMode.bulanan) {
                  setState(() {
                    _viewMode = AttendanceViewMode.bulanan;
                  });
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: _viewMode == AttendanceViewMode.bulanan
                      ? cardColor
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(11),
                  boxShadow: _viewMode == AttendanceViewMode.bulanan
                      ? [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.06),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.calendar_month_rounded,
                      size: 16,
                      color: _viewMode == AttendanceViewMode.bulanan
                          ? primaryColor
                          : subTextColor,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _t('Monthly View'),
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: _viewMode == AttendanceViewMode.bulanan
                            ? FontWeight.bold
                            : FontWeight.w600,
                        color: _viewMode == AttendanceViewMode.bulanan
                            ? textColor
                            : subTextColor,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonthlyFilterChip({
    required String label,
    required String filterKey,
    required bool isDark,
  }) {
    final bool isSelected = _monthlyFilterStatus == filterKey;
    final primaryColor = Theme.of(context).colorScheme.primary;

    return GestureDetector(
      onTap: () {
        setState(() {
          _monthlyFilterStatus = filterKey;
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: isSelected
              ? primaryColor.withValues(alpha: isDark ? 0.25 : 0.15)
              : (isDark ? const Color(0xFF0F172A) : Colors.grey.shade100),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected
                ? primaryColor
                : (isDark ? Colors.white10 : Colors.grey.shade300),
            width: isSelected ? 1.4 : 1.0,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11.5,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
            color: isSelected
                ? primaryColor
                : (isDark ? Colors.grey.shade300 : Colors.grey.shade700),
          ),
        ),
      ),
    );
  }

  Widget _buildMonthlySummarySection(Color cardColor, Color textColor, Color subTextColor) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    bool isIndo = MyApp.of(context)?.isIndonesian ?? false;

    List<DailyAttendanceLog> filteredLogs = _monthlySummary.dailyLogs;
    if (_monthlyFilterStatus == 'hadir') {
      filteredLogs = filteredLogs.where((l) => l.hours > 0 || l.clockInTime != null).toList();
    } else if (_monthlyFilterStatus == 'libur') {
      filteredLogs = filteredLogs.where((l) => l.hours == 0 && l.clockInTime == null).toList();
    }
    // Tampilkan hari terbaru di posisi teratas
    final displayLogs = filteredLogs.reversed.toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header & Month Selector
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Row(
                children: [
                  Icon(
                    Icons.calendar_month_rounded,
                    size: 22,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      _t('Monthly Summary'),
                      style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _selectedMonthPeriod,
                  icon: const Icon(Icons.arrow_drop_down, size: 20),
                  style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.bold, color: textColor),
                  dropdownColor: cardColor,
                  onChanged: (val) {
                    if (val != null) _onMonthPeriodChanged(val);
                  },
                  items: _availableMonthPeriods.map((period) {
                    return DropdownMenuItem<String>(
                      value: period,
                      child: Text(_formatMonthLabel(period, isIndo)),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // 4 METRIKS MINI CARDS (2x2)
        Row(
          children: [
            Expanded(
              child: _buildMetricMiniCard(
                cardColor: cardColor,
                textColor: textColor,
                subTextColor: subTextColor,
                icon: Icons.timer_outlined,
                accentColor: const Color(0xFF2563EB),
                title: _t('Total Monthly Hours'),
                value: '${_monthlySummary.totalHours} ${_t('Hours')}',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricMiniCard(
                cardColor: cardColor,
                textColor: textColor,
                subTextColor: subTextColor,
                icon: Icons.event_available_outlined,
                accentColor: const Color(0xFF10B981),
                title: _t('Days Present'),
                value: '${_monthlySummary.daysPresent} / ${_monthlySummary.standardWorkingDays} ${_t('Days')}',
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: _buildMetricMiniCard(
                cardColor: cardColor,
                textColor: textColor,
                subTextColor: subTextColor,
                icon: Icons.pie_chart_outline_rounded,
                accentColor: const Color(0xFFF59E0B),
                title: _t('Attendance Rate'),
                value: '${_monthlySummary.attendancePercentage}%',
                isDark: isDark,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: _buildMetricMiniCard(
                cardColor: cardColor,
                textColor: textColor,
                subTextColor: subTextColor,
                icon: Icons.speed_outlined,
                accentColor: const Color(0xFF8B5CF6),
                title: _t('Daily Average'),
                value: '${_monthlySummary.avgHoursPerDay}h',
                isDark: isDark,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),

        // TARGET HARI KERJA PROGRESS BAR
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    _t('Monthly Working Target'),
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: subTextColor),
                  ),
                  Text(
                    '${_monthlySummary.daysPresent} / ${_monthlySummary.standardWorkingDays} ${_t('Days')}',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: (_monthlySummary.daysPresent / (_monthlySummary.standardWorkingDays > 0 ? _monthlySummary.standardWorkingDays : 1)).clamp(0.0, 1.0),
                  minHeight: 7,
                  backgroundColor: isDark ? const Color(0xFF334155) : Colors.grey.shade200,
                  valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFF10B981)),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),

        // FILTER CHIPS ROW
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: [
              _buildMonthlyFilterChip(
                label: '${_t('All Days')} (${_monthlySummary.totalDaysInMonth})',
                filterKey: 'all',
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildMonthlyFilterChip(
                label: '${_t('Attended Days')} (${_monthlySummary.daysPresent})',
                filterKey: 'hadir',
                isDark: isDark,
              ),
              const SizedBox(width: 8),
              _buildMonthlyFilterChip(
                label: '${_t('Days Off / Absent')} (${_monthlySummary.totalDaysInMonth - _monthlySummary.daysPresent})',
                filterKey: 'libur',
                isDark: isDark,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // DAFTAR LOG HARIAN BULANAN
        if (displayLogs.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
            ),
            child: Center(
              child: Text(
                _t('No data for this filter.'),
                style: TextStyle(fontSize: 13, color: subTextColor),
              ),
            ),
          )
        else
          ...displayLogs.map((log) => _buildDailyLogCard(
                log: log,
                cardColor: cardColor,
                textColor: textColor,
                subTextColor: subTextColor,
                isDark: isDark,
                isIndo: isIndo,
              )),
      ],
    );
  }
}
