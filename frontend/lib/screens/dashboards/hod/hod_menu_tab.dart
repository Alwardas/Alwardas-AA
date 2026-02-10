import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import 'hod_announcements_screen.dart';
import 'hod_attendance_screen.dart';
import 'hod_courses_screen.dart';
import 'hod_schedule_screen.dart';
import 'hod_timetables_screen.dart';
import 'hod_notifications_screen.dart';
import 'hod_department_screen.dart';


class HodMenuTab extends StatelessWidget {
  final Map<String, dynamic> userData;
  const HodMenuTab({super.key, this.userData = const {}});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;

    final branch = userData['branch'] ?? 'Computer Engineering';

    final List<Map<String, dynamic>> menuItems = [
      {'label': 'Announcements', 'icon': Icons.campaign, 'route': const HODAnnouncementsScreen(), 'color': const Color(0xFFf83600)},
      {'label': 'Attendance', 'icon': Icons.calendar_today, 'route': const HODAttendanceScreen(), 'color': const Color(0xFF8e44ad)},
      {'label': 'My Course', 'icon': Icons.book, 'route': const HodCoursesScreen(), 'color': const Color(0xFFfee140)},
      {'label': 'My Schedule', 'icon': Icons.today, 'route': const HodScheduleScreen(), 'color': const Color(0xFFfa709a)},
      {'label': 'Our Time Tables', 'icon': Icons.access_time, 'route': const HodTimetablesScreen(), 'color': const Color(0xFF43e97b)},
      {'label': 'Requests', 'icon': Icons.notifications, 'route': const HodNotificationsScreen(), 'color': const Color(0xFFff9f43)},
      {'label': 'Our Department', 'icon': Icons.account_balance, 'route': HodDepartmentScreen(userData: userData), 'color': const Color(0xFF3F51B5)},
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

