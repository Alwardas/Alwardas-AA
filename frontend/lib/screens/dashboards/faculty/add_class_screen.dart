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
import 'package:intl/intl.dart';

class AddClassScreen extends StatefulWidget {
  final Map<String, dynamic>? initialData;
  final String day;
  final int periodIndex;
  final String startTime;
  final String endTime;

  const AddClassScreen({
    super.key,
    this.initialData,
    required this.day,
    required this.periodIndex,
    required this.startTime,
    required this.endTime,
  });

  @override
  _AddClassScreenState createState() => _AddClassScreenState();
}

class _AddClassScreenState extends State<AddClassScreen> {
  // Dropdown Values
  String? _selectedBranch;
  String? _selectedYear;
  String? _selectedSection;
  
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _subjectCodeController = TextEditingController();
  
  bool _isLoading = false;
  List<String> _sections = [];
  List<Map<String, String>> _fetchedSubjects = [];

  // Options
  final List<String> _branches = ["CME", "EEE", "ECE", "MEC", "CIV"];
  final List<String> _years = ["1st Year", "2nd Year", "3rd Year"];
  
  // Activities for dropdown suggestions
  final List<String> _activities = ["Games", "Library", "Digital Class", "Seminar", "Workshop", "Self Study"];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _selectedBranch = widget.initialData!['branch'];
      _selectedYear = widget.initialData!['year'];
      _selectedSection = widget.initialData!['section'];
      _subjectController.text = widget.initialData!['subject'] ?? '';
      _subjectCodeController.text = widget.initialData!['subjectCode'] ?? '';
      _fetchSections();
      _loadSubjectsFromJson();
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
        // Map 3rd Semester to 2nd Year, 5th to 3rd Year etc if needed
        // But user said 1st Year, 2nd Year, 3rd Year. 
        // Let's check keys in subject.json
        String semesterKey = _selectedYear!;
        // Handle semester mapping if necessary
        if (_selectedYear == "2nd Year") semesterKey = "3rd Semester"; 
        if (_selectedYear == "3rd Year") semesterKey = "5th Semester";

        final semesterData = branchData['semesters'][semesterKey];
        if (semesterData != null) {
          List<Map<String, String>> subjects = [];
          if (semesterData['theory'] != null) {
            for (var s in semesterData['theory']) {
              subjects.add({'id': s['id'].toString(), 'name': s['name'].toString()});
            }
          }
          if (semesterData['practical'] != null) {
            for (var s in semesterData['practical']) {
              subjects.add({'id': s['id'].toString(), 'name': s['name'].toString()});
            }
          }
          setState(() {
            _fetchedSubjects = subjects;
          });
        }
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
    if (_selectedBranch == null || _selectedYear == null || _selectedSection == null || _subjectController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please fill all fields")));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final facultyId = prefs.getString('faculty_id') ?? '';
      
      String fid = facultyId;
      if (fid.isEmpty) {
          final userData = prefs.getString('user_session');
          if (userData != null) {
              fid = jsonDecode(userData)['login_id']; 
          }
      }

      final body = {
        'facultyId': fid,
        'branch': _mapBranchToFull(_selectedBranch!),
        'year': _selectedYear,
        'section': _selectedSection,
        'day': widget.day,
        'periodIndex': widget.periodIndex,
        'subject': _subjectController.text,
        'subjectCode': _subjectCodeController.text.isEmpty ? null : _subjectCodeController.text,
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
          final format = DateFormat("hh:mm a"); 
          final DateTime parsedTime = format.parse(widget.startTime);
          int targetWeekday = _getWeekdayIndex(widget.day);
          
          DateTime now = DateTime.now();
          DateTime scheduledDate = DateTime(now.year, now.month, now.day, parsedTime.hour, parsedTime.minute);
          
          while (scheduledDate.weekday != targetWeekday || scheduledDate.isBefore(now)) {
              scheduledDate = scheduledDate.add(const Duration(days: 1));
          }

          int id = targetWeekday * 100 + widget.periodIndex;
          String subInfo = _subjectController.text;
          if (_subjectCodeController.text.isNotEmpty) {
              subInfo = "${_subjectCodeController.text}: $subInfo";
          }

          await NotificationService.scheduleClassNotification(
              id: id,
              title: "Upcoming Class",
              body: "Branch: $_selectedBranch, Year: $_selectedYear, Section: $_selectedSection - $subInfo at ${widget.startTime}",
              scheduledTime: scheduledDate
          );
      } catch (e) {
          debugPrint("Date Parsing Error: $e");
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
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
                 const SizedBox(height: 30),
                 
                 Row(
                   children: [
                     Expanded(child: _buildDropdown("Branch", _branches, _selectedBranch, (val) {
                       setState(() { _selectedBranch = val; _selectedSection = null; _fetchedSubjects = []; });
                       _fetchSections();
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
                 
                 const SizedBox(height: 20),
                 
                 Text("Subject", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w500)),
                 const SizedBox(height: 10),
                 Autocomplete<Map<String, String>>(
                   displayStringForOption: (Map<String, String> option) => option['name']!,
                   optionsBuilder: (TextEditingValue textEditingValue) {
                     if (textEditingValue.text == '') {
                       return _fetchedSubjects.take(5);
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
                           // If value changed manually, check if it matches a known subject to auto-fill code?
                           // Or just leave code empty if not selected from list.
                        },
                        style: TextStyle(color: textColor),
                        decoration: InputDecoration(
                          hintText: "Search or enter manually...",
                          hintStyle: TextStyle(color: textColor.withOpacity(0.5)),
                          filled: true,
                          fillColor: cardColor,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
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
                            constraints: const BoxConstraints(maxHeight: 250, maxWidth: 350),
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
                                        Expanded(child: Text(option['name']!, style: TextStyle(color: textColor))),
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
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text("Subject Code: ${_subjectCodeController.text}", style: TextStyle(color: tint, fontSize: 12, fontWeight: FontWeight.bold)),
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
      return Container(
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
                          Text(widget.day, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
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
