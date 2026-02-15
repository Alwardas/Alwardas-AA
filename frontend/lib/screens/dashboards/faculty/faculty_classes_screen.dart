import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/courses_data.dart';
// Keep for reference or remove if unused
import 'faculty_lesson_plan_screen.dart';
import '../../../core/theme/app_theme.dart';

import 'faculty_add_subject_screen.dart';

class FacultyClassesScreen extends StatefulWidget {
  final VoidCallback? onBack;
  const FacultyClassesScreen({super.key, this.onBack});

  @override
  _FacultyClassesScreenState createState() => _FacultyClassesScreenState();
}

class _FacultyClassesScreenState extends State<FacultyClassesScreen> {
  List<dynamic> _facultySubjects = [];
  bool _loading = true;
  String _facultyName = '';
  List<dynamic> _allCourses = [];
  
  // Delete Mode State
  bool _isDeleteMode = false;
  final Set<String> _idsToDelete = {};

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _loading = true);
    final courses = await CoursesData.getAllCourses();
    if (mounted) {
      setState(() {
        _allCourses = courses;
      });
    }
    await _fetchFacultySubjects();
  }

  Future<void> _fetchFacultySubjects() async {
    try {
      final user = await AuthService.getUserSession();
      if (user == null) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      
      if (mounted) {
         setState(() {
           _facultyName = user['full_name'] ?? 'Faculty';
         });
      }
      
      final res = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/faculty/subjects?userId=${user['id']}'));
      if (res.statusCode == 200) {
        if (mounted) setState(() => _facultySubjects = json.decode(res.body));
      } else {
        if (mounted) setState(() => _facultySubjects = []);
      }
    } catch (e) {
      debugPrint("Error fetching subjects: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAddSubjects(List<Map<String, dynamic>> subjectDetails) async {
    final user = await AuthService.getUserSession();
    if (user == null) return;
    
    // Optimistic Update
    if (mounted) {
      setState(() {
        for (var d in subjectDetails) {
            final name = d['name'];
            if (!_facultySubjects.any((existing) => existing['name'] == name && existing['section'] == d['section'])) {
               _facultySubjects.add({
                  'id': d['id'],
                  'name': name,
                  'code': d['code'] ?? d['id'],
                  'branch': d['branch'],
                  'section': d['section'],
                  'year': d['year'],
                  // infer semester or leave blank for now, or the Add Screen could provide it
                  'semester': '?', 
                  'status': 'PENDING'
               });
            }
        }
      });
    }

    _showSnackBar("Requests sent to HODs.");
    
    try {
       for (var d in subjectDetails) {
          final response = await http.post(
            Uri.parse('${ApiConstants.baseUrl}/api/faculty/subjects'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({
              'userId': user['id'],
              'subjectId': d['id'],
              'subjectName': d['name'],
              'branch': d['branch'],
              'year': d['year'],
              'section': d['section']
            })
          );
          
          if (response.statusCode != 200) {
             throw Exception('Failed to add subject: ${response.body}');
          }
       }
    } catch (e) {
      _showSnackBar("Network Error: ${e.toString()}");
    }
  }

  void _openAddPage() async {
    final result = await Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (_) => FacultyAddSubjectScreen(
          allCourses: _allCourses,
          existingSubjects: _facultySubjects,
        )
      )
    );

    if (result != null && result is List<Map<String, dynamic>> && result.isNotEmpty) {
      _handleAddSubjects(result);
    }
  }

  void _showSnackBar(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  // _promptRemoveAll Removed in favor of bulk delete mode

  Future<void> _deleteSelectedSubjects() async {
    final user = await AuthService.getUserSession();
    if (user == null) return;
    
    // Optimistic clear
    final backup = List.from(_facultySubjects);
    setState(() {
      _facultySubjects.removeWhere((s) => _idsToDelete.contains(s['id'].toString()));
      _isDeleteMode = false; // Exit mode immediately
    });
    
    try {
      for (var id in _idsToDelete) {
         final request = http.Request('DELETE', Uri.parse('${ApiConstants.baseUrl}/api/faculty/subjects'));
         request.headers['Content-Type'] = 'application/json';
         request.body = json.encode({'userId': user['id'], 'subjectId': id});
         await request.send();
      }
      _showSnackBar("Selected subjects removed.");
      _idsToDelete.clear();
      _fetchFacultySubjects();
    } catch (e) {
      _showSnackBar("Failed to remove some subjects.");
      // Revert if critical failure or just re-fetch
      _fetchFacultySubjects();
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        systemOverlayStyle: AppTheme.getAdaptiveOverlayStyle(isDark),
        centerTitle: true,
        leading: _isDeleteMode 
          ? IconButton(
              icon: Icon(Icons.close, color: textColor),
              onPressed: () => setState(() {
                _isDeleteMode = false;
                _idsToDelete.clear();
              }),
            )
          : IconButton(
              icon: Icon(Icons.arrow_back, color: textColor),
              onPressed: () {
                if (widget.onBack != null) {
                  widget.onBack!();
                } else {
                  Navigator.pop(context);
                }
              },
            ),
        title: Text(
          _isDeleteMode ? "${_idsToDelete.length} Selected" : "My Courses",
          style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          if (!_isDeleteMode) ...[
             IconButton(
               icon: Icon(Icons.add, color: textColor),
               onPressed: _openAddPage,
             ),
             if (_facultySubjects.isNotEmpty)
               IconButton(
                 icon: Icon(Icons.delete_outline, color: textColor),
                 onPressed: () => setState(() => _isDeleteMode = true),
               )
          ] else ...[
             IconButton(
               icon: Icon(Icons.delete, color: Colors.red),
               onPressed: _idsToDelete.isEmpty ? null : _deleteSelectedSubjects,
             )
          ]
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? AppTheme.darkBodyGradient : AppTheme.lightBodyGradient, 
            begin: Alignment.topCenter, 
            end: Alignment.bottomCenter
          )
        ),
        child: _loading 
              ? const Center(child: CircularProgressIndicator())
              : _facultySubjects.isEmpty
                ? _buildEmptyState(tint, textColor, subTextColor)
                : _buildSubjectsList(isDark, textColor, subTextColor, tint),
      ),
    );
  }

  Widget _buildEmptyState(Color tint, Color textColor, Color subTextColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(
            onTap: _openAddPage,
            child: Container(
              padding: const EdgeInsets.all(30),
              decoration: BoxDecoration(
                color: tint.withValues(alpha: 0.1),
                shape: BoxShape.circle,
                border: Border.all(color: tint.withValues(alpha: 0.3), width: 2),
              ),
              child: Icon(Icons.add, size: 80, color: tint),
            ),
          ),
          const SizedBox(height: 20),
          Text("No subjects added", style: GoogleFonts.poppins(color: textColor, fontSize: 18, fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text("Tap the plus to add subjects to your account", style: GoogleFonts.poppins(color: subTextColor)),
        ],
      ),
    );
  }

  Widget _buildSubjectsList(bool isDark, Color textColor, Color subTextColor, Color tint) {
    final topPadding = MediaQuery.of(context).padding.top + kToolbarHeight + 20;

    // Helper to get code safely
    String getCode(Map<String, dynamic> item) {
       if (item['code'] != null && item['code'].toString().isNotEmpty) return item['code'];
       // Lookup
       if (_allCourses.isNotEmpty) {
           final match = _allCourses.firstWhere(
             (c) => c['id'].toString() == item['subjectId'].toString() || c['id'].toString() == item['id'].toString(), 
             orElse: () => null
           );
           if (match != null) return match['code'] ?? '';
       }
       return '';
    }

    // Sort by Code (Prefix + Number)
    final sortedSubjects = List<Map<String, dynamic>>.from(_facultySubjects);
    sortedSubjects.sort((a, b) {
      String codeA = getCode(a).toUpperCase();
      String codeB = getCode(b).toUpperCase();
      
      // Regex to separate prefix (letters, optional) and number
      // e.g., "CM-101" -> Prefix: "CM", Number: 101
      // e.g., "101" -> Prefix: "", Number: 101
      final RegExp exp = RegExp(r'^([A-Z]*)[^0-9]*([0-9]+)');
      final matchA = exp.firstMatch(codeA);
      final matchB = exp.firstMatch(codeB);
      
      if (matchA != null && matchB != null) {
        String prefixA = matchA.group(1) ?? '';
        int numA = int.parse(matchA.group(2) ?? '0');
        
        String prefixB = matchB.group(1) ?? '';
        int numB = int.parse(matchB.group(2) ?? '0');
        
        int prefixComp = prefixA.compareTo(prefixB);
        if (prefixComp != 0) return prefixComp;
        
        return numA.compareTo(numB);
      }
      
      // Fallback: Code might be purely numeric without regex match
      int? intA = int.tryParse(codeA.replaceAll(RegExp(r'[^0-9]'), ''));
      int? intB = int.tryParse(codeB.replaceAll(RegExp(r'[^0-9]'), ''));
      if (intA != null && intB != null) {
        return intA.compareTo(intB);
      }
      return codeA.compareTo(codeB);
    });

    return ListView.builder(
      padding: EdgeInsets.fromLTRB(20, topPadding, 20, 20),
      itemCount: sortedSubjects.length,
      itemBuilder: (ctx, index) {
        final item = sortedSubjects[index];
        final isPending = (item['status'] ?? '').toString().toUpperCase() == 'PENDING';
        final code = getCode(item);
        
        // Colors matching Student Dashboard
        final cardBg = isDark ? const Color(0xFF1E1E2C) : Colors.white;
        final titleColor = isDark ? Colors.white : const Color(0xFF1A1A2E); 
        final subtitleColor = isDark ? Colors.white70 : Colors.grey[600]!;
        final courseIdColor = const Color(0xFF4B7FFB);
        
        // Status Logic for Faculty
        String statusText;
        Color statusColor;
        if (isPending) {
           statusText = "Pending Approval";
           statusColor = Colors.orange;
        } else {
           statusText = "On Track"; 
           statusColor = const Color(0xFF34C759);
        }

        // Mock Progress for visual consistency
        final progress = 0; 

        return GestureDetector(
          onTap: () {
             if (isPending) return; // Do nothing if pending
             
             // Navigate to Lesson Plan details
             Navigator.push(
               context,
               MaterialPageRoute(
                 builder: (context) => FacultyLessonPlanScreen(
                   subjectId: item['subjectId']?.toString() ?? item['id'].toString(), 
                   subjectName: item['name'] ?? 'Subject',
                   facultyName: _facultyName.isNotEmpty ? _facultyName : 'You',
                   section: item['section'],
                 ),
               ),
             );
          },
          child: Opacity(
            opacity: isPending ? 0.6 : 1.0, // Fade out pending items
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(18),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header Row: Code â€¢ Semester â€¢ Branch â€¢ Section
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            code.isNotEmpty ? code : "---",
                            style: GoogleFonts.poppins(
                              color: courseIdColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.5,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            "â€¢",
                            style: GoogleFonts.poppins(color: subtitleColor.withValues(alpha: 0.5)),
                          ),
                          const SizedBox(width: 8),
                           Expanded(
                            child: Text(
                              // Combine Sem, Branch, Section
                              "Sem ${item['semester'] ?? '?'} â€¢ ${(item['branch'] ?? '').toString().split(' ').first} ${item['section'] != null ? 'â€¢ Sec ${item['section']}' : ''}",
                              style: GoogleFonts.poppins(
                                color: subtitleColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Actions: ONLY Checkbox for Delete Mode
                    if (_isDeleteMode)
                      SizedBox(
                        height: 24,
                        width: 24,
                        child: Checkbox(
                          value: _idsToDelete.contains(item['id'].toString()),
                          activeColor: Colors.red,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                          onChanged: (val) {
                            setState(() {
                              if (val == true) {
                                _idsToDelete.add(item['id'].toString());
                              } else {
                                _idsToDelete.remove(item['id'].toString());
                              }
                            });
                          },
                        ),
                      )
                  ],
                ),
                
                const SizedBox(height: 8),

                // Course Name
                Text(
                  item['name'] ?? 'Untitled Subject',
                  style: GoogleFonts.manrope(
                    color: titleColor,
                    fontSize: 14, // Reduced size
                    fontWeight: FontWeight.w700,
                    height: 1.2,
                  ),
                ),

                
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

                // Progress Bar Row (Visual only)
                Row(
                  children: [
                    Expanded(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: progress / 100.0,
                          backgroundColor: isDark ? Colors.white10 : Colors.grey.shade100,
                          color: statusColor,
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
        );
      },
    );
  }

  Widget _buildTag(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Text(
        text.toUpperCase(), 
        style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.bold, fontSize: 10)
      ),
    );
  }
}

