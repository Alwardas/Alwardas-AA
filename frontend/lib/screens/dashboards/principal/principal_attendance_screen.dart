import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../hod/hod_attendance_screen.dart';

class PrincipalAttendanceScreen extends StatefulWidget {
  const PrincipalAttendanceScreen({super.key});

  @override
  _PrincipalAttendanceScreenState createState() => _PrincipalAttendanceScreenState();
}

class _PrincipalAttendanceScreenState extends State<PrincipalAttendanceScreen> {
  final List<String> branches = [
    "Computer Engineering",
    "Civil Engineering",
    "Mechanical Engineering",
    "Electronics & Communication Engineering",
    "Electrical & Electronics Engineering"
  ];

  Map<String, dynamic> _aggregatedStats = {
    'totalStudents': 0, 
    'totalPresent': 0, 
    'totalAbsent': 0
  };
  Map<String, Map<String, int>> _branchData = {};
  Map<String, bool> _branchCompletionStatus = {};
  
  bool _loadingStats = true;
  DateTime _selectedDate = DateTime.now();
  String _selectedSession = 'Morning';

  @override
  void initState() {
    super.initState();
    // Initialize default data for instant render
    for (var branch in branches) {
      _branchData[branch] = {'total': 0, 'present': 0, 'absent': 0};
    }
    _fetchAggregatedStats();
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
        _loadingStats = true;
      });
      _fetchAggregatedStats();
    }
  }

  Future<void> _fetchAggregatedStats() async {
    final date = _selectedDate.toIso8601String();

    try {
      // Run all branch fetches in parallel
      final List<Map<String, dynamic>> results = await Future.wait(
        branches.map((branch) => _fetchSingleBranchData(branch, date))
      );

      int total = 0;
      int present = 0;
      int absent = 0;
      Map<String, Map<String, int>> branchStats = {};
      Map<String, bool> completionStatus = {};

      for (var result in results) {
        final String branch = result['branch'];
        final Map<String, int> stats = result['stats'];
        final bool isComplete = result['isComplete'];

        total += stats['total']!;
        present += stats['present']!;
        absent += stats['absent']!;
        
        branchStats[branch] = stats;
        completionStatus[branch] = isComplete;
      }

      if (mounted) {
        setState(() {
          _aggregatedStats = {
            'totalStudents': total,
            'totalPresent': present,
            'totalAbsent': absent
          };
          _branchData = branchStats;
          _branchCompletionStatus = completionStatus;
        });
      }
    } catch (e) {
      debugPrint("Error fetching aggregated stats: $e");
    } finally {
      if (mounted) {
        setState(() => _loadingStats = false);
      }
    }
  }

  Future<Map<String, dynamic>> _fetchSingleBranchData(String branch, String date) async {
    try {
      // Define Stats Future
      final statsFuture = http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/attendance/stats').replace(queryParameters: {
          'branch': branch,
          'date': date,
          'session': _selectedSession 
        })
      );

      // Define Year Check Futures
      final yearFutures = ['1st Year', '2nd Year', '3rd Year'].map((year) {
           return http.get(
           Uri.parse('${ApiConstants.baseUrl}/api/attendance/check').replace(queryParameters: {
               'branch': branch,
               'year': year,
               'date': date,
               'session': _selectedSession.toUpperCase()
           })
         );
      });

      // Execute concurrently
      final results = await Future.wait([
        statsFuture,
        ...yearFutures
      ]);

      // 1. Process Stats
      // results[0] is stats
      final statsRes = results[0];
      Map<String, int> stats = {'total': 0, 'present': 0, 'absent': 0};
      
      if (statsRes.statusCode == 200) {
         try {
           final data = json.decode(statsRes.body);
           stats = {
             'total': (data['totalStudents'] as int? ?? 0),
             'present': (data['totalPresent'] as int? ?? 0),
             'absent': (data['totalAbsent'] as int? ?? 0)
           };
         } catch (e) {
           debugPrint("Error parsing stats for $branch: $e");
         }
      }

      // 2. Process Completion (results[1], results[2], results[3])
      bool allYearsMarked = true;
      for (int i = 1; i < results.length; i++) {
         final res = results[i];
         if (res.statusCode == 200) {
            try {
               final data = json.decode(res.body);
               if (data['submitted'] != true) {
                  allYearsMarked = false;
                  break; 
               }
            } catch (e) {
               allYearsMarked = false;
            }
         } else {
            allYearsMarked = false;
         }
      }

      return {
        'branch': branch,
        'stats': stats,
        'isComplete': allYearsMarked
      };
    } catch (e) {
      debugPrint("Error fetching single branch $branch: $e");
      return {
        'branch': branch,
        'stats': {'total': 0, 'present': 0, 'absent': 0},
        'isComplete': false
      };
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

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("College Attendance", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 18)),
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
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              setState(() => _loadingStats = true);
              _fetchAggregatedStats();
            },
          )
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
                Container(
                  margin: const EdgeInsets.only(bottom: 20),
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
                            setState(() {
                              _selectedSession = session;
                              _loadingStats = true;
                            });
                            _fetchAggregatedStats();
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

                // Top Aggregated Stats
                // Removed global loading check; cards always visible
                Builder(
                  builder: (context) {
                    final bool aggLoading = _loadingStats;
                    return Row(
                      children: [
                          _buildStatCard("Total", _aggregatedStats['totalStudents'].toString(), Colors.blue, isLoading: aggLoading),
                          const SizedBox(width: 10),
                          _buildStatCard("Present", _aggregatedStats['totalPresent'].toString(), Colors.green, isLoading: aggLoading),
                          const SizedBox(width: 10),
                          _buildStatCard("Absent", _aggregatedStats['totalAbsent'].toString(), Colors.red, isLoading: aggLoading),
                      ],
                    );
                  }
                ),
                
                const SizedBox(height: 30),
                Text("Branch Overview", style: GoogleFonts.poppins(color: subTextColor, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),

                // Branch Cards List
                ...branches.map((branch) {
                   final stats = _branchData[branch] ?? {'total': 0, 'present': 0, 'absent': 0};
                   final isCompleted = _branchCompletionStatus[branch] ?? false;
                   
                   // If total is 0, assume data is still loading or failed (hide 0)
                   final bool branchLoading = _loadingStats;

                   return GestureDetector(
                     onTap: () {
                       Navigator.push(
                         context, 
                         MaterialPageRoute(
                           builder: (_) => HODAttendanceScreen(
                             forcedBranch: branch,
                             initialDate: _selectedDate,
                             initialSession: _selectedSession, // Pass session to HOD screen 
                           )
                         )
                       );
                     },
                     child: Container(
                       margin: const EdgeInsets.only(bottom: 15),
                       padding: const EdgeInsets.all(20),
                       decoration: BoxDecoration(
                         color: isCompleted ? Colors.green.withValues(alpha: 0.1) : cardColor,
                         borderRadius: BorderRadius.circular(15),
                         border: Border.all(color: isCompleted ? Colors.green : iconBg),
                         boxShadow: [
                           if(isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 5, offset: const Offset(0,2))
                         ]
                       ),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Row(
                             children: [
                               // Color Effect Strip
                               Container(
                                 width: 4, 
                                 height: 40,
                                 decoration: BoxDecoration(
                                   color: isCompleted ? Colors.green : tint,
                                   borderRadius: BorderRadius.circular(2),
                                   boxShadow: [
                                      BoxShadow(
                                        color: (isCompleted ? Colors.green : tint).withValues(alpha: 0.5), 
                                        blurRadius: 6, 
                                        offset: const Offset(0, 0)
                                      )
                                   ]
                                 ),
                               ),
                               const SizedBox(width: 15),
                               Expanded(
                                 child: Text(
                                   branch, 
                                   style: GoogleFonts.poppins(
                                     fontSize: 16, 
                                     fontWeight: FontWeight.bold, 
                                     color: textColor
                                   ),
                                 ),
                               ),
                               if (isCompleted)
                                 const Icon(Icons.check_circle, size: 20, color: Colors.green)
                               else
                                 Icon(Icons.arrow_forward_ios, size: 16, color: subTextColor)
                             ],
                           ),
                           // Always show stats row, use loading indicator for values if needed
                             const SizedBox(height: 15),
                             Row(
                               mainAxisAlignment: MainAxisAlignment.spaceAround,
                               children: [
                                 _buildMiniStat("Total", stats['total'].toString(), subTextColor, isLoading: branchLoading),
                                 _buildMiniStat("Present", stats['present'].toString(), Colors.green, isLoading: branchLoading),
                                 _buildMiniStat("Absent", stats['absent'].toString(), Colors.red, isLoading: branchLoading),
                               ],
                             )
                           ],
                       ),
                     ),
                   );
                }),
                
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMiniStat(String label, String value, Color color, {bool isLoading = false}) {
    return Column(
      children: [
        isLoading 
          ? SizedBox(
              width: 20, 
              height: 20, 
              child: CircularProgressIndicator(strokeWidth: 2, color: color)
            )
          : Text(
              value == "0" ? "-" : value, 
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: color)
            ),
        Text(label, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
      ],
    );
  }

  Widget _buildStatCard(String label, String value, Color color, {bool isLoading = false}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(12)),
        child: Column(
          children: [
            isLoading 
              ? const SizedBox(
                  width: 24, 
                  height: 24, 
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)
                )
              : Text(
                  value == "0" ? "-" : value, 
                  style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)
                ), 
            Text(label, style: const TextStyle(color: Colors.white70))
          ]
        ),
      ),
    );
  }
}
