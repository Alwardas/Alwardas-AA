import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../../../widgets/absent_students_popup.dart';
// Added for rootBundle

class FacultyAttendanceScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const FacultyAttendanceScreen({super.key, this.userData});

  @override
  _FacultyAttendanceScreenState createState() => _FacultyAttendanceScreenState();
}

class _FacultyAttendanceScreenState extends State<FacultyAttendanceScreen> {
  // UI State
  String _step = 'SELECT'; // SELECT | MARK
  String _activeTab = 'Students'; // Self | Students
  
  // Selection State
  String _selectedBranch = 'Computer Engineering';
  String _selectedYear = '1st Year';
  String _selectedSession = 'MORNING'; // MORNING | AFTERNOON
  String _selectedSection = '';
  List<String> _availableSections = [];
  bool _loadingSections = false;
  // ignore: unused_field
  final DateTime _selectedDate = DateTime.now();
  String _searchText = '';

  // Data State
  List<dynamic> _students = [];
  List<String> _selectedStudentIds = [];
  bool _loading = false;

  late String _facultyId; // Changed to String for Login ID (e.g. FAC-001)

  @override
  void initState() {
    super.initState();
    // Default to 'faculty' if no userData (fallback for direct hot-reload dev)
    // But ideally uses the logged in user's login_id
    _facultyId = widget.userData != null ? widget.userData!['login_id'].toString() : 'faculty';
    if (_step == 'MARK') {
      _fetchStudents();
    } else {
       _fetchSections(); // Initial fetch
    }
  }

