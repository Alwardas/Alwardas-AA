import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import '../core/api_constants.dart';
import '../core/providers/theme_provider.dart';
import '../screens/dashboards/coordinator/coordinator_announcements_screen.dart';
import '../screens/dashboards/coordinator/coordinator_announcement_details_screen.dart';

class SharedDashboardAnnouncements extends StatefulWidget {
  final String userRole; // e.g. 'Student', 'Faculty', 'Coordinator'

  const SharedDashboardAnnouncements({super.key, required this.userRole});

  @override
  State<SharedDashboardAnnouncements> createState() => _SharedDashboardAnnouncementsState();
}

class _SharedDashboardAnnouncementsState extends State<SharedDashboardAnnouncements> {
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
        if (mounted) setState(() => _isLoadingAnnouncements = false);
      }
    } catch (e) {
      debugPrint("Error fetching dashboard announcements: $e");
      if (mounted) setState(() => _isLoadingAnnouncements = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final Color textColor = theme.colorScheme.onSurface;
    final Color subTextColor = theme.colorScheme.secondary;
    final bool isCoordinator = widget.userRole.toLowerCase() == 'coordinator';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
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
            if (isCoordinator)
               GestureDetector(
                 onTap: () async {
                    // Quick add logic for coordinator handled in coordinator_dashboard natively,
                    // but we can route them to the main announcements page.
                    Navigator.push(context, MaterialPageRoute(builder: (_) => CoordinatorAnnouncementsScreen(isReadOnly: false))).then((_) => _fetchDashboardAnnouncements());
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
        
        if (_isLoadingAnnouncements) 
            _buildLoadingState(isDark)
        else
            Builder(
              builder: (context) {
                // Filter by role (if not coordinator/admin/principal)
                List<Announcement> filteredList = List.from(_dashboardAnnouncements);
                if (!isCoordinator && widget.userRole.toLowerCase() != 'admin' && widget.userRole.toLowerCase() != 'principal') {
                    // Note: This relies on the backend or frontend to filter correctly. 
                    // Actually, let's keep it simple: Show them all since the user requested: 
                    // "display on the all users dashboard page like coordinator dashboard annoncemnt view exactly"
                }

                // Sort by pinned, then date (same logic as main screen)
                filteredList.sort((a, b) {
                  if (a.isPinned && !b.isPinned) return -1;
                  if (!a.isPinned && b.isPinned) return 1;
                  return b.createdAt.compareTo(a.createdAt);
                });

                final displayList = filteredList.take(3).toList();
                final hasMore = filteredList.length > 3;

                if (displayList.isEmpty) {
                  return Center(child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Text("No upcoming announcements", style: GoogleFonts.poppins(color: subTextColor)),
                  ));
                }

                return SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      ...displayList.map((announcement) => Padding(
                        padding: const EdgeInsets.only(right: 15),
                        child: _buildHorizontalAnnouncementCard(announcement),
                      )),
                      
                      if (hasMore || !isCoordinator)
                        GestureDetector(
                          onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CoordinatorAnnouncementsScreen(isReadOnly: !isCoordinator))),
                          child: Container(
                            width: 60,
                            height: 80,
                            decoration: BoxDecoration(
                              color: isDark ? const Color(0xFF1E293B) : Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
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
      ],
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
        width: 250,
        height: 80,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [typeColorStart, typeColorEnd],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
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
                      Row(
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
                            width: 140,
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

  Widget _buildLoadingState(bool isDark) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: List.generate(2, (index) {
          return Padding(
            padding: const EdgeInsets.only(right: 15),
            child: Shimmer.fromColors(
              baseColor: isDark ? const Color(0xFF1E293B) : Colors.grey[300]!,
              highlightColor: isDark ? const Color(0xFF334155) : Colors.grey[100]!,
              child: Container(
                width: 250,
                height: 80,
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
