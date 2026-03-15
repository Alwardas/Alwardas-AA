import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/providers/theme_provider.dart';
import '../../../core/api_constants.dart';
import '../../../widgets/skeleton_loader.dart';
import 'hod_syllabus_lesson_topics_screen.dart';

class HodSyllabusSubjectsScreen extends StatefulWidget {
  final String courseId;
  final String year;
  final String semester;
  final String section;
  final Map<String, dynamic> userData;

  const HodSyllabusSubjectsScreen({
    super.key,
    required this.courseId,
    required this.year,
    required this.semester,
    required this.section,
    required this.userData,
  });

  @override
  State<HodSyllabusSubjectsScreen> createState() => _HodSyllabusSubjectsScreenState();
}

class _HodSyllabusSubjectsScreenState extends State<HodSyllabusSubjectsScreen> {
  bool _isLoading = true;
  List<dynamic> _subjects = [];

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
  }

  Future<void> _fetchSubjects() async {
    final branch = widget.userData['branch'] ?? 'Computer Engineering';
    final url = Uri.parse(
      '${ApiConstants.baseUrl}/api/hod/syllabus/section-subjects-progress?branch=${Uri.encodeComponent(branch)}&year=${Uri.encodeComponent(widget.year)}&section=${Uri.encodeComponent(widget.section)}&courseId=${Uri.encodeComponent(widget.courseId)}&semester=${Uri.encodeComponent(widget.semester)}'
    );
    
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        setState(() {
          _subjects = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching subjects: $e");
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
        title: Text('${widget.semester} Subjects', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: bgColors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Column(
            children: [
               Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.orange),
                    const SizedBox(width: 5),
                    Text("${widget.year} - ${widget.section}", style: GoogleFonts.poppins(fontSize: 14, color: textColor.withValues(alpha: 0.7))),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _isLoading 
                  ? _buildSkeletonList(isDark)
                  : _subjects.isEmpty
                      ? Center(child: Text("No subjects found for this semester.", style: GoogleFonts.poppins(color: subTextColor)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _subjects.length,
                          itemBuilder: (context, index) {
                            final subject = _subjects[index];
                            return _buildSubjectCard(subject, isDark, textColor, subTextColor);
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectCard(dynamic subject, bool isDark, Color textColor, Color subTextColor) {
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final status = subject['status'] ?? 'On Track';
    final percentage = (subject['percentage'] as num).toInt();

    Color statusColor;
    switch (status) {
      case 'Lagging': statusColor = Colors.red; break;
      case 'Overfast': 
      case 'Over Fast': statusColor = Colors.orange; break;
      default: statusColor = Colors.green;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => HodSyllabusLessonTopicsScreen(
          subjectId: subject['subjectId'],
          subjectName: subject['subjectName'],
          year: widget.year,
          semester: widget.semester,
          section: widget.section,
          userData: widget.userData,
        )));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: Icon(Icons.book, color: statusColor, size: 24),
                ),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject['subjectName'],
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 18),
                      ),
                      Text(
                        "Code: ${subject['subjectId']}",
                        style: GoogleFonts.poppins(fontSize: 12, color: subTextColor),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    status,
                    style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Completion Progress", style: GoogleFonts.poppins(fontSize: 13, color: subTextColor)),
                Text("$percentage%", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: statusColor.withValues(alpha: 0.1),
              color: statusColor,
              borderRadius: BorderRadius.circular(10),
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonLoader(width: 48, height: 48, borderRadius: BorderRadius.circular(24)),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(width: 150, height: 18, borderRadius: BorderRadius.circular(4)),
                      const SizedBox(height: 8),
                      SkeletonLoader(width: 80, height: 12, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
                ),
                SkeletonLoader(width: 60, height: 20, borderRadius: BorderRadius.circular(10)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonLoader(width: 120, height: 13, borderRadius: BorderRadius.circular(4)),
                SkeletonLoader(width: 40, height: 13, borderRadius: BorderRadius.circular(4)),
              ],
            ),
            const SizedBox(height: 8),
            SkeletonLoader(width: double.infinity, height: 8, borderRadius: BorderRadius.circular(10)),
          ],
        ),
      ),
    );
  }
}

