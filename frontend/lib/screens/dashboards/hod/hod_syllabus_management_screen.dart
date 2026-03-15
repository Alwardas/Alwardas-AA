import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/providers/theme_provider.dart';
import '../../../core/api_constants.dart';
import '../../../theme/theme_constants.dart';
import '../../../widgets/skeleton_loader.dart';
import 'hod_syllabus_year_selection_screen.dart';

class HodSyllabusManagementScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const HodSyllabusManagementScreen({super.key, required this.userData});

  @override
  State<HodSyllabusManagementScreen> createState() => _HodSyllabusManagementScreenState();
}

class _HodSyllabusManagementScreenState extends State<HodSyllabusManagementScreen> {
  bool _isLoading = true;
  List<dynamic> _courses = [];
  Map<String, dynamic>? _branchProgress;

  @override
  void initState() {
    super.initState();
    _fetchCourses();
    _fetchBranchProgress();
  }

  Future<void> _fetchBranchProgress() async {
    try {
      final String branch = widget.userData['branch'] ?? 'Computer Engineering';
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/hod/branch-progress?branch=${Uri.encodeComponent(branch)}&courseId=C-23'));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _branchProgress = json.decode(response.body);
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching branch progress: $e");
    }
  }

  Future<void> _fetchCourses() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/faculty/hod-courses'));
      if (response.statusCode == 200) {
        setState(() {
          _courses = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching courses: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final bgColors = isDark 
        ? [const Color(0xFF1a1a2e), const Color(0xFF16213e)] 
        : [const Color(0xFFF8F9FA), Colors.white];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Syllabus Management', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: bgColors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: _isLoading 
            ? _buildSkeletonList(isDark)
            : _courses.isEmpty
                ? Center(child: Text("No courses found.", style: GoogleFonts.poppins(color: subTextColor)))
                : Column(
                    children: [
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          children: [
                            const SizedBox(height: 10),
                            if (_branchProgress != null)
                              _buildBranchProgressCard(_branchProgress!, isDark),
                            
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20.0),
                              child: Text(
                                "Select Course to Begin",
                                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
                              ),
                            ),
                            ..._courses.map((course) => _buildCourseCard(course, isDark)),
                          ],
                        ),
                      ),
                    ],
                  ),
        ),
      ),
    );
  }

  Widget _buildBranchProgressCard(Map<String, dynamic> data, bool isDark) {
    final int overall = data['overallPercentage'] ?? 0;
    final List<dynamic> years = data['years'] ?? [];
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final accentColor = _getAccentColor(overall / 100.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
        ],
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Overall Branch Progress", 
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(overall >= 75 ? "On Track" : "In Progress", 
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor)
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$overall% Completed", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
              Icon(Icons.auto_graph_rounded, color: accentColor, size: 24),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(5)),
              ),
              FractionallySizedBox(
                widthFactor: (overall / 100.0).clamp(0.0, 1.0),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accentColor.withOpacity(0.7), accentColor]),
                    borderRadius: BorderRadius.circular(5),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: years.map((y) => _buildYearMiniProgress(y, textColor)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildYearMiniProgress(dynamic yearData, Color textColor) {
    final String year = yearData['year']?.toString().split(' ')[0] ?? '';
    final int percentage = yearData['percentage'] ?? 0;
    final color = _getAccentColor(percentage / 100.0);

    return Column(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(shape: BoxShape.circle, border: Border.all(color: color.withOpacity(0.2), width: 2)),
          child: Center(
            child: Text("$percentage%", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: textColor)),
          ),
        ),
        const SizedBox(height: 6),
        Text("$year Yr", style: GoogleFonts.poppins(fontSize: 10, color: textColor.withOpacity(0.6))),
      ],
    );
  }

  Color _getAccentColor(double progress) {
    if (progress >= 0.8) return const Color(0xFF10B981);
    if (progress >= 0.5) return const Color(0xFF6366F1);
    if (progress >= 0.3) return const Color(0xFFF59E0B);
    return const Color(0xFFEF4444);
  }

  Widget _buildCourseCard(dynamic course, bool isDark) {
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => HodSyllabusYearSelectionScreen(
          courseId: course['courseId'],
          courseName: course['courseName'],
          userData: widget.userData,
        )));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: Colors.purple.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))
          ]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.school, color: Colors.purple, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(course['courseId'], style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.purple)),
                  Text(course['courseName'], style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 16, color: textColor.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.purple.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            SkeletonLoader(width: 52, height: 52, borderRadius: BorderRadius.circular(26)),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 60, height: 14, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(height: 8),
                  SkeletonLoader(width: double.infinity, height: 20, borderRadius: BorderRadius.circular(4)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
