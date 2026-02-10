                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';

class FacultyScheduleScreen extends StatefulWidget {
  const FacultyScheduleScreen({super.key});

  @override
  _FacultyScheduleScreenState createState() => _FacultyScheduleScreenState();
}

class _FacultyScheduleScreenState extends State<FacultyScheduleScreen> {
  // Mock Data Structure
  final Map<String, List<Map<String, dynamic>>> _scheduleData = {
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

  // Modal State
  bool _modalVisible = false;
  late String _modalDay;
  String _periodNumber = '1';
  String _selectedSubject = '';
  String _customSubject = '';
  List<dynamic> _activeSubjects = [];

  @override
  void initState() {
    super.initState();
    // Default to current day
    int weekday = DateTime.now().weekday; // 1 = Mon, 7 = Sun
    if (weekday > 6) weekday = 1;
    _selectedDay = _days[weekday - 1];
    _modalDay = _selectedDay;

    _fetchActiveSubjects();
  }

  Future<void> _fetchActiveSubjects() async {
    final user = await AuthService.getUserSession();
    if (user == null) return;
    try {
      final res = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/faculty/subjects?userId=${user['id']}'));
      if (res.statusCode == 200) {
        final List<dynamic> subs = json.decode(res.body);
        setState(() {
          _activeSubjects = subs.where((s) => (s['status'] == 'ACTIVE' || s['status'] == 'active')).toList();
        });
      }
    } catch (e) {
      print("Failed to fetch subjects: $e");
    }
  }

  void _handleAddClass() {
    final subjectToAdd = _customSubject.trim().isNotEmpty ? _customSubject : _selectedSubject;
    if (subjectToAdd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select or enter a subject.")));
      return;
    }

    setState(() {
      final daySchedule = _scheduleData[_modalDay]!;
      final index = daySchedule.indexWhere((p) => p['number'] == int.parse(_periodNumber));
      
      if (index != -1) {
        daySchedule[index] = {
           ...daySchedule[index],
           'subject': subjectToAdd
        };
      } else {
        // Should not happen for standard layout
      }
      
      _modalVisible = false;
      _customSubject = '';
      _selectedSubject = '';
    });
  }

  void _handleClearClass(String day, String id) {
     setState(() {
       final daySchedule = _scheduleData[day]!;
       final index = daySchedule.indexWhere((p) => p['id'] == id);
       if (index != -1) {
         daySchedule[index] = { ...daySchedule[index], 'subject': '---' };
       }
     });
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
        title: Text("My Schedule", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: CircleAvatar(backgroundColor: tint, child: const Icon(Icons.add, color: Colors.white)),
            onPressed: () {
               setState(() => _modalDay = _selectedDay);
               setState(() => _modalVisible = true);
            },
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Day Selector
                  Padding(
                     padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                     child: GestureDetector(
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
                  ),
                  
                  Expanded(
                    child: SingleChildScrollView( // Changed to Scrollable Grid
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      child: Wrap(
                        spacing: 12,
                        runSpacing: 12,
                        children: currentSchedule.map((item) {
                           final width = (MediaQuery.of(context).size.width - 40 - 12) / 2; // 2 columns
                           
                           if (item['type'] != 'class') {
                             return Container(
                               width: double.infinity,
                               padding: const EdgeInsets.symmetric(vertical: 8),
                               margin: const EdgeInsets.symmetric(vertical: 10),
                               decoration: BoxDecoration(
                                 border: Border.all(color: tint.withOpacity(0.5)),
                                 borderRadius: BorderRadius.circular(50),
                               ),
                               alignment: Alignment.center,
                               child: Text(item['label'], style: GoogleFonts.poppins(color: tint, fontWeight: FontWeight.bold, letterSpacing: 4)),
                             );
                           }

                           return GestureDetector(
                             onLongPress: () {
                               if (item['subject'] != '---') {
                                 showDialog(
                                   context: context, 
                                   builder: (ctx) => AlertDialog(
                                     title: const Text("Clear Class?"),
                                     content: const Text("Are you sure?"),
                                     actions: [
                                       TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                       TextButton(onPressed: () { _handleClearClass(_selectedDay, item['id']); Navigator.pop(ctx); }, child: const Text("Clear")),
                                     ],
                                   )
                                 );
                               }
                             },
                             child: Container(
                               width: width,
                               padding: const EdgeInsets.all(16),
                               decoration: BoxDecoration(
                                 color: cardColor,
                                 border: Border.all(color: iconBg),
                                 borderRadius: BorderRadius.circular(16),
                               ),
                               child: Column(
                                 children: [
                                   Text("Period ${item['number']}", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w600)),
                                   const SizedBox(height: 5),
                                   Text(item['time'], style: GoogleFonts.poppins(color: tint, fontSize: 12)),
                                   const SizedBox(height: 10),
                                   Text(item['subject'], 
                                     textAlign: TextAlign.center,
                                     style: GoogleFonts.poppins(color: textColor, fontSize: 18, fontWeight: FontWeight.bold),
                                     maxLines: 2, 
                                     overflow: TextOverflow.ellipsis
                                   ),
                                 ],
                               ),
                             ),
                           );
                        }).toList(),
                      ),
                    ),
                  )
                ],
              ),

              if (_dropdownVisible) 
                Positioned(
                  top: 60, left: 20,
                  child: Container(
                    width: 150,
                    decoration: BoxDecoration(color: isDark ? const Color(0xFF24243e) : Colors.white, borderRadius: BorderRadius.circular(12), boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)]),
                    child: Column(
                      children: _days.map((day) => ListTile(
                        title: Text(day, style: TextStyle(color: day == _selectedDay ? tint : textColor, fontWeight: day == _selectedDay ? FontWeight.bold : FontWeight.normal)),
                        onTap: () => setState(() { _selectedDay = day; _dropdownVisible = false; }),
                        dense: true,
                      )).toList(),
                    ),
                  ),
                ),
                
              if (_modalVisible)
                _buildModal(textColor, subTextColor, isDark ? const Color(0xFF24243e) : Colors.white, tint, iconBg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModal(Color textColor, Color subTextColor, Color modalBg, Color tint, Color iconBg) {
    return Container(
      color: Colors.black54,
      alignment: Alignment.bottomCenter,
      child: Container(
        height: 500,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: modalBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                 const Text("Add Class", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                 IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _modalVisible = false))
               ],
             ),
             
             // Day Selector Horizontal
             const Text("Select Day", style: TextStyle(fontWeight: FontWeight.bold)),
             const SizedBox(height: 10),
             SingleChildScrollView(
               scrollDirection: Axis.horizontal,
               child: Row(
                 children: _days.map((day) => GestureDetector(
                   onTap: () => setState(() => _modalDay = day),
                   child: Container(
                     margin: const EdgeInsets.only(right: 10),
                     padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                     decoration: BoxDecoration(
                       color: _modalDay == day ? tint : Colors.transparent,
                       border: Border.all(color: iconBg),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: Text(day.substring(0,3), style: TextStyle(color: _modalDay == day ? Colors.white : textColor)),
                   ),
                 )).toList(),
               ),
             ),

             const SizedBox(height: 20),
             const Text("Select Period (1-8)", style: TextStyle(fontWeight: FontWeight.bold)),
             const SizedBox(height: 10),
             Wrap( // Period Grid
               spacing: 10, runSpacing: 10,
               children: List.generate(8, (index) {
                 final num = (index + 1).toString();
                 return GestureDetector(
                   onTap: () => setState(() => _periodNumber = num),
                   child: Container(
                     width: 40, height: 40,
                     alignment: Alignment.center,
                     decoration: BoxDecoration(
                        color: _periodNumber == num ? tint : Colors.transparent,
                        border: Border.all(color: iconBg),
                        borderRadius: BorderRadius.circular(20)
                     ),
                     child: Text(num, style: TextStyle(color: _periodNumber == num? Colors.white : textColor, fontWeight: FontWeight.bold)),
                   ),
                 );
               }),
             ),

             const SizedBox(height: 20),
             // Subject Choice
             const Text("Active Subjects", style: TextStyle(fontWeight: FontWeight.bold)),
             const SizedBox(height: 10),
             SizedBox(
               height: 50,
               child: ListView(
                 scrollDirection: Axis.horizontal,
                 children: _activeSubjects.map((sub) => GestureDetector(
                   onTap: () => setState(() { _selectedSubject = sub['name']; _customSubject = ''; }),
                   child: Container(
                     margin: const EdgeInsets.only(right: 10),
                     padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                     decoration: BoxDecoration(
                        color: _selectedSubject == sub['name'] ? tint : Colors.transparent,
                        border: Border.all(color: tint),
                        borderRadius: BorderRadius.circular(20),
                     ),
                     child: Text(sub['name'], style: TextStyle(color: _selectedSubject == sub['name'] ? Colors.white : textColor)),
                   ),
                 )).toList(),
               ),
             ),
             
             const SizedBox(height: 10),
             TextField(
               onChanged: (v) => setState(() { _customSubject = v; if (v.isNotEmpty) _selectedSubject = ''; }),
               style: TextStyle(color: textColor),
               decoration: InputDecoration(
                 hintText: "Or enter custom subject...",
                 hintStyle: TextStyle(color: subTextColor),
                 border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
               ),
             ),
             
             const Spacer(),
             SizedBox(
               width: double.infinity,
               child: ElevatedButton(
                 onPressed: _handleAddClass,
                 style: ElevatedButton.styleFrom(backgroundColor: tint, padding: const EdgeInsets.all(15)),
                 child: const Text("Add to Schedule", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
               ),
             )
          ],
        ),
      ),
    );
  }
}
