import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../../common/absent_students_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../auth/login_screen.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import 'hod_announcements_screen.dart';
import 'hod_notifications_screen.dart';
import 'hod_courses_screen.dart';
import 'hod_attendance_screen.dart';
import 'hod_menu_tab.dart';
import 'hod_profile_tab.dart';
import 'hod_faculty_screen.dart';
import 'hod_timetables_screen.dart';
import 'hod_schedule_screen.dart';
import 'hod_requests_screen.dart';
import '../../common/issue_management_screen.dart';
import 'hod_department_screen.dart';
import 'hod_syllabus_management_screen.dart';
import '../../../widgets/custom_bottom_nav_bar.dart';
import '../../../widgets/shared_dashboard_announcements.dart';
import 'dart:async';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/notification_service.dart';

class HodDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const HodDashboard({super.key, required this.userData});

  @override
  State<HodDashboard> createState() => _HodDashboardState();
}


class _HodDashboardState extends State<HodDashboard> {
  int _selectedIndex = 1; // Default to Home (index 1)
  Timer? _notificationTimer;
  String? _lastNotifiedId;

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
    // Initial fetch to set the baseline ID without showing a notification
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

      final response = await http.get(Uri.parse(
          '${ApiConstants.baseUrl}/api/notifications?role=HOD&branch=${Uri.encodeComponent(user['branch'] ?? '')}&userId=${user['id']}'));

