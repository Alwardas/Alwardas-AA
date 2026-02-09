import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/services.dart'; // For JSON fallback
import 'package:http/http.dart' as http;

import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';
import 'hod_manage_attendance_screen.dart';

class HODAttendanceScreen extends StatefulWidget {
  const HODAttendanceScreen({super.key});

  @override
  _HODAttendanceScreenState createState() => _HODAttendanceScreenState();
}

class _HODAttendanceScreenState extends State<HODAttendanceScreen> {
  Map<String, dynamic> _stats = {'totalStudents': 0, 'totalPresent': 0, 'totalAbsent': 0};
  bool _loading = false;
  
  // Modal State
  bool _modalVisible = false;
  String _activeTab = 'add'; // add | remove
  final _fullNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  String _selectedYear = '1st Year';
  final _removeIdController = TextEditingController();
  bool _submitting = false;

  Map<String, bool> _attendanceStatus = {
    '1st Year': false,
    '2nd Year': false,
    '3rd Year': false
  };

  String _selectedSession = 'All'; // All | Morning | Afternoon

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _loading = true);
    final user = await AuthService.getUserSession();
    final branch = user?['branch'] ?? 'Computer Engineering';
    final dateStr = DateTime.now().toIso8601String();
    
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/attendance/stats')
          .replace(queryParameters: {
            'branch': branch,
            'date': dateStr,
            'session': _selectedSession
          });
          
      final res = await http.get(uri);
      int total = 0;
      int present = 0;
      int absent = 0;

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        total = data['total_students'] ?? 0;
        present = data['total_present'] ?? 0;
        absent = data['total_absent'] ?? 0;
      }
      
      // Fallback: If DB total is 0, use JSON count
      if (total == 0) {
         total = await _calculateTotalFromJson(branch);
      }

      setState(() {
        _stats = {
          'totalStudents': total,
          'totalPresent': present,
          'totalAbsent': absent
        };
        _loading = false;
      });

    } catch (e) {
      setState(() => _loading = false);
      print("Error fetching stats: $e");
    }
  }

  Future<int> _calculateTotalFromJson(String branchName) async {
      try {
        String branchKey = 'cme'; 
        final b = branchName.toLowerCase();
        if (b.contains('computer')) branchKey = 'cme';
        else if (b.contains('civil')) branchKey = 'civil';
        else if (b.contains('electrical')) branchKey = 'eee';
        else if (b.contains('electronics')) branchKey = 'ece';
        else if (b.contains('mechanical')) branchKey = 'mech';

        final files = ['2025-2028_students.json', '2024-2027_students.json', '2023-2026_students.json'];
        int count = 0;

        for (String file in files) {
           try {
             final String content = await rootBundle.loadString('assets/data/json/$file');
             final Map<String, dynamic> data = json.decode(content);
             data.forEach((year, branches) {
                if (branches is Map && branches.containsKey(branchKey)) {
                   count += (branches[branchKey] as List).length;
                }
             });
           } catch (_) {}
        }
        return count > 0 ? count : 0; 
      } catch (e) {
        return 0;
      }
  }

  Future<void> _handleAddStudent() async {
     setState(() => _submitting = true);
     final user = await AuthService.getUserSession();
     final branch = user?['branch'] ?? 'Computer Engineering'; // Use full name for consistency if needed, or normalizing backend handles it
     
     if (_fullNameController.text.isEmpty || _studentIdController.text.isEmpty) {
        _showSnackBar("Please fill all fields");
        setState(() => _submitting = false);
        return;
     }

     try {
       final res = await http.post(
         Uri.parse('${ApiConstants.baseUrl}/api/students/create'),
         headers: {'Content-Type': 'application/json'},
         body: json.encode({
           'fullName': _fullNameController.text,
           'studentId': _studentIdController.text,
           'branch': branch,
           'year': _selectedYear,
           'section': 'Section A' // Default to Section A as it's the primary view
         })
       );

       if (res.statusCode == 201) {
          _showSnackBar("Student Added Successfully");
          setState(() {
             _modalVisible = false;
             _fullNameController.clear();
             _studentIdController.clear();
          });
          _fetchStats(); // Refresh stats
       } else {
          // Try parse error
          try {
             final err = json.decode(res.body);
             _showSnackBar("Failed: ${err['error']}");
          } catch (_) {
             _showSnackBar("Failed: ${res.statusCode}");
          }
       }
     } catch (e) {
       _showSnackBar("Error: $e");
     } finally {
       if (mounted) setState(() => _submitting = false);
     }
  }

  Future<void> _handleRemoveStudent() async {
     // Backend connection removed
     _showSnackBar("Feature disabled");
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
    
    // Determine Absent Display Text
    // If no attendance submitted (Present=0 & Absent=0), show '-'
    // Note: This logic assumes 'totalStudents' > 0. If 0 students, '0' is fine.
    bool noAttendance = (_stats['totalPresent'] == 0 && _stats['totalAbsent'] == 0);
    String absentText = noAttendance && _stats['totalStudents'] > 0 ? "-" : _stats['totalAbsent'].toString();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Attendance Management", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => setState(() => _modalVisible = true),
        backgroundColor: tint,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Stack(
            children: [
              SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
    // Session Selector
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: iconBg)
                      ),
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: ['All', 'Morning', 'Afternoon'].map((session) {
                            final isSelected = _selectedSession == session;
                            return GestureDetector(
                              onTap: () {
                                setState(() => _selectedSession = session);
                                _fetchStats();
                              },
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSelected ? tint : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                  session, 
                                  style: GoogleFonts.poppins(
                                    color: isSelected ? Colors.white : textColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14
                                  )
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                      ),
                    ),

                    // Stats
                    Row(
                      children: [
                         _buildStatCard("Total", _stats['totalStudents'].toString(), Colors.blue),
                         const SizedBox(width: 10),
                         _buildStatCard("Present", _stats['totalPresent'].toString(), Colors.green),
                         const SizedBox(width: 10),
                         _buildStatCard("Absent", absentText, Colors.red),
                      ],
                    ),
                    const SizedBox(height: 30),
                    
                    Text("Select Year to View/Manage", style: GoogleFonts.poppins(color: subTextColor, fontSize: 16)),
                    const SizedBox(height: 20),
                    
                    ...['1st Year', '2nd Year', '3rd Year'].map((year) {
                       final isMarked = _attendanceStatus[year] ?? false; 
                       return GestureDetector(
                         onTap: () async {
                           final user = await AuthService.getUserSession();
                           if (user == null) return;
                           
                           final prefs = await SharedPreferences.getInstance();
                           final key = 'sections_${user['branch']}_$year';
                           final List<String> sections = prefs.getStringList(key) ?? ['Section A'];
                           
                           if (!mounted) return;

                           showDialog(
                             context: context,
                             builder: (ctx) => Dialog(
                               backgroundColor: Colors.transparent,
                               child: Container(
                                 padding: const EdgeInsets.all(25),
                                 decoration: BoxDecoration(
                                   color: Colors.white,
                                   borderRadius: BorderRadius.circular(20),
                                   boxShadow: [
                                     BoxShadow(
                                       color: Colors.black.withOpacity(0.15),
                                       blurRadius: 20,
                                       offset: const Offset(0, 10),
                                     )
                                   ],
                                 ),
                                 child: SingleChildScrollView(
                                   child: Column(
                                     mainAxisSize: MainAxisSize.min,
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Row(
                                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                         children: [
                                           Text("Select Section", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFF1e1e2d))),
                                           Row(
                                             children: [
                                               IconButton(
                                                 icon: const Icon(Icons.add_circle, color: Colors.blue),
                                                 onPressed: () async {
                                                    Navigator.pop(ctx);
                                                    final n = await showDialog<String>(context: context, builder: (c) {
                                                      String v = "";
                                                      return AlertDialog(
                                                        title: const Text("New Section"), 
                                                        content: TextField(autofocus: true, decoration: const InputDecoration(hintText: "Section Name"), onChanged: (val)=>v=val),
                                                        actions: [TextButton(onPressed:()=>Navigator.pop(c), child: const Text("Cancel")), ElevatedButton(onPressed:()=>Navigator.pop(c,v), child: const Text("Create"))]
                                                      );
                                                    });
                                                    if (n != null && n.isNotEmpty) {
                                                       final updated = List<String>.from(sections)..add(n);
                                                       await prefs.setStringList(key, updated);
                                                       _showSnackBar("Created $n");
                                                    }
                                                 },
                                               ),
                                               IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close, color: Color(0xFF1e1e2d)))
                                             ],
                                           )
                                         ],
                                       ),
                                       Text(year, style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14)),
                                       const SizedBox(height: 25),
                                       ...sections.map((section) => Container(
                                         margin: const EdgeInsets.only(bottom: 12),
                                         decoration: BoxDecoration(
                                           color: const Color(0xFFf8f9fa),
                                           borderRadius: BorderRadius.circular(15),
                                           border: Border.all(color: tint.withOpacity(0.2)),
                                         ),
                                         child: ListTile(
                                           title: Text(section, style: GoogleFonts.poppins(color: const Color(0xFF1e1e2d), fontWeight: FontWeight.w600)),
                                           leading: Container(
                                             padding: const EdgeInsets.all(8),
                                             decoration: BoxDecoration(color: tint.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                             child: Icon(Icons.class_, color: tint, size: 20),
                                           ),
                                           trailing: Icon(Icons.arrow_forward_ios, size: 14, color: tint),
                                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                                           onTap: () async {
                                             Navigator.pop(ctx);
                                             await Navigator.push(context, MaterialPageRoute(builder: (_) => HODManageAttendanceScreen(year: year, initialSession: _selectedSession, section: section)));
                                             _fetchStats();
                                           },
                                         ),
                                       )),
                                       const SizedBox(height: 10),
                                     ],
                                   ),
                                 ),
                               ),
                             )
                           );
                         },
                         child: Container(
                           margin: const EdgeInsets.only(bottom: 15),
                           padding: const EdgeInsets.all(20),
                           decoration: BoxDecoration(
                             color: isMarked ? Colors.green.withOpacity(0.1) : cardColor,
                             border: Border.all(color: isMarked ? Colors.green : iconBg),
                             borderRadius: BorderRadius.circular(15),
                           ),
                           child: Row(
                             children: [
                               Container(
                                 padding: const EdgeInsets.all(12),
                                 decoration: BoxDecoration(color: isMarked ? Colors.green.withOpacity(0.2) : iconBg, borderRadius: BorderRadius.circular(12)),
                                 child: Icon(Icons.calendar_today, color: isMarked ? Colors.green : tint),
                               ),
                               const SizedBox(width: 15),
                               Expanded(
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                     Text(year, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                                     if (isMarked)
                                       Text("Attendance Marked", style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)) 
                                     else
                                       Text("Mark Attendance", style: GoogleFonts.poppins(color: subTextColor)),
                                   ],
                                 ),
                               ),
                               Icon(Icons.chevron_right, color: isMarked ? Colors.green : subTextColor)
                             ],
                           ),
                         ),
                       );
                    }).toList(),
                    
                    const SizedBox(height: 80), 
                  ],
                ),
              ),

              if (_modalVisible) _buildModal(textColor, subTextColor, isDark ? const Color(0xFF24243e) : Colors.white, tint, iconBg),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 10, offset: const Offset(0, -5))]
        ),
        child: SafeArea(
          child: ElevatedButton.icon(
            icon: const Icon(Icons.download, color: Colors.white),
            label: Text("Download Monthly Report (PDF)", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: tint,
              padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            ),
            onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(
                   content: Text("Generating PDF Report..."),
                   duration: Duration(seconds: 1),
                 )
               );
               
               // Simulate PDF generation delay
               Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Success"),
                        content: const Text("Report has been downloaded successfully to /Download/Alwardas_Report_Dec2025.pdf"),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Open"))
                        ],
                      )
                    );
                  }
               });
            },
          ),
        ),
      ),
    );
  }

  Widget _buildStatCard(String label, String value, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Column(children: [Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(color: Colors.white70))]),
      ),
    );
  }
  
  Widget _buildModal(Color textColor, Color subTextColor, Color bg, Color tint, Color iconBg) {
    return Container(
      color: Colors.black54,
      alignment: Alignment.center,
      child: Center(
        child: SingleChildScrollView(
          child: Container(
             width: MediaQuery.of(context).size.width * 0.9,
             padding: const EdgeInsets.all(20),
             decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(16)),
             child: Column(
               mainAxisSize: MainAxisSize.min,
               children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text("Manage Students", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                      IconButton(onPressed: () => setState(() => _modalVisible = false), icon: Icon(Icons.close, color: textColor))
                    ],
                  ),
                  // Tabs
                  Row(
                    children: [
                      Expanded(child: GestureDetector(
                        onTap: () => setState(() => _activeTab = 'add'),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          color: _activeTab == 'add' ? tint : Colors.transparent,
                          alignment: Alignment.center,
                          child: Text("Add Student", style: TextStyle(color: _activeTab == 'add' ? Colors.white : textColor, fontWeight: FontWeight.bold)),
                        ),
                      )),
                      Expanded(child: GestureDetector(
                        onTap: () => setState(() => _activeTab = 'remove'),
                        child: Container(
                          padding: const EdgeInsets.all(10),
                          color: _activeTab == 'remove' ? Colors.red : Colors.transparent,
                          alignment: Alignment.center,
                          child: Text("Remove Student", style: TextStyle(color: _activeTab == 'remove' ? Colors.white : textColor, fontWeight: FontWeight.bold)),
                        ),
                      )),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  if (_activeTab == 'add') ...[
                     TextField(controller: _fullNameController, decoration: InputDecoration(hintText: "Full Name", hintStyle: TextStyle(color: subTextColor)), style: TextStyle(color: textColor)),
                     const SizedBox(height: 10),
                     TextField(controller: _studentIdController, decoration: InputDecoration(hintText: "Student ID", hintStyle: TextStyle(color: subTextColor)), style: TextStyle(color: textColor)),
                     const SizedBox(height: 10),
                     // Year chips
                     Row(
                       children: ['1st Year', '2nd Year', '3rd Year'].map((y) => GestureDetector(
                         onTap: () => setState(() => _selectedYear = y),
                         child: Container(
                           margin: const EdgeInsets.only(right: 10),
                           padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                           decoration: BoxDecoration(color: _selectedYear == y ? tint : iconBg, borderRadius: BorderRadius.circular(10)),
                           child: Text(y, style: TextStyle(color: _selectedYear == y ? Colors.white : textColor)),
                         ),
                       )).toList(),
                     ),
                     const SizedBox(height: 20),
                     ElevatedButton(onPressed: _submitting ? null : _handleAddStudent, style: ElevatedButton.styleFrom(backgroundColor: tint), child: _submitting ? const CircularProgressIndicator(color: Colors.white) : const Text("Add Student", style: TextStyle(color: Colors.white))),
                  ] else ...[
                     TextField(controller: _removeIdController, decoration: InputDecoration(hintText: "Student ID", hintStyle: TextStyle(color: subTextColor)), style: TextStyle(color: textColor)),
                     const SizedBox(height: 10),
                     Text("Warning: Irreversible action.", style: TextStyle(color: Colors.red, fontSize: 12)),
                     const SizedBox(height: 20),
                     ElevatedButton(onPressed: _submitting ? null : _handleRemoveStudent, style: ElevatedButton.styleFrom(backgroundColor: Colors.red), child: _submitting ? const CircularProgressIndicator(color: Colors.white) : const Text("Remove Student", style: TextStyle(color: Colors.white))),
                  ]
               ],
             ),
          ),
        ),
      ),
    );
  }
}
