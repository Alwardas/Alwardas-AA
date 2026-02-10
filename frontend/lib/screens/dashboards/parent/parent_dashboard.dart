import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/api_constants.dart';
import '../../auth/login_screen.dart';
import 'add_child_screen.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../student/attendance_screen.dart';
import '../student/student_notifications_screen.dart';
import '../student/student_marks_screen.dart'; 
import 'parent_profile_tab.dart'; 
import 'parent_requests_screen.dart'; 

class ParentDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const ParentDashboard({super.key, required this.userData});

  @override
  State<ParentDashboard> createState() => _ParentDashboardState();
}

class _ParentDashboardState extends State<ParentDashboard> {
  int _selectedIndex = 2; // Default to Home
  
  // Mock Children Data - In a real app, this would come from the API
  List<Map<String, String>> _children = [];
  int _selectedChildIndex = 0;

  @override
  void initState() {
    super.initState();
    // Initialize with a placeholder or empty list, actual data will be fetched
    if (widget.userData['childrenData'] != null) {
      _children = List<Map<String, String>>.from(widget.userData['childrenData']);
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
                                "batch_no": student['batchNo'], // Mapped for Attendance Screen
                                "year": student['year'] ?? "N/A",
                                "semester": student['semester'] ?? ""
                            }
                         ];
                    });
                }
            }
        }
      } catch (e) {
         print("Error fetching child data: $e");
         if (mounted) {
             setState(() {
                 _children = [{
                     "name": "Error Loading",
                     "id": "Try refreshing",
                     "branch": "", "batch": "", "year": "", "sem": ""
                 }];
             });
         }
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

  void _switchChild(int index) {
    setState(() {
      _selectedChildIndex = index;
    });
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
              Text("Switch Child Account", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black)),
              const SizedBox(height: 20),
              ..._children.asMap().entries.map((entry) {
                final index = entry.key;
                final child = entry.value;
                final isSelected = index == _selectedChildIndex;
                
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isSelected ? Theme.of(context).primaryColor : Colors.grey.withOpacity(0.2),
                    child: Text(child['name']![0], style: TextStyle(color: isSelected ? Colors.white : Colors.grey)),
                  ),
                  title: Text(child['name']!, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: isDark ? Colors.white : Colors.black)),
                  subtitle: Text(child['id']!, style: GoogleFonts.poppins(color: Colors.grey)),
                  trailing: isSelected ? Icon(Icons.check_circle, color: Theme.of(context).primaryColor) : null,
                  onTap: () => _switchChild(index),
                );
              }),
              const Divider(),
              ListTile(
                leading: CircleAvatar(
                  backgroundColor: Theme.of(context).primaryColor.withOpacity(0.1),
                  child: Icon(Icons.add, color: Theme.of(context).primaryColor),
                ),
                title: Text("Add Another Child", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Theme.of(context).primaryColor)),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const AddChildScreen()));
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
              // 0: Marks
              const StudentMarksScreen(),
              // 1: Attendance
              AttendanceScreen(
                userData: _children.isNotEmpty ? _children[_selectedChildIndex] : null,
                onBack: () => setState(() => _selectedIndex = 2),
              ),
              // 2: Home
              _buildHomeTab(context, bgColor, cardColor, accentBlue, textColor, subTextColor, isDark),
              // 3: Requests & Permissions
              const ParentRequestsScreen(),
              // 4: Profile
              ParentProfileTab(
                userData: widget.userData, 
                currentChild: _children[_selectedChildIndex],
                onLogout: _logout,
                onWebSwitch: _showChildSwitcher,
              ),
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
            type: BottomNavigationBarType.fixed,
            showUnselectedLabels: true,
            selectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
            unselectedLabelStyle: GoogleFonts.poppins(fontSize: 10),
            items: const [
              BottomNavigationBarItem(icon: Icon(Icons.school), label: 'Marks'),
              BottomNavigationBarItem(icon: Icon(Icons.calendar_today), label: 'Attendance'),
              BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
              BottomNavigationBarItem(icon: Icon(Icons.assignment_turned_in), label: 'Requests'),
              BottomNavigationBarItem(icon: Icon(Icons.person), label: 'Profile'),
            ],
          ),
        ),
      ),
    );
  }



  Widget _buildHomeTab(BuildContext context, Color bgColor, Color cardColor, Color accentBlue, Color textColor, Color subTextColor, bool isDark) {
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
                               padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
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
                         child: _buildHeaderIcon(themeProvider.isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round),
                       ),
                       const SizedBox(width: 10),
                       GestureDetector(
                         onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => StudentNotificationsScreen(userId: currentChild['id']))),
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
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: [
                        _buildAnnouncementCard(
                          'Parent-Teacher Meeting',
                          'Saturday, 10 AM',
                          AppTheme.announcementBlue,
                        ),
                         const SizedBox(width: 15),
                        _buildAnnouncementCard(
                          'Results Declared',
                          'Check now',
                          AppTheme.announcementOrange,
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 25),

                  Text(
                    "${currentChild['name']}'s Overview",
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
                          Icons.calendar_today,
                          'Attendance',
                          '95% Present',
                          cardColor,
                          const Color(0xFF2ecc71).withOpacity(0.1), 
                          const Color(0xFF2ecc71),
                          textColor,
                          subTextColor,
                          onTap: () => setState(() => _selectedIndex = 1),
                        ),
                        _buildQuickAccessCard(
                          Icons.insights,
                          'Marks',
                          'View report',
                          cardColor,
                          const Color(0xFF3b5998).withOpacity(0.1),
                          const Color(0xFF3b5998),
                          textColor,
                          subTextColor,
                           onTap: () => setState(() => _selectedIndex = 0),
                        ),
                        _buildQuickAccessCard(
                          Icons.payment,
                          'Fee Payments',
                          'Due: \$0',
                          cardColor,
                          Colors.orange.withOpacity(0.1),
                          Colors.orange,
                          textColor,
                          subTextColor,
                        ),
                        _buildQuickAccessCard(
                          Icons.assignment_turned_in,
                          'Permissions',
                          'New Request',
                          cardColor,
                          Colors.purple.withOpacity(0.1),
                          Colors.purple,
                          textColor,
                          subTextColor,
                           onTap: () => setState(() => _selectedIndex = 3),
                        ),
                    ]
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
        color: Colors.white.withOpacity(0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withOpacity(0.5), width: 1),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildAnnouncementCard(String title, String subtitle, List<Color> gradientColors) {
    return Container(
      width: 250,
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: gradientColors,
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ]
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
                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  subtitle,
                  style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.8), fontSize: 13),
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
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
             color: isDark ? Colors.white10 : Colors.black.withOpacity(0.03),
             width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withOpacity(0.2) : Colors.grey.withOpacity(0.1),
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
                color: iconColor.withOpacity(0.1),
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
