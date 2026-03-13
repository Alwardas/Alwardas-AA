import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';

class HodAddSubjectScreen extends StatefulWidget {
  final List<dynamic> allCourses;
  final List<dynamic> existingSubjects;

  const HodAddSubjectScreen({
    super.key,
    required this.allCourses,
    required this.existingSubjects,
  });

  @override
  _HodAddSubjectScreenState createState() => _HodAddSubjectScreenState();
}

class _HodAddSubjectScreenState extends State<HodAddSubjectScreen> {
  String? _selectedBranch;
  String? _selectedYear;
  String? _selectedSection;
  String? _selectedSubject;

  List<String> _branches = [];
  final List<String> _years = ["1st Year", "2nd Year", "3rd Year"];
  List<String> _sections = [];
  List<String> _subjects = [];

  bool _loadingBranches = true;
  bool _loadingSections = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

  Future<void> _fetchBranches() async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.hodGetDepartments));
      if (response.statusCode == 200) {
        setState(() {
          _branches = List<String>.from(json.decode(response.body));
          _loadingBranches = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching branches: $e");
      setState(() => _loadingBranches = false);
    }
  }

  Future<void> _fetchSections() async {
    if (_selectedBranch == null || _selectedYear == null) return;
    setState(() {
      _loadingSections = true;
      _selectedSection = null;
      _sections = [];
    });
    try {
      final response = await http.get(
        Uri.parse("${ApiConstants.baseUrl}/api/sections?branch=$_selectedBranch&year=$_selectedYear"),
      );
      if (response.statusCode == 200) {
        setState(() {
          final List<dynamic> data = json.decode(response.body);
          _sections = data.map((e) => e.toString()).toList();
          _loadingSections = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching sections: $e");
      setState(() => _loadingSections = false);
    }
  }

  void _filterSubjectsLocally() {
    if (_selectedBranch == null || _selectedYear == null) {
      setState(() => _subjects = []);
      return;
    }

    final targetSems = [];
    if (_selectedYear == "1st Year") targetSems.addAll(["1", "2", "Semester 1", "Semester 2", "1st Year"]);
    else if (_selectedYear == "2nd Year") targetSems.addAll(["3", "4", "Semester 3", "Semester 4"]);
    else if (_selectedYear == "3rd Year") targetSems.addAll(["5", "6", "Semester 5", "Semester 6"]);

    final filtered = widget.allCourses.where((c) {
      final b = c['branch'] ?? '';
      final s = c['semester']?.toString() ?? '';
      
      bool branchMatch = b == _selectedBranch || b.contains(_selectedBranch!);
      if (!branchMatch) return false;

      bool semMatch = targetSems.any((ts) => s.toLowerCase().contains(ts.toLowerCase()));
      return semMatch;
    }).map((e) => e['name'].toString()).toSet().toList(); // Unique names

    setState(() {
      _subjects = filtered;
      _selectedSubject = null;
    });
  }

  Future<void> _addSubject() async {
    if (_selectedBranch == null || _selectedYear == null || _selectedSection == null || _selectedSubject == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields."), backgroundColor: Colors.orange),
      );
      return;
    }

    final user = await AuthService.getUserSession();
    if (user == null) return;

    setState(() => _submitting = true);

    // Find subject code from filtered subjects
    String subjectCode = "";
    final match = widget.allCourses.firstWhere(
      (c) => c['name'] == _selectedSubject,
      orElse: () => null,
    );
    if (match != null) {
      subjectCode = match['code']?.toString() ?? "";
    }
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.hodCourseSubjects),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "branch": _selectedBranch,
          "year": _selectedYear,
          "section": _selectedSection,
          "subjectName": _selectedSubject,
          "subjectCode": subjectCode,
          "createdBy": user['id'],
        }),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Subject added successfully."), backgroundColor: Colors.green),
          );
          Navigator.pop(context, true);
        }
      } else if (response.statusCode == 409) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Subject already assigned."), backgroundColor: Colors.red),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Failed to add subject."), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      debugPrint("Error adding subject: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Network error."), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Add Subject", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildHeader(tint, textColor, subTextColor),
                const SizedBox(height: 32),
                _buildSelectionCard(cardColor, textColor, subTextColor, tint),
                const SizedBox(height: 32),
                _buildSubmitButton(tint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader(Color tint, Color textColor, Color subTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: tint.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
          child: Icon(Icons.menu_book_rounded, color: tint, size: 32),
        ),
        const SizedBox(height: 16),
        Text("Manage Courses", style: GoogleFonts.poppins(fontSize: 28, fontWeight: FontWeight.bold, color: textColor)),
        Text("Configure subjects for different branches and sections.", style: GoogleFonts.poppins(fontSize: 14, color: subTextColor)),
      ],
    );
  }

  Widget _buildSelectionCard(Color cardColor, Color textColor, Color subTextColor, Color tint) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 20, offset: const Offset(0, 10))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildDropdownLabel("Branch", Icons.account_tree_outlined, tint, textColor),
          _buildDropdown(
            value: _selectedBranch,
            items: _branches,
            hint: "Select Branch",
            loading: _loadingBranches,
            onChanged: (v) {
              setState(() => _selectedBranch = v);
              _fetchSections();
              _filterSubjectsLocally();
            },
            textColor: textColor,
            tint: tint,
          ),
          const SizedBox(height: 20),
          _buildDropdownLabel("Year", Icons.calendar_today_outlined, tint, textColor),
          _buildDropdown(
            value: _selectedYear,
            items: _years,
            hint: "Select Year",
            onChanged: (v) {
              setState(() => _selectedYear = v);
              _fetchSections();
              _filterSubjectsLocally();
            },
            textColor: textColor,
            tint: tint,
          ),
          const SizedBox(height: 20),
          _buildDropdownLabel("Section", Icons.grid_view_outlined, tint, textColor),
          _buildDropdown(
            value: _selectedSection,
            items: _sections,
            hint: "Select Section",
            loading: _loadingSections,
            enabled: _selectedBranch != null && _selectedYear != null,
            onChanged: (v) => setState(() => _selectedSection = v),
            textColor: textColor,
            tint: tint,
          ),
          const SizedBox(height: 32),
          const Divider(),
          const SizedBox(height: 24),
          _buildDropdownLabel("Select Subject", Icons.library_books_outlined, tint, textColor),
          _buildSearchableSelector(
            value: _selectedSubject,
            items: _subjects,
            hint: "Select Subject",
            enabled: _selectedBranch != null && _selectedYear != null,
            onTap: () => _showSearchableModal(context, "Select Subject", _subjects, (val) {
              setState(() => _selectedSubject = val);
            }, textColor, cardColor, tint),
            textColor: textColor,
            tint: tint,
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---

  Widget _buildDropdownLabel(String label, IconData icon, Color tint, Color textColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: tint),
          const SizedBox(width: 8),
          Text(label, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String? value,
    required List<String> items,
    required String hint,
    required void Function(String?) onChanged,
    required Color textColor,
    required Color tint,
    bool loading = false,
    bool enabled = true,
  }) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: tint.withValues(alpha: 0.2)),
        color: enabled ? Colors.transparent : Colors.grey.withValues(alpha: 0.1),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          hint: loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : Text(hint, style: GoogleFonts.poppins(color: textColor.withValues(alpha: 0.5), fontSize: 14)),
          isExpanded: true,
          icon: Icon(Icons.keyboard_arrow_down_rounded, color: tint),
          dropdownColor: Theme.of(context).cardColor,
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: GoogleFonts.poppins(color: textColor, fontSize: 14)),
            );
          }).toList(),
          onChanged: enabled ? onChanged : null,
        ),
      ),
    );
  }

  Widget _buildSearchableSelector({
    required String? value,
    required List<String> items,
    required String hint,
    required VoidCallback onTap,
    required Color textColor,
    required Color tint,
    bool enabled = true,
  }) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tint.withValues(alpha: 0.2)),
          color: enabled ? Colors.transparent : Colors.grey.withValues(alpha: 0.1),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                value ?? hint,
                style: GoogleFonts.poppins(color: value != null ? textColor : textColor.withValues(alpha: 0.5), fontSize: 14),
              ),
            ),
            Icon(Icons.search, size: 20, color: tint),
          ],
        ),
      ),
    );
  }

  Widget _buildSubmitButton(Color tint) {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: _submitting ? null : _addSubject,
        style: ElevatedButton.styleFrom(
          backgroundColor: tint,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          elevation: 0,
        ),
        child: _submitting ? const CircularProgressIndicator(color: Colors.white) : Text("Add Subject", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)),
      ),
    );
  }

  void _showSearchableModal(BuildContext context, String title, List<String> items, Function(String) onSelect, Color textColor, Color cardColor, Color tint) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _SearchContent(title: title, items: items, onSelect: onSelect, textColor: textColor, cardColor: cardColor, tint: tint),
    );
  }
}

