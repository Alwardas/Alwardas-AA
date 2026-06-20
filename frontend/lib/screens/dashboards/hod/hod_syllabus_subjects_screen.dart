import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:file_picker/file_picker.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/api_constants.dart';
import '../../../widgets/skeleton_loader.dart';
import '../../../core/api_config.dart';
import '../../../data/courses_data.dart';
import 'hod_syllabus_lesson_topics_screen.dart';
import '../../../services/pdf_service.dart';

class HodSyllabusSubjectsScreen extends StatefulWidget {
  final String courseId;
  final String year;
  final String semester;
  final String section;
  final Map<String, dynamic> userData;

  const HodSyllabusSubjectsScreen({
    super.key,
    required this.courseId,
    required this.year,
    required this.semester,
    required this.section,
    required this.userData,
  });

  @override
  State<HodSyllabusSubjectsScreen> createState() => _HodSyllabusSubjectsScreenState();
}

class _HodSyllabusSubjectsScreenState extends State<HodSyllabusSubjectsScreen> {
  bool _isLoading = true;
  List<dynamic> _subjects = [];

  @override
  void initState() {
    super.initState();
    _fetchSubjects();
  }

  Future<void> _fetchSubjects() async {
    final branch = widget.userData['branch'] ?? 'Computer Engineering';
    final url = '${ApiConstants.baseUrl}/api/hod/syllabus/section-subjects-progress?branch=${Uri.encodeComponent(branch)}&year=${Uri.encodeComponent(widget.year)}&section=${Uri.encodeComponent(widget.section)}&courseId=${Uri.encodeComponent(widget.courseId)}&semester=${Uri.encodeComponent(widget.semester)}';
    
    Map<String, dynamic> apiProgressMap = {};

    try {
      final response = await ApiConfig.get(url);
      if (response.success && response.data != null && (response.data as List).isNotEmpty) {
        for (var item in response.data) {
          apiProgressMap[item['subjectId'].toString().toLowerCase()] = {
            'status': item['status'],
            'percentage': item['percentage'],
          };
        }
      }
    } catch (e) {
      debugPrint("Error fetching subjects progress: $e");
    }

    try {
      final allCourses = await CoursesData.getAllCourses();
      
      final filtered = allCourses.where((c) {
        bool matchCourse = c['regulation'].toString().toUpperCase() == widget.courseId.toUpperCase().replaceAll('-', '');
        bool matchBranch = CoursesData.normalizeBranch(c['branch']) == CoursesData.normalizeBranch(branch);
        bool matchSem = CoursesData.normalizeSemester(c['semester']) == CoursesData.normalizeSemester(widget.semester);
        return matchCourse && matchBranch && matchSem;
      }).toList();

      List<dynamic> localSubjects = filtered.map((c) {
        final subjIdLower = c['id'].toString().toLowerCase();
        final progressData = apiProgressMap[subjIdLower];
        return {
          'subjectId': c['id'],
          'subjectName': c['name'],
          'status': progressData != null ? progressData['status'] : 'On Track',
          'percentage': progressData != null ? progressData['percentage'] : 0,
        };
      }).toList();

      localSubjects.sort((a, b) => (a['subjectId'] as String).compareTo(b['subjectId'] as String));

      if (mounted) {
        setState(() {
          _subjects = localSubjects;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching local subjects: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final bgColors = isDark 
        ? [const Color(0xFF1a1a2e), const Color(0xFF16213e)] 
        : [const Color(0xFFF8F9FA), Colors.white];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('${widget.semester} Subjects', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: bgColors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Column(
            children: [
               Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  children: [
                    const Icon(Icons.location_on, size: 16, color: Colors.orange),
                    const SizedBox(width: 5),
                    Text("${widget.year} - ${widget.section}", style: GoogleFonts.poppins(fontSize: 14, color: textColor.withValues(alpha: 0.7))),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: _isLoading 
                  ? _buildSkeletonList(isDark)
                  : _subjects.isEmpty
                      ? Center(child: Text("No subjects found for this semester.", style: GoogleFonts.poppins(color: subTextColor)))
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _subjects.length,
                          itemBuilder: (context, index) {
                            final subject = _subjects[index];
                            return _buildSubjectCard(subject, isDark, textColor, subTextColor);
                          },
                        ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSubjectCard(dynamic subject, bool isDark, Color textColor, Color subTextColor) {
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;
    final status = subject['status'] ?? 'On Track';
    final percentage = (subject['percentage'] as num).toInt();

    Color statusColor;
    switch (status) {
      case 'Lagging': statusColor = Colors.red; break;
      case 'Overfast': 
      case 'Over Fast': statusColor = Colors.orange; break;
      default: statusColor = Colors.green;
    }

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => HodSyllabusLessonTopicsScreen(
          subjectId: subject['subjectId'],
          subjectName: subject['subjectName'],
          year: widget.year,
          semester: widget.semester,
          section: widget.section,
          userData: widget.userData,
        )));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subject['subjectName'],
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 16),
                      ),
                      Text(
                        "Code: ${subject['subjectId']}",
                        style: GoogleFonts.poppins(fontSize: 12, color: subTextColor),
                      ),
                    ],
                  ),
                ),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        status,
                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: statusColor),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _PdfDownloadButton(subject: subject, parentWidget: widget),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Completion Progress", style: GoogleFonts.poppins(fontSize: 13, color: subTextColor)),
                Text("$percentage%", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: textColor)),
              ],
            ),
            const SizedBox(height: 8),
            LinearProgressIndicator(
              value: percentage / 100,
              backgroundColor: statusColor.withValues(alpha: 0.1),
              color: statusColor,
              borderRadius: BorderRadius.circular(10),
              minHeight: 8,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList(bool isDark) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 4,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 20),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                SkeletonLoader(width: 48, height: 48, borderRadius: BorderRadius.circular(24)),
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SkeletonLoader(width: 150, height: 18, borderRadius: BorderRadius.circular(4)),
                      const SizedBox(height: 8),
                      SkeletonLoader(width: 80, height: 12, borderRadius: BorderRadius.circular(4)),
                    ],
                  ),
                ),
                SkeletonLoader(width: 60, height: 20, borderRadius: BorderRadius.circular(10)),
              ],
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonLoader(width: 120, height: 13, borderRadius: BorderRadius.circular(4)),
                SkeletonLoader(width: 40, height: 13, borderRadius: BorderRadius.circular(4)),
              ],
            ),
            const SizedBox(height: 8),
            SkeletonLoader(width: double.infinity, height: 8, borderRadius: BorderRadius.circular(10)),
          ],
        ),
      ),
    );
  }
}

