import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
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
        '/custom': (context) => const CombinedWaterScreen(),
      },
    );
  }
}