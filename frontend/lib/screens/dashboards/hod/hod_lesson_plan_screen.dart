import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';

class HodLessonPlanScreen extends StatefulWidget {
  final String subjectId;

  const HodLessonPlanScreen({super.key, required this.subjectId});

  @override
  _HodLessonPlanScreenState createState() => _HodLessonPlanScreenState();
}

class _HodLessonPlanScreenState extends State<HodLessonPlanScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  String? _togglingId;

  @override
  void initState() {
    super.initState();
    _fetchLessonPlan();
  }

  Future<void> _fetchLessonPlan() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/student/lesson-plan?subjectId=${widget.subjectId}'));
      if (response.statusCode == 200) {
        setState(() {
          _data = json.decode(response.body);
          _loading = false;
        });
      }
    } catch (e) {
      print("Error fetching lesson plan: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleToggleItem(Map<String, dynamic> item) async {
    if (item['type'] != 'TOPIC') return;
    if (_togglingId != null) return;

    final itemId = item['id'].toString();
    setState(() => _togglingId = itemId);

    final newState = !(item['completed'] ?? false);
    final newDate = newState ? DateTime.now().toIso8601String().split('T')[0] : null;

    // Optimistic Update
    final originalData = json.decode(json.encode(_data));
    setState(() {
      final items = _data!['items'] as List<dynamic>;
      _data!['items'] = items.map((i) {
        if (i['id'].toString() == itemId) {
          return {...i, 'completed': newState, 'completedDate': newDate};
        }
        return i;
      }).toList();
    });

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/faculty/lesson-plan/complete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'itemId': itemId, 'completed': newState}),
      );

      if (response.statusCode != 200) {
        throw Exception('Failed to toggle');
      }
      // Success, maybe refetch to get updated percentages
      _fetchLessonPlan();
    } catch (e) {
      print("Toggle error: $e");
      setState(() => _data = originalData);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update status.")));
    } finally {
      setState(() => _togglingId = null);
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
        title: Text("Lesson Plan", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(20),
                  children: [
                    _buildHeaderCard(cardColor, textColor, subTextColor, tint, iconBg),
                    const SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text("TOPICS TO COVER", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: subTextColor, letterSpacing: 1.2)),
                        Text("Tap to mark complete", style: GoogleFonts.poppins(fontSize: 11, color: subTextColor)),
                      ],
                    ),
                    const SizedBox(height: 10),
                    ...(_data?['items'] as List<dynamic>? ?? []).map((item) => _buildLessonItem(item, cardColor, textColor, subTextColor, tint, iconBg)).toList(),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildHeaderCard(Color cardColor, Color textColor, Color subTextColor, Color tint, Color iconBg) {
    if (_data == null) return const SizedBox();

    final percentage = _data!['percentage'] as int;
    final status = _data!['status'] as String;
    final warning = _data!['warning'] as String?;

    Color statusColor;
    Color statusBg;

    if (status == 'LAGGING') {
      statusColor = Colors.red;
      statusBg = Colors.red.withOpacity(0.1);
    } else if (status == 'OVERFAST') {
      statusColor = Colors.orange;
      statusBg = Colors.orange.withOpacity(0.1);
    } else {
      statusColor = Colors.green;
      statusBg = Colors.green.withOpacity(0.1);
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: iconBg)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${widget.subjectId} Plan", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: statusBg, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(status == 'NORMAL' ? Icons.check_circle : Icons.error, color: statusColor, size: 16),
                      const SizedBox(width: 6),
                      Text(status == 'NORMAL' ? 'On Track' : status, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: statusColor)),
                    ],
                  ),
                ),
                if (warning != null) ...[
                  const SizedBox(height: 8),
                  Text(warning, style: GoogleFonts.poppins(fontSize: 12, color: statusColor, fontWeight: FontWeight.w500)),
                ]
              ],
            ),
          ),
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(width: 70, height: 70, child: CircularProgressIndicator(value: percentage / 100, strokeWidth: 4, backgroundColor: iconBg, valueColor: AlwaysStoppedAnimation(statusColor))),
              Column(mainAxisSize: MainAxisSize.min, children: [Text("$percentage%", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)), Text("Done", style: GoogleFonts.poppins(fontSize: 10, color: subTextColor))]),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLessonItem(dynamic item, Color cardColor, Color textColor, Color subTextColor, Color tint, Color iconBg) {
    final type = item['type'] as String;

    if (type == 'UNIT') {
      return Padding(
        padding: const EdgeInsets.only(top: 15, bottom: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          decoration: BoxDecoration(color: tint.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text(item['text'], style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: tint)),
        ),
      );
    }

    if (type == 'UNIT_END') return const SizedBox(height: 10);

    final completed = item['completed'] == true;
    final isProcessing = _togglingId == item['id'].toString();

    return GestureDetector(
      onTap: isProcessing ? null : () => _handleToggleItem(item),
      child: Container(
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
        decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: iconBg.withOpacity(0.5))),
        child: Row(
          children: [
            SizedBox(
              width: 40,
              child: isProcessing
                  ? const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)))
                  : Icon(completed ? Icons.check_box : Icons.check_box_outline_blank, color: completed ? Colors.green : subTextColor, size: 24),
            ),
            SizedBox(width: 30, child: Center(child: Text(item['sno'] ?? '', style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: subTextColor)))),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item['topic'] ?? '',
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: textColor,
                        decoration: completed ? TextDecoration.lineThrough : null,
                        decorationColor: subTextColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        if (item['targetDate'] != null)
                          Text("Target: ${DateTime.parse(item['targetDate']).day}/${DateTime.parse(item['targetDate']).month}", style: GoogleFonts.poppins(fontSize: 10, color: subTextColor)),
                        if (item['completedDate'] != null) ...[
                          const SizedBox(width: 10),
                          Text("Done: ${item['completedDate']}", style: GoogleFonts.poppins(fontSize: 10, color: Colors.green)),
                        ]
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
}
