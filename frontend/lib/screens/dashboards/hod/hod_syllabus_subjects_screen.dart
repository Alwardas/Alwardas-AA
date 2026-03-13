import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/providers/theme_provider.dart';
import '../../../core/api_constants.dart';
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
      '${ApiConstants.baseUrl}/api/faculty/hod-semester-subjects?branch=${Uri.encodeComponent(branch)}&year=${Uri.encodeComponent(widget.year)}&semester=${Uri.encodeComponent(widget.semester)}&course_id=${Uri.encodeComponent(widget.courseId)}'
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
          child: _isLoading 
            ? const Center(child: CircularProgressIndicator())
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
      ),
    );
  }

  Widget _buildSubjectCard(dynamic subject, bool isDark, Color textColor, Color subTextColor) {
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => HodSyllabusLessonTopicsScreen(
          subjectId: subject['id'],
          subjectName: subject['subjectName'],
          year: widget.year,
          semester: widget.semester,
          section: widget.section,
          userData: widget.userData,
        )));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
          ]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.book, color: Colors.orange, size: 24),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "${subject['id']} - ${subject['subjectName']}",
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "Assign lesson plan schedule",
                    style: GoogleFonts.poppins(fontSize: 12, color: subTextColor),
                  ),
                ],
              ),
            ),
            Icon(Icons.calendar_month, color: Colors.orange.withValues(alpha: 0.7), size: 20),
          ],
        ),
      ),
    );
  }
}
