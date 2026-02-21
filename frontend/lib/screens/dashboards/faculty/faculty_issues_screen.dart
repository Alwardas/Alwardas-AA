import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api_constants.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../student/raise_issue_screen.dart';

class FacultyIssuesScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const FacultyIssuesScreen({super.key, required this.userData});

  @override
  _FacultyIssuesScreenState createState() => _FacultyIssuesScreenState();
}

class _FacultyIssuesScreenState extends State<FacultyIssuesScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _assignedIssues = [];
  List<dynamic> _myRaisedIssues = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchIssues();
  }

  Future<void> _fetchIssues() async {
    final userId = widget.userData['id'];
    if (userId == null) return;

    if (mounted) setState(() => _isLoading = true);
    try {
      final assignedRes = await http.get(Uri.parse('${ApiConstants.facultyGetIssues}?facultyId=$userId'));
      final raisedRes = await http.get(Uri.parse('${ApiConstants.studentGetIssues}?userId=$userId'));

      if (assignedRes.statusCode == 200 && raisedRes.statusCode == 200 && mounted) {
        setState(() {
          _assignedIssues = json.decode(assignedRes.body);
          _myRaisedIssues = json.decode(raisedRes.body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching faculty issues: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resolveIssue(String issueId, String response, String status) async {
    final userId = widget.userData['id'];
    if (userId == null) return;

    try {
      final res = await http.post(
        Uri.parse(ApiConstants.facultyResolveIssue(issueId)),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'facultyId': userId,
          'response': response,
          'status': status,
        }),
      );

      if (res.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Issue updated successfully")));
          _fetchIssues();
        }
      } else {
        throw Exception("Failed to update issue");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to update issue")));
      }
    }
  }

  void _showResolveDialog(Map<String, dynamic> issue) {
    final responseController = TextEditingController();
    String selectedStatus = 'RESOLVED';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => AlertDialog(
          title: Text("Resolve Issue", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Issue: ${issue['subject']}", style: GoogleFonts.poppins(fontSize: 14)),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                value: selectedStatus,
                decoration: InputDecoration(labelText: "Status", border: OutlineInputBorder(borderRadius: BorderRadius.circular(12))),
                items: ['RESOLVED', 'IN_PROGRESS', 'CLOSED'].map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (v) => setModalState(() => selectedStatus = v!),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: responseController,
                maxLines: 3,
                decoration: InputDecoration(
                  labelText: "Your Response",
                  alignLabelWithHint: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _resolveIssue(issue['id'], responseController.text, selectedStatus);
              },
              child: const Text("Submit"),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? AppTheme.darkBodyGradient : AppTheme.lightBodyGradient;
    final textColor = isDark ? Colors.white : Colors.black87;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Issues Management", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        bottom: TabBar(
          controller: _tabController,
          labelColor: themeProvider.isDarkMode ? Colors.white : Colors.blue,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Colors.blue,
          tabs: const [
            Tab(text: "Assigned to Me"),
            Tab(text: "Raised by Me"),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topCenter, end: Alignment.bottomCenter)),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : TabBarView(
                  controller: _tabController,
                  children: [
                    _buildIssueList(_assignedIssues, true, cardColor, textColor, isDark),
                    _buildIssueList(_myRaisedIssues, false, cardColor, textColor, isDark),
                  ],
                ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => RaiseIssueScreen(userData: widget.userData)),
          );
          if (res == true) _fetchIssues();
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _buildIssueList(List<dynamic> issues, bool isAssigned, Color cardColor, Color textColor, bool isDark) {
    if (issues.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.assignment_turned_in_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text("No issues found", style: GoogleFonts.poppins(color: Colors.grey)),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: issues.length,
      itemBuilder: (context, index) {
        final issue = issues[index];
        final status = issue['status'] ?? 'PENDING';
        final isResolved = status == 'RESOLVED' || status == 'CLOSED';

        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text(issue['subject'] ?? 'No Subject', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: textColor))),
                  _buildStatusChip(status),
                ],
              ),
              const SizedBox(height: 8),
              Text(issue['description'] ?? '', style: GoogleFonts.poppins(fontSize: 13, color: textColor.withOpacity(0.7))),
              const SizedBox(height: 12),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                   Text(
                     "Date: ${DateFormat('dd MMM yyyy').format(DateTime.parse(issue['createdAt']).toLocal())}",
                     style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
                   ),
                   if (isAssigned && !isResolved) 
                      ElevatedButton(
                        onPressed: () => _showResolveDialog(issue),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                        ),
                        child: Text("Respond", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                ],
              ),
              if (issue['response'] != null) ...[
                const Divider(height: 24),
                Container(
                  padding: const EdgeInsets.all(12),
                  width: double.infinity,
                  decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.grey[100], borderRadius: BorderRadius.circular(8)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text("Response:", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 12)),
                      const SizedBox(height: 4),
                      Text(issue['response'], style: GoogleFonts.poppins(fontSize: 12, fontStyle: FontStyle.italic)),
                      if (issue['responderName'] != null) ...[
                        const SizedBox(height: 4),
                        Text("- ${issue['responderName']}", style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                      ]
                    ],
                  ),
                )
              ]
            ],
          ),
        );
      },
    );
  }

  Widget _buildStatusChip(String status) {
    Color color;
    switch (status.toUpperCase()) {
      case 'PENDING':
      case 'OPEN':
        color = Colors.orange;
        break;
      case 'IN_PROGRESS':
        color = Colors.blue;
        break;
      case 'RESOLVED':
        color = Colors.green;
        break;
      default:
        color = Colors.grey;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(12), border: Border.all(color: color.withOpacity(0.5))),
      child: Text(status, style: GoogleFonts.poppins(color: color, fontSize: 10, fontWeight: FontWeight.bold)),
    );
  }
}
