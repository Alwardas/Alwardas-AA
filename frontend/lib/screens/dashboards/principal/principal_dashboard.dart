import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../common/absent_students_screen.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; 
import '../../auth/login_screen.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api_constants.dart';
import 'principal_attendance_screen.dart';
import 'principal_announcements_screen.dart';
import 'principal_notifications_screen.dart';
import '../../../widgets/custom_bottom_nav_bar.dart';
import '../../../widgets/shared_dashboard_announcements.dart';

import 'principal_faculty_screen.dart';
import 'principal_lesson_plans_screen.dart';
import 'principal_requests_screen.dart';
import 'principal_schedule_screen.dart';
import 'principal_timetables_screen.dart';
import '../../common/issue_management_screen.dart';
import '../coordinator/coordinator_department_screen.dart';
import 'principal_menu_tab.dart';
import 'principal_profile_tab.dart';
import 'dart:async';
import '../../../core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PrincipalDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const PrincipalDashboard({super.key, required this.userData});

  @override
  State<PrincipalDashboard> createState() => _PrincipalDashboardState();
}


class _PrincipalDashboardState extends State<PrincipalDashboard> {
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
    _fetchTodayAttendance();
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
          '${ApiConstants.baseUrl}/api/notifications?role=Principal&userId=${user['id']}'));

      if (response.statusCode == 200) {
        final List<dynamic> notifications = json.decode(response.body);
        if (notifications.isEmpty) return;

        final latest = notifications.first;
        final String latestId = latest['id'].toString();

        if (_lastNotifiedId == null) {
          final prefs = await SharedPreferences.getInstance();
          _lastNotifiedId = prefs.getString('last_principal_notification_id');
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
          await prefs.setString('last_principal_notification_id', latestId);
        }
      }
    } catch (e) {
      debugPrint("Principal Notification Polling Error: $e");
    }
  }

  String _getNotificationTitle(String? type) {
    switch (type) {
      case 'HOD_REQUEST':
        return 'HOD Approval Request';
      case 'ANNOUNCEMENT':
        return 'New Announcement';
      case 'ISSUE_REPORTED':
        return 'New Issue Reported';
      case 'SYSTEM_ALERT':
        return 'System Alert';
      default:
        return 'Principal Notification';
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
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

      // Principal gets aggregated stats for the whole college
      final statsUri = Uri.parse('${ApiConstants.baseUrl}/api/attendance/stats').replace(queryParameters: {
        'date': dateStr,
        'session': 'Morning'
      });
      final statsRes = await http.get(statsUri);
      
      final absentUri = Uri.parse('${ApiConstants.baseUrl}/api/attendance/absents').replace(queryParameters: {
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
      debugPrint("Error fetching today attendance (Principal): $e");
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
          title: "College-wide Absentees",
        ),
      ),
    );
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
              PrincipalMenuTab(userData: widget.userData),
              _buildHomeTab(context, cardColor, textColor, subTextColor, isDark),
              PrincipalProfileTab(userData: widget.userData, onLogout: _logout),
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
    // Principal Header Gradient ['#8E2DE2', '#4A00E0']
    final List<Color> headerGradient = isDark ? AppTheme.darkHeaderGradient : [const Color(0xFF8E2DE2), const Color(0xFF4A00E0)];

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
              colors: headerGradient,
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
                         widget.userData['full_name']?.toString().toUpperCase() ?? 'PRINCIPAL', 
                          style: GoogleFonts.poppins(
                            color: Colors.white, 
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                       ),
                     ),
                     const SizedBox(height: 2),
                     Text(
                       'Alwardas Polytechnic - Principal',
                        style: GoogleFonts.poppins(
                          color: Colors.white.withValues(alpha: 0.8), 
                          fontSize: 13,
                        ),
                     ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(30),
                  border: Border.all(color: Colors.white.withOpacity(0.4), width: 1),
                  color: Colors.white.withOpacity(0.1),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrincipalNotificationsScreen())),
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          const Icon(Icons.notifications_none, color: Colors.white, size: 22),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: Container(
                              width: 8, height: 8,
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
                  // 2. Announcements
                  SharedDashboardAnnouncements(userRole: widget.userData['role'] ?? 'Principal'),
                  const SizedBox(height: 15),

                  // Quick Access: Grid Layout
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
                    padding: EdgeInsets.zero,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1.4,
                    ),
                    children: [
                        _buildQuickAccessCard(
                          Icons.calendar_today_outlined,
                          'Attendance',
                          'All Branches',
                          cardColor,
                          const Color(0xFF8E2DE2).withValues(alpha: 0.1), 
                          const Color(0xFF8E2DE2),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrincipalAttendanceScreen())),
                        ),
                        _buildQuickAccessCard(
                          Icons.menu_book,
                          'Syllabus',
                          'Track Progress',
                          cardColor,
                          const Color(0xFF38ef7d).withValues(alpha: 0.1), 
                          const Color(0xFF38ef7d),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => PrincipalLessonPlansScreen(userData: widget.userData))),
                        ),
                        _buildQuickAccessCard(
                          Icons.access_time,
                          'Timetables',
                          'Master View',
                          cardColor,
                          const Color(0xFF606c88).withValues(alpha: 0.1), 
                          const Color(0xFF606c88),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrincipalTimetablesScreen())),
                        ),

                        _buildQuickAccessCard(
                          Icons.event_note,
                          'My Schedule',
                          'Personal',
                          cardColor,
                          const Color(0xFF00d2ff).withValues(alpha: 0.1), 
                          const Color(0xFF00d2ff),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrincipalScheduleScreen())),
                        ),
                        _buildQuickAccessCard(
                          Icons.groups_outlined,
                          'Faculty',
                          'Directory',
                          cardColor,
                          const Color(0xFF38ef7d).withValues(alpha: 0.1), 
                          const Color(0xFF38ef7d),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrincipalFacultyScreen())),
                        ),
                        _buildQuickAccessCard(
                          Icons.business,
                          'Departments',
                          'All Branches',
                          cardColor,
                          const Color(0xFF29B6F6).withValues(alpha: 0.1), 
                          const Color(0xFF29B6F6),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoordinatorDepartmentScreen())),
                        ),
                        _buildQuickAccessCard(
                          Icons.report_problem,
                          'Issues',
                          'Reported Issues',
                          cardColor,
                          const Color(0xFFEF5350).withValues(alpha: 0.1), 
                          const Color(0xFFEF5350),
                          textColor,
                          subTextColor,
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => IssueManagementScreen(userData: widget.userData))),
                        ),
                    ],
                  ),
                  const SizedBox(height: 100), // Additional bottom spacing
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
}
