import 'package:flutter/material.dart';

extension ThemeContextExtension on BuildContext {
  bool get isDark => Theme.of(this).brightness == Brightness.dark;
  Color get bgColor => isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
  Color get cardColor => isDark ? const Color(0xFF1E293B) : Colors.white;
  Color get borderColor => isDark ? Colors.white10 : const Color(0xFFE2E8F0);
  Color get textPrimary => isDark ? Colors.white : const Color(0xFF0F172A);
  Color get textSecondary => isDark ? Colors.white70 : const Color(0xFF334155);
  Color get textMuted => isDark ? Colors.white38 : const Color(0xFF64748B);
  Color get textMuted2 => isDark ? Colors.white24 : const Color(0xFF94A3B8);
}
