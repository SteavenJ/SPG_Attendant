import 'package:flutter/material.dart';
import 'package:spg_attendant/main.dart';
import 'package:spg_attendant/screens/attendance_screen.dart';
import 'package:spg_attendant/screens/sales_screen.dart';
import 'package:spg_attendant/services/api_service.dart';
import 'package:spg_attendant/services/location_service.dart';
import 'package:spg_attendant/services/storage_service.dart';

class MainScreen extends StatefulWidget {
  final ApiService apiService;
  final LocationService locationService;
  final StorageService storageService;

  const MainScreen({
    Key? key,
    required this.apiService,
    required this.locationService,
    required this.storageService,
  }) : super(key: key);

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _currentIndex = 0;

  @override
  Widget build(BuildContext context) {
    final myApp = MyApp.of(context);
    final isIndo = myApp?.isIndonesian ?? false;
    final String attendanceLabel = isIndo ? 'Kehadiran' : 'Attendance';
    final String salesLabel = isIndo ? 'Penjualan' : 'Sales';

    final List<Widget> screens = [
      AttendanceScreen(
        apiService: widget.apiService,
        locationService: widget.locationService,
        storageService: widget.storageService,
      ),
      const SalesScreen(),
    ];

    bool isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black54 : Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          child: BottomNavigationBar(
            backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
            elevation: 0,
            selectedItemColor: Theme.of(context).colorScheme.primary,
            unselectedItemColor: isDark ? Colors.grey.shade600 : Colors.grey.shade400,
            currentIndex: _currentIndex,
            onTap: (index) {
              setState(() {
                _currentIndex = index;
              });
            },
            items: [
              BottomNavigationBarItem(icon: const Icon(Icons.access_time_filled), label: attendanceLabel),
              BottomNavigationBarItem(icon: const Icon(Icons.shopping_cart), label: salesLabel),
            ],
          ),
        ),
      ),
    );
  }
}