class _SearchContent extends StatefulWidget {
  final String title;
  final List<String> items;
  final Function(String) onSelect;
  final Color textColor;
  final Color cardColor;
  final Color tint;

  const _SearchContent({required this.title, required this.items, required this.onSelect, required this.textColor, required this.cardColor, required this.tint});

  @override
  __SearchContentState createState() => __SearchContentState();
}

class __SearchContentState extends State<_SearchContent> {
  late List<String> filteredItems;
  String query = "";

  @override
  void initState() {
    super.initState();
    filteredItems = widget.items;
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Container(
      height: MediaQuery.of(context).size.height * 0.7 + bottomInset,
      padding: EdgeInsets.only(bottom: bottomInset),
      decoration: BoxDecoration(color: widget.cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(24))),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey.withValues(alpha: 0.3), borderRadius: BorderRadius.circular(2))),
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(widget.title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: widget.textColor)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24.0),
            child: TextField(
              autofocus: true,
              style: GoogleFonts.poppins(color: widget.textColor),
              decoration: InputDecoration(
                hintText: "Search...",
                hintStyle: GoogleFonts.poppins(color: widget.textColor.withValues(alpha: 0.5)),
                prefixIcon: Icon(Icons.search, color: widget.tint),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.tint.withValues(alpha: 0.2))),
                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: widget.tint)),
              ),
              onChanged: (v) {
                setState(() {
                  query = v;
                  filteredItems = widget.items.where((i) => i.toLowerCase().contains(v.toLowerCase())).toList();
                });
              },
            ),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filteredItems.length,
              itemBuilder: (context, index) {
                return ListTile(
                  title: Text(filteredItems[index], style: GoogleFonts.poppins(color: widget.textColor)),
                  trailing: Icon(Icons.chevron_right, color: widget.tint.withValues(alpha: 0.3)),
                  onTap: () {
                    widget.onSelect(filteredItems[index]);
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