  Future<void> _fetchSections() async {
    if (_selectedBranch.isEmpty || _selectedYear.isEmpty) return;

    setState(() {
       _loadingSections = true;
       _availableSections = [];
       _selectedSection = '';
    });

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/sections?branch=${Uri.encodeComponent(_selectedBranch)}&year=${Uri.encodeComponent(_selectedYear)}');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _availableSections = data.map((e) => e.toString()).toList();
          if (_availableSections.isNotEmpty) {
             _availableSections.sort();
             _selectedSection = _availableSections.first;
          } else {
             _selectedSection = '';
          }
        });
      } else {
         debugPrint("Failed to fetch sections: ${response.body}");
         setState(() => _availableSections = []);
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Failed to load sections (Status: ${response.statusCode}). Backend might be restarting."),
              action: SnackBarAction(label: 'Retry', onPressed: _fetchSections),
            )
         );
      }
    } catch (e) {
      debugPrint("Error fetching sections: $e");
       setState(() => _availableSections = []);
       ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Connection error. Check network."),
            action: SnackBarAction(label: 'Retry', onPressed: _fetchSections),
          )
       );
    } finally {
      if (mounted) setState(() => _loadingSections = false);
    }
  }

  bool _alreadySubmitted = false;

  Future<void> _checkSubmissionStatus(String branchCode) async {
      _alreadySubmitted = false; // Reset strictly before checking
      try {
        final dateStr = _selectedDate.toIso8601String().split('T')[0];
        // We need an endpoint to check if this batch is done.
        // Heuristic: Check if ANY student in this branch/year has attendance for this date/session.
        // Ideally backend should provide this check. 
        // For now, we'll assume if we fetch students and we find they have 'P' or 'A' status pre-filled ??
        // Actually, let's add a quick check API call or just infer from fetched data if we were fetching attendance state.
        // Since `_fetchStudents` only gets user list, we might need a separate check.
        
        // Simpler: Just Fetch attendance for today for this branch/year?
        // Or adding a lightweight endpoint `/api/attendance/check?branch=...&date=...&session=...`
        
        // Let's implement a simple check by fetch query
        final url = Uri.parse('${ApiConstants.baseUrl}/api/attendance/check?branch=${Uri.encodeComponent(branchCode)}&year=${Uri.encodeComponent(_selectedYear)}&date=$dateStr&session=$_selectedSession&section=${Uri.encodeComponent(_selectedSection)}');
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
            final data = json.decode(response.body);
            setState(() {
                _alreadySubmitted = data['submitted'] == true;
            });
        }
      } catch (e) {
          debugPrint("Check Submission Error: $e");
      }
  }

  bool _isHoliday = false;
  String _holidayReason = '';

  Future<void> _fetchStudents() async {
    setState(() => _loading = true);
    try {
      final dateStr = _selectedDate.toIso8601String().split('T')[0];
      final url = Uri.parse('${ApiConstants.baseUrl}/api/attendance/class-record?'
          'branch=${Uri.encodeComponent(_selectedBranch)}&'
          'year=${Uri.encodeComponent(_selectedYear)}&'
          'session=$_selectedSession&'
          'date=$dateStr&'
          'section=${Uri.encodeComponent(_selectedSection)}');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final bool marked = data['marked'] ?? false;
        final List<dynamic> fetchedStudents = data['students'] ?? [];

        bool holidayDetected = fetchedStudents.any((s) => s['status'] == 'HOLIDAY');
        String reason = '';
        if (holidayDetected) {
            reason = "Holiday Marked"; // Default if reason not in student record
            // If backend eventually sends reason, parse it here
        }

        setState(() {
          _students = fetchedStudents;
          _alreadySubmitted = marked;
          _isHoliday = holidayDetected;
          _holidayReason = reason;
          
          if (marked || holidayDetected) {
            // Pre-select students who were present (if holiday, maybe none or all, but irrelevant as locked)
            _selectedStudentIds = fetchedStudents
                .where((s) => s['status'] == 'PRESENT')
                .map((s) => s['studentId'].toString())
                .toList();
          } else {
             // Default to all selected (present) for fresh marking
             _selectedStudentIds = _students.map((s) => s['studentId'].toString()).toList();
          }
        });
      } else {
        _showErrorDialog("Failed to fetch students from server.");
      }
    } catch (e) {
      _showErrorDialog("Network error: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Okay'))],
      ),
    );
  }

  void _toggleStudent(String id) {
    setState(() {
      if (_selectedStudentIds.contains(id)) {
        _selectedStudentIds.remove(id);
      } else {
        _selectedStudentIds.add(id);
      }
    });
  }

  void _toggleSelectAll() {
    final filtered = _getFilteredStudents();
    final allVisibleIds = filtered.map((s) => s['studentId'].toString()).toList();
    final allSelected = allVisibleIds.every((id) => _selectedStudentIds.contains(id));

    setState(() {
      if (allSelected) {
        _selectedStudentIds.removeWhere((id) => allVisibleIds.contains(id));
      } else {
        for (var id in allVisibleIds) {
          if (!_selectedStudentIds.contains(id)) {
            _selectedStudentIds.add(id);
          }
        }
      }
    });
  }

  List<dynamic> _getFilteredStudents() {
    if (_searchText.isEmpty) return _students;
    return _students.where((s) {
      final name = s['fullName'].toString().toLowerCase();
      final id = s['studentId'].toString().toLowerCase();
      return name.contains(_searchText.toLowerCase()) || id.contains(_searchText.toLowerCase());
    }).toList();
  }

  Future<void> _handleSubmit() async {
    final total = _students.length;
    final present = _students.where((s) => _selectedStudentIds.contains(s['studentId'].toString())).length;
    final absentStudents = _students.where((s) => !_selectedStudentIds.contains(s['studentId'].toString())).toList();
    final absentCount = total - present;

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Text("Confirm Submission", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  _buildSummaryItem(total.toString(), "Total", Colors.blue),
                  _buildSummaryItem(present.toString(), "Present", Colors.green),
                  _buildSummaryItem(absentCount.toString(), "Absent", Colors.red),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text("Are you sure you want to submit the attendance for this session?", 
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey[600])
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.grey, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF6366F1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              elevation: 0,
            ),
            onPressed: () {
              Navigator.pop(ctx);
              _executeSubmission();
            },
            child: Text("Confirm", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600], fontWeight: FontWeight.w500)),
      ],
    );
  }

  Future<void> _executeSubmission() async {
    final records = _students.map((student) => {
      'studentId': student['studentId'],
      'status': _selectedStudentIds.contains(student['studentId'].toString()) ? 'PRESENT' : 'ABSENT'
    }).toList();

    final payload = {
      'session': _selectedSession,
      'date': _selectedDate.toIso8601String(),
      'markedBy': _facultyId,
      'records': records
    };

    // Show loading dialog
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const Center(
        child: CircularProgressIndicator(color: Colors.white),
      ),
    );

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/attendance/batch'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (mounted) Navigator.pop(context); // Dismiss loading dialog

      if (response.statusCode == 200 || response.statusCode == 201) {
         // final result = json.decode(response.body); // Not strictly needed for the message if we use local count
         final presentCount = records.where((r) => r['status'] == 'PRESENT').length;
         final sessionDisplay = _selectedSession.isNotEmpty 
             ? _selectedSession[0] + _selectedSession.substring(1).toLowerCase() 
             : _selectedSession;

         setState(() {
            _alreadySubmitted = true;
         });
         _showSuccessDialog(presentCount, sessionDisplay);
      } else {
         _showErrorDialog("Failed to submit attendance.");
      }
    } catch (e) {
      _showErrorDialog("Network error."); 
    }
  }

  void _showSuccessDialog(int count, String session) {
     showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 28),
            const SizedBox(width: 10),
            Text('Success', style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Marked attendance for $count students', 
              style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
            Text('$session session', 
              style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('OK', style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.bold)))],
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
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard; // Transparent usually
    final tintColor = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;
    final iconBgColor = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;
    final borderColor = iconBgColor;

    final dropdownBgColor = isDark ? Colors.grey[900] : Colors.white;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Attendance', style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: bgColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea( // Use SafeArea to respect AppBar
          child: Column(
            children: [
               // Tab Switcher
               Container(
                 margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                 padding: const EdgeInsets.all(4),
                 decoration: BoxDecoration(
                   color: iconBgColor,
                   borderRadius: BorderRadius.circular(12),
                 ),
                 child: Row(
                   children: [
                     _buildTabButton('Students', tintColor, textColor, subTextColor),
                     _buildTabButton('Self', tintColor, textColor, subTextColor),
                   ],
                 ),
               ),

               Expanded(
                 child: _activeTab == 'Students' 
                  ? (_step == 'SELECT' ? _buildSelectionForm(textColor, subTextColor, tintColor, iconBgColor, cardColor, dropdownBgColor) : _buildMarkingScreen(textColor, subTextColor, tintColor, iconBgColor, cardColor))
                  : _buildSelfTab(textColor, subTextColor, cardColor, borderColor, tintColor),
               ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTabButton(String title, Color tint, Color text, Color subText) {
    final isActive = _activeTab == title;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _activeTab = title),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: isActive ? tint : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            title,
            style: GoogleFonts.poppins(
              color: isActive ? Colors.white : subText,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSelectionForm(Color textColor, Color subTextColor, Color tintColor, Color iconBgColor, Color cardColor, Color? dropdownBgColor) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Container(
        padding: const EdgeInsets.all(25),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 15,
              offset: const Offset(0, 5),
            )
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Class Selection", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFF1e1e2d))),
            Text("Please select details to fetch students", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[600])),
            const SizedBox(height: 30),
            
            _buildDropdown("Branch", _selectedBranch, [
               'Computer Engineering',
               'Civil Engineering',
               'Electrical & Electronics Engineering',
               'Electronics & Communication Engineering',
               'Mechanical Engineering'
            ], (val) {
               setState(() => _selectedBranch = val!);
               _fetchSections();
            }, const Color(0xFF1e1e2d), Colors.grey[600]!, const Color(0xFFf8f9fa), Colors.white, Colors.white),

            _buildDropdown("Year", _selectedYear, ['1st Year', '2nd Year', '3rd Year'], 
              (val) {
                 setState(() => _selectedYear = val!);
                 _fetchSections();
              }, const Color(0xFF1e1e2d), Colors.grey[600]!, const Color(0xFFf8f9fa), Colors.white, Colors.white),

            if (_loadingSections)
               const Padding(padding: EdgeInsets.only(bottom: 20), child: LinearProgressIndicator())
            else if (_availableSections.isNotEmpty)
              _buildDropdown("Section", _selectedSection, _availableSections, 
                (val) => setState(() => _selectedSection = val!), const Color(0xFF1e1e2d), Colors.grey[600]!, const Color(0xFFf8f9fa), Colors.white, Colors.white),

            const SizedBox(height: 10),
            Text("SESSION", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey[600])),
            const SizedBox(height: 10),
            Row(
              children: [
                _buildSessionButton("Morning", "MORNING", tintColor, const Color(0xFF1e1e2d), borderColor: const Color(0xFFe9ecef)),
                const SizedBox(width: 10),
                _buildSessionButton("Afternoon", "AFTERNOON", tintColor, const Color(0xFF1e1e2d), borderColor: const Color(0xFFe9ecef)),
              ],
            ),

            const SizedBox(height: 40),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: tintColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                onPressed: () {
                  setState(() => _step = 'MARK');
                  _fetchStudents();
                },
                child: Text("Fetch Students", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildDropdown(String label, String value, List<String> options, Function(String?) onChanged, Color textColor, Color subTextColor, Color iconBg, Color cardColor, Color? dropdownBgColor) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: subTextColor)),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            decoration: BoxDecoration(
              color: cardColor, // Or minimal bg
              border: Border.all(color: iconBg),
              borderRadius: BorderRadius.circular(12),
            ),
            child: DropdownButtonHideUnderline(
              child: DropdownButton<String>(
                value: value,
                isExpanded: true,
                dropdownColor: dropdownBgColor, 
                icon: Icon(Icons.keyboard_arrow_down, color: subTextColor),
                style: GoogleFonts.poppins(fontSize: 16, color: textColor),
                onChanged: onChanged,
                items: options.map((String val) {
                   return DropdownMenuItem<String>(
                     value: val,
                     child: FittedBox(
                       fit: BoxFit.scaleDown,
                       alignment: Alignment.centerLeft,
                       child: Text(val, style: GoogleFonts.poppins(color: textColor)),
                     ), // Ensure text color is right in light/dark
                   );
                }).toList(),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSessionButton(String label, String value, Color tintColor, Color textColor, {Color? borderColor}) {
    final isSelected = _selectedSession == value;
    return Expanded(
      child: GestureDetector(
        onTap: () => setState(() => _selectedSession = value),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: BoxDecoration(
            color: isSelected ? tintColor : Colors.transparent,
            border: Border.all(color: isSelected ? tintColor : (borderColor ?? Colors.grey)),
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.poppins(
              color: isSelected ? Colors.white : textColor,
              fontWeight: FontWeight.bold,
              fontSize: 16,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMarkingScreen(Color textColor, Color subTextColor, Color tintColor, Color iconBgColor, Color cardColor) {
    if (_loading) return Center(child: CircularProgressIndicator(color: tintColor));
    
    final filtered = _getFilteredStudents();
    final total = filtered.length;
    final present = filtered.where((s) => _selectedStudentIds.contains(s['studentId'].toString())).length;
    final absentStudents = filtered.where((s) => !_selectedStudentIds.contains(s['studentId'].toString())).toList();
    final absent = total - present;

    return Stack(
      children: [
        Column(
          children: [
             // Controls
             Padding(
               padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
               child: Column(
                 children: [
                   Row(
                     children: [
                       IconButton(onPressed: () => setState(() => _step = 'SELECT'), icon: Icon(Icons.arrow_back, color: textColor)),
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             FittedBox(
                               fit: BoxFit.scaleDown,
                               alignment: Alignment.centerLeft,
                               child: Text("$_selectedBranch - $_selectedYear", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
                             ),
                             Text(_selectedSession, style: GoogleFonts.poppins(fontSize: 12, color: subTextColor)),
                           ],
                         ),
                       )
                     ],
                   ),
                   const SizedBox(height: 10),
                   // Search
                   Container(
                     padding: const EdgeInsets.symmetric(horizontal: 12),
                     decoration: BoxDecoration(
                       color: cardColor,
                       border: Border.all(color: iconBgColor),
                       borderRadius: BorderRadius.circular(12),
                     ),
                     child: TextField(
                       style: GoogleFonts.poppins(color: textColor),
                       decoration: InputDecoration(
                         icon: Icon(Icons.search, color: subTextColor),
                         hintText: "Search Name or ID",
                         hintStyle: GoogleFonts.poppins(color: subTextColor),
                         border: InputBorder.none,
                       ),
                       onChanged: (val) => setState(() => _searchText = val),
                     ),
                   ),
                   // Select All
                   if (!_alreadySubmitted && !_isHoliday)
                   Align(
                     alignment: Alignment.centerRight,
                     child: TextButton(
                       onPressed: _toggleSelectAll, 
                       child: Text(filtered.isNotEmpty && _selectedStudentIds.length == filtered.length ? "Unselect All" : "Select All", style: GoogleFonts.poppins(color: tintColor, fontWeight: FontWeight.bold))
                     ),
                   ),
                 ],
               ),
             ),

             // List
             Expanded(
               child: ListView.builder(
                 padding: const EdgeInsets.symmetric(horizontal: 20),
                 itemCount: filtered.length,
                 itemBuilder: (context, index) {
                   final student = filtered[index];
                   final id = student['studentId'].toString();
                   final isSelected = _selectedStudentIds.contains(id);
                   return GestureDetector(
                     onTap: (_alreadySubmitted || _isHoliday) ? null : () => _toggleStudent(id),
                     child: Container(
                       margin: const EdgeInsets.only(bottom: 10),
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         color: cardColor,
                         border: Border.all(color: iconBgColor),
                         borderRadius: BorderRadius.circular(16),
                       ),
                       child: Row(
                         children: [
                           Expanded(
                             child: Column(
                               crossAxisAlignment: CrossAxisAlignment.start,
                               children: [
                                 Text(id, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                                 Text(student['fullName'], style: GoogleFonts.poppins(fontSize: 14, color: subTextColor)),
                               ],
                             ),
                           ),
                           Container(
                             width: 24, height: 24,
                             decoration: BoxDecoration(
                               color: isSelected ? Colors.green : Colors.transparent,
                               border: Border.all(color: isSelected ? Colors.green : subTextColor, width: 2),
                               borderRadius: BorderRadius.circular(6),
                             ),
                             child: isSelected ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
                           )
                         ],
                       ),
                     ),
                   );
                 },
               ),
             ),
             
             // Footer
             Container(
               padding: const EdgeInsets.all(20),
               decoration: BoxDecoration(
                 color: cardColor,
                 border: Border(top: BorderSide(color: iconBgColor)),
                 borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
               ),
               child: Column(
                 children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Text("Present: $present", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.green)),
                       GestureDetector(onTap:()=>AbsentStudentsPopup.show(context,absentStudents,"Absent Students"),child:Text("Absent: $absent", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.red))),
                       Text("Total: $total", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: subTextColor)),
                     ],
                   ),
                   const SizedBox(height: 15),
                   SizedBox(
                     width: double.infinity,
                     child: ElevatedButton(
                       style: ElevatedButton.styleFrom(
                         backgroundColor: _alreadySubmitted ? Colors.grey : tintColor,
                         padding: const EdgeInsets.symmetric(vertical: 15),
                         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                       ),
                        onPressed: (_alreadySubmitted || _isHoliday) ? null : _handleSubmit,
                        child: Text(_isHoliday ? "Holiday (Locked)" : (_alreadySubmitted ? "Submitted (View Only)" : "Submit Attendance"), style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                      ),
                   ),
                 ],
               ),
             )
          ],
        ),

        // Watermark Bloat overlay
        if (_alreadySubmitted || _isHoliday)
          Positioned.fill(
              child: IgnorePointer(
                  child: Container(
                      color: Colors.white.withValues(alpha: 0.05), // Subtle fade
                      alignment: Alignment.center,
                      child: Transform.rotate(
                          angle: -0.5,
                          child: Opacity(
                            opacity: 0.15,
                            child: Text(
                                _isHoliday ? "HOLIDAY" : "SUBMITTED",
                                style: GoogleFonts.blackOpsOne(
                                    fontSize: 60, 
                                    color: _isHoliday ? Colors.blue : textColor, 
                                    fontWeight: FontWeight.bold
                                ),
                            ),
                          ),
                      ),
                  ),
              ),
          )
      ],
    );
  }

  Widget _buildSelfTab(Color textColor, Color subTextColor, Color cardColor, Color borderColor, Color tintColor) {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: cardColor,
              border: Border.all(color: borderColor),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("My Attendance", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildStatItem("95%", "Overall", tintColor),
                    _buildStatItem("120", "Present", textColor),
                    _buildStatItem("4", "Leaves", Colors.red),
                  ],
                )
              ],
            ),
          ),
          const SizedBox(height: 20),
          Text("Detailed history coming soon...", style: GoogleFonts.poppins(color: subTextColor, fontStyle: FontStyle.italic)),
        ],
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: color)),
        Text(label, style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)), // Simplified subtext
      ],
    );
  }
}
