import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/api_constants.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/services/auth_service.dart';

class HodAssignClassScreen extends StatefulWidget {
  final String branch;
  final String year;
  final String section;
  final String? initialDay;
  final int? initialPeriod;

  const HodAssignClassScreen({
    super.key,
    required this.branch,
    required this.year,
    required this.section,
    this.initialDay,
    this.initialPeriod,
  });

  @override
  _HodAssignClassScreenState createState() => _HodAssignClassScreenState();
}

class _HodAssignClassScreenState extends State<HodAssignClassScreen> {
  String? _selectedDay;
  int? _selectedPeriod;
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _manualSubjectController = TextEditingController();
  
  bool _isLoading = false;
  List<int> _availablePeriods = [1, 2, 3, 4, 5, 6, 7, 8];
  Map<int, Map<String, String>> _periodTimes = {};
  List<Map<String, String>> _fetchedSubjects = [];
  
  String? _selectedBranch;
  String? _selectedYear;
  String? _selectedSection;
  List<String> _sectionsList = [];

  final List<String> _daysList = ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"];
  final List<String> _yearsList = ["1st Year", "2nd Year", "3rd Year"];
  final List<String> _activities = ["Games", "Library", "Digital Class", "Seminar", "Workshop", "Self Study"];

  @override
  void initState() {
    super.initState();
    _selectedDay = widget.initialDay ?? _daysList[0];
    _selectedPeriod = widget.initialPeriod;
    _selectedBranch = widget.branch;
    _selectedYear = widget.year;
    _selectedSection = widget.section;

    _fetchTimings();
    _fetchSections();
    _loadSubjectsFromJson();
  }

  Future<void> _fetchSections() async {
    if (_selectedBranch == null || _selectedYear == null) return;
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/sections?branch=${Uri.encodeComponent(_selectedBranch!)}&year=${Uri.encodeComponent(_selectedYear!)}');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        final List<dynamic> fetched = json.decode(res.body);
        setState(() {
          _sectionsList = fetched.map((e) => e.toString()).toList();
          if (_sectionsList.isEmpty) _sectionsList = ["A"];
          if (!_sectionsList.contains(_selectedSection)) {
            _selectedSection = _sectionsList.first;
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching sections: $e");
    }
  }

  Future<void> _fetchTimings() async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/department/timing')
          .replace(queryParameters: {'branch': _selectedBranch ?? widget.branch});
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

      if (mounted) {
        setState(() {
          _availablePeriods = periods;
          _periodTimes = newTimes;
        });
      }
    } catch (e) {
      debugPrint("Error fetching timings: $e");
    }
  }

