import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
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
  
  bool _isLoading = false;
  List<String> _sections = [];

  // Options
  final List<String> _branches = ["CME", "EEE", "ECE", "MEC", "CIV"];
  final List<String> _years = ["1st Year", "2nd Year", "3rd Year"];
  
  // Example Subjects (Should ideally be fetched, but user said "drop downlist contanis all subjects list can manually search")
  // We'll use a hardcoded list + API subject list merge later or just allow free text with suggestions.
  final List<String> _commonSubjects = [
    "Mathematics I", "Physics", "Chemistry", "C Programming", "Data Structures", 
    "Digital Logic", "Microprocessors", "Thermodynamics", "Fluid Mechanics", 
    "Control Systems", "Machine Learning", "Cloud Computing", "Games", "Library", "Digital Class"
  ];

  @override
  void initState() {
    super.initState();
    if (widget.initialData != null) {
      _selectedBranch = widget.initialData!['branch'];
      _selectedYear = widget.initialData!['year'];
      _selectedSection = widget.initialData!['section'];
      _subjectController.text = widget.initialData!['subject'] ?? '';
      _fetchSections();
    }
  }

  Future<void> _fetchSections() async {
    if (_selectedBranch == null || _selectedYear == null) return;
    
    // Convert short branch to full if needed by API, but let's assume API handles normalized or we send full.
    // Actually Backend expects "Computer Engineering" etc.
    // User wants "CME" in UI. We should map it.
    
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
      case "EEE": return "Electrical & Electronics Engineering";
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
      final facultyId = prefs.getString('faculty_id') ?? ''; // Should be stored on login
      // If not stored, we might need to fetch profile or user session again.
      // Assuming 'user_data' key has JSON.
      
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
        'subject': _subjectController.text
      };

      final res = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/timetable/assign'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body)
      );

      if (res.statusCode == 200) {
        // Schedule Notification
        try {
           await _scheduleNotification();
        } catch (e) {
           debugPrint("Notification Error: $e");
        }

        Navigator.pop(context, true); // Return true to refresh
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
      // Parse Time "09:00 AM"
      try {
          // Remove spaces for robust parsing if needed, but DateFormat handles it
          // Format expected: hh:mm a
          final format = DateFormat("hh:mm a"); 
          final DateTime parsedTime = format.parse(widget.startTime);
          
          // Find next instance of Day
          // widget.day is "Monday", "Tuesday"...
          int targetWeekday = _getWeekdayIndex(widget.day);
          
          DateTime now = DateTime.now();
          DateTime scheduledDate = DateTime(now.year, now.month, now.day, parsedTime.hour, parsedTime.minute);
          
          while (scheduledDate.weekday != targetWeekday || scheduledDate.isBefore(now)) {
              scheduledDate = scheduledDate.add(const Duration(days: 1));
          }

          // ID: Unique ID based on Day + Period?
          // dayIndex * 100 + periodIndex
          int id = targetWeekday * 100 + widget.periodIndex;

          await NotificationService.scheduleClassNotification(
              id: id,
              title: "Class Reminder",
              body: "You have a class: ${_selectedBranch} - ${_selectedYear} - ${_selectedSection} : ${_subjectController.text}",
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
    
    // Calculate full background to avoid transparency issues
    final bgColor = isDark ? ThemeColors.darkBackground.first : ThemeColors.lightBackground.first; // Just use first for solid

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text(widget.initialData == null ? "Assign Class" : "Edit Class", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
         // Ensure solid background is visually consistent if gradients used elsewhere
         decoration: BoxDecoration(
           color: bgColor
         ),
         child: SafeArea(
           child: SingleChildScrollView(
             padding: const EdgeInsets.all(20),
             child: Column(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 _buildInfoCard(cardColor, textColor, tint),
                 const SizedBox(height: 30),
                 
                 // Branch, Year, Section Row
                 Row(
                   children: [
                     Expanded(child: _buildDropdown("Branch", _branches, _selectedBranch, (val) {
                       setState(() { _selectedBranch = val; _selectedSection = null; });
                       _fetchSections();
                     }, tint, textColor, cardColor)),
                     const SizedBox(width: 10),
                     Expanded(child: _buildDropdown("Year", _years, _selectedYear, (val) {
                       setState(() { _selectedYear = val; _selectedSection = null; });
                       _fetchSections();
                     }, tint, textColor, cardColor)),
                     const SizedBox(width: 10),
                     Expanded(child: _buildDropdown("Section", _sections, _selectedSection, (val) => setState(() => _selectedSection = val), tint, textColor, cardColor)),
                   ],
                 ),
                 
                 const SizedBox(height: 20),
                 
                 // Subject
                 Text("Subject", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w500)),
                 const SizedBox(height: 10),
                 Autocomplete<String>(
                   optionsBuilder: (TextEditingValue textEditingValue) {
                     if (textEditingValue.text == '') {
                       return const Iterable<String>.empty();
                     }
                     return _commonSubjects.where((String option) {
                       return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                     });
                   },
                   onSelected: (String selection) {
                     _subjectController.text = selection;
                   },
                   fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                      // Sync controller if editing
                      if (controller.text.isEmpty && _subjectController.text.isNotEmpty) {
                          controller.text = _subjectController.text;
                      }
                      
                      return TextField(
                        controller: controller, // Use the Autocomplete's controller for display
                        focusNode: focusNode,
                        onChanged: (val) => _subjectController.text = val, // Sync back
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
                            constraints: const BoxConstraints(maxHeight: 200, maxWidth: 300), // Restrict width
                            child: ListView.builder(
                              padding: EdgeInsets.zero,
                              shrinkWrap: true,
                              itemCount: options.length,
                              itemBuilder: (BuildContext context, int index) {
                                final String option = options.elementAt(index);
                                return InkWell(
                                  onTap: () => onSelected(option),
                                  child: Container(
                                    padding: const EdgeInsets.all(16.0),
                                    child: Text(option, style: TextStyle(color: textColor)),
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                      );
                   },
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
