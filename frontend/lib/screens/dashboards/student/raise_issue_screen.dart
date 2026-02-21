import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api_constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class RaiseIssueScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const RaiseIssueScreen({super.key, required this.userData});

  @override
  _RaiseIssueScreenState createState() => _RaiseIssueScreenState();
}

class _RaiseIssueScreenState extends State<RaiseIssueScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  
  String? _selectedCategory;
  List<String> _selectedTargets = [];
  bool _isSubmitting = false;

  final List<String> _categories = ['Attendance', 'Marks', 'Academic', 'Other'];
  final List<String> _targets = ['HOD', 'Principal', 'Coordinator', 'Parent', 'Course Faculty', 'Branch Faculty'];

  // Dynamic Faculty Dropdown Support
  List<dynamic> _studentCourses = [];
  bool _isLoadingCourses = false;

  List<dynamic> _branchFaculties = [];
  bool _isLoadingBranchFaculties = false;
  
  // For multiple select
  List<String> _selectedFaculties = [];

  @override
  void initState() {
    super.initState();
    if (widget.userData['role'] == 'Student') {
      _fetchStudentCourses();
    }
    _fetchBranchFaculties();
  }

  Future<void> _fetchStudentCourses() async {
    final userId = widget.userData['id'];
    if (userId == null) return;

    setState(() => _isLoadingCourses = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.studentGetCourses}?userId=$userId'), // I need to verify if this endpoint mapping exists in ApiConstants. If not, I'll fallback to hardcoded or I'll patch ApiConstants
      );
      if (response.statusCode == 200) {
        setState(() {
          _studentCourses = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error fetching courses: $e");
    } finally {
      if (mounted) setState(() => _isLoadingCourses = false);
    }
  }

  Future<void> _fetchBranchFaculties() async {
    final branch = widget.userData['branch'] ?? 'All';

    setState(() => _isLoadingBranchFaculties = true);
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.facultyByBranch}?branch=$branch'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _branchFaculties = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error fetching branch faculties: $e");
    } finally {
      if (mounted) setState(() => _isLoadingBranchFaculties = false);
    }
  }

  Future<void> _submitIssue() async {
    if (!_formKey.currentState!.validate()) return;
    
    // Validate Target Selection
    if (_selectedTargets.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one target.")),
      );
      return;
    }

    // Validate Faculty Multiple Selection
    if ((_selectedTargets.contains('Course Faculty') || _selectedTargets.contains('Branch Faculty')) && _selectedFaculties.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select at least one faculty member.")),
      );
      return;
    }

    final userId = widget.userData['id'];
    if (userId == null) return;

    setState(() => _isSubmitting = true);

    // If Faculty selected, append names to the description so backend can see it implicitly inside Description or Category
    String finalDescription = _descriptionController.text;
    if (widget.userData['role'] == 'Student' && (_selectedTargets.contains('Course Faculty') || _selectedTargets.contains('Branch Faculty')) && _selectedFaculties.isNotEmpty) {
      finalDescription = 'Target Faculties: ${_selectedFaculties.join(", ")}\n\n$finalDescription';
    }

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.studentSubmitIssue),
        body: json.encode({
          'userId': userId,
          'subject': _titleController.text, 
          'description': finalDescription, 
          'category': _selectedCategory,
          'targetRole': _selectedTargets.join(', '),
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context, true); // true = refresh requested
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Issue reported successfully!", style: GoogleFonts.poppins()),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            )
          );
        }
      } else {
        throw Exception("Failed to submit");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to report issue. Please try again.", style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  // A simple build method for multiple selection chips for Course Faculty
  Widget _buildFacultyMultiSelect(Color cardColor, Color textColor, Color subTextColor) {
    if (_isLoadingCourses) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_studentCourses.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text("No courses/faculty found.", style: GoogleFonts.poppins(color: Colors.red)),
      );
    }

    // Extract unique faculty names
    final Set<String> uniqueFaculties = {};
    for (var course in _studentCourses) {
      final fname = course['facultyName'] ?? course['faculty_name'] ?? 'TBA';
      if (fname != 'TBA' && fname.toString().trim().isNotEmpty) {
        uniqueFaculties.add(fname.toString());
      }
    }

    if (uniqueFaculties.isEmpty) {
       return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text("No assignments found for your courses.", style: GoogleFonts.poppins(color: subTextColor)),
      );
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text("Select Course Faculty (Multiple Allowed)", style: GoogleFonts.poppins(color: subTextColor, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: uniqueFaculties.map((faculty) {
            final isSelected = _selectedFaculties.contains(faculty);
            return FilterChip(
              label: Text(faculty, style: GoogleFonts.poppins(color: isSelected ? Colors.white : textColor, fontSize: 13)),
              selected: isSelected,
              selectedColor: theme.primaryColor,
              backgroundColor: cardColor,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? theme.primaryColor : subTextColor.withOpacity(0.3)),
              ),
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    _selectedFaculties.add(faculty);
                  } else {
                    _selectedFaculties.remove(faculty);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  // A simple build method for multiple selection chips for Branch Faculty
  Widget _buildBranchFacultyMultiSelect(Color cardColor, Color textColor, Color subTextColor) {
    if (_isLoadingBranchFaculties) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 10),
        child: Center(child: CircularProgressIndicator()),
      );
    }

    if (_branchFaculties.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text("No branch faculties found.", style: GoogleFonts.poppins(color: Colors.red)),
      );
    }

    // Extract unique faculty names
    final Set<String> uniqueFaculties = {};
    for (var faculty in _branchFaculties) {
      final fname = faculty['fullName'] ?? faculty['full_name'] ?? 'Unknown';
      if (fname != 'Unknown' && fname.toString().trim().isNotEmpty) {
        uniqueFaculties.add(fname.toString());
      }
    }

    if (uniqueFaculties.isEmpty) {
       return Padding(
        padding: const EdgeInsets.symmetric(vertical: 10),
        child: Text("No faculties found in your branch.", style: GoogleFonts.poppins(color: subTextColor)),
      );
    }

    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Text("Select Branch Faculty (Multiple Allowed)", style: GoogleFonts.poppins(color: subTextColor, fontSize: 13)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8.0,
          runSpacing: 8.0,
          children: uniqueFaculties.map((faculty) {
            final isSelected = _selectedFaculties.contains(faculty);
            return FilterChip(
              label: Text(faculty, style: GoogleFonts.poppins(color: isSelected ? Colors.white : textColor, fontSize: 13)),
              selected: isSelected,
              selectedColor: theme.primaryColor,
              backgroundColor: cardColor,
              checkmarkColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
                side: BorderSide(color: isSelected ? theme.primaryColor : subTextColor.withOpacity(0.3)),
              ),
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    _selectedFaculties.add(faculty);
                  } else {
                    _selectedFaculties.remove(faculty);
                  }
                });
              },
            );
          }).toList(),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? AppTheme.darkBodyGradient : AppTheme.lightBodyGradient;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    final isStudent = widget.userData['role'] == 'Student';
    final targetList = isStudent 
      ? ['HOD', 'Principal', 'Coordinator', 'Parent', 'Course Faculty', 'Branch Faculty']
      : ['HOD', 'Principal', 'Coordinator'];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Raise Issue", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(20),
                 boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 4),
                    )
                  ]
              ),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Category Dropdown
                    DropdownButtonFormField<String>(
                      value: _selectedCategory,
                      decoration: InputDecoration(
                        labelText: "Category",
                        labelStyle: GoogleFonts.poppins(color: subTextColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                      ),
                      dropdownColor: cardColor,
                      style: GoogleFonts.poppins(color: textColor),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                      onChanged: (v) => setState(() => _selectedCategory = v),
                      validator: (v) => v == null ? "Select Category" : null,
                    ),
                    const SizedBox(height: 20),

                    // Target Multiple Selection Chips
                    const SizedBox(height: 10),
                    Text("Select Targets (Multiple Allowed)", style: GoogleFonts.poppins(color: subTextColor, fontSize: 13)),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8.0,
                      runSpacing: 8.0,
                      children: targetList.map((target) {
                        final isSelected = _selectedTargets.contains(target);
                        return FilterChip(
                          label: Text(target, style: GoogleFonts.poppins(color: isSelected ? Colors.white : textColor, fontSize: 13)),
                          selected: isSelected,
                          selectedColor: theme.primaryColor,
                          backgroundColor: cardColor,
                          checkmarkColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(20),
                            side: BorderSide(color: isSelected ? theme.primaryColor : subTextColor.withOpacity(0.3)),
                          ),
                          onSelected: (bool selected) {
                            setState(() {
                              if (selected) {
                                _selectedTargets.add(target);
                              } else {
                                _selectedTargets.remove(target);
                                // Clear faculty selections if all faculty targets are deselected
                                if (!_selectedTargets.contains('Course Faculty') && !_selectedTargets.contains('Branch Faculty')) {
                                   _selectedFaculties.clear();
                                }
                              }
                            });
                          },
                        );
                      }).toList(),
                    ),
                    const SizedBox(height: 20),
                    
                    // Dynamic Faculty Selection
                    if (_selectedTargets.contains('Course Faculty')) 
                      _buildFacultyMultiSelect(cardColor, textColor, subTextColor),
                      
                    if (_selectedTargets.contains('Branch Faculty'))
                      _buildBranchFacultyMultiSelect(cardColor, textColor, subTextColor),

                    if (!_selectedTargets.contains('Course Faculty') && !_selectedTargets.contains('Branch Faculty'))
                       const SizedBox(height: 5),

                    // Title TextField
                    TextFormField(
                      controller: _titleController,
                      style: GoogleFonts.poppins(color: textColor),
                      decoration: InputDecoration(
                        labelText: "Title",
                        labelStyle: GoogleFonts.poppins(color: subTextColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                      ),
                      validator: (v) => v == null || v.isEmpty ? "Enter title" : null,
                    ),
                    const SizedBox(height: 20),

                    // Description TextField
                    TextFormField(
                      controller: _descriptionController,
                      style: GoogleFonts.poppins(color: textColor),
                      maxLines: 5,
                      decoration: InputDecoration(
                        labelText: "Description",
                        alignLabelWithHint: true,
                        labelStyle: GoogleFonts.poppins(color: subTextColor),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white24 : Colors.black12)),
                      ),
                      validator: (v) => v == null || v.isEmpty ? "Enter description" : null,
                    ),
                    const SizedBox(height: 30),

                    // Submit Button
                    SizedBox(
                      width: double.infinity,
                      height: 55,
                      child: ElevatedButton(
                        onPressed: _isSubmitting ? null : _submitIssue,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: theme.primaryColor,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                          elevation: 2,
                        ),
                        child: _isSubmitting 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text("Submit Issue", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                    ),
                  ],
                ),
              )
            )
          ),
        ),
      ),
    );
  }
}
