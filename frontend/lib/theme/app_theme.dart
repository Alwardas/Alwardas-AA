import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LoginAppTheme {
  // Theme colors as specified
  static const Color primary = Color(0xFF2F5AA8);
  static const Color secondary = Color(0xFF4A86D9);
  static const Color darkText = Color(0xFF1E2B57);
  static const Color lightText = Color(0xFF6B7280);
  static const Color cardBg = Colors.white;
  static const Color inputBg = Color(0xFFF5F7FA);
  static const Color border = Color(0xFFE5E7EB);

  // Background gradient overlay colors
  static const List<Color> backgroundOverlayGradient = [
    Color(0xCC4A86D9),
    Color(0xBB3E78C7),
    Color(0xCC1D4F91),
  ];

  static ThemeData get themeData {
    return ThemeData(
      useMaterial3: true,
      primaryColor: primary,
      scaffoldBackgroundColor: Colors.transparent,
      colorScheme: ColorScheme.light(
        primary: primary,
        secondary: secondary,
        surface: cardBg,
        onSurface: darkText,
        outline: border,
      ),
      textTheme: GoogleFonts.poppinsTextTheme().copyWith(
        displayLarge: GoogleFonts.poppins(
          fontSize: 72,
          fontWeight: FontWeight.w300,
          letterSpacing: 1.2,
          color: Colors.white,
        ),
        headlineMedium: GoogleFonts.poppins(
          fontSize: 48,
          fontWeight: FontWeight.w700,
          color: darkText,
        ),
        titleMedium: GoogleFonts.poppins(
          fontSize: 22,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
        bodyLarge: GoogleFonts.poppins(
          fontSize: 18,
          color: lightText,
        ),
        bodyMedium: GoogleFonts.poppins(
          fontSize: 14,
          color: lightText,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: inputBg,
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: border, width: 1),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        labelStyle: GoogleFonts.poppins(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: darkText,
        ),
        hintStyle: GoogleFonts.poppins(
          fontSize: 14,
          color: lightText,
        ),
      ),
    );
  }
}