  Future<void> _loadSubjectsFromJson() async {
    try {
      final String response = await rootBundle.loadString('assets/data/json/subject.json');
      final List<dynamic> data = json.decode(response);
      
      final branchData = data.firstWhere(
        (b) => b['branch_name'] == (_selectedBranch ?? widget.branch),
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
                        subjects.add({'name': s['name'].toString(), 'sem': semKey});
                    }
                }
                if (semesterData['practical'] != null) {
                    for (var s in semesterData['practical']) {
                        subjects.add({'name': s['name'].toString(), 'sem': semKey});
                    }
                }
            }
        }
        if (mounted) setState(() => _fetchedSubjects = subjects);
      }
    } catch (e) {
      debugPrint("Error loading subjects: $e");
    }
  }

  Future<void> _handleAssign() async {
    final String subject = _manualSubjectController.text.isNotEmpty 
        ? _manualSubjectController.text 
        : _subjectController.text;

    if (_selectedDay == null || _selectedPeriod == null || subject.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select Day, Period and Subject")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final user = await AuthService.getUserSession();
      if (user == null) return;
      
      final body = {
        'facultyId': user['login_id'] ?? user['id'], // Set HOD as faculty
        'branch': _selectedBranch,
        'year': _selectedYear,
        'section': _selectedSection,
        'day': _selectedDay,
        'periodIndex': _selectedPeriod,
        'subject': subject,
      };

      final res = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/timetable/assign'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body)
      );

      if (res.statusCode == 200) {
        Navigator.pop(context, true);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to assign class")));
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network Error")));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColor = isDark ? ThemeColors.darkBackground.first : ThemeColors.lightBackground.first;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Assign Class", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header Info
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: tint.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tint.withOpacity(0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                     children: [
                       Expanded(
                         child: _buildDropdown(
                           label: "Year", 
                           value: _selectedYear, 
                           items: _yearsList, 
                           onChanged: (val) {
                             setState(() => _selectedYear = val);
                             _fetchSections();
                             _loadSubjectsFromJson();
                           },
                           cardColor: cardColor, tint: tint, textColor: textColor
                         ),
                       ),
                       const SizedBox(width: 12),
                       Expanded(
                         child: _buildDropdown(
                           label: "Section", 
                           value: _selectedSection, 
                           items: _sectionsList.isEmpty ? ["A"] : _sectionsList, 
                           onChanged: (val) => setState(() => _selectedSection = val),
                           cardColor: cardColor, tint: tint, textColor: textColor
                         ),
                       ),
                     ],
                   ),
                   const SizedBox(height: 12),
                   Text(_selectedBranch ?? widget.branch, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: tint)),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Dropdowns row
            Row(
              children: [
                Expanded(
                  child: _buildDropdown(
                    label: "Day", 
                    value: _selectedDay, 
                    items: _daysList, 
                    onChanged: (val) => setState(() => _selectedDay = val),
                    cardColor: cardColor, tint: tint, textColor: textColor
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: _buildDropdown(
                    label: "Period", 
                    value: _selectedPeriod?.toString(), 
                    items: _availablePeriods.map((e) => e.toString()).toList(), 
                    onChanged: (val) => setState(() => _selectedPeriod = int.tryParse(val ?? '')),
                    cardColor: cardColor, tint: tint, textColor: textColor
                  ),
                ),
              ],
            ),
            
            if (_selectedPeriod != null && _periodTimes.containsKey(_selectedPeriod))
              Padding(
                padding: const EdgeInsets.only(top: 8, left: 4),
                child: Text(
                  "${_periodTimes[_selectedPeriod]!['start']} - ${_periodTimes[_selectedPeriod]!['end']}",
                  style: GoogleFonts.poppins(fontSize: 11, color: tint, fontWeight: FontWeight.bold),
                ),
              ),

            const SizedBox(height: 30),

            // Subject Autocomplete
            Text("Select Subject", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 14)),
            const SizedBox(height: 12),
            Autocomplete<Map<String, String>>(
              displayStringForOption: (option) => option['name']!,
              optionsBuilder: (textValue) {
                if (textValue.text == '') return _fetchedSubjects;
                final filtered = _fetchedSubjects.where((option) => 
                  option['name']!.toLowerCase().contains(textValue.text.toLowerCase())
                ).toList();
                
                for (var activity in _activities) {
                  if (activity.toLowerCase().contains(textValue.text.toLowerCase())) {
                    filtered.add({'name': activity, 'sem': 'Activity'});
                  }
                }
                return filtered;
              },
              onSelected: (selection) => setState(() {
                _subjectController.text = selection['name']!;
                _manualSubjectController.clear();
              }),
              fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                if (controller.text.isEmpty && _subjectController.text.isNotEmpty) {
                  controller.text = _subjectController.text;
                }
                return TextField(
                  controller: controller,
                  focusNode: focusNode,
                  style: TextStyle(color: textColor),
                  onChanged: (val) {
                    _subjectController.text = val;
                    if (val.isNotEmpty) _manualSubjectController.clear();
                  },
                  decoration: InputDecoration(
                    hintText: "Search subject list...",
                    hintStyle: TextStyle(color: textColor.withOpacity(0.3)),
                    filled: true,
                    fillColor: cardColor,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tint.withOpacity(0.2))),
                    enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tint.withOpacity(0.2))),
                  ),
                );
              },
              optionsViewBuilder: (context, onSelected, options) {
                return Align(
                  alignment: Alignment.topLeft,
                  child: Material(
                    elevation: 8,
                    color: cardColor,
                    borderRadius: BorderRadius.circular(12),
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxHeight: 250, maxWidth: MediaQuery.of(context).size.width - 40),
                      child: ListView.builder(
                        padding: EdgeInsets.zero,
                        shrinkWrap: true,
                        itemCount: options.length,
                        itemBuilder: (ctx, index) {
                          final option = options.elementAt(index);
                          return InkWell(
                            onTap: () => onSelected(option),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(border: Border(bottom: BorderSide(color: textColor.withOpacity(0.05)))),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(option['name']!, style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                                  if (option['sem'] != null)
                                    Text(option['sem']!, style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 10)),
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

            const SizedBox(height: 24),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Text("OR", style: TextStyle(color: textColor.withOpacity(0.3), fontWeight: FontWeight.bold, fontSize: 12)),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            const SizedBox(height: 24),

            // Manual Entry
            Text("Enter Subject Manually", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 14)),
            const SizedBox(height: 12),
            TextField(
              controller: _manualSubjectController,
              style: TextStyle(color: textColor),
              onChanged: (val) {
                if (val.isNotEmpty) _subjectController.clear();
              },
              decoration: InputDecoration(
                hintText: "e.g. Special Lecture",
                hintStyle: TextStyle(color: textColor.withOpacity(0.3)),
                filled: true,
                fillColor: cardColor,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tint.withOpacity(0.2))),
                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: tint.withOpacity(0.2))),
              ),
            ),

            const SizedBox(height: 40),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _isLoading ? null : _handleAssign,
                style: ElevatedButton.styleFrom(
                  backgroundColor: tint,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 5,
                  shadowColor: tint.withOpacity(0.3),
                ),
                child: _isLoading 
                  ? const CircularProgressIndicator(color: Colors.white)
                  : Text("Assign Class", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown({
    required String label, 
    required String? value, 
    required List<String> items, 
    required Function(String?) onChanged,
    required Color cardColor, required Color tint, required Color textColor
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: textColor.withOpacity(0.7))),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: tint.withOpacity(0.2)),
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: items.contains(value) ? value : null,
              isExpanded: true,
              dropdownColor: cardColor,
              icon: Icon(Icons.keyboard_arrow_down, color: tint),
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: TextStyle(color: textColor, fontSize: 14)))).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
