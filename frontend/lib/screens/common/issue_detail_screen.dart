import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';

import '../../core/api_constants.dart';
import '../../core/models/issue_model.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_theme.dart';

class IssueDetailScreen extends StatefulWidget {
  final Issue issue;
  final Map<String, dynamic> userData;

  const IssueDetailScreen({super.key, required this.issue, required this.userData});

  @override
  _IssueDetailScreenState createState() => _IssueDetailScreenState();
}

class _IssueDetailScreenState extends State<IssueDetailScreen> {
  final _commentController = TextEditingController();
  List<IssueComment> _comments = [];
  bool _isLoadingComments = true;
  bool _isSubmittingComment = false;
  late Issue _currentIssue;

  @override
  void initState() {
    super.initState();
    _currentIssue = widget.issue;
    _fetchComments();
  }

  Future<void> _fetchComments() async {
    try {
      final response = await http.get(Uri.parse(ApiConstants.getIssueComments(_currentIssue.id)));
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _comments = data.map((json) => IssueComment.fromJson(json)).toList();
          _isLoadingComments = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching comments: $e");
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.isEmpty) return;

    setState(() => _isSubmittingComment = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.submitComment),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'issueId': _currentIssue.id,
          'comment': _commentController.text,
          'commentBy': widget.userData['id'],
        }),
      );

      if (response.statusCode == 200) {
        _commentController.clear();
        _fetchComments();
      }
    } catch (e) {
      debugPrint("Error submitting comment: $e");
    } finally {
      setState(() => _isSubmittingComment = false);
    }
  }

  Future<void> _updateStatus(String newStatus) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.updateIssueStatus(_currentIssue.id)),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': newStatus}),
      );

      if (response.statusCode == 200) {
        setState(() {
          _currentIssue = Issue(
            id: _currentIssue.id,
            title: _currentIssue.title,
            description: _currentIssue.description,
            category: _currentIssue.category,
            priority: _currentIssue.priority,
            status: newStatus,
            createdBy: _currentIssue.createdBy,
            userRole: _currentIssue.userRole,
            assignedTo: _currentIssue.assignedTo,
            createdDate: _currentIssue.createdDate,
            creatorName: _currentIssue.creatorName,
            assignedName: _currentIssue.assignedName,
          );
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Status updated to $newStatus"), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      debugPrint("Error updating status: $e");
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high': return Colors.red;
      case 'medium': return Colors.orange;
      case 'low': return Colors.green;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    // Check if user has admin privileges for this issue
    final role = widget.userData['role'];
    final isAdmin = role == 'HOD' || role == 'Principal' || role == 'Coordinator' || role == 'Faculty';

    return Scaffold(
      appBar: AppBar(
        title: Text("Issue Details", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w600)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      extendBodyBehindAppBar: true,
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? AppTheme.darkBodyGradient : AppTheme.lightBodyGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildIssueCard(cardColor, textColor, subTextColor, isAdmin),
                      const SizedBox(height: 24),
                      Text("Comments", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 12),
                      _buildCommentList(subTextColor, textColor, cardColor),
                    ],
                  ),
                ),
              ),
              _buildCommentInput(cardColor, textColor, subTextColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildIssueCard(Color cardColor, Color textColor, Color subTextColor, bool isAdmin) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getPriorityColor(_currentIssue.priority).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(_currentIssue.priority.toUpperCase(),
                  style: GoogleFonts.poppins(color: _getPriorityColor(_currentIssue.priority), fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              Text(DateFormat('dd MMM yyyy, hh:mm a').format(_currentIssue.createdDate),
                style: GoogleFonts.poppins(color: subTextColor, fontSize: 12)),
            ],
          ),
          const SizedBox(height: 16),
          Text(_currentIssue.title, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
          const SizedBox(height: 8),
          Text(_currentIssue.description, style: GoogleFonts.poppins(fontSize: 15, color: subTextColor, height: 1.5)),
          const Divider(height: 32),
          _buildInfoRow(Icons.person_outline, "Created By", _currentIssue.creatorName ?? "Unknown", subTextColor, textColor),
          _buildInfoRow(Icons.category_outlined, "Category", _currentIssue.category, subTextColor, textColor),
          _buildInfoRow(Icons.assignment_ind_outlined, "Assigned To", _currentIssue.assignedName ?? "Not Assigned", subTextColor, textColor),
          const SizedBox(height: 16),
          _buildStatusDropdown(isAdmin, textColor, subTextColor),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value, Color subTextColor, Color textColor) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 16, color: subTextColor),
          const SizedBox(width: 8),
          Text("$label: ", style: GoogleFonts.poppins(color: subTextColor, fontSize: 13)),
          Text(value, style: GoogleFonts.poppins(color: textColor, fontSize: 13, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  Widget _buildStatusDropdown(bool isAdmin, Color textColor, Color subTextColor) {
    final statusOptions = ['Open', 'In Progress', 'Resolved', 'Closed'];
    
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text("Status:", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold)),
        if (isAdmin)
          DropdownButton<String>(
            value: _currentIssue.status,
            underline: Container(),
            icon: Icon(Icons.arrow_drop_down, color: Theme.of(context).primaryColor),
            items: statusOptions.map((s) => DropdownMenuItem(value: s, child: Text(s, style: GoogleFonts.poppins(color: textColor, fontSize: 14)))).toList(),
            onChanged: (v) {
              if (v != null) _updateStatus(v);
            },
          )
        else
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.blue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(_currentIssue.status, style: GoogleFonts.poppins(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 13)),
          ),
      ],
    );
  }

  Widget _buildCommentList(Color subTextColor, Color textColor, Color cardColor) {
    if (_isLoadingComments) return const Center(child: CircularProgressIndicator());
    if (_comments.isEmpty) return Center(child: Text("No comments yet", style: GoogleFonts.poppins(color: subTextColor)));

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _comments.length,
      itemBuilder: (context, index) {
        final comment = _comments[index];
        final isMe = comment.commentBy == widget.userData['id'];

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: isMe ? Theme.of(context).primaryColor.withOpacity(0.1) : cardColor.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: isMe ? Theme.of(context).primaryColor.withOpacity(0.2) : Colors.black12),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(comment.userName ?? "User", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13, color: textColor)),
                  Text(DateFormat('hh:mm a').format(comment.commentDate), style: GoogleFonts.poppins(fontSize: 11, color: subTextColor)),
                ],
              ),
              const SizedBox(height: 4),
              Text(comment.comment, style: GoogleFonts.poppins(fontSize: 14, color: textColor)),
            ],
          ),
        );
      },
    );
  }

  Widget _buildCommentInput(Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + MediaQuery.of(context).viewPadding.bottom),
      decoration: BoxDecoration(
        color: cardColor,
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, -2))],
      ),
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _commentController,
              style: GoogleFonts.poppins(color: textColor),
              decoration: InputDecoration(
                hintText: "Add a comment...",
                hintStyle: GoogleFonts.poppins(color: subTextColor),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(24), borderSide: BorderSide.none),
                fillColor: isDark ? Colors.white10 : Colors.black12.withOpacity(0.05),
                filled: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              ),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(
            onPressed: _isSubmittingComment ? null : _submitComment,
            icon: Icon(Icons.send, color: Theme.of(context).primaryColor),
          ),
        ],
      ),
    );
  }
}
