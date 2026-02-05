import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;

import 'dart:convert';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';

class HODManageAttendanceScreen extends StatefulWidget {
  final String year;
  final String? initialSession;
  final String? branchOverride;
  final String? section;
  const HODManageAttendanceScreen({super.key, required this.year, this.initialSession, this.branchOverride, this.section});

  @override
  _HODManageAttendanceScreenState createState() => _HODManageAttendanceScreenState();
}

class _HODManageAttendanceScreenState extends State<HODManageAttendanceScreen> {
  DateTime _date = DateTime.now();
  late String _session; 

  @override
  void initState() {
    super.initState();
    // Default to MORNING if initialSession is All or null, otherwise use the specific session
    String init = widget.initialSession?.toUpperCase() ?? 'MORNING';
    _session = (init == 'ALL') ? 'MORNING' : init;
    
    _checkDailyStatus();
    _fetchAttendance();
  }
  bool _morningMarked = false;
  bool _afternoonMarked = false;
  
  List<dynamic> _students = [];
  List<dynamic> _originalStudents = []; 
  String _searchQuery = '';
  bool _loading = false;
  bool _submitting = false;
  String? _markedBy;
  bool _isEditing = false;
  
  // Removed Mock Data

  Future<void> _checkDailyStatus() async {
    final user = await AuthService.getUserSession();
    final branch = widget.branchOverride ?? user?['branch'] ?? '';
    final dateStr = _date.toIso8601String();
    final section = widget.section ?? 'Section A';

    try {
      final amRes = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/attendance/check?branch=${Uri.encodeComponent(branch)}&year=${Uri.encodeComponent(widget.year)}&session=MORNING&date=$dateStr&section=${Uri.encodeComponent(section)}'));
      if (amRes.statusCode == 200) {
        final data = json.decode(amRes.body);
        setState(() => _morningMarked = data['submitted']);
      }
      
      final pmRes = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/attendance/check?branch=${Uri.encodeComponent(branch)}&year=${Uri.encodeComponent(widget.year)}&session=AFTERNOON&date=$dateStr&section=${Uri.encodeComponent(section)}'));
      if (pmRes.statusCode == 200) {
        final data = json.decode(pmRes.body);
        setState(() => _afternoonMarked = data['submitted']);
      }
    } catch (e) {
      print("Status check error: $e");
    }
  }

