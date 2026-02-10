import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../core/api_constants.dart';
import '../../core/providers/theme_provider.dart';
import '../../theme/theme_constants.dart';

class CommonLessonPlanViewer extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final String facultyName;

  const CommonLessonPlanViewer({
    super.key,
    required this.subjectId,
    required this.subjectName,
    required this.facultyName,
  });

  @override
  State<CommonLessonPlanViewer> createState() => _CommonLessonPlanViewerState();
}

class _CommonLessonPlanViewerState extends State<CommonLessonPlanViewer> {
  bool _isLoading = true;
  String? _error;
  List<dynamic> _topics = [];
  Map<String, dynamic>? _stats;

  @override
  void initState() {
    super.initState();
    _fetchLessonPlan();
  }

  Future<void> _fetchLessonPlan() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/student/lesson-plan?subjectId=${widget.subjectId}'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _topics = data['items'] ?? [];
          _stats = {
            'percentage': data['percentage'],
            'status': data['status'],
            'warning': data['warning']
          };
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Failed to load lesson plan: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error: $e";
        _isLoading = false;
      });
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
        title: Column(
          children: [
            Text("Lesson Plan", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
            Text(widget.subjectName, style: GoogleFonts.poppins(fontSize: 12, color: subTextColor)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: _isLoading
              ? Center(child: CircularProgressIndicator(color: tint))
              : _error != null
                  ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
                  : Column(
                      children: [
                        // Stats Card
                        if (_stats != null)
                          Container(
                            margin: const EdgeInsets.all(20),
                            padding: const EdgeInsets.all(20),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: iconBg),
                              boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
                            ),
                            child: Row(
                              children: [
                                CircularProgressIndicator(
                                  value: (_stats!['percentage'] as int) / 100,
                                  backgroundColor: iconBg,
                                  color: _getStatusColor(_stats!['status'] ?? 'NORMAL'),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        "${_stats!['percentage']}% Completed",
                                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                                      ),
                                      Text(
                                        "Status: ${_stats!['status']}",
                                        style: GoogleFonts.poppins(fontSize: 14, color: _getStatusColor(_stats!['status'] ?? 'NORMAL'), fontWeight: FontWeight.w600),
                                      ),
                                      if (_stats!['warning'] != null)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 4),
                                          child: Text(
                                            _stats!['warning'],
                                            style: GoogleFonts.poppins(fontSize: 12, color: Colors.orange),
                                          ),
                                        ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),

                        // Topics List
                        Expanded(
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 0),
                            itemCount: _topics.length,
                            itemBuilder: (ctx, index) {
                              final item = _topics[index];
                              final isCompleted = item['completed'] ?? false;
                              return Container(
                                margin: const EdgeInsets.only(bottom: 12),
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: cardColor,
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(color: isCompleted ? Colors.green.withValues(alpha: 0.3) : iconBg, width: isCompleted ? 1.5 : 1),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: isCompleted ? Colors.green.withValues(alpha: 0.1) : iconBg.withValues(alpha: 0.5),
                                        shape: BoxShape.circle,
                                      ),
                                      child: Text(
                                        "${index + 1}",
                                        style: TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: isCompleted ? Colors.green : subTextColor,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            item['topic'] ?? 'No Topic',
                                            style: GoogleFonts.poppins(
                                              fontWeight: FontWeight.w600,
                                              fontSize: 15,
                                              color: textColor,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            item['text'] ?? '',
                                            style: TextStyle(color: subTextColor, fontSize: 13),
                                          ),
                                          if (isCompleted && item['completed_at'] != null)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 6),
                                              child: Row(
                                                children: [
                                                  const Icon(Icons.check_circle, size: 14, color: Colors.green),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    "Completed on ${item['completed_at'].toString().split('T')[0]}",
                                                    style: const TextStyle(color: Colors.green, fontSize: 11, fontWeight: FontWeight.bold),
                                                  ),
                                                ],
                                              ),
                                            ),
                                        ],
                                      ),
                                    ),
                                  ],
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'LAGGING': return Colors.red;
      case 'OVERFAST': return Colors.orange;
      case 'NORMAL': return Colors.green;
      default: return Colors.blue;
    }
  }
}
