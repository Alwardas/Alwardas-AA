
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
                GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    mainAxisExtent: 100,
                    mainAxisSpacing: 16,
                  ),
                  itemCount: _years.length,
                  itemBuilder: (context, index) {
                    return _buildYearCard(_years[index], isDark, textColor, subTextColor);
                  },
                ),
              ],
            ),
          ),
    );
  }

  Widget _buildYearCard(String year, bool isDark, Color textColor, Color subTextColor) {
    return GestureDetector(
      onTap: () {
        if (_selectedBranch == null) return;
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => HodStudentListScreen(
              branch: _selectedBranch!,
              year: year,
              section: "All", // Coordinator can view all sections
              allSections: const ["Section A", "Section B", "Section C"], // Mock for now
            ),
          ),
        );
      },
      child: Container(
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
          border: Border.all(color: isDark ? Colors.white10 : Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 80,
              decoration: BoxDecoration(
                color: const Color(0xFF2563EB).withValues(alpha: 0.1),
                borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
              ),
              child: const Icon(Icons.school_outlined, color: Color(0xFF2563EB), size: 32),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(year, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                  Text("View all students", style: GoogleFonts.poppins(fontSize: 13, color: subTextColor)),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: Colors.grey),
            const SizedBox(width: 16),
          ],
        ),
      ),
    );
  }
}
