import 'dart:convert';
import 'package:flutter/material.dart';
// For rootBundle
// Persistence
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../../core/services/auth_service.dart';
import '../../../core/api_constants.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';

class HodStudentListScreen extends StatefulWidget {
  final String branch;
  final String year;
  final String section;
  final List<String> allSections;

  const HodStudentListScreen({
    super.key, 
    required this.branch, 
    required this.year, 
    required this.section,
    required this.allSections
  });

  @override
  _HodStudentListScreenState createState() => _HodStudentListScreenState();
}

class _HodStudentListScreenState extends State<HodStudentListScreen> {
  List<dynamic> _studentList = [];
  bool _isLoading = true;
  String _searchQuery = '';
  
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  // STATIC CACHE for Moved Students (Simulates Backend Persistence in Session)
  static final Map<String, String> _movedStudentsCache = {};

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() => _isLoading = true);
    
    try {
      // 1. Fetch from API
      // Use branch from widget. The backend handles variations.
      // Encode query parameters
      final queryParams = {
        'branch': widget.branch,
        'year': widget.year,
        'section': widget.section, 
      };
      
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/students').replace(queryParameters: queryParams);
      debugPrint("Fetching students from: $uri");

      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        setState(() {
           _studentList = data.map((s) => {
             'fullName': s['full_name'] ?? s['fullName'] ?? 'Unknown',
             'studentId': s['student_id'] ?? s['studentId'] ?? s['login_id'] ?? 'Unknown',
             'section': widget.section, // We fetched specific section
             'branch': widget.branch,
             'year': widget.year
           }).toList();
           _isLoading = false;
        });
      } else {
         debugPrint("API Error: ${response.statusCode}");
         // Fallback to empty or JSON if critical
         setState(() { _studentList = []; _isLoading = false; });
      }

    } catch (e) {
      debugPrint("Error loading students: $e");
      setState(() { _studentList = []; _isLoading = false; });
    }
  }

  void _addStudent() {
     final nameController = TextEditingController();
     final idController = TextEditingController();
     bool isSubmitting = false;
     
     showDialog(
       context: context,
       builder: (ctx) => StatefulBuilder(
         builder: (context, setStateModal) {
           return AlertDialog(
             title: Text("Add Student to ${widget.section}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
             content: SingleChildScrollView(
               child: Column(
                 mainAxisSize: MainAxisSize.min,
                 children: [
                   TextField(controller: nameController, decoration: const InputDecoration(labelText: "Full Name")),
                   TextField(controller: idController, decoration: const InputDecoration(labelText: "Student ID")),
                   if (isSubmitting) const Padding(padding: EdgeInsets.only(top: 10), child: LinearProgressIndicator())
                 ],
               ),
             ),
             actions: [
               TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
               ElevatedButton(
                 onPressed: isSubmitting ? null : () async {
                   if (nameController.text.isNotEmpty && idController.text.isNotEmpty) {
                     setStateModal(() => isSubmitting = true);
                     try {
                        final user = await AuthService.getUserSession();
                        final branch = user?['branch'] ?? 'Computer Engineering';
                        
                        final res = await http.post(
                          Uri.parse('${ApiConstants.baseUrl}/api/students/create'),
                          headers: {'Content-Type': 'application/json'},
                          body: json.encode({
                             'fullName': nameController.text,
                             'studentId': idController.text,
                             'branch': branch,
                             'year': widget.year,
                             'section': widget.section // KEY FIX: Use current section
                          })
                        );
                        
                        if (res.statusCode == 201) {
                           Navigator.pop(ctx);
                           _fetchStudents(); // Refresh list to fetch from DB
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Student added successfully")));
                        } else {
                           final err = json.decode(res.body);
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${err['error']}")));
                        }
                     } catch (e) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                     } finally {
                        if (mounted) setStateModal(() => isSubmitting = false);
                     }
                   }
                 },
                 child: const Text("Add"),
               )
             ],
           );
         }
       )
     );
  }

  // API / Action Methods


  void _bulkMoveStudents() {
      if (widget.allSections.length <= 1) {
         ScaffoldMessenger.of(context).showSnackBar(
           const SnackBar(
             content: Text("Create another section first!"), 
             backgroundColor: Colors.red
            )
          );
         return;
      }

      // Show Dialog to select target
      String? targetSection;
      final otherSections = widget.allSections.where((s) => s != widget.section).toList();
      targetSection = otherSections.first;

      showDialog(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: Text("Move ${_selectedIds.length} Students"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text("Select Target Section:"),
                  const SizedBox(height: 10),
                  DropdownButton<String>(
                     value: targetSection,
                     isExpanded: true,
                     items: otherSections.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                     onChanged: (val) => setDialogState(() => targetSection = val),
                  )
                ],
              ),
              actions: [
                 TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                 ElevatedButton(
                   onPressed: () async {
                     Navigator.pop(ctx);
                     try {
                        final url = Uri.parse('${ApiConstants.baseUrl}/api/students/move');
                        final response = await http.post(
                          url, 
                          body: json.encode({
                            'student_ids': _selectedIds.toList(), // Changed to match backend struct (snake_case in some contexts, but let's check backend)
                            // Backend `MoveStudentsRequest` expects camelCase `studentIds` OR snake_case `student_ids` depending on Serde?
                            // Backend struct:
                            // #[serde(rename_all = "camelCase")]
                            // pub struct MoveStudentsRequest { pub student_ids: Vec<String>, ... }
                            // 
                            // If `rename_all="camelCase"`, then Rust field `student_ids` maps to JSON `studentIds`.
                            'studentIds': _selectedIds.toList(),
                            'targetSection': targetSection,
                            'branch': widget.branch,
                            'year': widget.year
                          }),
                          headers: {'Content-Type': 'application/json'}
                        );
                        
                        if (response.statusCode == 200) {
                           // Success
                           setState(() {
                             // Remove from local list immediately
                             _studentList.removeWhere((s) => _selectedIds.contains(s['studentId']));
                             _isSelectionMode = false;
                             _selectedIds.clear();
                           });
                           _fetchStudents(); // Refresh to be sure
                           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Moved students to $targetSection")));
                        } else {
                           debugPrint("Move failed: ${response.body}");
                           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to move students")));
                        }
                     } catch (e) {
                        debugPrint("Move Error: $e");
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                     }
                   },
                   child: const Text("Move"),
                 )
              ],
            );
          }
        )
      );
  }

  Future<void> _deleteStudent(int index, String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Are you sure you want to permanently delete student $id?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true), 
            child: const Text("Delete", style: TextStyle(color: Colors.white))
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/students/delete');
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'studentId': id}),
      );

      if (response.statusCode == 200) {
        // Remove locally by ID
        setState(() {
          _studentList.removeWhere((s) => s['studentId'].toString() == id);
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Student deleted successfully")));
      } else {
        setState(() => _isLoading = false);
        debugPrint("Delete failed: ${response.body}");
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to delete: ${response.statusCode}")));
      }
    } catch (e) {
      debugPrint("Delete error: $e");
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  // Fallback stubs
  void _suspendStudent(String id) {
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Suspend feature coming soon")));
  }
  
  void _reportStudent(String id) {
     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Report feature coming soon")));
  } 


  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? ThemeColors.darkBackground : ThemeColors.lightBackground;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;

    final filteredList = _studentList.where((s) => 
      s['fullName'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) || 
      s['studentId'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: _isSelectionMode 
          ? Row(
              children: [
                IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() { _isSelectionMode = false; _selectedIds.clear(); })),
                Text('${_selectedIds.length} Selected', style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold)),
              ],
            )
          : Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Students', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
            Text('${widget.year} - ${widget.section}', style: GoogleFonts.poppins(fontSize: 12, color: subTextColor)),
          ],
        ),
        actions: [
          if (_isSelectionMode)
            IconButton(
              icon: Icon(Icons.swap_horiz, color: tint), // Move Icon
               onPressed: _selectedIds.isEmpty ? null : _bulkMoveStudents,
            )
          else
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: textColor),
              onSelected: (val) {
                if (val == 'move_mode') setState(() => _isSelectionMode = true);
              },
              itemBuilder: (ctx) => [
                PopupMenuItem(value: 'move_mode', child: Row(children: [Icon(Icons.checklist, color: tint), const SizedBox(width: 8), const Text("Move Students")])),
              ],
            )
        ],
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addStudent,
        icon: const Icon(Icons.add),
        label: const Text("Add Student"),
        backgroundColor: tint,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: iconBg),
                  ),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      icon: Icon(Icons.search, color: subTextColor),
                      hintText: "Search students...",
                      hintStyle: TextStyle(color: subTextColor),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),

              Expanded(
                child: _isLoading 
                  ? Center(child: CircularProgressIndicator(color: tint))
                  : filteredList.isEmpty
                    ? Center(child: Text("No students found", style: TextStyle(color: subTextColor)))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        itemCount: filteredList.length,
                        itemBuilder: (ctx, index) {
                          final student = filteredList[index];
                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12), // Compact padding
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(color: iconBg),
                              boxShadow: [
                                BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
                              ],
                            ),
                            child: Row(
                              children: [
                                if (_isSelectionMode)
                                  Checkbox(
                                    value: _selectedIds.contains(student['studentId']),
                                    onChanged: (val) {
                                      setState(() {
                                        if (val == true) {
                                          _selectedIds.add(student['studentId']);
                                        } else {
                                          _selectedIds.remove(student['studentId']);
                                        }
                                      });
                                    },
                                    activeColor: tint,
                                    side: BorderSide(color: subTextColor),
                                  ),
                                Stack(
                                  children: [
                                    CircleAvatar(
                                      radius: 25,
                                      backgroundColor: tint.withValues(alpha: 0.1),
                                      child: Text(
                                        student['fullName'].toString()[0].toUpperCase(), 
                                        style: TextStyle(color: tint, fontWeight: FontWeight.bold, fontSize: 20)
                                      ),
                                    ),
                                    Positioned(
                                      right: 0,
                                      bottom: 0,
                                      child: Container(
                                        padding: const EdgeInsets.all(4),
                                        decoration: BoxDecoration(
                                          color: Colors.green, 
                                          shape: BoxShape.circle,
                                          border: Border.all(color: cardColor, width: 2)
                                        ),
                                        child: const SizedBox(width: 4, height: 4),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        student['fullName'], 
                                        style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)
                                      ),
                                      Text(
                                        'ID: ${student['studentId']}', 
                                        style: GoogleFonts.poppins(fontSize: 14, color: subTextColor)
                                      ),
                                    ],
                                  ),
                                ),
                                if (!_isSelectionMode)
                                PopupMenuButton<String>(
                                  icon: Icon(Icons.more_vert, color: subTextColor),
                                  onSelected: (val) {
                                    final id = student['studentId'].toString();
                                    if (val == 'delete') _deleteStudent(index, id);
                                    if (val == 'suspend') _suspendStudent(id);
                                    if (val == 'report') _reportStudent(id);
                                  },
                                  itemBuilder: (context) => [
                                    const PopupMenuItem(value: 'suspend', child: Row(children: [Icon(Icons.block, color: Colors.orange), SizedBox(width: 8), Text("Suspend")])),
                                    const PopupMenuItem(value: 'report', child: Row(children: [Icon(Icons.flag, color: Colors.amber), SizedBox(width: 8), Text("Report")])),
                                    const PopupMenuItem(value: 'delete', child: Row(children: [Icon(Icons.delete, color: Colors.red), SizedBox(width: 8), Text("Delete")])),
                                  ],
                                )
                              ],
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
