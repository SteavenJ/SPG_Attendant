import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:spg_attendant/screens/main_screen.dart';
import 'package:spg_attendant/services/api_service.dart';
import 'package:spg_attendant/services/location_service.dart';
import 'package:spg_attendant/services/storage_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  final isDarkTheme = prefs.getBool('isDarkTheme') ?? true; // Default Dark Mode
  final isIndonesian = prefs.getBool('isIndonesian') ?? false;

  runApp(MyApp(
    initialDarkTheme: isDarkTheme,
    initialIndonesian: isIndonesian,
  ));
}

class MyApp extends StatefulWidget {
  final bool initialDarkTheme;
  final bool initialIndonesian;

  const MyApp({
    super.key,
    required this.initialDarkTheme,
    required this.initialIndonesian,
  });

  static _MyAppState? of(BuildContext context) =>
      context.findAncestorStateOfType<_MyAppState>();

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  late ThemeMode _themeMode;
  late bool _isIndonesian;

  @override
  void initState() {
    super.initState();
    _themeMode = widget.initialDarkTheme ? ThemeMode.dark : ThemeMode.light;
    _isIndonesian = widget.initialIndonesian;
  }

  void toggleTheme() async {
    setState(() {
      _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDarkTheme', _themeMode == ThemeMode.dark);
  }

  void toggleLanguage() async {
    setState(() {
      _isIndonesian = !_isIndonesian;
    });
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isIndonesian', _isIndonesian);
  }

  bool get isIndonesian => _isIndonesian;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SPG Attendant',
      debugShowCheckedModeBanner: false,
      themeMode: _themeMode,
      theme: ThemeData(
        brightness: Brightness.light,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0EA5E9), // Sky Blue Accent
          brightness: Brightness.light,
        ),
        scaffoldBackgroundColor: const Color(0xFFF1F5F9), // Slate 100
        textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
        useMaterial3: true,
      ),
      darkTheme: ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF0EA5E9), // Sky Blue Accent
          brightness: Brightness.dark,
        ),
        scaffoldBackgroundColor: const Color(0xFF0F172A), // Slate 900
        textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
        useMaterial3: true,
      ),
      home: MainScreen(
        apiService: ApiService(),
        locationService: LocationService(),
        storageService: StorageService(),
      ),
    );
  }
}
