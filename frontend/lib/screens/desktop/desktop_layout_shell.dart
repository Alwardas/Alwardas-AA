import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../theme/theme_extensions.dart';

import '../../core/providers/desktop_providers.dart';
import '../../core/services/hive_service.dart';
import 'shared-web/desktop_dashboard_view.dart';
import 'coordinator-web/desktop_student_management_view.dart';
import 'coordinator-web/desktop_attendance_view.dart';
import 'coordinator-web/desktop_examination_view.dart';
import 'accountant-web/desktop_fee_management_view.dart';
import 'coordinator-web/desktop_faculty_management_view.dart';
import 'coordinator-web/desktop_coordinator_academics_view.dart';
import 'shared-web/desktop_communication_view.dart';
import 'principal-web/desktop_principal_analytics_view.dart';
import 'principal-web/desktop_reports_view.dart';
import 'admin-web/desktop_user_management_view.dart';
import 'admin-web/desktop_audit_logs_view.dart';

// HOD custom desktop views
import 'hod-web/desktop_hod_dashboard_view.dart';
import 'hod-web/desktop_hod_requests_view.dart';
import 'hod-web/desktop_hod_timetable_view.dart';
import 'hod-web/desktop_hod_syllabus_view.dart';
import 'hod-web/desktop_hod_issues_view.dart';
import 'hod-web/desktop_hod_admission_view.dart';

class DesktopLayoutShell extends ConsumerWidget {
  final Map<String, dynamic> userData;

  const DesktopLayoutShell({super.key, required this.userData});

