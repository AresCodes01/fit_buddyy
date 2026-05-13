import 'package:flutter/material.dart';

class FitBuddyTheme {
  static const primaryColor = Color(0xFF00BFA5);
  
  static ThemeData buildTheme(Brightness brightness) {
    return ThemeData(
      useMaterial3: true,
      brightness: brightness,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        brightness: brightness,
        primary: primaryColor,
      ),
      scaffoldBackgroundColor: brightness == Brightness.light 
          ? const Color(0xFFF0FDF4) 
          : const Color(0xFF0A1210),
      appBarTheme: const AppBarTheme(
        centerTitle: true,
      ),
    );
  }
}