class _PdfDownloadButton extends StatefulWidget {
  final dynamic subject;
  final HodSyllabusSubjectsScreen parentWidget;
  const _PdfDownloadButton({required this.subject, required this.parentWidget});

  @override
  State<_PdfDownloadButton> createState() => _PdfDownloadButtonState();
}

class _PdfDownloadButtonState extends State<_PdfDownloadButton> {
  bool _isGenerating = false;

  List<String> _parseCsvLine(String line) {
    List<String> result = [];
    bool inQuotes = false;
    StringBuffer sb = StringBuffer();
    for (int i = 0; i < line.length; i++) {
      final c = line[i];
      if (c == '"') {
        inQuotes = !inQuotes;
      } else if (c == ',' && !inQuotes) {
        result.add(sb.toString().trim());
        sb.clear();
      } else {
        sb.write(c);
      }
    }
    result.add(sb.toString().trim());
    return result;
  }

  String? _parseInputDate(String input) {
    input = input.trim();
    if (input.isEmpty) return null;
    
    // 1. Try standard YYYY-MM-DD
    final yyyymmddRegExp = RegExp(r'^(\d{4})[-/](\d{1,2})[-/](\d{1,2})$');
    if (yyyymmddRegExp.hasMatch(input)) {
      final match = yyyymmddRegExp.firstMatch(input)!;
      final year = match.group(1)!;
      final month = match.group(2)!.padLeft(2, '0');
      final day = match.group(3)!.padLeft(2, '0');
      return "$year-$month-$day";
    }

    // 2. Try standard DD/MM/YYYY or DD-MM-YYYY
    final ddmmyyyyRegExp = RegExp(r'^(\d{1,2})[-/](\d{1,2})[-/](\d{4})$');
    if (ddmmyyyyRegExp.hasMatch(input)) {
      final match = ddmmyyyyRegExp.firstMatch(input)!;
      final day = match.group(1)!.padLeft(2, '0');
      final month = match.group(2)!.padLeft(2, '0');
      final year = match.group(3)!;
      return "$year-$month-$day";
    }

    // 3. Fallback: Try standard DateTime parse
    try {
      final parsed = DateTime.parse(input);
      return DateFormat('yyyy-MM-dd').format(parsed);
    } catch (_) {
      return null;
    }
  }

