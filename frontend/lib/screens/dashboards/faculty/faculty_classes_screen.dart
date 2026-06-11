import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../../../core/api_config.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/courses_data.dart';
import 'faculty_lesson_plan_screen.dart';
import 'faculty_add_subject_screen.dart';

class FacultyClassesScreen extends StatefulWidget {
  const FacultyClassesScreen({super.key});

  @override
  _FacultyClassesScreenState createState() => _FacultyClassesScreenState();
}

class _FacultyClassesScreenState extends State<FacultyClassesScreen> {
  List<dynamic> _mySubjects = [];
  bool _loading = true;
  bool _isSelectMode = false;
  final Set<String> _selectedForDelete = {};
  
  List<dynamic> _allCourses = [];
  String _facultyName = '';

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final courses = await CoursesData.getAllCourses();
    if (mounted) {
      setState(() {
        _allCourses = courses;
      });
    }
    _fetchMySubjects();
  }

  Future<void> _fetchMySubjects() async {
    final user = await AuthService.getUserSession();
    if (user == null) return;

    if (mounted) {
      setState(() {
        _facultyName = user['full_name'] ?? 'Faculty';
      });
    }

    try {
      final res = await ApiConfig.get('${ApiConstants.baseUrl}/api/faculty/subjects?userId=${user['id']}');
      if (res.success) {
        if (mounted) {
          setState(() {
            _mySubjects = res.data ?? [];
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint("Error fetching subjects: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleDeleteSelection(String id) {
    setState(() {
      if (_selectedForDelete.contains(id)) {
        _selectedForDelete.remove(id);
      } else {
        _selectedForDelete.add(id);
      }
    });
  }

  Future<void> _confirmDelete() async {
    if (_selectedForDelete.isEmpty) {
      setState(() => _isSelectMode = false);
      return;
    }

    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Subjects"),
        content: Text("Are you sure you want to remove ${_selectedForDelete.length} subject(s)?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Remove", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    final user = await AuthService.getUserSession();
    if (user == null) return;

    try {
      for (String id in _selectedForDelete) {
        final item = _mySubjects.firstWhere((element) => element['id'] == id, orElse: () => null);
        if (item != null) {
           await ApiConfig.delete(
             '${ApiConstants.baseUrl}/api/faculty/subjects',
             body: {
               'userId': user['id'], 
               'subjectId': item['subjectId'] ?? item['id'],
               'section': item['section']
             }
           );
        }
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Subjects removed successfully.")));
      _fetchMySubjects();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network error.")));
    } finally {
      setState(() {
        _isSelectMode = false;
        _selectedForDelete.clear();
      });
    }
  }

  void _openAddModal() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FacultyAddSubjectScreen(
          allCourses: _allCourses,
          existingSubjects: _mySubjects,
        ),
      ),
    );
    
    if (result == true) {
      _fetchMySubjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? ThemeColors.darkBackground : ThemeColors.lightBackground;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_isSelectMode ? "Selected (${_selectedForDelete.length})" : "My Courses", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        leading: _isSelectMode
            ? TextButton(onPressed: () => setState(() => _isSelectMode = false), child: Text("Cancel", style: TextStyle(color: textColor, fontSize: 13)))
            : null,
        actions: [
          if (!_isSelectMode) ...[
            IconButton(icon: Icon(Icons.add_circle, color: tint, size: 30), onPressed: _openAddModal),
            if (_mySubjects.isNotEmpty)
              IconButton(icon: Icon(Icons.delete_outline, color: textColor), onPressed: () => setState(() => _isSelectMode = true)),
          ] else
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _confirmDelete),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _mySubjects.isEmpty
                  ? _buildEmptyState(subTextColor, tint)
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _mySubjects.length,
                      itemBuilder: (ctx, index) {
                        final item = _mySubjects[index];
                        return _buildCourseCard(item, cardColor, textColor, subTextColor, tint, iconBg);
                      },
                    ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color subTextColor, Color tint) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(onTap: _openAddModal, child: Icon(Icons.add_circle, size: 80, color: tint)),
          const SizedBox(height: 20),
          Text("No courses added yet.", style: GoogleFonts.poppins(fontSize: 18, color: subTextColor)),
          Text("Tap the icon to add subjects.", style: GoogleFonts.poppins(fontSize: 14, color: subTextColor)),
        ],
      ),
    );
  }

  int _parseSemester(dynamic sem) {
    if (sem == null) return 1;
    if (sem is num) return sem.toInt();
    final s = sem.toString().toLowerCase();
    if (s.contains('1')) return 1;
    if (s.contains('2')) return 2;
    if (s.contains('3')) return 3;
    if (s.contains('4')) return 4;
    if (s.contains('5')) return 5;
    if (s.contains('6')) return 6;
    return 1;
  }

  String _semesterToYear(int sem) {
    if (sem <= 2) return "1st Year";
    if (sem <= 4) return "2nd Year";
    return "3rd Year";
  }

  Widget _buildCourseCard(dynamic item, Color cardColor, Color textColor, Color subTextColor, Color tint, Color iconBg) {
    final isSelected = _selectedForDelete.contains(item['id']);
    final percentage = item['completionPercentage'] ?? item['percentage'] ?? 0;
    final statusTag = item['progressStatus'] ?? item['status'] ?? 'NORMAL';
    final displayId = item['subjectId'] ?? item['id'];
    final subjectName = item['name'] ?? 'Untitled Subject';
    final displaySemester = item['semester'] ?? item['year'] ?? '';

    Color statusColor = Colors.green;
    if (statusTag.toString().toUpperCase() == 'LAGGING') statusColor = Colors.red;
    if (statusTag.toString().toUpperCase() == 'OVERFAST') statusColor = Colors.orange;
    
    final isPending = item['status']?.toString().toUpperCase() == 'PENDING';

    return GestureDetector(
      onTap: () {
        if (_isSelectMode) {
          _toggleDeleteSelection(item['id']);
        } else {
          if (isPending) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("This subject is pending approval.")));
             return;
          }
          final semInt = _parseSemester(item['semester']);
          final yearStr = item['year']?.toString() ?? _semesterToYear(semInt);
          Navigator.push(context, MaterialPageRoute(builder: (_) => FacultyLessonPlanScreen(
            subjectId: displayId, 
            subjectName: subjectName,
            facultyName: _facultyName.isNotEmpty ? _facultyName : 'You',
            section: item['section'] ?? 'Section A',
            branch: item['branch'] ?? 'Computer Engineering',
            year: yearStr,
            semester: semInt,
          )));
        }
      },
      child: Opacity(
        opacity: isPending ? 0.6 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(16),
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: isSelected ? Colors.red : iconBg, width: isSelected ? 2 : 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(color: tint.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        displayId, 
                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: tint),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (_isSelectMode)
                    Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank, color: isSelected ? Colors.red : subTextColor)
                  else
                    Row(
                      children: [
                        Text(isPending ? "Pending" : statusTag, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: isPending ? Colors.orange : statusColor)),
                        const SizedBox(width: 10),
                        if (!isPending)
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(width: 35, height: 35, child: CircularProgressIndicator(value: percentage / 100, strokeWidth: 3, backgroundColor: statusColor.withValues(alpha: 0.2), valueColor: AlwaysStoppedAnimation(statusColor))),
                              Text("$percentage%", style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor)),
                            ],
                          ),
                      ],
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                "${displayId} - ${subjectName}", 
                style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.w600, color: textColor),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildTag(
                      "${item['branch']} · ${displaySemester} · ${item['section']?.toString().replaceAll('Section', 'Sec') ?? ''}",
                      tint.withValues(alpha: 0.1),
                      subTextColor.withValues(alpha: 0.8),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color bg, Color text) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: text)),
    );
  }
}