  Future<void> _fetchAttendance() async {
    setState(() => _loading = true);
    final user = await AuthService.getUserSession();
    final branch = widget.branchOverride ?? user?['branch'] ?? '';
    final dateStr = _date.toIso8601String();
    final section = widget.section ?? 'Section A';

    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/attendance/class-record')
          .replace(queryParameters: {
            'branch': branch,
            'year': widget.year,
            'session': _session,
            'date': dateStr,
            'section': section
          });

      final res = await http.get(uri);
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        
        if (data['students'] != null) {
          final fetched = List<dynamic>.from(data['students']).map((s) => {
              ...s,
              'status': (s['status'] == 'PENDING') ? 'PRESENT' : s['status'],
              // Ensure we have section info if backend sends it, else default
              'section': section 
          }).toList();
          
          setState(() {
            _students = fetched;
            _originalStudents = fetched.map((s) => Map<String, dynamic>.from(s)).toList();
            _markedBy = data['markedBy'];
            _loading = false;
          });
        } else {
           setState(() => _loading = false);
        }
      } else {
        setState(() => _loading = false);
        _showSnackBar("Failed to fetch records");
      }
    } catch (e) {
      setState(() => _loading = false);
      _showSnackBar("Network Error: $e");
    }
  }

  Future<void> _handleSubmit() async {
     setState(() => _submitting = true);
     final user = await AuthService.getUserSession();
     
     final records = _students.map((s) => {
       'studentId': s['studentId'],
       'status': s['status']
     }).toList();

     try {
       final res = await http.post(
         Uri.parse('${ApiConstants.baseUrl}/api/attendance/batch'),
         headers: {'Content-Type': 'application/json'},
         body: json.encode({
           'records': records,
           'date': _date.toIso8601String(),
           'session': _session,
           'markedBy': user?['login_id']
         })
       );
       
       if (res.statusCode == 200 || res.statusCode == 201) {
         _showSnackBar("Attendance Saved");
         _checkDailyStatus();
         if (_session == 'MORNING') setState(() => _morningMarked = true);
         else setState(() => _afternoonMarked = true);
         setState(() => _isEditing = false);
         _fetchAttendance(); // Refresh to ensure strict sync
       } else {
         final body = json.decode(res.body);
         _showSnackBar(body['error'] ?? "Submission failed");
       }
     } catch (e) {
       _showSnackBar("Network Error");
     } finally {
       setState(() => _submitting = false);
     }
  }

  
  void _toggleStatus(int index) {
    if (_isLocked && !_isEditing) return;
    
    setState(() {
      final s = _students[index];
      _students[index]['status'] = s['status'] == 'PRESENT' ? 'ABSENT' : 'PRESENT';
    });
  }

  bool get _isLocked {
    if (_session == 'MORNING') return _morningMarked;
    return _afternoonMarked;
  }
  
  void _toggleSelectAll() {
     if (_isLocked && !_isEditing) return;
     
     final filtered = _filteredStudents;
     final allPresent = filtered.every((s) => s['status'] == 'PRESENT');
     final newStatus = allPresent ? 'ABSENT' : 'PRESENT';
     
     setState(() {
       for (var s in filtered) {
          final idx = _students.indexOf(s);
          if (idx != -1) _students[idx]['status'] = newStatus;
       }
     });
  }

  List<dynamic> get _filteredStudents {
    if (_searchQuery.isEmpty) return _students;
    return _students.where((s) => 
      s['fullName'].toString().toLowerCase().contains(_searchQuery.toLowerCase()) || 
      s['studentId'].toString().toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }
  
  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _date) {
      setState(() {
        _date = picked;
        _isEditing = false; // Reset edit mode on date change
      });
      _checkDailyStatus();
      _fetchAttendance();
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
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;
    
    final filtered = _filteredStudents;
    final total = _students.length;
    final present = _students.where((s) => s['status'] == 'PRESENT').length;
    final absent = total - present;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.year, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
            Text("Attendance Log", style: GoogleFonts.poppins(fontSize: 12, color: subTextColor)),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          if (_isLocked && !_isEditing)
            Padding(
              padding: const EdgeInsets.only(right: 16.0),
              child: TextButton(
                onPressed: () {
                   setState(() {
                     _isEditing = true;
                   });
                },
                child: Text("Correction", style: TextStyle(color: tint, fontWeight: FontWeight.bold)),
              ),
            )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Column(
            children: [
               // Controls
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                 child: Column(
                   children: [
                     Row(
                       children: [
                         Expanded(
                           flex: 2,
                           child: GestureDetector(
                             onTap: () => _selectDate(context),
                             child: Container(
                               padding: const EdgeInsets.all(12),
                               decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                               child: Row(
                                 mainAxisAlignment: MainAxisAlignment.center,
                                 children: [
                                   Icon(Icons.calendar_today, size: 16, color: textColor),
                                   const SizedBox(width: 8),
                                   Text("${_date.day}/${_date.month}/${_date.year}", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                 ],
                               ),
                             ),
                           ),
                         ),
                         const SizedBox(width: 10),
                         Expanded(
                           flex: 3,
                           child: Container(
                             padding: const EdgeInsets.all(4),
                             decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
                             child: Row(
                               children: [
                                 _buildSessionBtn("AM", "MORNING", _morningMarked, tint, textColor),
                                 _buildSessionBtn("PM", "AFTERNOON", _afternoonMarked, tint, textColor),
                               ],
                             ),
                           ),
                         )
                       ],
                     ),
                     const SizedBox(height: 10),
                     Container(
                       padding: const EdgeInsets.symmetric(horizontal: 10),
                       decoration: BoxDecoration(color: cardColor, border: Border.all(color: iconBg), borderRadius: BorderRadius.circular(10)),
                       child: TextField(
                         onChanged: (v) => setState(() => _searchQuery = v),
                         style: TextStyle(color: textColor),
                         decoration: InputDecoration(
                           icon: Icon(Icons.search, color: subTextColor),
                           hintText: "Search...",
                           hintStyle: TextStyle(color: subTextColor),
                           border: InputBorder.none
                         ),
                       ),
                     )
                   ],
                 ),
               ),
               
               // Select All Header
               Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 5),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.end,
                   children: [
                     GestureDetector(
                        onTap: () async {
                          final selected = _students.where((s) => s['status'] == 'PRESENT').toList();
                          if (selected.isEmpty) { _showSnackBar("Select students (Present) to move"); return; }
                          
                          String? target = await showDialog<String>(context: context, builder: (c) {
                             String v = "";
                             return AlertDialog(
                               title: const Text("Move to Section"),
                               content: TextField(autofocus: true, decoration: const InputDecoration(hintText: "Target Section"), onChanged: (val) => v = val),
                               actions: [TextButton(onPressed: () => Navigator.pop(c), child: const Text("Cancel")), ElevatedButton(onPressed: () => Navigator.pop(c, v), child: const Text("Move"))],
                             );
                          });
                          
                          if (target != null && target.isNotEmpty) {
                             setState(() => _loading = true);
                             try {
                               final ids = selected.map((s) => s['studentId']).toList();
                               final res = await http.post(
                                 Uri.parse('${ApiConstants.baseUrl}/api/students/move'),
                                 headers: {'Content-Type': 'application/json'},
                                 body: json.encode({
                                   'studentIds': ids,
                                   'targetSection': target,
                                   'branch': widget.branchOverride ?? '',
                                   'year': widget.year
                                 })
                               );
                               if (res.statusCode == 200) {
                                  _showSnackBar("Moved students to $target");
                                  _fetchAttendance();
                               } else {
                                  _showSnackBar("Failed to move");
                               }
                             } catch (e) {
                               _showSnackBar("Error: $e");
                             } finally {
                               setState(() => _loading = false);
                             }
                          }
                        }, 
                        child: Text("Move Selected", style: TextStyle(color: textColor, fontWeight: FontWeight.bold))
                      ),
                      const SizedBox(width: 20),
                      GestureDetector(
                       onTap: _toggleSelectAll,
                       child: Text("Select All", style: TextStyle(color: tint, fontWeight: FontWeight.bold)),
                     )
                   ],
                 ),
               ),

               Expanded(
                 child: Stack(
                   children: [
                     Opacity(
                       opacity: (_isLocked && !_isEditing) ? 0.7 : 1.0, // Increased opacity for better readability
                       child: _loading 
                         ? const Center(child: CircularProgressIndicator())
                         : (filtered.isEmpty
                           ? Center(child: Text("No records found", style: TextStyle(color: subTextColor)))
                           : ListView.builder(
                               padding: const EdgeInsets.symmetric(horizontal: 20),
                               itemCount: filtered.length,
                               itemBuilder: (ctx, index) {
                                 final student = filtered[index]; 
                                 final originalIndex = _students.indexOf(student);
                                 final isPresent = student['status'] == 'PRESENT';
                                 
                                 return AbsorbPointer(
                                   absorbing: _isLocked && !_isEditing,
                                   child: GestureDetector(
                                     onTap: () => _toggleStatus(originalIndex),
                                     child: Container(
                                       margin: const EdgeInsets.only(bottom: 10),
                                       padding: const EdgeInsets.all(15),
                                       decoration: BoxDecoration(
                                         color: cardColor,
                                         border: Border(left: BorderSide(color: isPresent ? Colors.green : Colors.red, width: 5)),
                                         borderRadius: BorderRadius.circular(10),
                                       ),
                                       child: Row(
                                         mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                         children: [
                                           Expanded(
                                             child: Column(
                                               crossAxisAlignment: CrossAxisAlignment.start,
                                               children: [
                                                 Text(student['fullName'], style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold)),
                                                 Text(student['studentId'], style: TextStyle(color: subTextColor, fontSize: 12)),
                                               ],
                                             ),
                                           ),
                                           Container(
                                             padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                             decoration: BoxDecoration(
                                               color: (isPresent ? Colors.green : Colors.red).withOpacity(0.2),
                                               borderRadius: BorderRadius.circular(12),
                                             ),
                                             child: Text(student['status'], style: TextStyle(color: isPresent ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 10)),
                                           )
                                         ],
                                       ),
                                     ),
                                   ),
                                 );
                               },
                             )
                         ),
                     ),
                     if (_isLocked && !_isEditing && !_loading)
                       IgnorePointer(
                         child: Center(
                           child: Transform.rotate(
                             angle: -0.5,
                             child: Text(
                               "SUBMITTED",
                               style: GoogleFonts.blackOpsOne(
                                 fontSize: 50,
                                 color: Colors.grey.withOpacity(0.3),
                                 fontWeight: FontWeight.bold
                               ),
                             ),
                           ),
                         ),
                       ),
                   ],
                 ),
               ),
               
               // Footer
               Container(
                 padding: const EdgeInsets.all(20),
                 decoration: BoxDecoration(color: cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
                 child: Column(
                   children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceAround,
                       children: [
                          _buildFooterStat(total.toString(), "Total", subTextColor),
                          _buildFooterStat(present.toString(), "Present", Colors.green),
                          _buildFooterStat(absent.toString(), "Absent", Colors.red),
                       ],
                     ),
                       const SizedBox(height: 15),
                       // Always show Submit/Update button if editable. Correction mode is toggled via AppBar.
                       if (!_isLocked || _isEditing)
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitting ? null : _confirmAndSubmit,
                            style: ElevatedButton.styleFrom(backgroundColor: tint, padding: const EdgeInsets.all(15)),
                            child: _submitting 
                             ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                             : Text(_isLocked ? "Update Attendance" : "Save Attendance", style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                          ),
                        )
                       else
                         // Read-only info
                         Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(15),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.2), borderRadius: BorderRadius.circular(12)),
                            child: Text("Attendance Marked by $_markedBy", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                         )
                   ],
                 ),
               )
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _confirmAndSubmit() async {
    final presentCount = _students.where((s) => s['status'] == 'PRESENT').length;
    final absentCount = _students.length - presentCount;
    
    final bool confirm = await showDialog(
      context: context, 
      builder: (ctx) => AlertDialog(
        title: Text(_isLocked ? "Confirm Update" : "Confirm Submission"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Text(_isLocked ? "Update existing attendance?" : "Submit attendance?"),
             const SizedBox(height: 10),
             Text("Present: $presentCount", style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
             Text("Absent: $absentCount", style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Confirm")),
        ],
      )
    ) ?? false;

    if (confirm) {
      _handleSubmit();
    }
  }

  Widget _buildSessionBtn(String label, String val, bool marked, Color tint, Color textColor) {
     final active = _session == val;
     return Expanded(
       child: GestureDetector(
         onTap: () {
            setState(() { 
              _session = val; 
              _isEditing = false; // Reset editing on session switch
            });
            _fetchAttendance();
         },
         child: Container(
           padding: const EdgeInsets.symmetric(vertical: 8),
           decoration: BoxDecoration(
             color: active ? tint : Colors.transparent,
             borderRadius: BorderRadius.circular(8),
             border: Border.all(color: active ? tint : Colors.transparent)
           ),
           alignment: Alignment.center,
           child: Row(
             mainAxisAlignment: MainAxisAlignment.center,
             children: [
               Text(label, style: TextStyle(color: active ? Colors.white : textColor, fontWeight: FontWeight.bold)),
               if (marked) ...[
                 const SizedBox(width: 4),
                 Icon(Icons.check_circle, size: 12, color: active ? Colors.white : tint)
               ]
             ],
           ),
         ),
       ),
     );
  }

  Widget _buildFooterStat(String val, String label, Color color) {
    return Column(children: [Text(val, style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.bold)), Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12))]);
  }
}
