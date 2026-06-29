import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/providers/theme_provider.dart';
import '../../../core/api_constants.dart';
import '../../../theme/theme_constants.dart';
import '../../../widgets/skeleton_loader.dart';
import 'hod_syllabus_year_details_screen.dart';

import '../../../core/api_config.dart';

class HodSyllabusManagementScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String? branchOverride;
  const HodSyllabusManagementScreen({super.key, required this.userData, this.branchOverride});

  @override
  State<HodSyllabusManagementScreen> createState() => _HodSyllabusManagementScreenState();
}

class _HodSyllabusManagementScreenState extends State<HodSyllabusManagementScreen> {
  bool _isLoading = true;
  Map<String, dynamic>? _branchProgress;

  @override
  void initState() {
    super.initState();
    _fetchBranchProgress();
  }

  Future<void> _fetchBranchProgress() async {
    try {
      final String branch = widget.branchOverride ?? widget.userData['branch'] ?? 'Computer Engineering';
      final response = await ApiConfig.get('${ApiConstants.baseUrl}/api/hod/branch-progress?branch=${Uri.encodeComponent(branch)}&courseId=C-23');
      if (response.success) {
        if (mounted) {
          setState(() {
            _branchProgress = response.data is Map ? response.data : null;
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching branch progress: $e");
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
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

    final yearsList = [
      {'label': '1st Year', 'icon': Icons.looks_one},
      {'label': '2nd Year', 'icon': Icons.looks_two},
      {'label': '3rd Year', 'icon': Icons.looks_3},
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Syllabus Management', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
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
                  Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        await _fetchBranchProgress();
                      },
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        children: [
                          const SizedBox(height: 10),
                          if (_branchProgress != null)
                            _buildBranchProgressCard(_branchProgress!, isDark),
                        
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 20.0),
                            child: Text(
                              "Select Academic Year",
                              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: textColor),
                            ),
                          ),
                          ...yearsList.map((year) {
                            int progress = 0;
                            if (_branchProgress != null && _branchProgress!['years'] != null) {
                              final yearsData = _branchProgress!['years'] as List<dynamic>;
                              final match = yearsData.firstWhere((y) => y['year'] == year['label'], orElse: () => null);
                              if (match != null) {
                                progress = (match['percentage'] as num).toInt();
                              }
                            }
                            return _buildYearCard(context, year, progress, isDark, textColor);
                          }),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
        ),
      ),
    );
  }

  Widget _buildBranchProgressCard(Map<String, dynamic> data, bool isDark) {
    final int overall = data['overallPercentage'] ?? 0;
    final List<dynamic> years = data['years'] ?? [];
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final accentColor = _getAccentColor(overall / 100.0);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 20, offset: const Offset(0, 10))
        ],
        border: Border.all(color: accentColor.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text("Overall Branch Progress", 
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: accentColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                child: Text(overall >= 75 ? "On Track" : "In Progress", 
                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.bold, color: accentColor)
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("$overall% Completed", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
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
                widthFactor: (overall / 100.0).clamp(0.0, 1.0),
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
            children: years.map((y) => _buildYearMiniProgress(y, textColor)).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildYearMiniProgress(dynamic yearData, Color textColor) {
    final String year = yearData['year']?.toString().split(' ')[0] ?? '';
    final int percentage = yearData['percentage'] ?? 0;
    final color = _getStatusColor(percentage);

    return Column(
      children: [
        Container(
          height: 40,
          width: 40,
          decoration: BoxDecoration(
            shape: BoxShape.circle, 
            border: Border.all(color: color.withOpacity(0.2), width: 2),
            color: color.withOpacity(0.1),
          ),
          child: Center(
            child: Text("$percentage%", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: color)),
          ),
        ),
        const SizedBox(height: 6),
        Text("$year Yr", style: GoogleFonts.poppins(fontSize: 10, color: textColor.withOpacity(0.6))),
      ],
    );
  }

  Color _getStatusColor(int percentage) {
    if (percentage >= 85) return const Color(0xFFF59E0B);
    if (percentage >= 60) return const Color(0xFF10B981);
    return const Color(0xFFEF4444);
  }

  Color _getAccentColor(double progress) {
    return _getStatusColor((progress * 100).toInt());
  }

  Widget _buildYearCard(BuildContext context, Map<String, dynamic> year, int progress, bool isDark, Color textColor) {
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;

    return GestureDetector(
      onTap: () {
        final courseId = year['label'] == '1st Year' ? 'C-26' : 'C-23';
        final courseName = year['label'] == '1st Year' ? 'C-26 Regulation' : 'C-23 Regulation';
        Navigator.push(context, MaterialPageRoute(builder: (_) => HodSyllabusYearDetailsScreen(
          courseId: courseId,
          courseName: courseName,
          year: year['label'] as String,
          userData: {
            ...widget.userData,
            if (widget.branchOverride != null) 'branch': widget.branchOverride,
          },
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
