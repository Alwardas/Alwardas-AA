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
import 'hod_student_profile_screen.dart';


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
    {
      'year': 'Graduated',
      'sections': [],
      'isExpanded': false,
    }
  ];

  @override
  void initState() {
    super.initState();
    // Dynamically calculate batches
    final now = DateTime.now();
    final startYear = now.month >= 6 ? now.year : now.year - 1;
    for (var year in _years) {
      if (year['year'] == '1st Year') {
        year['batch'] = '$startYear-${startYear + 3}';
      } else if (year['year'] == '2nd Year') {
        year['batch'] = '${startYear - 1}-${startYear + 2}';
      } else if (year['year'] == '3rd Year') {
        year['batch'] = '${startYear - 2}-${startYear + 1}';
      }
    }
  }

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

  void _promoteYear() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Promote Academic Year?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text("This will move 1st Year to 2nd Year, 2nd Year to 3rd Year, and mark 3rd Year as Graduated.\n\nAre you sure you want to proceed?", style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.purpleAccent),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Promote", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/admin/promote');
      final response = await http.post(url);
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Promotion successful!")));
          // Refresh state if needed
          setState((){});
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to promote students.")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
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
        title: Text('Our Department', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Promote Academic Year',
            icon: Icon(Icons.upgrade, color: Colors.purple.shade400),
            onPressed: _promoteYear,
          ),
        ],
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
          final responseData = json.decode(response.body);
          if (responseData['success'] == true) {
            final List<dynamic> fetched = responseData['data'] ?? [];
            yearData['sections'] = fetched.map((e) => e.toString()).toList();
            prefs.setStringList('sections_${branch}_$yearName', yearData['sections']);
            continue; // Successfully fetched from server, move to next year
          }
        }
      } catch (e) {
        debugPrint("Error fetching counts for $yearName: $e");
      }

      // Fallback only if the server request failed or errored out
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

  Future<void> _promoteStudents() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Promote Academic Year?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text("This will move 1st Year to 2nd Year, 2nd Year to 3rd Year, and mark 3rd Year as Graduated.\n\nAre you sure you want to proceed?", style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Promote", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('http://10.0.2.2:8000/api/admin/promote');
      // For real app we should use ApiConstants.baseUrl but we'll import it or hardcode for now
      final response = await http.post(url);
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Promotion successful!")));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to promote.")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _promoteStudents,
        backgroundColor: Colors.blueAccent,
        icon: const Icon(Icons.upgrade, color: Colors.white),
        label: Text("Promote Year", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
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
                    if (year['year'] == 'Graduated') {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => HodGraduatedStudentsScreen(
                          userData: widget.userData,
                        )),
                      );
                    } else {
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
                    }
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
                                year['year'] == 'Graduated' ? 'Graduated' : '${year['year']} (${year['batch']})',
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 18),
                              ),
                              if (year['year'] != 'Graduated')
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
          final responseData = json.decode(response.body);
          final List<dynamic> fetched = responseData['data'] ?? [];
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

  Future<void> _promoteStudents() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Promote Academic Year?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text("This will move 1st Year to 2nd Year, 2nd Year to 3rd Year, and mark 3rd Year as Graduated.\n\nAre you sure you want to proceed?", style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
            onPressed: () => Navigator.pop(context, true), 
            child: const Text("Promote", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('http://10.0.2.2:8000/api/admin/promote');
      // For real app we should use ApiConstants.baseUrl but we'll import it or hardcode for now
      final response = await http.post(url);
      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Promotion successful!")));
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to promote.")));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
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

// Scratch file to hold HodGraduatedStudentsScreen
class HodGraduatedStudentsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const HodGraduatedStudentsScreen({super.key, required this.userData});

  @override
  _HodGraduatedStudentsScreenState createState() => _HodGraduatedStudentsScreenState();
}

class _HodGraduatedStudentsScreenState extends State<HodGraduatedStudentsScreen> {
  bool _isLoading = true;
  List<dynamic> _graduatedBatches = [];
  List<dynamic> _filteredBatches = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchGraduatedBatches();
    _searchController.addListener(_filterBatches);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchGraduatedBatches() async {
    setState(() => _isLoading = true);
    try {
      final branch = widget.userData['branch'] ?? 'Computer Engineering';
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/hod/graduated-batches')
          .replace(queryParameters: {'branch': branch});
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> data = responseData['data'] ?? [];
        if (mounted) {
          setState(() {
            _graduatedBatches = data;
            _filteredBatches = data;
            _isLoading = false;
          });
        }
      } else {
        debugPrint("API Error: ${response.statusCode}");
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint("Error loading graduated batches: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterBatches() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredBatches = _graduatedBatches;
      } else {
        _filteredBatches = _graduatedBatches.where((b) => b['batch'].toString().toLowerCase().contains(query)).toList();
      }
    });
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
        title: Text('Graduated Batches', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
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
                padding: const EdgeInsets.all(20),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Search batch year (e.g. 2025-2028)',
                    hintStyle: TextStyle(color: subTextColor),
                    prefixIcon: Icon(Icons.search, color: subTextColor),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredBatches.isEmpty
                      ? Center(child: Text("No batches found.", style: TextStyle(color: subTextColor)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _filteredBatches.length,
                          itemBuilder: (context, index) {
                            final batch = _filteredBatches[index];
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => HodGraduatedSectionsScreen(
                                      userData: widget.userData,
                                      batch: batch['batch'].toString(),
                                    ),
                                  ),
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 15),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
                                      child: const Icon(Icons.check_circle, color: Colors.green, size: 24),
                                    ),
                                    const SizedBox(width: 20),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Batch ${batch['batch']}',
                                            style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 18),
                                          ),
                                          Text(
                                            '${batch['count']} Students',
                                            style: GoogleFonts.poppins(fontSize: 12, color: subTextColor),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(Icons.chevron_right, color: subTextColor),
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

class HodGraduatedSectionsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String batch;
  const HodGraduatedSectionsScreen({super.key, required this.userData, required this.batch});

  @override
  _HodGraduatedSectionsScreenState createState() => _HodGraduatedSectionsScreenState();
}

class _HodGraduatedSectionsScreenState extends State<HodGraduatedSectionsScreen> {
  bool _isLoading = true;
  List<dynamic> _sections = [];

  @override
  void initState() {
    super.initState();
    _fetchSections();
  }

  Future<void> _fetchSections() async {
    setState(() => _isLoading = true);
    try {
      final branch = widget.userData['branch'] ?? 'Computer Engineering';
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/hod/graduated-sections')
          .replace(queryParameters: {
            'branch': branch,
            'batch': widget.batch,
          });
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> data = responseData['data'] ?? [];
        if (mounted) {
          setState(() {
            _sections = data;
            _isLoading = false;
          });
        }
      } else {
        debugPrint("API Error: ${response.statusCode}");
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint("Error loading graduated sections: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Graduated Sections', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
            Text('Batch ${widget.batch}', style: GoogleFonts.poppins(fontSize: 12, color: subTextColor)),
          ],
        ),
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
              : _sections.isEmpty
                  ? Center(child: Text("No sections found for this batch.", style: TextStyle(color: subTextColor)))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                      itemCount: _sections.length,
                      itemBuilder: (context, index) {
                        final sec = _sections[index];
                        final sectionName = sec['section'] ?? '';
                        final studentCount = sec['count'] ?? 0;
                        return GestureDetector(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => HodGraduatedStudentListScreen(
                                  userData: widget.userData,
                                  batch: widget.batch,
                                  section: sectionName,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            margin: const EdgeInsets.only(bottom: 15),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                              borderRadius: BorderRadius.circular(15),
                              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(10),
                                  decoration: BoxDecoration(
                                    color: Colors.blueAccent.withValues(alpha: 0.1),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(Icons.class_outlined, color: Colors.blueAccent),
                                ),
                                const SizedBox(width: 15),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Section $sectionName',
                                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
                                      ),
                                      Text(
                                        '$studentCount Students',
                                        style: GoogleFonts.poppins(fontSize: 12, color: subTextColor),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(Icons.chevron_right, color: subTextColor),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ),
    );
  }
}

class HodGraduatedStudentListScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String batch;
  final String section;

  const HodGraduatedStudentListScreen({
    super.key,
    required this.userData,
    required this.batch,
    required this.section,
  });

  @override
  _HodGraduatedStudentListScreenState createState() => _HodGraduatedStudentListScreenState();
}

class _HodGraduatedStudentListScreenState extends State<HodGraduatedStudentListScreen> {
  bool _isLoading = true;
  List<dynamic> _students = [];
  List<dynamic> _filteredStudents = [];
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStudents();
    _searchController.addListener(_filterStudentsList);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchStudents() async {
    setState(() => _isLoading = true);
    try {
      final branch = widget.userData['branch'] ?? 'Computer Engineering';
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/hod/graduated-students')
          .replace(queryParameters: {
            'branch': branch,
            'batch': widget.batch,
            'section': widget.section,
          });
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final List<dynamic> data = responseData['data'] ?? [];
        if (mounted) {
          setState(() {
            _students = data;
            _filteredStudents = data;
            _isLoading = false;
          });
        }
      } else {
        debugPrint("API Error: ${response.statusCode}");
        if (mounted) {
          setState(() => _isLoading = false);
        }
      }
    } catch (e) {
      debugPrint("Error loading graduated students: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _filterStudentsList() {
    final query = _searchController.text.toLowerCase();
    setState(() {
      if (query.isEmpty) {
        _filteredStudents = _students;
      } else {
        _filteredStudents = _students.where((s) {
          final name = (s['fullName'] ?? '').toString().toLowerCase();
          final id = (s['studentId'] ?? '').toString().toLowerCase();
          return name.contains(query) || id.contains(query);
        }).toList();
      }
    });
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
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Graduated Students', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
            Text('Batch ${widget.batch} - Section ${widget.section}', style: GoogleFonts.poppins(fontSize: 12, color: subTextColor)),
          ],
        ),
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
                padding: const EdgeInsets.all(20),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: textColor),
                  decoration: InputDecoration(
                    hintText: 'Search by name or student ID...',
                    hintStyle: TextStyle(color: subTextColor),
                    prefixIcon: Icon(Icons.search, color: subTextColor),
                    filled: true,
                    fillColor: isDark ? Colors.white.withValues(alpha: 0.1) : Colors.grey[200],
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                  ),
                ),
              ),
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _filteredStudents.isEmpty
                        ? Center(child: Text("No students found.", style: TextStyle(color: subTextColor)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: _filteredStudents.length,
                            itemBuilder: (context, index) {
                              final student = _filteredStudents[index];
                              final String name = student['fullName'] ?? 'Unknown';
                              final String studentId = student['studentId'] ?? 'Unknown';
                              final String dbId = student['id'] ?? studentId;
                              
                              return GestureDetector(
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => HodStudentProfileScreen(
                                        userId: dbId,
                                        studentId: studentId,
                                        studentName: name,
                                      ),
                                    ),
                                  );
                                },
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 15),
                                  padding: const EdgeInsets.all(15),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
                                    borderRadius: BorderRadius.circular(15),
                                    border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
                                    boxShadow: [
                                      BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))
                                    ],
                                  ),
                                  child: Row(
                                    children: [
                                      CircleAvatar(
                                        radius: 25,
                                        backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                                        child: Text(
                                          name.isNotEmpty ? name[0].toUpperCase() : 'S',
                                          style: GoogleFonts.poppins(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 18),
                                        ),
                                      ),
                                      const SizedBox(width: 15),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              name,
                                              style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                                            ),
                                            Text(
                                              'ID: $studentId',
                                              style: GoogleFonts.poppins(fontSize: 12, color: subTextColor),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Icon(Icons.chevron_right, color: subTextColor),
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
