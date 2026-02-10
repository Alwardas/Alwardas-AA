import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/api_constants.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';

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
  Map<String, List<Map<String, dynamic>>> _scheduleData = {
    'Monday': _getEmptyDay(),
    'Tuesday': _getEmptyDay(),
    'Wednesday': _getEmptyDay(),
    'Thursday': _getEmptyDay(),
    'Friday': _getEmptyDay(),
    'Saturday': _getEmptyDay(),
  };

  static List<Map<String, dynamic>> _getEmptyDay() => [
        {'id': 'p1', 'type': 'class', 'number': 1, 'time': '9:00-9:50', 'subject': '---', 'faculty': ''},
        {'id': 'p2', 'type': 'class', 'number': 2, 'time': '9:50-10:40', 'subject': '---', 'faculty': ''},
        {'id': 'b1', 'type': 'break', 'label': 'B R E A K'},
        {'id': 'p3', 'type': 'class', 'number': 3, 'time': '11:00-11:50', 'subject': '---', 'faculty': ''},
        {'id': 'p4', 'type': 'class', 'number': 4, 'time': '11:50-12:40', 'subject': '---', 'faculty': ''},
        {'id': 'l1', 'type': 'lunch', 'label': 'L U N C H'},
        {'id': 'p5', 'type': 'class', 'number': 5, 'time': '1:30-2:20', 'subject': '---', 'faculty': ''},
        {'id': 'p6', 'type': 'class', 'number': 6, 'time': '2:20-3:10', 'subject': '---', 'faculty': ''},
        {'id': 'b2', 'type': 'break', 'label': 'B R E A K'},
        {'id': 'p7', 'type': 'class', 'number': 7, 'time': '3:30-4:20', 'subject': '---', 'faculty': ''},
        {'id': 'p8', 'type': 'class', 'number': 8, 'time': '4:20-5:10', 'subject': '---', 'faculty': ''},
      ];

  final Map<int, Map<String, String>> _periodTimes = {
      1: {'start': '09:00', 'end': '09:50'},
      2: {'start': '09:50', 'end': '10:40'},
      3: {'start': '11:00', 'end': '11:50'},
      4: {'start': '11:50', 'end': '12:40'},
      5: {'start': '13:30', 'end': '14:20'},
      6: {'start': '14:20', 'end': '15:10'},
      7: {'start': '15:30', 'end': '16:20'},
      8: {'start': '16:20', 'end': '17:10'},
  };

  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  late String _selectedDay;
  bool _dropdownVisible = false;

  // Modal State
  bool _modalVisible = false;
  late String _modalDay;
  String _periodNumber = '1';
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _facultyController = TextEditingController();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    int weekday = DateTime.now().weekday; // 1 = Mon, 7 = Sun
    if (weekday > 6) weekday = 1;
    _selectedDay = _days[weekday - 1];
    _modalDay = _selectedDay;
    _fetchTimetable();
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
                      int pNum = item['period_number'];
                      var daySlots = newSchedule[day]!;
                      for (var slot in daySlots) {
                          if (slot['type'] == 'class' && slot['number'] == pNum) {
                              slot['id'] = item['id']; 
                              slot['subject'] = item['subject_name'];
                          }
                      }
                  }
              }
              if (mounted) setState(() => _scheduleData = newSchedule);
          }
      } catch (e) {
          print("Fetch Timetable Error: $e");
      }
  }

  Future<void> _handleAddClass() async {
    if (_subjectController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a subject name.")));
      return;
    }
    
    setState(() => _isLoading = true);
    
    try {
        int pNum = int.parse(_periodNumber);
        String subject = _subjectController.text.trim();
        if (_facultyController.text.isNotEmpty) {
            subject += " (${_facultyController.text.trim()})";
        }
        
        final times = _periodTimes[pNum] ?? {'start': '00:00', 'end': '00:00'};
        
        final body = {
            'branch': widget.branch,
            'year': widget.year,
            'section': widget.section,
            'day': _modalDay,
            'period_number': pNum,
            'start_time': times['start'],
            'end_time': times['end'],
            'subject_name': subject,
            'entry_type': 'class'
        };
        
        final res = await http.post(
            Uri.parse('${ApiConstants.baseUrl}/api/timetable/assign'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode(body)
        );
        
        if (res.statusCode == 200) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Class Assigned")));
            _subjectController.clear();
            _facultyController.clear();
            setState(() => _modalVisible = false);
            _fetchTimetable();
        } else {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to assign class")));
        }
    } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network Error")));
    } finally {
        if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleClearClass(String day, String id) async {
    if (id.startsWith('p')) return; 

    try {
        final res = await http.post(
            Uri.parse('${ApiConstants.baseUrl}/api/timetable/clear'),
            headers: {'Content-Type': 'application/json'},
            body: json.encode({'id': id})
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
            onPressed: () {
              setState(() => _modalDay = _selectedDay);
              setState(() => _modalVisible = true);
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
                                border: Border.all(color: tint.withOpacity(0.5)),
                                borderRadius: BorderRadius.circular(50),
                              ),
                              alignment: Alignment.center,
                              child: Text(item['label'], style: GoogleFonts.poppins(color: tint, fontWeight: FontWeight.bold, letterSpacing: 4)),
                            );
                          }

                          // Class Item
                          final hasClass = item['subject'] != '---';

                          return GestureDetector(
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
                                                  _handleClearClass(_selectedDay, item['id']);
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
                                border: Border.all(color: hasClass ? tint.withOpacity(0.3) : iconBg),
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: [
                                  if (hasClass)
                                    BoxShadow(
                                      color: tint.withOpacity(0.1),
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
                                      color: tint.withOpacity(0.1),
                                      borderRadius: BorderRadius.circular(6)
                                    ),
                                    child: Text("Period ${item['number']}", style: GoogleFonts.poppins(color: tint, fontWeight: FontWeight.bold, fontSize: 10)),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(item['time'], style: GoogleFonts.poppins(color: subTextColor, fontSize: 11)),
                                  const SizedBox(height: 12),
                                  Text(item['subject'],
                                      textAlign: TextAlign.center,
                                      style: GoogleFonts.poppins(color: hasClass ? textColor : subTextColor.withOpacity(0.5), fontSize: 16, fontWeight: FontWeight.bold),
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

              // Add Modal
              if (_modalVisible) _buildModal(textColor, subTextColor, isDark ? const Color(0xFF24243e) : Colors.white, tint, iconBg),
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
        constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: modalBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text("Assign Class", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  IconButton(icon: const Icon(Icons.close), onPressed: () => setState(() => _modalVisible = false))
                ],
              ),
  
              // Day Selector Horizontal
              const Text("Select Day", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _days
                      .map((day) => GestureDetector(
                            onTap: () => setState(() => _modalDay = day),
                            child: Container(
                              margin: const EdgeInsets.only(right: 10),
                              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                              decoration: BoxDecoration(
                                color: _modalDay == day ? tint : Colors.transparent,
                                border: Border.all(color: iconBg),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Text(day.substring(0, 3), style: TextStyle(color: _modalDay == day ? Colors.white : textColor)),
                            ),
                          ))
                      .toList(),
                ),
              ),
  
              const SizedBox(height: 20),
              const Text("Select Period (1-8)", style: TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Wrap(
                // Period Grid
                spacing: 10, runSpacing: 10,
                children: List.generate(8, (index) {
                  final num = (index + 1).toString();
                  return GestureDetector(
                    onTap: () => setState(() => _periodNumber = num),
                    child: Container(
                      width: 40,
                      height: 40,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                          color: _periodNumber == num ? tint : Colors.transparent,
                          border: Border.all(color: iconBg),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(num,
                          style:
                              TextStyle(color: _periodNumber == num ? Colors.white : textColor, fontWeight: FontWeight.bold)),
                    ),
                  );
                }),
              ),
  
              const SizedBox(height: 20),
              TextField(
                controller: _subjectController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Subject Name",
                  labelStyle: TextStyle(color: subTextColor),
                  hintText: "e.g. Data Structures",
                  hintStyle: TextStyle(color: subTextColor.withOpacity(0.5)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              
              const SizedBox(height: 12),
               TextField(
                controller: _facultyController,
                style: TextStyle(color: textColor),
                decoration: InputDecoration(
                  labelText: "Faculty Name (Optional)",
                  labelStyle: TextStyle(color: subTextColor),
                  hintText: "e.g. Dr. Smith",
                  hintStyle: TextStyle(color: subTextColor.withOpacity(0.5)),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
  
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _handleAddClass,
                  style: ElevatedButton.styleFrom(backgroundColor: tint, padding: const EdgeInsets.all(15)),
                  child: const Text("Assign", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
