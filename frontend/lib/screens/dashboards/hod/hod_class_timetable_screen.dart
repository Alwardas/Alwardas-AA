import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/api_constants.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import 'hod_assign_class_screen.dart';

class HodClassTimetableScreen extends StatefulWidget {
  final String branch;
  final String year;
  final String section;

  const HodClassTimetableScreen({
    super.key,
    required this.branch,
    required this.year,
    required this.section,
  });

  @override
  _HodClassTimetableScreenState createState() => _HodClassTimetableScreenState();
}

class _HodClassTimetableScreenState extends State<HodClassTimetableScreen> {
  // Data Structure
  Map<String, List<Map<String, dynamic>>> _scheduleData = {};

  Map<int, Map<String, String>> _periodTimes = {
      1: {'start': '09:00', 'end': '09:50'},
      2: {'start': '09:50', 'end': '10:40'},
      3: {'start': '11:00', 'end': '11:50'},
      4: {'start': '11:50', 'end': '12:40'},
      5: {'start': '13:30', 'end': '14:20'},
      6: {'start': '14:20', 'end': '15:10'},
      7: {'start': '15:30', 'end': '16:20'},
      8: {'start': '16:20', 'end': '17:10'},
  };

  List<dynamic> _slotConfig = [];

  List<Map<String, dynamic>> _getEmptyDay() {
    List<Map<String, dynamic>> slots = [];
    
    if (_slotConfig.isEmpty) {
      slots.add({'id': 'p1', 'type': 'class', 'number': 1, 'time': '${_periodTimes[1]?['start']}-${_periodTimes[1]?['end']}', 'subject': '---', 'faculty': ''});
      slots.add({'id': 'p2', 'type': 'class', 'number': 2, 'time': '${_periodTimes[2]?['start']}-${_periodTimes[2]?['end']}', 'subject': '---', 'faculty': ''});
      slots.add({'id': 'b1', 'type': 'break', 'label': 'B R E A K'});
      slots.add({'id': 'p3', 'type': 'class', 'number': 3, 'time': '${_periodTimes[3]?['start']}-${_periodTimes[3]?['end']}', 'subject': '---', 'faculty': ''});
      slots.add({'id': 'p4', 'type': 'class', 'number': 4, 'time': '${_periodTimes[4]?['start']}-${_periodTimes[4]?['end']}', 'subject': '---', 'faculty': ''});
      slots.add({'id': 'l1', 'type': 'lunch', 'label': 'L U N C H'});
      slots.add({'id': 'p5', 'type': 'class', 'number': 5, 'time': '${_periodTimes[5]?['start']}-${_periodTimes[5]?['end']}', 'subject': '---', 'faculty': ''});
      slots.add({'id': 'p6', 'type': 'class', 'number': 6, 'time': '${_periodTimes[6]?['start']}-${_periodTimes[6]?['end']}', 'subject': '---', 'faculty': ''});
      slots.add({'id': 'b2', 'type': 'break', 'label': 'B R E A K'});
      slots.add({'id': 'p7', 'type': 'class', 'number': 7, 'time': '${_periodTimes[7]?['start']}-${_periodTimes[7]?['end']}', 'subject': '---', 'faculty': ''});
      slots.add({'id': 'p8', 'type': 'class', 'number': 8, 'time': '${_periodTimes[8]?['start']}-${_periodTimes[8]?['end']}', 'subject': '---', 'faculty': ''});
    } else {
        int pNum = 1;
        int bNum = 1;
        int lNum = 1;
        for (var type in _slotConfig) {
            if (type == 'P') {
                if (_periodTimes.containsKey(pNum)) {
                   slots.add({'id': 'p$pNum', 'type': 'class', 'number': pNum, 'time': '${_periodTimes[pNum]!['start']}-${_periodTimes[pNum]!['end']}', 'subject': '---', 'faculty': ''});
                }
                pNum++;
            } else if (type == 'SB') {
                slots.add({'id': 'b$bNum', 'type': 'break', 'label': 'B R E A K'});
                bNum++;
            } else if (type == 'LB') {
                slots.add({'id': 'l$lNum', 'type': 'lunch', 'label': 'L U N C H'});
                lNum++;
            }
        }
    }
    return slots;
  }

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  late String _selectedDay;
  bool _dropdownVisible = false;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    int weekday = DateTime.now().weekday; // 1 = Mon, 7 = Sun
    if (weekday > 6) weekday = 1;
    _selectedDay = _days[weekday - 1];
    _loadSettings().then((_) => _fetchTimetable());
  }

  Future<void> _loadSettings() async {
    int startHour = 9;
    int startMinute = 0;
    int classDuration = 50;
    int shortBreakDuration = 10;
    int lunchDuration = 50;
    List<dynamic> slotConfig = []; // Will store ['P', 'P', 'SB', ...]

    try {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/department/timing').replace(queryParameters: {'branch': widget.branch});
        final res = await http.get(uri);
        if (res.statusCode == 200) {
            final List<dynamic> listData = json.decode(res.body);
            if (listData.isNotEmpty) {
                final data = listData[0];
                startHour = data['start_hour'] ?? 9;
                startMinute = data['start_minute'] ?? 0;
                classDuration = data['class_duration'] ?? 50;
                shortBreakDuration = data['short_break_duration'] ?? 10;
                lunchDuration = data['lunch_duration'] ?? 50;
                if (data['slot_config'] != null) {
                   slotConfig = List<dynamic>.from(data['slot_config']);
                }
            }
        } else {
             // Fallback to shared prefs ... (simplified for brevity, assume default if offline)
             final prefs = await SharedPreferences.getInstance();
             final branch = widget.branch;
             startHour = prefs.getInt('timing_start_hour_$branch') ?? 9;
             // ... other preferences
        }
    } catch (e) {
         debugPrint("Error fetching timings: $e");
         final prefs = await SharedPreferences.getInstance();
         final branch = widget.branch;
         startHour = prefs.getInt('timing_start_hour_$branch') ?? 9;
         // ...
    }
    
    // Recalculate _periodTimes
    DateTime time = DateTime(2026, 1, 1, startHour, startMinute);
    Map<int, Map<String, String>> newPeriodTimes = {};
    String formatTime(DateTime t) => DateFormat('hh:mm a').format(t);

    if (slotConfig.isNotEmpty) {
        _slotConfig = slotConfig;
        int pNum = 1;
        for (var type in slotConfig) {
            DateTime start = time;
            int duration = 0;
            if (type == 'P') duration = classDuration;
            else if (type == 'SB') duration = shortBreakDuration;
            else if (type == 'LB') duration = lunchDuration;
            
            time = time.add(Duration(minutes: duration));
            
            if (type == 'P') {
                newPeriodTimes[pNum] = {
                    'start': formatTime(start),
                    'end': formatTime(time),
                };
                pNum++;
            }
        }
    } else {
        // Fallback Logic (Old)
        for (int p = 1; p <= 8; p++) {
           DateTime start = time;
           time = time.add(Duration(minutes: classDuration));
           newPeriodTimes[p] = {
             'start': formatTime(start),
             'end': formatTime(time),
           };
           
           if (p == 2 || p == 6) {
              time = time.add(Duration(minutes: shortBreakDuration));
           } else if (p == 4) {
              time = time.add(Duration(minutes: lunchDuration));
           }
        }
    }
    
    if (mounted) {
      setState(() {
        _periodTimes = newPeriodTimes;
        _scheduleData = {
          'Monday': _getEmptyDay(),
          'Tuesday': _getEmptyDay(),
          'Wednesday': _getEmptyDay(),
          'Thursday': _getEmptyDay(),
          'Friday': _getEmptyDay(),
          'Saturday': _getEmptyDay(),
        };
      });
    }
  }

  Future<void> _fetchTimetable() async {
      try {
          final uri = Uri.parse('${ApiConstants.baseUrl}/api/timetable').replace(queryParameters: {
            'branch': widget.branch,
            'year': widget.year,
            'section': widget.section
          });
          
          final res = await http.get(uri);
          if (res.statusCode == 200) {
              final List<dynamic> data = json.decode(res.body);
              
              Map<String, List<Map<String, dynamic>>> newSchedule = {};
              for (var d in _days) {
                newSchedule[d] = _getEmptyDay();
              }
              
              for (var item in data) {
                  String day = item['day'];
                  if (newSchedule.containsKey(day)) {
                      int pNum = item['period_index'] ?? item['periodIndex'] ?? 0;
                      var daySlots = newSchedule[day]!;
                      for (var slot in daySlots) {
                          if (slot['type'] == 'class' && slot['number'] == pNum) {
                              slot['id'] = item['id']; 
                              slot['subject'] = item['subject'];
                          }
                      }
                  }
              }
              if (mounted) setState(() => _scheduleData = newSchedule);
          }
      } catch (e) {
          debugPrint("Fetch Timetable Error: $e");
      }
  }

  // _handleAddClass removed in favor of HodAssignClassScreen

  Future<void> _handleClearClass(String day, int periodIndex) async {
    try {
        final body = {
            'facultyId': 'dummy',
            'branch': widget.branch,
            'year': widget.year,
            'section': widget.section,
            'day': day,
            'periodIndex': periodIndex,
            'subject': 'clear'
        };

        final res = await http.post(
            Uri.parse('${ApiConstants.baseUrl}/api/timetable/clear'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body)
        );
        
        if (res.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Class Cleared")));
            _fetchTimetable();
        } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to clear")));
        }
    } catch (e) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network Error")));
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
        title: Column(
          children: [
            Text("Class Timetable", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 16)),
            Text("${widget.year} • ${widget.branch} • Sec ${widget.section}", style: GoogleFonts.poppins(fontSize: 10, color: subTextColor))
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
        actions: [
          IconButton(
            icon: CircleAvatar(backgroundColor: tint, child: const Icon(Icons.add, color: Colors.white)),
            onPressed: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => HodAssignClassScreen(
                    branch: widget.branch,
                    year: widget.year,
                    section: widget.section,
                    initialDay: _selectedDay,
                  ),
                ),
              );
              if (result == true) _fetchTimetable();
            },
            tooltip: "Assign Class",
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
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(horizontal: 20),
                      physics: const BouncingScrollPhysics(),
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

                          // Class Item
                          final hasClass = item['subject'] != '---';

                          return GestureDetector(
                            onTap: () async {
                              if (!hasClass) {
                                final result = await Navigator.push(
                                  context, 
                                  MaterialPageRoute(
                                    builder: (_) => HodAssignClassScreen(
                                      branch: widget.branch,
                                      year: widget.year,
                                      section: widget.section,
                                      initialDay: _selectedDay,
                                      initialPeriod: item['number'] as int,
                                    )
                                  )
                                );
                                if (result == true) _fetchTimetable();
                              }
                            },
                            onLongPress: () {
                              if (hasClass) {
                                showDialog(
                                    context: context,
                                    builder: (ctx) => AlertDialog(
                                          title: const Text("Clear Class?"),
                                          content: const Text("Remove this class assignment?"),
                                          actions: [
                                            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                                            TextButton(
                                                onPressed: () {
                                                  _handleClearClass(_selectedDay, item['number']);
                                                  Navigator.pop(ctx);
                                                },
                                                child: const Text("Clear", style: TextStyle(color: Colors.red))),
                                          ],
                                        ));
                              }
                            },
                            child: Container(
                              width: width,
                              padding: const EdgeInsets.all(16),
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
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: tint.withValues(alpha: 0.1),
                                      borderRadius: BorderRadius.circular(6)
                                    ),
                                    child: Text("Period ${item['number']}", style: GoogleFonts.poppins(color: tint, fontWeight: FontWeight.bold, fontSize: 10)),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(item['time'], style: GoogleFonts.poppins(color: subTextColor, fontSize: 11)),
                                  const SizedBox(height: 12),
                                  Text(item['subject'],
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(color: hasClass ? textColor : subTextColor.withValues(alpha: 0.5), fontSize: 16, fontWeight: FontWeight.bold),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis),
                                  if (hasClass && item['faculty'] != null && item['faculty'].isNotEmpty) ...[
                                    const SizedBox(height: 4),
                                    Text("(${item['faculty']})", style: GoogleFonts.poppins(color: subTextColor, fontSize: 12)),
                                  ]
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

              // Dropdown
              if (_dropdownVisible)
                Positioned(
                  top: 60,
                  left: 20,
                  child: Container(
                    width: 150,
                    decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF24243e) : Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: const [BoxShadow(blurRadius: 10, color: Colors.black26)]),
                    child: Column(
                      children: _days
                          .map((day) => ListTile(
                                title: Text(day,
                                    style: TextStyle(
                                        color: day == _selectedDay ? tint : textColor, fontWeight: day == _selectedDay ? FontWeight.bold : FontWeight.normal)),
                                onTap: () => setState(() {
                                  _selectedDay = day;
                                  _dropdownVisible = false;
                                }),
                                dense: true,
                              ))
                          .toList(),
                    ),
                  ),
                ),

              // Modal removed
            ],
          ),
        ),
      ),
    );
  }

  // _buildModal removed
}
