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
                          const [Color(0xFFea5455), Color(0xFFfeb692)],
                        ),
                         const SizedBox(width: 15),
                        _buildAnnouncementCard(
                          'Faculty Meeting',
                          'Today at 4:30 PM',
                          const [Color(0xFF4c669f), Color(0xFF3b5998)],
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
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.event,
                          'Event Planning',
                          'Manage Events',
                          cardColor,
                          const Color(0xFFFFB75E).withOpacity(0.2), 
                          const Color(0xFFFFB75E),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoordinatorEventsScreen())),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.sports_basketball,
                          'Student Activities',
                          'Sports & Cultural',
                          cardColor,
                          const Color(0xFFFF4B2B).withOpacity(0.2), 
                          const Color(0xFFFF4B2B),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoordinatorActivitiesScreen())),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Row 2: Approvals (HOD & Principal)
                  Row(
                    children: [
                       Expanded(
                        child: _buildQuickAccessCard(
                          Icons.inbox_outlined,
                          'HOD Requests',
                          'Approve HODs',
                          cardColor,
                          const Color(0xFFf1c40f).withOpacity(0.2), 
                          const Color(0xFFf1c40f),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrincipalRequestsScreen())),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.admin_panel_settings_outlined,
                          'Principal Requests',
                          'Approve Principals',
                          cardColor,
                          const Color(0xFF8E2DE2).withOpacity(0.2), 
                          const Color(0xFF8E2DE2),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoordinatorRequestsScreen())),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Row 3: Academics (Borrow from Principal)
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.calendar_today_outlined,
                          'Attendance',
                          'Monitor All',
                          cardColor,
                          const Color(0xFF00d2ff).withOpacity(0.2), 
                          const Color(0xFF00d2ff),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrincipalAttendanceScreen())),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.menu_book,
                          'Syllabus',
                          'Track Progress',
                          cardColor,
                          const Color(0xFF38ef7d).withOpacity(0.2), 
                          const Color(0xFF38ef7d),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrincipalLessonPlansScreen())),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Row 4: Reports & Timetables
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.access_time,
                          'Master Timetables',
                          'View All',
                          cardColor,
                          const Color(0xFF606c88).withOpacity(0.2), 
                          const Color(0xFF606c88),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrincipalTimetablesScreen())),
                        ),
                      ),
                      const SizedBox(width: 15),
                       Expanded(
                        child: _buildQuickAccessCard(
                          Icons.groups_outlined,
                          'Faculty Dir',
                          'View Staff',
                          cardColor,
                          const Color(0xFFea5455).withOpacity(0.2), 
                          const Color(0xFFea5455),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrincipalFacultyScreen())),
                        ),
                      ),
                    ],
                  ),

                   const SizedBox(height: 15),

                   // Row 5: Communication
                   Row(
                    children: [
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.campaign_outlined,
                          'Announcer',
                          'Send Alerts',
                          cardColor,
                          const Color(0xFFFF416C).withOpacity(0.2), 
                          const Color(0xFFFF416C),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrincipalAnnouncementsScreen())),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.event_note,
                          'My Schedule',
                          'Personal View',
                          cardColor,
                          const Color(0xFF11998e).withOpacity(0.2), 
                          const Color(0xFF11998e),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrincipalScheduleScreen())),
                        ),
                      ),
                    ],
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
        color: const Color(0xFF1E293B).withOpacity(0.5), // Subtle bg
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF38BDF8).withOpacity(0.3), width: 1),
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
            color: Colors.black.withOpacity(0.1),
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
             decoration: BoxDecoration(color: Colors.white.withOpacity(0.5), borderRadius: BorderRadius.circular(2)),
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
                  style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.8), fontSize: 13),
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
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? ThemeColors.darkCardBg : Colors.white, // Solid color from theme
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
             color: isDark ? ThemeColors.darkBorder : Colors.black.withOpacity(0.03),
             width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
              blurRadius: 15, // Softer shadow
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBgColor.withOpacity(0.2), // Slightly lower opacity for bg to let glow shine
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: iconColor.withOpacity(0.3), // Glow color
                    blurRadius: 12,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
               textAlign: TextAlign.center,
               style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w600, fontSize: 15),
            ),
            const SizedBox(height: 4),
             Text(
              subtitle,
               textAlign: TextAlign.center,
               style: GoogleFonts.poppins(color: subTextColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
