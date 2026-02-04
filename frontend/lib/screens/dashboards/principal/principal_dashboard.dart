import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/login_screen.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import 'principal_attendance_screen.dart';
import 'principal_announcements_screen.dart';
import 'principal_notifications_screen.dart';

import 'principal_faculty_screen.dart';
import 'principal_lesson_plans_screen.dart';
import 'principal_requests_screen.dart';
import 'principal_schedule_screen.dart';
import 'principal_timetables_screen.dart';
import 'principal_menu_tab.dart';
import 'principal_profile_tab.dart';

class PrincipalDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const PrincipalDashboard({super.key, required this.userData});

  @override
  State<PrincipalDashboard> createState() => _PrincipalDashboardState();
}

class _PrincipalDashboardState extends State<PrincipalDashboard> {
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
    final Color cardColor = isDark ? const Color(0xFF222240) : Colors.white;
    final Color textColor = theme.colorScheme.onSurface;
    final Color subTextColor = theme.colorScheme.secondary;
    final Color tint = theme.primaryColor;

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
              const PrincipalMenuTab(),
              _buildHomeTab(context, cardColor, textColor, subTextColor, isDark),
              PrincipalProfileTab(userData: widget.userData, onLogout: _logout),
            ],
          ),
        ),
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            canvasColor: isDark ? const Color(0xFF1C1C2E) : Colors.white,
          ),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            backgroundColor: isDark ? const Color(0xFF1C1C2E) : Colors.white,
            selectedItemColor: tint,
            unselectedItemColor: Colors.grey,
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
    // Principal Header Gradient ['#8E2DE2', '#4A00E0']
    final List<Color> headerGradient = [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)];
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);

    return Column(
      children: [
        // 1. Header Section - Fixed at Top
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
                           'Good Morning,', 
                           style: GoogleFonts.poppins(
                             color: Colors.white.withOpacity(0.8),
                             fontSize: 18,
                           ),
                         ),
                         FittedBox(
                           fit: BoxFit.scaleDown,
                           alignment: Alignment.centerLeft,
                           child: Text(
                             widget.userData['full_name'] ?? 'Principal',
                             style: GoogleFonts.poppins(
                               color: Colors.white,
                               fontSize: 26,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                         ),
                         const SizedBox(height: 4),
                         Text(
                           widget.userData['role'] ?? 'Administration',
                           style: GoogleFonts.poppins(
                             color: Colors.white.withOpacity(0.7),
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
                  // 2. Announcements
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
                          'College Working Hours',
                          '9:00 AM - 5:10 PM',
                          const [Color(0xFF4c669f), Color(0xFF3b5998)],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 3. Quick Access (Administration)
                  Text(
                    'Administration',
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  
                  // Row 1
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.calendar_today_outlined,
                          'Attendance',
                          'All Branches',
                          cardColor,
                          const Color(0xFF8E2DE2).withOpacity(0.2), 
                          const Color(0xFF8E2DE2),
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
                  
                  // Row 2
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.access_time,
                          'Timetables',
                          'Master View',
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
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Row 3
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.campaign_outlined,
                          'Announcements',
                          '& Warnings',
                          cardColor,
                          const Color(0xFFff6347).withOpacity(0.2), 
                          const Color(0xFFff6347),
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
                          'Personal',
                          cardColor,
                          const Color(0xFF00d2ff).withOpacity(0.2), 
                          const Color(0xFF00d2ff),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrincipalScheduleScreen())),
                        ),
                      ),
                    ],
                  ),
                   const SizedBox(height: 15),

                  // Row 4
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.groups_outlined,
                          'Faculty',
                          'Directory',
                          cardColor,
                          const Color(0xFF38ef7d).withOpacity(0.2), 
                          const Color(0xFF38ef7d),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrincipalFacultyScreen())),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.person_outline,
                          'Profile',
                          'View Details',
                          cardColor,
                          Colors.grey.withOpacity(0.1), 
                          Colors.grey,
                          textColor,
                          subTextColor,
                          onTap: () => setState(() => _selectedIndex = 2),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  // 4. Today's Schedule (Priority Tasks)
                  Text(
                    "Priority Tasks",
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      border: Border(
                        left: const BorderSide(color: Color(0xFF8E2DE2), width: 4),
                        top: BorderSide(color: Colors.grey.withOpacity(0.1)),
                        right: BorderSide(color: Colors.grey.withOpacity(0.1)),
                        bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'DUE TODAY',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF8E2DE2),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Review Budget Proposals',
                          style: GoogleFonts.poppins(
                            color: textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Finance Dept',
                          style: GoogleFonts.poppins(
                            color: subTextColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
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
        color: Colors.white.withOpacity(0.1),
        shape: BoxShape.circle,
      ),
      child: Icon(icon, color: Colors.white, size: 20),
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
      child: AppTheme.buildGlassCard(
        isDark: isDark,
        padding: const EdgeInsets.all(15),
        customColor: cardColor,
        opacity: isDark ? 0.05 : 0.4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: iconBgColor.withOpacity(0.3),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 24),
            ),
            const SizedBox(height: 12),
            Text(
              title,
               style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w600, fontSize: 16),
            ),
            const SizedBox(height: 4),
             Text(
              subtitle,
               style: GoogleFonts.poppins(color: subTextColor, fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }
}
