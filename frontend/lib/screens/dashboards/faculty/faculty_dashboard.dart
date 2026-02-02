import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/login_screen.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import 'faculty_classes_screen.dart';
import 'faculty_schedule_screen.dart';
import 'faculty_attendance_screen.dart';
import 'faculty_profile_screen.dart';
import 'faculty_notifications_screen.dart';

class FacultyDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const FacultyDashboard({super.key, required this.userData});

  @override
  State<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard> {
  int _selectedIndex = 2; // Default to Home (Dashboard)

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

    // Status Bar Logic
    final bool isHomeTab = _selectedIndex == 2;
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
              const FacultyClassesScreen(),
              const FacultyScheduleScreen(),
              _buildHomeTab(context, isDark, textColor, subTextColor, cardColor),
              FacultyAttendanceScreen(userData: widget.userData),
              FacultyProfileScreen(userData: widget.userData),
            ],
          ),
        ),
        bottomNavigationBar: Theme(
          data: theme.copyWith(canvasColor: isDark ? const Color(0xFF1C1C2E) : Colors.white),
          child: BottomNavigationBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            backgroundColor: isDark ? const Color(0xFF1C1C2E) : Colors.white,
            selectedItemColor: tint,
            unselectedItemColor: Colors.grey,
            type: BottomNavigationBarType.fixed,
            showUnselectedLabels: true,
            selectedLabelStyle: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w600),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.menu_book_outlined), label: 'Classes'),
              BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Schedule'),
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.check_circle_outline), label: 'Attendance'),
              BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context, bool isDark, Color textColor, Color subTextColor, Color cardColor) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final List<Color> headerGradient = isDark 
        ? [const Color(0xFF343e52), const Color(0xFF3880ec)] 
        : [const Color(0xFF824abe), const Color(0xFF17b1d8)];

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
                             widget.userData['full_name'] ?? 'Prof. Faculty',
                             style: GoogleFonts.poppins(
                               color: Colors.white,
                               fontSize: 26,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                         ),
                         const SizedBox(height: 4),
                         Text(
                           widget.userData['branch'] ?? 'Department',
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
                         onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacultyNotificationsScreen())),
                         child: _buildHeaderIcon(Icons.notifications_none),
                       ),
                       const SizedBox(width: 10),
                       GestureDetector(
                         onTap: _logout,
                         child: _buildHeaderIcon(Icons.logout),
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
                          'Department Meeting',
                          'Conference Hall, 2 PM.',
                          const [Color(0xFF4c669f), Color(0xFF3b5998)],
                        ),
                        const SizedBox(width: 15),
                        _buildAnnouncementCard(
                          'Marks Submission',
                          'Due by Friday.',
                          const [Color(0xFFff9966), Color(0xFFff5e62)],
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
                          Icons.menu_book_outlined,
                          'My Classes',
                          'Manage',
                          cardColor,
                          const Color(0xFF3b5998).withOpacity(0.2), 
                          const Color(0xFF3b5998),
                          textColor,
                          subTextColor,
                          onTap: () => setState(() => _selectedIndex = 0),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.schedule,
                          'Schedule',
                          'View',
                          cardColor,
                          const Color(0xFF9b59b6).withOpacity(0.2), 
                          const Color(0xFF9b59b6),
                          textColor,
                          subTextColor,
                          onTap: () => setState(() => _selectedIndex = 1),
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
                          Icons.check_circle_outline,
                          'Attendance',
                          'Post',
                          cardColor,
                          const Color(0xFF2ecc71).withOpacity(0.2), 
                          const Color(0xFF2ecc71),
                          textColor,
                          subTextColor,
                          onTap: () => setState(() => _selectedIndex = 3),
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
                          onTap: () => setState(() => _selectedIndex = 4),
                        ),
                      ),
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
                      border: Border(
                        left: const BorderSide(color: Color(0xFF00d2ff), width: 4),
                        top: BorderSide(color: Colors.grey.withOpacity(0.1)),
                        right: BorderSide(color: Colors.grey.withOpacity(0.1)),
                        bottom: BorderSide(color: Colors.grey.withOpacity(0.1)),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '09:00 AM - 10:30 AM',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF00d2ff),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Data Structures',
                          style: GoogleFonts.poppins(
                            color: textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Room 201 (CS-A)',
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
