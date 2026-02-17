import 'coordinator_announcement_details_screen.dart';
import 'package:shimmer/shimmer.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../auth/login_screen.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';

// Principal Modules
import '../principal/principal_attendance_screen.dart';
import '../principal/principal_announcements_screen.dart';
import '../principal/principal_notifications_screen.dart';
import '../principal/principal_faculty_screen.dart';
import '../principal/principal_lesson_plans_screen.dart';
import '../principal/principal_requests_screen.dart';
import '../principal/principal_schedule_screen.dart';
import '../principal/principal_timetables_screen.dart';

// Coordinator Modules
import 'coordinator_events_screen.dart';
import 'coordinator_activities_screen.dart';
import 'coordinator_requests_screen.dart';
import 'coordinator_menu_tab.dart';
import 'coordinator_profile_tab.dart';
import 'coordinator_announcements_screen.dart';
import 'coordinator_create_announcement_screen.dart';
import '../../../widgets/custom_bottom_nav_bar.dart';


class CoordinatorDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const CoordinatorDashboard({super.key, required this.userData});

  @override
  State<CoordinatorDashboard> createState() => _CoordinatorDashboardState();
}

class _CoordinatorDashboardState extends State<CoordinatorDashboard> {
  int _selectedIndex = 1; // Default to Home (index 1)
  List<Announcement> _dashboardAnnouncements = [];
  bool _isLoadingAnnouncements = true;

  @override
  void initState() {
    super.initState();
    _fetchDashboardAnnouncements();
  }

