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

class HodScheduleScreen extends StatefulWidget {
  const HodScheduleScreen({super.key});

  @override
  _HodScheduleScreenState createState() => _HodScheduleScreenState();
}

class _HodScheduleScreenState extends State<HodScheduleScreen> {
  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  late String _selectedDay;
  final Map<String, List<Map<String, dynamic>>> _scheduleData = {};

  // Modal State
  bool _modalVisible = false;
  String? _modalDay;
  String _periodNumber = '1';
  String _selectedSubject = '';
  final TextEditingController _customSubjectController = TextEditingController();
  List<dynamic> _myActiveSubjects = [];

  @override
  void initState() {
    super.initState();
    final today = DateFormat('EEEE').format(DateTime.now());
    _selectedDay = _days.contains(today) ? today : 'Monday';
    _initMockData();
    _fetchMyActiveSubjects();
  }

  Future<void> _fetchMyActiveSubjects() async {
    final user = await AuthService.getUserSession();
    if (user == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/faculty/subjects?userId=${user['id']}'),
      );
      if (response.statusCode == 200 && mounted) {
        setState(() {
          _myActiveSubjects = json.decode(response.body);
        });
      }
    } catch (e) {
      debugPrint("Error fetching subjects: $e");
    }
  }

  void _initMockData() {
    for (var day in _days) {
      _scheduleData[day] = [
        {'id': '1', 'type': 'class', 'number': 1, 'time': '09:00 - 09:50', 'subject': '---'},
        {'id': '2', 'type': 'class', 'number': 2, 'time': '09:50 - 10:40', 'subject': '---'},
        {'id': 'b1', 'type': 'break', 'label': 'Short Break', 'time': '10:40 - 11:00'},
        {'id': '3', 'type': 'class', 'number': 3, 'time': '11:00 - 11:50', 'subject': '---'},
        {'id': '4', 'type': 'class', 'number': 4, 'time': '11:50 - 12:40', 'subject': '---'},
        {'id': 'l1', 'type': 'lunch', 'label': 'Lunch Break', 'time': '12:40 - 01:30'},
        {'id': '5', 'type': 'class', 'number': 5, 'time': '01:30 - 02:20', 'subject': '---'},
        {'id': '6', 'type': 'class', 'number': 6, 'time': '02:20 - 03:10', 'subject': '---'},
        {'id': 'b2', 'type': 'break', 'label': 'Short Break', 'time': '03:10 - 03:30'},
        {'id': '7', 'type': 'class', 'number': 7, 'time': '03:30 - 04:20', 'subject': '---'},
        {'id': '8', 'type': 'class', 'number': 8, 'time': '04:20 - 05:10', 'subject': '---'},
      ];
    }
  }

  void _showAddClassModal() {
    setState(() {
      _modalDay = _selectedDay;
      _modalVisible = true;
      _periodNumber = '1';
      _selectedSubject = '';
      _customSubjectController.clear();
    });
  }

  void _handleAddClass() {
    final subjectToAdd = _customSubjectController.text.trim().isNotEmpty 
        ? _customSubjectController.text.trim() 
        : _selectedSubject;

    if (subjectToAdd.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select or enter a subject.")));
      return;
    }

    setState(() {
      final daySchedule = _scheduleData[_modalDay!];
      if (daySchedule != null) {
        final idx = daySchedule.indexWhere((p) => p['number'].toString() == _periodNumber);
        if (idx != -1) {
          daySchedule[idx]['subject'] = subjectToAdd;
        }
      }
      _modalVisible = false;
    });
  }

  void _clearClass(Map<String, dynamic> item) {
    if (item['subject'] == '---' || item['type'] != 'class') return;
    
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Class"),
        content: const Text("Do you want to clear this class?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              setState(() {
                final daySchedule = _scheduleData[_selectedDay];
                if (daySchedule != null) {
                  final idx = daySchedule.indexWhere((p) => p['id'] == item['id']);
                  if (idx != -1) {
                    daySchedule[idx]['subject'] = '---';
                  }
                }
              });
              Navigator.pop(ctx);
            }, 
            child: const Text("Clear", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );
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
          Padding(
            padding: const EdgeInsets.only(right: 16.0),
            child: IconButton(
              onPressed: _showAddClassModal,
              icon: Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: tint.withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add, color: tint, size: 24),
              ),
              tooltip: "Add Class",
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          bottom: false,
          child: Column(
            children: [
              // Horizontal Day Selector
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

              // Timeline List
              Expanded(
                child: ListView.builder(
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
      // Overlay for Modal
      bottomSheet: _modalVisible ? _buildAddClassModalContent(textColor, subTextColor, tint, isDark) : null,
    );
  }

  Widget _buildTimelineItem(Map<String, dynamic> item, Color textColor, Color subTextColor, Color tint, bool isDark) {
    final bool isBreak = item['type'] == 'break' || item['type'] == 'lunch';
    final String time = item['time'] ?? '';
    final String startTime = time.split('-')[0].trim();
    final String endTime = time.split('-')[1].trim();

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Time Column
        SizedBox(
          width: 60,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(startTime, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: textColor)),
              Text(endTime, style: GoogleFonts.poppins(fontSize: 10, color: subTextColor)),
            ],
          ),
        ),
        const SizedBox(width: 16),
        
        // Timeline Line and Dot
        Column(
          children: [
            Container(
              width: 12, height: 12,
              decoration: BoxDecoration(
                color: isBreak ? Colors.orangeAccent : tint,
                shape: BoxShape.circle,
                border: Border.all(color: isDark ? Colors.black : Colors.white, width: 2),
                boxShadow: [BoxShadow(color: (isBreak ? Colors.orangeAccent : tint).withValues(alpha: 0.4), blurRadius: 6)],
              ),
            ),
            Container(
              width: 2,
              height: isBreak ? 50 : 70, // Height depends on content
              color: (isBreak ? Colors.orangeAccent : tint).withValues(alpha: 0.2),
            ),
          ],
        ),
        const SizedBox(width: 16),

        // Content Card
        Expanded(
          child: GestureDetector(
            onLongPress: () => _clearClass(item),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isBreak 
                  ? Colors.orangeAccent.withValues(alpha: 0.1) 
                  : (isDark ? const Color(0xFF1E1E1E) : Colors.white),
                borderRadius: BorderRadius.circular(16),
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
                  if (!isBreak)
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: tint.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6)
                          ),
                          child: Text("Period ${item['number']}", style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: tint)),
                        ),
                        if (item['subject'] != '---')
                           Icon(Icons.edit_note, size: 16, color: subTextColor),
                      ],
                    ),
                  
                  const SizedBox(height: 6),
                  
                  if (isBreak)
                    Text(item['label'], style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.orangeAccent, letterSpacing: 1))
                  else
                     Text(
                        item['subject'] == '---' ? "No Class Assigned" : item['subject'], 
                        style: GoogleFonts.poppins(
                          fontSize: 16, 
                          fontWeight: FontWeight.w600, 
                          color: item['subject'] == '---' ? subTextColor.withValues(alpha: 0.5) : textColor
                        )
                      ),
                  
                  if (!isBreak && item['subject'] == '---')
                    Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Text("Tap + to assign", style: TextStyle(fontSize: 12, color: tint, fontStyle: FontStyle.italic)),
                    )
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAddClassModalContent(Color textColor, Color subTextColor, Color tint, bool isDark) {
    // Re-using simplified modal logic similar to before but inline or focused
    return Container(
          width: double.infinity,
          height: MediaQuery.of(context).size.height * 0.75,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text("Add Class", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                  IconButton(onPressed: () => setState(() => _modalVisible = false), icon: Icon(Icons.close, color: subTextColor))
                ],
              ),
              const SizedBox(height: 10),
              // Day Selector (Modal)
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _days.map((d) {
                    final selected = _modalDay == d;
                    return GestureDetector(
                      onTap: () => setState(() => _modalDay = d),
                      child: Container(
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                        decoration: BoxDecoration(
                          color: selected ? tint : Colors.transparent,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: selected ? tint : subTextColor.withValues(alpha: 0.3)),
                        ),
                        child: Text(d.substring(0, 3), style: TextStyle(color: selected ? Colors.white : textColor, fontWeight: selected ? FontWeight.bold : FontWeight.normal)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              Text("Select Period", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: subTextColor)),
              const SizedBox(height: 8),
              SingleChildScrollView( // Make periods scrollable if needed
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [1, 2, 3, 4, 5, 6, 7, 8].map((n) {
                    final selected = _periodNumber == n.toString();
                    return GestureDetector(
                      onTap: () => setState(() => _periodNumber = n.toString()),
                      child: Container(
                        width: 40, height: 40,
                        margin: const EdgeInsets.only(right: 10),
                        decoration: BoxDecoration(
                          color: selected ? tint : Colors.transparent,
                          shape: BoxShape.circle,
                          border: Border.all(color: selected ? tint : subTextColor.withValues(alpha: 0.3)),
                        ),
                        alignment: Alignment.center,
                        child: Text(n.toString(), style: TextStyle(color: selected ? Colors.white : textColor, fontWeight: FontWeight.bold)),
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 20),
              Text("Choose Subject", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: subTextColor)),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  children: [
                    Wrap(
                      spacing: 8, runSpacing: 8,
                      children: [
                        if (_myActiveSubjects.isEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 10),
                            child: Text("No active subjects found. Add them in 'My Courses'.", style: TextStyle(color: subTextColor, fontSize: 13, fontStyle: FontStyle.italic)),
                          ),
                        ..._myActiveSubjects
                            .map((c) => c['name']?.toString() ?? 'Unnamed')
                            .map((s) {
                          final selected = _selectedSubject == s;
                          return GestureDetector(
                            onTap: () => setState(() {
                              _selectedSubject = s;
                              _customSubjectController.clear();
                            }),
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              decoration: BoxDecoration(
                                color: selected ? tint : Colors.transparent,
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: selected ? tint : subTextColor.withValues(alpha: 0.3)),
                              ),
                              child: Text(s, style: TextStyle(color: selected ? Colors.white : textColor, fontSize: 13)),
                            ),
                          );
                        }),
                      ],
                    ),
                    const SizedBox(height: 20),
                    Text("Or Enter Custom Subject", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: subTextColor)),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _customSubjectController,
                      style: GoogleFonts.poppins(color: textColor),
                      decoration: InputDecoration(
                        hintText: "e.g. Special Seminar",
                        hintStyle: TextStyle(color: subTextColor),
                        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: subTextColor.withValues(alpha: 0.3))),
                        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tint)),
                      ),
                      onChanged: (val) {
                        if (val.isNotEmpty) setState(() => _selectedSubject = '');
                      },
                    ),
                    const SizedBox(height: 30),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(backgroundColor: tint, padding: const EdgeInsets.symmetric(vertical: 15), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                        onPressed: _handleAddClass,
                        child: Text("Save to Schedule", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ],
          ),
        );
  }
}
