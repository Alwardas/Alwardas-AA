import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../core/api_constants.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../widgets/custom_modal_dropdown.dart';

class InchargeTrackingScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const InchargeTrackingScreen({super.key, required this.userData});

  @override
  State<InchargeTrackingScreen> createState() => _InchargeTrackingScreenState();
}

class _InchargeTrackingScreenState extends State<InchargeTrackingScreen> {
  String? _selectedBranch;
  String? _selectedYear;
  String? _selectedSection;
  String? _selectedPeriod;
  String? _currentDay;

  List<String> _branches = [];
  List<String> _years = ['1st Year', '2nd Year', '3rd Year'];
  List<String> _sections = [];
  List<String> _subjects = [];
  final List<String> _periods = ['P1', 'P2', 'P3', 'P4', 'P5', 'P6', 'P7', 'P8'];

  // Timetable lookup results
  String _originalSubject = "---";
  String _originalFaculty = "---";
  bool _isLoadingTimetable = false;

  // Manual / Substitute fields
  final TextEditingController _actualSubjectController = TextEditingController();
  final TextEditingController _actualFacultyController = TextEditingController();

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _currentDay = DateFormat('EEEE').format(DateTime.now());
    _fetchBranches();
  }

  Future<void> _fetchBranches() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/hod/departments'));
      if (response.statusCode == 200) {
        setState(() {
          _branches = List<String>.from(json.decode(response.body));
        });
      }
    } catch (e) {
      debugPrint("Error fetching branches: $e");
    }
  }

  Future<void> _fetchSections() async {
    if (_selectedBranch == null || _selectedYear == null) return;
    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/hod/sections?branch=$_selectedBranch&year=$_selectedYear'));
      if (response.statusCode == 200) {
        setState(() {
          _sections = List<String>.from(json.decode(response.body));
        });
      }
    } catch (e) {
      debugPrint("Error fetching sections: $e");
    }
  }

  Future<void> _fetchSubjects() async {
    if (_selectedBranch == null || _selectedYear == null) return;
    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/hod/subjects?branch=$_selectedBranch&year=$_selectedYear'));
      if (response.statusCode == 200) {
        setState(() {
          _subjects = List<String>.from(json.decode(response.body));
        });
      }
    } catch (e) {
      debugPrint("Error fetching subjects: $e");
    }
  }

  Future<void> _lookupTimetable() async {
    if (_selectedBranch == null || _selectedYear == null || _selectedSection == null || _selectedPeriod == null) return;
    
    setState(() => _isLoadingTimetable = true);
    try {
      final periodIndex = _periods.indexOf(_selectedPeriod!);
      final url = Uri.parse('${ApiConstants.baseUrl}/api/incharge/timetable-lookup?branch=$_selectedBranch&year=$_selectedYear&section=$_selectedSection&day=$_currentDay&period_index=$periodIndex');
      final response = await http.get(url);
      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _originalSubject = data['subject'];
          _originalFaculty = data['faculty'];
          _actualSubjectController.text = _originalSubject;
          _actualFacultyController.text = _originalFaculty;
        });
      }
    } catch (e) {
      debugPrint("Lookup Error: $e");
    } finally {
      setState(() => _isLoadingTimetable = false);
    }
  }

  Future<void> _updateStatus(String status, {String? subSubject, String? subFaculty}) async {
    if (_selectedBranch == null || _selectedYear == null || _selectedSection == null || _selectedPeriod == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select all filters first")));
      return;
    }

    final user = await AuthService.getUserSession();
    if (user == null) return;

    setState(() => _isLoading = true);
    try {
      final periodIndex = _periods.indexOf(_selectedPeriod!);
      final payload = {
        "branch": _selectedBranch,
        "year": _selectedYear,
        "section": _selectedSection,
        "day": _currentDay,
        "periodIndex": periodIndex,
        "statusDate": DateFormat('yyyy-MM-dd').format(DateTime.now()),
        "originalSubject": _originalSubject,
        "originalFaculty": _originalFaculty,
        "actualSubject": subSubject ?? _originalSubject,
        "actualFaculty": subFaculty ?? _originalFaculty,
        "status": status,
        "updatedBy": user['id'],
      };

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/incharge/update-status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text("Class status marked as ${status.replaceAll('_', ' ')}"),
          backgroundColor: status == 'conducted' ? Colors.green : (status == 'substitute' ? Colors.orange : Colors.red),
        ));
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update status")));
      }
    } catch (e) {
      debugPrint("Update Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Timetable Tracking", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        foregroundColor: textColor,
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Text(
                _currentDay!,
                style: GoogleFonts.poppins(color: theme.primaryColor, fontWeight: FontWeight.bold),
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Row 1: Branch, Year, Section
            Row(
              children: [
                Expanded(
                  child: CustomModalDropdown(
                    label: 'Branch',
                    value: _selectedBranch,
                    options: _branches,
                    onChanged: (val) {
                      setState(() {
                        _selectedBranch = val;
                        _selectedSection = null;
                        _fetchSections();
                        _fetchSubjects();
                        _lookupTimetable();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomModalDropdown(
                    label: 'Year',
                    value: _selectedYear,
                    options: _years,
                    onChanged: (val) {
                      setState(() {
                        _selectedYear = val;
                        _selectedSection = null;
                        _fetchSections();
                        _fetchSubjects();
                        _lookupTimetable();
                      });
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: CustomModalDropdown(
                    label: 'Section',
                    value: _selectedSection,
                    options: _sections,
                    onChanged: (val) {
                      setState(() {
                        _selectedSection = val;
                        _lookupTimetable();
                      });
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            
            // Row 2: Period
            CustomModalDropdown(
              label: 'Period',
              value: _selectedPeriod,
              options: _periods,
              onChanged: (val) {
                setState(() {
                  _selectedPeriod = val;
                  _lookupTimetable();
                });
              },
            ),
            const SizedBox(height: 32),
            
            // Details Display
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.grey[50],
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: theme.primaryColor.withOpacity(0.1)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Assigned Class", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey, fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  if (_isLoadingTimetable)
                    const Center(child: CircularProgressIndicator())
                  else
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailRow("Subject", _originalSubject, Icons.auto_stories_rounded, theme.primaryColor),
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Divider(height: 1),
                        ),
                        _buildDetailRow("Faculty", _originalFaculty, Icons.person_rounded, const Color(0xFF10B981)),
                      ],
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 40),
            
            Text("Update Actual Status", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
            const SizedBox(height: 20),
            
            // Action Buttons
            _buildStatusAction(
              "Assigned Faculty Conducted Class",
              "Standard class as per timetable",
              Icons.check_circle_rounded,
              Colors.green,
              isDark,
              () => _updateStatus("conducted"),
            ),
            const SizedBox(height: 16),
            _buildStatusAction(
              "Substitute Faculty / Subject",
              "Class taken by different person/topic",
              Icons.swap_horiz_rounded,
              Colors.orange,
              isDark,
              _showSubstituteDialog,
            ),
            const SizedBox(height: 16),
            _buildStatusAction(
              "No Faculty Attended",
              "Class slot was empty/not conducted",
              Icons.cancel_rounded,
              Colors.red,
              isDark,
              () => _updateStatus("not_conducted"),
            ),
            
            const SizedBox(height: 100),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value, IconData icon, Color color) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 16),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
            Text(value, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatusAction(String title, String subtitle, IconData icon, Color color, bool isDark, VoidCallback onTap) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            border: Border.all(color: color.withOpacity(0.3)),
            borderRadius: BorderRadius.circular(15),
            color: color.withOpacity(0.02),
          ),
          child: Row(
            children: [
              Icon(icon, color: color, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14)),
                    Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                  ],
                ),
              ),
              const Icon(Icons.arrow_forward_ios_rounded, size: 14, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }

  void _showSubstituteDialog() {
    final TextEditingController subSubjectC = TextEditingController(text: _originalSubject);
    final TextEditingController subFacultyC = TextEditingController(text: _originalFaculty);
    String? selectedSubSubject;

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Substitute Details", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Autocomplete<String>(
                optionsBuilder: (TextEditingValue textEditingValue) {
                  return _subjects.where((String option) {
                    return option.toLowerCase().contains(textEditingValue.text.toLowerCase());
                  });
                },
                onSelected: (String selection) {
                  selectedSubSubject = selection;
                },
                fieldViewBuilder: (context, controller, focusNode, onFieldSubmitted) {
                  controller.text = subSubjectC.text;
                  return TextField(
                    controller: controller,
                    focusNode: focusNode,
                    decoration: const InputDecoration(labelText: "Actual Subject"),
                  );
                },
              ),
              const SizedBox(height: 16),
              TextField(
                controller: subFacultyC,
                decoration: const InputDecoration(labelText: "Actual Faculty Name"),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _updateStatus("substitute", subSubject: subSubjectC.text, subFaculty: subFacultyC.text);
            },
            child: const Text("Done"),
          )
        ],
      ),
    );
  }
}
