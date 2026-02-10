import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import 'principal_announcements_screen.dart';
import 'principal_attendance_screen.dart';
import 'principal_faculty_screen.dart';
import 'principal_timetables_screen.dart';
import 'principal_schedule_screen.dart';
import 'principal_requests_screen.dart';
import 'principal_lesson_plans_screen.dart';

class PrincipalMenuTab extends StatelessWidget {
  const PrincipalMenuTab({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;

    final List<Map<String, dynamic>> menuItems = [
      {'label': 'Announcements', 'icon': Icons.campaign, 'route': const PrincipalAnnouncementsScreen(), 'color': const Color(0xFFff6347)},
      {'label': 'Attendance Monitor', 'icon': Icons.calendar_today, 'route': const PrincipalAttendanceScreen(), 'color': const Color(0xFF00d2ff)},
      {'label': 'Faculty Directory', 'icon': Icons.people, 'route': const PrincipalFacultyScreen(), 'color': const Color(0xFF8E2DE2)},
      {'label': 'Master Timetables', 'icon': Icons.access_time, 'route': const PrincipalTimetablesScreen(), 'color': const Color(0xFF606c88)},
      {'label': 'My Schedule', 'icon': Icons.today, 'route': const PrincipalScheduleScreen(), 'color': const Color(0xFFfa709a)},
      {'label': 'Requests & Approvals', 'icon': Icons.inbox, 'route': const PrincipalRequestsScreen(), 'color': const Color(0xFFf1c40f)},
      {'label': 'Syllabus Management', 'icon': Icons.book, 'route': const PrincipalLessonPlansScreen(), 'color': const Color(0xFF38ef7d)},
    ];

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Text(
              "Menu",
              style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: textColor),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: menuItems.length,
              itemBuilder: (ctx, index) {
                final item = menuItems[index];
                return GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item['route'])),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: iconBg.withValues(alpha: 0.5)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                      ]
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(color: (item['color'] as Color).withValues(alpha: 0.15), borderRadius: BorderRadius.circular(12)),
                          child: Icon(item['icon'], color: item['color'], size: 24),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            item['label'],
                            style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: textColor),
                          ),
                        ),
                        Icon(Icons.chevron_right, size: 20, color: subTextColor),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
