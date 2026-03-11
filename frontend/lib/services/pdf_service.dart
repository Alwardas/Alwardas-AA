import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart'; 
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';

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
}
