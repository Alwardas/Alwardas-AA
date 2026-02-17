import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';

class FacultyAddSubjectScreen extends StatefulWidget {
  final List<dynamic> allCourses;
  final List<dynamic> existingSubjects;

  const FacultyAddSubjectScreen({
    super.key, 
    required this.allCourses, 
    required this.existingSubjects
  });

  @override
  _FacultyAddSubjectScreenState createState() => _FacultyAddSubjectScreenState();
}

class _FacultyAddSubjectScreenState extends State<FacultyAddSubjectScreen> {
  // Dropdown Values
  String? _selectedBranch;
  String? _selectedYear;
  String? _selectedSection;
  
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _subjectCodeController = TextEditingController();
  
  bool _isLoading = false;
  List<String> _sections = [];
  List<Map<String, dynamic>> _filteredSubjects = [];

  // Options matching Schedule Page
  final List<String> _branches = ["CME", "EEE", "ECE", "MEC", "CIV"];
  final List<String> _years = ["1st Year", "2nd Year", "3rd Year"];

  @override
  void initState() {
    super.initState();
    // Pre-select if possible, e.g. from user session
    _loadFacultyDefault();
  }

  Future<void> _loadFacultyDefault() async {
      final user = await AuthService.getUserSession();
      if (user != null && _selectedBranch == null) {
          setState(() {
              _selectedBranch = _mapFullToShort(user['branch']);
          });
          // Initiate fetch if branch is set
          _updateSubjects();
      }
  }

  String _mapFullToShort(String? full) {
      if (full == null) return "CME";
      if (full.contains("Computer")) return "CME";
      if (full.contains("Electrical")) return "EEE";
      if (full.contains("Electronics")) return "ECE";
      if (full.contains("Mechanical")) return "MEC";
      if (full.contains("Civil")) return "CIV";
      return "CME";
  }

  String _mapShortToFull(String short) {
    switch (short) {
      case "CME": return "Computer Engineering";
      case "EEE": return "Electrical and Electronics Engineering";
      case "ECE": return "Electronics & Communication Engineering";
      case "MEC": return "Mechanical Engineering";
      case "CIV": return "Civil Engineering";
      default: return short;
    }
  }

