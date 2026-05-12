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
      final role = widget.userRole;
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/announcement?role=$role')).timeout(
        const Duration(seconds: 5),
        onTimeout: () => http.Response('[]', 408),
      );
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
    if (!_isLoadingAnnouncements && _dashboardAnnouncements.isEmpty) {
      return const SizedBox.shrink();
    }

    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final Color textColor = theme.colorScheme.onSurface;
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
                // Sort by pinned, then date (same logic as main screen)
                List<Announcement> filteredList = List.from(_dashboardAnnouncements);
                filteredList.sort((a, b) {
                  if (a.isPinned && !b.isPinned) return -1;
                  if (!a.isPinned && b.isPinned) return 1;
                  return b.createdAt.compareTo(a.createdAt);
                });

                final displayList = filteredList.take(3).toList();
                final hasMore = filteredList.length > 3;

                if (displayList.isEmpty) {
                  return const SizedBox.shrink();
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
        const SizedBox(height: 25), // Bottom gap only if shown
      ],
    );
  }

  Widget _buildHorizontalAnnouncementCard(Announcement announcement) {
    Color typeColorStart;
    Color typeColorEnd;
    IconData typeIcon;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    
    String audience = announcement.audience.isNotEmpty ? announcement.audience.first : 'All';

    // Audience Color Logic
    typeColorStart = Colors.grey; typeColorEnd = Colors.blueGrey;
    if (audience.toLowerCase().contains('student')) {
       typeColorStart = const Color(0xFF2E3192); typeColorEnd = const Color(0xFF1BFFFF); // Blue/Cyan
    } else if (audience.toLowerCase().contains('parent') || audience.toLowerCase().contains('exam')) {
       typeColorStart = const Color(0xFFD4145A); typeColorEnd = const Color(0xFFFBB03B); // Pink/Orange
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
      case AnnouncementType.exam: typeIcon = Icons.notifications_none; break;
      case AnnouncementType.event: typeIcon = Icons.calendar_today; break;
      case AnnouncementType.faculty: typeIcon = Icons.school; break;
      case AnnouncementType.urgent: typeIcon = Icons.warning_amber_rounded; break;
      default: typeIcon = Icons.notifications_none;
    }

    return GestureDetector(
      onTap: () {
         Navigator.push(context, MaterialPageRoute(builder: (_) => CoordinatorAnnouncementDetailsScreen(announcement: announcement)));
      },
      child: Container(
        width: MediaQuery.of(context).size.width * 0.75, // Better width for new shape
        height: 75,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(35),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [typeColorStart, typeColorEnd],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: const BorderRadius.only(
                    topLeft: Radius.circular(35),
                    bottomLeft: Radius.circular(35),
                    topRight: Radius.circular(40),
                    bottomRight: Radius.circular(8),
                  ),
                ),
                child: Row(
                  children: [
                    Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Container(
                          width: 75,
                          height: 75,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(35),
                          ),
                          child: Center(
                             child: Icon(typeIcon, color: Colors.white, size: 28),
                          ),
                        ),
                        if (announcement.priority == AnnouncementPriority.urgent)
                          Positioned(
                            right: 8,
                            top: 8,
                            child: Container(
                              width: 10,
                              height: 10,
                              decoration: const BoxDecoration(
                                color: Colors.redAccent,
                                shape: BoxShape.circle,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  announcement.title,
                                  style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (announcement.attachmentUrl != null && announcement.attachmentUrl!.isNotEmpty)
                                const Padding(
                                  padding: EdgeInsets.only(left: 4),
                                  child: Icon(Icons.attach_file, color: Colors.white70, size: 14),
                                ),
                            ],
                          ),
                          Text(
                            audience,
                            style: GoogleFonts.poppins(color: Colors.white.withValues(alpha: 0.8), fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Container(
              width: 80,
              alignment: Alignment.center,
              child: Text(
                DateFormat('dd MMM').format(announcement.startDate),
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.grey[400] : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                  fontSize: 14,
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
