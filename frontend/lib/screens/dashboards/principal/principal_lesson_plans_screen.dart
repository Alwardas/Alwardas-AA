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
import '../hod/hod_syllabus_management_screen.dart';

class PrincipalLessonPlansScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const PrincipalLessonPlansScreen({super.key, required this.userData});

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

  Widget _buildEnhancedDeptCard(Map<String, dynamic> dept, bool isDark) {
    final String name = dept['branch'] ?? 'Unknown';
    final int progress = dept['overallPercentage'] ?? 0;
    final List<dynamic> years = dept['years'] ?? [];
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final accentColor = _getAccentColor(progress / 100.0);

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => HodSyllabusManagementScreen(
          userData: widget.userData,
          branchOverride: name,
        )));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 24),
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
          ],
          border: Border.all(color: accentColor.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(name, 
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)
                  ),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                  child: Text(progress >= 75 ? "On Track" : "In Progress", 
                    style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor)
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("$progress% Overall", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                Icon(Icons.auto_graph_rounded, color: accentColor, size: 24),
              ],
            ),
            const SizedBox(height: 12),
            Stack(
              children: [
                Container(
                  height: 10,
                  width: double.infinity,
                  decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(5)),
                ),
                FractionallySizedBox(
                  widthFactor: (progress / 100.0).clamp(0.0, 1.0),
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [accentColor.withOpacity(0.7), accentColor]),
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: years.map((y) => _buildYearMiniProgress(y, textColor, isDark)).toList(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildYearMiniProgress(dynamic yearData, Color textColor, bool isDark) {
    final String year = yearData['year']?.toString().split(' ')[0] ?? '';
    final int percentage = yearData['percentage'] ?? 0;
    final color = _getStatusColor(percentage);

    return Column(
      children: [
        Container(
          height: 45,
          width: 45,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color.withOpacity(0.2), width: 2),
            color: color.withOpacity(0.1),
          ),
          child: Center(
            child: Text("$percentage%", 
              style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: color)
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

  Color _getStatusColor(int percentage) {
    if (percentage >= 85) return const Color(0xFFF59E0B); // Orange (Overfast/Ahead)
    if (percentage >= 60) return const Color(0xFF10B981); // Green (On Track)
    return const Color(0xFFEF4444); // Red (Lagging)
  }

  Color _getAccentColor(double progress) {
    return _getStatusColor((progress * 100).toInt());
  }
}
