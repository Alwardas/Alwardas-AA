
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/providers/theme_provider.dart';

class FacultyReviewsScreen extends StatefulWidget {
  const FacultyReviewsScreen({super.key});

  @override
  State<FacultyReviewsScreen> createState() => _FacultyReviewsScreenState();
}

class _FacultyReviewsScreenState extends State<FacultyReviewsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoading = true;
  List<dynamic> _feedbacks = [];
  String? _facultyId;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _initializeData();
  }

  Future<void> _initializeData() async {
    final user = await AuthService.getUserSession();
    if (user != null) {
      _facultyId = user['id'];
      _fetchFeedbacks();
    }
  }

  Future<void> _fetchFeedbacks() async {
    if (_facultyId == null) return;
    setState(() => _isLoading = true);

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/faculty/feedbacks?facultyId=$_facultyId'),
      );

      if (response.statusCode == 200) {
        setState(() {
          _feedbacks = json.decode(response.body);
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching feedback: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      backgroundColor: isDark ? const Color(0xFF0F172A) : Colors.grey[50],
      appBar: AppBar(
        title: Text("Feedbacks received", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        bottom: TabBar(
          controller: _tabController,
          labelColor: const Color(0xFF2563EB),
          unselectedLabelColor: subTextColor,
          indicatorColor: const Color(0xFF2563EB),
          labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
          tabs: const [
            Tab(text: "View Feedbacks"),
            Tab(text: "Replied by us"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildFeedbackList(isDark, textColor, subTextColor, replied: false),
          _buildFeedbackList(isDark, textColor, subTextColor, replied: true),
        ],
      ),
    );
  }

  Widget _buildFeedbackList(bool isDark, Color textColor, Color subTextColor, {required bool replied}) {
    final filtered = _feedbacks.where((f) {
      final hasReply = f['reply'] != null && f['reply'].toString().isNotEmpty;
      return replied ? hasReply : !hasReply;
    }).toList();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(replied ? Icons.reply_all_outlined : Icons.rate_review_outlined, size: 60, color: Colors.grey[400]),
            const SizedBox(height: 16),
            Text(
              replied ? "No replied feedbacks" : "No new feedbacks",
              style: GoogleFonts.poppins(fontSize: 16, color: subTextColor),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: filtered.length,
      itemBuilder: (context, index) {
        final f = filtered[index];
        return _buildFeedbackCard(f, isDark, textColor, subTextColor, replied);
      },
    );
  }

  Widget _buildFeedbackCard(dynamic f, bool isDark, Color textColor, Color subTextColor, bool replied) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f['subjectName'] ?? 'No Subject',
                      style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 15),
                    ),
                    Text(
                      f['topic'] ?? 'N/A',
                      style: GoogleFonts.poppins(color: subTextColor, fontSize: 13),
                    ),
                  ],
                ),
              ),
              _buildRatingBadge(f['rating'] ?? 0),
            ],
          ),
          const Divider(height: 24),
          Text(
            f['comment'] ?? 'No comment provided',
            style: GoogleFonts.poppins(color: textColor, fontSize: 14),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                f['createdAt'] != null ? DateFormat('MMM dd, yyyy').format(DateTime.parse(f['createdAt'])) : 'Unknown Date',
                style: GoogleFonts.poppins(color: subTextColor, fontSize: 11),
              ),
              if (!replied)
                TextButton.icon(
                  onPressed: () => _showReplyDialog(f),
                  icon: const Icon(Icons.reply, size: 16),
                  label: const Text("Reply", style: TextStyle(fontSize: 12)),
                  style: TextButton.styleFrom(visualDensity: VisualDensity.compact),
                ),
            ],
          ),
          if (replied && f['reply'] != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isDark ? Colors.blueAccent.withValues(alpha: 0.1) : Colors.blue[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.reply, size: 14, color: Colors.blueAccent),
                      const SizedBox(width: 8),
                      Text("Your Reply:", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12, color: Colors.blueAccent)),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(f['reply'], style: GoogleFonts.poppins(fontSize: 13, color: textColor)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildRatingBadge(int rating) {
    Color color;
    if (rating >= 4) color = Colors.green;
    else if (rating >= 3) color = Colors.orange;
    else color = Colors.red;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.star, size: 14, color: color),
          const SizedBox(width: 4),
          Text(rating.toString(), style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: color, fontSize: 12)),
        ],
      ),
    );
  }

  void _showReplyDialog(dynamic f) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Reply to Feedback", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(hintText: "Enter your reply...", border: OutlineInputBorder()),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                final success = await _submitReply(f['id'], controller.text);
                if (success) {
                  Navigator.pop(ctx);
                  _fetchFeedbacks();
                }
              }
            },
            child: const Text("Send"),
          ),
        ],
      ),
    );
  }

  Future<bool> _submitReply(String feedbackId, String reply) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/faculty/feedback/reply'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'feedbackId': feedbackId,
          'facultyId': _facultyId,
          'reply': reply,
        }),
      );
      return response.statusCode == 200;
    } catch (e) {
      return false;
    }
  }
}
