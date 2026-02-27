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
import 'hod_assign_class_screen.dart';

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
  String? _userBranch;

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
    _userBranch = branch;

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
                id = 'l1';
            }
            
            time = time.add(Duration(minutes: duration));
            
            if (entryType == 'class') {
                dailySlots.add({
                    'id': id,
                    'type': 'class',
                    'number': pNum,
                    'startTime': formatTime(start),
                    'endTime': formatTime(time),
                    'time': '${formatTime(start)} - ${formatTime(time)}',
                    'subject': 'Free Period',
                    'faculty': '',
                });
                pNum++;
            } else {
                dailySlots.add({
                    'id': id,
                    'type': entryType,
                    'label': label,
                    'startTime': formatTime(start),
                    'endTime': formatTime(time),
                    'time': '${formatTime(start)} - ${formatTime(time)}'
                });
            }
        }
    } else {
        // Fallback to 8 periods
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
             'subject': 'Free Period',
             'faculty': '',
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
          final String fid = user['login_id'] ?? user['id'] ?? '';
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
                                final idx = slots.indexWhere((s) => s['type'] == 'class' && s['number'] == pIndex);
                                if (idx != -1) {
                                    slots[idx]['subject'] = entry['subject'];
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? [const Color(0xFF0F172A), const Color(0xFF1E293B)] : [const Color(0xFFF8FAFC), const Color(0xFFF1F5F9)];
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("My Schedule", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
        ),
        child: SafeArea(
          child: Column(
            children: [
              _buildDaySelector(textColor, subTextColor),
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : _scheduleData[_selectedDay] == null || _scheduleData[_selectedDay]!.isEmpty
                    ? const Center(child: Text("No schedule for today"))
                    : ListView.builder(
                        padding: const EdgeInsets.all(20),
                        itemCount: _scheduleData[_selectedDay]!.length,
                        itemBuilder: (ctx, index) {
                          final slot = _scheduleData[_selectedDay]![index];
                          return _buildScheduleItem(slot, isDark);
                        },
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDaySelector(Color textColor, Color subTextColor) {
    return SizedBox(
      height: 60,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: _days.length,
        itemBuilder: (ctx, index) {
          final day = _days[index];
          final isSelected = day == _selectedDay;
          return GestureDetector(
            onTap: () => setState(() => _selectedDay = day),
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
              padding: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: isSelected ? Theme.of(context).primaryColor : Colors.transparent,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: Text(
                day.substring(0, 3),
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : subTextColor,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildScheduleItem(Map<String, dynamic> slot, bool isDark) {
    final bool isClass = slot['type'] == 'class';
    final bool isFree = isClass && (slot['subject'] == 'Free Period' || slot['subject'] == '---');
    
    // Logic to check if this is the current period
    bool isCurrent = false;
    if (isClass) {
      try {
        final now = DateTime.now();
        final format = DateFormat('hh:mm a');
        final start = format.parse(slot['startTime']);
        final end = format.parse(slot['endTime']);
        
        final currentTimeInSeconds = now.hour * 3600 + now.minute * 60;
        final startTimeInSeconds = start.hour * 3600 + start.minute * 60;
        final endTimeInSeconds = end.hour * 3600 + end.minute * 60;
        
        if (currentTimeInSeconds >= startTimeInSeconds && currentTimeInSeconds < endTimeInSeconds && _selectedDay == DateFormat('EEEE').format(now)) {
          isCurrent = true;
        }
      } catch (_) {}
    }

    if (!isClass) {
      return Container(
        margin: const EdgeInsets.symmetric(vertical: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(slot['type'] == 'lunch' ? Icons.restaurant : Icons.timer_outlined, size: 16, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              "${slot['label']} (${slot['time']})",
              style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      );
    }

    return GestureDetector(
      onTap: () async {
        if (isFree && isClass) {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => HodAssignClassScreen(
                branch: _userBranch ?? 'Computer Engineering',
                year: '1st Year', // Default
                section: 'A', // Default
                initialDay: _selectedDay,
                initialPeriod: slot['number'] as int,
              ),
            ),
          );
          if (result == true) _refreshSchedule();
        }
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isCurrent 
              ? Theme.of(context).primaryColor.withValues(alpha: 0.2)
              : isFree ? (isDark ? const Color(0xFF1E293B) : Colors.white) : Theme.of(context).primaryColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCurrent 
                ? Theme.of(context).primaryColor 
                : isFree ? Colors.grey.withValues(alpha: 0.1) : Theme.of(context).primaryColor.withValues(alpha: 0.3),
            width: isCurrent ? 2 : 1,
          ),
          boxShadow: isCurrent ? [
            BoxShadow(color: Theme.of(context).primaryColor.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 1)
          ] : null,
        ),
        child: Row(
          children: [
            Column(
              children: [
                Text(
                  slot['startTime'],
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, 
                    fontSize: 13,
                    color: isCurrent ? Theme.of(context).primaryColor : (isDark ? Colors.white : Colors.black),
                  ),
                ),
                Container(height: 20, width: 2, color: isCurrent ? Theme.of(context).primaryColor : Colors.grey.withValues(alpha: 0.3)),
                Text(
                  slot['endTime'],
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, 
                    fontSize: 13, 
                    color: isCurrent ? Theme.of(context).primaryColor : Colors.grey,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (isCurrent)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Text(
                        "● ONGOING",
                        style: GoogleFonts.poppins(color: Theme.of(context).primaryColor, fontSize: 10, fontWeight: FontWeight.bold),
                      ),
                    ),
                  Text(
                    isFree ? "Free Period" : slot['subject'],
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isFree ? Colors.grey : (isDark ? Colors.white : Colors.black87),
                    ),
                  ),
                  if (!isFree) ...[
                    const SizedBox(height: 4),
                    Text(
                      "${slot['branch']} - ${slot['year']} ${slot['section']}",
                      style: GoogleFonts.poppins(color: isCurrent ? Theme.of(context).primaryColor.withValues(alpha: 0.8) : Colors.grey, fontSize: 12),
                    ),
                  ],
                ],
              ),
            ),
            if (isClass)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: isCurrent 
                      ? Theme.of(context).primaryColor 
                      : isFree ? Colors.grey.withValues(alpha: 0.2) : Theme.of(context).primaryColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  "P${slot['number']}",
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                    color: isCurrent ? Colors.white : (isFree ? Colors.grey : Theme.of(context).primaryColor),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
