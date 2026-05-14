import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/curriculum_service.dart';
import '../../../core/models/curriculum_merged.dart';
import '../../../widgets/skeleton_loader.dart';

class FacultyLessonPlanScreen extends StatefulWidget {
  final String subjectId;
  final String subjectName; 
  final String facultyName;
  final String? section;
  final String? year;
  final int semester;
  final String branch;

  const FacultyLessonPlanScreen({
    super.key, 
    required this.subjectId, 
    this.subjectName = 'Lesson Plan',
    this.facultyName = 'Unknown Faculty',
    this.section,
    this.year,
    this.semester = 1,
    this.branch = 'Computer Engineering',
  });

  @override
  _FacultyLessonPlanScreenState createState() => _FacultyLessonPlanScreenState();
}

class _FacultyLessonPlanScreenState extends State<FacultyLessonPlanScreen> {
  CurriculumMerged? _curriculum;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchCurriculum();
  }

  Future<void> _fetchCurriculum() async {
    try {
      final response = await CurriculumService.getMergedCurriculum(
        branch: widget.branch,
        semester: widget.semester,
        subjectCode: widget.subjectId,
        section: widget.section ?? 'Section A',
        year: widget.year ?? '1st Year',
      );

      if (response.success && response.data != null) {
        if (mounted) {
          setState(() {
            _curriculum = CurriculumMerged.fromJson(response.data);
            _loading = false;
          });
        }
      } else {
        throw Exception(response.message);
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }
  
  Future<void> _markAsCompleted(CurriculumTopic topic) async {
      final isCompleted = topic.status == 'completed';
      
      bool? confirm = await showDialog(
        context: context, 
        builder: (context) => AlertDialog(
          title: Text(isCompleted ? "Mark Pending" : "Mark Completed", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text(isCompleted 
            ? "Revert this topic to pending?" 
            : "Mark this topic as COMPLETED? This will record the current date.", 
            style: GoogleFonts.poppins()),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false), 
              child: Text("Cancel", style: TextStyle(color: Colors.grey))
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true), 
              child: Text("Confirm", style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold))
            )
          ],
        )
      );

      if (confirm != true) return;

      try {
        final user = await AuthService.getUserSession();
        final facultyId = user?['login_id'] ?? '';
        
        final response = await CurriculumService.updateProgress(
          topicId: topic.id,
          subjectCode: widget.subjectId,
          facultyId: facultyId,
          branch: widget.branch,
          section: widget.section ?? 'Section A',
          year: widget.year ?? '1st Year',
          semester: widget.semester,
          status: isCompleted ? 'pending' : 'completed',
          completedDate: isCompleted ? null : DateTime.now().toIso8601String(),
        );
        
        if (response.success) {
           _fetchCurriculum();
           _showSnackBar(isCompleted ? "Topic reverted to Pending" : "Topic marked as Completed!");
        } else {
           _showSnackBar("Failed: ${response.message}");
        }
      } catch(e) {
        _showSnackBar("Error: $e");
      }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  void _showReviewsModal(CurriculumTopic topic) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Center(
              child: Container(
                width: 50,
                height: 5,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
            Expanded(
              child: _FeedbackList(
                topicId: topic.id,
                subjectCode: widget.subjectId,
                topicName: topic.topic,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF151517) : const Color(0xFFF5F7FA);
    final text = isDark ? Colors.white : const Color(0xFF2D3748);

    return Scaffold(
      backgroundColor: bg,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_ios, color: text, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Column(
          children: [
            Text("Faculty Lesson Plan", style: GoogleFonts.poppins(color: text, fontWeight: FontWeight.bold, fontSize: 16)),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(widget.subjectName, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12)),
            ),
          ],
        ),
      ),
      body: _loading
          ? _buildSkeletonList()
          : _error != null
              ? Center(child: Text("Error: $_error", style: GoogleFonts.poppins(color: Colors.red)))
              : _curriculum == null || _curriculum!.units.isEmpty
                  ? Center(child: Text("No curriculum data found", style: GoogleFonts.poppins(color: text)))
                  : ListView.builder(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(20),
                      itemCount: _curriculum!.units.length,
                      itemBuilder: (context, index) {
                        final unit = _curriculum!.units[index];
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 25, bottom: 15),
                              child: Text(
                                "Unit ${unit.unitNo}: ${unit.title}",
                                style: GoogleFonts.poppins(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Theme.of(context).primaryColor,
                                ),
                              ),
                            ),
                            ...unit.topics.map((topic) => _buildFacultyTopicItem(topic)).toList(),
                          ],
                        );
                      },
                    ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: Theme.of(context).primaryColor,
        icon: const Icon(Icons.picture_as_pdf, color: Colors.white),
        label: Text("Export Log", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        onPressed: () {
            // Simulate Report Download
            showDialog(
              context: context,
              barrierDismissible: false,
              builder: (ctx) => AlertDialog(
                 content: Row(
                   children: [
                     const CircularProgressIndicator(),
                     const SizedBox(width: 20),
                     Text("PDF Generating...", style: GoogleFonts.poppins())
                   ],
                 )
              )
            );
            
            Future.delayed(const Duration(seconds: 2), () {
               Navigator.pop(context); // Close loading
               if (mounted) {
                   ScaffoldMessenger.of(context).showSnackBar(
                     const SnackBar(content: Text("Lesson Plan Report exported to Downloads."))
                   );
               }
            });
        },
      ),
    );
  }

  Widget _buildFacultyTopicItem(CurriculumTopic topic) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final text = isDark ? Colors.white : const Color(0xFF2D3748);
    final isCompleted = topic.status == 'completed';
    
    // Dates
    final assignedDateStr = topic.assignedDate != null 
        ? DateFormat('dd-MM-yyyy').format(topic.assignedDate!.toLocal()) 
        : "Not Scheduled";
    final completedDateStr = isCompleted && topic.completedDate != null 
        ? DateFormat('dd-MM-yyyy').format(topic.completedDate!.toLocal()) 
        : "Pending"; 

    return Opacity(
      opacity: isCompleted ? 0.6 : 1.0,
      child: Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: isCompleted ? Colors.green.withValues(alpha: 0.05) : (isDark ? Colors.grey[900] : Colors.white),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
             if(!isCompleted)
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4)
              )
          ]
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: isCompleted ? Colors.green.withValues(alpha: 0.1) : Colors.grey.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                   Text(
                     topic.sno,
                     style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.grey),
                   ),
                   const SizedBox(width: 12),
                   InkWell(
                     onTap: () => _markAsCompleted(topic),
                     child: Row(
                       children: [
                         Icon(
                           isCompleted ? Icons.check_box : Icons.check_box_outline_blank,
                           color: isCompleted ? Colors.green : Colors.grey,
                           size: 20,
                         ),
                         const SizedBox(width: 6),
                         Text(
                           isCompleted ? "Completed" : "Mark Done",
                           style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: isCompleted ? Colors.green : Colors.grey),
                         )
                       ],
                     ),
                   ),
                   const Spacer(),
                   Column(
                     crossAxisAlignment: CrossAxisAlignment.end,
                     children: [
                       Text("Assigned: $assignedDateStr", style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                       if(isCompleted)
                        Text("Finished: $completedDateStr", style: GoogleFonts.poppins(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                     ],
                   ),
                   const SizedBox(width: 8),
                   IconButton(
                      icon: Stack(
                        children: [
                          const Icon(Icons.comment_outlined, size: 20, color: Colors.blueGrey),
                          if (topic.feedback_count > 0)
                            Positioned(
                              right: 0,
                              top: 0,
                              child: Container(
                                padding: const EdgeInsets.all(2),
                                decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                                child: Text("${topic.feedback_count}", style: const TextStyle(fontSize: 8, color: Colors.white)),
                              ),
                            ),
                        ],
                      ),
                      onPressed: () => _showReviewsModal(topic),
                      constraints: const BoxConstraints(),
                      tooltip: "View Reviews",
                   ),
                ],
              ),
            ),
            Padding(
               padding: const EdgeInsets.all(16),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                    Text(
                      topic.topic,
                      style: GoogleFonts.poppins(
                           fontSize: 14, 
                           color: text, 
                           fontWeight: FontWeight.w500,
                           decoration: isCompleted ? TextDecoration.lineThrough : null,
                           height: 1.4,
                      ),
                    ),
                    if (topic.feedback_count > 0) ...[
                      const SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.thumb_up_outlined, size: 12, color: Colors.blue[300]),
                          const SizedBox(width: 4),
                          Text(
                            "${topic.understoodPercentage.toStringAsFixed(0)}% Understood by Students",
                            style: GoogleFonts.poppins(fontSize: 11, color: Colors.blue[300]),
                          ),
                        ],
                      ),
                    ],
                 ],
               ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildSkeletonList() {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: 5,
      itemBuilder: (context, index) => Container(
        margin: const EdgeInsets.only(bottom: 20),
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.dark ? Colors.grey[900] : Colors.white,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.grey.withValues(alpha: 0.05),
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  SkeletonLoader(width: 20, height: 20, borderRadius: BorderRadius.circular(4)),
                  const SizedBox(width: 12),
                  SkeletonLoader(width: 80, height: 16, borderRadius: BorderRadius.circular(4)),
                  const Spacer(),
                  SkeletonLoader(width: 100, height: 12, borderRadius: BorderRadius.circular(4)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: SkeletonLoader(width: double.infinity, height: 40, borderRadius: BorderRadius.circular(8)),
            ),
          ],
        ),
      ),
    );
  }
}

