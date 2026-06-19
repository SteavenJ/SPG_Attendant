import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:spg_attendant/services/api_service.dart';
import 'package:spg_attendant/services/location_service.dart';
import 'package:spg_attendant/services/storage_service.dart';
import 'package:spg_attendant/widgets/attendance_graph.dart';

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
  final TextEditingController _employeeIdController = TextEditingController();
  Timer? _timer;
  bool _isLoading = false;
  Map<int, double> _weeklyHours = {};

  @override
  void initState() {
    super.initState();
    _updateTime();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _updateTime();
    });
    _fetchLocation();
    _loadGraphData();
  }

  void _updateTime() {
    setState(() {
      _currentTime = DateFormat('yyyy-MM-dd HH:mm:ss').format(DateTime.now());
    });
  }

  Future<void> _fetchLocation() async {
    final address = await widget.locationService.getCurrentAddress();
    setState(() {
      _currentAddress = address;
    });
  }

  Future<void> _loadGraphData() async {
    final hours = await widget.storageService.getWeeklyHours();
    setState(() {
      _weeklyHours = hours;
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _employeeIdController.dispose();
    super.dispose();
  }

  Future<void> _handleClock(String type) async {
    if (_employeeIdController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter an Employee ID')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final success = await widget.apiService.recordAttendance(
      timestamp: _currentTime,
      employeeId: _employeeIdController.text.trim(),
      type: type,
      address: _currentAddress,
    );

    if (success) {
      await widget.storageService.saveEvent(_currentTime, type);
      await _loadGraphData();
    }

    setState(() {
      _isLoading = false;
    });

    if (success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Attendance recorded!')),
      );
      _employeeIdController.clear();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to record attendance')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SPG Attendance'),
        backgroundColor: Colors.blueAccent,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text('Current Time', style: TextStyle(color: Colors.grey)),
                      const SizedBox(height: 8),
                      Text(
                        _currentTime,
                        style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Card(
                elevation: 4,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Icon(Icons.location_on, color: Colors.red, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        _currentAddress,
                        textAlign: TextAlign.center,
                        style: const TextStyle(fontSize: 16),
                      ),
                      TextButton(
                        onPressed: _fetchLocation,
                        child: const Text('Refresh Location'),
                      )
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _employeeIdController,
                decoration: const InputDecoration(
                  labelText: 'Employee ID',
                  border: OutlineInputBorder(),
                  prefixIcon: Icon(Icons.badge),
                ),
              ),
              const SizedBox(height: 16),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => _handleClock('Clock In'),
                        child: const Text('Clock In', style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          padding: const EdgeInsets.symmetric(vertical: 16),
                        ),
                        onPressed: () => _handleClock('Clock Out'),
                        child: const Text('Clock Out', style: TextStyle(fontSize: 18, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 24),
              if (_weeklyHours.isNotEmpty) AttendanceGraph(weeklyHours: _weeklyHours),
            ],
          ),
        ),
      ),
    );
  }
}
