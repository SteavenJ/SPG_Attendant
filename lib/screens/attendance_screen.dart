import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:intl/intl.dart';
import 'package:spg_attendant/main.dart';
import 'package:spg_attendant/services/api_service.dart';
import 'package:spg_attendant/services/location_service.dart';
import 'package:spg_attendant/services/storage_service.dart';
import 'package:spg_attendant/widgets/attendance_graph.dart';
import 'package:ntp/ntp.dart';

class AttendanceScreen extends StatefulWidget {
  final ApiService apiService;
  final LocationService locationService;
  final StorageService storageService;

  const AttendanceScreen({
    Key? key,
    required this.apiService,
    required this.locationService,
    required this.storageService,
  }) : super(key: key);

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

  @override
  void initState() {
    super.initState();
    _syncNetworkTime();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
    _fetchLocation();
    _onEmployeeIdChanged();
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
      'Please enter an Employee ID': 'Harap masukkan ID Karyawan',
      'Attendance recorded!': 'Kehadiran dicatat!',
      'Failed to record attendance': 'Gagal mencatat kehadiran',
    };
    return dict[key] ?? key;
  }

  Future<void> _fetchLocation() async {
    final address = await widget.locationService.getCurrentAddress();
    if (mounted) {
      setState(() {
        _currentAddress = address;
      });
    }
  }

  Future<void> _onEmployeeIdChanged() async {
    final empId = _employeeIdController.text.trim();
    final state = await widget.storageService.getClockStateToday(empId);
    final hours = await widget.storageService.getWeeklyHours(empId);
    
    if (mounted) {
      setState(() {
        _clockState = state;
        _weeklyHours = hours;
      });
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
      await widget.storageService.saveEvent(_currentTime, empId, _clockState);
      await _onEmployeeIdChanged(); // Refresh state
    }

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
              const SizedBox(height: 40),
              
              if (_weeklyHours.isNotEmpty) ...[
                Text(
                  _t('Weekly Summary'),
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
                ).animate().fade(delay: 600.ms),
                const SizedBox(height: 16),
                AttendanceGraph(weeklyHours: _weeklyHours, cardColor: cardColor, textColor: textColor)
                  .animate().fade(delay: 700.ms).slideY(begin: 0.1),
              ],
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
            color: Theme.of(context).colorScheme.primary.withOpacity(0.3),
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
          BoxShadow(color: isDark ? Colors.black54 : Colors.black.withOpacity(0.03), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle),
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
              BoxShadow(color: isDark ? Colors.black54 : Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
            ],
          ),
          child: TextField(
            controller: _employeeIdController,
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
          BoxShadow(color: btnColor.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8)),
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
}
