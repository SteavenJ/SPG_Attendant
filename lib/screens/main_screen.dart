import 'package:flutter/material.dart';
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
    final List<Widget> screens = [
      AttendanceScreen(
        apiService: widget.apiService,
        locationService: widget.locationService,
        storageService: widget.storageService,
      ),
      const SalesScreen(),
    ];

    return Scaffold(
      body: screens[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.access_time), label: 'Attendance'),
          BottomNavigationBarItem(icon: Icon(Icons.shopping_cart), label: 'Sales'),
        ],
      ),
    );
  }
}
