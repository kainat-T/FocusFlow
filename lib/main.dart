//import 'dart:async';
import 'package:flutter/material.dart';
//import 'package:google_fonts/google_fonts.dart';
import 'screens/home_screen.dart';
//import 'screens/login_screen.dart';
//import 'screens/register_screen.dart';


void main() => runApp(const FocusFlowApp());


class FocusFlowApp extends StatelessWidget {
  const FocusFlowApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FocusFlow',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: FFColors.ink,
        colorScheme: ColorScheme.fromSeed(
          seedColor: FFColors.brass,
          brightness: Brightness.dark,
          surface: FFColors.surface,
        ),
      ),
      home: const HomeScreen(),
    );
  }
}


class FFColors {
  static const ink = Color(0xFF13171F);
  static const surface = Color(0xFF1C2230);
  static const brass = Color(0xFFD4A24C);
  static const sage = Color(0xFF74957C);
  static const parchment = Color(0xFFEDE7DA);
  static const slate = Color(0xFF8B93A6);
}