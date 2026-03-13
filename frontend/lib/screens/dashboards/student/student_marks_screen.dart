import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import '../../../../core/services/auth_service.dart';
import '../../../../core/api_constants.dart';

class StudentMarksScreen extends StatefulWidget {
  final String? userId;
  const StudentMarksScreen({super.key, this.userId});

  @override
  State<StudentMarksScreen> createState() => _StudentMarksScreenState();
}

class _StudentMarksScreenState extends State<StudentMarksScreen> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _semesters = [];

  @override
  void initState() {
    super.initState();
    _fetchAcademics();
  }

  Future<void> _fetchAcademics() async {
    try {
      final user = await AuthService.getUserSession();
      if (user == null) {
        setState(() {
          _error = "User session not found.";
          _isLoading = false;
        });
        return;
      }

      final targetUserId = widget.userId ?? user['id'];
      final url = Uri.parse('${ApiConstants.baseUrl}/api/student/academics?userId=$targetUserId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        setState(() {
          _semesters = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Failed to load academic records.";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Network error while connecting.";
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: Text("Academics & Marks", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.poppins(color: Colors.red)))
              : _semesters.isEmpty
                  ? Center(child: Text("No academic records found.", style: GoogleFonts.poppins(color: textColor)))
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      physics: const BouncingScrollPhysics(),
                      itemCount: _semesters.length,
                      itemBuilder: (context, index) {
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 20),
                          child: _buildSemesterCard(context, _semesters[index]),
                        );
                      },
                    ),
    );
  }

  Widget _buildSemesterCard(BuildContext context, Map<String, dynamic> semesterData) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E24) : Colors.white;

    final String yearLabel = semesterData['yearLabel'] ?? '';
    final String semName = semesterData['semesterName'] ?? '';
    final bool isOngoing = semesterData['isOngoing'] ?? false;
    final double? sgpa = semesterData['sgpa'];

    final String title = "$yearLabel – $semName${isOngoing ? ' (Ongoing)' : ''}";
    
    final List<dynamic> subjects = semesterData['subjects'] ?? [];
    
    int backlogCount = 0;
    for (var sub in subjects) {
      final marks = sub['marks'];
      final grade = sub['grade'];
      if ((marks != null && marks < 35) || grade == 'F') {
        backlogCount++;
      }
    }

    String sgpaText;
    if (isOngoing) {
      sgpaText = sgpa != null ? "Current Avg: ${sgpa.toStringAsFixed(2)}" : "Current Avg: -";
    } else {
      sgpaText = sgpa != null ? "SGPA: ${sgpa.toStringAsFixed(2)}" : "SGPA: -";
    }

    Widget subtitleWidget;
    if (backlogCount > 0) {
      subtitleWidget = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(sgpaText, style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.w600)),
          const SizedBox(height: 2),
          Text("$backlogCount Backlog", style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
        ],
      );
    } else {
      subtitleWidget = Text(sgpaText, style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.w600));
    }

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
        ]
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: subtitleWidget,
          children: [
            if (subjects.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text("No subjects available for this semester.", style: GoogleFonts.poppins(color: Colors.grey)),
              )
            else
              ...subjects.map((sub) {
                final subName = sub['subjectName'] ?? 'Unknown Subject';
                final marks = sub['marks'];
                final scoreStr = marks != null ? "$marks / 100" : "- / 100";
                final gradeStr = sub['grade'] ?? "-";
                
                final bool isFailed = (marks != null && marks < 40) || gradeStr == 'F';
                
                final bgColor = isFailed ? Colors.red.withValues(alpha: 0.05) : Colors.transparent;
                final textColor = isFailed ? Colors.red : (isDark ? Colors.white : Colors.black);
                final subtitleColor = isFailed ? Colors.red[300]! : Colors.grey;

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  decoration: BoxDecoration(
                    color: bgColor,
                    border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.1)))
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text("${sub['subjectId']} - $subName", style: GoogleFonts.poppins(fontWeight: FontWeight.w500, color: textColor)),
                            Text(
                              isFailed ? "$scoreStr (Failed)" : scoreStr,
                              style: GoogleFonts.poppins(fontSize: 12, color: subtitleColor)
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 10),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.grey[800] : Colors.grey[100],
                          borderRadius: BorderRadius.circular(10)
                        ),
                        child: Text(gradeStr, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      )
                    ],
                  ),
                );
              })
          ],
        ),
      ),
    );
  }
}

