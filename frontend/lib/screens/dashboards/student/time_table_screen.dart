import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';

class TimeTableScreen extends StatefulWidget {
  const TimeTableScreen({super.key});

  @override
  _TimeTableScreenState createState() => _TimeTableScreenState();
}

class _TimeTableScreenState extends State<TimeTableScreen> {
  // Mock Data Structure
  Map<String, List<Map<String, dynamic>>> _scheduleData = {
    'Monday': _getStandardDay(),
    'Tuesday': _getStandardDay(),
    'Wednesday': _getStandardDay(),
    'Thursday': _getStandardDay(),
    'Friday': _getStandardDay(),
    'Saturday': _getStandardDay(),
  };

  static List<Map<String, dynamic>> _getStandardDay() => [
    {'id': '1', 'type': 'class', 'number': 1, 'time': '9:00-9:50', 'subject': '---'},
    {'id': '2', 'type': 'class', 'number': 2, 'time': '9:50-10:40', 'subject': '---'},
    {'id': 'b1', 'type': 'break', 'label': 'B R E A K'},
    {'id': '3', 'type': 'class', 'number': 3, 'time': '11:00-11:50', 'subject': '---'},
    {'id': '4', 'type': 'class', 'number': 4, 'time': '11:50-12:40', 'subject': '---'},
    {'id': 'l1', 'type': 'lunch', 'label': 'L U N C H'},
    {'id': '5', 'type': 'class', 'number': 5, 'time': '1:30-2:20', 'subject': '---'},
    {'id': '6', 'type': 'class', 'number': 6, 'time': '2:20-3:10', 'subject': '---'},
    {'id': 'b2', 'type': 'break', 'label': 'B R E A K'},
    {'id': '7', 'type': 'class', 'number': 7, 'time': '3:30-4:20', 'subject': '---'},
    {'id': '8', 'type': 'class', 'number': 8, 'time': '4:20-5:10', 'subject': '---'},
  ];

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  late String _selectedDay;
  bool _dropdownVisible = false;

  // Student Data
  String? _studentYear;
  String? _studentBranch;
  String? _studentSection;

  @override
  void initState() {
    super.initState();
    // Default to current day
    int weekday = DateTime.now().weekday; // 1 = Mon, 7 = Sun
    if (weekday > 6) weekday = 1;
    _selectedDay = _days[weekday - 1];
    
    _fetchStudentProfile();
  }

  Future<void> _fetchStudentProfile() async {
    final user = await AuthService.getUserSession();
    if (user != null) {
      if (mounted) {
        setState(() {
          // Rule: Read only the year (e.g., "2nd Year"). Ignore semester.
          _studentYear = user['year'] ?? '';
          _studentBranch = user['branch'];
          _studentSection = user['section'] ?? 'Section A';
        });
        
        if (_studentYear != null && _studentBranch != null) {
           _fetchTimetableForYear(_studentYear!, _studentBranch!, _studentSection!);
        }
      }
    }
  }