  Future<void> _fetchDashboardAnnouncements() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/announcement'));
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _dashboardAnnouncements = data.map((json) => Announcement.fromJson(json)).toList();
            _isLoadingAnnouncements = false;
          });
        }
      } else {
        _loadMockDashboardAnnouncements();
      }
    } catch (e) {
      debugPrint("Error fetching dashboard announcements: $e");
      _loadMockDashboardAnnouncements();
    }
  }

  void _loadMockDashboardAnnouncements() {
    if (mounted) {
      setState(() {
        _dashboardAnnouncements = _getMockAnnouncements();
        _isLoadingAnnouncements = false;
      });
    }
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

    final Color bgColor = theme.scaffoldBackgroundColor;
    final Color cardColor = isDark ? ThemeColors.darkCardBg : Colors.white;
    final Color textColor = theme.colorScheme.onSurface;
    final Color subTextColor = theme.colorScheme.secondary;
    final Color tint = const Color(0xFFFF4B2B); // Coordinator Theme Color (Orange/Red)

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
              const CoordinatorMenuTab(),
              _buildHomeTab(context, cardColor, textColor, subTextColor, isDark),
              CoordinatorProfileTab(userData: widget.userData, onLogout: _logout),
            ],
          ),
        ),
        bottomNavigationBar: CustomBottomNavBar(
          currentIndex: _selectedIndex,
          onTap: (index) => setState(() => _selectedIndex = index),
          selectedItemColor: ThemeColors.accentBlue,
          unselectedItemColor: const Color(0xFF64748B),
          backgroundColor: isDark ? const Color(0xFF020617) : Colors.white,
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
    // Coordinator Header Gradient (Futuristic Theme)
    final List<Color> headerGradient = ThemeColors.headerGradient; 
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final theme = Theme.of(context);

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
                              color: ThemeColors.accentBlue, // Accent Blue (Header Text Main)
                              fontSize: 18,
                              fontWeight: FontWeight.w600,
                            ),
                         ),
                         FittedBox(
                           fit: BoxFit.scaleDown,
                           alignment: Alignment.centerLeft,
                           child: Text(
                             widget.userData['full_name'] ?? 'Coordinator',
                              style: GoogleFonts.poppins(
                                color: const Color(0xFFE5E7EB), // Primary Text
                                fontSize: 26,
                                fontWeight: FontWeight.bold,
                              ),
                           ),
                         ),
                         const SizedBox(height: 4),
                         Text(
                           'Master Administration',
                            style: GoogleFonts.poppins(
                              color: const Color(0xFF94A3B8), // Text Sub
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
                         onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrincipalNotificationsScreen())),
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
                  
                  // Announcements Header
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Announcements',
                        style: GoogleFonts.poppins(
                          color: textColor,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      GestureDetector(
                        onTap: () async {
                           final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CoordinatorCreateAnnouncementScreen()));
                           if (result == true) {
                             _fetchDashboardAnnouncements();
                           }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: theme.primaryColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: Icon(Icons.add, size: 20, color: theme.primaryColor),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  
                  // Dynamic Announcement List
                  if (_isLoadingAnnouncements) 
                      _buildAnnouncementsLoadingState(isDark)
                  else
                      Builder(
                        builder: (context) {
                          List<Announcement> sortedList = List.from(_dashboardAnnouncements);
                          // Sort by pinned, then date (same logic as main screen)
                          sortedList.sort((a, b) {
                            if (a.isPinned && !b.isPinned) return -1;
                            if (!a.isPinned && b.isPinned) return 1;
                            return b.createdAt.compareTo(a.createdAt);
                          });

                          final displayList = sortedList.take(3).toList();
                          final hasMore = sortedList.length > 3;

                          if (displayList.isEmpty) {
                            return Center(child: Text("No announcements", style: GoogleFonts.poppins(color: subTextColor)));
                          }

                          return SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ...displayList.map((announcement) => Padding(
                                  padding: const EdgeInsets.only(right: 15),
                                  child: _buildHorizontalAnnouncementCard(announcement),
                                )),
                                
                                if (hasMore)
                                  GestureDetector(
                                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CoordinatorAnnouncementsScreen())),
                                    child: Container(
                                      width: 60,
                                      height: 90, // Match card height roughly
                                      decoration: BoxDecoration(
                                        color: cardColor,
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(color: Colors.grey.withOpacity(0.2)),
                                      ),
                                      child: const Center(
                                        child: Icon(Icons.arrow_forward_ios, color: Colors.grey),
                                      ),
                                    ),
                                  )
                              ],
                            ),
                          );
                        }
                      ),

                  const SizedBox(height: 25),

                  // Quick Access: Coordinator Specific
                  Text(
                    'Administration',
                    style: GoogleFonts.poppins(
                      color: textColor,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 15),

                  // Row 1: Events & Activities (Coordinator Special)
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 2,
                      crossAxisSpacing: 15,
                      mainAxisSpacing: 15,
                      childAspectRatio: 1.2,
                    ),
                    itemCount: 10,
                    itemBuilder: (context, index) {
                      // Define items data
                      final List<Map<String, dynamic>> items = [
                        {
                          'icon': Icons.calendar_today_outlined,
                          'title': 'Attendance',
                          'subtitle': 'Monitor All',
                          'color': const Color(0xFF29B6F6), // Cyan
                          'route': const PrincipalAttendanceScreen(),
                        },
                        {
                          'icon': Icons.menu_book,
                          'title': 'Syllabus',
                          'subtitle': 'Track Progress',
                          'color': const Color(0xFF66BB6A), // Green
                          'route': const PrincipalLessonPlansScreen(),
                        },
                        {
                          'icon': Icons.event,
                          'title': 'Event Planning',
                          'subtitle': 'Manage Events',
                          'color': const Color(0xFF4FC3F7), // Light Blue
                          'route': const CoordinatorEventsScreen(),
                        },
                        {
                          'icon': Icons.sports_basketball,
                          'title': 'Student Activities',
                          'subtitle': 'Sports & Cultural',
                          'color': const Color(0xFF1565C0), // Dark Blue
                          'route': const CoordinatorActivitiesScreen(),
                        },
                        {
                          'icon': Icons.assignment_turned_in,
                          'title': 'HOD Requests',
                          'subtitle': 'Approve HODs',
                          'color': const Color(0xFF00B0FF), // Blue
                          'route': const PrincipalRequestsScreen(),
                        },
                        {
                          'icon': Icons.verified_user, 
                          'title': 'Principal Requests',
                          'subtitle': 'Approve Principals',
                          'color': const Color(0xFF0D47A1), // Deep Blue
                          'route': const CoordinatorRequestsScreen(),
                        },
                        {
                          'icon': Icons.access_time,
                          'title': 'Master Timetables',
                          'subtitle': 'View All',
                          'color': const Color(0xFF78909C), // Blue Grey
                          'route': const PrincipalTimetablesScreen(),
                        },
                        {
                          'icon': Icons.groups_outlined,
                          'title': 'Faculty Dir',
                          'subtitle': 'View Staff',
                          'color': const Color(0xFFEC407A), // Pink
                          'route': const PrincipalFacultyScreen(),
                        },
                        {
                          'icon': Icons.campaign_outlined,
                          'title': 'Announcer',
                          'subtitle': 'Send Alerts',
                          'color': const Color(0xFFEF5350), // Red
                          'route': const CoordinatorAnnouncementsScreen(),
                        },
                        {
                          'icon': Icons.event_note,
                          'title': 'My Schedule',
                          'subtitle': 'Personal View',
                          'color': const Color(0xFF26A69A), // Teal
                          'route': const PrincipalScheduleScreen(),
                        },
                      ];

                      final item = items[index];
                      return _buildQuickAccessCard(
                        item['icon'],
                        item['title'],
                        item['subtitle'],
                        cardColor,
                        item['color'].withValues(alpha: 0.1), 
                        item['color'],
                        textColor,
                        subTextColor,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => item['route'])),
                      );
                    },
                  ),
                  
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
        color: const Color(0xFF1E293B).withValues(alpha: 0.5), // Subtle bg
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFF38BDF8).withValues(alpha: 0.3), width: 1),
      ),
      child: Icon(icon, color: const Color(0xFF38BDF8), size: 20), // Blue Icon
    );
  }

  List<Announcement> _getMockAnnouncements() {
    return [
      Announcement(
        id: '1',
        title: 'Examination Schedule Released',
        description: 'The final examination schedule has been released for all departments. Please review matches.',
        type: AnnouncementType.exam,
        audience: ['All Departments'],
        priority: AnnouncementPriority.urgent,
        startDate: DateTime.now().add(const Duration(days: 5)),
        endDate: DateTime.now().add(const Duration(days: 10)),
        createdAt: DateTime.now(),
        isNew: true,
        isPinned: true,
      ),
      Announcement(
        id: '2',
        title: 'Cultural Fest Announcement',
        description: 'Get ready for the biggest cultural fest of the year!',
        type: AnnouncementType.event,
        audience: ['Students'],
        priority: AnnouncementPriority.important,
        startDate: DateTime.now().subtract(const Duration(days: 1)),
        endDate: DateTime.now().add(const Duration(days: 3)),
        createdAt: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      Announcement(
        id: '3',
        title: 'Faculty Meeting at 2 PM',
        description: 'Mandatory faculty meeting in the conference hall.',
        type: AnnouncementType.faculty,
        audience: ['Faculty'],
        priority: AnnouncementPriority.normal,
        startDate: DateTime.now(),
        endDate: DateTime.now().add(const Duration(hours: 4)),
        createdAt: DateTime.now().subtract(const Duration(hours: 5)),
        isPinned: true,
      ),
      Announcement(
        id: '4',
        title: 'System Maintenance at Midnight',
        description: 'Server will be down for maintenance.',
        type: AnnouncementType.urgent,
        audience: ['All Departments'],
        priority: AnnouncementPriority.urgent,
        startDate: DateTime.now().add(const Duration(days: 8)),
        endDate: DateTime.now().add(const Duration(days: 9)),
        createdAt: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ];
  }

  Widget _buildAnnouncementCard(Announcement announcement) {
    Color typeColorStart;
    Color typeColorEnd;
    IconData typeIcon;
    
    String audience = announcement.audience.isNotEmpty ? announcement.audience.first : 'All';

    // Audience Color Logic
    typeColorStart = Colors.grey; typeColorEnd = Colors.blueGrey;
    if (audience.toLowerCase().contains('student')) {
       typeColorStart = const Color(0xFF2E3192); typeColorEnd = const Color(0xFF1BFFFF); // Blue/Cyan
    } else if (audience.toLowerCase().contains('parent')) {
       typeColorStart = const Color(0xFFD4145A); typeColorEnd = const Color(0xFFFBB03B); // Red/Orange
    } else if (audience.toLowerCase().contains('faculty')) {
       typeColorStart = const Color(0xFF009245); typeColorEnd = const Color(0xFFFCEE21); // Green/Yellow
    } else if (audience.toLowerCase().contains('hod')) {
       typeColorStart = const Color(0xFF662D8C); typeColorEnd = const Color(0xFFED1E79); // Purple/Pink
    } else if (audience.toLowerCase().contains('principal')) {
       typeColorStart = const Color(0xFF12c2e9); typeColorEnd = const Color(0xFFc471ed); // Blue/Purple
    } else if (audience.toLowerCase().contains('all')) {
       typeColorStart = const Color(0xFFC04848); typeColorEnd = const Color(0xFF480048); // Red/Purple (Distinctive)
    }

    switch(announcement.type) {
      case AnnouncementType.exam: typeIcon = Icons.campaign_outlined; break;
      case AnnouncementType.event: typeIcon = Icons.calendar_today; break;
      case AnnouncementType.faculty: typeIcon = Icons.school; break;
      case AnnouncementType.urgent: typeIcon = Icons.warning_amber_rounded; break;
      default: typeIcon = Icons.info_outline;
    }

    return GestureDetector(
      onTap: () {
         // Navigate to details if needed, or open announcements page
         Navigator.push(context, MaterialPageRoute(builder: (_) => CoordinatorAnnouncementDetailsScreen(announcement: announcement)));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [typeColorStart, typeColorEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: typeColorStart.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 44, 
                    height: 44, 
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                    child: Icon(typeIcon, color: Colors.white, size: 22),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          announcement.title,
                          style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 3),
                        Text(
                          DateFormat('MMM d, yyyy').format(announcement.startDate),
                          style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.8), fontSize: 13),
                        ),
                      ],
                    ),
                  )
                ],
              ),
            ),
            if (announcement.priority == AnnouncementPriority.urgent)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 14),
                      const SizedBox(width: 4),
                      Text('URGENT', style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildHorizontalAnnouncementCard(Announcement announcement) {
    Color typeColorStart;
    Color typeColorEnd;
    IconData typeIcon;
    
    String audience = announcement.audience.isNotEmpty ? announcement.audience.first : 'All';

    // Audience Color Logic
    typeColorStart = Colors.grey; typeColorEnd = Colors.blueGrey;
    if (audience.toLowerCase().contains('student')) {
       typeColorStart = const Color(0xFF2E3192); typeColorEnd = const Color(0xFF1BFFFF); // Blue/Cyan
    } else if (audience.toLowerCase().contains('parent')) {
       typeColorStart = const Color(0xFFD4145A); typeColorEnd = const Color(0xFFFBB03B); // Red/Orange
    } else if (audience.toLowerCase().contains('faculty')) {
       typeColorStart = const Color(0xFF009245); typeColorEnd = const Color(0xFFFCEE21); // Green/Yellow
    } else if (audience.toLowerCase().contains('hod')) {
       typeColorStart = const Color(0xFF662D8C); typeColorEnd = const Color(0xFFED1E79); // Purple/Pink
    } else if (audience.toLowerCase().contains('principal')) {
       typeColorStart = const Color(0xFF12c2e9); typeColorEnd = const Color(0xFFc471ed); // Blue/Purple
    } else if (audience.toLowerCase().contains('all')) {
       typeColorStart = const Color(0xFFC04848); typeColorEnd = const Color(0xFF480048); // Red/Purple (Distinctive)
    }

    switch(announcement.type) {
      case AnnouncementType.exam: typeIcon = Icons.campaign_outlined; break;
      case AnnouncementType.event: typeIcon = Icons.calendar_today; break;
      case AnnouncementType.faculty: typeIcon = Icons.school; break;
      case AnnouncementType.urgent: typeIcon = Icons.warning_amber_rounded; break;
      default: typeIcon = Icons.info_outline;
    }

    return GestureDetector(
      onTap: () {
         Navigator.push(context, MaterialPageRoute(builder: (_) => CoordinatorAnnouncementDetailsScreen(announcement: announcement)));
      },
      child: Container(
        width: 250, // Reduced width slightly
        height: 90, // Reduced height as requested
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [typeColorStart, typeColorEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16), // Slightly smaller radius
          boxShadow: [
            BoxShadow(
              color: typeColorStart.withValues(alpha: 0.2),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Stack(
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row( // Title Row with Icon
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Container(
                            width: 28,
                            height: 28,
                            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), shape: BoxShape.circle),
                            child: Icon(typeIcon, color: Colors.white, size: 14),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 140, // Constrain Title Width
                            child: Text(
                              announcement.title,
                              style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                      
                    ],
                  ),
                  
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                         padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                         decoration: BoxDecoration(
                           color: Colors.black.withValues(alpha: 0.2),
                           borderRadius: BorderRadius.circular(8),
                         ),
                         child: Text(
                           audience,
                           style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.9), fontSize: 9),
                         ),
                      ),
                      Text(
                        DateFormat('MMM d').format(announcement.startDate),
                        style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                      ),
                    ],
                  )
                ],
              ),
            ),
            if (announcement.priority == AnnouncementPriority.urgent)
              Positioned(
                top: 12,
                right: 12,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.25),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 0.5)
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 12),
                      const SizedBox(width: 2),
                      Text('URGENT', style: GoogleFonts.poppins(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildQuickAccessCard(IconData icon, String title, String subtitle, Color cardColor, Color iconBgColor, Color iconColor, Color textColor, Color subTextColor, {VoidCallback? onTap}) {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? ThemeColors.darkCardBg : Colors.white, // Solid color from theme
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
             color: isDark ? ThemeColors.darkBorder : Colors.black.withValues(alpha: 0.03),
             width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
              blurRadius: 15, // Softer shadow
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
                color: iconBgColor.withValues(alpha: 0.2), // Clean no-shadow bg
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
  Widget _buildAnnouncementsLoadingState(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(3, (index) {
          return Padding(
            padding: const EdgeInsets.only(right: 15),
            child: Shimmer.fromColors(
              baseColor: isDark ? const Color(0xFF1E293B) : Colors.grey[300]!,
              highlightColor: isDark ? const Color(0xFF334155) : Colors.grey[100]!,
              child: Container(
                width: 250,
                height: 90,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
