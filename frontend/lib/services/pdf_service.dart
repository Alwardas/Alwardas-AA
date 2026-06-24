import 'package:flutter/foundation.dart';
import 'dart:io';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart'; 
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

import '../core/api_constants.dart';
import '../data/courses_data.dart';
import '../core/models/curriculum_merged.dart';

class PdfService {


  static Future<void> generateMultiMonthSummaryReport({
    required String branch,
    required String year,
    required String section,
    required DateTime startDate,
    required DateTime endDate,
    required List<Map<String, dynamic>> monthReports, // {month: Str, workingDays: int, data: Map}
    required List<Map<String, String>> students,
  }) async {
    final pdf = pw.Document();

    // Fonts
    ByteData? fontRegular;
    try {
      fontRegular = await rootBundle.load("assets/fonts/Poppins-Regular.ttf");
    } catch (_) {
      try {
        fontRegular = await rootBundle.load("assets/fonts/Inter-Regular.ttf");
      } catch (_) {
        fontRegular = null;
      }
    }

    ByteData? fontBold;
    try {
      fontBold = await rootBundle.load("assets/fonts/Poppins-Bold.ttf");
    } catch (_) {
      try {
        fontBold = await rootBundle.load("assets/fonts/Inter-Bold.ttf");
      } catch (_) {
        fontBold = null;
      }
    }

    final ttfRegular = fontRegular != null ? pw.Font.ttf(fontRegular) : pw.Font.courier();
    final ttfBold = fontBold != null ? pw.Font.ttf(fontBold) : pw.Font.courierBold();

    final now = DateTime.now();
    final formattedDate = DateFormat('dd/MM/yyyy hh:mm a').format(now);

    final parsedMonths = monthReports.map((r) {
       final mStr = r['month'].toString();
       final mName = mStr.split(' ')[0].substring(0, 3).toUpperCase();
       final wDays = r['workingDays'] as int;
       return "$mName($wDays)";
    }).toList();

    int totalOverallWorkingDays = monthReports.fold(0, (sum, r) => sum + (r['workingDays'] as int));
    
    // Generate Report ID
    final String reportId = "ATT-${now.year}-${now.millisecondsSinceEpoch.toString().substring(8)}";

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4, // Changed from landscape to portrait
        margin: const pw.EdgeInsets.all(30),
        footer: (context) => _buildBottomFooter(reportId, context.pageNumber, 1, ttfRegular),
        build: (context) => [
          _buildReportHeader(branch, year, section, startDate, endDate, reportId, ttfBold, ttfRegular),
          pw.SizedBox(height: 10),
          _buildMultiMonthSummaryTable(students, monthReports, parsedMonths, totalOverallWorkingDays, ttfBold, ttfRegular),
          pw.SizedBox(height: 30),
          _buildSignatureBlock(ttfBold, ttfRegular, formattedDate),
        ]
      )
    );

    await _saveAndLaunchPdf(pdf, "Summary_Report_${branch}_$section.pdf");
  }



  static pw.Widget _buildReportHeader(String branch, String year, String section, DateTime startDate, DateTime endDate, String reportId, pw.Font fontBold, pw.Font fontRegular) {
    String fromToStr = "${DateFormat('dd/MM/yyyy').format(startDate)}  \u2192  ${DateFormat('dd/MM/yyyy').format(endDate)}";
    
    return pw.Column(
      children: [
        // Grey Header Bar
        pw.Container(
          width: double.infinity,
          height: 25,
          color: PdfColors.grey300,
          alignment: pw.Alignment.center,
          child: pw.Text("ATTENDANCE MANAGEMENT REPORT", style: pw.TextStyle(font: fontBold, fontSize: 12, fontWeight: pw.FontWeight.bold))
        ),
        pw.SizedBox(height: 5),
        
        // Info Box
        pw.Container(
           decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.5)),
           padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 8),
           child: pw.Row(
             crossAxisAlignment: pw.CrossAxisAlignment.start,
             children: [
               // Left Column
               pw.Expanded(
                 flex: 3,
                 child: pw.Column(
                   crossAxisAlignment: pw.CrossAxisAlignment.start,
                   children: [
                      _buildInfoRow("College Name:", "ALWARDAS POLYTECHNIC", fontBold, fontRegular),
                      pw.SizedBox(height: 4),
                      _buildInfoRow("Branch:", branch, fontBold, fontRegular),
                      pw.SizedBox(height: 4),
                      _buildInfoRow("Year:", year, fontBold, fontRegular),
                      pw.SizedBox(height: 4),
                      _buildInfoRow("Section:", section, fontBold, fontRegular),
                   ]
                 )
               ),
               // Right Column
               pw.Expanded(
                 flex: 2,
                 child: pw.Column(
                   crossAxisAlignment: pw.CrossAxisAlignment.start,
                   children: [
                      _buildInfoRow("Report ID:", reportId, fontBold, fontRegular),
                      pw.SizedBox(height: 4),
                      _buildInfoRow("From - To:", fromToStr, fontBold, fontRegular),
                   ]
                 )
               )
             ]
           )
        ),
        pw.SizedBox(height: 8),
      ]
    );
  }

  static pw.Widget _buildInfoRow(String label, String value, pw.Font fb, pw.Font fr) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.SizedBox(width: 80, child: pw.Text(label, style: pw.TextStyle(font: fb, fontSize: 9))),
        pw.Expanded(child: pw.Text(value, style: pw.TextStyle(font: fr, fontSize: 9)))
      ]
    );
  }


  static String _normalizeStatus(String? s) {
     if (s == null) return '';
     final up = s.toUpperCase();
     if (up.contains('ABSENT') || up == 'A') return 'A';
     if (up.contains('PRESENT') || up == 'P') return 'P';
     if (up.contains('HOLIDAY') || up == 'H') return 'H';
     return ''; 
  }



  static pw.Widget _summaryHeaderCell(String text, pw.Font font) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(4),
      alignment: pw.Alignment.center,
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)
    );
  }

   static pw.Widget _buildMultiMonthSummaryTable(List<Map<String, String>> students, List<Map<String, dynamic>> monthReports, List<String> monthLabels, int totalWorkingDays, pw.Font fb, pw.Font fr) {
      double totalDaysDouble = totalWorkingDays.toDouble();

      return pw.Table(
        border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
        columnWidths: {
          0: const pw.FixedColumnWidth(60), // ID (made smaller for portrait)
          1: const pw.FlexColumnWidth(2),   // Name
          for (int i=0; i<monthLabels.length; i++)
             (i+2): const pw.FlexColumnWidth(1),
          // Total and Percentage
          (monthLabels.length + 2): const pw.FixedColumnWidth(50),
          (monthLabels.length + 3): const pw.FixedColumnWidth(40),
        },
        children: [
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.grey200),
            children: [
               _summaryHeaderCell("Student ID", fb),
               _summaryHeaderCell("Student Name", fb),
               for (String m in monthLabels)
                 _summaryHeaderCell(m, fb),
               _summaryHeaderCell("Total($totalWorkingDays)", fb),
               _summaryHeaderCell("%", fb),
            ]
          ),
          for (var s in students)
            _buildMultiMonthRow(s, monthReports, monthLabels, totalDaysDouble, fb, fr)
        ]
      );
   }

   static pw.TableRow _buildMultiMonthRow(Map<String, String> student, List<Map<String, dynamic>> monthReports, List<String> monthLabels, double totalWorkingDays, pw.Font fb, pw.Font fr) {
      double overallPresent = 0;
      List<pw.Widget> monthCells = [];

      for (var report in monthReports) {
         Map<String, Map<String, Map<String, String>>> data = report['data'];
         double mPresentDays = 0;

         data.forEach((day, studentsData) {
             bool hasAM = false;
             bool hasPM = false;
             
             // Check class-wide if AM or PM sessions happened and weren't holidays
             for (var sData in studentsData.values) {
                 final am = _normalizeStatus(sData['AM']);
                 final pm = _normalizeStatus(sData['PM']);
                 if (am == 'P' || am == 'A') hasAM = true;
                 if (pm == 'P' || pm == 'A') hasPM = true;
             }

             if (hasAM || hasPM) {
                 bool isSingleSession = (hasAM && !hasPM) || (!hasAM && hasPM);
                 
                 if (studentsData.containsKey(student['id'])) {
                     final sStatus = studentsData[student['id']]!;
                     bool pAM = _normalizeStatus(sStatus['AM']) == 'P';
                     bool pPM = _normalizeStatus(sStatus['PM']) == 'P';
                     
                     if (hasAM && pAM) {
                         mPresentDays += isSingleSession ? 1.0 : 0.5;
                     }
                     if (hasPM && pPM) {
                         mPresentDays += isSingleSession ? 1.0 : 0.5;
                     }
                 }
             }
         });
         
         overallPresent += mPresentDays;
         
         String disp = mPresentDays % 1 == 0 ? mPresentDays.toInt().toString() : mPresentDays.toStringAsFixed(1);
         monthCells.add(_centeredCell(disp, fr));
      }

      double percentage = totalWorkingDays > 0 ? (overallPresent / totalWorkingDays) * 100 : 0.0;
      String dispTotal = overallPresent % 1 == 0 ? overallPresent.toInt().toString() : overallPresent.toStringAsFixed(1);
      
      // format percentage cleanly
      String dispPerc = percentage % 1 == 0 ? percentage.toInt().toString() : percentage.toStringAsFixed(2);

      return pw.TableRow(
         children: [
            _centeredCell(student['id'] ?? '', fr),
            pw.Padding(padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 4), child: pw.Text(student['name']?.toUpperCase() ?? '', style: pw.TextStyle(font: fb, fontSize: 8))),
            ...monthCells,
            _centeredCell(dispTotal, fr),
            _centeredCell("$dispPerc%", fb),
         ]
      );
   }

  static pw.Widget _centeredCell(String text, pw.Font font) {
     return pw.Container(
       padding: const pw.EdgeInsets.symmetric(vertical: 4, horizontal: 1),
       alignment: pw.Alignment.center,
       child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 8))
     );
  }

  static pw.Widget _buildSignatureBlock(pw.Font fb, pw.Font fr, String date) {
     return pw.Column(
       children: [
         pw.Divider(thickness: 1, color: PdfColors.black),
         pw.SizedBox(height: 30),
         pw.Row(
           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
           children: [
              _signatureLine("Class In-Charge Name:", fb),
              _signatureLine("Signature:", fb),
           ]
         ),
         pw.SizedBox(height: 30),
         pw.Row(
           mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
           children: [
              _signatureLine("HOD Name:", fb),
              pw.Row(children: [pw.Text("Date: ", style: pw.TextStyle(font: fb)), pw.Container(width: 120, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())), child: pw.Text(""))])
           ]
         ),
       ]
     );
  }

  static pw.Widget _buildBottomFooter(String reportId, int pageNum, int totalPages, pw.Font font) {
     return pw.Container(
       width: double.infinity,
       margin: const pw.EdgeInsets.only(top: 10),
       child: pw.Column(
         children: [
            pw.Divider(thickness: 0.5, color: PdfColors.grey),
            pw.SizedBox(height: 5),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text("Report ID: $reportId", style: pw.TextStyle(font: font, fontSize: 8)),
                pw.Text("Page $pageNum of $totalPages", style: pw.TextStyle(font: font, fontSize: 8)),
              ]
            )
         ]
       )
     );
  }

  static pw.Widget _signatureLine(String label, pw.Font font) {
     return pw.Row(
       children: [
          pw.Text(label, style: pw.TextStyle(font: font, fontSize: 10, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(width: 10),
          pw.Container(width: 200, decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide())), child: pw.Text(""))
       ]
     );
  }
  


  static Future<void> _saveAndLaunchPdf(pw.Document pdf, String fileName) async {
    try {
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
           status = await Permission.storage.request();
           if (!status.isGranted && await Permission.manageExternalStorage.status.isDenied) {
                 await Permission.manageExternalStorage.request();
           }
        }
      }
      final dir = await getExternalStorageDirectory(); 
      String path = "${dir?.path ?? ''}/$fileName";
      final output = File(path);
      await output.writeAsBytes(await pdf.save());
      await OpenFilex.open(path);
    } catch (e) {
      debugPrint("Error saving PDF: $e");
    }
  }

  static Future<void> generateLessonPlanPdf({
    required BuildContext context,
    required String subjectId,
    required String subjectName,
    required String status,
    required int percentage,
    required String facultyName,
    required String academicYear,
    required String branch,
    required String section,
  }) async {
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/faculty/hod-lesson-topics?subject_id=${Uri.encodeComponent(subjectId)}&section=${Uri.encodeComponent(section)}&branch=${Uri.encodeComponent(branch)}');
      
      Map<String, dynamic> apiTopicsMap = {};
      try {
        final response = await http.get(url);
        if (response.statusCode == 200) {
          final Map<String, dynamic> decoded = json.decode(response.body);
          if (decoded['success'] == true && decoded['data'] is List) {
            for (var t in decoded['data']) {
              if (t['id'] != null) {
                apiTopicsMap[t['id'].toString().toLowerCase()] = t;
              }
            }
          }
        }
      } catch (e) {
        debugPrint("Error fetching API topics for PDF: $e");
      }

      final subjectDetails = await CoursesData.getSubjectDetails(subjectId);
      List<dynamic> localTopics = [];

      if (subjectDetails != null && subjectDetails['units'] != null) {
        for (var unit in subjectDetails['units']) {
          localTopics.add({
            'type': 'unit',
            'topicName': 'Unit ${unit['unitNo']}: ${unit['title']}',
            'unitNo': unit['unitNo'],
          });

          if (unit['topics'] != null) {
            for (var t in unit['topics']) {
              final apiData = apiTopicsMap[t['id'].toString().toLowerCase()];
              localTopics.add({
                'id': t['id'],
                'type': t['type'] ?? 'topic',
                'topicName': t['topic'],
                'unitNo': unit['unitNo'],
                'scheduleDate': apiData?['scheduleDate'],
                'completed': apiData?['completed'] ?? false,
                'completedDate': apiData?['completedDate'],
              });
            }
          }
        }
      }

      if (localTopics.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No syllabus data available to generate PDF.")));
        }
        return;
      }

      // Standard Arial equivalent Helvetica fonts
      final ttfRegular = pw.Font.helvetica();
      final ttfBold = pw.Font.helveticaBold();

      // Load logo image
      pw.MemoryImage? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/images/college logo.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (e) {
        debugPrint("Error loading college logo for PDF: $e");
      }

      final pdf = pw.Document();

      Map<int, List<dynamic>> unitsMap = {};
      for (var t in localTopics) {
        final int uNo = t['unitNo'] ?? 1;
        unitsMap.putIfAbsent(uNo, () => []);
        unitsMap[uNo]!.add(t);
      }

      for (var unitNo in unitsMap.keys.toList()..sort()) {
        final items = unitsMap[unitNo]!;
        final unitHeader = items.firstWhere((e) => e['type'] == 'unit', orElse: () => null);
        final unitTitle = unitHeader != null ? unitHeader['topicName'] : 'UNIT $unitNo';
        
        int sNo = 1;
        final totalPeriods = items.where((e) => e['type'] != 'unit').length;

        pdf.addPage(
          pw.MultiPage(
            pageTheme: pw.PageTheme(
              pageFormat: PdfPageFormat.a4,
              margin: const pw.EdgeInsets.all(32),
              buildBackground: logoImage == null ? null : (pw.Context pdfContext) {
                return pw.Center(
                  child: pw.Opacity(
                    opacity: 0.30, // Opacity is 30%
                    child: pw.Image(
                      logoImage!,
                      width: 320,
                      height: 320,
                      fit: pw.BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
            header: (pw.Context pdfContext) {
              if (pdfContext.pageNumber != 1) return pw.SizedBox();
              return pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'NAME OF THE FACULTY: ${facultyName.toUpperCase()}',
                    style: pw.TextStyle(font: ttfBold, fontSize: 12),
                  ),
                  pw.SizedBox(height: 8),
                  pw.Text(
                    'Lesson Plan: $subjectName ($subjectId) — Academic Year: $academicYear',
                    style: pw.TextStyle(font: ttfBold, fontSize: 12),
                  ),
                  pw.SizedBox(height: 16),
                ],
              );
            },
            footer: (pw.Context pdfContext) {
              return pw.Container(
                alignment: pw.Alignment.center,
                margin: const pw.EdgeInsets.only(top: 20),
                child: pw.Text(
                  'SUBJECT: $subjectId ($subjectName)',
                  style: pw.TextStyle(
                    font: ttfBold,
                    fontSize: 10,
                  ),
                ),
              );
            },
            build: (pw.Context pdfContext) {
              return [
                pw.Container(
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.5)),
                  child: pw.Column(
                    children: [
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(6),
                        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                        child: pw.Text(
                          '$unitTitle ($totalPeriods Periods)',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(font: ttfBold, fontSize: 12),
                        ),
                      ),
                      pw.Table(
                        border: pw.TableBorder.symmetric(inside: const pw.BorderSide(color: PdfColors.black, width: 0.5)),
                        columnWidths: {
                          0: const pw.FixedColumnWidth(30),
                          1: const pw.FixedColumnWidth(70),
                          2: const pw.FlexColumnWidth(),
                          3: const pw.FixedColumnWidth(40),
                          4: const pw.FixedColumnWidth(70),
                        },
                        children: [
                          pw.TableRow(
                            children: [
                              _lpCell('S.No', true, true, ttfBold, ttfRegular),
                              _lpCell('Date', true, true, ttfBold, ttfRegular),
                              _lpCell('Name of the topic to be covered', true, true, ttfBold, ttfRegular),
                              _lpCell('No. Of\nPeriods', true, true, ttfBold, ttfRegular),
                              _lpCell('completed\nDate', true, true, ttfBold, ttfRegular),
                            ],
                          ),
                          ...items.where((e) => e['type'] != 'unit').map((t) {
                            String dateStr = '';
                            if (t['scheduleDate'] != null) {
                              try { dateStr = DateFormat('dd-MM-yyyy').format(DateTime.parse(t['scheduleDate']).toLocal()); } catch (_) {}
                            }
                            String completedDateStr = '';
                            if (t['completed'] == true && t['completedDate'] != null) {
                              try { completedDateStr = DateFormat('dd-MM-yyyy').format(DateTime.parse(t['completedDate']).toLocal()); } catch (_) {}
                            }
                            return pw.TableRow(
                              children: [
                                _lpCell('${sNo++}', false, true, ttfBold, ttfRegular),
                                _lpCell(dateStr, false, true, ttfBold, ttfRegular),
                                _lpCell(_buildTopicText(t['topicName'] ?? '', ttfBold, ttfRegular), false, false, ttfBold, ttfRegular),
                                _lpCell('1', false, true, ttfBold, ttfRegular),
                                _lpCell(completedDateStr, false, true, ttfBold, ttfRegular),
                              ],
                            );
                          }),
                        ],
                      ),
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(6),
                        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                        child: pw.Row(
                           children: [
                             pw.Expanded(flex: 9, child: pw.Text('(UNIT $unitNo END)', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: ttfBold, fontSize: 10))),
                             pw.Expanded(flex: 3, child: pw.Text('Total\n$totalPeriods Periods', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: ttfBold, fontSize: 10))),
                           ]
                        )
                      )
                    ],
                  ),
                ),
                pw.SizedBox(height: 20),
              ];
            },
          ),
        );
      }

      await _saveAndLaunchPdf(pdf, "LessonPlan_${subjectId}_$section.pdf");

    } catch (e) {
      debugPrint("PDF Generation error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to generate PDF.")));
      }
    }
  }

  static pw.Widget _buildTopicText(String text, pw.Font fb, pw.Font fr) {
    final int colonIndex = text.indexOf(':');
    if (colonIndex != -1) {
      final prefix = text.substring(0, colonIndex + 1);
      final suffix = text.substring(colonIndex + 1);
      return pw.RichText(
        text: pw.TextSpan(
          children: [
            pw.TextSpan(text: prefix, style: pw.TextStyle(font: fb, fontSize: 10, fontWeight: pw.FontWeight.bold)),
            pw.TextSpan(text: suffix, style: pw.TextStyle(font: fr, fontSize: 10)),
          ],
        ),
      );
    }
    return pw.Text(text, style: pw.TextStyle(font: fr, fontSize: 10));
  }

  static pw.Widget _lpCell(dynamic content, bool isHeader, bool isCenter, pw.Font fb, pw.Font fr) {
    return pw.Container(
      padding: const pw.EdgeInsets.all(6),
      alignment: isCenter ? pw.Alignment.center : pw.Alignment.centerLeft,
      child: content is pw.Widget 
          ? content 
          : pw.Text(
              content.toString(),
              style: pw.TextStyle(
                font: isHeader ? fb : fr,
                fontSize: 10,
              ),
            ),
    );
  }

  static Future<void> generateLessonPlanPdfFromData({
    required BuildContext context,
    required String subjectId,
    required String subjectName,
    required String facultyName,
    required String branch,
    required String section,
    required String year,
    required int semester,
    required CurriculumMerged curriculum,
  }) async {
    try {
      final ttfRegular = pw.Font.helvetica();
      final ttfBold = pw.Font.helveticaBold();

      // Calculate completion percentage and scheduled status
      int totalTopics = 0;
      int completedTopics = 0;
      int scheduledTopics = 0;
      bool hasSchedule = false;
      final now = DateTime.now();
      for (var unit in curriculum.units) {
        for (var topic in unit.topics) {
          totalTopics += 1;
          if (topic.status == 'completed') {
            completedTopics += 1;
          }
          if (topic.assignedDate != null) {
            hasSchedule = true;
            if (topic.assignedDate!.isBefore(now)) {
              scheduledTopics += 1;
            }
          }
        }
      }
      final percentage = totalTopics > 0 ? (completedTopics * 100 ~/ totalTopics) : 0;

      String statusText = "On Track";
      if (hasSchedule) {
        if (completedTopics < scheduledTopics) {
          statusText = "Lagging";
        } else if (completedTopics > scheduledTopics) {
          statusText = "Overfast";
        }
      }

      // Load logo image
      pw.MemoryImage? logoImage;
      try {
        final logoBytes = await rootBundle.load('assets/images/college logo.png');
        logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
      } catch (e) {
        debugPrint("Error loading college logo for PDF: $e");
      }

      final pdf = pw.Document();

      pdf.addPage(
        pw.MultiPage(
          pageTheme: pw.PageTheme(
            pageFormat: PdfPageFormat.a4,
            margin: const pw.EdgeInsets.all(32),
            buildBackground: logoImage == null ? null : (pw.Context pdfContext) {
              return pw.Center(
                child: pw.Opacity(
                  opacity: 0.15,
                  child: pw.Image(
                    logoImage!,
                    width: 320,
                    height: 320,
                    fit: pw.BoxFit.contain,
                  ),
                ),
              );
            },
          ),
          header: (pw.Context pdfContext) {
            if (pdfContext.pageNumber != 1) return pw.SizedBox();
            return pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                pw.Expanded(
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      pw.Text(
                        'NAME OF THE FACULTY: ${facultyName.toUpperCase()}',
                        style: pw.TextStyle(font: ttfBold, fontSize: 12),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Lesson Plan: $subjectName ($subjectId) — Academic Year: $year',
                        style: pw.TextStyle(font: ttfBold, fontSize: 12),
                      ),
                      pw.SizedBox(height: 8),
                      pw.Text(
                        'Branch: $branch | Section: $section | Semester: $semester',
                        style: pw.TextStyle(font: ttfBold, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                pw.SizedBox(width: 20),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: pw.BoxDecoration(
                    border: pw.Border.all(color: PdfColors.grey400, width: 1),
                    borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
                  ),
                  child: pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'Progress: $percentage%',
                        style: pw.TextStyle(font: ttfBold, fontSize: 11, color: PdfColors.green700),
                      ),
                      pw.SizedBox(height: 4),
                      pw.Text(
                        'Status: ${statusText.toUpperCase()}',
                        style: pw.TextStyle(
                          font: ttfBold,
                          fontSize: 10,
                          color: statusText == 'Lagging'
                              ? PdfColors.red700
                              : (statusText == 'Overfast' ? PdfColors.orange700 : PdfColors.green700),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
          footer: (pw.Context pdfContext) {
            return pw.Container(
              alignment: pw.Alignment.center,
              margin: const pw.EdgeInsets.only(top: 20),
              child: pw.Text(
                'SUBJECT: $subjectId ($subjectName) — Page ${pdfContext.pageNumber}',
                style: pw.TextStyle(
                  font: ttfBold,
                  fontSize: 10,
                ),
              ),
            );
          },
          build: (pw.Context pdfContext) {
            List<pw.Widget> widgets = [];
            for (int i = 0; i < curriculum.units.length; i++) {
              final unit = curriculum.units[i];
              final unitTitle = "Unit ${unit.unitNo}: ${unit.title}";
              final totalPeriods = unit.topics.length;
              
              widgets.add(
                pw.Container(
                  margin: const pw.EdgeInsets.only(bottom: 20),
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.black, width: 0.5)),
                  child: pw.Column(
                    children: [
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(6),
                        decoration: const pw.BoxDecoration(
                          color: PdfColors.grey200,
                          border: pw.Border(bottom: pw.BorderSide(color: PdfColors.black, width: 0.5)),
                        ),
                        child: pw.Text(
                          '$unitTitle ($totalPeriods Periods)',
                          textAlign: pw.TextAlign.center,
                          style: pw.TextStyle(font: ttfBold, fontSize: 11),
                        ),
                      ),
                      pw.Table(
                        border: pw.TableBorder.symmetric(inside: const pw.BorderSide(color: PdfColors.black, width: 0.5)),
                        columnWidths: {
                          0: const pw.FixedColumnWidth(40),
                          1: const pw.FixedColumnWidth(80),
                          2: const pw.FlexColumnWidth(),
                          3: const pw.FixedColumnWidth(50),
                          4: const pw.FixedColumnWidth(80),
                        },
                        children: [
                          pw.TableRow(
                            decoration: const pw.BoxDecoration(color: PdfColors.grey100),
                            children: [
                              _lpCell('S.No', true, true, ttfBold, ttfRegular),
                              _lpCell('Assigned Date', true, true, ttfBold, ttfRegular),
                              _lpCell('Name of the topic to be covered', true, true, ttfBold, ttfRegular),
                              _lpCell('No. Of\nPeriods', true, true, ttfBold, ttfRegular),
                              _lpCell('Completed Date', true, true, ttfBold, ttfRegular),
                            ],
                          ),
                          ...unit.topics.map((t) {
                            final assignedDateStr = t.assignedDate != null 
                                ? DateFormat('dd-MM-yyyy').format(t.assignedDate!.toLocal()) 
                                : "";
                            final completedDateStr = t.status == 'completed' && t.completedDate != null 
                                ? DateFormat('dd-MM-yyyy').format(t.completedDate!.toLocal()) 
                                : "";
                            return pw.TableRow(
                              children: [
                                _lpCell(t.sno, false, true, ttfBold, ttfRegular),
                                _lpCell(assignedDateStr, false, true, ttfBold, ttfRegular),
                                _lpCell(_buildTopicText(t.topic, ttfBold, ttfRegular), false, false, ttfBold, ttfRegular),
                                _lpCell(t.period.toString(), false, true, ttfBold, ttfRegular),
                                _lpCell(completedDateStr, false, true, ttfBold, ttfRegular),
                              ],
                            );
                          }),
                        ],
                      ),
                      pw.Container(
                        width: double.infinity,
                        padding: const pw.EdgeInsets.all(6),
                        decoration: const pw.BoxDecoration(border: pw.Border(top: pw.BorderSide(color: PdfColors.black, width: 0.5))),
                        child: pw.Row(
                           children: [
                             pw.Expanded(flex: 9, child: pw.Text('(UNIT ${unit.unitNo} END)', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: ttfBold, fontSize: 9))),
                             pw.Expanded(flex: 3, child: pw.Text('Total: $totalPeriods Periods', textAlign: pw.TextAlign.center, style: pw.TextStyle(font: ttfBold, fontSize: 9))),
                           ]
                        )
                      )
                    ],
                  ),
                ),
              );

              if (i < curriculum.units.length - 1) {
                widgets.add(pw.NewPage());
              }
            }
            return widgets;
          },
        ),
      );

      final sanitizedSubject = subjectName.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final sanitizedSection = section.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      await _saveAndLaunchPdf(pdf, "LessonPlan_${sanitizedSubject}_$sanitizedSection.pdf");

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Lesson Plan PDF exported successfully.")),
        );
      }
    } catch (e) {
      debugPrint("PDF Generation error: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to generate PDF.")),
        );
      }
    }
  }

  static Future<void> generateLessonPlanExcelFromData({
    required BuildContext context,
    required String subjectId,
    required String subjectName,
    required String facultyName,
    required String branch,
    required String section,
    required String year,
    required int semester,
    required CurriculumMerged curriculum,
  }) async {
    try {
      StringBuffer csvBuffer = StringBuffer();
      
      // Header metadata
      csvBuffer.writeln("Faculty Name,$facultyName");
      csvBuffer.writeln("Subject,$subjectName ($subjectId)");
      csvBuffer.writeln("Branch,$branch");
      csvBuffer.writeln("Section,$section");
      csvBuffer.writeln("Academic Year,$year");
      csvBuffer.writeln("Semester,$semester");
      csvBuffer.writeln(""); // Blank line
      
      // Table Header
      csvBuffer.writeln("S.No,Unit,Topic Description,Periods,Assigned Date,Completed Date,Status");
      
      for (var unit in curriculum.units) {
        final unitLabel = "Unit ${unit.unitNo}: ${unit.title}";
        for (var t in unit.topics) {
          final cleanTopic = t.topic.replaceAll('"', '""');
          final assignedDateStr = t.assignedDate != null 
              ? DateFormat('dd-MM-yyyy').format(t.assignedDate!.toLocal()) 
              : "";
          final completedDateStr = t.status == 'completed' && t.completedDate != null 
              ? DateFormat('dd-MM-yyyy').format(t.completedDate!.toLocal()) 
              : "";
              
          csvBuffer.writeln('"${t.sno}","$unitLabel","$cleanTopic","${t.period}","$assignedDateStr","$completedDateStr","${t.status.toUpperCase()}"');
        }
      }
      
      final bytes = utf8.encode(csvBuffer.toString());
      final sanitizedSubject = subjectName.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final sanitizedSection = section.replaceAll(RegExp(r'[^\w\s\-]'), '_');
      final fileName = "LessonPlan_${sanitizedSubject}_$sanitizedSection.csv";
      
      if (Platform.isAndroid) {
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          await Permission.storage.request();
        }
      }
      final dir = await getExternalStorageDirectory();
      final file = File("${dir?.path}/$fileName");
      await file.writeAsBytes(bytes);
      await OpenFilex.open(file.path);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Lesson Plan Excel exported to ${file.path}")),
        );
      }
    } catch (e) {
      debugPrint("Error exporting Excel: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to download Excel.")),
        );
      }
    }
  }
}
