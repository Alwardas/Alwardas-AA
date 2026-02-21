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
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../core/api_constants.dart';
import 'student_feedback_screen.dart';
import '../../../widgets/custom_bottom_nav_bar.dart';
import '../../../widgets/shared_dashboard_announcements.dart';

class StudentDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const StudentDashboard({super.key, required this.userData});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}

class _StudentDashboardState extends State<StudentDashboard> {
  int _selectedIndex = 1; // Default to Home (index 1)

  @override
  void initState() {
    super.initState();
  }

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
    final bool isHomeTab = _selectedIndex == 1;
    SystemUiOverlayStyle overlayStyle = AppTheme.getAdaptiveOverlayStyle(isHomeTab || isDark);

    return PopScope(
      canPop: _selectedIndex == 1,
      onPopInvoked: (bool didPop) {
        if (didPop) {
          return;
        }
        setState(() {
          _selectedIndex = 1;
        });
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: overlayStyle,
        child: Scaffold(
          extendBody: true,
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
                _buildMenuTab(context, bgColor, cardColor, accentBlue, textColor, subTextColor),
                _buildHomeTab(context, bgColor, cardColor, accentBlue, textColor, subTextColor, isDark),
                StudentProfileTab(userData: widget.userData, onLogout: _logout),
              ],
            ),
          ),
          bottomNavigationBar: CustomBottomNavBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            selectedItemColor: accentBlue,
            unselectedItemColor: Colors.grey,
            backgroundColor: isDark ? const Color(0xFF1C1C2E) : Colors.white,
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.grid_view_rounded), label: 'Menu'),
              BottomNavigationBarItem(icon: Icon(Icons.home_rounded), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.person_rounded), label: 'Profile'),
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
        // 1. Header Section
        Container(
          padding: EdgeInsets.only(
            top: MediaQuery.of(context).padding.top + 10, 
            bottom: 20, 
            left: 24, 
            right: 24
          ),
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              colors: [Color(0xFF1a4ab2), Color(0xFF3b82f6)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.only(
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
                               color: Colors.white70,
                               fontSize: 14,
                               fontWeight: FontWeight.w500,
                             ),
                          ),
                          Text(
                            widget.userData['full_name'] ?? 'Student', 
                             style: GoogleFonts.poppins(
                               color: Colors.white, 
                               fontSize: 20, // Reduced from 24
                               fontWeight: FontWeight.bold,
                             ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'ID: ${widget.userData['login_id'] ?? 'N/A'}',
                             style: GoogleFonts.poppins(
                               color: Colors.white.withOpacity(0.9), 
                               fontSize: 13, // Reduced from 15
                               fontWeight: FontWeight.w500,
                             ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.userData['branch'] ?? 'Engineering',
                             style: GoogleFonts.poppins(
                               color: Colors.white70, 
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
                  SharedDashboardAnnouncements(userRole: widget.userData['role'] ?? 'Student'),
                  const SizedBox(height: 25),

                  // Quick Access: Grid Layout
                  Text(
                    'Quick Access',
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),

                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1.2,
                    ),
                    children: [
                      _buildQuickAccessCard(
                        Icons.menu_book,
                        'My Courses',
                        '4 Active',
                        cardColor,
                        const Color(0xFF3b5998).withValues(alpha: 0.1),
                        const Color(0xFF3b5998),
                        textColor,
                        subTextColor,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => MyCoursesScreen())),
                      ),
                      _buildQuickAccessCard(
                        Icons.calendar_today,
                        'Attendance',
                        '95%',
                        cardColor,
                        const Color(0xFF2ecc71).withValues(alpha: 0.1),
                        const Color(0xFF2ecc71),
                        textColor,
                        subTextColor,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(userData: widget.userData))),
                      ),
                      _buildQuickAccessCard(
                        Icons.schedule,
                        'Time Table',
                        '3 Classes',
                        cardColor,
                        const Color(0xFF9b59b6).withValues(alpha: 0.1),
                        const Color(0xFF9b59b6),
                        textColor,
                        subTextColor,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TimeTableScreen())),
                      ),
                      _buildQuickAccessCard(
                        Icons.insights,
                        'Marks / Results',
                        'View Grades',
                        cardColor,
                        const Color(0xFFe67e22).withValues(alpha: 0.1),
                        const Color(0xFFe67e22),
                        textColor,
                        subTextColor,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentMarksScreen())),
                      ),
                      _buildQuickAccessCard(
                        Icons.report_problem_outlined,
                        'Issues',
                        'Report & Track',
                        cardColor,
                        const Color(0xFFE94057).withValues(alpha: 0.1),
                        const Color(0xFFE94057),
                        textColor,
                        subTextColor,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentCommentsScreen(userData: widget.userData))),
                      ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  // Today's Schedule (Cleaned up)
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
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        ),
                      ],
                      border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '10:00 AM - 11:30 AM',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF00d2ff),
                            fontSize: 13,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Software Engineering',
                          style: GoogleFonts.poppins(
                            color: textColor,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Room 301 (Dr. Lee)',
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
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }



  Widget _buildQuickAccessCard(IconData icon, String title, String subtitle, Color cardColor, Color iconBgColor, Color iconColor, Color textColor, Color subTextColor, {VoidCallback? onTap}) {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
             color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03),
             width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
              blurRadius: 15,
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
                color: iconColor.withValues(alpha: 0.1),
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

  Widget _buildPlaceholder(String title, Color textColor) {
     return Center(child: Text(title, style: TextStyle(color: textColor, fontSize: 20)));
  }

  Widget _buildMenuTab(BuildContext context, Color bgColor, Color cardColor, Color accentBlue, Color textColor, Color subTextColor) {
    final List<Map<String, dynamic>> menuItems = [
      {'label': 'My Courses', 'subtitle': '4 Active', 'icon': Icons.menu_book, 'color': const Color(0xFF3b5998), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => MyCoursesScreen()))},
      {'label': 'Time Table', 'subtitle': '3 Classes', 'icon': Icons.schedule, 'color': const Color(0xFF9b59b6), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => TimeTableScreen()))},
      {'label': 'Attendance', 'subtitle': 'Check status', 'icon': Icons.calendar_today, 'color': const Color(0xFF2ecc71), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(userData: widget.userData)))},
      {'label': 'Marks / Results', 'subtitle': 'View Grades', 'icon': Icons.insights, 'color': const Color(0xFFe67e22), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentMarksScreen()))},
      {'label': 'Issues', 'subtitle': 'Report & Track', 'icon': Icons.report_problem_outlined, 'color': const Color(0xFFE94057), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentCommentsScreen(userData: widget.userData)))},
      {'label': 'My Feedbacks', 'subtitle': 'Reviews', 'icon': Icons.feedback_outlined, 'color': const Color(0xFF1ABC9C), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentFeedbackScreen(userData: widget.userData)))},
    ];

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Menu',
                  style: GoogleFonts.poppins(
                    color: textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  'Access all features',
                  style: GoogleFonts.poppins(
                    color: subTextColor,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                return _buildMenuCard(item, cardColor, textColor, subTextColor);
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(Map<String, dynamic> item, Color cardColor, Color textColor, Color subTextColor) {
    return GestureDetector(
      onTap: item['onTap'],
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: (item['color'] as Color).withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(item['icon'], color: item['color'], size: 24),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item['label'],
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  Text(
                    item['subtitle'],
                    style: GoogleFonts.poppins(
                      fontSize: 12,
                      color: subTextColor,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 20, color: subTextColor),
          ],
        ),
      ),
    );
  }
}
