import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/api_constants.dart';

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
        setState(() {
          _topics = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching topics: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _pickDate(Map<String, dynamic> topic) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: topic['scheduleDate'] != null ? DateTime.parse(topic['scheduleDate']) : DateTime.now(),
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
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'subjectId': widget.subjectId,
          'topicId': topicId,
          'scheduleDate': date.toUtc().toIso8601String(),
          'facultyId': widget.userData['login_id'], // Or null, but usually we know who is assigning
          'branch': branch,
          'year': widget.year,
          'semester': widget.semester,
          'section': widget.section,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Schedule assigned!")));
        _fetchTopics(); // Refresh
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to assign schedule.")));
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
            ? const Center(child: CircularProgressIndicator())
            : Column(
                children: [
                   Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("Topics List", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        _buildInfoBadge(widget.section, Colors.purple),
                      ],
                    ),
                  ),
                  Expanded(
                    child: _topics.isEmpty
                        ? Center(child: Text("No topics found for this subject.", style: GoogleFonts.poppins(color: subTextColor)))
                        : ListView.builder(
                            padding: const EdgeInsets.all(20),
                            itemCount: _topics.length,
                            itemBuilder: (context, index) {
                              final topic = _topics[index];
                              return _buildTopicCard(topic, isDark, textColor, subTextColor);
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
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final bool hasSchedule = topic['scheduleDate'] != null;
    final bool isCompleted = topic['completed'] == true;
    final dateStr = hasSchedule ? DateFormat('dd/MM/yyyy').format(DateTime.parse(topic['scheduleDate'])) : "Not Scheduled";
    final completedDateStr = isCompleted && topic['completedDate'] != null 
        ? DateFormat('dd/MM/yyyy').format(DateTime.parse(topic['completedDate'])) 
        : "";

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isCompleted 
            ? Colors.green.withValues(alpha: 0.3) 
            : (hasSchedule ? Colors.deepPurple.withValues(alpha: 0.3) : Colors.grey.withValues(alpha: 0.2))
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      topic['unit'] ?? 'Unit X',
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: isCompleted ? Colors.green : Colors.deepPurpleAccent),
                    ),
                    if (isCompleted)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.green.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          "Completed",
                          style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.green),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  topic['topicName'] ?? 'Unnamed Topic',
                  style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: textColor),
                ),
                const SizedBox(height: 10),
                Row(
                   children: [
                      GestureDetector(
                        onTap: () => _pickDate(topic),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: hasSchedule ? Colors.deepPurple.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.calendar_today, size: 14, color: hasSchedule ? Colors.deepPurple : subTextColor),
                              const SizedBox(width: 6),
                              Text(
                                dateStr,
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: hasSchedule ? Colors.deepPurple : subTextColor),
                              ),
                            ],
                          ),
                        ),
                      ),
                      if (isCompleted) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: Colors.green.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.check_circle, size: 14, color: Colors.green),
                              const SizedBox(width: 6),
                              Text(
                                completedDateStr,
                                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.green),
                              ),
                            ],
                          ),
                        ),
                      ],
                   ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.edit_calendar, color: Colors.deepPurple.withValues(alpha: 0.7)),
            onPressed: () => _pickDate(topic),
          ),
        ],
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
}
