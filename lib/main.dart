import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
// import 'screens/home_screen.dart';
// import 'screens/water_quality_screen.dart';
// import 'screens/filter_reminder_screen.dart';
// import 'screens/settings_screen.dart';
import 'screens/CombinedWaterScreen.dart';

void main() {
  runApp(const EcoFlowApp());
}

class EcoFlowApp extends StatelessWidget {
  const EcoFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'EcoFlow',
      theme: ThemeData(
        fontFamily: 'Poppins',
        primarySwatch: Colors.blue,
        scaffoldBackgroundColor: Colors.white,
      ),
      initialRoute: '/',
      routes: {
        '/': (context) => const SplashScreen(),
        // '/home': (context) => const HomeScreen(),
        // '/water-quality': (context) => const WaterQualityScreen(),
        // '/filter-reminder': (context) => const FilterReminderScreen(),
        // '/settings': (context) => const SettingsScreen(),
        '/custom': (context) => const CombinedWaterScreen(),
      },
    );
  }
}