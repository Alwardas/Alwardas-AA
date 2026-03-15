import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/api_constants.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/services/auth_service.dart';

class HodMasterTimetableScreen extends StatefulWidget {
  final String branch;

  const HodMasterTimetableScreen({super.key, required this.branch});

  @override
  _HodMasterTimetableScreenState createState() => _HodMasterTimetableScreenState();
}

class _HodMasterTimetableScreenState extends State<HodMasterTimetableScreen> {
  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  late String _selectedDay;
  bool _isLoading = false;
  
  List<dynamic> _rows = [];
  List<dynamic> _labRows = [];
  List<dynamic> _clashes = [];

  @override
  void initState() {
    super.initState();
    int weekday = DateTime.now().weekday;
    if (weekday > 6) weekday = 1;
    _selectedDay = _days[weekday - 1];
    _fetchMasterTimetable();
  }

  Future<void> _fetchMasterTimetable() async {
    setState(() => _isLoading = true);
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/hod/master-timetable').replace(queryParameters: {
        'branch': widget.branch,
        'day': _selectedDay,
      });

      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _rows = data['rows'] ?? [];
            _labRows = data['labRows'] ?? [];
            _clashes = data['facultyClashes'] ?? [];
            _isLoading = false;
          });
        }
      } else {
        if (mounted) setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Master Timetable Fetch Error: $e");
      if (mounted) setState(() => _isLoading = false);
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
        title: Text("Master Timetable", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Column(
            children: [
              // Day Selector
              _buildDaySelector(isDark, textColor, tint, iconBg),
              
              if (_clashes.isNotEmpty) _buildClashWarning(isDark),

              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : _rows.isEmpty && _labRows.isEmpty
                    ? _buildEmptyState(textColor, subTextColor, tint)
                    : SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (_rows.isNotEmpty) ...[
                              _buildSectionHeader("Classes (Year & Section)", textColor),
                              _buildTimetableGrid(_rows, cardColor, textColor, subTextColor, tint, iconBg),
                              const SizedBox(height: 30),
                            ],
                            if (_labRows.isNotEmpty) ...[
                              _buildSectionHeader("Computer Labs", textColor),
                              _buildTimetableGrid(_labRows, cardColor, textColor, subTextColor, tint, iconBg),
                              const SizedBox(height: 30),
                            ],
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

  Widget _buildSectionHeader(String title, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Text(
        title,
        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
      ),
    );
  }

  Widget _buildDaySelector(bool isDark, Color textColor, Color tint, Color iconBg) {
    return Container(
      height: 60,
      margin: const EdgeInsets.symmetric(vertical: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: _days.length,
        itemBuilder: (context, index) {
          final day = _days[index];
          final isSelected = day == _selectedDay;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(day, style: GoogleFonts.poppins(color: isSelected ? Colors.white : textColor, fontSize: 13, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal)),
              selected: isSelected,
              onSelected: (selected) {
                if (selected) {
                  setState(() => _selectedDay = day);
                  _fetchMasterTimetable();
                }
              },
              selectedColor: tint,
              backgroundColor: iconBg,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              side: BorderSide.none,
              showCheckmark: false,
            ),
          );
        },
      ),
    );
  }

  Widget _buildClashWarning(bool isDark) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 20),
              const SizedBox(width: 8),
              Text("Faculty Timetable Conflict", style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 14)),
            ],
          ),
          const SizedBox(height: 8),
          ..._clashes.map((c) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text(
              "• ${c['facultyName']} is assigned to ${c['classes'].join(', ')} in Period ${c['periodIndex'] + 1}",
              style: GoogleFonts.poppins(color: Colors.red, fontSize: 12),
            ),
          )).toList(),
        ],
      ),
    );
  }

  Widget _buildTimetableGrid(List<dynamic> rows, Color cardColor, Color textColor, Color subTextColor, Color tint, Color iconBg) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: iconBg),
        ),
        child: DataTable(
          columnSpacing: 25,
          headingRowColor: WidgetStateProperty.all(tint.withValues(alpha: 0.05)),
          columns: [
            DataColumn(label: _headerText("Name", textColor)),
            ...List.generate(8, (i) => DataColumn(label: _headerText("P${i + 1}", textColor))),
          ],
          rows: rows.map((row) {
            return DataRow(cells: [
              DataCell(Text(row['className'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 13))),
              ... (row['periods'] as List).map((p) => DataCell(_buildCell(p, textColor, subTextColor))),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  Widget _headerText(String text, Color color) {
    return Text(text, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: color, fontSize: 14));
  }

  Widget _buildCell(dynamic period, Color textColor, Color subTextColor) {
    if (period == null) {
      return Center(child: Text("-", style: GoogleFonts.poppins(color: subTextColor.withValues(alpha: 0.5))));
    }
    return Container(
      constraints: const BoxConstraints(maxWidth: 120),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(period['subject'] ?? "Unknown", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis),
          Text(period['facultyName'] ?? "N/A", style: GoogleFonts.poppins(color: subTextColor, fontSize: 10), overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color textColor, Color subTextColor, Color tint) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.table_rows_outlined, size: 80, color: tint.withValues(alpha: 0.2)),
          const SizedBox(height: 20),
          Text("No Schedule Found", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          Text("Timetable for $_selectedDay is not assigned.", style: GoogleFonts.poppins(color: subTextColor, fontSize: 14)),
        ],
      ),
    );
  }
}
