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
import '../../common/erp_connect_screen.dart';

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
  Map<String, dynamic>? _currentUser;
  
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

    setState(() {
      _currentUser = user;
    });

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

      debugPrint("Student Profile: Branch=$studentBranch, Semester=$studentSemester");

      // 1. Load curriculum from local assets (Source of Truth)
      final allCurriculumCourses = await CoursesData.getAllCourses();
      
      // Filter by student's branch and semester
      // Normalize values for comparison
      final normalizedBranch = CoursesData.normalizeBranch(studentBranch);
      final normalizedSemester = CoursesData.normalizeSemester(studentSemester);
      
      debugPrint("Normalized: Branch=$normalizedBranch, Semester=$normalizedSemester");

      final List<dynamic> localCourses = allCurriculumCourses.where((c) {
        final localBranch = CoursesData.normalizeBranch(c['branch']?.toString() ?? '');
        final localSem = CoursesData.normalizeSemester(c['semester']?.toString() ?? '');
        return localBranch == normalizedBranch && localSem == normalizedSemester;
      }).toList();

      debugPrint("Matched local courses count: ${localCourses.length}");
      if (localCourses.isEmpty && allCurriculumCourses.isNotEmpty) {
          debugPrint("Example course from assets: Branch=${allCurriculumCourses[0]['branch']}, Sem=${allCurriculumCourses[0]['semester']}");
      }

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
            'facultyId': apiMatch['facultyId'] ?? apiMatch['faculty_id'],
          };
        } else {
          // Subject exists in curriculum but not yet assigned/tracked in DB
          return {
            ...local,
            'facultyName': 'TBA',
            'progress': 0,
            'status': 'On Track',
            'subjectType': local['type'] ?? 'Theory',
            'facultyId': null,
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
    // We'll use a case-insensitive match for robustness.
    final displayedCourses = _courses.where((c) {
       final type = (c['subjectType'] ?? c['type'] ?? 'Theory').toString();
       return type.toLowerCase() == _selectedFilter.toLowerCase();
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
                   child: RefreshIndicator(
                     onRefresh: _fetchCourses,
                     child: _isLoading 
                       ? _buildSkeletonCourseList(isDark)
                       : displayedCourses.isEmpty 
                          ? SingleChildScrollView(
                              physics: const AlwaysScrollableScrollPhysics(),
                              child: Container(
                                height: MediaQuery.of(context).size.height * 0.6,
                                alignment: Alignment.center,
                                child: _buildEmptyState(subHeadingColor),
                              ),
                            )
                          : _buildCourseList(displayedCourses, isDark),
                   ),
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
             "Debug Info:\nProfile Branch: $_headerSubtitle\nNormalized Branch: ${CoursesData.normalizeBranch(_headerSubtitle.split(' • ')[0])}\nNormalized Semester: ${CoursesData.normalizeSemester(_headerSubtitle.split(' • ').length > 1 ? _headerSubtitle.split(' • ')[1] : '')}", 
             textAlign: TextAlign.center,
             style: GoogleFonts.poppins(color: subHeadingColor.withValues(alpha: 0.5), fontSize: 10),
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
      physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
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
    final facultyDept = course['facultyDepartment'];
    final facultyId = course['facultyId'] ?? 'N/A';
    
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
                  branch: course['branch'] ?? user?['branch'] ?? 'Computer Engineering',
                  section: user?['section'],
                  year: user?['year'],
                  semester: int.tryParse((course['semester'] ?? user?['semester'])?.toString().replaceAll(RegExp(r'[^0-9]'), '') ?? '1') ?? 1,
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
                        _showFacultyDetails(context, facultyName, facultyDept, facultyId);
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


  Future<void> _sendChatRequest(String facultyId, String facultyName) async {
    if (_currentUser == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Session expired. Please log in again.')),
      );
      return;
    }
    
    final senderId = _currentUser!['login_id']?.toString() ?? _currentUser!['id']?.toString() ?? '';
    final senderName = _currentUser!['full_name']?.toString() ?? 'Student';
    final senderRole = _currentUser!['role']?.toString() ?? 'Student';

    if (senderId.isEmpty || facultyId.isEmpty || facultyId == 'N/A') {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Invalid user or faculty details.')),
      );
      return;
    }

    final body = {
      'sender_id': senderId,
      'receiver_id': facultyId,
      'optional_message': 'Connection request from $senderName ($senderRole)',
    };

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.chatRequests),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Request sent to $facultyName successfully!'),
            backgroundColor: const Color(0xFF34C759),
          ),
        );
      } else {
        final err = json.decode(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(err['message'] ?? 'Failed to send request.'),
            backgroundColor: const Color(0xFFFF4B4B),
          ),
        );
      }
    } catch (e) {
      debugPrint("Error sending chat request: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Network error. Please try again.'),
          backgroundColor: Color(0xFFFF4B4B),
        ),
      );
    }
  }

  void _showFacultyDetails(BuildContext context, String name, String? dept, String? facultyId) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;
    final dialogBg = isDark ? const Color(0xFF2C2C2E) : Colors.white;
    final textCol = isDark ? Colors.white : Colors.black87;

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: dialogBg,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: const Color(0xFF4B7FFB).withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.privacy_tip_outlined, color: Color(0xFF4B7FFB), size: 24),
            ),
            const SizedBox(width: 12),
            Text(
              "Faculty Profile",
              style: GoogleFonts.poppins(
                fontWeight: FontWeight.bold,
                color: textCol,
                fontSize: 20,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [Color(0xFF4B7FFB), Color(0xFFA569BD)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: const Color(0xFF4B7FFB).withValues(alpha: 0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ],
                ),
                child: const Icon(Icons.person, size: 36, color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
            _buildDetailRow(Icons.person_outline, "Name", name),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.business_outlined, "Department", dept ?? "N/A"),
            const SizedBox(height: 12),
            _buildDetailRow(Icons.badge_outlined, "Faculty ID", facultyId ?? "N/A"),
          ],
        ),
        actionsPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        actions: [
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: (facultyId == null || facultyId == 'N/A' || facultyId.isEmpty)
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          _sendChatRequest(facultyId, name);
                        },
                  icon: const Icon(Icons.send_rounded, size: 16),
                  label: Text("Request", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600)),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFF4B7FFB),
                    side: const BorderSide(color: Color(0xFF4B7FFB)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _currentUser == null
                      ? null
                      : () {
                          Navigator.pop(dialogContext);
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => ErpConnectScreen(userData: _currentUser!),
                            ),
                          );
                        },
                  icon: const Icon(Icons.chat_bubble_outline_rounded, size: 16, color: Colors.white),
                  label: Text("Message", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w600, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF4B7FFB),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Center(
            child: TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                "Close",
                style: GoogleFonts.poppins(
                  color: isDark ? Colors.white70 : Colors.grey[600],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
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
