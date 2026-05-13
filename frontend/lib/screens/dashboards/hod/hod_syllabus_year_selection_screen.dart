import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/providers/theme_provider.dart';
import '../../../core/api_constants.dart';
import '../../../widgets/skeleton_loader.dart';
import '../../../core/api_config.dart';
import 'hod_syllabus_year_details_screen.dart';

class HodSyllabusYearSelectionScreen extends StatefulWidget {
  final String courseId;
  final String courseName;
  final Map<String, dynamic> userData;

  const HodSyllabusYearSelectionScreen({
    super.key, 
    required this.courseId, 
    required this.courseName,
    required this.userData,
  });

  @override
  State<HodSyllabusYearSelectionScreen> createState() => _HodSyllabusYearSelectionScreenState();
}

class _HodSyllabusYearSelectionScreenState extends State<HodSyllabusYearSelectionScreen> {
  bool _isLoading = true;
  Map<String, int> _yearProgress = {};
  int _overallPercentage = 0;

  @override
  void initState() {
    super.initState();
    _fetchProgress();
  }

  Future<void> _fetchProgress() async {
    final branch = widget.userData['branch'] ?? 'Computer Engineering';
    final url = '${ApiConstants.baseUrl}/api/hod/syllabus/branch-progress?branch=${Uri.encodeComponent(branch)}&courseId=${Uri.encodeComponent(widget.courseId)}';
    try {
      final response = await ApiConfig.get(url);
      
      if (response.success && response.data != null) {
        final data = response.data;
        final List<dynamic> yearsData = data['years'] ?? [];
        
        Map<String, int> progressMap = {};
        for (var y in yearsData) {
          progressMap[y['year']] = (y['percentage'] as num).toInt();
        }

        setState(() {
          _yearProgress = progressMap;
          _overallPercentage = (data['overallPercentage'] as num).toInt();
          _isLoading = false;
        });
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching progress: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bgColors = isDark 
        ? [const Color(0xFF1a1a2e), const Color(0xFF16213e)] 
        : [const Color(0xFFF8F9FA), Colors.white];

    final years = [
      {'label': '1st Year', 'icon': Icons.looks_one},
      {'label': '2nd Year', 'icon': Icons.looks_two},
      {'label': '3rd Year', 'icon': Icons.looks_3},
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Select Year', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
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
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        Text(widget.courseName, style: GoogleFonts.poppins(fontSize: 16, color: textColor.withValues(alpha: 0.7))),
                        const SizedBox(height: 10),
                        Text("Select Academic Year", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                      ],
                    ),
                  ),
                  Expanded(
                    child: ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      itemCount: years.length + 1, // +1 for Overall Branch
                      itemBuilder: (context, index) {
                        if (index < years.length) {
                          final year = years[index];
                          final label = year['label'] as String;
                          final progress = _yearProgress[label] ?? 0;
                          return _buildYearCard(context, year, progress, isDark, textColor);
                        } else {
                          // Overall Branch Card
                          return _buildOverallCard(context, isDark, textColor);
                        }
                      },
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildYearCard(BuildContext context, Map<String, dynamic> year, int progress, bool isDark, Color textColor) {
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => HodSyllabusYearDetailsScreen(
          courseId: widget.courseId,
          courseName: widget.courseName,
          year: year['label'],
          userData: widget.userData,
        )));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 15),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: Colors.blue.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))
          ]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(year['icon'] as IconData, color: Colors.blue, size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(
                    year['label'] as String,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Expanded(
                        child: LinearProgressIndicator(
                          value: progress / 100,
                          backgroundColor: Colors.blue.withValues(alpha: 0.1),
                          color: Colors.blue,
                          borderRadius: BorderRadius.circular(10),
                          minHeight: 6,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text("$progress%", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.blue)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(Icons.arrow_forward_ios, size: 16, color: textColor.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }

  Widget _buildOverallCard(BuildContext context, bool isDark, Color textColor) {
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.purple, Colors.purple.shade700],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(color: Colors.purple.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 8))
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
                child: const Icon(Icons.analytics, color: Colors.white, size: 24),
              ),
              const SizedBox(width: 15),
              Text(
                "Overall Branch Progress",
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$_overallPercentage%", style: GoogleFonts.poppins(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.white)),
              SizedBox(
                width: 100,
                height: 10,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(5),
                  child: LinearProgressIndicator(
                    value: _overallPercentage / 100,
                    backgroundColor: Colors.white.withValues(alpha: 0.2),
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          Text(
            "Average of all academic years",
            style: GoogleFonts.poppins(fontSize: 12, color: Colors.white.withValues(alpha: 0.8)),
          ),
        ],
      ),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      itemCount: 4,
      itemBuilder: (context, index) {
        if (index < 3) {
          return Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
            ),
            child: Row(
              children: [
                SkeletonLoader(width: 52, height: 52, borderRadius: BorderRadius.circular(26)),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(width: 100, height: 18, borderRadius: BorderRadius.circular(4)),
                      const SizedBox(height: 12),
                      SkeletonLoader(width: double.infinity, height: 8, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
                ),
              ],
            ),
          );
        } else {
          return Container(
            margin: const EdgeInsets.symmetric(vertical: 20),
            padding: const EdgeInsets.all(25),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(25),
              border: Border.all(color: Colors.purple.withValues(alpha: 0.2)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SkeletonLoader(width: 200, height: 20, borderRadius: BorderRadius.circular(4)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    SkeletonLoader(width: 80, height: 36, borderRadius: BorderRadius.circular(4)),
                    SkeletonLoader(width: 100, height: 10, borderRadius: BorderRadius.circular(5)),
                  ],
                ),
              ],
            ),
          );
        }
      },
    );
  }
}

