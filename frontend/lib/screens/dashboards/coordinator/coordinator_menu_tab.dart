import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../principal/principal_announcements_screen.dart';
import '../principal/principal_attendance_screen.dart';
import '../principal/principal_faculty_screen.dart';
import '../principal/principal_timetables_screen.dart';
import '../principal/principal_schedule_screen.dart';
import '../principal/principal_requests_screen.dart';
import '../principal/principal_lesson_plans_screen.dart';
import 'coordinator_events_screen.dart';
import 'coordinator_activities_screen.dart';
import 'coordinator_requests_screen.dart';

class CoordinatorMenuTab extends StatelessWidget {
  const CoordinatorMenuTab({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;

    final List<Map<String, dynamic>> menuItems = [
      {'label': 'Announcements', 'icon': Icons.campaign, 'route': const PrincipalAnnouncementsScreen(), 'color': ThemeColors.accentPurple},
      {'label': 'Attendance Monitor', 'icon': Icons.calendar_today, 'route': const PrincipalAttendanceScreen(), 'color': ThemeColors.accentBlue},
      {'label': 'Faculty Directory', 'icon': Icons.people, 'route': const PrincipalFacultyScreen(), 'color': ThemeColors.accentCyan},
      {'label': 'Master Timetables', 'icon': Icons.access_time, 'route': const PrincipalTimetablesScreen(), 'color': ThemeColors.accentGreen},
      {'label': 'My Schedule', 'icon': Icons.today, 'route': const PrincipalScheduleScreen(), 'color': ThemeColors.accentPurple},
      {'label': 'HOD Approvals', 'icon': Icons.verified_user_outlined, 'route': const PrincipalRequestsScreen(), 'color': ThemeColors.accentGold},
      {'label': 'Principal Approvals', 'icon': Icons.admin_panel_settings_outlined, 'route': const CoordinatorRequestsScreen(), 'color': ThemeColors.accentCyan},
      {'label': 'Syllabus Management', 'icon': Icons.book, 'route': const PrincipalLessonPlansScreen(), 'color': ThemeColors.accentGreen},
      {'label': 'Event Planning', 'icon': Icons.event, 'route': const CoordinatorEventsScreen(), 'color': ThemeColors.accentBlue},
      {'label': 'Student Activities', 'icon': Icons.sports_basketball, 'route': const CoordinatorActivitiesScreen(), 'color': ThemeColors.accentPurple},
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
                      border: Border.all(color: iconBg.withOpacity(0.5)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))
                      ]
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(color: (item['color'] as Color).withOpacity(0.15), borderRadius: BorderRadius.circular(12)),
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
