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
  static Future<void> generateAttendanceReport({
    required String branch,
    required String year,
    required String section,
    required String month, 
    required Map<String, Map<String, Map<String, String>>> attendanceData, 
    required List<Map<String, String>> students, 
  }) async {
    final pdf = pw.Document();

    // Load Fonts
    // Load Fonts safely
    ByteData? fontRegular;
    try {
      fontRegular = await rootBundle.load("assets/fonts/Poppins-Regular.ttf");
    } catch (_) {
      try {
        fontRegular = await rootBundle.load("assets/fonts/Inter-Regular.ttf");
      } catch (_) {}
    }

    ByteData? fontBold;
    try {
      fontBold = await rootBundle.load("assets/fonts/Poppins-Bold.ttf");
    } catch (_) {
      try {
        fontBold = await rootBundle.load("assets/fonts/Inter-Bold.ttf");
      } catch (_) {}
    }
    
    final ttfRegular = fontRegular != null ? pw.Font.ttf(fontRegular) : pw.Font.courier();
    final ttfBold = fontBold != null ? pw.Font.ttf(fontBold) : pw.Font.courierBold();

    final daysInMonth = _getDaysInMonth(month);
    
    // Layout Config
    const int daysPerPage = 8;
    int totalPages = (daysInMonth / daysPerPage).ceil();

    final now = DateTime.now();
    final formattedDate = DateFormat('dd-MMM-yyyy hh:mm a').format(now);
    final reportId = "ATT-${month.split(' ').first.substring(0,3).toUpperCase()}-${month.split(' ').last}-${branch.substring(0,2).toUpperCase()}-${section.split(' ').last}";

    // --- Detailed Pages ---
    final int docTotalPages = totalPages + 1;

    for (int pageIdx = 0; pageIdx < totalPages; pageIdx++) {
      final startDay = (pageIdx * daysPerPage) + 1;
      final endDay = (startDay + daysPerPage - 1) > daysInMonth ? daysInMonth : (startDay + daysPerPage - 1);
      final currentDays = <int>[];
      for (int i = startDay; i <= endDay; i++) {
        currentDays.add(i);
      }

      pdf.addPage(
        pw.MultiPage(
          pageFormat: PdfPageFormat.a4.landscape,
          margin: const pw.EdgeInsets.all(20), 
          footer: (context) => _buildBottomFooter(reportId, context.pageNumber, docTotalPages, ttfRegular),
          // REMOVED header property to control it manually
          build: (context) {
             return [
               if (pageIdx == 0) ...[
                 _buildReportHeader(branch, year, section, month, formattedDate, reportId, ttfBold, ttfRegular),
                 pw.SizedBox(height: 10),
               ] else ...[
                 pw.SizedBox(height: 20), // Minimal top spacing for subsequent pages
               ],
               pw.Center(child: pw.Text("Student Details (Days $startDay-$endDay)", style: pw.TextStyle(font: ttfBold, fontSize: 14))),
               pw.SizedBox(height: 10),
               _buildDetailedTable(currentDays, students, attendanceData, ttfBold, ttfRegular),
               // Footer for page number is handled by footer property usually, or we can add it here if it's content flow
               // Standard footer for page numbers
             ];
          }
        ),
      );
    }
    
    // Calculate Working Days
    int workingDays = 0;
    try {
      final dateObj = DateFormat("MMMM yyyy").parse(month);
      for (int i = 1; i <= daysInMonth; i++) {
         DateTime d = DateTime(dateObj.year, dateObj.month, i);
         if (d.weekday == DateTime.sunday) continue;

         // Check for Holiday in Data
         bool isHoliday = false;
         String key = i.toString();
         if (attendanceData.containsKey(key)) {
             final dayRecs = attendanceData[key]!;
             // If any record shows 'H', treat as holiday. 
             // We check the first student's status for efficiency, assuming class-wide holidays.
             if (dayRecs.isNotEmpty) {
                 final oneStudent = dayRecs.values.first; // Check first student
                 if (_normalizeStatus(oneStudent['AM']) == 'H' || _normalizeStatus(oneStudent['PM']) == 'H') {
                     isHoliday = true;
                 }
             }
         }
         
         if (!isHoliday) workingDays++;
      }
    } catch (e) {
      debugPrint("Error calculating working days: $e");
      workingDays = daysInMonth; // Fallback
    }

    // --- Summary Page ---
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape, 
        margin: const pw.EdgeInsets.all(30),
        footer: (context) => _buildBottomFooter(reportId, context.pageNumber, docTotalPages, ttfRegular),
        build: (context) => [
          pw.Center(child: pw.Text("FINAL VIEW OF THE ATTENDANCE REPORT", style: pw.TextStyle(font: ttfBold, fontSize: 18, decoration: pw.TextDecoration.underline))),
          pw.SizedBox(height: 30),
          _buildSummaryTable(students, attendanceData, workingDays, ttfBold, ttfRegular),
          pw.SizedBox(height: 40),
          _buildSignatureBlock(ttfBold, ttfRegular, formattedDate),
        ]
      )
    );

    await _saveAndLaunchPdf(pdf, "Attendance_Report_${branch}_${section}_${month.replaceAll(' ', '_')}.pdf");
  }

  static pw.Widget _buildReportHeader(String branch, String year, String section, String month, String generatedOn, String reportId, pw.Font fontBold, pw.Font fontRegular) {
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
                      _buildInfoRow("College:", "ALWARDAS POLYTECHNICâ€”GOPALAPATNAM", fontBold, fontRegular),
                      pw.SizedBox(height: 4),
                      _buildInfoRow("Branch:", branch, fontBold, fontRegular),
                      pw.SizedBox(height: 4),
                      _buildInfoRow("Year & Section:", "$year â€“ $section", fontBold, fontRegular),
                      pw.SizedBox(height: 4),
                      _buildInfoRow("Month:", month, fontBold, fontRegular),
                   ]
                 )
               ),
               // Right Column
               pw.Expanded(
                 flex: 2,
                 child: pw.Column(
                   crossAxisAlignment: pw.CrossAxisAlignment.start,
                   children: [
                      _buildInfoRow("Generated On:", generatedOn, fontBold, fontRegular),
                      pw.SizedBox(height: 4),
                      _buildInfoRow("Generated By:", "HOD / Admin", fontBold, fontRegular),
                      pw.SizedBox(height: 4),
                      _buildInfoRow("Report ID:", reportId, fontBold, fontRegular),
                   ]
                 )
               )
             ]
           )
        ),
        pw.SizedBox(height: 8),
        pw.Center(child: pw.Text("Legend: P = Present | A = Absent | H = Holiday", style: pw.TextStyle(font: fontBold, fontSize: 10))),
        pw.Divider(thickness: 1.5, color: PdfColors.grey800),
        pw.SizedBox(height: 5),
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

  static pw.Widget _buildDetailedTable(List<int> days, List<Map<String, String>> students, Map<String, Map<String, Map<String, String>>> data, pw.Font fb, pw.Font fr) {
     
     bool isDayHoliday(int day) {
        String k = day.toString();
        if (data.containsKey(k)) {
           final dayRecs = data[k]!;
           if (dayRecs.isNotEmpty) {
               final s = dayRecs.values.first;
               if (_normalizeStatus(s['AM']) == 'H' || _normalizeStatus(s['PM']) == 'H') return true;
           }
        }
        return false;
     }

     return pw.Table(
       border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
       columnWidths: {
         0: const pw.FixedColumnWidth(140), 
         for(int i=0; i < days.length; i++) 
            (i + 1): const pw.FlexColumnWidth(1),
       },
       children: [
          // Header Row
          pw.TableRow(
            decoration: const pw.BoxDecoration(color: PdfColors.white),
            children: [
               pw.Container(
                 padding: const pw.EdgeInsets.all(5),
                 alignment: pw.Alignment.center,
                 height: 35, 
                 child: pw.Text("Student Details:", style: pw.TextStyle(font: fb, fontSize: 10)),
               ),
               for (var day in days)
                 pw.Container(
                   decoration: const pw.BoxDecoration(border: pw.Border(left: pw.BorderSide(width: 0.5))),
                   child: pw.Column(
                     children: [
                        pw.Container(
                           height: 18,
                           alignment: pw.Alignment.center,
                           color: PdfColors.grey100,
                           child: pw.Text(day.toString().padLeft(2, '0'), style: pw.TextStyle(font: fr, fontSize: 10, fontWeight: pw.FontWeight.bold)),
                        ),
                        pw.Container(decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(width: 0.5)))),
                        if (isDayHoliday(day))
                           pw.Container(height: 17, alignment: pw.Alignment.center, child: pw.Text("HOLIDAY", style: pw.TextStyle(font: fb, fontSize: 6))) // Small font to fit
                        else
                           pw.Row(
                             children: [
                                pw.Expanded(child: pw.Container(height: 17, alignment: pw.Alignment.center, decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))), child: pw.Text("AM", style: pw.TextStyle(font: fr, fontSize: 8)))),
                                pw.Expanded(child: pw.Container(height: 17, alignment: pw.Alignment.center, child: pw.Text("PM", style: pw.TextStyle(font: fr, fontSize: 8)))),
                             ]
                           )
                     ]
                   )
                 )
            ]
          ),
          
          // Data Rows
          for (var student in students) 
             pw.TableRow(
               children: [
                  // Student Name Cell (No ID, Single Line)
                  pw.Container(
                    padding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 6),
                    alignment: pw.Alignment.centerLeft,
                    child: pw.Text(
                      student['name']?.toUpperCase() ?? '', 
                      style: pw.TextStyle(font: fb, fontSize: 9),
                      maxLines: 1,
                      overflow: pw.TextOverflow.clip
                    ),
                  ),
                  
                  // Day Cells
                  for (var day in days)
                    _buildDayCell(day.toString(), student['id']!, data, fb, fr, isDayHoliday(day))
               ]
             )
       ]
     );
  }

  static pw.Widget _buildDayCell(String day, String sid, Map<String, Map<String, Map<String, String>>> data, pw.Font fb, pw.Font fr, bool isHoliday) {
     if (isHoliday) {
        return pw.Container(height: 30, color: PdfColors.grey100); // Empty grey cell for holiday
     }

     final dayData = data[day];
     String am = '';
     String pm = '';
     
     if (dayData != null && dayData.containsKey(sid)) {
        am = _normalizeStatus(dayData[sid]?['AM']);
        pm = _normalizeStatus(dayData[sid]?['PM']);
     }
     
     return pw.Container(
       height: 30, // Fixed row height
       child: pw.Row(
         children: [
            pw.Expanded(
              child: pw.Container(
                decoration: const pw.BoxDecoration(border: pw.Border(right: pw.BorderSide(width: 0.5))),
                alignment: pw.Alignment.center,
                child: _buildStatusText(am, fb)
              )
            ),
            pw.Expanded(
              child: pw.Container(
                alignment: pw.Alignment.center,
                child: _buildStatusText(pm, fb)
              )
            )
         ]
       )
     );
  }

  static pw.Widget _buildStatusText(String status, pw.Font font) {
     if (status == 'P') return pw.Text('P', style: pw.TextStyle(font: font, fontSize: 9));
     if (status == 'A') return pw.Text('A', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.red));
     if (status == 'H') return pw.Text('H', style: pw.TextStyle(font: font, fontSize: 9, color: PdfColors.blue));
     return pw.Text('', style: pw.TextStyle(font: font, fontSize: 9));
  }

  static String _normalizeStatus(String? s) {
     if (s == null) return '';
     final up = s.toUpperCase();
     if (up.contains('ABSENT')) return 'A';
     if (up.contains('PRESENT')) return 'P';
     if (up.contains('HOLIDAY')) return 'H';
     return ''; 
  }

  // --- Summary Section ---
  static pw.Widget _buildSummaryTable(List<Map<String, String>> students, Map<String, Map<String, Map<String, String>>> data, int totalDays, pw.Font fb, pw.Font fr) {
    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.black, width: 0.5),
      columnWidths: {
        0: const pw.FixedColumnWidth(100), // Register No
        1: const pw.FlexColumnWidth(2.5), // Student Name
        2: const pw.FixedColumnWidth(55), // Total Days
        3: const pw.FixedColumnWidth(55), // Present AM
        4: const pw.FixedColumnWidth(55), // Present PM
        5: const pw.FixedColumnWidth(65), // Absent Days
        6: const pw.FixedColumnWidth(70), // Attendance %
      },
      children: [
        // Complex Header Simulation
        pw.TableRow(
          decoration: const pw.BoxDecoration(color: PdfColors.grey200),
          children: [
             _summaryHeaderCell("Register No.", fb, height: 40),
             _summaryHeaderCell("Student Name", fb, height: 40),
             _summaryHeaderCell("TOTAL\nDAYS", fb, height: 40),
             // Merged Header for Present Days
             // Since "PRESENT DAYS" creates a column in the table, we CANNOT easily split it into two real columns for data rows using standard TableRow.
             // TRICK: We will actually use 2 columns in the table def (Col 3 and 4), and fake the header spanning.
             // BUT `pdf` TableRow doesn't span.
             // SO we must have explicit headers: "PRESENT (AM)" "PRESENT (PM)". 
             // To match the image look:
             // We'll use "PRESENT DAYS" as a single column header? No, data rows need 2 columns.
             // REVERT: We will just use standard headers "AM" "PM" with "PRESENT" above? Not possible without span.
             // CLEANEST: "Present (AM)", "Present (PM)".
             // OR: Manually draw header Row.
             // Let's stick to explicit headers for layout stability but style them.
             
             // RETRYing the Layout:
             // The Table has 7 columns.
             // Header Row:
             // Col 0: Reg
             // Col 1: Name
             // Col 2: Total
             // Col 3: Present AM
             // Col 4: Present PM
             // Col 5: Absent
             // Col 6: %
             // We can textually label Col 3 "PRESENT\n(AM)" and Col 4 "PRESENT\n(PM)".
             
             _summaryHeaderCell("PRESENT\n(AM)", fb, height: 40),
             _summaryHeaderCell("PRESENT\n(PM)", fb, height: 40),
             
             _summaryHeaderCell("ABSENT\nDAYS", fb, height: 40),
             _summaryHeaderCell("ATTENDA-\nNCE %", fb, height: 40),
          ]
        ),
        // Data Rows
        for (var student in students)
           _buildSummaryRow(student, data, totalDays, fb, fr)
      ]
    );
  }
  
  static pw.Widget _summaryHeaderCell(String text, pw.Font font, {double height = 30}) {
    return pw.Container(
      height: height,
      padding: const pw.EdgeInsets.all(5),
      alignment: pw.Alignment.center,
      child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9, fontWeight: pw.FontWeight.bold), textAlign: pw.TextAlign.center)
    );
  }

  static pw.TableRow _buildSummaryRow(Map<String, String> student, Map<String, Map<String, Map<String, String>>> data, int totalDays, pw.Font fb, pw.Font fr) {
      int presentAM = 0;
      int presentPM = 0;
      // Calculate Sessions Present
      data.forEach((day, studentsData) {
         if (studentsData.containsKey(student['id'])) {
             final s = studentsData[student['id']]!;
             if (_normalizeStatus(s['AM']) == 'P') presentAM++;
             if (_normalizeStatus(s['PM']) == 'P') presentPM++;
         }
      });
      
      // Calculate Total Sessions (Total Days * 2)
      // Logic: 
      // If student is absent in AM, and present in PM -> 0.5 day absent?
      
      // Image Logic Reverse Engineering:
      // 31 Total Days.
      // 28 Present (AM/PM).
      // 3 Absent.
      // 90.32%
      // 28/31 = 90.32%.
      // This means "Present Days" = Number of days where student was present (ignoring sessions? or strict?)
      // BUT they show AM and PM columns. AM=28, PM=28.
      // If AM=28 and PM=28, it implies 28 full days.
      // What if AM=28, PM=27?
      // Then Present Days = 27.5?
      // Let's display simple counts.
      
      int totalPotentialSessions = totalDays * 2;
      double percentage = 0.0;
      if (totalPotentialSessions > 0) {
         percentage = ((presentAM + presentPM) / totalPotentialSessions) * 100;
      }
      
      // Absent Days: Calculate based on sessions.
      // Total Sessions - Present Sessions = Absent Sessions.
      // Absent Days = Absent Sessions / 2.
      double absentDays = (totalPotentialSessions - (presentAM + presentPM)) / 2.0;
      if (absentDays < 0) absentDays = 0.0;

      return pw.TableRow(
         children: [
            _centeredCell(student['id'] ?? '', fr),
            pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(student['name']?.toUpperCase() ?? '', style: pw.TextStyle(font: fb, fontSize: 9))),
            _centeredCell(totalDays.toString(), fr), // Total Days
            _centeredCell(presentAM.toString(), fr),
            _centeredCell(presentPM.toString(), fr),
            _centeredCell(absentDays % 1 == 0 ? absentDays.toInt().toString() : absentDays.toStringAsFixed(1), fr),
            _centeredCell("${percentage.toStringAsFixed(2)}%", fb), // Bold Percentage
         ]
      );
  }

  static pw.Widget _centeredCell(String text, pw.Font font) {
     return pw.Container(
       height: 25,
       padding: const pw.EdgeInsets.all(2),
       alignment: pw.Alignment.center,
       child: pw.Text(text, style: pw.TextStyle(font: font, fontSize: 9))
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
  
  static int _getDaysInMonth(String monthYear) {
    try {
      final date = DateFormat("MMMM yyyy").parse(monthYear);
      final nextMonth = DateTime(date.year, date.month + 1, 0);
      return nextMonth.day;
    } catch (e) {
      return 30; 
    }
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

