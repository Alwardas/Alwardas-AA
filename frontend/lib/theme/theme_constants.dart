import 'package:flutter/material.dart';

class ThemeColors {
  // Dark Theme
  static const List<Color> darkBackground = [Color(0xFF0f0c29), Color(0xFF302b63), Color(0xFF24243e)];
  static const Color darkCard = Colors.transparent; // Often transparency is handled by parent, but text/border color matters
  static const Color darkCardBg = Colors.transparent; // For explicit bg
  static const Color darkText = Color(0xFFffffff);
  static const Color darkSubtext = Color(0xFFaaaaaa);
  static const Color darkTabBar = Color(0xFF24243e);
  static const Color darkTint = Color(0xFF00d2ff);
  static const Color darkIconBg = Color(0x19FFFFFF); // rgba(255,255,255,0.1)
  static const Color darkError = Color(0xFFff4b4b);
  static const Color darkBackgroundSecondary = Color(0x0DFFFFFF); // rgba(255,255,255,0.05)
  static const Color darkNotificationBg = Color(0x33FFC107); // rgba(255, 193, 7, 0.2)
  static const Color darkNotificationText = Color(0xFFFFC107);

  // Light Theme
  static const List<Color> lightBackground = [Color(0xFFffffff), Color(0xFFf3f4f6), Color(0xFFe5e7eb)];
  static const Color lightCard = Colors.transparent;
  static const Color lightCardBg = Colors.transparent;
  static const Color lightText = Color(0xFF1f2937);
  static const Color lightSubtext = Color(0xFF6b7280);
  static const Color lightTabBar = Color(0xFFffffff);
  static const Color lightTint = Color(0xFF2563eb);
  static const Color lightIconBg = Color(0x0D000000); // rgba(0,0,0,0.05)
  static const Color lightError = Color(0xFFef4444);
  static const Color lightBackgroundSecondary = Color(0xFFffffff);
  static const Color lightNotificationBg = Color(0x33FBBF24); // rgba(251, 191, 36, 0.2)
  static const Color lightNotificationText = Color(0xFFd97706);

// Helper to get colors based on theme
}
