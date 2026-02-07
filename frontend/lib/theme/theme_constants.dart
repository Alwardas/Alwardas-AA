import 'package:flutter/material.dart';

class ThemeColors {
  // Futuristic Dark Theme
  static const List<Color> darkBackground = [Color(0xFF020617), Color(0xFF020617)]; // Changed back to List for compatibility
  static const Color darkBackgroundColor = Color(0xFF020617); // Single color alias
  static const Color darkCardBg = Color(0xFF0F172A); // Secondary Dark
  static const Color darkSurface = Color(0xFF111827); // Surface Dark (Faculty Card)
  static const Color darkBorder = Color(0xFF1E293B);
  
  static const Color accentCyan = Color(0xFF22D3EE); // Neon Cyan
  static const Color accentBlue = Color(0xFF38BDF8); // Accent Blue
  static const Color accentGold = Color(0xFFFACC15); // Highlight Gold
  static const Color accentGreen = Color(0xFF34D399);
  static const Color accentPurple = Color(0xFFA78BFA);

  static const Color darkTextPrimary = Color(0xFFE5E7EB);
  static const Color darkTextSecondary = Color(0xFF94A3B8);
  static const Color darkTextMuted = Color(0xFF64748B);
  static const Color darkTextOnAccent = Color(0xFF020617);

  // Header Gradient
  static const List<Color> headerGradient = [Color(0xFF1E1B4B), Color(0xFF312E81)];
  
  // Announcement Gradients
  static const List<Color> examGradient = [Color(0xFF2563EB), Color(0xFF38BDF8)];

  // Legacy mappings for compatibility (updating to match new theme where possible)
  static const List<Color> darkBackgroundGradient = [Color(0xFF020617), Color(0xFF020617)]; // Solid background for futuristic look
  static const Color darkCard = darkCardBg; 
  static const Color darkText = darkTextPrimary;
  static const Color darkSubtext = darkTextSecondary;
  static const Color darkTabBar = darkCardBg;
  static const Color darkTint = accentCyan;
  static const Color darkIconBg = Color(0xFF1E293B); // Using border color as subtle bg
  static const Color darkError = Color(0xFFef4444);
  static const Color darkBackgroundSecondary = darkSurface;
  static const Color darkNotificationBg = Color(0x33FACC15); 
  static const Color darkNotificationText = accentGold;

  // Light Theme (Keeping existing but updating accents to match for consistency if needed, 
  // but user focus is Dark. Keeping original light theme for safety unless requested)
  static const List<Color> lightBackground = [Color(0xFFffffff), Color(0xFFf3f4f6), Color(0xFFe5e7eb)];
  static const Color lightCard = Colors.white;
  static const Color lightCardBg = Colors.white;
  static const Color lightText = Color(0xFF1f2937);
  static const Color lightSubtext = Color(0xFF6b7280);
  static const Color lightTabBar = Color(0xFFffffff);
  static const Color lightTint = Color(0xFF2563eb);
  static const Color lightIconBg = Color(0x0D000000); 
  static const Color lightError = Color(0xFFef4444);
  static const Color lightBackgroundSecondary = Color(0xFFffffff);
  static const Color lightNotificationBg = Color(0x33FBBF24);
  static const Color lightNotificationText = Color(0xFFd97706);
}
