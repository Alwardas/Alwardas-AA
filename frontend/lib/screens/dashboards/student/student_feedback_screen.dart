
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../core/api_constants.dart';
import '../../../theme/theme_constants.dart';

class StudentFeedbackScreen extends StatefulWidget {
  final Map<String, dynamic> userData;

  const StudentFeedbackScreen({super.key, required this.userData});

  @override
  State<StudentFeedbackScreen> createState() => _StudentFeedbackScreenState();
}

class _StudentFeedbackScreenState extends State<StudentFeedbackScreen> {
  List<dynamic> _feedbacks = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchFeedbacks();
  }

  Future<void> _fetchFeedbacks() async {
    final userId = widget.userData['id']?.toString() ?? widget.userData['login_id']?.toString();
    if (userId == null) {
        setState(() => _loading = false);
        return;
    }

    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/student/feedbacks?userId=$userId'));
      
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _feedbacks = json.decode(response.body);
            _loading = false;
          });
        }
      } else {
        debugPrint("Failed to fetch feedbacks: ${response.statusCode}");
        if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint("Error fetching feedbacks: $e");
      if (mounted) setState(() => _loading = false);
    }
  }
  
  Color _getIssueColor(String type) {
      switch(type.toUpperCase()) {
          case 'DONE': return Colors.green;
          case 'NOT_UNDERSTOOD': return Colors.orange;
          case 'NOT_DONE': return Colors.red;
          default: return Colors.blue; 
      }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bgColor = isDark ? const Color(0xFF151517) : const Color(0xFFF5F7FA);
    final cardColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2D3748);
    final subTextColor = isDark ? Colors.white70 : Colors.grey[600];

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("My Feedbacks", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _feedbacks.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.feedback_outlined, size: 80, color: Colors.grey[400]),
                      const SizedBox(height: 16),
                      Text(
                        "No Feedbacks Yet",
                        style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: subTextColor),
                      ),
                    ],
                  ),
                )
              : ListView.separated(
                  padding: const EdgeInsets.all(20),
                  itemCount: _feedbacks.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 15),
                  itemBuilder: (context, index) {
                    final item = _feedbacks[index];
                    final dateStr = DateFormat('MMM d, yyyy • h:mm a').format(DateTime.parse(item['createdAt']).toLocal());
                    final rating = item['rating'] ?? 0;
                    final issueType = item['issueType'] ?? 'FEEDBACK';
                    final issueColor = _getIssueColor(issueType);
                    
                    final reply = item['reply'];
                    final repliedAt = item['repliedAt'];

                    return Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Header: Subject Code & Date
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: Colors.blue.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  item['subjectCode'] ?? item['subject_code'] ?? 'Unknown Subject',
                                  style: GoogleFonts.poppins(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blue,
                                  ),
                                ),
                              ),
                              Text(dateStr, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          // Topic Name
                          Text(
                             item['topic'] ?? 'Unknown Topic',
                             style: GoogleFonts.poppins(
                                 fontSize: 16,
                                 fontWeight: FontWeight.w600,
                                 color: textColor,
                             ),
                          ),
                           const SizedBox(height: 4),
                           
                          // Subject Name (subtitle)
                          Text(
                             item['subjectName'] ?? item['subject_name'] ?? '',
                             style: GoogleFonts.poppins(fontSize: 12, color: subTextColor),
                          ),

                          const SizedBox(height: 12),
                          const Divider(height: 1),
                          const SizedBox(height: 12),

                          // Rating & Issue Type
                          Row(
                            children: [
                                Icon(Icons.star_rounded, color: issueColor, size: 20),
                                const SizedBox(width: 4),
                                Text("$rating", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: issueColor)),
                                Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 8.0),
                                  child: Text("•", style: TextStyle(color: Colors.grey[600])),
                                ),
                                Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                    decoration: BoxDecoration(
                                        color: issueColor.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(8)
                                    ),
                                    child: Text(
                                        issueType,
                                        style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: issueColor),
                                    ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          
                          // Comment
                          Text(
                              item['comment'] ?? "",
                              style: GoogleFonts.poppins(fontSize: 14, color: textColor, height: 1.5),
                          ),
                          
                          // Faculty Reply
                          if (reply != null && reply.toString().isNotEmpty) ...[
                             const SizedBox(height: 15),
                             Container(
                                 width: double.infinity,
                                 padding: const EdgeInsets.all(12),
                                 decoration: BoxDecoration(
                                     color: isDark ? Colors.black26 : Colors.grey.shade50,
                                     borderRadius: BorderRadius.circular(12),
                                     border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                                 ),
                                 child: Column(
                                     crossAxisAlignment: CrossAxisAlignment.start,
                                     children: [
                                         Row(
                                             children: [
                                                 Icon(Icons.reply, size: 16, color: Colors.blue),
                                                 const SizedBox(width: 8),
                                                 Text("Faculty Reply", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.blue)),
                                                 const Spacer(),
                                                 if (repliedAt != null)
                                                   Text(
                                                      DateFormat('MMM d').format(DateTime.parse(repliedAt).toLocal()),
                                                      style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey),
                                                   ),
                                             ],
                                         ),
                                         const SizedBox(height: 6),
                                         Text(
                                             reply,
                                             style: GoogleFonts.poppins(fontSize: 13, color: subTextColor),
                                         ),
                                     ],
                                 ),
                             ),
                          ],
                        ],
                      ),
                    );
                  },
                ),
    );
  }
}
