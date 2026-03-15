
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/api_constants.dart';
import '../../../core/providers/theme_provider.dart';
import '../hod/hod_student_list_screen.dart';

class CoordinatorStudentsScreen extends StatefulWidget {
  const CoordinatorStudentsScreen({super.key});

  @override
  State<CoordinatorStudentsScreen> createState() => _CoordinatorStudentsScreenState();
}

class _CoordinatorStudentsScreenState extends State<CoordinatorStudentsScreen> {
  String? _selectedBranch;
  List<String> _branches = [];
  bool _isLoading = true;

  final List<String> _years = ['1st Year', '2nd Year', '3rd Year'];

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    try {
      final res = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/departments'));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _branches = data.map((d) => d['branch'].toString()).toList();
            if (_branches.isNotEmpty) _selectedBranch = _branches[0];
            _isLoading = false;
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (_) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF020617) : Colors.grey[50],
      appBar: AppBar(
        title: Text("Students", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator())
        : SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Select Branch",
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF1E293B) : Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade300),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<String>(
                      value: _selectedBranch,
                      isExpanded: true,
                      dropdownColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                      items: _branches.map((b) => DropdownMenuItem(value: b, child: Text(b, style: TextStyle(color: textColor)))).toList(),
                      onChanged: (val) => setState(() => _selectedBranch = val),
                    ),
                  ),
                ),
                const SizedBox(height: 30),
                Text(
                  "Select Year",
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                ),
                const SizedBox(height: 16),
                Column(
                  children: _years.map((year) => _buildYearCard(year, isDark, textColor)).toList(),
                ),
              ],
            ),
          ),
    );
  }

  Future<void> _showSectionSelection(String year) async {
    if (_selectedBranch == null) return;
    
    showDialog(
      context: context,
      builder: (context) {
        return Dialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: _SectionSelector(
            branch: _selectedBranch!,
            year: year,
            onSectionSelected: (section, allSections) {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HodStudentListScreen(
                    branch: _selectedBranch!,
                    year: year,
                    section: section,
                    allSections: allSections,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildYearCard(String year, bool isDark, Color textColor) {
    return GestureDetector(
      onTap: () => _showSectionSelection(year),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 15,
              offset: const Offset(0, 8),
            )
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54, // Fixed size for proper square look
              height: 54,
              decoration: BoxDecoration(
                color: const Color(0xFFE3F2FD), // Subtle Light Blue
                borderRadius: BorderRadius.circular(15), // Soft rounded square
              ),
              child: const Icon(Icons.people_alt, color: Color(0xFF2196F3), size: 28),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Text(
                year,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : const Color(0xFF1E293B),
                ),
              ),
            ),
            const Icon(Icons.chevron_right_rounded, color: Color(0xFFB0BEC5), size: 24),
          ],
        ),
      ),
    );
  }
}

class _SectionSelector extends StatefulWidget {
  final String branch;
  final String year;
  final Function(String, List<String>) onSectionSelected;

  const _SectionSelector({
    required this.branch,
    required this.year,
    required this.onSectionSelected,
  });

  @override
  State<_SectionSelector> createState() => _SectionSelectorState();
}

class _SectionSelectorState extends State<_SectionSelector> {
  List<String> _sections = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchSections();
  }

  Future<void> _fetchSections() async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/sections?branch=${Uri.encodeComponent(widget.branch)}&year=${widget.year}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _sections = data.map((e) => e.toString()).toList();
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (_) {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            "Select Section",
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 10),
          const Divider(),
          if (_loading)
            const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
          else if (_sections.isEmpty)
            Padding(
              padding: const EdgeInsets.all(30),
              child: Column(
                children: [
                  Icon(Icons.info_outline, size: 40, color: Colors.grey[400]),
                  const SizedBox(height: 10),
                  Text("No sections found for this year.", style: GoogleFonts.poppins(color: Colors.grey)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () => widget.onSectionSelected("All", ["All"]),
                    child: const Text("View All Students"),
                  )
                ],
              ),
            )
          else
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  ListTile(
                    leading: const Icon(Icons.groups_outlined, color: Colors.blue),
                    title: Text("All Sections", style: GoogleFonts.poppins(color: textColor)),
                    onTap: () => widget.onSectionSelected("All", _sections),
                  ),
                  ..._sections.map((s) => ListTile(
                    leading: const Icon(Icons.class_outlined, color: Colors.blue),
                    title: Text(s, style: GoogleFonts.poppins(color: textColor)),
                    onTap: () => widget.onSectionSelected(s, _sections),
                  )),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
