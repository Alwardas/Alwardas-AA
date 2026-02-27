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
import 'faculty_issues_screen.dart';
import 'faculty_exams_screen.dart';
import 'faculty_requests_screen.dart';
import 'faculty_announcements_screen.dart';
import 'faculty_reviews_screen.dart';
import '../../../widgets/custom_bottom_nav_bar.dart';
import '../../../widgets/shared_dashboard_announcements.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/notification_service.dart';

class FacultyDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const FacultyDashboard({super.key, required this.userData});

  @override
  State<FacultyDashboard> createState() => _FacultyDashboardState();
}


class _FacultyDashboardState extends State<FacultyDashboard> {
  int _selectedIndex = 1; // Default to Home (Dashboard)
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
    // Initial fetch to set baseline ID
    _checkNewNotifications(isInitial: true);
    // Poll every 30 seconds
    _notificationTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      _checkNewNotifications(isInitial: false);
    });
  }

  Future<void> _checkNewNotifications({bool isInitial = false}) async {
    try {
      final user = await AuthService.getUserSession();
      if (user == null) return;

      final role = user['role'] ?? 'Faculty';
      final branch = user['branch'] ?? '';
      final userId = user['id'];

      final response = await http.get(Uri.parse(
          '${ApiConstants.baseUrl}/api/notifications?role=$role&branch=${Uri.encodeComponent(branch)}&userId=$userId'));

      if (response.statusCode == 200) {
        final List<dynamic> notifications = json.decode(response.body);
        if (notifications.isEmpty) return;

        final latest = notifications.first;
        final String latestId = latest['id'].toString();

        if (_lastNotifiedId == null) {
          final prefs = await SharedPreferences.getInstance();
          _lastNotifiedId = prefs.getString('last_faculty_notification_id');
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
          await prefs.setString('last_faculty_notification_id', latestId);
        }
      }
    } catch (e) {
      debugPrint("Faculty Notification Polling Error: $e");
    }
  }

  Future<void> _setupClassReminders() async {
    try {
      final user = await AuthService.getUserSession();
      if (user == null) return;
      final String fid = user['login_id'] ?? user['id'] ?? '';
      final String branch = user['branch'] ?? 'Computer Engineering';

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

      // 3. Fetch My Schedule
      final scheduleUri = Uri.parse('${ApiConstants.baseUrl}/api/timetable').replace(queryParameters: {'facultyId': fid});
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
              title: 'Class Reminder (1 min to go)',
              body: 'Upcoming: ${item['subject']} for ${item['branch']} ${item['year']} ${item['section']}',
              scheduledTime: scheduledDateTime,
            );
          }
        }
      }
    } catch (e) {
      debugPrint("Setup Class Reminders Error (Faculty): $e");
    }
  }

  String _getNotificationTitle(String? type) {
    switch (type) {
      case 'ISSUE_ASSIGNED':
        return 'New Issue Allocated';
      case 'ISSUE_RESOLVED':
        return 'Issue Resolved';
      case 'ANNOUNCEMENT':
        return 'New Announcement';
      case 'ATTENDANCE_CORRECTION':
        return 'Attendance Request';
      case 'LEAVE_STATUS':
        return 'Leave Update';
      default:
        return 'Faculty Notification';
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
      child: PopScope(
        canPop: _selectedIndex == 1,
        onPopInvoked: (didPop) {
          if (didPop) return;
          setState(() => _selectedIndex = 1);
        },
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
                _buildMenuTab(context, isDark, textColor, subTextColor, cardColor),
                _buildHomeTab(context, isDark, textColor, subTextColor, cardColor),
                FacultyProfileScreen(userData: widget.userData),
              ],
            ),
          ),
          bottomNavigationBar: CustomBottomNavBar(
            currentIndex: _selectedIndex,
            onTap: (index) => setState(() => _selectedIndex = index),
            selectedItemColor: tint,
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

  Widget _buildHomeTab(BuildContext context, bool isDark, Color textColor, Color subTextColor, Color cardColor) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final List<Color> headerGradient = isDark 
        ? [const Color(0xFF343e52), const Color(0xFF3880ec)] 
        : [const Color(0xFF824abe), const Color(0xFF17b1d8)];

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
                             color: Colors.white70, 
                             fontSize: 18,
                             fontWeight: FontWeight.w600,
                           ),
                         ),
                         FittedBox(
                           fit: BoxFit.scaleDown,
                           alignment: Alignment.centerLeft,
                           child: Text(
                             widget.userData['full_name'] ?? 'Faculty',
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
                       const SizedBox(width: 10),
                       GestureDetector(
                         onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacultyNotificationsScreen())),
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
                  SharedDashboardAnnouncements(userRole: widget.userData['role'] ?? 'Faculty'),
                  const SizedBox(height: 25),

                  // Quick Access
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
                          Icons.menu_book_outlined,
                          'My Classes',
                          'Manage',
                          cardColor,
                          const Color(0xFF3b5998).withValues(alpha: 0.1), 
                          const Color(0xFF3b5998),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacultyClassesScreen())),
                        ),
                        _buildQuickAccessCard(
                          Icons.schedule,
                          'Schedule',
                          'View',
                          cardColor,
                          const Color(0xFF9b59b6).withValues(alpha: 0.1), 
                          const Color(0xFF9b59b6),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacultyScheduleScreen())),
                        ),
                        _buildQuickAccessCard(
                          Icons.check_circle_outline,
                          'Attendance',
                          'Post',
                          cardColor,
                          const Color(0xFF2ecc71).withValues(alpha: 0.1), 
                          const Color(0xFF2ecc71),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FacultyAttendanceScreen(userData: widget.userData))),
                        ),
                        _buildQuickAccessCard(
                          Icons.person_outline,
                          'Profile',
                          'Details',
                          cardColor,
                          const Color(0xFFf1c40f).withValues(alpha: 0.1), 
                          const Color(0xFFf1c40f),
                          textColor,
                          subTextColor,
                          onTap: () => setState(() => _selectedIndex = 2),
                        ),
                    ],
                  ),

                  const SizedBox(height: 25),

                  // Today's Schedule
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
  Widget _buildMenuTab(BuildContext context, bool isDark, Color textColor, Color subTextColor, Color cardColor) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(24.0),
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
            const SizedBox(height: 10),
            Text(
              'Access all features',
              style: GoogleFonts.poppins(
                color: subTextColor,
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 25),
            Expanded(
              child: GridView.count(
                crossAxisCount: 2,
                crossAxisSpacing: 15,
                mainAxisSpacing: 15,
                childAspectRatio: 1.2,
                children: [
                  _buildQuickAccessCard(
                    Icons.menu_book_outlined,
                    'Classes',
                    'Manage',
                    cardColor,
                    const Color(0xFF3b5998).withValues(alpha: 0.1),
                    const Color(0xFF3b5998),
                    textColor,
                    subTextColor,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacultyClassesScreen())),
                  ),
                  _buildQuickAccessCard(
                    Icons.schedule,
                    'Schedule',
                    'View',
                    cardColor,
                    const Color(0xFF9b59b6).withValues(alpha: 0.1),
                    const Color(0xFF9b59b6),
                    textColor,
                    subTextColor,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacultyScheduleScreen())),
                  ),
                  _buildQuickAccessCard(
                    Icons.check_circle_outline,
                    'Attendance',
                    'Post',
                    cardColor,
                    const Color(0xFF2ecc71).withValues(alpha: 0.1),
                    const Color(0xFF2ecc71),
                    textColor,
                    subTextColor,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FacultyAttendanceScreen(userData: widget.userData))),
                  ),

                   _buildQuickAccessCard(
                    Icons.campaign_outlined,
                    'Announcements',
                    'News',
                    cardColor,
                    const Color(0xFFF39C12).withValues(alpha: 0.1),
                    const Color(0xFFF39C12),
                    textColor,
                    subTextColor,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacultyAnnouncementsScreen())),
                  ),
                   _buildQuickAccessCard(
                    Icons.report_problem_outlined,
                    'Issues',
                    'Report',
                    cardColor,
                    const Color(0xFFE74C3C).withValues(alpha: 0.1),
                    const Color(0xFFE74C3C),
                    textColor,
                    subTextColor,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => FacultyIssuesScreen(userData: widget.userData))),
                  ),
                   _buildQuickAccessCard(
                    Icons.assignment_outlined,
                    'Exams',
                    'Manage',
                    cardColor,
                    const Color(0xFF3498DB).withValues(alpha: 0.1),
                    const Color(0xFF3498DB),
                    textColor,
                    subTextColor,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacultyExamsScreen())),
                  ),
                   _buildQuickAccessCard(
                    Icons.request_page_outlined,
                    'Requests',
                    'Pending',
                    cardColor,
                    const Color(0xFF9B59B6).withValues(alpha: 0.1),
                    const Color(0xFF9B59B6),
                    textColor,
                    subTextColor,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacultyRequestsScreen())),
                  ),
                   _buildQuickAccessCard(
                    Icons.rate_review_outlined,
                    'Reviews',
                    'Feedback',
                    cardColor,
                    const Color(0xFF1ABC9C).withValues(alpha: 0.1),
                    const Color(0xFF1ABC9C),
                    textColor,
                    subTextColor,
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacultyReviewsScreen())),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
