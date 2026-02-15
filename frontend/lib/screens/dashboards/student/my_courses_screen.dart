import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/api_constants.dart';
import '../../../core/providers/theme_provider.dart';
import 'student_lesson_plan_screen.dart'; // Keep this for navigation

class MyCoursesScreen extends StatefulWidget {
  const MyCoursesScreen({super.key});

  @override
  State<MyCoursesScreen> createState() => _MyCoursesScreenState();
}

class _MyCoursesScreenState extends State<MyCoursesScreen> {
  bool _isLoading = true;
  List<dynamic> _courses = [];
  String _headerSubtitle = "Loading details...";
  
  // Filter state
  String _selectedFilter = 'Theory';
  bool _dropdownVisible = false;
  final List<String> _filterOptions = ['Theory', 'Practical'];

  // Theme colors usage
  final List<Color> _cardColors = [
    const Color(0xFF4B7FFB), // Blue
    const Color(0xFF34C759), // Green
    const Color(0xFFE67E22), // Orange
    const Color(0xFFA569BD), // Purple
  ];

  @override
  void initState() {
    super.initState();
    _fetchCourses();
  }

  Future<void> _fetchCourses() async {
    final user = await AuthService.getUserSession();
    if (user == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final userId = user['id'];
      // Update header subtitle with user details if available
      if (user['branch'] != null && user['year'] != null) {
         String subtitle = "${user['branch']} • ${user['year']}";
         if (user['semester'] != null && user['semester'].toString().isNotEmpty && user['semester'] != user['year']) {
             subtitle += " • ${user['semester']}";
         }
         setState(() {
           _headerSubtitle = subtitle;
         });
      }

      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/student/courses?userId=$userId'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _courses = data;
        });
      } else {
        debugPrint("Failed to fetch courses: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching courses: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme setup
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    // The image has a very clean white look, but we support dark mode.
    // We'll adapt colors slightly for dark mode, but try to keep the 'vibe'.
    
    // Background colors as per design guidelines or current theme
    // Design image background is very light grey/white.
    // Dark mode: dark background.
    
    // Text Colors
    final headingColor = isDark ? Colors.white : const Color(0xFF1A1A2E); // Dark blueish black
    final subHeadingColor = isDark ? Colors.white70 : Colors.grey[600]!;
    final iconBg = isDark ? Colors.white10 : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    // Filter Logic
    // Backend returns 'subjectType' as 'Theory' or 'Practical'. 
    // If backend returns lowercase, handle case insensitively if needed, but 'Theory' is expected.
    final displayedCourses = _courses.where((c) {
       final type = c['subjectType'] as String? ?? 'Theory';
       return type == _selectedFilter;
    }).toList();
    
    return Scaffold(
      backgroundColor: Colors.transparent, // Parent gradient visible
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false,
        title: Text(
          "My Courses",
          style: GoogleFonts.poppins(
            color: headingColor,
            fontWeight: FontWeight.w700,
            fontSize: 22, // 22-24px
          ),
        ),
      ),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
            // Header Subtitle
            Center(
               child: Text(
                 _headerSubtitle,
                 style: GoogleFonts.poppins(
                   fontSize: 14,
                   color: subHeadingColor,
                   fontWeight: FontWeight.w500,
                 ),
               ),
            ),
            
            const SizedBox(height: 15),

            // Dropdown Filter
            Padding(
               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   GestureDetector(
                     onTap: () => setState(() => _dropdownVisible = !_dropdownVisible),
                     child: Container(
                       padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                       decoration: BoxDecoration(
                         color: iconBg,
                         borderRadius: BorderRadius.circular(12),
                         border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade300),
                         boxShadow: [
                           if (!isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                         ]
                       ),
                       child: Row(
                         mainAxisSize: MainAxisSize.min, // Wrap content
                         children: [
                           Text("$_selectedFilter Subjects", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                           const SizedBox(width: 10),
                           Icon(_dropdownVisible ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: textColor)
                         ],
                       ),
                     ),
                   ),
                   if (_dropdownVisible)
                     Container(
                       margin: const EdgeInsets.only(top: 8),
                       width: 200, 
                       decoration: BoxDecoration(
                         color: isDark ? const Color(0xFF2C2C2E) : Colors.white,
                         borderRadius: BorderRadius.circular(12),
                         boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))],
                       ),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: _filterOptions.map((option) {
                           return InkWell(
                             onTap: () {
                               setState(() {
                                 _selectedFilter = option;
                                 _dropdownVisible = false;
                               });
                             },
                             child: Container(
                               width: double.infinity,
                               padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                               decoration: BoxDecoration(
                                 border: option != _filterOptions.last 
                                    ? Border(bottom: BorderSide(color: isDark ? Colors.white10 : Colors.grey.shade100))
                                    : null
                               ),
                               child: Text(
                                 "$option Subjects",
                                 style: GoogleFonts.poppins(
                                   color: _selectedFilter == option ? const Color(0xFF4B7FFB) : textColor,
                                   fontWeight: _selectedFilter == option ? FontWeight.w600 : FontWeight.normal,
                                 ),
                               ),
                             ),
                           );
                         }).toList(),
                       ),
                     ),
                 ],
               ),
            ),

            const SizedBox(height: 10),

            Expanded(
               child: _isLoading 
                 ? const Center(child: CircularProgressIndicator())
                 : displayedCourses.isEmpty 
                    ? _buildEmptyState(subHeadingColor)
                    : _buildCourseList(displayedCourses, isDark),
            ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color subHeadingColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 64, color: subHeadingColor),
          const SizedBox(height: 16),
          Text(
            "No $_selectedFilter courses assigned.",
            style: GoogleFonts.poppins(color: subHeadingColor, fontSize: 16),
          ),
           const SizedBox(height: 10),
           Text(
             "Branch: $_headerSubtitle", 
             style: GoogleFonts.poppins(color: subHeadingColor, fontSize: 12),
           ),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () { 
                setState(() {
                   _isLoading = true;
                });
                _fetchCourses(); 
            },
            child: const Text("Refresh"),
          )
        ],
      ),
    );
  }

  Widget _buildCourseList(List<dynamic> courses, bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      itemCount: courses.length,
      itemBuilder: (context, index) {
        final course = courses[index];
        // Cycle colors
        final accentColor = _cardColors[index % _cardColors.length];
        return _buildCourseItem(course, accentColor, isDark);
      },
    );
  }

  Widget _buildCourseItem(dynamic course, Color accentColor, bool isDark) {
    // Theme colors
    final cardBg = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E); 
    final subtitleColor = isDark ? Colors.white70 : Colors.grey[600]!;
    // Single color only for Course ID as requested (e.g., standard Blue)
    final courseIdColor = const Color(0xFF4B7FFB); 

    final progress = course['progress'] ?? 0;
    final facultyName = course['facultyName'] ?? course['faculty_name'] ?? 'TBA';
    
    // Status Logic
    String statusText;
    Color statusColor;
    if (progress > 85) {
      statusText = "Overfast";
      statusColor = Colors.orange;
    } else if (progress >= 30) {
      statusText = "On Track";
      statusColor = const Color(0xFF34C759); // Green
    } else {
      statusText = "Lagging";
      statusColor = const Color(0xFFFF4B4B); // Red
    }
    
    return GestureDetector(
       onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => StudentLessonPlanScreen(
              subjectId: course['id'] ?? '',
              subjectName: course['name'] ?? 'Lesson Plan',
              facultyName: facultyName,
            ),
          ),
        );
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16), // Reduced margin
        padding: const EdgeInsets.all(18), // Reduced padding
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(20), // Slightly smaller radius
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Row: Course ID and Faculty Name
            Row(
              children: [
                Text(
                  course['id'] ?? '',
                  style: GoogleFonts.poppins(
                    color: courseIdColor,
                    fontSize: 13, // Smaller font
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    facultyName,
                    style: GoogleFonts.poppins(
                      color: subtitleColor,
                      fontSize: 12, // Smaller font
                      fontWeight: FontWeight.w500,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8), // Tighter spacing

            // Course Name
            Text(
              course['name'] ?? 'Unknown Course',
              style: GoogleFonts.manrope(
                color: titleColor,
                fontSize: 16, // Reduced from 20
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
            ),

            const SizedBox(height: 12),
            
            // Status Row
            Row(
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(color: statusColor.withValues(alpha: 0.4), blurRadius: 6, offset: const Offset(0, 2))
                    ]
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  statusText,
                  style: GoogleFonts.poppins(
                    color: subtitleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // Progress Bar Row
            Row(
              children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (progress as int).toDouble() / 100.0,
                      backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                      color: statusColor, // Match status color
                      minHeight: 6,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "$progress%",
                  style: GoogleFonts.poppins(
                    color: titleColor,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
