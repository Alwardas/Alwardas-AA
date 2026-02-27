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
import 'student_announcements_screen.dart';
import 'dart:async';
import '../../../core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class StudentDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const StudentDashboard({super.key, required this.userData});

  @override
  State<StudentDashboard> createState() => _StudentDashboardState();
}


class _StudentDashboardState extends State<StudentDashboard> {
  int _selectedIndex = 1; // Default to Home (index 1)
  Timer? _notificationTimer;
  String? _lastNotifiedId;

  @override
  void initState() {
    super.initState();
    _startNotificationPolling();
    _setupClassReminders();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _startNotificationPolling() {
    _checkNewNotifications(isInitial: true);
    _notificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkNewNotifications(isInitial: false);
    });
  }

  Future<void> _checkNewNotifications({bool isInitial = false}) async {
    try {
      final user = await AuthService.getUserSession();
      if (user == null) return;

      final response = await http.get(Uri.parse(
          '${ApiConstants.baseUrl}/api/notifications?role=Student&userId=${user['id']}'));

      if (response.statusCode == 200) {
        final List<dynamic> notifications = json.decode(response.body);
        if (notifications.isEmpty) return;

        final latest = notifications.first;
        final String latestId = latest['id'].toString();

        if (_lastNotifiedId == null) {
          final prefs = await SharedPreferences.getInstance();
          _lastNotifiedId = prefs.getString('last_student_notification_id');
        }

        if (latestId != _lastNotifiedId) {
          if (!isInitial) {
            if (latest['status'] == 'UNREAD' || latest['status'] == 'PENDING') {
              await NotificationService.showImmediateNotification(
                id: latestId.hashCode,
                title: _getNotificationTitle(latest['type']),
                body: latest['message'] ?? 'New notification received',
                payload: 'notif_${latest['id']}',
              );
            }
          }

          _lastNotifiedId = latestId;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_student_notification_id', latestId);
        }
      }
    } catch (e) {
      debugPrint("Student Notification Polling Error: $e");
    }
  }

  Future<void> _setupClassReminders() async {
    try {
      final user = await AuthService.getUserSession();
      if (user == null) return;
      
      final String branch = user['branch'] ?? 'Computer Engineering';
      final String year = user['year'] ?? '';
      final String section = user['section'] ?? '';

      if (year.isEmpty || branch.isEmpty) return;

      // 1. Fetch Timings
      final timingUri = Uri.parse('${ApiConstants.baseUrl}/api/department/timing').replace(queryParameters: {'branch': branch});
      final timingRes = await http.get(timingUri);
      if (timingRes.statusCode != 200) return;
      final List<dynamic> timings = json.decode(timingRes.body);
      if (timings.isEmpty) return;
      
      final t = timings[0];
      int startHour = t['start_hour'] ?? 9;
      int startMinute = t['start_minute'] ?? 0;
      int classDuration = t['class_duration'] ?? 50;
      int breakDuration = t['short_break_duration'] ?? 10;
      int lunchDuration = t['lunch_duration'] ?? 50;
      List<dynamic> slotConfig = List<dynamic>.from(t['slot_config'] ?? ['P','P','SB','P','P','LB','P','P','SB','P','P']);

      // 2. Map period index to start time
      Map<int, TimeOfDay> periodStartTimes = {};
      DateTime currentTime = DateTime(2026, 1, 1, startHour, startMinute);
      int pNum = 1;
      for (var type in slotConfig) {
        if (type == 'P') {
          periodStartTimes[pNum] = TimeOfDay(hour: currentTime.hour, minute: currentTime.minute);
          currentTime = currentTime.add(Duration(minutes: classDuration));
          pNum++;
        } else if (type == 'SB') {
          currentTime = currentTime.add(Duration(minutes: breakDuration));
        } else if (type == 'LB') {
          currentTime = currentTime.add(Duration(minutes: lunchDuration));
        }
      }

      // 3. Fetch Class Schedule
      final scheduleUri = Uri.parse('${ApiConstants.baseUrl}/api/timetable').replace(queryParameters: {
        'branch': branch,
        'year': year,
        'section': section
      });
      final scheduleRes = await http.get(scheduleUri);
      if (scheduleRes.statusCode != 200) return;
      final List<dynamic> schedule = json.decode(scheduleRes.body);

      // 4. Schedule Notifications
      const mapDays = {'Monday': 1, 'Tuesday': 2, 'Wednesday': 3, 'Thursday': 4, 'Friday': 5, 'Saturday': 6};
      for (var item in schedule) {
        final dayStr = item['day'];
        final pIndex = item['period_index'] ?? item['periodIndex'];
        if (dayStr != null && pIndex != null && mapDays.containsKey(dayStr)) {
          final startTime = periodStartTimes[pIndex];
          if (startTime != null) {
            int targetDay = mapDays[dayStr]!;
            DateTime now = DateTime.now();
            int daysUntil = targetDay - now.weekday;
            if (daysUntil < 0) daysUntil += 7;
            
            DateTime scheduledDateTime = DateTime(
              now.year, now.month, now.day,
              startTime.hour, startTime.minute
            ).add(Duration(days: daysUntil));

            // Set to 1 minute before
            scheduledDateTime = scheduledDateTime.subtract(const Duration(minutes: 1));

            // If the time for today has already passed, move to next week's occurrence
            if (scheduledDateTime.isBefore(now)) {
              scheduledDateTime = scheduledDateTime.add(const Duration(days: 7));
            }

            await NotificationService.scheduleClassNotification(
              id: 'class_${item['id']}'.hashCode,
              title: 'Class Alert!',
              body: 'Upcoming: ${item['subject']} starts in 1 minute.',
              scheduledTime: scheduledDateTime,
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Setup Class Reminders Error (Student): $e");
    }
  }

  String _getNotificationTitle(String? type) {
    switch (type) {
      case 'ATTENDANCE_MARKED':
        return 'Attendance Update';
      case 'ANNOUNCEMENT':
        return 'New Announcement';
      case 'TIMETABLE_CHANGE':
        return 'Timetable Updated';
      case 'LESSON_PLAN_UPDATE':
        return 'Lesson Plan Update';
      case 'ISSUE_RESOLVED':
        return 'Issue Resolved';
      default:
        return 'Student Notification';
    }
  }

  void _logout() async {
     _notificationTimer?.cancel();
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
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark ? AppTheme.darkHeaderGradient : AppTheme.lightHeaderGradient,
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
                               color: Colors.white70,
                               fontSize: 14,
                               fontWeight: FontWeight.w500,
                             ),
                          ),
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              widget.userData['full_name'] ?? 'Student', 
                               style: GoogleFonts.poppins(
                                 color: Colors.white, 
                                 fontSize: 18, // Reduced for a better fit
                                 fontWeight: FontWeight.bold,
                               ),
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
                         onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentNotificationsScreen(userId: widget.userData['id']))),
                         child: _buildHeaderIcon(Icons.notifications_outlined),
                       ),
                       const SizedBox(width: 12),
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
                  const SizedBox(height: 5),

                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
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
                        'Exams / Results',
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
      {'label': 'Announcements', 'subtitle': 'Updates & News', 'icon': Icons.campaign_rounded, 'color': const Color(0xFFf83600), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentAnnouncementsScreen()))},
      {'label': 'Attendance', 'subtitle': 'Check status', 'icon': Icons.calendar_today, 'color': const Color(0xFF2ecc71), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => AttendanceScreen(userData: widget.userData)))},
      {'label': 'My Courses', 'subtitle': '4 Active', 'icon': Icons.menu_book, 'color': const Color(0xFF3b5998), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => MyCoursesScreen()))},
      {'label': 'Time Table', 'subtitle': '3 Classes', 'icon': Icons.schedule, 'color': const Color(0xFF9b59b6), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => TimeTableScreen()))},
      {'label': 'Exams / Results', 'subtitle': 'View Grades', 'icon': Icons.insights, 'color': const Color(0xFFe67e22), 'onTap': () => Navigator.push(context, MaterialPageRoute(builder: (_) => const StudentMarksScreen()))},
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