  static final List<Map<String, dynamic>> sidebarItems = [
    {'name': 'Dashboard', 'icon': Icons.dashboard_outlined, 'activeIcon': Icons.dashboard},
    {'name': 'Admissions', 'icon': Icons.app_registration_outlined, 'activeIcon': Icons.app_registration},
    {'name': 'Students', 'icon': Icons.people_outline, 'activeIcon': Icons.people},
    {'name': 'Faculty', 'icon': Icons.badge_outlined, 'activeIcon': Icons.badge},
    {'name': 'Attendance', 'icon': Icons.fact_check_outlined, 'activeIcon': Icons.fact_check},
    {'name': 'Academics', 'icon': Icons.school_outlined, 'activeIcon': Icons.school},
    {'name': 'Examinations', 'icon': Icons.assignment_outlined, 'activeIcon': Icons.assignment},
    {'name': 'Fee Management', 'icon': Icons.account_balance_wallet_outlined, 'activeIcon': Icons.account_balance_wallet},
    {'name': 'Transport', 'icon': Icons.directions_bus_outlined, 'activeIcon': Icons.directions_bus},
    {'name': 'Library', 'icon': Icons.local_library_outlined, 'activeIcon': Icons.local_library},
    {'name': 'Hostel', 'icon': Icons.hotel_outlined, 'activeIcon': Icons.hotel},
    {'name': 'Communication', 'icon': Icons.chat_bubble_outline, 'activeIcon': Icons.chat_bubble},
    {'name': 'Reports', 'icon': Icons.assessment_outlined, 'activeIcon': Icons.assessment},
    {'name': 'Analytics', 'icon': Icons.analytics_outlined, 'activeIcon': Icons.analytics},
    {'name': 'Settings', 'icon': Icons.settings_outlined, 'activeIcon': Icons.settings},
    {'name': 'User Management', 'icon': Icons.manage_accounts_outlined, 'activeIcon': Icons.manage_accounts},
    {'name': 'Audit Logs', 'icon': Icons.history_toggle_off_outlined, 'activeIcon': Icons.history},
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeSection = ref.watch(desktopNavigationProvider);
    final notificationCount = ref.watch(desktopNotificationCountProvider);
    
    final role = userData['role']?.toString() ?? 'Staff';
    final items = _getFilteredSidebarItems(role);
    
    final hasActiveSection = items.any((item) => item['name'] == activeSection);
    if (!hasActiveSection && items.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(desktopNavigationProvider.notifier).state = items.first['name'] as String;
      });
    }

    return Scaffold(
      backgroundColor: context.bgColor,
      body: Row(
        children: [
          // 1. Sidebar Menu (Left Pane)
          Container(
            width: 260,
            decoration: BoxDecoration(
              color: context.cardColor,
              border: Border(right: BorderSide(color: context.borderColor, width: 1)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Branding Header
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24, vertical: 30),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Color(0xFF3b5998).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(Icons.school, color: Colors.blueAccent, size: 24),
                      ),
                      SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Alwardas ERP',
                            style: GoogleFonts.poppins(
                              color: context.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          Text(
                            'Desktop Workspace',
                            style: GoogleFonts.poppins(
                              color: context.textMuted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                Divider(color: context.borderColor, height: 1),

                // Navigation Items List
                Expanded(
                  child: ListView.builder(
                    padding: EdgeInsets.symmetric(vertical: 16, horizontal: 12),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      final item = items[index];
                      final name = item['name'] as String;
                      final isSelected = activeSection == name;

                      return Padding(
                        padding: EdgeInsets.only(bottom: 4),
                        child: InkWell(
                          onTap: () {
                            ref.read(desktopNavigationProvider.notifier).state = name;
                          },
                          borderRadius: BorderRadius.circular(10),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? Color(0xFF3b5998).withOpacity(0.15)
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected ? Color(0xFF3b5998).withOpacity(0.3) : Colors.transparent,
                                width: 1,
                              ),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isSelected ? item['activeIcon'] : item['icon'],
                                  color: isSelected ? Colors.blueAccent : context.textSecondary,
                                  size: 20,
                                ),
                                SizedBox(width: 14),
                                Expanded(
                                  child: Text(
                                    name,
                                    style: GoogleFonts.poppins(
                                      color: isSelected ? context.textPrimary : context.textSecondary,
                                      fontSize: 13,
                                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w400,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),

                Divider(color: context.borderColor, height: 1),

                // Current logged in User profile segment
                Padding(
                  padding: EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.blueAccent.withOpacity(0.2),
                        child: Text(
                          (userData['full_name'] ?? 'U').toString().substring(0, 1).toUpperCase(),
                          style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold),
                        ),
                      ),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              (userData['full_name'] ?? 'User').toString().toUpperCase(),
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.poppins(
                                color: context.textPrimary,
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              userData['role'] ?? 'Staff',
                              style: GoogleFonts.poppins(
                                color: context.textMuted,
                                fontSize: 11,
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

          // 2. View Panel (Right Pane)
          Expanded(
            child: Column(
              children: [
                // Header (Glassmorphism inspired)
                Container(
                  height: 70,
                  decoration: BoxDecoration(
                    color: context.bgColor,
                    border: Border(bottom: BorderSide(color: context.borderColor, width: 1)),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // breadcrumbs / Section Indicator
                      Row(
                        children: [
                          Text(
                            'ERP System',
                            style: GoogleFonts.poppins(color: context.textMuted, fontSize: 13),
                          ),
                          SizedBox(width: 8),
                          Icon(Icons.chevron_right, color: context.textMuted, size: 16),
                          SizedBox(width: 8),
                          Text(
                            activeSection,
                            style: GoogleFonts.poppins(
                              color: context.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),

                      // Header Actions (Search, Notification, Profile Dropdown)
                      Row(
                        children: [
                          // Search Box
                          Container(
                            width: 240,
                            height: 38,
                            decoration: BoxDecoration(
                              color: context.cardColor,
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: context.borderColor),
                            ),
                            padding: EdgeInsets.symmetric(horizontal: 12),
                            child: Row(
                              children: [
                                Icon(Icons.search, color: context.textMuted, size: 18),
                                SizedBox(width: 8),
                                Expanded(
                                  child: TextField(
                                    style: TextStyle(color: context.textPrimary, fontSize: 12),
                                    decoration: InputDecoration(
                                      hintText: 'Search ERP...',
                                      hintStyle: GoogleFonts.poppins(color: context.textMuted2),
                                      border: InputBorder.none,
                                      isDense: true,
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(width: 20),

                          // Notification bell icon
                          Stack(
                            clipBehavior: Clip.none,
                            children: [
                              IconButton(
                                icon: Icon(Icons.notifications_none, color: context.textSecondary),
                                onPressed: () {
                                  // Open notification side drawer or alert overlay
                                  _showNotificationsDialog(context);
                                },
                              ),
                              if (notificationCount > 0)
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: Colors.redAccent,
                                      shape: BoxShape.circle,
                                    ),
                                    constraints: BoxConstraints(
                                      minWidth: 16,
                                      minHeight: 16,
                                    ),
                                    child: Text(
                                      '$notificationCount',
                                      style: TextStyle(
                                        color: context.textPrimary,
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          SizedBox(width: 10),

                          // Logout / Session dropdown
                          PopupMenuButton<String>(
                            icon: Icon(Icons.keyboard_arrow_down, color: context.textSecondary),
                            color: context.cardColor,
                            onSelected: (value) {
                              if (value == 'logout') {
                                HiveService.clearSession();
                                context.go('/login');
                              }
                            },
                            itemBuilder: (BuildContext context) => [
                              PopupMenuItem<String>(
                                value: 'profile',
                                child: Text(
                                  'My Profile',
                                  style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
                                ),
                              ),
                              PopupMenuItem<String>(
                                value: 'settings',
                                child: Text(
                                  'ERP Settings',
                                  style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
                                ),
                              ),
                              const PopupMenuDivider(height: 1),
                              PopupMenuItem<String>(
                                value: 'logout',
                                child: Row(
                                  children: [
                                    Icon(Icons.logout, color: Colors.redAccent, size: 16),
                                    SizedBox(width: 8),
                                    Text(
                                      'Log Out',
                                      style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Main body view content area
                Expanded(
                  child: _getView(context, activeSection, userData),
                ),

                // Footer segment
                Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: context.bgColor,
                    border: Border(top: BorderSide(color: context.borderColor, width: 1)),
                  ),
                  padding: EdgeInsets.symmetric(horizontal: 30),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '© 2026 Alwardas Group of Institutions. All rights reserved.',
                        style: GoogleFonts.poppins(color: context.textMuted2, fontSize: 10),
                      ),
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: Colors.greenAccent,
                              shape: BoxShape.circle,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'System Active (v1.0.1)',
                            style: GoogleFonts.poppins(color: context.textMuted, fontSize: 10),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _getView(BuildContext context, String section, Map<String, dynamic> userData) {
    final role = userData['role']?.toString().toLowerCase().trim() ?? 'staff';

    switch (section) {
      case 'Dashboard':
        if (role == 'hod') {
          return DesktopHodDashboardView(userData: userData);
        }
        return DesktopDashboardView(userData: userData);
      case 'Admissions':
        if (role == 'hod' || role == 'admin' || role == 'principal') {
          return DesktopHodAdmissionView(userData: userData);
        }
        return Center(child: Text("Access Denied"));
      case 'Students':
        return DesktopStudentManagementView(userData: userData);
      case 'Attendance':
        return DesktopAttendanceView(userData: userData);
      case 'Examinations':
        return DesktopExaminationView(userData: userData);
      case 'Academics':
        if (role == 'coordinator' || role == 'principal' || role == 'admin') {
          return DesktopCoordinatorAcademicsView(userData: userData);
        }
        return Center(child: Text("Access Denied"));
      case 'Fee Management':
        return DesktopFeeManagementView(userData: userData);
      case 'Faculty':
        return DesktopFacultyManagementView(userData: userData);
      case 'Communication':
        return DesktopCommunicationView(userData: userData);
      case 'Analytics':
        return DesktopPrincipalAnalyticsView(userData: userData);
      case 'Reports':
        return DesktopReportsView(userData: userData);
      case 'User Management':
        return DesktopUserManagementView(userData: userData);
      case 'Audit Logs':
        return DesktopAuditLogsView(userData: userData);
      case 'Requests':
        if (role == 'hod') {
          return DesktopHodRequestsView(userData: userData);
        }
        return Center(child: Text("Access Denied"));
      case 'Timetable':
        if (role == 'hod') {
          return DesktopHodTimetableView(userData: userData);
        }
        return Center(child: Text("Access Denied"));
      case 'Syllabus':
        if (role == 'hod') {
          return DesktopHodSyllabusView(userData: userData);
        }
        return Center(child: Text("Access Denied"));
      case 'Issues':
        if (role == 'hod') {
          return DesktopHodIssuesView(userData: userData);
        }
        return Center(child: Text("Access Denied"));
      default:
        return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.hourglass_empty, color: Colors.blueAccent.withOpacity(0.4), size: 60),
              SizedBox(height: 16),
              Text(
                'ERP $section module coming soon',
                style: GoogleFonts.poppins(
                  color: Colors.white.withOpacity(0.5),
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'We are finishing migrations for this desktop subsection.',
                style: GoogleFonts.poppins(color: context.textMuted2, fontSize: 12),
              ),
            ],
          ),
        );
    }
  }

  void _showNotificationsDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Container(
          width: 400,
          padding: EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Recent Notifications',
                    style: GoogleFonts.poppins(
                      color: context.textPrimary,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, color: context.textSecondary),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              SizedBox(height: 16),
              _buildNotificationItem(context, 'Admission request from John Doe (HOD Review)', '10 mins ago'),
              _buildNotificationItem(context, 'Semester exam schedules updated', '2 hours ago'),
              _buildNotificationItem(context, 'System security backup finished', '5 hours ago'),
              SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Color(0xFF3b5998),
                    foregroundColor: context.textPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: Text('Close Feed', style: GoogleFonts.poppins()),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationItem(BuildContext context, String message, String time) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.circle, color: Colors.blueAccent, size: 8),
          SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  message,
                  style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
                ),
                SizedBox(height: 4),
                Text(
                  time,
                  style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  List<Map<String, dynamic>> _getFilteredSidebarItems(String role) {
    final cleanRole = role.toLowerCase().trim();
    
    if (cleanRole == 'accountant') {
      return [
        {'name': 'Dashboard', 'icon': Icons.dashboard_outlined, 'activeIcon': Icons.dashboard},
        {'name': 'Fee Management', 'icon': Icons.account_balance_wallet_outlined, 'activeIcon': Icons.account_balance_wallet},
        {'name': 'Reports', 'icon': Icons.assessment_outlined, 'activeIcon': Icons.assessment},
        {'name': 'Settings', 'icon': Icons.settings_outlined, 'activeIcon': Icons.settings},
      ];
    }
    
    if (cleanRole == 'accounts manager' || cleanRole == 'finance') {
      return [
        {'name': 'Dashboard', 'icon': Icons.dashboard_outlined, 'activeIcon': Icons.dashboard},
        {'name': 'Fee Management', 'icon': Icons.account_balance_wallet_outlined, 'activeIcon': Icons.account_balance_wallet},
        {'name': 'Reports', 'icon': Icons.assessment_outlined, 'activeIcon': Icons.assessment},
        {'name': 'Settings', 'icon': Icons.settings_outlined, 'activeIcon': Icons.settings},
        {'name': 'Audit Logs', 'icon': Icons.history_toggle_off_outlined, 'activeIcon': Icons.history},
      ];
    }

    if (cleanRole == 'hod') {
      return [
        {'name': 'Dashboard', 'icon': Icons.dashboard_outlined, 'activeIcon': Icons.dashboard},
        {'name': 'Admissions', 'icon': Icons.app_registration_outlined, 'activeIcon': Icons.app_registration},
        {'name': 'Students', 'icon': Icons.people_outline, 'activeIcon': Icons.people},
        {'name': 'Faculty', 'icon': Icons.badge_outlined, 'activeIcon': Icons.badge},
        {'name': 'Attendance', 'icon': Icons.fact_check_outlined, 'activeIcon': Icons.fact_check},
        {'name': 'Timetable', 'icon': Icons.schedule_outlined, 'activeIcon': Icons.schedule},
        {'name': 'Syllabus', 'icon': Icons.menu_book_outlined, 'activeIcon': Icons.menu_book},
        {'name': 'Requests', 'icon': Icons.mail_outline, 'activeIcon': Icons.mail},
        {'name': 'Issues', 'icon': Icons.report_problem_outlined, 'activeIcon': Icons.report_problem},
        {'name': 'Communication', 'icon': Icons.chat_bubble_outline, 'activeIcon': Icons.chat_bubble},
        {'name': 'Reports', 'icon': Icons.assessment_outlined, 'activeIcon': Icons.assessment},
        {'name': 'Settings', 'icon': Icons.settings_outlined, 'activeIcon': Icons.settings},
      ];
    }
    
    return sidebarItems;
  }
}

