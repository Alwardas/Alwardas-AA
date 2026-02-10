import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import 'principal_branch_years_screen.dart';

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
    "Electronics and Communication Engineering",
    "Electrical and Electronics Engineering"
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

  @override
  void initState() {
    super.initState();
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
        _loadingStats = false;
      });
    }
  }

  Future<Map<String, dynamic>> _fetchSingleBranchData(String branch, String date) async {
    // Define Stats Future
    final statsFuture = http.get(
      Uri.parse('${ApiConstants.baseUrl}/api/attendance/stats').replace(queryParameters: {
        'branch': branch,
        'date': date,
        'session': 'ALL' 
      })
    );

    // Define Year Check Futures
    final yearFutures = ['1st Year', '2nd Year', '3rd Year'].map((year) {
       return http.get(
         Uri.parse('${ApiConstants.baseUrl}/api/attendance/check').replace(queryParameters: {
             'branch': branch,
             'year': year,
             'date': date,
             'session': 'MORNING'
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
                break; // Optimization: one false means incomplete
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
                // Top Aggregated Stats
                if (_loadingStats)
                   const Center(child: Padding(padding: EdgeInsets.all(20.0), child: CircularProgressIndicator()))
                else
                  Row(
                    children: [
                        _buildStatCard("Total", _aggregatedStats['totalStudents'].toString(), Colors.blue),
                        const SizedBox(width: 10),
                        _buildStatCard("Present", _aggregatedStats['totalPresent'].toString(), Colors.green),
                        const SizedBox(width: 10),
                        _buildStatCard("Absent", _aggregatedStats['totalAbsent'].toString(), Colors.red),
                    ],
                  ),
                
                const SizedBox(height: 30),
                Text("Branch Overview", style: GoogleFonts.poppins(color: subTextColor, fontSize: 16, fontWeight: FontWeight.bold)),
                const SizedBox(height: 15),

                // Branch Cards List
                ...branches.map((branch) {
                   final stats = _branchData[branch] ?? {'total': 0, 'present': 0, 'absent': 0};
                   final isCompleted = _branchCompletionStatus[branch] ?? false;
                   
                   return GestureDetector(
                     onTap: () {
                       Navigator.push(
                         context, 
                         MaterialPageRoute(
                           builder: (_) => PrincipalBranchYearsScreen(
                             branchName: branch,
                             initialDate: _selectedDate, 
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
                           if (_branchData.isNotEmpty) ...[
                             const SizedBox(height: 15),
                             Row(
                               mainAxisAlignment: MainAxisAlignment.spaceAround,
                               children: [
                                 _buildMiniStat("Total", stats['total'].toString(), subTextColor),
                                 _buildMiniStat("Present", stats['present'].toString(), Colors.green),
                                 _buildMiniStat("Absent", stats['absent'].toString(), Colors.red),
                               ],
                             )
                           ]
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
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold)), 
            Text(label, style: const TextStyle(color: Colors.white70))
          ]
        ),
      ),
    );
  }
}
