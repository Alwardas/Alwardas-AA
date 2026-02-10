import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../theme/theme_constants.dart';

class AppTheme {
  // ... (previous colors and gradients)
  
  // Light Theme
  static const Color _lightText = ThemeColors.lightText;
  static const Color _lightBackground = Color(0xFFffffff); 
  static const Color _lightTint = ThemeColors.lightTint;
  static const Color _lightIcon = Color(0xFF687076);

  // Futuristic Dark Theme Constants
  static const Color _darkText = ThemeColors.darkTextPrimary;
  static const Color _darkBackground = ThemeColors.darkBackgroundColor; // Use single color alias
  static const Color _darkTint = ThemeColors.accentCyan; 
  static const Color _darkIcon = ThemeColors.accentBlue; 

  // Gradients
  static const List<Color> lightBodyGradient = ThemeColors.lightBackground;
  static const List<Color> darkBodyGradient = ThemeColors.darkBackground; // Use List alias 

  static const List<Color> lightHeaderGradient = [Color(0xFF824abe), Color(0xFF17b1d8)];
  static const List<Color> darkHeaderGradient = ThemeColors.headerGradient; 

  // Announcement Gradients
  static const List<Color> announcementBlue = ThemeColors.examGradient;
  static const List<Color> announcementOrange = [Color(0xFFff9966), Color(0xFFff5e62)]; // Keeping orange for variety if needed

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
        statusBarIconBrightness: Brightness.dark, 
        statusBarBrightness: Brightness.light,    
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
      surface: ThemeColors.darkCardBg, // Card Background
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
        statusBarIconBrightness: Brightness.light, 
        statusBarBrightness: Brightness.dark,     
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

  // Glossy / Glassmorphism Utility (Updated for new design)
  static BoxDecoration glassDecoration({
    required bool isDark,
    double opacity = 0.1,
    double borderRadius = 24,
    Color? customColor,
  }) {
    // New Shadow System
    final List<BoxShadow> shadows = isDark 
    ? [BoxShadow(color: Colors.black.withValues(alpha: 0.6), blurRadius: 40, offset: const Offset(0, 20))] // Dark Theme Shadow
    : [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 30, offset: const Offset(0, 10))]; // Light Theme Shadow

    return BoxDecoration(
      color: customColor ?? (isDark ? ThemeColors.darkCardBg : Colors.white),
      borderRadius: BorderRadius.circular(borderRadius),
      border: Border.all(
        color: isDark ? ThemeColors.darkBorder : Colors.transparent,
        width: 1.0,
      ),
      boxShadow: shadows,
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
