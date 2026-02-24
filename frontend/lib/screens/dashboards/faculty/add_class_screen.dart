import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import '../../../core/api_constants.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import 'package:provider/provider.dart';
import '../../../../core/services/notification_service.dart';
import '../../../../core/services/auth_service.dart';
import 'package:intl/intl.dart';

class AddClassScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final String? day;
  final int? periodIndex;
  final String? startTime;
  final String? endTime;

  const AddClassScreen({
    super.key,
    this.initialData,
    this.day,
    this.periodIndex,
    this.startTime,
    this.endTime,
  });

  @override
  _AddClassScreenState createState() => _AddClassScreenState();
}

class _AddClassScreenState extends State<AddClassScreen> {
  // Dropdown Values
  String? _selectedBranch;
  String? _selectedYear;
  String? _selectedSection;
  String? _selectedDay;
  int? _selectedPeriodIndex;
  
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _subjectCodeController = TextEditingController();
  final TextEditingController _manualSubjectController = TextEditingController();
  
  bool _isLoading = false;
  List<String> _sections = [];
  List<Map<String, String>> _fetchedSubjects = [];
  List<int> _availablePeriods = [1, 2, 3, 4, 5, 6, 7, 8];
  Map<int, Map<String, String>> _periodTimes = {};

  // Options
  final List<String> _branches = ["CME", "EEE", "ECE", "MEC", "CIV"];
  final List<String> _years = ["1st Year", "2nd Year", "3rd Year"];
  final List<String> _daysList = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  
  // Activities for dropdown suggestions
  final List<String> _activities = ["Games", "Library", "Digital Class", "Seminar", "Workshop", "Self Study"];

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.day ?? DateFormat('EEEE').format(DateTime.now());
    if (!_daysList.contains(_selectedDay)) _selectedDay = "Monday";
    _selectedPeriodIndex = widget.periodIndex;

