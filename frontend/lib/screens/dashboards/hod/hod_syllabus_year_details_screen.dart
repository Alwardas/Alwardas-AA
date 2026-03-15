import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/providers/theme_provider.dart';
import '../../../core/api_constants.dart';
import '../../../widgets/skeleton_loader.dart';
import 'hod_syllabus_subjects_screen.dart';

class HodSyllabusYearDetailsScreen extends StatefulWidget {
  final String courseId;
  final String courseName;
  final String year;
  final Map<String, dynamic> userData;

  const HodSyllabusYearDetailsScreen({
    super.key,
    required this.courseId,
    required this.courseName,
    required this.year,
    required this.userData,
  });

  @override
  State<HodSyllabusYearDetailsScreen> createState() => _HodSyllabusYearDetailsScreenState();
}

class _HodSyllabusYearDetailsScreenState extends State<HodSyllabusYearDetailsScreen> {
  bool _loadingSections = true;
  List<Map<String, dynamic>> _sections = [];
  String? _selectedSemester;

  @override
  void initState() {
    super.initState();
    _fetchSections();
    // Default semester
    final sems = _getSemestersForYear(widget.year);
    if (sems.isNotEmpty) {
      _selectedSemester = sems.first;
    }
  }

  List<String> _getSemestersForYear(String year) {
    switch (year) {
      case '1st Year': return ['Semester 1'];
      case '2nd Year': return ['Semester 3', 'Semester 4'];
      case '3rd Year': return ['Semester 5', 'Semester 6'];
      default: return [];
    }
  }

  Future<void> _fetchSections() async {
    final branch = widget.userData['branch'] ?? 'Computer Engineering';
    try {
      final response = await http.get(Uri.parse(
        '${ApiConstants.baseUrl}/api/hod/syllabus/year-sections-progress?branch=${Uri.encodeComponent(branch)}&year=${Uri.encodeComponent(widget.year)}&courseId=${Uri.encodeComponent(widget.courseId)}'
      ));
      if (response.statusCode == 200) {
        final List<dynamic> fetched = json.decode(response.body);
        setState(() {
          _sections = fetched.map((e) => e as Map<String, dynamic>).toList();
          _loadingSections = false;
        });
      } else {
        setState(() => _loadingSections = false);
      }
    } catch (e) {
      debugPrint("Error fetching sections: $e");
      if (mounted) setState(() => _loadingSections = false);
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

    final semesters = _getSemestersForYear(widget.year);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('${widget.year} Details', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: bgColors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Select Semester', textColor),
                const SizedBox(height: 15),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: semesters.map((sem) {
                      final isSelected = _selectedSemester == sem;
                      return GestureDetector(
                        onTap: () => setState(() => _selectedSemester = sem),
                        child: Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? Colors.orange : (isDark ? Colors.white12 : Colors.white),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: isSelected ? Colors.orange : Colors.grey.withValues(alpha: 0.3)),
                            boxShadow: isSelected ? [BoxShadow(color: Colors.orange.withValues(alpha: 0.3), blurRadius: 10)] : null,
                          ),
                          child: Text(
                            sem,
                            style: GoogleFonts.poppins(
                              fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                              color: isSelected ? Colors.white : textColor,
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 30),
                _buildSectionHeader('Select Section', textColor),
                const SizedBox(height: 15),
                _loadingSections 
                    ? _buildSkeletonGrid(isDark)
                    : _sections.isEmpty
                        ? Center(child: Text("No sections found.", style: GoogleFonts.poppins(color: subTextColor)))
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 1,
                              childAspectRatio: 4,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: _sections.length,
                            itemBuilder: (context, index) {
                              final section = _sections[index];
                              return _buildSectionCard(section, isDark, textColor);
                            },
                          ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor));
  }

  Widget _buildSectionCard(Map<String, dynamic> section, bool isDark, Color textColor) {
    final sectionName = section['sectionName'];
    final percentage = (section['percentage'] as num).toInt();
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;

    return GestureDetector(
      onTap: () {
        if (_selectedSemester == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a semester first.")));
          return;
        }
        Navigator.push(context, MaterialPageRoute(builder: (_) => HodSyllabusSubjectsScreen(
          courseId: widget.courseId,
          year: widget.year,
          semester: _selectedSemester!,
          section: sectionName,
          userData: widget.userData,
        )));
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 3))
          ]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.class_, color: Colors.green, size: 24),
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    sectionName,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 16),
                  ),
                   Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: percentage / 100,
                          backgroundColor: Colors.green.withValues(alpha: 0.1),
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(10),
                          minHeight: 4,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text("$percentage%", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.arrow_forward_ios, size: 14, color: textColor.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonGrid(bool isDark) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 1,
        childAspectRatio: 4,
        mainAxisSpacing: 12,
      ),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.green.withValues(alpha: 0.1)),
        ),
        child: Row(
          children: [
            SkeletonLoader(width: 44, height: 44, borderRadius: BorderRadius.circular(22)),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SkeletonLoader(width: 80, height: 16, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(height: 10),
                  SkeletonLoader(width: double.infinity, height: 4, borderRadius: BorderRadius.circular(2)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

