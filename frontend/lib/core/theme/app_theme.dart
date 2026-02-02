import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ... (previous colors and gradients)
  
  // Light Theme
  static const Color _lightText = Color(0xFF1f2937); // #1f2937
  static const Color _lightBackground = Color(0xFFffffff); // Main white
  static const Color _lightTint = Color(0xFF2563eb); // #2563eb Royal Blue
  static const Color _lightIcon = Color(0xFF687076); // Kept similar

  // Dark Theme
  static const Color _darkText = Color(0xFFffffff); // #ffffff
  static const Color _darkBackground = Color(0xFF0f0c29); // Start of gradient
  static const Color _darkTint = Color(0xFF00d2ff); // #00d2ff Cyan
  static const Color _darkIcon = Color(0xFF9BA1A6);

  // Gradients
  static const List<Color> lightBodyGradient = [Color(0xFFffffff), Color(0xFFf3f4f6), Color(0xFFe5e7eb)];
  static const List<Color> darkBodyGradient = [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)];

  static const List<Color> lightHeaderGradient = [Color(0xFF824abe), Color(0xFF17b1d8)];
  static const List<Color> darkHeaderGradient = [Color(0xFF343e52), Color(0xFF3880ec)];

  // Announcement Gradients
  static const List<Color> announcementBlue = [Color(0xFF4c669f), Color(0xFF3b5998)];
  static const List<Color> announcementOrange = [Color(0xFFff9966), Color(0xFFff5e62)];

  static final ThemeData lightTheme = ThemeData(
    brightness: Brightness.light,
    scaffoldBackgroundColor: _lightBackground,
    primaryColor: _lightTint,
    colorScheme: ColorScheme.light(
      primary: _lightTint,
      surface: _lightBackground,
      onSurface: _lightText,
      secondary: _lightIcon,
    ),
    iconTheme: const IconThemeData(color: _lightIcon),
    textTheme: GoogleFonts.poppinsTextTheme().apply(
      bodyColor: _lightText,
      displayColor: _lightText,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: _lightBackground,
      elevation: 0,
      iconTheme: IconThemeData(color: _lightIcon),
      titleTextStyle: TextStyle(color: _lightText, fontSize: 20, fontWeight: FontWeight.bold),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark, // Dark icons for light theme
        statusBarBrightness: Brightness.light,    // For iOS
      ),
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    splashFactory: InkRipple.splashFactory,
  );

  static final ThemeData darkTheme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: _darkBackground,
    primaryColor: _darkTint,
    colorScheme: ColorScheme.dark(
      primary: _darkTint,
      surface: _darkBackground,
      onSurface: _darkText,
      secondary: _darkIcon,
    ),
    iconTheme: const IconThemeData(color: _darkIcon),
    textTheme: GoogleFonts.poppinsTextTheme().apply(
      bodyColor: _darkText,
      displayColor: _darkText,
    ),
     appBarTheme: const AppBarTheme(
      backgroundColor: _darkBackground,
      elevation: 0,
      iconTheme: IconThemeData(color: _darkIcon),
      titleTextStyle: TextStyle(color: _darkText, fontSize: 20, fontWeight: FontWeight.bold),
      systemOverlayStyle: SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light, // Light icons for dark theme
        statusBarBrightness: Brightness.dark,     // For iOS
      ),
    ),
    visualDensity: VisualDensity.adaptivePlatformDensity,
    splashFactory: InkRipple.splashFactory,
  );

  /// Helper to get consistent Status Bar Style based on background
  static SystemUiOverlayStyle getAdaptiveOverlayStyle(bool isDarkBackground) {
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDarkBackground ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDarkBackground ? Brightness.dark : Brightness.light,
    );
  }

  // Glossy / Glassmorphism Utility
  static BoxDecoration glassDecoration({
    required bool isDark,
    double opacity = 0.1,
    double borderRadius = 24,
    Color? customColor,
  }) {
    return BoxDecoration(
      color: customColor?.withOpacity(opacity) ?? 
             (isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.5)),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark ? Colors.white.withOpacity(0.15) : Colors.white.withOpacity(0.35),
        width: 1.2,
      ),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
          blurRadius: 10, // Reduced for performance
          offset: const Offset(0, 5),
        ),
      ],
    );
  }

  /// True Glassmorphism Card with BackdropFilter
  static Widget buildGlassCard({
    required Widget child,
    required bool isDark,
    double borderRadius = 24,
    double blur = 5, // Reduced for performance
    double opacity = 0.1,
    Color? customColor,
    EdgeInsetsGeometry? padding,
    EdgeInsetsGeometry? margin,
  }) {
    return Container(
      margin: margin,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            padding: padding,
            decoration: glassDecoration(
              isDark: isDark,
              opacity: opacity,
              borderRadius: borderRadius,
              customColor: customColor,
            ),
            child: child,
          ),
        ),
      ),
    );
  }
}
