import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Persistence
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/api_constants.dart';
import 'hod_student_list_screen.dart';

class HodYearSectionsScreen extends StatefulWidget {
  final Map<String, dynamic> yearData; // {year: "1st Year", sections: ["Section A", "Section B"]}
  final String branch;
  final Function(List<String>) onUpdateSections;

  const HodYearSectionsScreen({
    super.key, 
    required this.yearData, 
    required this.branch,
    required this.onUpdateSections
  });

  @override
  _HodYearSectionsScreenState createState() => _HodYearSectionsScreenState();
}

class _HodYearSectionsScreenState extends State<HodYearSectionsScreen> {
  late List<String> _sections;

  @override
  void initState() {
    super.initState();
    // Initialize immediately to prevent LateInitializationError during first build
    _sections = List<String>.from(widget.yearData['sections'] ?? []);
    _loadSections();
  }

  Future<void> _loadSections() async {
    // 1. Try fetching from backend
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/sections?branch=${Uri.encodeComponent(widget.branch)}&year=${widget.yearData['year']}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
           setState(() {
             _sections = data.map((e) => e.toString()).toList();
           });
           return;
        }
      }
    } catch (e) {
      debugPrint("API Fetch Error: $e");
    }

    // 2. Fallback to passed data or SharedPreferences (migration path)
    final prefs = await SharedPreferences.getInstance();
    final key = 'sections_${widget.branch}_${widget.yearData['year']}';
    List<String>? stored = prefs.getStringList(key);
    
    setState(() {
       _sections = stored ?? List<String>.from(widget.yearData['sections']);
       // If we loaded from local/default, let's sync to backend immediately if backend was empty?
       // optional.
    });
  }

  Future<void> _saveSections() async {
    // 1. Save locally (optimistic)
    final prefs = await SharedPreferences.getInstance();
    final key = 'sections_${widget.branch}_${widget.yearData['year']}';
    await prefs.setStringList(key, _sections);

    // 2. Save to Backend
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/sections/update');
      await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'branch': widget.branch,
          'year': widget.yearData['year'],
          'sections': _sections
        }),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to sync sections to cloud: $e")));
    }
  }

  void _addSection() {
    TextEditingController controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text('Add Section', style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: "Enter Section Name (e.g. Section C)",
              hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white54 : Colors.black54)),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  setState(() {
                    _sections.add(controller.text.trim());
                  });
                  _saveSections(); // Persist
                  widget.onUpdateSections(_sections); // Update parent
                  Navigator.pop(context);
                }
              },
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }

  void _renameSection(int index) {
    TextEditingController controller = TextEditingController(text: _sections[index]);
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text('Rename Section', style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black)),
          content: TextField(
            controller: controller,
            style: TextStyle(color: isDark ? Colors.white : Colors.black),
            decoration: InputDecoration(
              hintText: "Enter Section Name",
              hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.black54),
              enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: isDark ? Colors.white54 : Colors.black54)),
            ),
            autofocus: true,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              onPressed: () {
                if (controller.text.trim().isNotEmpty) {
                  final newName = controller.text.trim();
                  final oldName = _sections[index];
                  
                  if (newName != oldName) {
                      _performSectionRename(oldName, newName, index);
                  }
                  Navigator.pop(context);
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _performSectionRename(String oldName, String newName, int index) async {
    // Optimistic Update
    setState(() {
      _sections[index] = newName;
    });
    // We update parent immediately for UI response
    widget.onUpdateSections(_sections);

    // Call Backend
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/sections/rename');
      final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'branch': widget.branch,
            'year': widget.yearData['year'],
            'oldName': oldName,
            'newName': newName
          })
      );

      if (response.statusCode != 200) {
         // Revert on failure
         if (mounted) {
            setState(() {
              _sections[index] = oldName;
            });
            widget.onUpdateSections(_sections);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Rename failed: ${response.statusCode}")));
         }
      } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Section renamed & students migrated.")));
      }
    } catch (e) {
      debugPrint("Rename API Error: $e");
      if (mounted) {
         setState(() {
             _sections[index] = oldName;
         });
         widget.onUpdateSections(_sections);
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  Future<void> _deleteSection(int index) async {
    final sectionName = _sections[index];
    
    // Check for students
    List<String> studentIds = [];
    bool hasStudents = false;
    
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/students?branch=${Uri.encodeComponent(widget.branch)}&year=${widget.yearData['year']}&section=${Uri.encodeComponent(sectionName)}');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (data.isNotEmpty) {
           hasStudents = true;
           // Assuming login_id is key. Adapt if needed.
           studentIds = data.map((s) => s['login_id']?.toString() ?? s['id'].toString()).toList(); 
        }
      }
    } catch (e) {
       debugPrint("Error checking students: $e");
    }

    if (!mounted) return;

    if (!hasStudents) {
       _confirmDeleteEmpty(index);
    } else {
       _showMoveAndDeleteDialog(index, studentIds);
    }
  }

  void _confirmDeleteEmpty(int index) {
    showDialog(
      context: context,
      builder: (context) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return AlertDialog(
          backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          title: Text('Delete Section', style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black)),
          content: Text(
            'Are you sure you want to delete "${_sections[index]}"? This action cannot be undone.',
            style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black87),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context), 
              child: const Text('Cancel')
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
              onPressed: () {
                Navigator.pop(context);
                setState(() {
                  _sections.removeAt(index);
                });
                _saveSections(); // Persist
                widget.onUpdateSections(_sections);
              },
              child: const Text('Delete', style: TextStyle(color: Colors.white)),
            ),
          ],
        );
      },
    );
  }

  void _showMoveAndDeleteDialog(int index, List<String> studentIds) {
    final currentSection = _sections[index];
    final otherSections = _sections.where((s) => s != currentSection).toList();
    
    if (otherSections.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Cannot delete: Contains students and no other section to move to.")));
       return;
    }

    String targetSection = otherSections.first;
    // We use a local StateSetter for the dialog to update UI inside dialog
    
    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return AlertDialog(
            backgroundColor: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            title: Text('Section has Students', style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'This section contains ${studentIds.length} students. You must move them to another section before deleting.',
                  style: GoogleFonts.poppins(color: isDark ? Colors.white70 : Colors.black87),
                ),
                const SizedBox(height: 15),
                Text('Move to:', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: isDark ? Colors.white70 : Colors.black54)),
                DropdownButton<String>(
                  value: targetSection,
                  isExpanded: true,
                  dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                  items: otherSections.map((s) => DropdownMenuItem(value: s, child: Text(s, style: TextStyle(color: isDark ? Colors.white : Colors.black)))).toList(),
                  onChanged: (val) => setDialogState(() => targetSection = val!),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ElevatedButton(
                onPressed: () async {
                  
                  // 1. Move Students
                  try {
                    final url = Uri.parse('${ApiConstants.baseUrl}/api/students/move');
                    final response = await http.post(
                      url,
                      headers: {'Content-Type': 'application/json'},
                      body: json.encode({
                        'studentIds': studentIds,
                        'targetSection': targetSection,
                        'branch': widget.branch,
                        'year': widget.yearData['year']
                      }),
                    );
                    
                    if (response.statusCode == 200) {
                       // 2. Delete Section Locally & Save
                       if (mounted) {
                          Navigator.pop(ctx); // Close dialog
                          setState(() {
                             _sections.removeAt(index);
                          });
                          _saveSections(); 
                          widget.onUpdateSections(_sections);
                          
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Moved students to $targetSection & deleted $currentSection")));
                       }
                    } else {
                       if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to move: ${response.statusCode}")));
                       }
                    }
                  } catch (e) {
                     if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Network Error: $e")));
                     }
                  }
                },
                child: const Text('Move & Delete'),
              )
            ],
          );
        }
      )
    );
  }

  void _navigateToStudentList(String section) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HodStudentListScreen(
          branch: widget.branch,
          year: widget.yearData['year'],
          section: section,
          allSections: _sections,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? AppTheme.darkBodyGradient : AppTheme.lightBodyGradient;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('${widget.yearData['year']} Sections', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: bgColors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      "Active Sections", 
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)
                    ),
                    ElevatedButton.icon(
                      onPressed: _addSection,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text("Add Section"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      ),
                    )
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: _sections.length,
                  itemBuilder: (ctx, index) {
                    final section = _sections[index];
                    return GestureDetector(
                      onTap: () => _navigateToStudentList(section),
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withOpacity(0.05) : Colors.white,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: Colors.grey.withOpacity(0.1)),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 5, offset: const Offset(0, 2))
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.1),
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(Icons.class_outlined, color: Colors.blueAccent),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                section, 
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)
                              ),
                            ),
                            PopupMenuButton<String>(
                              icon: Icon(Icons.more_vert, color: subTextColor),
                              onSelected: (value) {
                                if (value == 'rename') _renameSection(index);
                                if (value == 'delete') _deleteSection(index);
                              },
                              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                                const PopupMenuItem<String>(
                                  value: 'rename',
                                  child: Row(
                                    children: [
                                      Icon(Icons.edit, size: 18, color: Colors.blue),
                                      SizedBox(width: 10),
                                      Text('Rename'),
                                    ],
                                  ),
                                ),
                                const PopupMenuItem<String>(
                                  value: 'delete',
                                  child: Row(
                                    children: [
                                      Icon(Icons.delete, size: 18, color: Colors.red),
                                      SizedBox(width: 10),
                                      Text('Delete'),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
