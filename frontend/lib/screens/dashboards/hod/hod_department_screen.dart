import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Persistence
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'hod_class_timetable_screen.dart';
import 'hod_year_sections_screen.dart';
import 'hod_faculty_screen.dart';
import 'hod_syllabus_management_screen.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/api_constants.dart';


class HodDepartmentScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const HodDepartmentScreen({super.key, required this.userData});

  @override
  _HodDepartmentScreenState createState() => _HodDepartmentScreenState();
}

class _HodDepartmentScreenState extends State<HodDepartmentScreen> {
  // Temporary data structure for demonstration
  // In a real app, this would come from a database/API
  List<Map<String, dynamic>> _years = [
    {
      'year': '1st Year',
      'sections': ['Section A'],
      'isExpanded': false,
    },
    {
      'year': '2nd Year',
      'sections': ['Section A'],
      'isExpanded': false,
    },
    {
      'year': '3rd Year',
      'sections': ['Section A'],
      'isExpanded': false,
    },
  ];

  void _addSection(int yearIndex) {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Add Section to ${_years[yearIndex]['year']}', style: GoogleFonts.poppins()),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Enter Section Name (e.g. Section C)"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (controller.text.trim().isNotEmpty) {
                setState(() {
                  _years[yearIndex]['sections'].add(controller.text.trim());
                });
                Navigator.pop(context);
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }


  void _navigateToTimetable(String year, String section) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HodClassTimetableScreen(
          branch: widget.userData['branch'] ?? 'Computer Engineering',
          year: year,
          section: section,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? AppTheme.darkBodyGradient : AppTheme.lightBodyGradient;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Our Department', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: false,
      ),
      body: SizedBox(
        height: MediaQuery.of(context).size.height,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: bgColors,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: EdgeInsets.only(
               top: MediaQuery.of(context).padding.top + kToolbarHeight + 10, 
               left: 20, 
               right: 20, 
               bottom: 100 // Padding for bottom navbar
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader('Department Overview', textColor),
                const SizedBox(height: 15),
                _buildOverviewCard(isDark, textColor, subTextColor),
                const SizedBox(height: 30),
                _buildSectionHeader('Department Management', textColor),
                const SizedBox(height: 15),
                _buildManagementCards(context, isDark, textColor, subTextColor),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }

  Widget _buildOverviewCard(bool isDark, Color textColor, Color subTextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.amber.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.userData['branch']?.toUpperCase() ?? 'DEPARTMENT',
            style: GoogleFonts.poppins(
              fontSize: 18, 
              fontWeight: FontWeight.w800, 
              color: Colors.amber[900],
              letterSpacing: 0.5
            ),
          ),
          const SizedBox(height: 8),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'Hod :- ',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.amber[800]),
                ),
                TextSpan(
                  text: widget.userData['full_name'] ?? 'Not Assigned',
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.brown[900]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildManagementCards(BuildContext context, bool isDark, Color textColor, Color subTextColor) {
    return Row(
      children: [
        Expanded(
          child: _buildManagementCard(
            context,
            isDark,
            'Staff',
            Icons.people_alt_outlined,
            Colors.orange,
            () => Navigator.push(context, MaterialPageRoute(builder: (_) => HodFacultyScreen(branch: widget.userData['branch'] ?? 'Computer Engineering'))),
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildManagementCard(
            context,
            isDark,
            'Students',
            Icons.school_outlined,
            Colors.blue,
            () => _showStudentYearsModal(context),
          ),
        ),
      ],
    );
  }


  Widget _buildManagementCard(BuildContext context, bool isDark, String title, IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 120,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))
          ],
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 30, color: color),
            ),
            const SizedBox(height: 10),
            Text(title, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }

  void _showStudentYearsModal(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => HodStudentManagementScreen(
      userData: widget.userData,
      years: _years, // Pass state
      onUpdateYears: (updatedYears) => setState(() => _years = updatedYears),
    )));
  }

  void _showSyllabusYearsModal(BuildContext context) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => HodSyllabusYearsScreen(
      userData: widget.userData,
      years: _years,
    )));
  }

}

class HodStudentManagementScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final List<Map<String, dynamic>> years;
  final Function(List<Map<String, dynamic>>) onUpdateYears;

  const HodStudentManagementScreen({super.key, required this.userData, required this.years, required this.onUpdateYears});
  
  @override
  _HodStudentManagementScreenState createState() => _HodStudentManagementScreenState();
}


class _HodStudentManagementScreenState extends State<HodStudentManagementScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllSectionCounts();
  }

  Future<void> _loadAllSectionCounts() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    final branch = widget.userData['branch'] ?? 'Computer Engineering';

    for (var yearData in widget.years) {
      final yearName = yearData['year'];
      
      try {
        final url = Uri.parse('${ApiConstants.baseUrl}/api/sections?branch=${Uri.encodeComponent(branch)}&year=${Uri.encodeComponent(yearName)}');
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          final List<dynamic> fetched = json.decode(response.body);
          if (fetched.isNotEmpty) {
            yearData['sections'] = fetched.map((e) => e.toString()).toList();
            prefs.setStringList('sections_${branch}_$yearName', yearData['sections']);
            continue; 
          }
        }
      } catch (e) {
        debugPrint("Error fetching counts for $yearName: $e");
      }

      final key = 'sections_${branch}_$yearName';
      final List<String>? stored = prefs.getStringList(key);
      if (stored != null) {
        yearData['sections'] = stored;
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? AppTheme.darkBodyGradient : AppTheme.lightBodyGradient;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Student Management', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
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
            : Padding(
                padding: const EdgeInsets.all(20),
                child: ListView.builder(
                  itemCount: widget.years.length,
                  itemBuilder: (context, index) {
                final year = widget.years[index];
                return GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => HodYearSectionsScreen(
                        yearData: year,
                        branch: widget.userData['branch'] ?? 'Computer Engineering',
                        onUpdateSections: (newSections) {
                          setState(() {
                            year['sections'] = newSections;
                          });
                          widget.onUpdateYears(widget.years);
                        },
                      )),
                    );
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                      boxShadow: [
                         BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
                      ]
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.school, color: Colors.blueAccent, size: 24),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                year['year'],
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 18),
                              ),
                              Text(
                                '${year['sections'].length} Sections',
                                style: GoogleFonts.poppins(fontSize: 12, color: subTextColor),
                              ),
                            ],
                          ),
                        ),
                        Icon(Icons.arrow_forward_ios, size: 16, color: subTextColor),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

class HodSyllabusYearsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final List<Map<String, dynamic>> years;

  const HodSyllabusYearsScreen({super.key, required this.userData, required this.years});
  
  @override
  _HodSyllabusYearsScreenState createState() => _HodSyllabusYearsScreenState();
}


class _HodSyllabusYearsScreenState extends State<HodSyllabusYearsScreen> {
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadAllSectionCounts();
  }

  Future<void> _loadAllSectionCounts() async {
    setState(() => _isLoading = true);
    
    final prefs = await SharedPreferences.getInstance();
    final branch = widget.userData['branch'] ?? 'Computer Engineering';

    for (var yearData in widget.years) {
      final yearName = yearData['year'];
      
      try {
        final url = Uri.parse('${ApiConstants.baseUrl}/api/sections?branch=${Uri.encodeComponent(branch)}&year=${Uri.encodeComponent(yearName)}');
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          final List<dynamic> fetched = json.decode(response.body);
          if (fetched.isNotEmpty) {
            yearData['sections'] = fetched.map((e) => e.toString()).toList();
            prefs.setStringList('sections_${branch}_$yearName', yearData['sections']);
            continue; 
          }
        }
      } catch (e) {
        debugPrint("Error fetching counts for $yearName: $e");
      }

      final key = 'sections_${branch}_$yearName';
      final List<String>? stored = prefs.getStringList(key);
      if (stored != null) {
        yearData['sections'] = stored;
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? AppTheme.darkBodyGradient : AppTheme.lightBodyGradient;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

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
            ? const Center(child: CircularProgressIndicator())
            : Padding(
                padding: const EdgeInsets.all(20),
                child: ListView.builder(
                  itemCount: widget.years.length,
                  itemBuilder: (context, index) {
                final year = widget.years[index];
                return GestureDetector(
                  onTap: () {
                    _openSyllabusSectionsScreen(context, year);
                  },
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 15),
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                      boxShadow: [
                         BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
                      ]
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(color: Colors.purple.withValues(alpha: 0.1), shape: BoxShape.circle),
                          child: const Icon(Icons.menu_book, color: Colors.purple, size: 24),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                year['year'],
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 18),
                              ),
                              Text(
                                '${year['sections'].length} Sections',
                                style: GoogleFonts.poppins(fontSize: 12, color: subTextColor),
                              ),
                            ],
                          ),
                        ),
                        SizedBox(
                          width: 45,
                          height: 45,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              CircularProgressIndicator(
                                value: 0.0,
                                strokeWidth: 4,
                                backgroundColor: Colors.purple.withValues(alpha: 0.1),
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                              ),
                              Text('0%', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  void _openSyllabusSectionsScreen(BuildContext context, Map<String, dynamic> yearData) {
    Navigator.push(context, MaterialPageRoute(builder: (_) => HodSyllabusSectionsScreen(
      yearData: yearData,
      branch: widget.userData['branch'] ?? 'Computer Engineering',
    )));
  }
}

class HodSyllabusSectionsScreen extends StatelessWidget {
  final Map<String, dynamic> yearData;
  final String branch;

  const HodSyllabusSectionsScreen({super.key, required this.yearData, required this.branch});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? AppTheme.darkBodyGradient : AppTheme.lightBodyGradient;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    final List<String> sections = List<String>.from(yearData['sections'] ?? []);
    
    // Sort sections alphabetically
    sections.sort();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('${yearData['year']} Sections', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
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
              Expanded(
                child: sections.isEmpty
                    ? Center(
                        child: Text(
                          'No sections found for ${yearData['year']}.',
                          style: GoogleFonts.poppins(color: subTextColor),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        itemCount: sections.length,
                        itemBuilder: (context, index) {
                          final sectionName = sections[index];
                          return GestureDetector(
                            onTap: () {
                               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Section syllabus coming soon!')));
                            },
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                                boxShadow: [
                                   BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
                                ]
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: Colors.purple.withValues(alpha: 0.1),
                                      shape: BoxShape.circle,
                                    ),
                                    child: const Icon(Icons.class_, color: Colors.purple, size: 20),
                                  ),
                                  const SizedBox(width: 16),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          sectionName,
                                          style: GoogleFonts.poppins(
                                            fontWeight: FontWeight.w600,
                                            color: textColor,
                                            fontSize: 16,
                                          ),
                                        ),
                                        Text(
                                          'View Syllabus progress',
                                          style: GoogleFonts.poppins(
                                            fontSize: 12,
                                            color: subTextColor,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  SizedBox(
                                    width: 45,
                                    height: 45,
                                    child: Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        CircularProgressIndicator(
                                          value: 0.0,
                                          strokeWidth: 4,
                                          backgroundColor: Colors.purple.withValues(alpha: 0.1),
                                          valueColor: const AlwaysStoppedAnimation<Color>(Colors.purple),
                                        ),
                                        Text('0%', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
