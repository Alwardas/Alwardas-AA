import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../core/api_constants.dart';
import '../../auth/login_screen.dart';
import 'add_child_screen.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../student/attendance_screen.dart';
import '../student/student_notifications_screen.dart';
import '../student/student_marks_screen.dart';
import '../student/my_courses_screen.dart';
import 'parent_profile_tab.dart';
import 'parent_menu_tab.dart';
import 'parent_requests_screen.dart';
import '../../../widgets/custom_bottom_nav_bar.dart';
import '../../../widgets/shared_dashboard_announcements.dart';
import 'dart:async';
import '../../../core/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ParentDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ParentDashboard({super.key, required this.userData});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  int _selectedIndex = 1; // Default to Home
  Timer? _notificationTimer;
  String? _lastNotifiedId;

  // Mock Children Data - In a real app, this would come from the API
  List<Map<String, String>> _children = [];
  int _selectedChildIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize with a placeholder or empty list, actual data will be fetched
    if (widget.userData['childrenData'] != null) {
      _children =
          List<Map<String, String>>.from(widget.userData['childrenData']);
    } else {
      // Fallback placeholder while loading
      _children = [
        {
          "name": "Loading...",
          "id": "",
          "branch": "",
          "batch": "",
          "year": "",
          "sem": ""
        },
      ];
      _fetchChildData();
    }
    _startNotificationPolling();
    // Fetch attendance for initial child if available
    _fetchTodayAttendance();
  }

  String _todayAttendanceStatus = "Not taken yet";

  Future<void> _fetchTodayAttendance() async {
    if (_children.isEmpty || _children[_selectedChildIndex]['id'] == null || _children[_selectedChildIndex]['id']!.isEmpty) return;
    String studentId = _children[_selectedChildIndex]['id']!;
    
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/attendance?studentId=$studentId');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final Map<String, dynamic> dataMap = json.decode(response.body);
        final List<dynamic> data = dataMap['history'] ?? [];
        final String todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
        bool hasMorning = false;
        bool hasAfternoon = false;
        String morningStatus = "";
        String afternoonStatus = "";
        bool dayIsHoliday = false;

        for (var record in data) {
          String rawDate = record['date']?.toString() ?? '';
          String recordDateStr = rawDate.split('T')[0];
          String statusRaw = (record['status'] ?? '').toString().toUpperCase();
          // Normalize status
          String recordStatus = (statusRaw.startsWith('H') || statusRaw.contains('HOLIDAY')) 
              ? 'HOLIDAY' 
              : (statusRaw.startsWith('P') ? 'PRESENT' : 'ABSENT');

          if (recordDateStr == todayStr) {
            if (record['session'] == 'MORNING') {
              hasMorning = true;
              morningStatus = recordStatus;
            } else if (record['session'] == 'AFTERNOON') {
              hasAfternoon = true;
              afternoonStatus = recordStatus;
            }
            
            // Comprehensive holiday check
            if (recordStatus == 'HOLIDAY') {
              dayIsHoliday = true;
            }
          }
        }
        
        if (mounted) {
          setState(() {
            if (dayIsHoliday) {
              _todayAttendanceStatus = "Holiday";
            } else if (hasMorning && hasAfternoon) {
               if (morningStatus.contains('HOLIDAY') || afternoonStatus.contains('HOLIDAY')) {
                  _todayAttendanceStatus = "Holiday";
               } else if (morningStatus == 'PRESENT' && afternoonStatus == 'PRESENT') {
                  _todayAttendanceStatus = "Present";
               } else if (morningStatus == 'ABSENT' && afternoonStatus == 'ABSENT') {
                  _todayAttendanceStatus = "Absent";
               } else {
                  _todayAttendanceStatus = "Half Day";
               }
            } else if (hasMorning) {
               if (morningStatus.contains('HOLIDAY')) {
                  _todayAttendanceStatus = "Holiday";
               } else {
                  _todayAttendanceStatus = morningStatus == 'PRESENT' ? "Present (Morning)" : "Absent (Morning)";
               }
            } else if (hasAfternoon) {
               if (afternoonStatus.contains('HOLIDAY')) {
                  _todayAttendanceStatus = "Holiday";
               } else {
                  _todayAttendanceStatus = afternoonStatus == 'PRESENT' ? "Present (Afternoon)" : "Absent (Afternoon)";
               }
            } else {
               _todayAttendanceStatus = "Not taken yet";
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching parent today attendance: $e");
    }
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
          '${ApiConstants.baseUrl}/api/notifications?role=Parent&userId=${user['id']}'));

      if (response.statusCode == 200) {
        final List<dynamic> notifications = json.decode(response.body);
        if (notifications.isEmpty) return;

        final latest = notifications.first;
        final String latestId = latest['id'].toString();

        if (_lastNotifiedId == null) {
          final prefs = await SharedPreferences.getInstance();
          _lastNotifiedId = prefs.getString('last_parent_notification_id');
        }

        if (latestId != _lastNotifiedId) {
          if (!isInitial) {
            if (latest['status'] == 'UNREAD' || latest['status'] == 'PENDING') {
              await NotificationService.showImmediateNotification(
                id: latestId.hashCode,
                title: 'Parent Notification',
                body: latest['message'] ?? 'New update regarding your child',
                payload: 'notif_${latest['id']}',
              );
            }
          }

          _lastNotifiedId = latestId;
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('last_parent_notification_id', latestId);
        }
      }
    } catch (e) {
      debugPrint("Parent Notification Polling Error: $e");
    }
  }

  Future<void> _fetchChildData() async {
    final userId = widget.userData['id'] ?? widget.userData['userId'];
    if (userId == null) return;

    try {
      final response = await http.get(
        Uri.parse("${ApiConstants.baseUrl}/api/parent/profile?userId=$userId"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data['student'] != null) {
          final student = data['student'];
          if (mounted) {
            setState(() {
              _children = [
                {
                  "name": student['fullName'] ?? "N/A",
                  "id": student['loginId'] ?? "N/A",
                  "branch": student['branch'] ?? "N/A",
                  "batch_no":
                      student['batchNo'], // Mapped for Attendance Screen
                  "year": student['year'] ?? "N/A",
                  "semester": student['semester'] ?? ""
                }
              ];
            });
            // Fetch attendance after children data is loaded
            _fetchTodayAttendance();
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching child data: $e");
      if (mounted) {
        setState(() {
          _children = [
            {
              "name": "Error Loading",
              "id": "Try refreshing",
              "branch": "",
              "batch": "",
              "year": "",
              "sem": ""
            }
          ];
        });
      }
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

  void _switchChild(int index) {
    setState(() {
      _selectedChildIndex = index;
      _todayAttendanceStatus = "Loading...";
    });
    _fetchTodayAttendance();
    Navigator.pop(context); // Close the bottom sheet
  }

  void _showChildSwitcher() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1C1C2E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Switch Child Account",
                  style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 20),
              ..._children.asMap().entries.map((entry) {
                final index = entry.key;
                final child = entry.value;
                final isSelected = index == _selectedChildIndex;

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected
                        ? Theme.of(context).primaryColor
                        : Colors.grey.withValues(alpha: 0.2),
                    child: Text(child['name']![0],
                        style: TextStyle(
                            color: isSelected ? Colors.white : Colors.grey)),
                  ),
                  title: Text(child['name']!,
                      style: GoogleFonts.poppins(
                          fontWeight: FontWeight.w600,
                          color: isDark ? Colors.white : Colors.black)),
                  subtitle: Text(child['id']!,
                      style: GoogleFonts.poppins(color: Colors.grey)),
                  trailing: isSelected
                      ? Icon(Icons.check_circle,
                          color: Theme.of(context).primaryColor)
                      : null,
                  onTap: () => _switchChild(index),
                );
              }),
              const Divider(),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor:
                      Theme.of(context).primaryColor.withValues(alpha: 0.1),
                  child: Icon(Icons.add, color: Theme.of(context).primaryColor),
                ),
                title: Text("Add Another Child",
                    style: GoogleFonts.poppins(
                        fontWeight: FontWeight.w600,
                        color: Theme.of(context).primaryColor)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const AddChildScreen()));
                },
              ),
              const SizedBox(height: 10),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final Color bgColor = theme.scaffoldBackgroundColor;
    final Color cardColor = isDark ? const Color(0xFF222240) : Colors.white;
    final Color accentBlue = theme.primaryColor;
    final Color textColor = theme.colorScheme.onSurface;
    final Color subTextColor = theme.colorScheme.secondary;

    final bool isHomeTab = _selectedIndex == 1;
    SystemUiOverlayStyle overlayStyle =
        AppTheme.getAdaptiveOverlayStyle(isHomeTab || isDark);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: overlayStyle,
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
              // 0: Menu
              ParentMenuTab(
                  userData: widget.userData,
                  currentChild: _children.isNotEmpty
                      ? _children[_selectedChildIndex]
                      : {}),
              // 1: Home
              _buildHomeTab(context, bgColor, cardColor, accentBlue, textColor,
                  subTextColor, isDark),
              // 2: Profile
              ParentProfileTab(
                userData: widget.userData,
                currentChild:
                    _children.isNotEmpty ? _children[_selectedChildIndex] : {},
                onLogout: _logout,
                onWebSwitch: _showChildSwitcher,
              ),
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
            BottomNavigationBarItem(
                icon: Icon(Icons.dashboard_customize), label: 'Menu'),
            BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
            BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeTab(BuildContext context, Color bgColor, Color cardColor,
      Color accentBlue, Color textColor, Color subTextColor, bool isDark) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final currentChild = _children[_selectedChildIndex];

    return Column(
      children: [
        // 1. Header Section
        Container(
          padding: EdgeInsets.only(
              top: MediaQuery.of(context).padding.top + 10,
              bottom: 30,
              left: 24,
              right: 24),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark
                  ? AppTheme.darkHeaderGradient
                  : AppTheme.lightHeaderGradient,
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
                          'Alwardas \u2013 Parent Portal',
                          style: GoogleFonts.poppins(
                            color: Colors.white70,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 2),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            widget.userData['full_name'] ?? 'Parent',
                            style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: Colors.white24,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                'Student: ${currentChild['name'] ?? 'Loading...'}',
                                style: GoogleFonts.poppins(
                                  color: Colors.white,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => themeProvider.toggleTheme(),
                        child: _buildHeaderIcon(themeProvider.isDarkMode
                            ? Icons.wb_sunny_outlined
                            : Icons.nightlight_round),
                      ),
                      const SizedBox(width: 10),
                      GestureDetector(
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => StudentNotificationsScreen(
                                    userId: currentChild['id']))),
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
                  // Announcements
                  SharedDashboardAnnouncements(
                      userRole: widget.userData['role'] ?? 'Parent'),
                  const SizedBox(height: 10),

                  // Quick Access Section
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

                  // Simplified Quick Info Section (Recent Status) - Repositioned & Resized
                  Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      decoration: BoxDecoration(
                          color:
                              isDark ? const Color(0xFF1E293B) : Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                              color: isDark
                                  ? Colors.white10
                                  : Colors.black.withOpacity(0.05)),
                          boxShadow: [
                            BoxShadow(
                              color:
                                  Colors.black.withOpacity(isDark ? 0.2 : 0.05),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            )
                          ]),
                      child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text("Today Attendance",
                                style: GoogleFonts.poppins(
                                    color: subTextColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w600)),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 4),
                              decoration: BoxDecoration(
                                color: _todayAttendanceStatus.toLowerCase().contains('present') 
                                    ? const Color(0xFF2ecc71).withOpacity(0.1)
                                    : _todayAttendanceStatus.toLowerCase().contains('absent')
                                      ? Colors.red.withOpacity(0.1)
                                      : _todayAttendanceStatus.toLowerCase().contains('holiday')
                                        ? Colors.blue.withOpacity(0.1)
                                        : Colors.orange.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                                ),
                              child: Text(_todayAttendanceStatus,
                                  style: GoogleFonts.poppins(
                                      color: _todayAttendanceStatus.toLowerCase().contains('present') 
                                        ? const Color(0xFF2ecc71)
                                        : _todayAttendanceStatus.toLowerCase().contains('absent')
                                          ? Colors.red
                                          : _todayAttendanceStatus.toLowerCase().contains('holiday')
                                            ? Colors.blue
                                            : Colors.orange,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600)),
                            )
                          ])),
                  const SizedBox(height: 15),

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
                        Icons.calendar_today,
                        'Attendance',
                        'Check Status',
                        cardColor,
                        const Color(0xFF2ecc71).withValues(alpha: 0.1),
                        const Color(0xFF2ecc71),
                        textColor,
                        subTextColor,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => AttendanceScreen(
                                    userData: currentChild,
                                    onBack: () => Navigator.pop(context)))),
                      ),
                      _buildQuickAccessCard(
                        Icons.assignment_ind_outlined,
                        'Permissions',
                        'Requests & Leave',
                        cardColor,
                        const Color(0xFF9b59b6).withValues(alpha: 0.1),
                        const Color(0xFF9b59b6),
                        textColor,
                        subTextColor,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => ParentRequestsScreen(userData: widget.userData))),
                      ),
                      _buildQuickAccessCard(
                        Icons.menu_book_rounded,
                        'My Courses',
                        'Study Material',
                        cardColor,
                        const Color(0xFF3b5998).withValues(alpha: 0.1),
                        const Color(0xFF3b5998),
                        textColor,
                        subTextColor,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => MyCoursesScreen(
                                    userId: currentChild['id']))),
                      ),
                      _buildQuickAccessCard(
                        Icons.insights,
                        'Academics',
                        'View Marks',
                        cardColor,
                        const Color(0xFFe67e22).withValues(alpha: 0.1),
                        const Color(0xFFe67e22),
                        textColor,
                        subTextColor,
                        onTap: () => Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (_) => StudentMarksScreen(
                                    userId: currentChild['id']))),
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
