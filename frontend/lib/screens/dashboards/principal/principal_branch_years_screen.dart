import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../hod/hod_manage_attendance_screen.dart';

class PrincipalBranchYearsScreen extends StatefulWidget {
  final String branchName;
  final DateTime? initialDate;
  const PrincipalBranchYearsScreen({super.key, required this.branchName, this.initialDate});

  @override
  _PrincipalBranchYearsScreenState createState() => _PrincipalBranchYearsScreenState();
}

class _PrincipalBranchYearsScreenState extends State<PrincipalBranchYearsScreen> {
  Map<String, dynamic> _stats = {'totalStudents': 0, 'totalPresent': 0, 'totalAbsent': 0};
  Map<String, bool> _attendanceStatus = {
    '1st Year': false,
    '2nd Year': false,
    '3rd Year': false
  };

  String _selectedSession = 'All'; 
  bool _loading = false;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.initialDate ?? DateTime.now();
    _fetchStats();
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
        _loading = true;
      });
      _fetchStats();
    }
  }

  Future<void> _fetchStats() async {
    setState(() => _loading = true);
    final date = _selectedDate.toIso8601String();
    
    // 1. Fetch Stats for Selected Branch
    try {
      final queryParams = {
        'branch': widget.branchName,
        'date': date,
      };
      
      if (_selectedSession != 'All') {
        queryParams['session'] = _selectedSession.toUpperCase();
      } else {
        queryParams['session'] = 'ALL';
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/attendance/stats').replace(queryParameters: queryParams);
      final res = await http.get(uri);

      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _stats = {
              'totalStudents': data['totalStudents'] ?? 0,
              'totalPresent': data['totalPresent'] ?? 0,
              'totalAbsent': data['totalAbsent'] ?? 0
            };
          });
        }
      }
    } catch (e) {
      print("Fetch Stats Error: $e");
    }

    // 2. Fetch Status for Years for Selected Branch
    Map<String, bool> newStatus = {
      '1st Year': false,
      '2nd Year': false,
      '3rd Year': false
    };

    for (String year in ['1st Year', '2nd Year', '3rd Year']) {
      try {
         String sessionToCheck = (_selectedSession == 'All') ? 'MORNING' : _selectedSession.toUpperCase();

         final uri = Uri.parse('${ApiConstants.baseUrl}/api/attendance/check').replace(queryParameters: {
           'branch': widget.branchName,
           'year': year,
           'date': date,
           'session': sessionToCheck
         });

         final res = await http.get(uri);
         if (res.statusCode == 200) {
            final data = json.decode(res.body);
            newStatus[year] = data['submitted'] ?? false;
         }
      } catch (e) {
         print("Fetch Status Error ($year): $e");
      }
    }
    
    if (mounted) {
      setState(() {
      _attendanceStatus = newStatus;
      _loading = false;
    });
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
    
    bool noAttendance = (_stats['totalPresent'] == 0 && _stats['totalAbsent'] == 0);
    String absentText = noAttendance && _stats['totalStudents'] > 0 ? "-" : _stats['totalAbsent'].toString();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.branchName, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 18)),
            Text(
              "${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}", 
              style: GoogleFonts.poppins(fontSize: 12, color: subTextColor)
            )
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: () => _selectDate(context),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Session Selector
                Center(
                  child: Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(25),
                      border: Border.all(color: iconBg)
                    ),
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

                // Stats Cards
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 20.0),
                    child: Center(child: CircularProgressIndicator()),
                  )
                else
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
                
                Text("${widget.branchName} Years", style: GoogleFonts.poppins(color: subTextColor, fontSize: 16)),
                const SizedBox(height: 20),
                
                ...['1st Year', '2nd Year', '3rd Year'].map((year) {
                    final isMarked = _attendanceStatus[year] ?? false; 
                    return GestureDetector(
                      onTap: () async {
                        // Navigate directly to Managed screen with Override
                        await Navigator.push(
                          context, 
                          MaterialPageRoute(
                            builder: (_) => HODManageAttendanceScreen(
                              year: year, 
                              initialSession: _selectedSession,
                              branchOverride: widget.branchName, 
                            )
                          )
                        );
                        _fetchStats();
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
                                    Text("View / Mark", style: GoogleFonts.poppins(color: subTextColor)),
                                ],
                              ),
                            ),
                            Icon(Icons.chevron_right, color: isMarked ? Colors.green : subTextColor)
                          ],
                        ),
                      ),
                    );
                }),
              ],
            ),
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
}
