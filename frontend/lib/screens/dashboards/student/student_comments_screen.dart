import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';

class StudentCommentsScreen extends StatefulWidget {
  final Map<String, dynamic> userData; // Need userData for ID
  const StudentCommentsScreen({super.key, required this.userData});

  @override
  _StudentCommentsScreenState createState() => _StudentCommentsScreenState();
}

class _StudentCommentsScreenState extends State<StudentCommentsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _subjectController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSubmitting = false;
  List<dynamic> _issues = [];
  bool _isLoadingIssues = true;

  @override
  void initState() {
    super.initState();
    _fetchIssues();
  }

  Future<void> _fetchIssues() async {
    final userId = widget.userData['id'];
    if (userId == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.studentGetIssues}?userId=$userId'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _issues = json.decode(response.body);
          _isLoadingIssues = false;
        });
      } else {
        throw Exception('Failed to load issues');
      }
    } catch (e) {
      print("Error fetching issues: $e");
      setState(() => _isLoadingIssues = false);
    }
  }

  Future<void> _submitIssue() async {
    if (!_formKey.currentState!.validate()) return;
    
    final userId = widget.userData['id']; // Ensure ID is present
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User ID not found")));
      return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.studentSubmitIssue),
        body: json.encode({
          'userId': userId,
          'subject': _subjectController.text,
          'description': _messageController.text, // Backend expects description
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Issue reported successfully!", style: GoogleFonts.poppins()),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            )
          );
          _subjectController.clear();
          _messageController.clear();
          
          // Refresh list instead of popping
          _fetchIssues(); 
        }
      } else {
        throw Exception("Failed to submit");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to report issue. Please try again.", style: GoogleFonts.poppins()),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          )
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? ThemeColors.darkBackground : ThemeColors.lightBackground;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Report Issue", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Form Section
                Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Report an Issue", 
                        style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)
                      ),
                      const SizedBox(height: 8),
                      Text(
                        "Describe the issue you are facing.", 
                        style: GoogleFonts.poppins(fontSize: 14, color: subTextColor)
                      ),
                      const SizedBox(height: 30),
                      
                      Text("Subject", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _subjectController,
                        style: GoogleFonts.poppins(color: textColor),
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: cardColor,
                          hintText: "Enter subject (e.g., Course Issue, Facility Request)",
                          hintStyle: GoogleFonts.poppins(color: subTextColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (val) => val == null || val.isEmpty ? "Subject is required" : null,
                      ),
                      const SizedBox(height: 20),

                      Text("Description", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 8),
                      TextFormField(
                        controller: _messageController,
                        style: GoogleFonts.poppins(color: textColor),
                        maxLines: 6,
                        decoration: InputDecoration(
                          filled: true,
                          fillColor: cardColor,
                          hintText: "Describe your issue here...",
                          hintStyle: GoogleFonts.poppins(color: subTextColor),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
                        ),
                        validator: (val) => val == null || val.isEmpty ? "Description is required" : null,
                      ),
                      
                      const SizedBox(height: 30),
                      
                      SizedBox(
                        width: double.infinity,
                        height: 55,
                        child: ElevatedButton(
                          onPressed: _isSubmitting ? null : _submitIssue,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE94057),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                            elevation: 5,
                            shadowColor: const Color(0xFFE94057).withOpacity(0.4),
                          ),
                          child: _isSubmitting 
                            ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                            : Text(
                                "Submit Issue", 
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold)
                              ),
                        ),
                      )
                    ],
                  ),
                ),

                const SizedBox(height: 40),
                Divider(color: subTextColor.withOpacity(0.2), thickness: 2),
                const SizedBox(height: 20),

                // Track Issues Section
                Text("Track Issues", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                const SizedBox(height: 15),

                if (_isLoadingIssues)
                  const Center(child: CircularProgressIndicator())
                else if (_issues.isEmpty)
                   Center(child: Text("No issues raised yet.", style: GoogleFonts.poppins(color: subTextColor)))
                else
                  ..._issues.map((issue) {
                    final status = issue['status'] ?? 'PENDING';
                    final color = _getStatusColor(status);
                    final date = DateTime.parse(issue['createdAt']);
                    final formattedDate = DateFormat('MMM d, y, h:mm a').format(date.toLocal());

                    return Container(
                      margin: const EdgeInsets.only(bottom: 15),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(15),
                        border: Border.all(color: iconBg),
                        boxShadow: [
                           if(isDark) BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 5, offset: const Offset(0,2))
                         ]
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Expanded(
                                child: Text(
                                  issue['subject'] ?? 'No Subject',
                                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  color: color.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  status,
                                  style: GoogleFonts.poppins(color: color, fontWeight: FontWeight.bold, fontSize: 12),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(issue['description'] ?? '', style: GoogleFonts.poppins(color: subTextColor, fontSize: 14)),
                          const SizedBox(height: 12),
                          Row(
                             children: [
                               Icon(Icons.calendar_today, size: 14, color: subTextColor),
                               const SizedBox(width: 5),
                               Text("Raised: $formattedDate", style: GoogleFonts.poppins(color: subTextColor, fontSize: 12)),
                             ],
                          ),
                          
                          // Response Section if available
                          if (issue['response'] != null || issue['reactedAt'] != null) ...[
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.all(12),
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: isDark ? Colors.black26 : Colors.grey[100],
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if(issue['response'] != null)
                                    Text("Response: ${issue['response']}", style: GoogleFonts.poppins(color: textColor, fontSize: 13, fontStyle: FontStyle.italic)),
                                  
                                  const SizedBox(height: 5),
                                  if(issue['reactedAt'] != null) ...[
                                     Row(
                                       children: [
                                         Icon(Icons.check_circle_outline, size: 14, color: Colors.green),
                                         const SizedBox(width: 5),
                                         Text(
                                            "Reacted: ${DateFormat('MMM d, h:mm a').format(DateTime.parse(issue['reactedAt']).toLocal())}", 
                                            style: GoogleFonts.poppins(color: Colors.green, fontSize: 12)
                                         ),
                                       ],
                                     ),
                                  ],
                                  if(issue['responderName'] != null) ...[
                                    const SizedBox(height: 2),
                                    Text("By: ${issue['responderName']}", style: GoogleFonts.poppins(color: subTextColor, fontSize: 12)),
                                  ]
                                ],
                              ),
                            )
                          ]
                        ],
                      ),
                    );
                  }).toList(),
                  const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Color _getStatusColor(String status) {
    if (status == 'PENDING') return Colors.orange;
    if (status == 'RESOLVED' || status == 'ACCEPTED') return Colors.green;
    if (status == 'REJECTED') return Colors.red;
    return Colors.blue;
  }
}