  Future<void> _fetchTimetableForYear(String year, String branch, String section) async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/timetable').replace(queryParameters: {
        'branch': branch,
        'year': year,
        'section': section,
      });
      
      final res = await http.get(uri);
      
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        
        // Reset to standard empty schedule
        Map<String, List<Map<String, dynamic>>> newSchedule = {};
        for (var day in _days) {
            newSchedule[day] = _getStandardDay();
        }
        
        // Populate with fetched data
        for (var item in data) {
           String day = item['day'];
           if (newSchedule.containsKey(day)) {
             int period = item['period_index'] ?? item['periodIndex'] ?? 0;
             var daySlots = newSchedule[day]!;
             
             for (var slot in daySlots) {
                if (slot['type'] == 'class' && slot['number'] == period) {
                   String subjectStr = item['subject'] ?? '';
                   String facName = item['faculty_name'] ?? '';
                   
                   if (facName.isEmpty && subjectStr.contains('(') && subjectStr.endsWith(')')) {
                       int idx = subjectStr.lastIndexOf('(');
                       facName = subjectStr.substring(idx + 1, subjectStr.length - 1);
                       subjectStr = subjectStr.substring(0, idx).trim();
                   }
                   
                   slot['subject'] = subjectStr;
                   slot['facultyName'] = facName;
                }
             }
           }
        }

        if (mounted) {
          setState(() {
            _scheduleData = newSchedule;
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching timetable: $e");
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

    final currentSchedule = _scheduleData[_selectedDay] ?? [];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Time Table ${_studentYear != null ? ' - $_studentYear' : ''}", 
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 18)
        ),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        automaticallyImplyLeading: false, // Ensure no back button conflict if standalone
        leading: Navigator.canPop(context) ? IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)) : null,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Day Selector
              Padding(
                 padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                 child: Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                     GestureDetector(
                       onTap: () => setState(() => _dropdownVisible = !_dropdownVisible),
                       child: Container(
                         padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                         decoration: BoxDecoration(
                           color: iconBg,
                           borderRadius: BorderRadius.circular(12),
                           border: Border.all(color: Colors.white10),
                         ),
                         child: Row(
                           mainAxisSize: MainAxisSize.min,
                           children: [
                             Text(_selectedDay, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                             const SizedBox(width: 10),
                             Icon(_dropdownVisible ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: textColor)
                           ],
                         ),
                       ),
                     ),
                   ],
                 ),
              ),
              
              if (_dropdownVisible) 
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 20),
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: isDark ? const Color(0xFF24243e) : Colors.white, 
                    borderRadius: BorderRadius.circular(12), 
                    boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)]
                  ),
                  child: Column(
                    children: _days.map((day) => ListTile(
                      title: Text(day, style: TextStyle(color: day == _selectedDay ? tint : textColor, fontWeight: day == _selectedDay ? FontWeight.bold : FontWeight.normal)),
                      onTap: () => setState(() { _selectedDay = day; _dropdownVisible = false; }),
                      dense: true,
                    )).toList(),
                  ),
                ),

              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 120),
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: currentSchedule.map((item) {
                       final width = (MediaQuery.of(context).size.width - 40 - 12) / 2; 
                       
                       if (item['type'] != 'class') {
                         return Container(
                           width: double.infinity,
                           padding: const EdgeInsets.symmetric(vertical: 8),
                           margin: const EdgeInsets.symmetric(vertical: 10),
                           decoration: BoxDecoration(
                             border: Border.all(color: tint.withValues(alpha: 0.5)),
                             borderRadius: BorderRadius.circular(50),
                           ),
                           alignment: Alignment.center,
                           child: Text(item['label'], style: GoogleFonts.poppins(color: tint, fontWeight: FontWeight.bold, letterSpacing: 4)),
                         );
                       }

                       // Class Item (Read Only)
                       final hasClass = item['subject'] != '---';
                       
                       return Container(
                         width: width,
                         height: 100, // Fixed height for uniformity
                         padding: const EdgeInsets.all(12),
                         decoration: BoxDecoration(
                           color: cardColor,
                           border: Border.all(color: hasClass ? tint.withValues(alpha: 0.3) : iconBg),
                           borderRadius: BorderRadius.circular(16),
                           boxShadow: [
                             if (hasClass)
                               BoxShadow(
                                 color: tint.withValues(alpha: 0.1),
                                 blurRadius: 8,
                                 offset: const Offset(0, 4),
                               )
                           ]
                         ),
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Row(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Expanded(
                                   flex: 3,
                                   child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                       Container(
                                         padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                         decoration: BoxDecoration(
                                           color: tint.withValues(alpha: 0.1),
                                           borderRadius: BorderRadius.circular(4)
                                         ),
                                         child: Text("P${item['number']} • ${item['time']}", style: GoogleFonts.poppins(color: tint, fontWeight: FontWeight.bold, fontSize: 9)),
                                       ),
                                     ],
                                   ),
                                 ),
                                 if (hasClass && item['facultyName'] != null && item['facultyName'].toString().isNotEmpty) ...[
                                   const SizedBox(width: 4),
                                   Expanded(
                                     flex: 2,
                                     child: Text(
                                       item['facultyName'], 
                                       textAlign: TextAlign.right, 
                                       style: GoogleFonts.poppins(color: subTextColor, fontSize: 9, fontWeight: FontWeight.w500), 
                                       maxLines: 2, 
                                       overflow: TextOverflow.ellipsis
                                     ),
                                   ),
                                 ]
                               ],
                             ),
                             const Spacer(),
                             Text(
                               item['subject'], 
                               style: GoogleFonts.poppins(
                                 color: hasClass ? textColor : subTextColor.withValues(alpha: 0.5), 
                                 fontSize: 13, 
                                 fontWeight: FontWeight.bold
                               ),
                               maxLines: 2,
                               overflow: TextOverflow.ellipsis
                             ),
                           ],
                         ),
                       );
                    }).toList(),
                  ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
