import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/providers/theme_provider.dart';
import '../../../core/api_constants.dart';
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
  List<String> _sections = [];
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
        '${ApiConstants.baseUrl}/api/sections?branch=${Uri.encodeComponent(branch)}&year=${Uri.encodeComponent(widget.year)}'
      ));
      if (response.statusCode == 200) {
        final List<dynamic> fetched = json.decode(response.body);
        setState(() {
          _sections = fetched.map((e) => e.toString()).toList();
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
                    ? const Center(child: CircularProgressIndicator())
                    : _sections.isEmpty
                        ? Center(child: Text("No sections found.", style: GoogleFonts.poppins(color: subTextColor)))
                        : GridView.builder(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: 2,
                              childAspectRatio: 2.2,
                              crossAxisSpacing: 12,
                              mainAxisSpacing: 12,
                            ),
                            itemCount: _sections.length,
                            itemBuilder: (context, index) {
                              final sectionName = _sections[index];
                              return _buildSectionCard(sectionName, isDark, textColor);
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

  Widget _buildSectionCard(String sectionName, bool isDark, Color textColor) {
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
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 3))
          ]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: const Icon(Icons.class_, color: Colors.green, size: 18),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                sectionName,
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 13),
              ),
            ),
            Icon(Icons.arrow_forward_ios, size: 10, color: textColor.withValues(alpha: 0.3)),
          ],
        ),
      ),
    );
  }
}
