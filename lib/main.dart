import 'package:flutter/material.dart';
import 'package:spg_attendant/screens/attendance_screen.dart';
import 'package:spg_attendant/services/api_service.dart';
import 'package:spg_attendant/services/location_service.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SPG Attendant',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.blueAccent),
        useMaterial3: true,
      ),
      home: AttendanceScreen(
        apiService: ApiService(),
        locationService: LocationService(),
      ),
    );
  }
}
