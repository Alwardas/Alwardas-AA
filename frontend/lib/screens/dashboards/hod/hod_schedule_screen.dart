import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/notification_service.dart';
import '../faculty/add_class_screen.dart';

class HodScheduleScreen extends StatefulWidget {
  const HodScheduleScreen({super.key});

  @override
  _HodScheduleScreenState createState() => _HodScheduleScreenState();
}

class _HodScheduleScreenState extends State<HodScheduleScreen> {
  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  late String _selectedDay;
  final Map<String, List<Map<String, dynamic>>> _scheduleData = {};
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    final today = DateFormat('EEEE').format(DateTime.now());
    _selectedDay = _days.contains(today) ? today : 'Monday';
    _refreshSchedule();
  }

  Future<void> _refreshSchedule() async {
    setState(() => _isLoading = true);
    await _fetchTimings(); 
    await _fetchClassAssignments();
    setState(() => _isLoading = false);
  }

  Future<void> _fetchTimings() async {
    final user = await AuthService.getUserSession();
    if (user == null) return;
    final branch = user['branch'] ?? 'Computer Engineering'; 

    int startHour = 9;
    int startMinute = 0;
    int classDuration = 50;
    int shortBreakDuration = 10;
    int lunchDuration = 50;
    List<dynamic> slotConfig = [];

    try {
        final uri = Uri.parse('${ApiConstants.baseUrl}/api/department/timing').replace(queryParameters: {'branch': branch});
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
        }
    } catch (e) {
         debugPrint("Error fetching timings: $e");
    }

    // Generate Slots
    DateTime time = DateTime(2026, 1, 1, startHour, startMinute);
    List<Map<String, dynamic>> dailySlots = [];
    String formatTime(DateTime t) => DateFormat('hh:mm a').format(t);

    if (slotConfig.isNotEmpty) {
        int pNum = 1;
        int bNum = 1;
        for (var type in slotConfig) {
            DateTime start = time;
            int duration = 0;
            String id = "";
            String entryType = "";
            String label = "";
            
            if (type == 'P') {
                duration = classDuration;
                entryType = 'class';
                id = 'p$pNum';
            } else if (type == 'SB') {
                duration = shortBreakDuration;
                entryType = 'break';
                label = 'Short Break';
                id = 'sb$bNum';
                bNum++;
            } else if (type == 'LB') {
                duration = lunchDuration;
                entryType = 'lunch';
                label = 'Lunch Break';
                id = 'lb1';
            }
            
            DateTime end = time.add(Duration(minutes: duration));
            
            dailySlots.add({
                'id': id,
                'type': entryType,
                'number': type == 'P' ? pNum : null,
                'label': label,
                'startTime': formatTime(start),
                'endTime': formatTime(end),
                'time': '${formatTime(start)} - ${formatTime(end)}',
                'subject': type == 'P' ? '---' : null
            });
            
            time = end;
            if (type == 'P') pNum++;
        }
    } else {
        // Fallback Logic
        for (int p = 1; p <= 8; p++) {
           DateTime start = time;
           time = time.add(Duration(minutes: classDuration));
           
           dailySlots.add({
             'id': 'p$p',
             'type': 'class',
             'number': p,
             'startTime': formatTime(start),
             'endTime': formatTime(time),
             'time': '${formatTime(start)} - ${formatTime(time)}',
             'subject': '---'
           });
           
           if (p == 2 || p == 6) {
              DateTime bStart = time;
              time = time.add(Duration(minutes: shortBreakDuration));
              dailySlots.add({
                 'id': 'b${p==2?1:2}',
                 'type': 'break',
                 'label': 'Short Break',
                 'startTime': formatTime(bStart),
                 'endTime': formatTime(time),
                 'time': '${formatTime(bStart)} - ${formatTime(time)}'
              });
           } else if (p == 4) {
              DateTime bStart = time;
              time = time.add(Duration(minutes: lunchDuration));
              dailySlots.add({
                 'id': 'l1',
                 'type': 'lunch',
                 'label': 'Lunch Break',
                 'startTime': formatTime(bStart),
                 'endTime': formatTime(time),
                 'time': '${formatTime(bStart)} - ${formatTime(time)}'
              });
           }
        }
    }

    if (mounted) {
      setState(() {
        for (var day in _days) {
            _scheduleData[day] = dailySlots.map((s) => Map<String, dynamic>.from(s)).toList();
        }
      });
    }
  }

  Future<void> _fetchClassAssignments() async {
      final user = await AuthService.getUserSession();
      if (user == null) return;
      
      try {
          final String fid = user['login_id'] ?? user['studentId'] ?? user['id'] ?? '';
          final uri = Uri.parse('${ApiConstants.baseUrl}/api/timetable').replace(queryParameters: {'facultyId': fid});
          final res = await http.get(uri);
          
          if (res.statusCode == 200) {
              final List<dynamic> assignments = json.decode(res.body);
              
              if (mounted) {
                   setState(() {
                       for (var entry in assignments) {
                           final day = entry['day'];
                           final pIndex = entry['period_index'] ?? entry['periodIndex'];
                           
                           if (day != null && pIndex != null && _scheduleData.containsKey(day)) {
                               var slots = _scheduleData[day]!;
                               final idx = slots.indexWhere((s) => s['number'] == pIndex);
                               if (idx != -1) {
                                   slots[idx]['subject'] = entry['subject'];
                                   slots[idx]['subjectCode'] = entry['subject_code'] ?? entry['subjectCode'];
                                   slots[idx]['branch'] = entry['branch'];
                                   slots[idx]['year'] = entry['year'];
                                   slots[idx]['section'] = entry['section'];
                               }
                           }
                       }
                   });
              }
          }
      } catch (e) {
          debugPrint("Error fetching assignments: $e");
      }
  }

  void _onSlotTap(Map<String, dynamic> item) async {
    if (item['type'] != 'class') return;
    if (item['subject'] != '---') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Long press to edit this class."), duration: Duration(milliseconds: 1000)));
        return;
    }
    await _openAddClassScreen(item);
  }
  
  void _onSlotLongPress(Map<String, dynamic> item) async {
      if (item['type'] != 'class') return;
      
      if (item['subject'] == '---') {
          await _openAddClassScreen(item);
          return;
      }

      final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
      final isDark = themeProvider.isDarkMode;
      final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
      final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
      final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;

      showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (context) => Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: const BorderRadius.vertical(top: Radius.circular(25)),
              ),
              child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      Container(width: 40, height: 4, decoration: BoxDecoration(color: textColor.withOpacity(0.1), borderRadius: BorderRadius.circular(2))),
                      const SizedBox(height: 20),
                      Text("Manage Schedule", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
                      const SizedBox(height: 10),
                      Text("Period ${item['number']} - ${item['subject']}", style: TextStyle(color: textColor.withOpacity(0.7), fontSize: 14)),
                      const SizedBox(height: 25),
                      ListTile(
                          leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: tint.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(Icons.edit_outlined, color: tint)),
                          title: Text("Edit Assignment", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                          subtitle: Text("Change details or subject", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12)),
                          onTap: () {
                              Navigator.pop(context);
                              _openAddClassScreen(item);
                          },
                      ),
                      const Divider(),
                      ListTile(
                          leading: Container(padding: const EdgeInsets.all(8), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: const Icon(Icons.delete_outline, color: Colors.red)),
                          title: const Text("Clear Schedule", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                          subtitle: Text("Remove this period assignment", style: TextStyle(color: Colors.red.withOpacity(0.5), fontSize: 12)),
                          onTap: () {
                              Navigator.pop(context);
                              _showDeleteConfirm(item);
                          },
                      ),
                      const SizedBox(height: 20),
                  ],
              ),
          )
      );
  }

  void _showDeleteConfirm(Map<String, dynamic> item) {
      showDialog(
          context: context,
          builder: (context) => AlertDialog(
              title: const Text("Clear Class?"),
              content: const Text("This will remove the assigned class from your schedule."),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
                  TextButton(
                      onPressed: () {
                          Navigator.pop(context);
                          _clearSchedule(item);
                      }, 
                      child: const Text("Clear", style: TextStyle(color: Colors.red))
                  ),
              ],
          )
      );
  }

  Future<void> _clearSchedule(Map<String, dynamic> item) async {
      setState(() => _isLoading = true);
      try {
          final body = {
              'facultyId': 'dummy', 
              'branch': item['branch'],
              'year': item['year'],
              'section': item['section'],
              'day': _selectedDay,
              'periodIndex': item['number'],
              'subject': 'clear'
          };

          final res = await http.post(
              Uri.parse('${ApiConstants.baseUrl}/api/timetable/clear'),
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode(body)
          );

          if (res.statusCode == 200) {
              try {
                  int targetWeekday = _getWeekdayIndex(_selectedDay);
                  int id = targetWeekday * 100 + (item['number'] as int);
                  await NotificationService.cancelNotification(id);
              } catch (ev) {
                  debugPrint("Cancel Notification Error: $ev");
              }
              _refreshSchedule();
          } else {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to clear schedule")));
          }
      } catch (e) {
          debugPrint("Clear Error: $e");
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error clearing schedule")));
      } finally {
          setState(() => _isLoading = false);
      }
  }

  Future<void> _openAddClassScreen(Map<String, dynamic> item) async {
      final updated = await Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => AddClassScreen(
                  day: _selectedDay,
                  periodIndex: item['number'],
                  startTime: item['startTime'] ?? '',
                  endTime: item['endTime'] ?? '',
                  initialData: item['subject'] != '---' ? {
                      'branch': _mapFullToShort(item['branch']),
                      'year': item['year'],
                      'section': item['section'],
                      'subject': item['subject'],
                      'subjectCode': item['subjectCode']
                  } : null
              )
          )
      );
      
      if (updated == true) {
          _refreshSchedule();
      }
  }

  String _mapFullBranchToShort(String? full) {
      return _mapFullToShort(full);
  }

   String _mapFullToShort(String? full) {
      if (full == null) return "CME";
      if (full == "Computer Engineering") return "CME";
      if (full == "Electrical and Electronics Engineering") return "EEE";
      if (full == "Electronics & Communication Engineering") return "ECE";
      if (full == "Mechanical Engineering") return "MEC";
      if (full == "Civil Engineering") return "CIV";
      
      if (full.contains("Computer")) return "CME";
      if (full.contains("Electrical")) return "EEE";
      if (full.contains("Electronics")) return "ECE";
      if (full.contains("Mechanical")) return "MEC";
      if (full.contains("Civil")) return "CIV";
      return "CME";
  }

  String _mapSectionShort(String? section) {
      if (section == null) return "Sec A";
      if (section.toLowerCase().contains("section")) {
          return section.replaceAll(RegExp(r'section', caseSensitive: false), 'Sec').trim();
      }
      return "Sec $section";
  }

  int _getWeekdayIndex(String day) {
       switch (day) {
           case 'Monday': return DateTime.monday;
           case 'Tuesday': return DateTime.tuesday;
           case 'Wednesday': return DateTime.wednesday;
           case 'Thursday': return DateTime.thursday;
           case 'Friday': return DateTime.friday;
           case 'Saturday': return DateTime.saturday;
           case 'Sunday': return DateTime.sunday;
           default: return DateTime.monday;
       }
   }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? ThemeColors.darkBackground : ThemeColors.lightBackground;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;
    
    final currentSchedule = _scheduleData[_selectedDay] ?? [];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("My Schedule", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
        actions: [
          IconButton(
            icon: CircleAvatar(
              backgroundColor: tint,
              child: const Icon(Icons.add, color: Colors.white, size: 20),
            ),
            onPressed: () => _openAddClassScreen({}),
            tooltip: "Assign Class",
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              Container(
                height: 60,
                margin: const EdgeInsets.symmetric(vertical: 10),
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _days.length,
                  itemBuilder: (ctx, index) {
                    final day = _days[index];
                    final isSelected = day == _selectedDay;
                    return GestureDetector(
                      onTap: () => setState(() => _selectedDay = day),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: isSelected ? tint : (isDark ? Colors.white10 : Colors.grey[200]),
                          borderRadius: BorderRadius.circular(30),
                          boxShadow: isSelected 
                            ? [BoxShadow(color: tint.withValues(alpha: 0.4), blurRadius: 8, offset: const Offset(0, 4))] 
                            : [],
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          day, 
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.white : textColor, 
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal
                          )
                        ),
                      ),
                    );
                  },
                ),
              ),

              Expanded(
                child: _isLoading 
                    ? Center(child: CircularProgressIndicator(color: tint))
                    : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 80),
                      physics: const BouncingScrollPhysics(),
                      itemCount: currentSchedule.length,
                      itemBuilder: (ctx, index) {
                        final item = currentSchedule[index];
                        return _buildTimelineItem(item, textColor, subTextColor, tint, isDark);
                      },
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> item, Color textColor, Color subTextColor, Color tint, bool isDark) {
    final bool isBreak = item['type'] == 'break' || item['type'] == 'lunch';
    final String time = item['time'] ?? '';
    final String startTime = item['startTime'] ?? time.split('-')[0].trim();
    final String endTime = item['endTime'] ?? time.split('-')[1].trim();
    final bool isAssigned = item['subject'] != '---' && item['subject'] != null;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(startTime, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
              Text(endTime, style: GoogleFonts.poppins(fontSize: 10, color: subTextColor)),
              if (item['number'] != null)
                 Padding(
                   padding: const EdgeInsets.only(top: 4.0),
                   child: Text("Period ${item['number']}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tint)),
                 ),
            ],
          ),
        ),
        const SizedBox(width: 16),
        
        Column(
          children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: isBreak ? Colors.orangeAccent : (isAssigned ? tint : tint.withOpacity(0.3)),
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? const Color(0xFF1E1E1E) : Colors.white, width: 2),
                boxShadow: [BoxShadow(color: (isBreak ? Colors.orangeAccent : tint).withValues(alpha: 0.4), blurRadius: 6)],
              ),
            ),
            Container(
              width: 2,
              height: isBreak ? 60 : 100, 
              color: (isBreak ? Colors.orangeAccent : tint).withValues(alpha: 0.2),
            ),
          ],
        ),
        const SizedBox(width: 16),

        Expanded(
          child: GestureDetector(
            onTap: () => _onSlotTap(item),
            onLongPress: () => _onSlotLongPress(item),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isBreak 
                  ? Colors.orangeAccent.withValues(alpha: 0.1) 
                  : (isDark ? const Color(0xFF252525) : Colors.white),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: isBreak ? Colors.orange.withValues(alpha: 0.3) : (isDark ? Colors.white10 : Colors.grey.shade200)
                ),
                boxShadow: isBreak ? [] : [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4))
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isBreak)
                    Text(item['label'], style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orangeAccent, letterSpacing: 1))
                  else
                     Column(
                       crossAxisAlignment: CrossAxisAlignment.start,
                       children: [
                         if (isAssigned && item['subjectCode'] != null)
                           Padding(
                             padding: const EdgeInsets.only(bottom: 6.0),
                             child: Text(item['subjectCode'], style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: tint, letterSpacing: 1.2)),
                           ),
                         
                         Text(
                            isAssigned ? item['subject'] : "Free Period", 
                            style: GoogleFonts.poppins(
                              fontSize: 16, 
                              fontWeight: FontWeight.w700, 
                              color: isAssigned ? textColor : subTextColor.withValues(alpha: 0.5)
                            )
                          ),
                          
                          if (isAssigned)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                                decoration: BoxDecoration(
                                  color: tint.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(color: tint.withOpacity(0.1))
                                ),
                                child: Text(
                                  "${_mapFullBranchToShort(item['branch'])} : ${item['year']} : ${_mapSectionShort(item['section'])}",
                                  style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w500, color: subTextColor),
                                ),
                              ),
                            ),
                          
                          if (!isAssigned)
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                children: [
                                  Icon(Icons.add_circle_outline, size: 14, color: tint),
                                  const SizedBox(width: 4),
                                  Text("Tap to assign", style: TextStyle(fontSize: 12, color: tint, fontStyle: FontStyle.italic)),
                                ],
                              ),
                            )
                       ],
                     )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
