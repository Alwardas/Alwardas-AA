import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
import '../../../widgets/skeleton_loader.dart';
import '../../../core/api_constants.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';

class PrincipalLessonPlansScreen extends StatefulWidget {
  const PrincipalLessonPlansScreen({super.key});

  @override
  _PrincipalLessonPlansScreenState createState() => _PrincipalLessonPlansScreenState();
}

class _PrincipalLessonPlansScreenState extends State<PrincipalLessonPlansScreen> {
  List<Map<String, dynamic>> deptProgress = [];
  bool isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

  Future<void> _fetchBranches() async {
    try {
      final res = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/coordinator/overall-syllabus-progress'));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        if (mounted) {
          setState(() {
            deptProgress = data.map((d) {
              return {
                 'dept': d['branch']?.toString() ?? '', 
                 'progress': (d['overallPercentage'] ?? 0) / 100.0,
                 'years': d['years'] ?? [],
              };
            }).toList();
            isLoading = false;
          });
        }
      } else {
         _fallbackBranches();
      }
    } catch (e) {
      debugPrint("Fetch Syllabus Progress Error: $e");
      _fallbackBranches();
    }
  }

  void _fallbackBranches() {
    if (!mounted) return;
    setState(() {
      deptProgress = [
        {
          'dept': 'Computer Engineering', 
          'progress': 0.75, 
          'years': [
            {'year': '1st Year', 'percentage': 80},
            {'year': '2nd Year', 'percentage': 70},
            {'year': '3rd Year', 'percentage': 75},
          ]
        },
        {
          'dept': 'Civil Engineering', 
          'progress': 0.60, 
          'years': [
            {'year': '1st Year', 'percentage': 60},
            {'year': '2nd Year', 'percentage': 55},
            {'year': '3rd Year', 'percentage': 65},
          ]
        },
      ];
      isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);
    final bgColor = isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Syllabus Management", 
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
      ),
      body: isLoading 
        ? _buildSkeletonLoader(isDark)
        : RefreshIndicator(
            onRefresh: _fetchBranches,
            color: ThemeColors.accentBlue,
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              children: [
                _buildHeader(textColor, subTextColor),
                const SizedBox(height: 30),
                ...deptProgress.map((d) => _buildEnhancedDeptCard(d, cardColor, textColor, subTextColor, isDark)),
                const SizedBox(height: 80),
              ],
            ),
          ),
    );
  }

  Widget _buildSkeletonLoader(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(24),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Container(
          margin: const EdgeInsets.only(bottom: 24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   SkeletonLoader(width: 140, height: 20, borderRadius: BorderRadius.circular(4)),
                   SkeletonLoader(width: 80, height: 24, borderRadius: BorderRadius.circular(12)),
                ],
              ),
              const SizedBox(height: 20),
              SkeletonLoader(width: 120, height: 24, borderRadius: BorderRadius.circular(4)),
              const SizedBox(height: 12),
              SkeletonLoader(width: double.infinity, height: 10, borderRadius: BorderRadius.circular(5)),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: List.generate(3, (i) => Column(
                  children: [
                    SkeletonLoader(width: 40, height: 40, borderRadius: BorderRadius.circular(20)),
                    const SizedBox(height: 8),
                    SkeletonLoader(width: 30, height: 10, borderRadius: BorderRadius.circular(4)),
                  ],
                )),
              )
            ],
          ),
        );
      },
    );
  }

  Widget _buildHeader(Color textColor, Color subTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "College-wide Progress",
          style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
        ),
        Text(
          "Tracking syllabus completion across all departments",
          style: GoogleFonts.poppins(fontSize: 14, color: subTextColor),
        ),
      ],
    );
  }

  Widget _buildEnhancedDeptCard(Map<String, dynamic> d, Color cardColor, Color textColor, Color subTextColor, bool isDark) {
    final double overallProgress = d['progress'];
    final List<dynamic> years = d['years'];
    final accentColor = _getAccentColor(overallProgress);

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
        border: Border.all(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.03),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(d['dept'].toUpperCase(), 
                      style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: accentColor, letterSpacing: 1.1)
                    ),
                    const SizedBox(height: 4),
                    Text("Overall Syllabus Progress", 
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)
                    ),
                  ],
                ),
              ),
              Container(
                height: 50,
                width: 50,
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.analytics_rounded, color: accentColor, size: 24),
              ),
            ],
          ),
          const SizedBox(height: 25),
          
          // Overall Progress Bar
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("${(overallProgress * 100).toInt()}% Completed", 
                style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)
              ),
              Text(overallProgress >= 0.75 ? "On Track" : (overallProgress >= 0.5 ? "In Progress" : "Needs Attention"),
                style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: accentColor)
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 10,
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.grey[200],
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
              FractionallySizedBox(
                widthFactor: overallProgress.clamp(0.0, 1.0),
                child: Container(
                  height: 10,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [accentColor.withOpacity(0.7), accentColor]),
                    borderRadius: BorderRadius.circular(5),
                    boxShadow: [
                      BoxShadow(color: accentColor.withOpacity(0.3), blurRadius: 4, offset: const Offset(0, 2)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 24),
          Divider(color: isDark ? Colors.white10 : Colors.black12, height: 1),
          const SizedBox(height: 20),
          
          // Yearly Breakdown
          Text("Yearly Breakdown", 
            style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: textColor.withOpacity(0.7))
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: years.map((y) => _buildYearMiniProgress(y, textColor, isDark)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildYearMiniProgress(dynamic yearData, Color textColor, bool isDark) {
    final String year = yearData['year']?.toString().split(' ')[0] ?? '';
    final int percentage = yearData['percentage'] ?? 0;
    final color = _getAccentColor(percentage / 100.0);

    return Column(
      children: [
        Container(
          height: 45,
          width: 45,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.2), width: 2),
          ),
          child: Center(
            child: Text("$percentage%", 
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: textColor)
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text("$year Year", 
          style: GoogleFonts.poppins(fontSize: 10, color: textColor.withOpacity(0.6), fontWeight: FontWeight.w500)
        ),
      ],
    );
  }

  Color _getAccentColor(double progress) {
    if (progress >= 0.8) return const Color(0xFF10B981); // Emerald
    if (progress >= 0.5) return const Color(0xFF6366F1); // Indigo
    if (progress >= 0.3) return const Color(0xFFF59E0B); // Amber
    return const Color(0xFFEF4444); // Red
  }
}
