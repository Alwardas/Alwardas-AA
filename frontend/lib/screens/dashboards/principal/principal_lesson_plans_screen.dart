import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:math';
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
      final res = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/departments'));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        final colors = [Colors.blue, Colors.green, Colors.orange, Colors.red, Colors.purple, Colors.teal];
        final random = Random();
        
        if (mounted) {
          setState(() {
            deptProgress = data.map((d) {
              final String branchName = d['branch']?.toString() ?? '';
              return {
                 'dept': branchName, 
                 'progress': 0.40 + (random.nextDouble() * 0.50), // 40-90%
                 'color': colors[deptProgress.length % colors.length]
              };
            }).where((b) => (b['dept'] as String).isNotEmpty).toList();
            isLoading = false;
          });
        }
      } else {
         _fallbackBranches();
      }
    } catch (e) {
      _fallbackBranches();
    }
  }

  void _fallbackBranches() {
    if (!mounted) return;
    setState(() {
      deptProgress = [
        {'dept': 'Computer Engineering', 'progress': 0.75, 'color': Colors.blue},
        {'dept': 'Civil Engineering', 'progress': 0.60, 'color': Colors.green},
        {'dept': 'Mechanical Engineering', 'progress': 0.85, 'color': Colors.orange},
        {'dept': 'Electrical Engineering', 'progress': 0.45, 'color': Colors.red},
      ];
      isLoading = false;
    });
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

    // Find highest completion
    Map<String, dynamic>? highest;
    if (deptProgress.isNotEmpty) {
      highest = deptProgress.reduce((curr, next) => curr['progress'] > next['progress'] ? curr : next);
    }

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Syllabus Management", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: isLoading 
            ? Center(child: CircularProgressIndicator(color: tint))
            : ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                "Departmental Overview",
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
              ),
              const SizedBox(height: 20),
              ...deptProgress.map((d) => _buildDeptProgressCard(d, cardColor, textColor, subTextColor, iconBg)),
              const SizedBox(height: 30),
              if (highest != null) ...[
                Text(
                  "Highest Completion",
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 15),
                _buildTopPerformerCard(highest['dept'], '${(highest['progress'] * 100).toInt()}%', cardColor, textColor, highest['color'], iconBg),
              ]
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDeptProgressCard(Map<String, dynamic> d, Color cardColor, Color textColor, Color subTextColor, Color iconBg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: iconBg),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(d['dept'], style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor), overflow: TextOverflow.ellipsis),
              ),
              Text("${(d['progress'] * 100).toInt()}%", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: d['color'])),
            ],
          ),
          const SizedBox(height: 15),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: d['progress'],
              backgroundColor: iconBg,
              color: d['color'],
              minHeight: 10,
            ),
          ),
          const SizedBox(height: 15),
          Row(
            children: [
              _buildStat("85 Total Units", subTextColor),
              const SizedBox(width: 20),
              _buildStat("${(85 * d['progress']).toInt()} Completed", subTextColor),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildStat(String text, Color color) {
    return Row(
      children: [
        Container(width: 6, height: 6, decoration: BoxDecoration(color: color.withValues(alpha: 0.5), shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(text, style: GoogleFonts.poppins(fontSize: 12, color: color)),
      ],
    );
  }

  Widget _buildTopPerformerCard(String name, String value, Color cardColor, Color textColor, Color accentColor, Color iconBg) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [accentColor.withValues(alpha: 0.8), accentColor], begin: Alignment.topLeft, end: Alignment.bottomRight),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: accentColor.withValues(alpha: 0.3), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Current Leader", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13)),
                Text(name, style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.2), borderRadius: BorderRadius.circular(12)),
            child: Text(value, style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20)),
          )
        ],
      ),
    );
  }
}