  Future<void> _fetchSections() async {
    if (_selectedBranch == null || _selectedYear == null) return;
    
    setState(() => _isLoading = true);
    
    String fullBranch = _mapShortToFull(_selectedBranch!);
    
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/sections')
          .replace(queryParameters: {'branch': fullBranch, 'year': _selectedYear});
      
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _sections = data.map((e) => e.toString()).toList();
            // Reset section if not in new list
            if (_selectedSection != null && !_sections.contains(_selectedSection)) {
               _selectedSection = null;
            }
            // Auto Select if only one (optional, user asked for fetch)
            if (_sections.isNotEmpty && _selectedSection == null) {
               _selectedSection = _sections.first;
            }
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching sections: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _updateSubjects() {
      if (_selectedBranch == null || _selectedYear == null) {
          setState(() => _filteredSubjects = []);
          return;
      }
      
      final fullBranch = _mapShortToFull(_selectedBranch!);
      
      // Filter logic: Match Branch AND Year (mapped to semesters)
      final List<String> targetSemesters = [];
      if (_selectedYear == "1st Year") {
          targetSemesters.addAll(["1st Year", "1", "2", "Semester 1", "Semester 2"]);
      } else if (_selectedYear == "2nd Year") {
          targetSemesters.addAll(["3rd Semester", "4th Semester", "3", "4"]);
      } else if (_selectedYear == "3rd Year") {
          targetSemesters.addAll(["5th Semester", "6th Semester", "5", "6"]);
       } else if (_selectedYear == "4th Year") {
          targetSemesters.addAll(["7th Semester", "8th Semester", "7", "8"]);
      }

      final filtered = widget.allCourses.where((c) {
          final b = c['branch'] ?? '';
          final s = c['semester']?.toString() ?? '';
          
          bool branchMatch = b == fullBranch || b.contains(fullBranch); // Simple match
          if (!branchMatch && _selectedBranch == "CME" && b.contains("Computer")) branchMatch = true; 
          
          if (!branchMatch) return false;

          // Check semester
          // Normalize s
          String semCheck = s;
          if (s.toLowerCase().contains("1st year")) semCheck = "1st Year";
          // We can just rely on basic string match vs our target list
          bool semMatch = targetSemesters.any((ts) => s.toLowerCase().contains(ts.toLowerCase()));
          
          return semMatch;
      }).map((e) => e as Map<String, dynamic>).toList();

      setState(() {
          _filteredSubjects = filtered;
      });
  }

  void _onBranchChanged(String? val) {
      setState(() {
          _selectedBranch = val;
          _selectedSection = null;
          _sections = []; 
          _subjectController.clear();
          _subjectCodeController.clear();
      });
      _fetchSections();
      _updateSubjects();
  }

  void _onYearChanged(String? val) {
      setState(() {
          _selectedYear = val;
          _selectedSection = null; 
          _subjectController.clear();
          _subjectCodeController.clear();
      });
      _fetchSections();
      _updateSubjects();
  }

  void _submit() {
      if (_selectedBranch == null || _selectedYear == null || _selectedSection == null || _subjectController.text.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
          return;
      }
      
      String subjectId = _subjectCodeController.text;
      String subjectName = _subjectController.text;
      String? code;

      // Try to find the full object for more details
      final match = _filteredSubjects.firstWhere(
          (s) => s['name'] == subjectName || s['id'].toString() == subjectId,
          orElse: () => <String, dynamic>{}
      );

      if (match.isNotEmpty) {
         subjectId = match['id'].toString();
         subjectName = match['name'] ?? subjectName;
         code = match['code']?.toString();
      }
      
      if (subjectId.isEmpty) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a valid subject from the list")));
         return;
      }

      // Return List of Maps as expected by FacultyClassesScreen
      final result = [{
        'id': subjectId,
        'name': subjectName,
        'code': code ?? subjectId,
        'branch': _mapShortToFull(_selectedBranch!),
        'year': _selectedYear,
        'section': _selectedSection
      }];

      Navigator.pop(context, result);
  }

