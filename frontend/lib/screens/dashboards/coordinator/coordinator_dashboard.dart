import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/login_screen.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../theme/theme_constants.dart';

// Principal Modules
import '../principal/principal_attendance_screen.dart';
import '../principal/principal_announcements_screen.dart';
import '../principal/principal_notifications_screen.dart';
import '../principal/principal_faculty_screen.dart';
import '../principal/principal_lesson_plans_screen.dart';
import '../principal/principal_requests_screen.dart';
import '../principal/principal_schedule_screen.dart';
import '../principal/principal_timetables_screen.dart';

// Coordinator Modules
import 'coordinator_events_screen.dart';
import 'coordinator_activities_screen.dart';
import 'coordinator_requests_screen.dart';
import 'coordinator_menu_tab.dart';
import 'coordinator_profile_tab.dart';


class CoordinatorDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const CoordinatorDashboard({super.key, required this.userData});

  @override
  State<CoordinatorDashboard> createState() => _CoordinatorDashboardState();
}

class _CoordinatorDashboardState extends State<CoordinatorDashboard> {
  int _selectedIndex = 1; // Default to Home (index 1)

  void _logout() async {
     await AuthService.logout();
     if (mounted) {
       Navigator.pushAndRemoveUntil(
         context,
         MaterialPageRoute(builder: (context) => const LoginScreen()),
         (route) => false,
       );
     }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final Color bgColor = theme.scaffoldBackgroundColor;
    final Color cardColor = isDark ? ThemeColors.darkCardBg : Colors.white;
    final Color textColor = theme.colorScheme.onSurface;
    final Color subTextColor = theme.colorScheme.secondary;
    final Color tint = const Color(0xFFFF4B2B); // Coordinator Theme Color (Orange/Red)

    final bool isHomeTab = _selectedIndex == 1;
    SystemUiOverlayStyle overlayStyle = AppTheme.getAdaptiveOverlayStyle(isHomeTab || isDark);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: Scaffold(
        backgroundColor: bgColor,
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark ? AppTheme.darkBodyGradient : AppTheme.lightBodyGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              const CoordinatorMenuTab(),
              _buildHomeTab(context, cardColor, textColor, subTextColor, isDark),
              CoordinatorProfileTab(userData: widget.userData, onLogout: _logout),
            ],
          ),
        ),
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            canvasColor: isDark ? const Color(0xFF020617) : Colors.white,
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            backgroundColor: isDark ? const Color(0xFF020617) : Colors.white,
            selectedItemColor: ThemeColors.accentBlue,
            unselectedItemColor: const Color(0xFF64748B),
            type: BottomNavigationBarType.fixed,
            showUnselectedLabels: true,
            selectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.menu), label: 'Menu'),
              BottomNavigationBarItem(
                icon: Icon(Icons.home_outlined, size: 28),
                activeIcon: Icon(Icons.home, size: 28),
                label: 'Home',
              ),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context, Color cardColor, Color textColor, Color subTextColor, bool isDark) {
    // Coordinator Header Gradient (Futuristic Theme)
    final List<Color> headerGradient = ThemeColors.headerGradient; 
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return Column(
      children: [
        // 1. Header Section
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10, 
            bottom: 30, 
            left: 24, 
            right: 24
          ),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: headerGradient,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
          ),
          child: Column(
             children: [
               Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         Text(
                           'Welcome Back,', 
                            style: GoogleFonts.poppins(
                              color: ThemeColors.accentBlue, // Accent Blue (Header Text Main)
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                         ),
                         FittedBox(
                           fit: BoxFit.scaleDown,
                           alignment: Alignment.centerLeft,
                           child: Text(
                             widget.userData['full_name'] ?? 'Coordinator',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFE5E7EB), // Primary Text
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                           ),
                         ),
                         const SizedBox(height: 4),
                         Text(
                           'Master Administration',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF94A3B8), // Text Sub
                              fontSize: 14,
                            ),
                         ),
                       ],
                     ),
                   ),
                   Row(
                     children: [
                       GestureDetector(
                         onTap: () => themeProvider.toggleTheme(),
                         child: _buildHeaderIcon(themeProvider.isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round),
                       ),
                       const SizedBox(width: 10),
                       GestureDetector(
                         onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrincipalNotificationsScreen())),
                         child: _buildHeaderIcon(Icons.notifications_none),
                       ),
                     ],
                   ),
                 ],
               )
             ],
           ),
        ),

        // 2. Scrollable Body
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // Announcements
                  Text(
                    'Announcements',
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildAnnouncementCard(
                          'Examination Schedule',
                          'Released for All Depts',
                          const [Color(0xFF42E695), Color(0xFF3BB2B8)], // Cyan/Greenish Blue
                        ),
                         const SizedBox(width: 15),
                        _buildAnnouncementCard(
                          'Faculty', // Changed from meeting to match image text if needed, but image says "Faculty"
                          'Today at 2 PM', // Match image
                          const [Color(0xFF2E2D88), Color(0xFF712B91)], // Dark Blue/Purple
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // Quick Access: Coordinator Specific
                  Text(
                    'Administration',
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Row 1: Events & Activities (Coordinator Special)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: 10,
                    itemBuilder: (context, index) {
                      // Define items data
                      final List<Map<String, dynamic>> items = [
                        {
                          'icon': Icons.calendar_today_outlined,
                          'title': 'Attendance',
                          'subtitle': 'Monitor All',
                          'color': const Color(0xFF29B6F6), // Cyan
                          'route': const PrincipalAttendanceScreen(),
                        },
                        {
                          'icon': Icons.menu_book,
                          'title': 'Syllabus',
                          'subtitle': 'Track Progress',
                          'color': const Color(0xFF66BB6A), // Green
                          'route': const PrincipalLessonPlansScreen(),
                        },
                        {
                          'icon': Icons.event,
                          'title': 'Event Planning',
                          'subtitle': 'Manage Events',
                          'color': const Color(0xFF4FC3F7), // Light Blue
                          'route': const CoordinatorEventsScreen(),
                        },
                        {
                          'icon': Icons.sports_basketball,
                          'title': 'Student Activities',
                          'subtitle': 'Sports & Cultural',
                          'color': const Color(0xFF1565C0), // Dark Blue
                          'route': const CoordinatorActivitiesScreen(),
                        },
                        {
                          'icon': Icons.assignment_turned_in,
                          'title': 'HOD Requests',
                          'subtitle': 'Approve HODs',
                          'color': const Color(0xFF00B0FF), // Blue
                          'route': const PrincipalRequestsScreen(),
                        },
                        {
                          'icon': Icons.verified_user, 
                          'title': 'Principal Requests',
                          'subtitle': 'Approve Principals',
                          'color': const Color(0xFF0D47A1), // Deep Blue
                          'route': const CoordinatorRequestsScreen(),
                        },
                        {
                          'icon': Icons.access_time,
                          'title': 'Master Timetables',
                          'subtitle': 'View All',
                          'color': const Color(0xFF78909C), // Blue Grey
                          'route': const PrincipalTimetablesScreen(),
                        },
                        {
                          'icon': Icons.groups_outlined,
                          'title': 'Faculty Dir',
                          'subtitle': 'View Staff',
                          'color': const Color(0xFFEC407A), // Pink
                          'route': const PrincipalFacultyScreen(),
                        },
                        {
                          'icon': Icons.campaign_outlined,
                          'title': 'Announcer',
                          'subtitle': 'Send Alerts',
                          'color': const Color(0xFFEF5350), // Red
                          'route': const PrincipalAnnouncementsScreen(),
                        },
                        {
                          'icon': Icons.event_note,
                          'title': 'My Schedule',
                          'subtitle': 'Personal View',
                          'color': const Color(0xFF26A69A), // Teal
                          'route': const PrincipalScheduleScreen(),
                        },
                      ];

                      final item = items[index];
                      return _buildQuickAccessCard(
                        item['icon'],
                        item['title'],
                        item['subtitle'],
                        cardColor,
                        item['color'].withValues(alpha: 0.1), 
                        item['color'],
                        textColor,
                        subTextColor,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item['route'])),
                      );
                    },
                  ),
                  
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeaderIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B).withValues(alpha: 0.5), // Subtle bg
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3), width: 1),
      ),
      child: Icon(icon, color: const Color(0xFF38BDF8), size: 20), // Blue Icon
    );
  }

  Widget _buildAnnouncementCard(String title, String subtitle, List<Color> gradientColors) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
             width: 4, 
             height: 35, 
             decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.5), borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildQuickAccessCard(IconData icon, String title, String subtitle, Color cardColor, Color iconBgColor, Color iconColor, Color textColor, Color subTextColor, {VoidCallback? onTap}) {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? ThemeColors.darkCardBg : Colors.white, // Solid color from theme
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
             color: isDark ? ThemeColors.darkBorder : Colors.black.withValues(alpha: 0.03),
             width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
              blurRadius: 15, // Softer shadow
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconBgColor.withValues(alpha: 0.2), // Clean no-shadow bg
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: subTextColor, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
