import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/api_constants.dart';
import '../../../widgets/skeleton_loader.dart';

class HodSyllabusLessonTopicsScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final String year;
  final String semester;
  final String section;
  final Map<String, dynamic> userData;

  const HodSyllabusLessonTopicsScreen({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.year,
    required this.semester,
    required this.section,
    required this.userData,
  });

  @override
  State<HodSyllabusLessonTopicsScreen> createState() => _HodSyllabusLessonTopicsScreenState();
}

class _HodSyllabusLessonTopicsScreenState extends State<HodSyllabusLessonTopicsScreen> {
  bool _isLoading = true;
  List<dynamic> _topics = [];

  @override
  void initState() {
    super.initState();
    _fetchTopics();
  }

  Future<void> _fetchTopics() async {
    final branch = widget.userData['branch'] ?? 'Computer Engineering';
    final url = Uri.parse('${ApiConstants.baseUrl}/api/faculty/hod-lesson-topics?subject_id=${Uri.encodeComponent(widget.subjectId)}&section=${Uri.encodeComponent(widget.section)}&branch=${Uri.encodeComponent(branch)}');
    try {
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> fetched = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            _topics = fetched;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching topics: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate(Map<String, dynamic> topic) async {
    // Safety check for date parsing
    DateTime initial;
    try {
      if (topic['scheduleDate'] != null) {
        initial = DateTime.parse(topic['scheduleDate']).toLocal();
      } else {
        initial = DateTime.now();
      }
    } catch (e) {
      initial = DateTime.now();
    }

    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2023),
      lastDate: DateTime(2030),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.deepPurple,
              brightness: Theme.of(context).brightness,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _assignSchedule(topic['id'], picked);
    }
  }

  Future<void> _assignSchedule(String topicId, DateTime date) async {
    final url = Uri.parse('${ApiConstants.baseUrl}/api/faculty/hod-assign-schedule');
    final branch = widget.userData['branch'] ?? 'Computer Engineering';
    
    try {
      // Format as YYYY-MM-DD to avoid timezone shifting
      final dateStr = DateFormat('yyyy-MM-dd').format(date);
      
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'subjectId': widget.subjectId,
          'topicId': topicId,
          'scheduleDate': dateStr, // Sending formatted date
          'facultyId': widget.userData['login_id'],
          'branch': branch,
          'year': widget.year,
          'semester': widget.semester,
          'section': widget.section,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Schedule updated successfully!")));
        _fetchTopics(); // Refresh
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update schedule.")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network error.")));
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
        title: Text(widget.subjectName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
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
            : Column(
                children: [
                   Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text("Syllabus Breakdown", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                              Text("ID: ${widget.subjectId}", style: TextStyle(fontSize: 10, color: subTextColor)),
                            ],
                          ),
                        ),
                        _buildInfoBadge(widget.section, Colors.purple),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _topics.isEmpty
                        ? Center(child: Text("No topics found for this subject.", style: GoogleFonts.poppins(color: subTextColor)))
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                            itemCount: _topics.length,
                            itemBuilder: (context, index) {
                              final topic = _topics[index];
                              
                              // Check if we need a Unit Header if the unit column exists but no explicit unit row
                              bool showUnitDivider = false;
                              if (index == 0) {
                                showUnitDivider = true;
                              } else {
                                final prevUnit = _topics[index - 1]['unit'];
                                final currUnit = topic['unit'];
                                if (currUnit != prevUnit && currUnit != null) {
                                  showUnitDivider = true;
                                }
                              }

                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (showUnitDivider && topic['type']?.toString().toLowerCase() != 'unit') 
                                    Padding(
                                      padding: const EdgeInsets.only(top: 20, bottom: 10, left: 8),
                                      child: Text(
                                        topic['unit'] ?? '',
                                        style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey),
                                      ),
                                    ),
                                  _buildTopicCard(topic, isDark, textColor, subTextColor),
                                ],
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

  Widget _buildTopicCard(dynamic topic, bool isDark, Color textColor, Color subTextColor) {
    final String type = topic['type']?.toString().toLowerCase() ?? 'topic';
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final hasSchedule = topic['scheduleDate'] != null;
    final bool isCompleted = topic['completed'] == true;
    
    // Non-topic items (headings, unit ends, etc.) should not have date assignment
    if (type == 'unit' || type == 'unitend' || type == 'heading') {
       return Padding(
         padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
         child: Text(
           topic['topicName'] ?? 'Heading',
           style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.deepPurple, fontStyle: FontStyle.italic),
         ),
       );
    }
    
    String dateStr = "Assign Date";
    if (hasSchedule) {
      try {
        dateStr = DateFormat('dd/MM/yyyy').format(DateTime.parse(topic['scheduleDate']).toLocal());
      } catch (e) {
        dateStr = "Error";
      }
    }
    
    String completedDateStr = "";
    if (isCompleted && topic['completedDate'] != null) {
      try {
        completedDateStr = DateFormat('dd/MM/yyyy').format(DateTime.parse(topic['completedDate']).toLocal());
      } catch (e) {
        completedDateStr = "Err";
      }
    }

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted 
            ? Colors.green.withValues(alpha: 0.2) 
            : (hasSchedule ? Colors.deepPurple.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1))
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 4, offset: const Offset(0, 2))
        ]
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            Container(
              width: 5,
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green : (hasSchedule ? Colors.deepPurple : Colors.grey.withValues(alpha: 0.3)),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(16), bottomLeft: Radius.circular(16)),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            topic['topicName'] ?? 'Unnamed Topic',
                            style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: textColor),
                          ),
                        ),
                        if (isCompleted)
                          const Icon(Icons.check_circle, color: Colors.green, size: 18),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                       children: [
                          _buildActionButton(
                            label: dateStr,
                            icon: Icons.calendar_today,
                            color: hasSchedule ? Colors.deepPurple : Colors.grey,
                            onTap: () => _pickDate(topic),
                          ),
                          if (isCompleted) ...[
                            const SizedBox(width: 8),
                            _buildActionButton(
                              label: completedDateStr,
                              icon: Icons.done_all,
                              color: Colors.green,
                              onTap: null,
                            ),
                          ],
                       ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActionButton({required String label, required IconData icon, required Color color, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: color),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInfoBadge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20), border: Border.all(color: color.withValues(alpha: 0.3))),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 6,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SkeletonLoader(width: 100, height: 12, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 12),
            SkeletonLoader(width: double.infinity, height: 16, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 15),
            Row(
              children: [
                SkeletonLoader(width: 120, height: 28, borderRadius: BorderRadius.circular(8)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
