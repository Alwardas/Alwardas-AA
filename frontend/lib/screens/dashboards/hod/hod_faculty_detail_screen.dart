import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/models/faculty_model.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';

import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/api_constants.dart';
import '../../common/common_lesson_plan_viewer.dart';

class HodFacultyDetailScreen extends StatefulWidget {
  final BackendFacultyMember faculty;

  const HodFacultyDetailScreen({super.key, required this.faculty});

  @override
  State<HodFacultyDetailScreen> createState() => _HodFacultyDetailScreenState();
}

class _HodFacultyDetailScreenState extends State<HodFacultyDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _assignedCourses = [];
  bool _loadingCourses = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _fetchFacultyCourses();
  }

  Future<void> _fetchFacultyCourses() async {
    setState(() => _loadingCourses = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/faculty/subjects?userId=${widget.faculty.id}'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _assignedCourses = data;
          _loadingCourses = false;
        });
      } else {
        setState(() => _loadingCourses = false);
      }
    } catch (e) {
      debugPrint("Error fetching courses: $e");
      setState(() => _loadingCourses = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? ThemeColors.darkBackground : ThemeColors.lightBackground;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Faculty Profile", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Creative Faculty Card
              Container(
                margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5)),
                  ],
                  border: Border.all(color: iconBg.withValues(alpha: 0.5)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: tint, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 32,
                            backgroundColor: tint.withValues(alpha: 0.1),
                            child: Text(
                              widget.faculty.name.isNotEmpty ? widget.faculty.name[0].toUpperCase() : '?', 
                              style: TextStyle(color: tint, fontWeight: FontWeight.bold, fontSize: 26)
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.faculty.name, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: tint.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "ID: ${widget.faculty.loginId}", 
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: tint)
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoItem(Icons.email_outlined, widget.faculty.email, subTextColor),
                        _buildInfoItem(Icons.phone_outlined, widget.faculty.phone, subTextColor),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Creative Tab Bar
              Container(
                height: 50,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: iconBg.withValues(alpha: 0.5)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: tint,
                    boxShadow: [
                      BoxShadow(color: tint.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 2))
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: subTextColor,
                  labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                  padding: const EdgeInsets.all(4),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  splashBorderRadius: BorderRadius.circular(25),
                  tabs: const [
                    Tab(text: "Courses"),
                    Tab(text: "Attend."),
                    Tab(text: "Comments"),
                    Tab(text: "Time Table"),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. Expanded Tab View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildCoursesTab(context),
                    _buildPlaceholderTab(context, Icons.bar_chart, "Attendance Stats", "Faculty attendance records and statistics."),
                    _buildCommentsTab(context),
                    _buildPlaceholderTab(context, Icons.schedule, "Weekly Schedule", "Detailed time table for the week."),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, Color color) {
    return Row(
      children: [
        Icon(icon, size: 16, color: color),
        const SizedBox(width: 8),
        SizedBox(
          width: 100, // Limit width
          child: Text(text, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 12, color: color)),
        ),
      ],
    );
  }

  Widget _buildCoursesTab(BuildContext context) {
    if (_loadingCourses) {
      final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
      return Center(child: CircularProgressIndicator(color: isDark ? ThemeColors.darkTint : ThemeColors.lightTint));
    }

    if (_assignedCourses.isEmpty) {
      return _buildPlaceholderTab(context, Icons.book_outlined, "No Courses", "No active courses found for this faculty.");
    }

    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: _assignedCourses.length,
      itemBuilder: (ctx, index) {
        final course = _assignedCourses[index];
        final subjectId = course['subject_id']; // Ensure backend returns this
        final subjectName = course['name'] ?? 'Unknown Subject';
        final branch = course['branch'] ?? '';
        final sem = course['semester'] ?? '';

        return GestureDetector(
          onTap: () {
            // Navigate to Lesson Plan View
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CommonLessonPlanViewer(
                subjectId: subjectId, 
                subjectName: subjectName,
                facultyName: widget.faculty.name,
              ))
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: iconBg),
              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 8)],
            ),
            child: Row(
              children: [
                Container(
                  width: 55, 
                  height: 55,
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    color: tint.withValues(alpha: 0.05),
                    shape: BoxShape.circle,
                  ),
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                       CircularProgressIndicator(
                         value: (course['completion_percentage'] ?? 0) / 100,
                         backgroundColor: iconBg,
                         color: _getStatusColor(course['completion_percentage'] ?? 0),
                         strokeWidth: 4,
                       ),
                       Text(
                         "${course['completion_percentage'] ?? 0}%",
                         style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: textColor),
                       ),
                    ],
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(subjectName, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                      Text("$branch • $sem", style: TextStyle(fontSize: 13, color: Colors.grey)),
                    ],
                  ),
                ),
                Icon(Icons.chevron_right, color: Colors.grey[400]),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCommentsTab(BuildContext context) {
    return FutureBuilder<List<dynamic>>(
      future: _fetchFacultyFeedback(),
      builder: (context, snapshot) {
         if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
         }
         if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
         }
         
         final feedbacks = snapshot.data ?? [];
         
         if (feedbacks.isEmpty) {
            return _buildPlaceholderTab(context, Icons.chat_bubble_outline, "No Comments", "No feedback available for this faculty.");
         }
         
         final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
         final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
         final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
         final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;

         return ListView.separated(
            padding: const EdgeInsets.all(20),
            itemCount: feedbacks.length,
            separatorBuilder: (ctx, index) => const SizedBox(height: 15),
            itemBuilder: (ctx, index) {
               final item = feedbacks[index];
               // format date
               // item['createdAt']
               
               return Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
                  ),
                  child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                  Text(item['subjectName'] ?? 'Subject', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: textColor)),
                                  // Rating
                                  Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                      decoration: BoxDecoration(
                                          color: _getRatingColor(item['rating'] ?? 0).withValues(alpha: 0.1),
                                          borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                          children: [
                                              Icon(Icons.star, size: 14, color: _getRatingColor(item['rating'] ?? 0)),
                                              const SizedBox(width: 4),
                                              Text("${item['rating'] ?? 0}", style: TextStyle(fontWeight: FontWeight.bold, color: _getRatingColor(item['rating'] ?? 0))),
                                          ],
                                      ),
                                  ),
                              ],
                          ),
                          const SizedBox(height: 8),
                          Text(item['comment'] ?? '', style: GoogleFonts.poppins(fontSize: 13, color: textColor)),
                          if (item['reply'] != null) ...[
                             const SizedBox(height: 8),
                             Container(
                                 padding: const EdgeInsets.all(8),
                                 decoration: BoxDecoration(
                                     color: isDark ? Colors.black26 : Colors.grey[100],
                                     borderRadius: BorderRadius.circular(8),
                                 ),
                                 child: Row(
                                     children: [
                                         const Icon(Icons.reply, size: 14, color: Colors.blue),
                                         const SizedBox(width: 8),
                                         Expanded(child: Text("Reply: ${item['reply']}", style: TextStyle(fontSize: 12, color: subTextColor, fontStyle: FontStyle.italic))),
                                     ], 
                                 ),
                             ),
                          ]
                      ],
                  ),
               );
            },
         );
      },
    );
  }

  Future<List<dynamic>> _fetchFacultyFeedback() async {
      try {
          final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/faculty/feedbacks?facultyId=${widget.faculty.id}'));
          if (response.statusCode == 200) {
              return json.decode(response.body);
          }
      } catch (e) {
          debugPrint("Error fetching feedback: $e");
      }
      return [];
  }
  
  Color _getRatingColor(int rating) {
      if (rating >= 4) return Colors.green;
      if (rating >= 2) return Colors.orange;
      return Colors.red;
  }

  Widget _buildPlaceholderTab(BuildContext context, IconData icon, String title, String subtitle) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? ThemeColors.darkCard : ThemeColors.lightCard, // Match card color
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80, height: 80,
            decoration: BoxDecoration(
              color: tint.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: tint),
          ),
          const SizedBox(height: 24),
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 12),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: subTextColor, fontSize: 15, height: 1.5)),
        ],
      ),
    );
  }
  Color _getStatusColor(int percentage) {
    if (percentage < 30) return Colors.red;
    if (percentage > 80) return Colors.orange; // Overfast
    return Colors.green;
  }
}

