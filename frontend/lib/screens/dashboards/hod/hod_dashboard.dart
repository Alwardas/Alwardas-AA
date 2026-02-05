import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/login_screen.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import 'hod_manage_attendance_screen.dart';
import 'hod_announcements_screen.dart';
import 'hod_notifications_screen.dart';
import 'hod_courses_screen.dart';
import 'hod_attendance_screen.dart';
import 'hod_menu_tab.dart';
import 'hod_profile_tab.dart';
import 'hod_faculty_screen.dart';
import 'hod_timetables_screen.dart';
import 'hod_requests_screen.dart';
import '../faculty/faculty_profile_screen.dart';
import 'hod_department_screen.dart';

class HodDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HodDashboard({super.key, required this.userData});

  @override
  State<HodDashboard> createState() => _HodDashboardState();
}

class _HodDashboardState extends State<HodDashboard> {
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
              HodMenuTab(userData: widget.userData),
              _buildHomeTab(context, cardColor, textColor, subTextColor, isDark),
              HodProfileTab(userData: widget.userData, onLogout: _logout),
            ],
          ),
        ),  bottomNavigationBar: Theme(
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
    // Determine Header Icons based on theme
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
              colors: isDark ? AppTheme.darkHeaderGradient : AppTheme.lightHeaderGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
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
                           'Welcome back,', 
                           style: GoogleFonts.poppins(
                             color: Colors.white.withOpacity(0.8),
                             fontSize: 18,
                           ),
                         ),
                         FittedBox(
                           fit: BoxFit.scaleDown,
                           alignment: Alignment.centerLeft,
                           child: Text(
                             widget.userData['full_name'] ?? 'Dr. HOD',
                             style: GoogleFonts.poppins(
                               color: Colors.white,
                               fontSize: 26,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                         ),
                         const SizedBox(height: 4),
                         Text(
                           widget.userData['branch'] ?? 'My Department',
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
                         onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HodNotificationsScreen())),
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
                  // 2. Announcements HEADER
                  Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text(
                         'Announcements',
                         style: GoogleFonts.poppins(
                           color: textColor,
                           fontSize: 18,
                           fontWeight: FontWeight.bold,
                         ),
                       ),
                       GestureDetector(
                         onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HODAnnouncementsScreen())),
                         child: Text(
                           "View All",
                           style: GoogleFonts.poppins(color: const Color(0xFF00d2ff), fontWeight: FontWeight.bold),
                         ),
                       )
                     ],
                  ),
                  const SizedBox(height: 15),
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildAnnouncementCard(
                          'College Working Hours',
                          '9:00 AM - 5:10 PM\nby College Management',
                          const [Color(0xFF4c669f), Color(0xFF3b5998)],
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  // 3. Quick Access
                  Text(
                    'Quick Access',
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
                          Icons.people_alt_outlined,
                          'Faculty',
                          'Manage',
                          cardColor,
                          const Color(0xFF38ef7d).withOpacity(0.2), 
                          const Color(0xFF38ef7d),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HodFacultyScreen(branch: widget.userData['branch'] ?? 'Computer Engineering'))),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.schedule,
                          'Timetables',
                          'Oversee',
                          cardColor,
                          const Color(0xFF606c88).withOpacity(0.2), 
                          const Color(0xFF606c88),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HodTimetablesScreen())),
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
                          Icons.description_outlined,
                          'Reports',
                          'View',
                          cardColor,
                          const Color(0xFF141E30).withOpacity(0.2), 
                          const Color(0xFF243B55),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HODAttendanceScreen())),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.group_add_outlined,
                          'Branch Requests',
                          'Approve Users',
                          cardColor,
                          const Color(0xFFe74c3c).withOpacity(0.2), 
                          const Color(0xFFe74c3c),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HodRequestsScreen())),
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
                          Icons.book,
                          'Courses',
                          'My Plan',
                          cardColor,
                          Colors.blue.withOpacity(0.2),
                          Colors.blue,
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HodCoursesScreen())),
                        ),
                      ),
                       const SizedBox(width: 15),
                       Expanded(
                        child: _buildQuickAccessCard(
                          Icons.person_outline,
                          'Profile',
                          'Details',
                          cardColor,
                          const Color(0xFFf1c40f).withOpacity(0.2), 
                          const Color(0xFFf1c40f),
                          textColor,
                          subTextColor,
                          onTap: () => setState(() => _selectedIndex = 2),
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
                          Icons.account_balance,
                          'Our Dept',
                          'Management',
                          cardColor,
                          Colors.indigo.withOpacity(0.2),
                          Colors.indigo,
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HodDepartmentScreen(userData: widget.userData))),
                        ),
                      ),
                      const SizedBox(width: 15),
                      const Expanded(child: SizedBox()), // Placeholder for balance
                    ],
                  ),

                  const SizedBox(height: 25),

                  // 4. Today's Schedule
                  Text(
                    "Today's Schedule",
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
                      border: Border.all(color: Colors.grey.withOpacity(0.1)),
                      boxShadow: [
                        BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
                      ]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '11:00 AM - 12:00 PM',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF00d2ff),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'HOD Meeting',
                          style: GoogleFonts.poppins(
                            color: textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Board Room',
                          style: GoogleFonts.poppins(
                            color: subTextColor,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 30),
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
