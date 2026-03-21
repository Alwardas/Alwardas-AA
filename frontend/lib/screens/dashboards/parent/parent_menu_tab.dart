import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';

// Screens
import '../student/attendance_screen.dart';
import '../student/student_notifications_screen.dart';
import '../student/student_marks_screen.dart';
import '../student/my_courses_screen.dart';
import '../student/student_announcements_screen.dart';
import '../student/time_table_screen.dart';
import 'parent_requests_screen.dart';
import '../../common/issue_management_screen.dart';

class ParentMenuTab extends StatelessWidget {
  final Map<String, dynamic> userData;
  final Map<String, String> currentChild;

  const ParentMenuTab({
    super.key,
    required this.userData,
    required this.currentChild,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Provider.of<ThemeProvider>(context);
    final isDark = theme.isDarkMode;
    final Color textColor = Theme.of(context).colorScheme.onSurface;
    final Color subTextColor = Theme.of(context).colorScheme.secondary;
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    final List<Map<String, dynamic>> menuItems = [
      {
        'title': 'Announcements',
        'icon': Icons.campaign_outlined,
        'color': const Color(0xFFff6347),
        'onTap': () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const StudentAnnouncementsScreen())),
      },
      {
        'title': 'Attendance',
        'icon': Icons.calendar_today,
        'color': const Color(0xFF2ecc71),
        'onTap': () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => AttendanceScreen(
                    userData: currentChild,
                    onBack: () => Navigator.pop(context)))),
      },
      {
        'title': 'Time Table',
        'icon': Icons.access_time_filled,
        'color': const Color(0xFF3498db),
        'onTap': () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => TimeTableScreen(studentData: currentChild))),
      },
      {
        'title': 'My Courses',
        'icon': Icons.menu_book_rounded,
        'color': const Color(0xFF3b5998),
        'onTap': () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => MyCoursesScreen(userId: currentChild['id']))),
      },
      {
        'title': 'Academics',
        'icon': Icons.insights_rounded,
        'color': const Color(0xFFe67e22),
        'onTap': () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => StudentMarksScreen(userId: currentChild['id']))),
      },
      {
        'title': 'Fee Payments',
        'icon': Icons.payment,
        'color': Colors.orange,
        'onTap': () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Fee Payments coming soon'))),
      },
      {
        'title': 'Permission & Requests',
        'icon': Icons.assignment_turned_in,
        'color': Colors.indigo,
        'onTap': () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => ParentRequestsScreen(
                      userData: userData,
                      studentId: currentChild['id'],
                    ))),
      },
      {
        'title': 'Issues',
        'icon': Icons.report_problem,
        'color': const Color(0xFFEF5350),
        'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => IssueManagementScreen(userData: userData))),
      },
    ];

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          'Menu',
          style: GoogleFonts.poppins(
            color: textColor,
            fontWeight: FontWeight.bold,
            fontSize: 24,
          ),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            ...menuItems.map((item) => _buildMenuCard(
                  item['title'],
                  item['icon'],
                  item['color'],
                  item['onTap'],
                  cardColor,
                  textColor,
                  subTextColor,
                  isDark,
                )),
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuCard(
      String title,
      IconData icon,
      Color baseColor,
      VoidCallback onTap,
      Color cardColor,
      Color textColor,
      Color subTextColor,
      bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
            color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: baseColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(15),
                  ),
                  child: Icon(icon, color: baseColor, size: 28),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Text(
                    title,
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(Icons.arrow_forward_ios, color: subTextColor, size: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
