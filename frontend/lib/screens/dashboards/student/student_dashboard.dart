import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../auth/login_screen.dart';
import 'student_profile_tab.dart';
import 'attendance_screen.dart';
import 'time_table_screen.dart';
import 'my_courses_screen.dart';
import 'student_notifications_screen.dart';
import 'student_marks_screen.dart';
import 'student_comments_screen.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';

class StudentDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const StudentDashboard({super.key, required this.userData});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _selectedIndex = 2; // Default to Home (index 2)

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

    // Derived Colors based on Theme
    final Color bgColor = theme.scaffoldBackgroundColor;
    final Color cardColor = isDark ? const Color(0xFF222240) : Colors.white;
    final Color accentBlue = theme.primaryColor;
    
    // Text Color
    final Color textColor = theme.colorScheme.onSurface;
    final Color subTextColor = theme.colorScheme.secondary;

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
              // Placeholder for MyCoursesScreen
              MyCoursesScreen(),
              // Placeholder for TimeTableScreen
              TimeTableScreen(),
              _buildHomeTab(context, bgColor, cardColor, accentBlue, textColor, subTextColor, isDark),
              // Placeholder for AttendanceScreen
              AttendanceScreen(userData: widget.userData, onBack: () => setState(() => _selectedIndex = 2)),
              StudentProfileTab(userData: widget.userData, onLogout: _logout),
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
          selectedItemColor: accentBlue,
          unselectedItemColor: Colors.grey,
          type: BottomNavigationBarType.fixed, // Needed for 5 items
          showUnselectedLabels: true,
          selectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
          unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
          items: const [
            BottomNavigationBarItem(icon: Icon(Icons.menu_book), label: 'My Courses'),
            BottomNavigationBarItem(icon: Icon(Icons.schedule), label: 'Time Table'),
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Attendance'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    ),
    );
  }

  Widget _buildHomeTab(BuildContext context, Color bgColor, Color cardColor, Color accentBlue, Color textColor, Color subTextColor, bool isDark) {
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
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1a4ab2), Color(0xFF3b82f6)],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
          ),
          child: Column(
             children: [
               Align(
                 alignment: Alignment.topLeft,
                 child: Text(
                    (widget.userData['branch'] ?? 'COMPUTER ENGINEERING').toUpperCase(),
                    style: GoogleFonts.poppins(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 13,
                      letterSpacing: 1.2,
                      fontWeight: FontWeight.w500,
                    ),
                    textAlign: TextAlign.left,
                 ),
               ),
               const SizedBox(height: 10),
               
                // Name and ID Row
                Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   Expanded(
                     child: Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         FittedBox(
                           fit: BoxFit.scaleDown,
                           alignment: Alignment.centerLeft,
                           child: Text(
                             widget.userData['full_name'] ?? 'Student',
                             style: GoogleFonts.poppins(
                               color: Colors.white,
                               fontSize: 26,
                               fontWeight: FontWeight.bold,
                             ),
                           ),
                         ),
                         const SizedBox(height: 2),
                         Text(
                           'Student ID: ${widget.userData['login_id'] ?? '24634-CM-026'}',
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
                       // Theme Switcher - Glassy style as per image
                       GestureDetector(
                         onTap: () => themeProvider.toggleTheme(),
                         child: _buildHeaderIcon(themeProvider.isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round),
                       ),
                       const SizedBox(width: 12),
                       GestureDetector(
                         onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentNotificationsScreen())),
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
                    physics: const BouncingScrollPhysics(),
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildAnnouncementCard(
                          'Mid-term schedules released',
                          'Check your portal.',
                          AppTheme.announcementBlue,
                        ),
                        const SizedBox(width: 15),
                        _buildAnnouncementCard(
                          'Guest Lecture',
                          'Auditorium at 3 PM',
                          AppTheme.announcementOrange,
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
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.menu_book,
                          'My Courses',
                          '4 Active',
                          cardColor,
                          const Color(0xFF3b5998).withOpacity(0.2), // React: rgba(59, 89, 152, 0.2)
                          const Color(0xFF3b5998),
                          textColor,
                          subTextColor,
                          onTap: () => setState(() => _selectedIndex = 0),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.calendar_today,
                          'Attendance',
                          '95%',
                          cardColor,
                          const Color(0xFF2ecc71).withOpacity(0.2), // React: rgba(46, 204, 113, 0.2)
                          const Color(0xFF2ecc71),
                          textColor,
                          subTextColor,
                          onTap: () => setState(() => _selectedIndex = 3),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.schedule,
                          'Time Table',
                          '3 Classes',
                          cardColor,
                          const Color(0xFF9b59b6).withOpacity(0.2), // React: rgba(155, 89, 182, 0.2)
                          const Color(0xFF9b59b6),
                          textColor,
                          subTextColor,
                          onTap: () => setState(() => _selectedIndex = 1), // TimeTable is Index 1
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.insights,
                          'Marks / Results',
                          'View Grades',
                          cardColor,
                          const Color(0xFFe67e22).withOpacity(0.2), // Orange tint
                          const Color(0xFFe67e22),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentMarksScreen())),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  Row(
                    children: [
                      Expanded(
                        child: _buildQuickAccessCard(
                          Icons.report_problem_outlined, // Changed icon to be more relevant to "Issues"
                          'Issues',
                          'Report & Track',
                          cardColor,
                          const Color(0xFFE94057).withOpacity(0.2), // Pink/Red tint
                          const Color(0xFFE94057),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentCommentsScreen(userData: widget.userData))),
                        ),
                      ),
                      const SizedBox(width: 15),
                      // Placeholder or empty expanded to keep alignment if needed, 
                      // or just use Flexible/Expanded logic. 
                      // For now, let's just make it a single full width row or half width. 
                      // A single card looking like the others is fine.
                      const Spacer(), 
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
                    decoration: AppTheme.glassDecoration(
                      isDark: isDark,
                      customColor: cardColor,
                      opacity: 0.6,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 4,
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.cyanAccent,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 15),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '10:00 AM - 11:30 AM',
                              style: GoogleFonts.poppins(
                                color: Colors.cyanAccent,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              'Software Engineering',
                              style: GoogleFonts.poppins(
                                color: textColor,
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              'Room 301 (Dr. Lee)',
                              style: GoogleFonts.poppins(
                                color: subTextColor,
                                fontSize: 13,
                              ),
                            ),
                          ],
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
      child: Icon(icon, color: Colors.white, size: 25),
    );
  }

  Widget _buildAnnouncementCard(String title, String subtitle, List<Color> gradientColors) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(15),
      decoration: AppTheme.glassDecoration(
        isDark: Provider.of<ThemeProvider>(context, listen: false).isDarkMode,
        borderRadius: 20,
        opacity: 0.1,
      ).copyWith(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
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
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.8), fontSize: 11),
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
               style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 14),
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

  Widget _buildPlaceholder(String title, Color textColor) {
     return Center(child: Text(title, style: TextStyle(color: textColor, fontSize: 20)));
  }
}
