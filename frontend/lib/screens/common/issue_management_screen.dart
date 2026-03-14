import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../../core/providers/theme_provider.dart';
import '../../core/api_constants.dart';
import '../../core/models/issue_model.dart';
import '../../theme/theme_constants.dart';
import '../../core/theme/app_theme.dart';
import 'issue_detail_screen.dart';

class IssueManagementScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const IssueManagementScreen({super.key, required this.userData});

  @override
  _IssueManagementScreenState createState() => _IssueManagementScreenState();
}

class _IssueManagementScreenState extends State<IssueManagementScreen> {
  List<Issue> _issues = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchIssues();
  }

  Future<void> _fetchIssues() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final userId = widget.userData['id'];
      final role = widget.userData['role'];
      final branch = widget.userData['branch'];
      
      final queryParameters = {
        'userId': userId.toString(),
        'role': role.toString(),
      };
      if (branch != null) {
        queryParameters['branch'] = branch.toString();
      }

      final uri = Uri.parse(ApiConstants.getIssues).replace(queryParameters: queryParameters);
      
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _issues = data.map((json) => Issue.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        String errorMessage = "Failed to load issues: ${response.statusCode}";
        try {
          final body = json.decode(response.body);
          if (body['error'] != null) errorMessage = body['error'];
        } catch (_) {}
        setState(() {
          _error = errorMessage;
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error: $e";
        _isLoading = false;
      });
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.red;
      case 'medium':
        return Colors.orange;
      case 'low':
        return Colors.green;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.blue;
      case 'in progress':
        return Colors.amber;
      case 'resolved':
        return Colors.green;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.blue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.grey[400]! : Colors.grey[600]!;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Issue Management", 
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: _fetchIssues,
          )
        ],
      ),
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
              _buildHeader(textColor, subTextColor),
              Expanded(
                child: _isLoading 
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                    ? Center(child: Text(_error!, style: GoogleFonts.poppins(color: Colors.red)))
                    : _issues.isEmpty
                      ? _buildEmptyState(subTextColor)
                      : _buildIssueList(cardColor, textColor, subTextColor),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showCreateIssueDialog(context),
        label: Text("Report Issue", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
        backgroundColor: Theme.of(context).primaryColor,
      ),
    );
  }

  Widget _buildHeader(Color textColor, Color subTextColor) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Central Help Desk", 
                  style: GoogleFonts.poppins(fontSize: 24, fontWeight: FontWeight.bold, color: textColor)),
                Text("Track and manage all your issues in one place", 
                  style: GoogleFonts.poppins(fontSize: 14, color: subTextColor)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(Color subTextColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.assignment_turned_in_outlined, size: 80, color: subTextColor.withOpacity(0.5)),
          const SizedBox(height: 16),
          Text("No issues reported yet", 
            style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w500, color: subTextColor)),
          const SizedBox(height: 8),
          Text("Tap the + button to report a new issue", 
            style: GoogleFonts.poppins(fontSize: 14, color: subTextColor.withOpacity(0.7))),
        ],
      ),
    );
  }

  Widget _buildIssueList(Color cardColor, Color textColor, Color subTextColor) {
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 80),
      itemCount: _issues.length,
      itemBuilder: (context, index) {
        final issue = _issues[index];
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () async {
              final result = await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => IssueDetailScreen(issue: issue, userData: widget.userData)),
              );
              if (result == true) _fetchIssues();
            },
            borderRadius: BorderRadius.circular(16),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, 4),
                  )
                ],
                border: Border.all(color: Colors.black.withOpacity(0.05)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getPriorityColor(issue.priority).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(issue.priority.toUpperCase(),
                          style: GoogleFonts.poppins(
                            color: _getPriorityColor(issue.priority),
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      Text(DateFormat('dd MMM yyyy').format(issue.createdDate),
                        style: GoogleFonts.poppins(color: subTextColor, fontSize: 12)),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Text(issue.title,
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                  const SizedBox(height: 4),
                  Text(issue.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.poppins(color: subTextColor, fontSize: 13)),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Row(
                        children: [
                          Icon(Icons.category_outlined, size: 14, color: subTextColor),
                          const SizedBox(width: 4),
                          Text(issue.category, style: GoogleFonts.poppins(color: subTextColor, fontSize: 12)),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: _getStatusColor(issue.status).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: _getStatusColor(issue.status).withOpacity(0.3)),
                        ),
                        child: Text(issue.status,
                          style: GoogleFonts.poppins(
                            color: _getStatusColor(issue.status),
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showCreateIssueDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => CreateIssueSheet(userData: widget.userData, onSubmitted: _fetchIssues),
    );
  }
}

class CreateIssueSheet extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onSubmitted;

  const CreateIssueSheet({super.key, required this.userData, required this.onSubmitted});

  @override
  _CreateIssueSheetState createState() => _CreateIssueSheetState();
}

class _CreateIssueSheetState extends State<CreateIssueSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  
  String _category = 'General';
  String _priority = 'Medium';
  bool _isSubmitting = false;

  final List<String> _categories = ['Academic', 'Attendance', 'Technical', 'Timetable', 'Facilities', 'General'];
  final List<String> _priorities = ['Low', 'Medium', 'High'];

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.submitIssue),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'title': _titleController.text,
          'description': _descriptionController.text,
          'category': _category,
          'priority': _priority,
          'createdBy': widget.userData['id'],
          'userRole': widget.userData['role'],
        }),
      );

      if (response.statusCode == 200) {
        widget.onSubmitted();
        Navigator.pop(context);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Issue reported successfully"), backgroundColor: Colors.green),
        );
      } else {
        String errorMessage = "Failed to report issue: ${response.statusCode}";
        try {
          final body = json.decode(response.body);
          if (body['error'] != null) errorMessage = body['error'];
        } catch (_) {}
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;

    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text("Report New Issue", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
              const SizedBox(height: 20),
              
              TextFormField(
                controller: _titleController,
                style: GoogleFonts.poppins(color: textColor),
                decoration: InputDecoration(
                  labelText: "Issue Title",
                  hintText: "e.g. Attendance not updated",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v!.isEmpty ? "Title is required" : null,
              ),
              const SizedBox(height: 16),
              
              TextFormField(
                controller: _descriptionController,
                maxLines: 4,
                style: GoogleFonts.poppins(color: textColor),
                decoration: InputDecoration(
                  labelText: "Description",
                  alignLabelWithHint: true,
                  hintText: "Describe the issue in detail...",
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                validator: (v) => v!.isEmpty ? "Description is required" : null,
              ),
              const SizedBox(height: 16),
              
              Row(
                children: [
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _category,
                      decoration: InputDecoration(
                        labelText: "Category",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c, style: GoogleFonts.poppins(fontSize: 13)))).toList(),
                      onChanged: (v) => setState(() => _category = v!),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _priority,
                      decoration: InputDecoration(
                        labelText: "Priority",
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      items: _priorities.map((p) => DropdownMenuItem(value: p, child: Text(p, style: GoogleFonts.poppins(fontSize: 13)))).toList(),
                      onChanged: (v) => setState(() => _priority = v!),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 30),
              
              SizedBox(
                width: double.infinity,
                height: 55,
                child: ElevatedButton(
                  onPressed: _isSubmitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: _isSubmitting 
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text("Submit Issue", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                ),
              ),
              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
