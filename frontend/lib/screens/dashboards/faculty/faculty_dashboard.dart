import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../common/absent_students_screen.dart';
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
import '../../common/issue_management_screen.dart';
import 'faculty_exams_screen.dart';
import 'faculty_requests_screen.dart';
import 'faculty_announcements_screen.dart';
import 'faculty_reviews_screen.dart';
import '../coordinator/coordinator_students_screen.dart';
import '../../../widgets/custom_bottom_nav_bar.dart';
import '../../../widgets/shared_dashboard_announcements.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/notification_service.dart';
import 'package:intl/intl.dart';

class FacultyDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const FacultyDashboard({super.key, required this.userData});

  @override
  State<FacultyDashboard> createState() => _FacultyDashboardState();
}

class _FacultyDashboardState extends State<FacultyDashboard> {
  int _selectedIndex = 1; // Default to Home
  Timer? _notificationTimer;
  String? _lastNotifiedId;

  List<Map<String, dynamic>> _todaySchedule = [];
  List<Map<String, dynamic>> _todayPracticals = [];

  // Attendance Stats
  int _absentCount = 0;
  List<dynamic> _absentStudents = [];
  bool _isLoadingAttendance = false;

  @override
  void initState() {
    super.initState();
    _startNotificationPolling();
    _setupClassReminders();
    _fetchTodayAttendance();
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
      final timingUri =
          Uri.parse('${ApiConstants.baseUrl}/api/department/timing')
              .replace(queryParameters: {'branch': branch});
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
      List<dynamic> slotConfig = List<dynamic>.from(t['slot_config'] ??
          ['P', 'P', 'SB', 'P', 'P', 'LB', 'P', 'P', 'SB', 'P', 'P']);

      // 2. Map period index to start time
      Map<int, TimeOfDay> periodStartTimes = {};
      DateTime currentTime = DateTime(2026, 1, 1, startHour, startMinute);
      int pNum = 1;
      for (var type in slotConfig) {
        if (type == 'P') {
          periodStartTimes[pNum] =
              TimeOfDay(hour: currentTime.hour, minute: currentTime.minute);
          currentTime = currentTime.add(Duration(minutes: classDuration));
          pNum++;
        } else if (type == 'SB') {
          currentTime = currentTime.add(Duration(minutes: breakDuration));
        } else if (type == 'LB') {
          currentTime = currentTime.add(Duration(minutes: lunchDuration));
        }
      }

      // 3. Fetch My Schedule
      final scheduleUri = Uri.parse('${ApiConstants.baseUrl}/api/timetable')
          .replace(queryParameters: {'facultyId': fid});
      final scheduleRes = await http.get(scheduleUri);
      if (scheduleRes.statusCode != 200) return;
      final List<dynamic> schedule = json.decode(scheduleRes.body);

      // 4. Schedule Notifications & Display
      const mapDays = {
        'Monday': 1,
        'Tuesday': 2,
        'Wednesday': 3,
        'Thursday': 4,
        'Friday': 5,
        'Saturday': 6
      };

      String todayStr = DateFormat('EEEE').format(DateTime.now());
      List<Map<String, dynamic>> tempNormal = [];
      List<Map<String, dynamic>> tempPractical = [];

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

            DateTime scheduledDateTime = DateTime(now.year, now.month, now.day,
                    startTime.hour, startTime.minute)
                .add(Duration(days: daysUntil));

            // Set to 1 minute before
            scheduledDateTime =
                scheduledDateTime.subtract(const Duration(minutes: 1));

            // If the time for today has already passed, move to next week's occurrence
            if (scheduledDateTime.isBefore(now)) {
              scheduledDateTime =
                  scheduledDateTime.add(const Duration(days: 7));
            }

            await NotificationService.scheduleClassNotification(
              id: 'class_${item['id']}'.hashCode,
              title: 'Class Reminder (1 min to go)',
              body:
                  'Upcoming: ${item['subject']} for ${item['branch']} ${item['year']} ${item['section']}',
              scheduledTime: scheduledDateTime,
            );

            if (dayStr == todayStr) {
              String hourStr = startTime.hour > 12
                  ? (startTime.hour - 12).toString()
                  : (startTime.hour == 0 ? "12" : startTime.hour.toString());
              String amPmStr = startTime.hour >= 12 ? 'PM' : 'AM';
              String classTime =
                  "$hourStr:${startTime.minute.toString().padLeft(2, '0')} $amPmStr";
              Map<String, dynamic> classData = {
                'subject': item['subject'],
                'time': classTime,
                'year': item['year'] ?? '',
                'branch': item['branch'] ?? '',
                'section': item['section'] ?? '',
                'pIndex': pIndex,
              };

              tempNormal.add(classData);
              if (item['subject']
                      .toString()
                      .toLowerCase()
                      .contains('practical') ||
                  item['subject'].toString().toLowerCase().contains('lab')) {
                tempPractical.add(classData);
              }
            }
          }
        }
      }

      tempNormal
          .sort((a, b) => (a['pIndex'] as int).compareTo(b['pIndex'] as int));
      tempPractical
          .sort((a, b) => (a['pIndex'] as int).compareTo(b['pIndex'] as int));

      if (mounted) {
        setState(() {
          _todaySchedule = tempNormal;
          _todayPracticals = tempPractical;
        });
      }
    } catch (e) {
      debugPrint("Setup Class Reminders Error (Faculty): $e");
    }
  }

  Future<void> _fetchTodayAttendance() async {
    if (mounted) setState(() => _isLoadingAttendance = true);
    try {
      final user = await AuthService.getUserSession();
      if (user == null) return;
      final branch = user['branch'] ?? 'Computer Engineering';
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Try Morning session by default
      final statsUri = Uri.parse('${ApiConstants.baseUrl}/api/attendance/stats')
          .replace(queryParameters: {
        'branch': branch,
        'date': dateStr,
        'session': 'Morning'
      });
      final statsRes = await http.get(statsUri);

      final absentUri =
          Uri.parse('${ApiConstants.baseUrl}/api/attendance/absents').replace(
              queryParameters: {
            'branch': branch,
            'date': dateStr,
            'session': 'Morning'
          });
      final absentRes = await http.get(absentUri);

      if (statsRes.statusCode == 200 &&
          absentRes.statusCode == 200 &&
          mounted) {
        final stats = json.decode(statsRes.body);
        final absents = json.decode(absentRes.body);
        setState(() {
          _absentCount = stats['totalAbsent'] ?? 0;
          _absentStudents = absents;
        });
      }
    } catch (e) {
      debugPrint("Error fetching today attendance (Faculty): $e");
    } finally {
      if (mounted) setState(() => _isLoadingAttendance = false);
    }
  }

  void _showAbsentList() {
    if (_absentStudents.isEmpty && _absentCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text("No attendance records for today yet.")));
      return;
    }
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => AbsentStudentsScreen(
          absents: _absentStudents,
          title: "Today's Absentees",
        ),
      ),
    );
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
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color bgColor = theme.scaffoldBackgroundColor;
    final Color cardColor = isDark ? const Color(0xFF222240) : Colors.white;
    final Color textColor = theme.colorScheme.onSurface;
    final Color subTextColor = theme.colorScheme.secondary;
    final Color tint = theme.primaryColor;

    // Status Bar Logic - Index 1 is Home
    final bool isHomeTab = _selectedIndex == 1;
    SystemUiOverlayStyle overlayStyle =
        AppTheme.getAdaptiveOverlayStyle(isHomeTab || isDark);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
      child: PopScope(
        canPop: _selectedIndex == 1,
        onPopInvoked: (bool didPop) {
          if (didPop) return;
          setState(() => _selectedIndex = 1);
        },
        child: Scaffold(
          extendBody: true,
          backgroundColor: bgColor,
          body: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: isDark
                    ? AppTheme.darkBodyGradient
                    : AppTheme.lightBodyGradient,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: IndexedStack(
              index: _selectedIndex,
              children: [
                _buildMenuTab(
                    context, isDark, textColor, subTextColor, cardColor),
                _buildHomeTab(
                    context, isDark, textColor, subTextColor, cardColor),
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
              BottomNavigationBarItem(
                  icon: Icon(Icons.grid_view_rounded), label: 'Menu'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.home_rounded), label: 'Home'),
              BottomNavigationBarItem(
                  icon: Icon(Icons.person_rounded), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context, bool isDark, Color textColor,
      Color subTextColor, Color cardColor) {
    return Column(
      children: [
        // 1. Header Section
        Container(
          padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: 20,
              left: 24,
              right: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark ? AppTheme.darkHeaderGradient : [const Color(0xFF6B48FF), const Color(0xFF4B83FF), const Color(0xFF1EC9F8)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            border: isDark ? Border(bottom: BorderSide(color: Colors.white.withOpacity(0.1), width: 1)) : null,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(isDark ? 0.4 : 0.1),
                blurRadius: 25,
                offset: const Offset(0, 12),
              ),
            ],
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(40),
              bottomRight: Radius.circular(40),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Welcome Back,',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.9),
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        widget.userData['full_name']
                                ?.toString()
                                .toUpperCase() ??
                            'FACULTY',
                        style: GoogleFonts.poppins(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${widget.userData['branch'] ?? 'Department'} ( Faculty )',
                      style: GoogleFonts.poppins(
                        color: Colors.white.withValues(alpha: 0.8),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.4), width: 1),
                  color: Colors.white.withOpacity(0.1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  const FacultyNotificationsScreen())),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications_none,
                              color: Colors.white, size: 22),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
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
                  SharedDashboardAnnouncements(
                      userRole: widget.userData['role'] ?? 'Faculty'),
                  const SizedBox(height: 15),

                  // Quick Access
                  Row(
                    children: [
                      Text(
                        'Quick Access',
                        style: GoogleFonts.poppins(
                          color: textColor,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Container(
                          height: 1,
                          color: Colors.grey.withValues(alpha: 0.2),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1.4,
                    ),
                    children: [
                      _buildQuickAccessCard(
                        Icons.menu_book_outlined,
                        'My Classes',
                        '',
                        cardColor,
                        const Color(0xFF3b5998).withValues(alpha: 0.1),
                        const Color(0xFF3b5998),
                        textColor,
                        subTextColor,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const FacultyClassesScreen())),
                      ),
                      _buildQuickAccessCard(
                        Icons.schedule,
                        'Schedule',
                        '',
                        cardColor,
                        const Color(0xFF9b59b6).withValues(alpha: 0.1),
                        const Color(0xFF9b59b6),
                        textColor,
                        subTextColor,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => const FacultyScheduleScreen())),
                      ),
                      _buildQuickAccessCard(
                        Icons.check_circle_outline,
                        'Attendance',
                        '',
                        cardColor,
                        const Color(0xFF2ecc71).withValues(alpha: 0.1),
                        const Color(0xFF2ecc71),
                        textColor,
                        subTextColor,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => FacultyAttendanceScreen(
                                    userData: widget.userData))),
                      ),
                      _buildQuickAccessCard(
                        Icons.people_outline,
                        'Students',
                        '',
                        cardColor,
                        const Color(0xFF3498db).withValues(alpha: 0.1),
                        const Color(0xFF3498db),
                        textColor,
                        subTextColor,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) =>
                                    const CoordinatorStudentsScreen())),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Bottom Horizontal Cards
                  Row(
                    children: [
                      Expanded(
                        child: _buildHorizontalCard(
                          Icons.report_problem_outlined,
                          'Issues',
                          '',
                          const Color(0xFFE94057),
                          cardColor,
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => IssueManagementScreen(
                                      userData: widget.userData))),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildHorizontalCard(
                          Icons.request_page_outlined,
                          'Requests',
                          '',
                          const Color(0xFF9B59B6),
                          cardColor,
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => FacultyRequestsScreen(
                                      userData: widget.userData))),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),

                  // Today's Schedule
                  if (_todaySchedule.isNotEmpty) ...[
                    Text(
                      "Today's Schedule",
                      style: GoogleFonts.poppins(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._todaySchedule.map((cls) =>
                        _buildClassCard(cls, isDark, textColor, subTextColor)),
                  ] else ...[
                    Text(
                      "Today's Schedule",
                      style: GoogleFonts.poppins(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text("No classes scheduled for today.",
                        style: GoogleFonts.poppins(color: subTextColor)),
                  ],

                  if (_todayPracticals.isNotEmpty) ...[
                    const SizedBox(height: 15),
                    Text(
                      "Today's Practical Schedule",
                      style: GoogleFonts.poppins(
                        color: textColor,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    ..._todayPracticals.map((cls) =>
                        _buildClassCard(cls, isDark, textColor, subTextColor)),
                  ],

                  const SizedBox(height: 100),
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
        border:
            Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildQuickAccessCard(
      IconData icon,
      String title,
      String subtitle,
      Color cardColor,
      Color iconBgColor,
      Color iconColor,
      Color textColor,
      Color subTextColor,
      {VoidCallback? onTap}) {
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.1),
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
                style: GoogleFonts.poppins(
                    color: textColor,
                    fontWeight: FontWeight.w600,
                    fontSize: 13),
              ),
            ),
            const SizedBox(height: 2),
            if (subtitle.isNotEmpty)
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

  Widget _buildHorizontalCard(IconData icon, String title, String subtitle,
      Color color, Color cardColor, Color textColor, Color subTextColor,
      {VoidCallback? onTap}) {
    final isDark =
        Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color:
                isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03),
            width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark
                  ? Colors.black.withValues(alpha: 0.2)
                  : Colors.grey.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.poppins(
                        color: textColor,
                        fontWeight: FontWeight.bold,
                        fontSize: 13),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(
                          color: subTextColor, fontSize: 10),
                    ),
                ],
              ),
            ),
            Icon(Icons.chevron_right, size: 16, color: subTextColor),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuTab(BuildContext context, bool isDark, Color textColor,
      Color subTextColor, Color cardColor) {
    final List<Map<String, dynamic>> menuItems = [
      {
        'icon': Icons.menu_book_outlined,
        'title': 'Classes',
        'color': const Color(0xFF3b5998),
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const FacultyClassesScreen())),
      },
      {
        'icon': Icons.schedule,
        'title': 'Schedule',
        'color': const Color(0xFF9b59b6),
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const FacultyScheduleScreen())),
      },
      {
        'icon': Icons.check_circle_outline,
        'title': 'Attendance',
        'color': const Color(0xFF2ecc71),
        'onTap': () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    FacultyAttendanceScreen(userData: widget.userData))),
      },
      {
        'icon': Icons.campaign_outlined,
        'title': 'Announcements',
        'color': const Color(0xFFF39C12),
        'onTap': () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const FacultyAnnouncementsScreen())),
      },
      {
        'icon': Icons.report_problem_outlined,
        'title': 'Issues',
        'color': const Color(0xFFE74C3C),
        'onTap': () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    IssueManagementScreen(userData: widget.userData))),
      },
      {
        'icon': Icons.request_page_outlined,
        'title': 'Requests',
        'color': const Color(0xFF9B59B6),
        'onTap': () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) =>
                    FacultyRequestsScreen(userData: widget.userData))),
      },
      {
        'icon': Icons.rate_review_outlined,
        'title': 'Feedbacks',
        'color': const Color(0xFF1ABC9C),
        'onTap': () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => const FacultyReviewsScreen())),
      },
      {
        'icon': Icons.people_outline,
        'title': 'Students',
        'color': const Color(0xFF3498db),
        'onTap': () => Navigator.push(
            context,
            MaterialPageRoute(
                builder: (_) => const CoordinatorStudentsScreen())),
      },
    ];

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Text(
              'Menu',
              style: GoogleFonts.poppins(
                color: textColor,
                fontSize: 28,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              physics: const BouncingScrollPhysics(),
              itemCount: menuItems.length,
              itemBuilder: (context, index) {
                final item = menuItems[index];
                return InkWell(
                  onTap: item['onTap'] as VoidCallback,
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isDark
                            ? Colors.white10
                            : Colors.black.withValues(alpha: 0.05),
                        width: 1,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                (item['color'] as Color).withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(item['icon'] as IconData,
                              color: item['color'] as Color, size: 28),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Text(
                            item['title'] as String,
                            style: GoogleFonts.poppins(
                              color: textColor,
                              fontWeight: FontWeight.w600,
                              fontSize: 17,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.chevron_right_rounded,
                          color: subTextColor.withValues(alpha: 0.5),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildClassCard(Map<String, dynamic> cls, bool isDark, Color textColor,
      Color subTextColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 15),
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
        border: Border.all(
            color:
                isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            cls['time'] ?? '',
            style: GoogleFonts.poppins(
              color: const Color(0xFF00d2ff),
              fontSize: 13,
              fontWeight: FontWeight.bold,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            cls['subject'] ?? '',
            style: GoogleFonts.poppins(
              color: textColor,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          if (cls['year'] != null && cls['year'].toString().isNotEmpty)
            Text(
              'For: ${cls['branch']} ${cls['year']} ${cls['section']}',
              style: GoogleFonts.poppins(
                color: subTextColor,
                fontSize: 14,
              ),
            ),
        ],
      ),
    );
  }
}
