import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/api_constants.dart';
import '../../../theme/theme_constants.dart';
import 'coordinator_create_announcement_screen.dart';
import 'coordinator_announcement_details_screen.dart';

class CoordinatorAnnouncementsScreen extends StatefulWidget {
  const CoordinatorAnnouncementsScreen({super.key});

  @override
  State<CoordinatorAnnouncementsScreen> createState() => _CoordinatorAnnouncementsScreenState();
}

class _CoordinatorAnnouncementsScreenState extends State<CoordinatorAnnouncementsScreen> {
  String _currentTab = 'Upcoming';
  final TextEditingController _searchController = TextEditingController();
  bool _isSearchExpanded = false;
  List<Announcement> _announcements = []; 
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/announcement'));
      
      if (response.statusCode == 200) {
        final List<dynamic> data = jsonDecode(response.body);
        if (mounted) {
          setState(() {
            _announcements = data.map((json) => Announcement.fromJson(json)).toList();
            _isLoading = false;
          });
        }
      } else {
        debugPrint("Failed api call: ${response.body}");
        _loadMock();
      }
    } catch (e) {
       debugPrint("Error fetching announcements: $e");
       _loadMock();
    }
  }

  void _loadMock() {
      if (mounted) {
          setState(() {
            _announcements = _getMockAnnouncements();
            _isLoading = false;
          });
      }
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
      // ... keep existing mocks ...
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

// ... existing code ...


  List<Announcement> get _filteredAnnouncements {
    // Create a copy to avoid mutating the original source
    List<Announcement> filtered = List.from(_announcements);

    // Filter by Tab
    final now = DateTime.now();
    if (_currentTab == 'Upcoming') {
      filtered = filtered.where((a) => a.endDate.isAfter(now)).toList();
    } else if (_currentTab == 'Completed') {
      filtered = filtered.where((a) => a.endDate.isBefore(now)).toList();
    }
    // 'All' shows everything

    // Search
    if (_searchController.text.isNotEmpty) {
      filtered = filtered.where((a) => a.title.toLowerCase().contains(_searchController.text.toLowerCase())).toList();
    }

    // Sort by Pinned first, then date
    filtered.sort((a, b) {
      // 1. Pinned status
      if (a.isPinned && !b.isPinned) return -1; // a comes first
      if (!a.isPinned && b.isPinned) return 1;  // b comes first
      
      // 2. Date (Newest first)
      return b.createdAt.compareTo(a.createdAt);
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    // UI Constants based on prompt
    const Color neonCyan = Color(0xFF00E5FF); 
    const Color headerBgStart = Color(0xFF1E1E2C); // Dark fallback
    // Gradient header strip (same as dashboard if we knew it, simulating dark rich)
    
    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : Colors.grey[50], // Dark Body
      body: Column(
        children: [
          // 1. APP BAR (Custom)
          _buildAppBar(context, isDark),

          // 2. FILTER TABS
          _buildFilterTabs(isDark),

          // 3. ANNOUNCEMENT LIST
          Expanded(
            child: _isLoading 
              ? _buildLoadingState(isDark)
              : _filteredAnnouncements.isEmpty 
                  ? _buildEmptyState(isDark)
                  : RefreshIndicator(
                      onRefresh: _fetchAnnouncements,
                      color: neonCyan,
                      child: AnimationLimiter(
                        child: ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _filteredAnnouncements.length,
                          itemBuilder: (context, index) {
                            return AnimationConfiguration.staggeredList(
                              position: index,
                              duration: const Duration(milliseconds: 375),
                              child: SlideAnimation(
                                verticalOffset: 50.0,
                                child: FadeInAnimation(
                                  child: GestureDetector(
                                    onTap: () {
                                      Navigator.push(context, MaterialPageRoute(builder: (_) => CoordinatorAnnouncementDetailsScreen(announcement: _filteredAnnouncements[index])));
                                    },
                                    child: _buildAnnouncementCard(context, _filteredAnnouncements[index], isDark),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
             Navigator.push(context, MaterialPageRoute(builder: (_) => const CoordinatorCreateAnnouncementScreen()));
        },
        backgroundColor: Colors.blueAccent,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAppBar(BuildContext context, bool isDark) {
    return Container(
      padding: EdgeInsets.only(top: MediaQuery.of(context).padding.top + 10, left: 20, right: 20, bottom: 20),
      child: Column(
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: () => Navigator.pop(context),
                child: _buildGlassIcon(Icons.arrow_back_ios_new, isDark),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Text(
                  'All Announcements',
                  style: GoogleFonts.poppins(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                onTap: () => setState(() => _isSearchExpanded = !_isSearchExpanded),
                child: _buildGlassIcon(Icons.search, isDark),
              ),
            ],
          ),
          if (_isSearchExpanded)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              margin: const EdgeInsets.only(top: 15),
              height: 50,
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(15),
                border: Border.all(color: isDark ? Colors.white.withValues(alpha: 0.2) : Colors.black.withValues(alpha: 0.1))
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: isDark ? Colors.white : Colors.black),
                onChanged: (val) => setState((){}),
                decoration: InputDecoration(
                  hintText: 'Search announcements...',
                  hintStyle: TextStyle(color: isDark ? Colors.white.withValues(alpha: 0.5) : Colors.black.withValues(alpha: 0.5)),
                  prefixIcon: Icon(Icons.search, color: isDark ? Colors.white.withValues(alpha: 0.7) : Colors.black.withValues(alpha: 0.7)),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                ),
              ),
            )
        ],
      ),
    );
  }
 
  Widget _buildGlassIcon(IconData icon, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Icon(icon, color: isDark ? Colors.white : Colors.black, size: 28),
    );
  }

  Widget _buildFilterTabs(bool isDark) {
    final tabs = ['Upcoming', 'All', 'Completed'];
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 10),
        height: 40,
        child: SingleChildScrollView( // Changed to allow scrolling if screen is too narrow, but centered if matches
          scrollDirection: Axis.horizontal,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: tabs.map((tab) {
                final isSelected = _currentTab == tab;
                return GestureDetector(
                  onTap: () => setState(() => _currentTab = tab),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 5), // Added margin here instead of separator
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), // Increased padding
                    decoration: BoxDecoration(
                      color: isSelected ? (isDark ? Colors.blueAccent : Colors.black) : Colors.transparent,
                      borderRadius: BorderRadius.circular(20),
                      border: isSelected ? null : Border.all(color: Colors.grey.withOpacity(0.5)),
                    ),
                    child: Text(
                      tab,
                      style: GoogleFonts.poppins(
                        color: isSelected ? Colors.white : (isDark ? Colors.grey : Colors.black87),
                        fontWeight: FontWeight.w500,
                        fontSize: 14,
                      ),
                    ),
                  ),
                );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(BuildContext context, Announcement announcement, bool isDark) {
      Color typeColorStart;
      Color typeColorEnd;
      IconData typeIcon;
      // Define audience colors (Target Audience types: Students, Faculty, HODs, Principal, Parents, All)
      // Map based on first audience entry for simplicity
      String audience = announcement.audience.isNotEmpty ? announcement.audience.first : 'All';
      
      // Default
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

      // Icon based on type still seems appropriate or should icon also be audience based?
      // Prompt says "annoucemnets cards must be in differnt different colors based on the type targent audience"
      // It implies card styling.

      switch(announcement.type) {
         case AnnouncementType.exam: typeIcon = Icons.campaign_outlined; break;
         case AnnouncementType.event: typeIcon = Icons.calendar_today; break;
         case AnnouncementType.faculty: typeIcon = Icons.school; break;
         case AnnouncementType.urgent: typeIcon = Icons.warning_amber_rounded; break;
         default: typeIcon = Icons.info_outline;
      }
      
      final now = DateTime.now();
      bool isScheduled = announcement.startDate.isAfter(now);
      bool isExpired = announcement.endDate.isBefore(now);
      
      Duration remaining = isScheduled 
          ? announcement.startDate.difference(now) 
          : announcement.endDate.difference(now);
          
      int daysRem = remaining.inDays;
      int hoursRem = remaining.inHours % 24;

      String timeText;
      Color timeColor;

      if (isScheduled) {
         timeText = daysRem > 0 ? "Starts in $daysRem days" : "Starts in $hoursRem hours";
         timeColor = Colors.blue;
      } else if (isExpired) {
         timeText = "Expired";
         timeColor = Colors.grey;
      } else {
         timeText = daysRem == 0 ? "Expires Today" : "$daysRem days left";
         timeColor = daysRem <= 2 ? Colors.red : (daysRem <= 5 ? Colors.orange : Colors.grey);
         if (daysRem == 0) timeColor = Colors.cyan;
      }

      return GestureDetector(
        onLongPress: () {
           showModalBottomSheet(
             context: context,
             backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
             shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
             builder: (ctx) => Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                 const SizedBox(height: 10),
                 Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2))),
                 const SizedBox(height: 20),
                 ListTile(
                   leading: Icon(Icons.push_pin, color: isDark ? Colors.white : Colors.black),
                   title: Text(announcement.isPinned ? 'Unpin Announcement' : 'Pin Announcement', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                   onTap: () {
                     // Toggle Pin Logic Mock
                     Navigator.pop(ctx);
                   },
                 ),
                 ListTile(
                   leading: const Icon(Icons.edit_note, color: Colors.blue),
                   title: Text('Move to Draft', style: TextStyle(color: isDark ? Colors.white : Colors.black)),
                   onTap: () {
                     Navigator.pop(ctx);
                   },
                 ),
                 ListTile(
                   leading: const Icon(Icons.delete, color: Colors.red),
                   title: const Text('Delete', style: TextStyle(color: Colors.red)),
                   onTap: () {
                     Navigator.pop(ctx);
                   },
                 ),
                 const SizedBox(height: 20),
               ],
             ) 
           );
        },
        child: Container(
          margin: const EdgeInsets.only(bottom: 16),
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
               color: typeColorStart.withValues(alpha: 0.3),
               blurRadius: 15,
               offset: const Offset(0, 8),
             )
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [


              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         // Left Icon
                        Hero(
                          tag: 'icon_${announcement.id}',
                          child: Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.2),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(typeIcon, color: Colors.white, size: 22),
                          ),
                        ),
                        const SizedBox(width: 12),
                        // Title & Audience
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                announcement.title,
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                announcement.audience.join(", "),
                                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Date Row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                         Row(
                           children: [
                             const SizedBox(width: 10),
                             const Icon(Icons.calendar_today_outlined, size: 14, color: Colors.white70),
                             const SizedBox(width: 5),
                             Text(
                                DateFormat('EEE, MMM d, yyyy').format(announcement.startDate),
                                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                             ),
                           ],
                         ),
                         Text(
                             "${DateFormat('hh:mm a').format(announcement.startDate)} • $timeText",
                             style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
                         )
                      ],
                    )
                  ],
                ),
              ),

              if (isScheduled)
                 Positioned(
                  top: 12,
                  right: 40,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text('SCHEDULED', style: GoogleFonts.poppins(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(bool isDark) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox_outlined, size: 60, color: Colors.grey.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text(
            'No announcements found',
            style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16),
          ),
          TextButton(
             onPressed: () => setState(() { _currentTab = 'All'; _searchController.clear(); }),
             child: const Text('Clear Filters'),
          )
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isDark) {
      return Shimmer.fromColors(
          baseColor: isDark ? const Color(0xFF0F172A) : Colors.grey[300]!,
          highlightColor: isDark ? const Color(0xFF1E293B) : Colors.grey[100]!,
          child: ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: 4,
            itemBuilder: (_, __) => Container(
              height: 120,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
      );
  }
}

// Models
enum AnnouncementType { exam, faculty, event, holiday, general, urgent }
enum AnnouncementPriority { normal, important, urgent }

class Announcement {
  final String id;
  final String title;
  final String description;
  final AnnouncementType type;
  final List<String> audience;
  final AnnouncementPriority priority;
  final DateTime startDate;
  final DateTime endDate;
  final DateTime createdAt;
  final bool isNew;
  final bool isPinned;

  Announcement({
    required this.id,
    required this.title,
    required this.description,
    required this.type,
    required this.audience,
    required this.priority,
    required this.startDate,
    required this.endDate,
    required this.createdAt,
    this.isNew = false,
    this.isPinned = false,
  });

  factory Announcement.fromJson(Map<String, dynamic> json) {
    return Announcement(
      id: json['id'],
      title: json['title'],
      description: json['description'],
      type: AnnouncementType.values.firstWhere(
        (e) => e.toString().split('.').last == json['type'], 
        orElse: () => AnnouncementType.general
      ),
      audience: List<String>.from(json['audience'] ?? []),
      priority: AnnouncementPriority.values.firstWhere(
        (e) => e.toString().split('.').last == json['priority'], 
        orElse: () => AnnouncementPriority.normal
      ),
      startDate: DateTime.parse(json['start_date']),
      endDate: DateTime.parse(json['end_date']),
      createdAt: DateTime.parse(json['created_at']),
      isNew: DateTime.now().difference(DateTime.parse(json['created_at'])).inHours < 24,
      isPinned: json['is_pinned'] ?? false,
    );
  }
}
