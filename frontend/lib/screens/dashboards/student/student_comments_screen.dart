import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api_constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'raise_issue_screen.dart';

class StudentCommentsScreen extends StatefulWidget {
  final Map<String, dynamic> userData; 
  const StudentCommentsScreen({super.key, required this.userData});

  @override
  _StudentCommentsScreenState createState() => _StudentCommentsScreenState();
}

class _StudentCommentsScreenState extends State<StudentCommentsScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  String? _selectedCategory;
  String? _selectedTarget;
  bool _isSubmitting = false;

  List<dynamic> _issues = [];
  bool _isLoadingIssues = true;

  final List<String> _categories = ['Attendance', 'Marks', 'Academic', 'Other'];
  final List<String> _targets = ['Faculty', 'HOD', 'Principal', 'Coordinator'];

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
      debugPrint("Error fetching issues: $e");
      setState(() => _isLoadingIssues = false);
    }
  }

  Future<void> _deleteIssue(String issueId) async {
    final userId = widget.userData['id'];
    if (userId == null) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text("Delete Issue?", style: GoogleFonts.poppins()),
        content: Text("Are you sure you want to delete this issue?", style: GoogleFonts.poppins()),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      )
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse('${ApiConstants.studentDeleteIssue}/$issueId?userId=$userId')
      );
      if (response.statusCode == 200) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Issue deleted")));
           _fetchIssues();
        }
      } else {
        throw Exception("Failed to delete issue");
      }
    } catch (e) {
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not delete issue")));
      }
    }
  }

  void _showEditDialog(Map<String, dynamic> issue) {
    if (issue['status'] != 'PENDING' && issue['status'] != 'OPEN') {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Only pending issues can be edited.")));
        return;
    }

    final editTitleController = TextEditingController(text: issue['subject']);
    final editDescController = TextEditingController(text: issue['description']);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit Issue", style: GoogleFonts.poppins()),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: editTitleController,
                decoration: const InputDecoration(labelText: "Subject"),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: editDescController,
                decoration: const InputDecoration(labelText: "Description"),
                maxLines: 3,
              ),
            ]
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            TextButton(
              onPressed: () async {
                Navigator.pop(context);
                final userId = widget.userData['id'];
                if (userId == null) return;
                
                try {
                  final response = await http.put(
                    Uri.parse('${ApiConstants.studentUpdateIssue}/${issue['id']}'),
                    headers: {'Content-Type': 'application/json'},
                    body: json.encode({
                      'userId': userId,
                      'subject': editTitleController.text,
                      'description': editDescController.text,
                      'category': issue['category'],
                      'targetRole': issue['targetRole'],
                    })
                  );

                  if (response.statusCode == 200) {
                     if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Issue updated successfully")));
                        _fetchIssues();
                     }
                  } else {
                     throw Exception("Failed to update");
                  }
                } catch (e) {
                   if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Could not update issue")));
                   }
                }
              }, 
              child: const Text("Save")
            ),
          ],
        );
      }
    );
  }

  Future<void> _submitIssue(BuildContext modalContext, StateSetter setModalState) async {
    if (!_formKey.currentState!.validate()) return;
    
    final userId = widget.userData['id'];
    if (userId == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User ID not found")));
      return;
    }

    setModalState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.studentSubmitIssue),
        body: json.encode({
          'userId': userId,
          'subject': _titleController.text, // Title maps to subject
          'description': _descriptionController.text, 
          'category': _selectedCategory,
          'targetRole': _selectedTarget,
        }),
        headers: {'Content-Type': 'application/json'},
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(modalContext); // Close modal
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text("Issue reported successfully!", style: GoogleFonts.poppins()),
              backgroundColor: Colors.green,
              behavior: SnackBarBehavior.floating,
            )
          );
          
          _titleController.clear();
          _descriptionController.clear();
          _selectedCategory = null;
          _selectedTarget = null;
          
          setState(() {
            _isLoadingIssues = true;
          });
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
      if (mounted) setModalState(() => _isSubmitting = false);
    }
  }

  void _navigateToRaiseIssue() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => RaiseIssueScreen(userData: widget.userData),
      ),
    );
    
    // If the issue was raised successfully, it returns true to trigger a refresh
    if (result == true) {
      setState(() {
        _isLoadingIssues = true;
      });
      _fetchIssues();
    }
  }

  Widget _buildStatusChip(String status) {
    Color color;
    String label;
    if (status.toUpperCase() == 'PENDING' || status.toUpperCase() == 'OPEN') {
      color = Colors.orange; // Yellow/Orange
      label = "Open";
    } else if (status.toUpperCase() == 'IN_PROGRESS') {
      color = Colors.blue;
      label = "In Progress";
    } else if (status.toUpperCase() == 'RESOLVED' || status.toUpperCase() == 'ACCEPTED') {
      color = Colors.green;
      label = "Resolved";
    } else {
      color = Colors.grey;
      label = status;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.5))
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
           Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
           const SizedBox(width: 6),
           Text(label, style: GoogleFonts.poppins(color: color, fontSize: 12, fontWeight: FontWeight.bold)),
        ]
      )
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final theme = Theme.of(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? AppTheme.darkBodyGradient : AppTheme.lightBodyGradient;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("My Issues", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.add, color: theme.primaryColor, size: 28),
            onPressed: _navigateToRaiseIssue,
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
            child: _isLoadingIssues
                ? const Center(child: CircularProgressIndicator())
                : _issues.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.mark_email_unread_outlined, size: 64, color: subTextColor.withValues(alpha: 0.5)),
                            const SizedBox(height: 16),
                            Text("No issues raised yet", style: GoogleFonts.poppins(fontSize: 16, color: subTextColor, fontWeight: FontWeight.w500)),
                          ],
                        ),
                      )
                    : ListView.builder(
                        itemCount: _issues.length,
                        physics: const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          final issue = _issues[index];
                          final status = issue['status'] ?? 'PENDING';
                          final date = DateTime.parse(issue['createdAt']);
                          final formattedDate = DateFormat('dd MMM yyyy').format(date.toLocal());

                          return Container(
                            margin: const EdgeInsets.only(bottom: 16),
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: cardColor,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05)),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                )
                              ]
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text("📌 ", style: TextStyle(fontSize: 16)),
                                    Expanded(
                                      child: Text(
                                        issue['subject'] ?? 'No Title',
                                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: textColor),
                                      ),
                                    ),
                                    if (status.toUpperCase() == 'PENDING' || status.toUpperCase() == 'OPEN') ...[
                                       IconButton(
                                         icon: const Icon(Icons.edit, size: 20, color: Colors.blue),
                                         padding: EdgeInsets.zero,
                                         constraints: const BoxConstraints(),
                                         onPressed: () => _showEditDialog(issue),
                                       ),
                                       const SizedBox(width: 10),
                                       IconButton(
                                         icon: const Icon(Icons.delete, size: 20, color: Colors.red),
                                         padding: EdgeInsets.zero,
                                         constraints: const BoxConstraints(),
                                         onPressed: () => _deleteIssue(issue['id'].toString()),
                                       ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  "Category: ${issue['category'] ?? 'Other'}", 
                                  style: GoogleFonts.poppins(color: subTextColor, fontSize: 13, fontWeight: FontWeight.w500)
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  "Target: ${issue['targetRole'] ?? 'Faculty'}", 
                                  style: GoogleFonts.poppins(color: subTextColor, fontSize: 13, fontWeight: FontWeight.w500)
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildStatusChip(status),
                                    Text(
                                      "Date: $formattedDate", 
                                      style: GoogleFonts.poppins(color: subTextColor, fontSize: 13)
                                    ),
                                  ],
                                ),
                                // Show description and response if available
                                if (issue['description'] != null && issue['description'].toString().isNotEmpty) ...[
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Text(
                                    issue['description'],
                                    style: GoogleFonts.poppins(color: textColor.withValues(alpha: 0.8), fontSize: 13),
                                  )
                                ],
                                if (issue['response'] != null) ...[
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
                                          Text("Response: ${issue['response']}", style: GoogleFonts.poppins(color: textColor, fontSize: 13, fontStyle: FontStyle.italic)),
                                          if(issue['responderName'] != null) ...[
                                            const SizedBox(height: 4),
                                            Text("By: ${issue['responderName']}", style: GoogleFonts.poppins(color: subTextColor, fontSize: 12)),
                                          ]
                                        ],
                                      ),
                                    )
                                ]
                              ],
                            ),
                          );
                        },
                      ),
          ),
        ),
      ),
    );
  }
}

