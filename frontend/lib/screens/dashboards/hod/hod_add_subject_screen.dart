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
  
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _subjectIdController = TextEditingController();

  final List<String> _branches = ["Computer Engineering", "Electronics & Communication Engineering", "Electrical & Electronics Engineering", "Mechanical Engineering", "Civil Engineering"];
  final List<String> _years = ["1st Year", "2nd Year", "3rd Year"];
  List<String> _sections = [];
  List<Map<String, dynamic>> _filteredSubjects = [];

  bool _loadingSections = false;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadDefaults();
  }

  Future<void> _loadDefaults() async {
    final user = await AuthService.getUserSession();
    if (user != null) {
      String branch = user['branch'] ?? '';
      if (branch.isNotEmpty) {
        // Find match in our branches list
        final match = _branches.firstWhere((b) => b.toLowerCase().contains(branch.toLowerCase()), orElse: () => "");
        if (match.isNotEmpty) {
          setState(() => _selectedBranch = match);
          _updateSubjects();
        }
      }
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
          if (_sections.isNotEmpty) _selectedSection = _sections.first;
        });
      }
    } catch (e) {
      debugPrint("Error fetching sections: $e");
      setState(() => _loadingSections = false);
    }
  }

  void _updateSubjects() {
    if (_selectedBranch == null || _selectedYear == null) {
      setState(() => _filteredSubjects = []);
      return;
    }

    // Filter logic similar to faculty: Match Branch AND Year
    final filtered = widget.allCourses.where((c) {
      final b = c['branch'] ?? '';
      final s = c['semester']?.toString() ?? '';
      
      bool branchMatch = b == _selectedBranch || b.contains(_selectedBranch!);
      if (!branchMatch) return false;

      // Extract year from semester string if possible
      bool yearMatch = s.toLowerCase().contains(_selectedYear!.toLowerCase());
      if (!yearMatch) {
         // Fallback mapping for semesters
         if (_selectedYear == "1st Year") yearMatch = s == "1" || s == "2" || s.contains("Semester 1") || s.contains("Semester 2");
         else if (_selectedYear == "2nd Year") yearMatch = s == "3" || s == "4" || s.contains("Semester 3") || s.contains("Semester 4");
         else if (_selectedYear == "3rd Year") yearMatch = s == "5" || s == "6" || s.contains("Semester 5") || s.contains("Semester 6");
      }
      
      return yearMatch;
    }).map((e) => e as Map<String, dynamic>).toList();

    setState(() {
      _filteredSubjects = filtered;
    });
  }

  Future<void> _addSubject() async {
    final subjectName = _subjectController.text.trim();
    if (_selectedBranch == null || _selectedYear == null || _selectedSection == null || subjectName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please fill all fields."), backgroundColor: Colors.orange),
      );
      return;
    }

    final user = await AuthService.getUserSession();
    if (user == null) return;

    setState(() => _submitting = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.hodCourseSubjects),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "branch": _selectedBranch,
          "year": _selectedYear,
          "section": _selectedSection,
          "subjectName": subjectName,
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
                _buildSelectors(cardColor, textColor, tint),
                const SizedBox(height: 24),
                _buildSubjectSearch(cardColor, textColor, tint),
                const SizedBox(height: 32),
                _buildSubmitButton(tint),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectors(Color cardColor, Color textColor, Color tint) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(child: _buildDropdown("Branch", _branches, _selectedBranch, (val) {
                setState(() => _selectedBranch = val);
                _fetchSections();
                _updateSubjects();
              }, tint, textColor, cardColor)),
              const SizedBox(width: 12),
              Expanded(child: _buildDropdown("Year", _years, _selectedYear, (val) {
                setState(() => _selectedYear = val);
                _fetchSections();
                _updateSubjects();
              }, tint, textColor, cardColor)),
            ],
          ),
          const SizedBox(height: 16),
          _buildDropdown("Section", _sections, _selectedSection, (val) => setState(() => _selectedSection = val), tint, textColor, cardColor, loading: _loadingSections),
        ],
      ),
    );
  }

  Widget _buildSubjectSearch(Color cardColor, Color textColor, Color tint) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Search Subject", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 10),
        Autocomplete<Map<String, dynamic>>(
          displayStringForOption: (option) => option['name'] ?? '',
          optionsBuilder: (TextEditingValue textEditingValue) {
            if (_selectedBranch == null || _selectedYear == null) return const Iterable<Map<String, dynamic>>.empty();
            if (textEditingValue.text.isEmpty) return _filteredSubjects;
            return _filteredSubjects.where((option) {
              final name = option['name'].toString().toLowerCase();
              return name.contains(textEditingValue.text.toLowerCase());
            });
          },
          onSelected: (selection) {
            setState(() {
              _subjectController.text = selection['name'];
              _subjectIdController.text = selection['id'].toString();
            });
          },
          fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
            if (controller.text.isEmpty && _subjectController.text.isNotEmpty) {
              controller.text = _subjectController.text;
            }
            return TextField(
              controller: controller,
              focusNode: focusNode,
              onChanged: (val) => _subjectController.text = val,
              style: GoogleFonts.poppins(color: textColor),
              decoration: InputDecoration(
                hintText: _selectedYear == null ? "Select Year first..." : "Type to search subject...",
                hintStyle: GoogleFonts.poppins(color: textColor.withValues(alpha: 0.5)),
                filled: true,
                fillColor: cardColor,
                prefixIcon: Icon(Icons.search, color: tint),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
            );
          },
          optionsViewBuilder: (context, onSelected, options) {
            return Align(
              alignment: Alignment.topLeft,
              child: Material(
                elevation: 4,
                color: cardColor,
                borderRadius: BorderRadius.circular(15),
                child: ConstrainedBox(
                  constraints: BoxConstraints(maxHeight: 300, maxWidth: MediaQuery.of(context).size.width - 48),
                  child: ListView.builder(
                    padding: EdgeInsets.zero,
                    shrinkWrap: true,
                    itemCount: options.length,
                    itemBuilder: (context, index) {
                      final option = options.elementAt(index);
                      return ListTile(
                        title: Text(option['name'], style: GoogleFonts.poppins(color: textColor)),
                        onTap: () => onSelected(option),
                      );
                    },
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, Function(String?) onChanged, Color tint, Color textColor, Color cardColor, {bool loading = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: textColor.withValues(alpha: 0.7))),
        const SizedBox(height: 6),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: cardColor.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tint.withValues(alpha: 0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: cardColor,
              icon: loading ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)) : Icon(Icons.keyboard_arrow_down, color: tint),
              hint: Text("Select", style: GoogleFonts.poppins(fontSize: 13, color: textColor.withValues(alpha: 0.5))),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, style: GoogleFonts.poppins(color: textColor, fontSize: 13)),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
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
}