    if (widget.initialData != null) {
      _selectedBranch = widget.initialData!['branch'];
      _selectedYear = widget.initialData!['year'];
      _selectedSection = widget.initialData!['section'];
      _subjectController.text = widget.initialData!['subject'] ?? '';
      _subjectCodeController.text = widget.initialData!['subjectCode'] ?? '';
      _fetchSections();
      _loadSubjectsFromJson();
    } else {
        _loadFacultyContext();
    }
  }

  Future<void> _loadFacultyContext() async {
      final user = await AuthService.getUserSession();
      if (user != null && _selectedBranch == null) {
          setState(() {
              _selectedBranch = _mapFullToShort(user['branch']);
          });
          _fetchTimings();
      }
  }

  String _mapFullToShort(String? full) {
      if (full == null) return "CME";
      if (full.contains("Computer")) return "CME";
      if (full.contains("Electrical")) return "EEE";
      if (full.contains("Electronics")) return "ECE";
      if (full.contains("Mechanical")) return "MEC";
      if (full.contains("Civil")) return "CIV";
      return "CME";
  }

  Future<void> _fetchTimings() async {
    if (_selectedBranch == null) return;
    String fullBranch = _mapBranchToFull(_selectedBranch!);

    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/department/timing').replace(queryParameters: {'branch': fullBranch});
      final res = await http.get(uri);
      
      int startHour = 9;
      int startMinute = 0;
      int classDuration = 50;
      int shortBreakDuration = 10;
      int lunchDuration = 50;
      List<dynamic> slotConfig = [];

      if (res.statusCode == 200) {
        final List<dynamic> listData = json.decode(res.body);
        if (listData.isNotEmpty) {
          final data = listData[0];
          startHour = data['start_hour'] ?? 9;
          startMinute = data['start_minute'] ?? 0;
          classDuration = data['class_duration'] ?? 50;
          shortBreakDuration = data['short_break_duration'] ?? 10;
          lunchDuration = data['lunch_duration'] ?? 50;
          slotConfig = data['slot_config'] ?? [];
        }
      }

      DateTime time = DateTime(2026, 1, 1, startHour, startMinute);
      Map<int, Map<String, String>> newTimes = {};
      List<int> periods = [];

      if (slotConfig.isNotEmpty) {
        int pNum = 1;
        for (var type in slotConfig) {
          DateTime start = time;
          int dur = 0;
          if (type == 'P') dur = classDuration;
          else if (type == 'SB') dur = shortBreakDuration;
          else if (type == 'LB') dur = lunchDuration;

          time = time.add(Duration(minutes: dur));
          if (type == 'P') {
            newTimes[pNum] = {
              'start': DateFormat('hh:mm a').format(start),
              'end': DateFormat('hh:mm a').format(time)
            };
            periods.add(pNum);
            pNum++;
          }
        }
      } else {
        for (int i = 1; i <= 8; i++) {
          DateTime start = time;
          time = time.add(Duration(minutes: classDuration));
          newTimes[i] = {
            'start': DateFormat('hh:mm a').format(start),
            'end': DateFormat('hh:mm a').format(time)
          };
          periods.add(i);
        }
      }

      setState(() {
        _availablePeriods = periods;
        _periodTimes = newTimes;
        if (_selectedPeriodIndex != null && !_availablePeriods.contains(_selectedPeriodIndex)) {
          _selectedPeriodIndex = null;
        }
      });
    } catch (e) {
      debugPrint("Error fetching timings: $e");
    }
  }

  Future<void> _loadSubjectsFromJson() async {
    if (_selectedBranch == null || _selectedYear == null) return;
    
    try {
      final String response = await rootBundle.loadString('assets/data/json/subject.json');
      final List<dynamic> data = json.decode(response);
      
      String fullBranch = _mapBranchToFull(_selectedBranch!);
      
      final branchData = data.firstWhere(
        (b) => b['branch_name'] == fullBranch,
        orElse: () => null
      );
      
      if (branchData != null && branchData['semesters'] != null) {
        List<String> semestersToLoad = [];
        if (_selectedYear == "1st Year") {
            semestersToLoad.add("1st Year");
        } else if (_selectedYear == "2nd Year") {
            semestersToLoad.addAll(["3rd Semester", "4th Semester"]);
        } else if (_selectedYear == "3rd Year") {
            semestersToLoad.addAll(["5th Semester", "6th Semester"]);
        }

        List<Map<String, String>> subjects = [];
        for (var semKey in semestersToLoad) {
            final semesterData = branchData['semesters'][semKey];
            if (semesterData != null) {
                if (semesterData['theory'] != null) {
                    for (var s in semesterData['theory']) {
                        subjects.add({
                            'id': s['id'].toString(), 
                            'name': s['name'].toString(),
                            'sem': semKey
                        });
                    }
                }
                if (semesterData['practical'] != null) {
                    for (var s in semesterData['practical']) {
                        subjects.add({
                            'id': s['id'].toString(), 
                            'name': s['name'].toString(),
                            'sem': semKey
                        });
                    }
                }
            }
        }

        setState(() {
            _fetchedSubjects = subjects;
        });
      }
    } catch (e) {
      debugPrint("Error loading subjects from JSON: $e");
    }
  }

  Future<void> _fetchSections() async {
    if (_selectedBranch == null || _selectedYear == null) return;
    
    String fullBranch = _mapBranchToFull(_selectedBranch!);
    
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/sections')
          .replace(queryParameters: {'branch': fullBranch, 'year': _selectedYear});
      
      final res = await http.get(uri);
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        setState(() {
          _sections = data.map((e) => e.toString()).toList();
          if (!_sections.contains(_selectedSection)) _selectedSection = null;
        });
      }
    } catch (e) {
      debugPrint("Error fetching sections: $e");
    }
  }

  String _mapBranchToFull(String short) {
    switch (short) {
      case "CME": return "Computer Engineering";
      case "EEE": return "Electrical and Electronics Engineering";
      case "ECE": return "Electronics & Communication Engineering";
      case "MEC": return "Mechanical Engineering";
      case "CIV": return "Civil Engineering";
      default: return short;
    }
  }

  Future<void> _saveClass() async {
    final String subject = _manualSubjectController.text.isNotEmpty 
        ? _manualSubjectController.text 
        : _subjectController.text;

    if (_selectedBranch == null || _selectedYear == null || _selectedSection == null || 
        _selectedDay == null || _selectedPeriodIndex == null || subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.getUserSession();
      if (user == null) return;
      final String fid = user['login_id'] ?? user['studentId'] ?? user['id'] ?? '';
      
      if (fid.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Session error. Please login again.")));
          return;
      }

      final times = _periodTimes[_selectedPeriodIndex] ?? {
          'start': widget.startTime ?? '09:00 AM',
          'end': widget.endTime ?? '09:50 AM'
      };

      final body = {
        'facultyId': fid,
        'branch': _mapBranchToFull(_selectedBranch!),
        'year': _selectedYear,
        'section': _selectedSection,
        'day': _selectedDay,
        'periodIndex': _selectedPeriodIndex,
        'subject': subject,
        'subjectCode': _manualSubjectController.text.isNotEmpty ? null : _subjectCodeController.text,
        'startTime': times['start'],
        'endTime': times['end']
      };

      final res = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/timetable/assign'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body)
      );

      if (res.statusCode == 200) {
        try {
           await _scheduleNotification();
        } catch (e) {
           debugPrint("Notification Error: $e");
        }

        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${res.statusCode}")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _scheduleNotification() async {
      try {
          final subject = _manualSubjectController.text.isNotEmpty ? _manualSubjectController.text : _subjectController.text;
          final startTime = _periodTimes[_selectedPeriodIndex]?['start'] ?? widget.startTime ?? '';
          if (startTime.isEmpty) return;

          final format = DateFormat("hh:mm a"); 
          final DateTime parsedTime = format.parse(startTime);
          int targetWeekday = _getWeekdayIndex(_selectedDay!);
          
          DateTime now = DateTime.now();
          DateTime scheduledDate = DateTime(now.year, now.month, now.day, parsedTime.hour, parsedTime.minute);
          
          while (scheduledDate.weekday != targetWeekday || scheduledDate.isBefore(now)) {
              scheduledDate = scheduledDate.add(const Duration(days: 1));
          }

          // Classes usually start on a specific date. 
          // Set reminder 1 minute before
          DateTime reminderTime = scheduledDate.subtract(const Duration(minutes: 1));
          
          if (reminderTime.isBefore(now)) {
              // If 1 min before is already past but class is in future, maybe notifying now is okay or skip
              // Let's just ensure it's in the future for the OS scheduler
              return; 
          }

          int id = targetWeekday * 100 + _selectedPeriodIndex!;
          
          String classInfo = "${_selectedBranch} : ${_selectedYear} : ${_mapSectionShort(_selectedSection)}";

          await NotificationService.scheduleClassNotification(
              id: id,
              title: "Class Reminder",
              body: "Subject: $subject\nYou have a class of $classInfo",
              scheduledTime: reminderTime
          );
      } catch (e) {
          debugPrint("Notification Error: $e");
      }
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

  void _clearManualSubject() {
      if (_manualSubjectController.text.isNotEmpty) {
          setState(() {
              _manualSubjectController.clear();
          });
      }
  }

  void _clearListSubject() {
      if (_subjectController.text.isNotEmpty) {
          setState(() {
              _subjectController.clear();
              _subjectCodeController.clear();
          });
      }
  }

  String _mapSectionShort(String? section) {
      if (section == null) return "Sec A";
      if (section.toLowerCase().contains("section")) {
          return section.replaceAll(RegExp(r'section', caseSensitive: false), 'Sec').trim();
      }
      return "Sec $section";
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;
    
    final bgColor = isDark ? ThemeColors.darkBackground.first : ThemeColors.lightBackground.first;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(widget.initialData == null ? "Assign Class" : "Edit Class", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
         decoration: BoxDecoration(color: bgColor),
         child: SafeArea(
           child: SingleChildScrollView(
             padding: const EdgeInsets.all(20),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 _buildInfoCard(cardColor, textColor, tint),
                 const SizedBox(height: 20),
                 
                 Row(
                   children: [
                     Expanded(child: _buildDropdown("Day", _daysList, _selectedDay, (val) => setState(() => _selectedDay = val), tint, textColor, cardColor)),
                     const SizedBox(width: 10),
                     Expanded(child: _buildDropdown("Period", _availablePeriods.map((e) => e.toString()).toList(), _selectedPeriodIndex?.toString(), (val) {
                         setState(() => _selectedPeriodIndex = int.tryParse(val ?? ''));
                     }, tint, textColor, cardColor)),
                   ],
                 ),

                 const SizedBox(height: 20),

                 Row(
                   children: [
                     Expanded(child: _buildDropdown("Branch", _branches, _selectedBranch, (val) {
                       setState(() { _selectedBranch = val; _selectedSection = null; _fetchedSubjects = []; });
                       _fetchSections();
                       _fetchTimings();
                       _loadSubjectsFromJson();
                     }, tint, textColor, cardColor)),
                     const SizedBox(width: 10),
                     Expanded(child: _buildDropdown("Year", _years, _selectedYear, (val) {
                       setState(() { _selectedYear = val; _selectedSection = null; _fetchedSubjects = []; });
                       _fetchSections();
                       _loadSubjectsFromJson();
                     }, tint, textColor, cardColor)),
                     const SizedBox(width: 10),
                     Expanded(child: _buildDropdown("Section", _sections, _selectedSection, (val) => setState(() => _selectedSection = val), tint, textColor, cardColor)),
                   ],
                 ),
                 
                 const SizedBox(height: 25),
                 
                 Text("Select Subject from List", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                 const SizedBox(height: 10),
                 Autocomplete<Map<String, String>>(
                   displayStringForOption: (Map<String, String> option) => option['name']!,
                   optionsBuilder: (TextEditingValue textEditingValue) {
                     if (_selectedBranch == null || _selectedYear == null) return const Iterable<Map<String, String>>.empty();
                     if (textEditingValue.text == '') {
                       return _fetchedSubjects;
                     }
                     final filtered = _fetchedSubjects.where((Map<String, String> option) {
                       return option['name']!.toLowerCase().contains(textEditingValue.text.toLowerCase()) ||
                              option['id']!.toLowerCase().contains(textEditingValue.text.toLowerCase());
                     }).toList();
                     
                     // Add activity suggestions
                     for (var activity in _activities) {
                        if (activity.toLowerCase().contains(textEditingValue.text.toLowerCase())) {
                           filtered.add({'id': 'ACT', 'name': activity});
                        }
                     }
                     return filtered;
                   },
                   onSelected: (Map<String, String> selection) {
                     setState(() {
                        _subjectController.text = selection['name']!;
                        _subjectCodeController.text = selection['id'] == 'ACT' ? '' : selection['id']!;
                     });
                   },
                   fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      if (controller.text.isEmpty && _subjectController.text.isNotEmpty) {
                          controller.text = _subjectController.text;
                      }
                       return TextField(
                         controller: controller,
                         focusNode: focusNode,
                         onChanged: (val) {
                            _subjectController.text = val;
                            _clearManualSubject();
                         },
                         style: TextStyle(color: textColor),
                         decoration: InputDecoration(
                           hintText: _selectedYear == null ? "Select Year first..." : "Search subject list...",
                           hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                           filled: true,
                           fillColor: cardColor,
                           border: OutlineInputBorder(
                             borderRadius: BorderRadius.circular(10),
                             borderSide: BorderSide(color: tint.withOpacity(0.3)),
                           ),
                           enabledBorder: OutlineInputBorder(
                             borderRadius: BorderRadius.circular(10),
                             borderSide: BorderSide(color: tint.withOpacity(0.3)),
                           ),
                           suffixIcon: _subjectController.text.isNotEmpty ? IconButton(icon: const Icon(Icons.clear, size: 16), onPressed: () {
                               controller.clear();
                               _clearListSubject();
                           }) : null,
                         ),
                       );
                    },
                   optionsViewBuilder: (context, onSelected, options) {
                      return Align(
                        alignment: Alignment.topLeft,
                        child: Material(
                          elevation: 4.0,
                          color: cardColor,
                          child: ConstrainedBox(
                            constraints: BoxConstraints(maxHeight: 250, maxWidth: MediaQuery.of(context).size.width - 40),
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final Map<String, String> option = options.elementAt(index);
                                return InkWell(
                                  onTap: () => onSelected(option),
                                  child: Container(
                                    padding: const EdgeInsets.all(12.0),
                                    decoration: BoxDecoration(
                                      border: Border(bottom: BorderSide(color: textColor.withOpacity(0.05)))
                                    ),
                                    child: Row(
                                      children: [
                                        if (option['id'] != 'ACT')
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(color: tint.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                                            child: Text(option['id']!, style: TextStyle(color: tint, fontSize: 10, fontWeight: FontWeight.bold)),
                                          ),
                                        if (option['id'] != 'ACT') const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(option['name']!, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                              if (option['sem'] != null)
                                                Text(option['sem']!, style: TextStyle(color: subTextColor, fontSize: 10)),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                   },
                 ),
                 
                  if (_subjectCodeController.text.isNotEmpty)
                     Padding(
                       padding: const EdgeInsets.only(top: 8.0, bottom: 8),
                       child: Text("Subject Code: ${_subjectCodeController.text}", style: TextStyle(color: tint, fontSize: 12, fontWeight: FontWeight.bold)),
                     ),

                  const SizedBox(height: 20),
                  Row(
                    children: [
                       const Expanded(child: Divider()),
                       Padding(
                         padding: const EdgeInsets.symmetric(horizontal: 10),
                         child: Text("OR", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12, fontWeight: FontWeight.bold)),
                       ),
                       const Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 20),
                  
                  Text("Enter Subject Manually", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _manualSubjectController,
                    onChanged: (val) {
                        if (val.isNotEmpty) _clearListSubject();
                        setState(() {});
                    },
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      hintText: "e.g. Special Guest Lecture",
                      hintStyle: TextStyle(color: textColor.withOpacity(0.35)),
                       filled: true,
                       fillColor: cardColor,
                       border: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(10),
                         borderSide: BorderSide(color: tint.withOpacity(0.3)),
                       ),
                       enabledBorder: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(10),
                         borderSide: BorderSide(color: tint.withOpacity(0.3)),
                       ),
                    ),
                  ),

                  const SizedBox(height: 40),
                 
                 SizedBox(
                   width: double.infinity,
                   child: ElevatedButton(
                     onPressed: _isLoading ? null : _saveClass,
                     style: ElevatedButton.styleFrom(
                       backgroundColor: tint,
                       padding: const EdgeInsets.symmetric(vertical: 16),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                     ),
                     child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white) 
                        : Text("Assign Class", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                   ),
                 )
               ],
             ),
           ),
         ),
      ),
    );
  }
  
  Widget _buildInfoCard(Color cardColor, Color textColor, Color tint) {
      if (widget.day == null || widget.periodIndex == null) {
          return const SizedBox.shrink();
      }
      return Container(
          margin: const EdgeInsets.only(bottom: 20),
          padding: const EdgeInsets.all(15),
          decoration: BoxDecoration(
              color: tint.withOpacity(0.1),
              borderRadius: BorderRadius.circular(15),
              border: Border.all(color: tint.withOpacity(0.3))
          ),
          child: Row(
              children: [
                  Icon(Icons.schedule, color: tint),
                  const SizedBox(width: 15),
                  Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                          Text("${widget.day} - Period ${widget.periodIndex}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
                          Text("${widget.startTime} - ${widget.endTime}", style: GoogleFonts.poppins(fontSize: 12, color: textColor.withOpacity(0.8))),
                      ],
                  )
              ],
          ),
      );
  }

  Widget _buildDropdown(String label, List<String> items, String? value, Function(String?) onChanged, Color tint, Color textColor, Color cardColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: textColor, fontWeight: FontWeight.w500)),
        const SizedBox(height: 5),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: tint.withOpacity(0.3)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: cardColor,
              icon: Icon(Icons.arrow_drop_down, color: tint),
              hint: Text("Select", style: TextStyle(fontSize: 10, color: textColor.withOpacity(0.5))),
              items: items.map((String item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Text(item, style: TextStyle(color: textColor, fontSize: 12), overflow: TextOverflow.ellipsis),
                );
              }).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
