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
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'dart:io';

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
      final periodIndex = _periods.indexOf(_selectedPeriod!) + 1;
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
      final periodIndex = _periods.indexOf(_selectedPeriod!) + 1;
      final actualSub = subSubject ?? _originalSubject;
      final actualFac = subFaculty ?? _originalFaculty;
      
      final payload = {
        "branch": _selectedBranch,
        "year": _selectedYear,
        "section": _selectedSection,
        "day": _currentDay,
        "periodIndex": _periods.indexOf(_selectedPeriod!) + 1,
        "statusDate": DateFormat('yyyy-MM-dd').format(DateTime.now()),
        "originalSubject": _originalSubject,
        "originalFaculty": _originalFaculty,
        "actualSubject": actualSub,
        "actualFaculty": actualFac,
        "status": status,
        "updatedBy": user['id'],
      };

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/incharge/update-status'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 200) {
        if (mounted) {
           _showConfirmationDialog(
              status: status,
              actualFaculty: actualFac,
           );
        }
      } else {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update status")));
        }
      }
    } catch (e) {
      debugPrint("Update Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _generateDailyReportPDF() async {
    if (_selectedBranch == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a branch first")));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final url = Uri.parse('${ApiConstants.baseUrl}/api/incharge/branch-daily-detail-report?branch=$_selectedBranch&date=$dateStr');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Group by Class (Year + Section)
        Map<String, List<dynamic>> grouped = {};
        for (var item in data) {
           String key = "${item['year']} - ${item['section']}";
           grouped.putIfAbsent(key, () => List.filled(8, null, growable: false));
           int idx = (item['periodIndex'] as int) - 1;
           if (idx >= 0 && idx < 8) {
              grouped[key]![idx] = item;
           }
        }

        final pdf = pw.Document();
        pdf.addPage(
          pw.MultiPage(
            pageFormat: PdfPageFormat.a4.landscape,
            margin: const pw.EdgeInsets.all(32),
            build: (pw.Context context) {
              return [
                pw.Header(
                  level: 0,
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                       pw.Text("ALWARDAS POLYTECHNIC", style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900)),
                       pw.Text("BRANCH: ${_selectedBranch!.toUpperCase()}", style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                       pw.SizedBox(height: 5),
                       pw.Row(
                         mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                         children: [
                           pw.Text("Daily Class Execution Report", style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
                           pw.Text("Date: $dateStr (${_currentDay})", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
                         ]
                       ),
                       pw.SizedBox(height: 20),
                    ]
                  )
                ),
                pw.Table(
                  border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
                  columnWidths: {
                    0: const pw.FixedColumnWidth(100),
                    for (int i=1; i<=8; i++) i: const pw.FlexColumnWidth(1),
                  },
                  children: [
                    pw.TableRow(
                      decoration: const pw.BoxDecoration(color: PdfColors.grey300),
                      children: [
                        pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("Year - Section", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10))),
                        ...List.generate(8, (i) => pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("P${i + 1}", style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10)))),
                      ],
                    ),
                    for (var entry in grouped.entries)
                      pw.TableRow(
                        children: [
                          pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text(entry.key, style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold))),
                          ...entry.value.map((p) {
                            if (p == null) return pw.Padding(padding: const pw.EdgeInsets.all(5), child: pw.Text("-", textAlign: pw.TextAlign.center, style: const pw.TextStyle(fontSize: 8)));
                            
                            // Determine Color & Status Text
                            PdfColor bgColor = PdfColors.white;
                            String statusText = "";
                            PdfColor textColor = PdfColors.black;

                            if (p['status'] == 'conducted') {
                               bgColor = PdfColor.fromHex("#E8F5E9"); // Very light green
                               statusText = "CONDUCTED";
                               textColor = PdfColors.green;
                            } else if (p['status'] == 'substitute') {
                               bgColor = PdfColor.fromHex("#FFF3E0"); // Very light orange
                               statusText = "SUBSTITUTE";
                               textColor = PdfColors.orange;
                            } else if (p['status'] == 'not_conducted') {
                               bgColor = PdfColor.fromHex("#FFEBEE"); // Very light red
                               statusText = "NOT CONDUCTED";
                               textColor = PdfColors.red;
                            } else {
                               statusText = "PENDING";
                               textColor = PdfColors.grey;
                            }

                            return pw.Container(
                              color: bgColor,
                              padding: const pw.EdgeInsets.all(4),
                              decoration: pw.BoxDecoration(
                                border: pw.Border.all(color: PdfColors.grey300, width: 0.2),
                              ),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Text(p['actualSubject'] ?? p['subject'], style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold)),
                                  pw.Text(p['actualFaculty'] ?? p['originalFaculty'], style: const pw.TextStyle(fontSize: 6.5)),
                                  pw.SizedBox(height: 2),
                                  pw.Text(statusText, style: pw.TextStyle(fontSize: 6, fontWeight: pw.FontWeight.bold, color: textColor)),
                                ],
                              ),
                            );
                          }).toList(),
                        ],
                      ),
                  ],
                ),
                pw.SizedBox(height: 30),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.end,
                  children: [
                    pw.Column(
                      children: [
                        pw.SizedBox(height: 40),
                        pw.Container(width: 150, decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide()))),
                        pw.Text("Incharge Signature", style: const pw.TextStyle(fontSize: 10)),
                      ]
                    )
                  ]
                )
              ];
            },
          ),
        );

        final dir = await getExternalStorageDirectory();
        final file = File("${dir!.path}/Daily_Report_${_selectedBranch}_$dateStr.pdf");
        await file.writeAsBytes(await pdf.save());
        await OpenFilex.open(file.path);
      }
    } catch (e) {
      debugPrint("PDF Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showConfirmationDialog({required String status, required String actualFaculty}) {
    String displayStatus = status.replaceAll('_', ' ').toUpperCase();
    Color statusColor = status == 'conducted' ? Colors.green : (status == 'substitute' ? Colors.orange : Colors.red);
    IconData statusIcon = status == 'conducted' ? Icons.check_circle : (status == 'substitute' ? Icons.swap_horiz : Icons.cancel);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(statusIcon, color: statusColor, size: 48),
            ),
            const SizedBox(height: 20),
            Text(
              "Status Updated Successfully!",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            const SizedBox(height: 24),
            _buildDialogDetailRow("Branch", _selectedBranch ?? "N/A"),
            _buildDialogDetailRow("Year", _selectedYear ?? "N/A"),
            _buildDialogDetailRow("Section", _selectedSection ?? "N/A"),
            _buildDialogDetailRow("Faculty Status", "$actualFaculty ($displayStatus)"),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: statusColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text("OK", style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.grey)),
          Expanded(child: Text(value, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
        ],
      ),
    );
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
          IconButton(
            icon: const Icon(Icons.picture_as_pdf_outlined),
            onPressed: _generateDailyReportPDF,
            tooltip: 'Download Daily Report',
          ),
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
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey),
              ),
              Text(
                value,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                ),
                softWrap: true,
              ),
            ],
          ),
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