  @override
  Widget build(BuildContext context) {
    // Theme
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final bgColor = isDark ? ThemeColors.darkBackground.first : ThemeColors.lightBackground.first;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Add Subject",
          style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Dropdowns Row
             Row(
               children: [
                 Expanded(child: _buildDropdown("Branch", _branches, _selectedBranch, _onBranchChanged, tint, textColor, cardColor)),
                 const SizedBox(width: 10),
                 Expanded(child: _buildDropdown("Year", _years, _selectedYear, _onYearChanged, tint, textColor, cardColor)),
               ],
             ),
             const SizedBox(height: 20),
             // Section Row (full width potentially or shorter)
             _buildDropdown("Section", _sections, _selectedSection, (val) => setState(() => _selectedSection = val), tint, textColor, cardColor),
            
            const SizedBox(height: 30),
            
            // Subject Autocomplete
            Text("Select Subject", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
            const SizedBox(height: 10),
            
            Autocomplete<Map<String, dynamic>>(
               displayStringForOption: (option) => option['name'] ?? '',
               optionsBuilder: (TextEditingValue textEditingValue) {
                 if (_selectedBranch == null || _selectedYear == null) return const Iterable<Map<String, dynamic>>.empty();
                 if (textEditingValue.text == '') return _filteredSubjects;
                 
                 return _filteredSubjects.where((option) {
                    final name = option['name'].toString().toLowerCase();
                    final code = option['code'].toString().toLowerCase();
                    final input = textEditingValue.text.toLowerCase();
                    return name.contains(input) || code.contains(input);
                 });
               },
               onSelected: (selection) {
                  setState(() {
                     _subjectController.text = selection['name'];
                     _subjectCodeController.text = selection['id'].toString();
                  });
               },
               fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                   if (controller.text.isEmpty && _subjectController.text.isNotEmpty) {
                      controller.text = _subjectController.text;
                   }
                   return TextField(
                     controller: controller,
                     focusNode: focusNode,
                     onChanged: (val) {
                        _subjectController.text = val;
                        // Clear code if manual typing
                        if (_subjectCodeController.text.isNotEmpty) {
                           // potentially check if valid match still exists
                        }
                     },
                     style: TextStyle(color: textColor),
                     decoration: InputDecoration(
                       hintText: _selectedYear == null ? "Select Year first..." : "Search subject...",
                       hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                       filled: true,
                       fillColor: cardColor,
                       border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tint.withOpacity(0.3))),
                       enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide(color: tint.withOpacity(0.3))),
                       prefixIcon: Icon(Icons.search, color: tint),
                       suffixIcon: _subjectController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () {
                          controller.clear();
                          setState(() {
                             _subjectController.clear();
                             _subjectCodeController.clear();
                          });
                       }) : null,
                     ),
                   );
               },
               optionsViewBuilder: (context, onSelected, options) {
                  return Align(
                    alignment: Alignment.topLeft,
                    child: Material(
                      elevation: 4.0,
                      color: cardColor,
                      borderRadius: BorderRadius.circular(10),
                      child: ConstrainedBox(
                        constraints: BoxConstraints(maxHeight: 250, maxWidth: MediaQuery.of(context).size.width - 40),
                        child: ListView.builder(
                          padding: EdgeInsets.zero,
                          shrinkWrap: true,
                          itemCount: options.length,
                          itemBuilder: (BuildContext context, int index) {
                            final option = options.elementAt(index);
                            
                            // CHECK DUPLICATES: Only if Section matches!
                            // Allows adding same subject to valid different sections (A vs B)
                            final isAlreadyAdded = widget.existingSubjects.any((existing) {
                                // ID Match
                                final exId = existing['subject_id']?.toString() ?? existing['id']?.toString();
                                final optId = option['id'].toString();
                                if (exId != optId) return false;
                                
                                // Section Match
                                var exSection = existing['section']?.toString() ?? '';
                                var curSection = _selectedSection ?? '';
                                
                                if (curSection.isEmpty) return false; 
                                
                                // Normalize: "Section A" -> "a", "A" -> "a"
                                exSection = exSection.toLowerCase().replaceAll('section', '').replaceAll(':', '').trim();
                                curSection = curSection.toLowerCase().replaceAll('section', '').replaceAll(':', '').trim();
                                
                                return exSection == curSection;
                            });
                            
                            return InkWell(
                              onTap: isAlreadyAdded ? null : () => onSelected(option),
                              child: Container(
                                padding: const EdgeInsets.all(12.0),
                                decoration: BoxDecoration(border: Border(bottom: BorderSide(color: textColor.withOpacity(0.05)))),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: tint.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                      child: Text(option['code'] ?? option['id'], style: TextStyle(color: tint, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: Text(
                                        option['name'], 
                                        style: TextStyle(
                                          color: isAlreadyAdded ? subTextColor : textColor, 
                                          fontWeight: FontWeight.bold,
                                          decoration: isAlreadyAdded ? TextDecoration.lineThrough : null
                                        )
                                      ),
                                    ),
                                    if (isAlreadyAdded) Icon(Icons.check, size: 16, color: subTextColor),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
               },
            ),
            
            if (_subjectCodeController.text.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Text("Selected Code: ${_subjectCodeController.text}", style: TextStyle(color: tint, fontSize: 12, fontWeight: FontWeight.bold)),
              ),

             const SizedBox(height: 40),
             
             SizedBox(
               width: double.infinity,
               child: ElevatedButton(
                 onPressed: _submit,
                 style: ElevatedButton.styleFrom(
                   backgroundColor: tint,
                   padding: const EdgeInsets.symmetric(vertical: 16),
                   shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                   elevation: 5,
                   shadowColor: tint.withOpacity(0.4),
                 ),
                 child: Text("Add Subject", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
               ),
             )
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, Function(String?) onChanged, Color tint, Color textColor, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: textColor, fontWeight: FontWeight.w500)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tint.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: cardColor,
              icon: Icon(Icons.arrow_drop_down, color: tint),
              hint: Text("Select", style: TextStyle(fontSize: 12, color: textColor.withOpacity(0.5))),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, style: TextStyle(color: textColor, fontSize: 14), overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