  Future<void> _downloadExcelTemplate() async {
    setState(() => _isGenerating = true);
    try {
      final subjectId = widget.subject['subjectId'];
      final subjectName = widget.subject['subjectName'];
      final branch = widget.parentWidget.userData['branch'] ?? 'Computer Engineering';
      final section = widget.parentWidget.section;

      // 1. Fetch current API schedule dates
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
        debugPrint("Error fetching API topics: $e");
      }

      // 2. Load local syllabus topics
      final subjectDetails = await CoursesData.getSubjectDetails(subjectId);
      if (subjectDetails == null || subjectDetails['units'] == null) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Syllabus details not found.")));
        }
        return;
      }

      // 3. Build CSV string
      StringBuffer csvBuffer = StringBuffer();
      csvBuffer.writeln("Topic ID,Unit,Topic Name,Scheduled Date (YYYY-MM-DD)");

      for (var unit in subjectDetails['units']) {
        final String unitLabel = "Unit ${unit['unitNo']}";
        if (unit['topics'] != null) {
          for (var t in unit['topics']) {
            final topicId = t['id'].toString();
            final topicName = t['topic'].toString();
            final cleanTopicName = topicName.replaceAll('"', '""');
            
            final apiData = apiTopicsMap[topicId.toLowerCase()];
            String scheduleDate = "";
            if (apiData != null && apiData['scheduleDate'] != null) {
              scheduleDate = apiData['scheduleDate'].toString().split('T')[0];
            }

            csvBuffer.writeln('"$topicId","$unitLabel","$cleanTopicName","$scheduleDate"');
          }
        }
      }

      // 4. Save and launch CSV file
      final bytes = utf8.encode(csvBuffer.toString());
      final fileName = "${subjectName.replaceAll(RegExp(r'[^\w\s\-]'), '_')}_Schedule_Template.csv";
      
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

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Template downloaded to ${file.path}")));
      }
    } catch (e) {
      debugPrint("Error generating Excel template: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to download template.")));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  Future<void> _uploadExcelAndAssign() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['csv'],
      );

      if (result == null || result.files.single.path == null) {
        return;
      }

      final file = File(result.files.single.path!);
      final content = await file.readAsString();
      final lines = const LineSplitter().convert(content);

      if (lines.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Selected CSV file is empty.")));
        }
        return;
      }

      List<Map<String, String>> topicsToUpdate = [];
      
      for (int i = 1; i < lines.length; i++) {
        final line = lines[i].trim();
        if (line.isEmpty) continue;
        final fields = _parseCsvLine(line);
        if (fields.length >= 4) {
          final topicId = fields[0].replaceAll('"', '').trim();
          final rawDate = fields[3].replaceAll('"', '').trim();
          final formattedDate = _parseInputDate(rawDate);
          
          if (topicId.isNotEmpty && formattedDate != null) {
            topicsToUpdate.add({
              'topicId': topicId,
              'scheduleDate': formattedDate,
            });
          }
        }
      }

      if (topicsToUpdate.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("No valid scheduled dates found in the file.")));
        }
        return;
      }

      int completedCount = 0;
      final totalCount = topicsToUpdate.length;
      bool isDone = false;

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          return StatefulBuilder(
            builder: (context, setDialogState) {
              if (completedCount == 0 && !isDone) {
                Future.microtask(() async {
                  final branch = widget.parentWidget.userData['branch'] ?? 'Computer Engineering';
                  final facultyId = widget.parentWidget.userData['login_id'] ?? 'HOD';
                  final url = Uri.parse('${ApiConstants.baseUrl}/api/faculty/hod-assign-schedule');

                  for (var item in topicsToUpdate) {
                    try {
                      await http.post(
                        url,
                        headers: {'Content-Type': 'application/json'},
                        body: json.encode({
                          'subjectId': widget.subject['subjectId'],
                          'topicId': item['topicId'],
                          'scheduleDate': item['scheduleDate'],
                          'facultyId': facultyId,
                          'branch': branch,
                          'year': widget.parentWidget.year,
                          'semester': widget.parentWidget.semester,
                          'section': widget.parentWidget.section,
                        }),
                      );
                    } catch (e) {
                      debugPrint("Error assigning topic ${item['topicId']}: $e");
                    }
                    
                    if (mounted) {
                      setDialogState(() {
                        completedCount++;
                      });
                    }
                  }

                  if (mounted) {
                    setDialogState(() {
                      isDone = true;
                    });
                  }
                });
              }

              return AlertDialog(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                title: Text(isDone ? "Upload Completed" : "Assigning Dates...", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (!isDone) ...[
                      const CircularProgressIndicator(),
                      const SizedBox(height: 20),
                      Text("Updating topics: $completedCount of $totalCount", style: GoogleFonts.poppins()),
                    ] else ...[
                      const Icon(Icons.check_circle, color: Colors.green, size: 48),
                      const SizedBox(height: 15),
                      Text("Successfully assigned dates to $totalCount topics!", style: GoogleFonts.poppins()),
                    ],
                  ],
                ),
                actions: [
                  if (isDone)
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        Navigator.pushReplacement(
                          context,
                          MaterialPageRoute(
                            builder: (context) => HodSyllabusSubjectsScreen(
                              courseId: widget.parentWidget.courseId,
                              year: widget.parentWidget.year,
                              semester: widget.parentWidget.semester,
                              section: widget.parentWidget.section,
                              userData: widget.parentWidget.userData,
                            ),
                          ),
                        );
                      },
                      child: Text("Close", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    ),
                ],
              );
            },
          );
        },
      );

    } catch (e) {
      debugPrint("Error uploading CSV: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error parsing or uploading file.")));
      }
    }
  }

  Future<void> _generatePdfReport() async {
    setState(() => _isGenerating = true);
    final role = widget.parentWidget.userData['role'] ?? '';
    final facultyName = role == 'Faculty' ? (widget.parentWidget.userData['full_name'] ?? 'Faculty') : 'Assigned Faculty';
    await PdfService.generateLessonPlanPdf(
      context: context,
      subjectId: widget.subject['subjectId'],
      subjectName: widget.subject['subjectName'],
      status: widget.subject['status'] ?? 'On Track',
      percentage: (widget.subject['percentage'] as num).toInt(),
      facultyName: facultyName,
      academicYear: "2025-26", 
      branch: widget.parentWidget.userData['branch'] ?? 'Computer Engineering',
      section: widget.parentWidget.section,
    );
    if (mounted) setState(() => _isGenerating = false);
  }

  void _showDownloadOptions() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Syllabus & Schedule Actions",
                style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                "Select how you want to manage the lesson plans for ${widget.subject['subjectName']}.",
                style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.picture_as_pdf, color: Colors.red),
                ),
                title: Text("Download PDF Report", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                subtitle: Text("Generate stylized Lesson Plan document", style: GoogleFonts.poppins(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _generatePdfReport();
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.green.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.table_view, color: Colors.green),
                ),
                title: Text("Download Excel Template", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                subtitle: Text("Download spreadsheet with topics and date fields", style: GoogleFonts.poppins(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _downloadExcelTemplate();
                },
              ),
              const Divider(),
              ListTile(
                leading: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.upload_file, color: Colors.blue),
                ),
                title: Text("Upload Excel (Assign Dates)", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                subtitle: Text("Upload edited CSV file to assign all dates at once", style: GoogleFonts.poppins(fontSize: 12)),
                onTap: () {
                  Navigator.pop(context);
                  _uploadExcelAndAssign();
                },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isGenerating 
      ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
      : GestureDetector(
          onTap: () {
            final role = widget.parentWidget.userData['role']?.toString().toUpperCase() ?? '';
            if (role == 'HOD') {
              _showDownloadOptions();
            } else {
              _generatePdfReport();
            }
          },
          child: Container(
             padding: const EdgeInsets.all(6),
             decoration: BoxDecoration(
               color: Colors.blue.withValues(alpha: 0.1),
               borderRadius: BorderRadius.circular(8),
             ),
             child: const Icon(Icons.download_rounded, color: Colors.blue, size: 18),
          ),
        );
  }
}

