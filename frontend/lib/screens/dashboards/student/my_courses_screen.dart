import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import 'package:shimmer/shimmer.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/api_constants.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'student_lesson_plan_screen.dart'; // Keep this for navigation
import '../../../data/courses_data.dart';

class MyCoursesScreen extends StatefulWidget {
  final String? userId;
  const MyCoursesScreen({super.key, this.userId});

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
      final String? userId = widget.userId ?? user['id'];
      if (userId == null) {
          setState(() => _isLoading = false);
          return;
      }
      
      // Get student info from session
      final studentBranch = user['branch'] ?? '';
      final studentSemester = user['semester'] ?? user['year'] ?? '';
      final studentSection = user['section'] ?? 'Section A';

      // Update header subtitle
      String subtitle = "$studentBranch • $studentSemester";
      if (studentSection.isNotEmpty) {
          subtitle += "\n$studentSection";
      }
      setState(() {
        _headerSubtitle = subtitle;
      });

      // 1. Load curriculum from local assets (Source of Truth)
      final allCurriculumCourses = await CoursesData.getAllCourses();
      
      // Filter by student's branch and semester
      // Normalize values for comparison
      final normalizedBranch = _normalizeBranch(studentBranch);
      final normalizedSemester = _normalizeSemester(studentSemester);
      
      final List<dynamic> localCourses = allCurriculumCourses.where((c) {
        return c['branch'] == normalizedBranch && c['semester'] == normalizedSemester;
      }).toList();

      debugPrint("Local courses found for $normalizedBranch / $normalizedSemester: ${localCourses.length}");

