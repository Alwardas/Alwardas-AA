import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/api_constants.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../widgets/custom_modal_dropdown.dart';

class InchargeReportsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const InchargeReportsScreen({super.key, required this.userData});

  @override
  _InchargeReportsScreenState createState() => _InchargeReportsScreenState();
}

class _InchargeReportsScreenState extends State<InchargeReportsScreen> {
  String? _selectedBranch;
  DateTime _selectedDate = DateTime.now();
  bool _isLoading = false;
  List<String> _branches = [];
  Map<String, dynamic>? _summaryData;

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

  Future<void> _fetchBranches() async {
    try {
      final res = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/hod/departments'));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        setState(() {
          _branches = data.map((d) => d['branch_name'].toString()).toList();
          if (_branches.isNotEmpty) {
            _selectedBranch = _branches[0];
            _fetchDailySummary();
          }
        });
      }
    } catch (e) {
      debugPrint("Fetch Branches Error: $e");
    }
  }

  Future<void> _fetchDailySummary() async {
    if (_selectedBranch == null) return;
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final url = Uri.parse('${ApiConstants.baseUrl}/api/hod/daily-activity-report?branch=$_selectedBranch&date=$dateStr');
      final res = await http.get(url);
      if (res.statusCode == 200) {
        setState(() {
          _summaryData = json.decode(res.body);
        });
      }
    } catch (e) {
      debugPrint("Summary Fetch Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2024),
      lastDate: DateTime.now(),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: ColorScheme.light(
              primary: ThemeColors.primary,
              onPrimary: Colors.white,
              onSurface: Colors.black,
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
        _summaryData = null;
      });
      _fetchDailySummary();
    }
  }

  Future<void> _generatePDF() async {
    if (_selectedBranch == null) return;
    setState(() => _isLoading = true);
    try {
      final dateStr = DateFormat('yyyy-MM-dd').format(_selectedDate);
      final dayName = DateFormat('EEEE').format(_selectedDate);
      final url = Uri.parse('${ApiConstants.baseUrl}/api/incharge/branch-daily-detail-report?branch=$_selectedBranch&date=$dateStr');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        // Group by Class
        Map<String, List<dynamic>> grouped = {};
        for (var item in data) {
           String key = "${item['year']} - ${item['section']}";
           grouped.putIfAbsent(key, () => List.filled(8, null, growable: false));
           int idx = item['periodIndex'];
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
                           pw.Text("Date: $dateStr ($dayName)", style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
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
                            
                            PdfColor bgColor = PdfColors.white;
                            String statusText = "PENDING";
                            PdfColor textColor = PdfColors.grey;

                            if (p['status'] == 'conducted') {
                               bgColor = PdfColor.fromHex("#E8F5E9");
                               statusText = "CONDUCTED";
                               textColor = PdfColors.green;
                            } else if (p['status'] == 'substitute') {
                               bgColor = PdfColor.fromHex("#FFF3E0");
                               statusText = "SUBSTITUTE";
                               textColor = PdfColors.orange;
                            } else if (p['status'] == 'not_conducted') {
                               bgColor = PdfColor.fromHex("#FFEBEE");
                               statusText = "ABSENT";
                               textColor = PdfColors.red;
                            }

                            return pw.Container(
                              color: bgColor,
                              padding: const pw.EdgeInsets.all(4),
                              decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300, width: 0.2)),
                              child: pw.Column(
                                crossAxisAlignment: pw.CrossAxisAlignment.start,
                                mainAxisAlignment: pw.MainAxisAlignment.center,
                                children: [
                                  pw.Text(p['actualSubject'] ?? p['subject'], style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold), maxLines: 1, overflow: pw.TextOverflow.clip),
                                  pw.Text(p['actualFaculty'] ?? p['originalFaculty'], style: const pw.TextStyle(fontSize: 6.5), maxLines: 1, overflow: pw.TextOverflow.clip),
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
                        pw.Container(width: 150, border: const pw.Border(top: pw.BorderSide())),
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
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
      appBar: AppBar(
        title: Text("Branch Reports", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildFilterSection(cardColor, textColor, isDark),
              const SizedBox(height: 24),
              if (_summaryData != null) _buildSummarySection(cardColor, textColor, isDark),
              const SizedBox(height: 32),
              _buildActionButtons(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterSection(Color cardColor, Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(isDark ? 0.3 : 0.05), blurRadius: 20, offset: const Offset(0, 10)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Report Filters", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 20),
          
          // Branch Dropdown
          Text("Select Branch", style: GoogleFonts.poppins(fontSize: 12, color: textColor.withOpacity(0.6))),
          const SizedBox(height: 8),
          CustomModalDropdown(
            hint: "Select Branch",
            value: _selectedBranch,
            items: _branches,
            onChanged: (val) {
              setState(() {
                _selectedBranch = val;
                _summaryData = null;
              });
              _fetchDailySummary();
            },
          ),
          
          const SizedBox(height: 20),
          
          // Date Selection
          Text("Select Date", style: GoogleFonts.poppins(fontSize: 12, color: textColor.withOpacity(0.6))),
          const SizedBox(height: 8),
          InkWell(
            onTap: () => _selectDate(context),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: isDark ? Colors.white12 : Colors.grey[300]!),
              ),
              child: Row(
                children: [
                  Icon(Icons.calendar_today_rounded, size: 18, color: ThemeColors.primary),
                  const SizedBox(width: 12),
                  Text(
                    DateFormat('dd MMMM, yyyy').format(_selectedDate),
                    style: GoogleFonts.poppins(color: textColor, fontSize: 14),
                  ),
                  const Spacer(),
                  Icon(Icons.arrow_drop_down, color: textColor.withOpacity(0.5)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummarySection(Color cardColor, Color textColor, bool isDark) {
    final conducted = _summaryData?['conducted'] ?? 0;
    final substitute = _summaryData?['substitute'] ?? 0;
    final notConducted = _summaryData?['not_conducted'] ?? 0;
    final total = _summaryData?['total_classes'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Daily Summary", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(child: _buildStatCard("Total", total.toString(), Colors.blue, cardColor, textColor, isDark)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard("Conducted", conducted.toString(), Colors.green, cardColor, textColor, isDark)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: _buildStatCard("Substitutes", substitute.toString(), Colors.orange, cardColor, textColor, isDark)),
            const SizedBox(width: 12),
            Expanded(child: _buildStatCard("Absent", notConducted.toString(), Colors.red, cardColor, textColor, isDark)),
          ],
        ),
      ],
    );
  }

  Widget _buildStatCard(String title, String value, Color color, Color cardColor, Color textColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 12, color: textColor.withOpacity(0.6))),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: color)),
        ],
      ),
    );
  }

  Widget _buildActionButtons() {
    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton.icon(
            onPressed: _isLoading ? null : _generatePDF,
            icon: _isLoading 
                ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.picture_as_pdf_outlined),
            label: Text(_isLoading ? "Generating..." : "Download Daily Detailed PDF", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
            style: ElevatedButton.styleFrom(
              backgroundColor: ThemeColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              elevation: 0,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Text(
          "This report includes year-wise and section-wise period status tracking for the selected branch and date.",
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
        ),
      ],
    );
  }
}