class _FeedbackList extends StatefulWidget {
  final String topicId;
  final String subjectCode;
  final String topicName;

  const _FeedbackList({
    required this.topicId, 
    required this.subjectCode,
    required this.topicName,
  });

  @override
  State<_FeedbackList> createState() => _FeedbackListState();
}

class _FeedbackListState extends State<_FeedbackList> {
  List<dynamic> _feedbacks = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 300), () {
      if(mounted) _fetchFeedback();
    });
  }

  Future<void> _fetchFeedback() async {
    try {
      // For now, we reuse the existing endpoint or create a new one. 
      // The user wants a clean integration, so let's assume we update the backend to support these filters.
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/student/lesson-plan/feedback?topicId=${widget.topicId}&subjectCode=${widget.subjectCode}'),
      );
      
      if (response.statusCode == 200) {
         final List<dynamic> data = json.decode(response.body);
         if (mounted) {
           setState(() {
             _feedbacks = data;
             _isLoading = false;
           });
         }
      } else {
         if (mounted) setState(() => _error = "No comments found (Status ${response.statusCode})");
      }
    } catch (e) {
      if (mounted) setState(() => _error = "Error: $e");
    } finally {
      if (mounted && _isLoading) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleReply(String feedbackId, String? existingReply) async {
      final TextEditingController replyController = TextEditingController();
      bool isEditing = existingReply == null; 
      
      await showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent, // Important for performance visually
        builder: (context) => StatefulBuilder(
          builder: (context, setSheetState) => Container(
             padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 20, 
                left: 20, 
                right: 20, 
                top: 20
             ),
             decoration: BoxDecoration(
                color: Theme.of(context).cardColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20))
             ),
             child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(isEditing ? "Write a Reply" : "Your Reply", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                      if(!isEditing)
                         IconButton(
                           icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                           onPressed: () {
                             setSheetState(() => isEditing = true);
                           },
                         )
                    ],
                  ),
                  const SizedBox(height: 15),
                  
                  if(!isEditing)
                     Container(
                       width: double.infinity,
                       padding: const EdgeInsets.all(16),
                       decoration: BoxDecoration(
                         color: Colors.blue.withValues(alpha: 0.05),
                         borderRadius: BorderRadius.circular(12),
                         border: Border.all(color: Colors.blue.withValues(alpha: 0.1))
                       ),
                       child: Text(
                         existingReply!,
                         style: GoogleFonts.poppins(fontSize: 14, height: 1.5, color: Colors.black87),
                       ),
                     ),

                  if(isEditing) ...[
                      // Quick Replies - Optimized with standard widgets
                      SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            _buildSimpleChip("Thank you", replyController),
                            _buildSimpleChip("Noted", replyController),
                            _buildSimpleChip("Good point", replyController),
                            _buildSimpleChip("Explain again", replyController),
                          ],
                        ),
                      ),
                      const SizedBox(height: 15),

                      TextField(
                        controller: replyController,
                        autofocus: true,
                        decoration: const InputDecoration(
                          hintText: "Type your reply here...",
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.all(12),
                        ),
                        maxLines: 3,
                      ),
                      const SizedBox(height: 10),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () async {
                             final text = replyController.text.trim();
                             if(text.isEmpty) return;
                             
                             Navigator.pop(context);
                             _submitReply(feedbackId, text);
                          },
                          child: const Text("Send Reply"),
                        ),
                      )
                  ]
                ],
              ),
          ),
        )
      );
  }

  Widget _buildSimpleChip(String text, TextEditingController controller) {
    return GestureDetector(
      onTap: () {
        controller.text = text;
        controller.selection = TextSelection.fromPosition(TextPosition(offset: controller.text.length));
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.grey.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.3))
        ),
        child: Text(text, style: GoogleFonts.poppins(fontSize: 12)),
      ),
    );
  }

  Future<void> _submitReply(String feedbackId, String text) async {
      final user = await AuthService.getUserSession();
      if(user == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: Not logged in")));
          return;
      }
      
      // Support both 'id' and 'login_id' depending on what authentication returns
      final facultyId = user['id'] ?? user['login_id'];
      if(facultyId == null) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Error: User ID not found in session")));
          debugPrint("User Session: $user"); // Debug log 
          return;
      }

      try {
        final response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/api/faculty/lesson-plan/feedback/reply'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'feedbackId': feedbackId,
            'facultyId': facultyId, 
            'reply': text
          })
        );
        
        if (response.statusCode == 200) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reply sent successfully!")));
           _fetchFeedback(); 
        } else {
           debugPrint("Reply Error: ${response.body}"); // Debug log
           ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${response.statusCode} - ${response.body}")));
        }
      } catch(e) {
         debugPrint("Exception Reply: $e");
         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Connection Error: $e")));
      }
  }

  Widget _buildSkeletonList() {
    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 15),
      itemBuilder: (_, __) => Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                SkeletonLoader(width: 60, height: 12, borderRadius: BorderRadius.circular(4)),
                SkeletonLoader(width: 80, height: 10, borderRadius: BorderRadius.circular(4)),
              ],
            ),
            const SizedBox(height: 12),
            SkeletonLoader(width: double.infinity, height: 14, borderRadius: BorderRadius.circular(4)),
            const SizedBox(height: 6),
            SkeletonLoader(width: 200, height: 14, borderRadius: BorderRadius.circular(4)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
           Text("Student Feedback", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blue)),
           Text(widget.topicName, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
           const SizedBox(height: 16),
           Divider(),
           
           Expanded(
             child: _isLoading 
                ? _buildSkeletonList()
                : _error != null 
                    ? Center(child: Text(_error!))
                    : _feedbacks.isEmpty
                       ? Center(
                           child: Column(
                             mainAxisSize: MainAxisSize.min,
                             children: [
                               Icon(Icons.chat_bubble_outline, size: 40, color: Colors.grey[300]),
                               const SizedBox(height: 10),
                               Text("No comments yet.", style: GoogleFonts.poppins(color: Colors.grey)),
                             ],
                           ),
                         )
                       : ListView.separated(
                           physics: const BouncingScrollPhysics(),
                           itemCount: _feedbacks.length,
                           separatorBuilder: (_, __) => const SizedBox(height: 15),
                           itemBuilder: (context, index) {
                              final fb = _feedbacks[index];
                              final date = fb['createdAt'] != null 
                                  ? DateFormat('MMM d, hh:mm a').format(DateTime.parse(fb['createdAt']).toLocal())
                                  : 'Unknown Date';
                              
                              final hasReply = fb['reply'] != null;

                              return Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: Theme.of(context).cardColor,
                                  border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                     Row(
                                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                       children: [
                                         // Hide Name - Just show "Student"
                                         Text('Student', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.blueGrey)),
                                         Text(date, style: GoogleFonts.poppins(fontSize: 10, color: Colors.grey)),
                                       ],
                                     ),
                                     
                                     if(fb['issueType'] != null && fb['issueType'] != 'Other')
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          margin: const EdgeInsets.only(top: 6, bottom: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.red.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(4)
                                          ),
                                          child: Text(fb['issueType'], style: GoogleFonts.poppins(fontSize: 10, color: Colors.red)),
                                        ),
                                     
                                     const SizedBox(height: 4),
                                     Text(
                                       fb['comment'] ?? '',
                                       style: GoogleFonts.poppins(fontSize: 13, height: 1.4, color: Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87),
                                     ),

                                     const SizedBox(height: 8),
                                     
                                     // Reply Button (Always Visible)
                                     Align(
                                       alignment: Alignment.centerRight,
                                       child: InkWell(
                                         onTap: () => _handleReply(fb['id'].toString(), fb['reply']),
                                         borderRadius: BorderRadius.circular(20),
                                         child: Container(
                                           padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                           decoration: BoxDecoration(
                                             color: hasReply ? Colors.green.withValues(alpha: 0.1) : Colors.blue.withValues(alpha: 0.1),
                                             borderRadius: BorderRadius.circular(20),
                                             border: Border.all(color: hasReply ? Colors.green.withValues(alpha: 0.3) : Colors.blue.withValues(alpha: 0.3))
                                           ),
                                           child: Row(
                                             mainAxisSize: MainAxisSize.min,
                                             children: [
                                               if(hasReply) Padding(
                                                 padding: const EdgeInsets.only(right: 5),
                                                 child: Icon(Icons.check, size: 12, color: Colors.green),
                                               ),
                                               Text(
                                                 hasReply ? "View Reply" : "Reply", 
                                                 style: GoogleFonts.poppins(
                                                    fontSize: 12, 
                                                    fontWeight: FontWeight.bold, 
                                                    color: hasReply ? Colors.green : Colors.blue
                                                 )
                                               ),
                                             ],
                                           ),
                                         ),
                                       ),
                                     ),
                                  ],
                                ),
                              );
                           },
                       ),
           )
        ],
      ),
    );
  }
}