      // 2. Fetch assigned courses and progress from API
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/student/courses?userId=$userId'),
      );

      List<dynamic> apiCourses = [];
      if (response.statusCode == 200) {
        final dynamic decoded = json.decode(response.body);
        if (decoded is List) {
          apiCourses = decoded;
        } else if (decoded is Map && decoded['success'] == true) {
          apiCourses = decoded['data'] ?? [];
        }
      }

      // 3. Merge: Local subjects + API progress/faculty
      final List<dynamic> mergedCourses = localCourses.map((local) {
        // Try to find matching course in API results
        final apiMatch = apiCourses.firstWhere(
          (api) => api['subjectCode'] == local['code'] || api['id'] == local['id'],
          orElse: () => null,
        );

        if (apiMatch != null) {
          return {
            ...local,
            'facultyName': apiMatch['facultyName'] ?? apiMatch['faculty_name'] ?? 'TBA',
            'progress': apiMatch['progress'] ?? 0,
            'status': apiMatch['status'] ?? 'On Track',
            'subjectType': apiMatch['subjectType'] ?? local['type'] ?? 'Theory',
            'facultyEmail': apiMatch['facultyEmail'],
            'facultyPhone': apiMatch['facultyPhone'],
            'facultyDepartment': apiMatch['facultyDepartment'],
          };
        } else {
          // Subject exists in curriculum but not yet assigned/tracked in DB
          return {
            ...local,
            'facultyName': 'TBA',
            'progress': 0,
            'status': 'On Track',
            'subjectType': local['type'] ?? 'Theory',
          };
        }
      }).toList();

      setState(() {
        _courses = mergedCourses;
      });
      
    } catch (e) {
      debugPrint("Error fetching courses: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // Helper normalizers to match CoursesData logic
  String _normalizeBranch(String b) {
    String upper = b.toUpperCase();
    if (upper == 'CME' || upper.contains('COMPUTER')) return 'Computer Engineering';
    if (upper == 'CIV' || upper == 'CIVIL') return 'Civil Engineering';
    if (upper == 'ECE' || upper.contains('ELECTRONICS')) return 'Electronics & Communication Engineering';
    if (upper == 'EEE' || upper.contains('ELECTRICAL')) return 'Electrical and Electronics Engineering';
    if (upper == 'MECH' || upper == 'MEC' || upper.contains('MECHANICAL')) return 'Mechanical Engineering';
    return b;
  }

  String _normalizeSemester(String sem) {
    String s = sem.toLowerCase();
    if (s.contains('1') && !s.contains('3') && !s.contains('5')) return '1st Year';
    if (s.contains('3')) return '3rd Semester';
    if (s.contains('4')) return '4th Semester';
    if (s.contains('5')) return '5th Semester';
    if (s.contains('6')) return '6th Semester';
    return sem;
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
    
    // Ensure gradient covers the entire screen including behind AppBar
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        automaticallyImplyLeading: false, // Back button handled manually if needed, or by navigation stack
        title: Text(
          "My Courses",
          style: GoogleFonts.poppins(
            color: headingColor,
            fontWeight: FontWeight.w700,
            fontSize: 22,
          ),
        ),
        iconTheme: IconThemeData(color: headingColor),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? AppTheme.darkBodyGradient : AppTheme.lightBodyGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
                // Header Subtitle
                Center(
                   child: Text(
                     _headerSubtitle,
                     textAlign: TextAlign.center,
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
                     ? _buildSkeletonCourseList(isDark)
                     : displayedCourses.isEmpty 
                        ? _buildEmptyState(subHeadingColor)
                        : _buildCourseList(displayedCourses, isDark),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSkeletonCourseList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
      itemCount: 4, // Number of skeleton items
      itemBuilder: (context, index) {
        return Shimmer.fromColors(
          baseColor: isDark ? const Color(0xFF1E1E2C) : Colors.grey.shade300,
          highlightColor: isDark ? const Color(0xFF2C2C2E) : Colors.grey.shade100,
          child: Container(
            margin: const EdgeInsets.only(bottom: 16),
            height: 120, // Approximate height of course item
            decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
              borderRadius: BorderRadius.circular(20),
            ),
          ),
        );
      },
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
    final facultyEmail = course['facultyEmail'];
    final facultyPhone = course['facultyPhone'];
    final facultyDept = course['facultyDepartment'];
    
    // Status Logic
    String statusText = course['status'] ?? 'On Track';
    Color statusColor;
    
    // Normalize status text
    if (statusText.toLowerCase() == 'overfast') {
      statusText = "Overfast";
      statusColor = Colors.orange;
    } else if (statusText.toLowerCase() == 'lagging') {
      statusText = "Lagging";
      statusColor = const Color(0xFFFF4B4B); // Red
    } else {
      statusText = "On Track";
      statusColor = const Color(0xFF34C759); // Green
    }
    
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () async {
            final user = await AuthService.getUserSession();
            if (!mounted) return;
            
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => StudentLessonPlanScreen(
                  subjectId: course['id'] ?? '',
                  subjectName: course['name'] ?? 'Lesson Plan',
                  facultyName: facultyName,
                  branch: user?['branch'] ?? 'Computer Engineering',
                  section: user?['section'],
                  year: user?['year'],
                  semester: int.tryParse(user?['semester']?.toString() ?? '1') ?? 1,
                ),
              ),
            );
          },
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header Row: Course ID and Faculty Name
            Row(
              children: [
                Flexible(
                  child: Text(
                    course['subjectCode'] ?? course['id'] ?? '',
                    style: GoogleFonts.poppins(
                      color: courseIdColor,
                      fontSize: 13, 
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: GestureDetector(
                    onTap: () {
                      if (facultyName != 'TBA') {
                        _showFacultyDetails(context, facultyName, facultyDept, facultyEmail, facultyPhone);
                      }
                    },
                    child: Text(
                      facultyName,
                      style: GoogleFonts.poppins(
                        color: subtitleColor,
                        fontSize: 12, 
                        fontWeight: FontWeight.w500,
                        decoration: facultyName != 'TBA' ? TextDecoration.underline : null,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 8), // Tighter spacing

            // Course Name
            Text(
              "${course['subjectCode'] ?? course['id']} - ${course['name']}",
              style: GoogleFonts.manrope(
                color: titleColor,
                fontSize: 16,
                fontWeight: FontWeight.w700,
                height: 1.2,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
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
    ),
  ),
);
  }


  void _showFacultyDetails(BuildContext context, String name, String? dept, String? email, String? phone) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Faculty Details", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildDetailRow(Icons.person, "Name", name),
            const SizedBox(height: 10),
            _buildDetailRow(Icons.business, "Department", dept ?? "N/A"),
            const SizedBox(height: 10),
            _buildDetailRow(Icons.email, "Email", email ?? "N/A"),
            const SizedBox(height: 10),
            _buildDetailRow(Icons.phone, "Phone", phone ?? "N/A"),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text("Close", style: GoogleFonts.poppins()),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: Colors.blueAccent),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
              Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w500)),
            ],
          ),
        ),
      ],
    );
  }
}
