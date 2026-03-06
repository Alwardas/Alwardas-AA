import 'package:flutter/material.dart';

class AnnouncementThemeData {
  final String pageTitle;
  final List<Color> backgroundGradient;
  final List<Color> cardGradient;
  final List<Color> buttonGradient;
  final Color darkGlow1;
  final Color darkGlow2;
  final IconData typeIcon;
  final Color iconCircleBg;
  final Color iconColor;

  AnnouncementThemeData({
    required this.pageTitle,
    required this.backgroundGradient,
    required this.cardGradient,
    required this.buttonGradient,
    required this.darkGlow1,
    required this.darkGlow2,
    required this.typeIcon,
    required this.iconCircleBg,
    required this.iconColor,
  });
}

class AnnouncementThemeHelper {
  static AnnouncementThemeData getTheme(String typeString, bool isDark) {
    String type = typeString.toLowerCase();

    if (type == 'exam' || type == 'urgent') { // 1. Pink/Magenta (Urgent/Exam)
      return AnnouncementThemeData(
        pageTitle: type == 'exam' ? "Exam" : "Important",
        backgroundGradient: isDark ? [const Color(0xFF100B1A), const Color(0xFF08050D)] : [const Color(0xFFF6A6D1), const Color(0xFFF9C0D9)],
        cardGradient: isDark ? [const Color(0xFF1F1533), const Color(0xFF150E24)] : [const Color(0xFF2A223A), const Color(0xFF1A1423)],
        buttonGradient: [const Color(0xFF6E56F8), const Color(0xFF4C3AE3)],
        darkGlow1: const Color(0xFFD01B6B),
        darkGlow2: const Color(0xFF8126B3),
        typeIcon: type == 'exam' ? Icons.calendar_today_rounded : Icons.warning_amber_rounded,
        iconCircleBg: const Color(0xFF4C3AE3).withOpacity(0.3),
        iconColor: Colors.white,
      );
    } else if (type == 'faculty') { // 2. Purple (Discussion/Faculty)
      return AnnouncementThemeData(
        pageTitle: "Discussion",
        backgroundGradient: isDark ? [const Color(0xFF150A20), const Color(0xFF0A0510)] : [const Color(0xFFD0A1FF), const Color(0xFFDFBCFF)],
        cardGradient: isDark ? [const Color(0xFF22113D), const Color(0xFF120921)] : [const Color(0xFF4C277A), const Color(0xFF2F174D)],
        buttonGradient: [const Color(0xFF8A3CD9), const Color(0xFF6523A3)],
        darkGlow1: const Color(0xFF8A3CD9),
        darkGlow2: const Color(0xFF4C3AE3),
        typeIcon: Icons.person,
        iconCircleBg: const Color(0xFF8A3CD9).withOpacity(0.3),
        iconColor: Colors.white,
      );
    } else if (type == 'event' || type == 'holiday') { // 3. Yellow/Orange (Event/Holiday)
      return AnnouncementThemeData(
        pageTitle: "Event",
        backgroundGradient: isDark ? [const Color(0xFF05151A), const Color(0xFF020A0D)] : [const Color(0xFFFFD166), const Color(0xFFFFE099)],
        cardGradient: isDark ? [const Color(0xFF0D2830), const Color(0xFF07171C)] : [const Color(0xFFC7811B), const Color(0xFF9E6310)],
        buttonGradient: isDark ? [const Color(0xFF00E5FF), const Color(0xFF0097A7)] : [const Color(0xFFFCA311), const Color(0xFFE58A00)],
        darkGlow1: isDark ? const Color(0xFF00E5FF) : Colors.transparent,
        darkGlow2: isDark ? const Color(0xFF00B0FF) : Colors.transparent,
        typeIcon: Icons.celebration,
        iconCircleBg: isDark ? const Color(0xFF00E5FF).withOpacity(0.2) : const Color(0xFFE58A00).withOpacity(0.4),
        iconColor: isDark ? const Color(0xFF00E5FF) : Colors.white,
      );
    } else { // 4. Blue (General / Default)
      return AnnouncementThemeData(
        pageTitle: "Announcements",
        backgroundGradient: isDark ? [const Color(0xFF0A1020), const Color(0xFF050810)] : [const Color(0xFF7CB8FF), const Color(0xFF9DD2FF)],
        cardGradient: isDark ? [const Color(0xFF122244), const Color(0xFF0A1226)] : [const Color(0xFF2654A3), const Color(0xFF1A3875)],
        buttonGradient: [const Color(0xFF4772FF), const Color(0xFF1B42E5)],
        darkGlow1: const Color(0xFF1B42E5),
        darkGlow2: const Color(0xFF00E5FF),
        typeIcon: Icons.campaign_rounded,
        iconCircleBg: const Color(0xFF4772FF).withOpacity(0.3),
        iconColor: Colors.white,
      );
    }
  }
}
