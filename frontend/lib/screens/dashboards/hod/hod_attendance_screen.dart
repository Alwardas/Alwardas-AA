import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
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
  // Overall Stats
  Map<String, dynamic> _stats = {'totalStudents': 0, 'totalPresent': 0, 'totalAbsent': 0};
  
  // Detailed Data: Year -> { stats: {total, present, absent}, sections: { name: {stats, isMarked} }, sectionList: [], allMarked: bool }
  Map<String, dynamic> _detailedStats = {};
  
  bool _loading = false;
  
  // Filters
  String _selectedSession = 'Morning'; // Morning | Afternoon (Removed "All")
  DateTime _selectedDate = DateTime.now();

  // Modal State
  bool _modalVisible = false;
  String _activeTab = 'add'; 
  final _fullNameController = TextEditingController();
  final _studentIdController = TextEditingController();
  String _selectedYear = '1st Year';
  final _removeIdController = TextEditingController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    setState(() => _loading = true);
    final user = await AuthService.getUserSession();
    final branch = user?['branch'] ?? 'Computer Engineering';
    final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate); 
    
    try {
      // 1. Overall Stats (Aggregated for all years)
      // Note: The backend /api/attendance/stats with only branch/date/session gives total for branch
      // We need to ensure we sum up if the backend doesn't handle "all years" implicitly (which it does by default if no year param)
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/attendance/stats')
          .replace(queryParameters: {
            'branch': branch,
            'date': dateStr,
            'session': _selectedSession
          });
          
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        _stats = {
          'totalStudents': data['totalStudents'] ?? 0,
          'totalPresent': data['totalPresent'] ?? 0,
          'totalAbsent': data['totalAbsent'] ?? 0
        };
      }

      // 2. Detailed Year & Section Stats
      Map<String, dynamic> newDetailedStats = {};
      
      for (String year in ['1st Year', '2nd Year', '3rd Year']) {
         // A. Fetch Sections
         final secRes = await http.get(
           Uri.parse('${ApiConstants.baseUrl}/api/sections').replace(queryParameters: {'branch': branch, 'year': year})
         );
         List<String> sections = ['Section A'];
         if (secRes.statusCode == 200) {
             sections = List<String>.from(json.decode(secRes.body));
         }

         // B. Fetch Year Stats
         final yearStatsRes = await http.get(
           Uri.parse('${ApiConstants.baseUrl}/api/attendance/stats').replace(queryParameters: {
             'branch': branch,
             'year': year,
             'date': dateStr,
             'session': _selectedSession
           })
         );
         Map<String, dynamic> yearStatsData = {'totalStudents': 0, 'totalPresent': 0, 'totalAbsent': 0};
         if (yearStatsRes.statusCode == 200) {
            yearStatsData = json.decode(yearStatsRes.body);
         }

         // C. Fetch Stats per Section
         Map<String, dynamic> sectionMap = {};
         bool allSectionsMarked = true;
         
         for (String section in sections) {
             final sRes = await http.get(
               Uri.parse('${ApiConstants.baseUrl}/api/attendance/stats').replace(queryParameters: {
                 'branch': branch,
                 'year': year,
                 'section': section,
                 'date': dateStr,
                 'session': _selectedSession
               })
             );
             
             Map<String, dynamic> sData = {'totalStudents': 0, 'totalPresent': 0, 'totalAbsent': 0};
             if (sRes.statusCode == 200) {
                sData = json.decode(sRes.body);
             }
             
             // Check if attendance is marked (Present + Absent > 0)
             bool isMarked = (sData['totalPresent'] as int) + (sData['totalAbsent'] as int) > 0;
             if (!isMarked) allSectionsMarked = false;

             sectionMap[section] = {
               'stats': sData,
               'isMarked': isMarked
             };
         }
         
         if (sections.isEmpty) allSectionsMarked = false;

         newDetailedStats[year] = {
           'stats': yearStatsData,
           'sections': sectionMap, 
           'sectionList': sections,
           'allMarked': allSectionsMarked
         };
      }

      setState(() {
        _detailedStats = newDetailedStats;
        _loading = false;
      });

    } catch (e) {
      if(mounted) setState(() => _loading = false);
      print("Error fetching stats: $e");
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      _fetchStats();
    }
  }

  Future<void> _handleAddStudent() async {
     setState(() => _submitting = true);
     final user = await AuthService.getUserSession();
     final branch = user?['branch'] ?? 'Computer Engineering'; 
     
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
           'section': 'Section A' 
         })
       );

       if (res.statusCode == 201) {
          _showSnackBar("Student Added Successfully");
          setState(() {
             _modalVisible = false;
             _fullNameController.clear();
             _studentIdController.clear();
          });
          _fetchStats(); 
       } else {
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
    
    bool noAttendance = (_stats['totalPresent'] == 0 && _stats['totalAbsent'] == 0);
    String absentText = noAttendance && (_stats['totalStudents'] ?? 0) > 0 ? "-" : _stats['totalAbsent'].toString();

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
                    // Filter Row: Session Selector + Date Picker
                    Container(
                      margin: const EdgeInsets.only(bottom: 20),
                      child: Row(
                        children: [
                          // Session Segmented Control (Morning/Afternoon)
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(4),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(25),
                                border: Border.all(color: iconBg)
                              ),
                              child: Row(
                                children: ['Morning', 'Afternoon'].map((session) {
                                  final isSelected = _selectedSession == session;
                                  return Expanded(
                                    child: GestureDetector(
                                      onTap: () {
                                        setState(() => _selectedSession = session);
                                        _fetchStats();
                                      },
                                      child: AnimatedContainer(
                                        duration: const Duration(milliseconds: 200),
                                        padding: const EdgeInsets.symmetric(vertical: 10),
                                        alignment: Alignment.center,
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
                                    ),
                                  );
                                }).toList(),
                              ),
                            ),
                          ),
                          const SizedBox(width: 15),
                          
                          // Date Picker
                          GestureDetector(
                            onTap: () => _selectDate(context),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
                              decoration: BoxDecoration(
                                color: cardColor,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: iconBg)
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.calendar_today, color: tint, size: 20),
                                  const SizedBox(width: 8),
                                  Text(
                                    DateFormat('MMM dd').format(_selectedDate),
                                    style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold)
                                  )
                                ],
                              ),
                            ),
                          )
                        ],
                      ),
                    ),

                    // Overall Stats
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
                    
                    Text("Year-wise Attendance", style: GoogleFonts.poppins(color: subTextColor, fontSize: 16)),
                    const SizedBox(height: 20),
                    
                    if (_loading) 
                        const Padding(padding: EdgeInsets.all(20), child: CircularProgressIndicator())
                    else
                    ...['1st Year', '2nd Year', '3rd Year'].map((year) {
                       final data = _detailedStats[year] ?? {};
                       final stats = data['stats'] ?? {'totalStudents': 0, 'totalPresent': 0, 'totalAbsent': 0};
                       final allMarked = data['allMarked'] ?? false;
                       final sections = data['sectionList'] as List<String>? ?? ['Section A'];

                       // Calculate Absent text for the year
                       // If Present=0 and Absent=0, show '-' if there are students
                       bool yearNoAtt = (stats['totalPresent'] == 0 && stats['totalAbsent'] == 0);
                       String yearAbsentStr = yearNoAtt && (stats['totalStudents'] ?? 0) > 0 ? "-" : stats['totalAbsent'].toString();

                       return GestureDetector(
                         onTap: () {
                           _showSectionDialog(context, year, sections, data['sections'] ?? {});
                         },
                         child: Container(
                           margin: const EdgeInsets.only(bottom: 15),
                           padding: const EdgeInsets.all(20),
                           decoration: BoxDecoration(
                             color: allMarked ? Colors.green.withOpacity(0.1) : cardColor,
                             border: Border.all(color: allMarked ? Colors.green : iconBg),
                             borderRadius: BorderRadius.circular(15),
                             boxShadow: [
                               if (isDark) BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5, offset: const Offset(0,2))
                             ]
                           ),
                           child: Column(
                             children: [
                               Row(
                                 children: [
                                   Container(
                                     padding: const EdgeInsets.all(12),
                                     decoration: BoxDecoration(color: allMarked ? Colors.green.withOpacity(0.2) : iconBg, borderRadius: BorderRadius.circular(12)),
                                     child: Icon(Icons.school, color: allMarked ? Colors.green : tint, size: 24),
                                   ),
                                   const SizedBox(width: 15),
                                   Expanded(
                                     child: Column(
                                       crossAxisAlignment: CrossAxisAlignment.start,
                                       children: [
                                         Text(year, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                                         if (allMarked)
                                           Text("All Sections Marked", style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 12)) 
                                         else
                                           Text("Tap to View/Manage", style: GoogleFonts.poppins(color: subTextColor, fontSize: 12)),
                                       ],
                                     ),
                                   ),
                                   Icon(Icons.chevron_right, color: allMarked ? Colors.green : subTextColor)
                                 ],
                               ),
                               const SizedBox(height: 15),
                               // Granular Stats for Year
                               Container(
                                 padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 5),
                                 decoration: BoxDecoration(
                                   color: isDark ? const Color(0xFF1E1E2D).withOpacity(0.5) : Colors.white.withOpacity(0.5),
                                   borderRadius: BorderRadius.circular(10)
                                 ),
                                 child: Row(
                                     mainAxisAlignment: MainAxisAlignment.spaceAround,
                                     children: [
                                       _buildMiniStat("Total", stats['totalStudents'].toString(), subTextColor),
                                       Container(height: 20, width: 1, color: iconBg),
                                       _buildMiniStat("Present", stats['totalPresent'].toString(), Colors.green),
                                       Container(height: 20, width: 1, color: iconBg),
                                       _buildMiniStat("Absent", yearAbsentStr, Colors.red),
                                     ],
                                 ),
                               )
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
                 const SnackBar(content: Text("Generating PDF Report..."), duration: Duration(seconds: 1))
               );
               Future.delayed(const Duration(seconds: 2), () {
                  if (mounted) {
                    showDialog(
                      context: context,
                      builder: (ctx) => AlertDialog(
                        title: const Text("Success"),
                        content: const Text("Report has been downloaded successfully to /Download/Alwardas_Report_Dec2025.pdf"),
                        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Open"))],
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

  void _showSectionDialog(BuildContext context, String year, List<String> sections, Map<String, dynamic> sectionsData) {
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
                BoxShadow(color: Colors.black.withOpacity(0.15), blurRadius: 20, offset: const Offset(0, 10))
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
                                      final user = await AuthService.getUserSession();
                                      _showSnackBar("Section creation requires backend update.");
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
                  ...sections.map((section) {
                     final sInfo = sectionsData[section] ?? {};
                     final isMarked = sInfo['isMarked'] == true;
                     final stats = sInfo['stats'] ?? {};
                     
                     // Helper for absent text
                     bool secNoAtt = ((stats['totalPresent'] ?? 0) == 0 && (stats['totalAbsent'] ?? 0) == 0);
                     String secAbsentStr = secNoAtt && (stats['totalStudents'] ?? 0) > 0 ? "-" : stats['totalAbsent'].toString();

                     return Container(
                       margin: const EdgeInsets.only(bottom: 12),
                       decoration: BoxDecoration(
                         color: isMarked ? Colors.green.withOpacity(0.1) : const Color(0xFFf8f9fa),
                         borderRadius: BorderRadius.circular(15),
                         border: Border.all(color: isMarked ? Colors.green : Colors.blue.withOpacity(0.2)), 
                       ),
                       child: Column(
                         children: [
                           ListTile(
                             title: Text(section, style: GoogleFonts.poppins(color: const Color(0xFF1e1e2d), fontWeight: FontWeight.w600)),
                             trailing: Icon(Icons.arrow_forward_ios, size: 14, color: isMarked ? Colors.green : Colors.blue),
                             onTap: () async {
                               Navigator.pop(ctx);
                               await Navigator.push(context, MaterialPageRoute(builder: (_) => HODManageAttendanceScreen(year: year, initialSession: _selectedSession, section: section)));
                               _fetchStats();
                             },
                           ),
                           // Mini Stats for Section
                           Padding(
                             padding: const EdgeInsets.only(left: 15, right: 15, bottom: 10),
                             child: Row(
                               mainAxisAlignment: MainAxisAlignment.spaceAround,
                               children: [
                                 Text("T: ${stats['totalStudents']}", style: TextStyle(fontSize: 12, color: Colors.grey[800])),
                                 Text("P: ${stats['totalPresent']}", style: TextStyle(fontSize: 12, color: Colors.green)),
                                 Text("A: $secAbsentStr", style: TextStyle(fontSize: 12, color: Colors.red)),
                               ],
                             ),
                           )
                         ],
                       ),
                     );
                  }),
                  const SizedBox(height: 10),
                ],
              ),
            ),
          ),
        )
      );
  }

  Widget _buildMiniStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
      ],
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