      if (response.statusCode == 200) {
        final List<dynamic> notifications = json.decode(response.body);
        if (notifications.isEmpty) return;

        // The first notification is the newest (sorted by created_at DESC)
        final latest = notifications.first;
        final String latestId = latest['id'].toString();

        // Load last notified ID if not in memory
        if (_lastNotifiedId == null) {
          final prefs = await SharedPreferences.getInstance();
          _lastNotifiedId = prefs.getString('last_hod_notification_id');
        }

        if (latestId != _lastNotifiedId) {
          if (!isInitial) {
            // New notification found AND it's not the very first check of this session
            // Only notify if it's UNREAD or PENDING (some backend endpoints use PENDING)
            if (latest['status'] == 'UNREAD' || latest['status'] == 'PENDING') {
              await NotificationService.showImmediateNotification(
                id: latestId.hashCode,
                title: _getNotificationTitle(latest['type']),
                body: latest['message'] ?? 'New request received',
                payload: 'notif_${latest['id']}',
              );
            }
          }

          // Update last notified ID
          _lastNotifiedId = latestId;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_hod_notification_id', latestId);
        }
      }
    } catch (e) {
      debugPrint("Notification Polling Error: $e");
    }
  }

  Future<void> _setupClassReminders() async {
    try {
      final user = await AuthService.getUserSession();
      if (user == null) return;
      final String fid = user['login_id'] ?? user['id'] ?? '';
      final String branch = user['branch'] ?? 'Computer Engineering';

      // 1. Fetch Department Timings
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
            // Find next occurrence of this day
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

            // If the time for today has already passed, move to next week
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
      debugPrint("Setup Class Reminders Error: $e");
    }
  }

  String _getNotificationTitle(String? type) {
    switch (type) {
      case 'USER_APPROVAL':
        return 'New User Approval';
      case 'PROFILE_UPDATE_REQUEST':
        return 'Profile Update Request';
      case 'SUBJECT_APPROVAL':
        return 'Subject Approval Required';
      case 'ATTENDANCE_CORRECTION':
        return 'Attendance Correction';
      case 'ISSUE_ASSIGNED':
        return 'New Issue Reported';
      default:
        return 'HOD Notification';
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

  Future<void> _fetchTodayAttendance() async {
    if (mounted) setState(() => _isLoadingAttendance = true);
    try {
      final user = await AuthService.getUserSession();
      if (user == null) return;
      final branch = user['branch'] ?? 'Computer Engineering';
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      final statsUri = Uri.parse('${ApiConstants.baseUrl}/api/attendance/stats').replace(queryParameters: {
        'branch': branch,
        'date': dateStr,
        'session': 'Morning'
      });
      final statsRes = await http.get(statsUri);
      
      final absentUri = Uri.parse('${ApiConstants.baseUrl}/api/attendance/absents').replace(queryParameters: {
        'branch': branch,
        'date': dateStr,
        'session': 'Morning'
      });
      final absentRes = await http.get(absentUri);

      if (statsRes.statusCode == 200 && absentRes.statusCode == 200 && mounted) {
        final stats = json.decode(statsRes.body);
        final absents = json.decode(absentRes.body);
        setState(() {
          _absentCount = stats['totalAbsent'] ?? 0;
          _absentStudents = absents;
        });
      }
    } catch (e) {
      debugPrint("Error fetching today attendance (HOD): $e");
    } finally {
      if (mounted) setState(() => _isLoadingAttendance = false);
    }
  }

  void _showAbsentList() {
    if (_absentStudents.isEmpty && _absentCount == 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No attendance records for today yet.")));
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
              HodMenuTab(userData: widget.userData),
              _buildHomeTab(context, cardColor, textColor, subTextColor, isDark),
              HodProfileTab(userData: widget.userData, onLogout: _logout),
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
    );
  }

  Widget _buildHomeTab(BuildContext context, Color cardColor, Color textColor, Color subTextColor, bool isDark) {
    // Determine Header Icons based on theme
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
                             fontSize: 18,
                             fontWeight: FontWeight.w600,
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
                  // 2. Announcements
                  SharedDashboardAnnouncements(userRole: widget.userData['role'] ?? 'HOD'),
                  const SizedBox(height: 15),


                  // 3. Quick Access
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
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HodSyllabusManagementScreen(userData: widget.userData))),
                    child: _buildProgressCard(textColor, subTextColor, isDark)
                  ),
                  const SizedBox(height: 25),

                  GridView(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1.4,
                    ),
                    children: [
                        _buildQuickAccessCard(
                          Icons.check_circle_outline,
                          'Attendance',
                          '',
                          cardColor,
                          const Color(0xFF2ecc71).withValues(alpha: 0.1), 
                          const Color(0xFF2ecc71),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HODAttendanceScreen())),
                        ),
                        _buildQuickAccessCard(
                          Icons.book,
                          'My Courses',
                          '',
                          cardColor,
                          Colors.blue.withValues(alpha: 0.1),
                          Colors.blue,
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HodCoursesScreen())),
                        ),
                        _buildQuickAccessCard(
                          Icons.schedule,
                          'Timetables',
                          '',
                          cardColor,
                          const Color(0xFF606c88).withValues(alpha: 0.1), 
                          const Color(0xFF606c88),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HodTimetablesScreen())),
                        ),
                        _buildQuickAccessCard(
                          Icons.business_outlined,
                          'Department',
                          '',
                          cardColor,
                          const Color(0xFF38ef7d).withValues(alpha: 0.1), 
                          const Color(0xFF38ef7d),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HodDepartmentScreen(userData: widget.userData))),
                        ),
                    ],
                  ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                      Expanded(
                        child: _buildHorizontalCard(
                          Icons.report_problem_outlined,
                          'Issues',
                          '',
                          Colors.red,
                          cardColor,
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IssueManagementScreen(userData: widget.userData))),
                        ),
                      ),
                      const SizedBox(width: 15),
                      Expanded(
                        child: _buildHorizontalCard(
                          Icons.mail_outline,
                          'Requests',
                          '',
                          Colors.orange,
                          cardColor,
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => HodRequestsScreen(userData: widget.userData))),
                        ),
                      ),
                    ],
                  ),
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
  Widget _buildProgressCard(Color textColor, Color subTextColor, bool isDark) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Over All Branch Progress',
                style: GoogleFonts.poppins(
                  color: textColor,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: const Color(0xFF6B48FF).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'On Track',
                  style: GoogleFonts.poppins(
                    color: const Color(0xFF6B48FF),
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Syllabus Completion',
                          style: GoogleFonts.poppins(
                            color: subTextColor,
                            fontSize: 13,
                          ),
                        ),
                        Text(
                          '74%',
                          style: GoogleFonts.poppins(
                            color: textColor,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Stack(
                      children: [
                        Container(
                          height: 8,
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                        Container(
                          height: 8,
                          width: MediaQuery.of(context).size.width * 0.5, // Approx 74% relative to container width
                          decoration: BoxDecoration(
                            gradient: const LinearGradient(
                              colors: [Color(0xFF6B48FF), Color(0xFF1EC9F8)],
                            ),
                            borderRadius: BorderRadius.circular(4),
                            boxShadow: [
                              BoxShadow(
                                color: const Color(0xFF6B48FF).withValues(alpha: 0.3),
                                blurRadius: 8,
                                offset: const Offset(0, 4),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 25),
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: const Color(0xFF6B48FF).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.auto_graph_rounded,
                  color: Color(0xFF6B48FF),
                  size: 26,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
  Widget _buildHorizontalCard(IconData icon, String title, String subtitle, Color color, Color cardColor, Color textColor, Color subTextColor, {VoidCallback? onTap}) {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
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
                    style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: GoogleFonts.poppins(color: subTextColor, fontSize: 10),
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
}
