import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../core/api_config.dart';
import '../../../core/api_constants.dart';

class DesktopHodIssuesView extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DesktopHodIssuesView({super.key, required this.userData});

  @override
  State<DesktopHodIssuesView> createState() => _DesktopHodIssuesViewState();
}

class _DesktopHodIssuesViewState extends State<DesktopHodIssuesView> {
  List<dynamic> _issues = [];
  dynamic _selectedIssue;
  List<dynamic> _comments = [];
  bool _isLoading = true;
  bool _isLoadingComments = false;
  final TextEditingController _commentController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchIssues();
  }

  Future<void> _fetchIssues() async {
    setState(() => _isLoading = true);
    final userId = widget.userData['id'];
    final role = widget.userData['role'];
    final branch = widget.userData['branch'];

    try {
      final String uri = '${ApiConstants.baseUrl}/api/issues?userId=$userId&role=$role' +
          (branch != null ? '&branch=${Uri.encodeComponent(branch)}' : '');
      final response = await ApiConfig.get(uri);
      
      if (response.success && response.data != null) {
        setState(() {
          _issues = response.data;
          _isLoading = false;
        });
        if (_issues.isNotEmpty) {
          _selectIssue(_issues[0]);
        } else {
          setState(() {
            _selectedIssue = null;
            _comments = [];
          });
        }
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching issues: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _selectIssue(dynamic issue) async {
    setState(() {
      _selectedIssue = issue;
      _comments = [];
      _isLoadingComments = true;
    });

    final issueId = issue['id'] ?? issue['issueId'];
    try {
      final uri = '${ApiConstants.baseUrl}/api/issues/$issueId/comments';
      final response = await ApiConfig.get(uri);
      if (response.success && response.data != null) {
        setState(() {
          _comments = response.data;
        });
      }
    } catch (e) {
      debugPrint("Error fetching comments: $e");
    } finally {
      setState(() => _isLoadingComments = false);
    }
  }

  Future<void> _submitComment() async {
    if (_commentController.text.trim().isEmpty || _selectedIssue == null) return;
    final issueId = _selectedIssue['id'] ?? _selectedIssue['issueId'];

    try {
      final response = await ApiConfig.post(
        '${ApiConstants.baseUrl}/api/issues/comments/submit',
        body: {
          'issueId': issueId,
          'commentText': _commentController.text.trim(),
          'authorId': widget.userData['id'],
          'authorRole': widget.userData['role'],
        },
      );

      if (response.success) {
        _commentController.clear();
        _selectIssue(_selectedIssue);
      } else {
        _showSnackBar("Failed to post comment: ${response.message}");
      }
    } catch (e) {
      _showSnackBar("Error posting comment");
    }
  }

  Future<void> _updateStatus(String status) async {
    if (_selectedIssue == null) return;
    final issueId = _selectedIssue['id'] ?? _selectedIssue['issueId'];

    try {
      final response = await ApiConfig.post(
        '${ApiConstants.baseUrl}/api/issues/$issueId/status',
        body: {'status': status},
      );

      if (response.success) {
        _showSnackBar("Status updated to $status");
        _fetchIssues();
      } else {
        _showSnackBar("Failed to update status");
      }
    } catch (e) {
      _showSnackBar("Error updating status");
    }
  }

  void _showSnackBar(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  Color _getPriorityColor(String priority) {
    switch (priority.toLowerCase()) {
      case 'high':
        return Colors.redAccent;
      case 'medium':
        return Colors.orangeAccent;
      case 'low':
        return Colors.greenAccent;
      default:
        return Colors.grey;
    }
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'open':
        return Colors.blueAccent;
      case 'in progress':
        return Colors.amberAccent;
      case 'resolved':
        return Colors.greenAccent;
      case 'closed':
        return Colors.grey;
      default:
        return Colors.blueAccent;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Department Issues Help Desk',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Monitor, assign, comment, and resolve issues reported by students and faculty in your branch',
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _fetchIssues,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text('Refresh', style: GoogleFonts.poppins(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF1E293B),
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main split layout
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : _issues.isEmpty
                    ? _buildEmptyState()
                    : Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Left Pane: Issues List
                          Expanded(
                            flex: 2,
                            child: Container(
                              decoration: BoxDecoration(
                                color: const Color(0xFF1E293B),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: ListView.separated(
                                padding: const EdgeInsets.all(20),
                                itemCount: _issues.length,
                                separatorBuilder: (context, index) => const Divider(color: Colors.white10, height: 1),
                                itemBuilder: (context, index) {
                                  final issue = _issues[index];
                                  final isSelected = _selectedIssue != null &&
                                      (_selectedIssue['id'] ?? _selectedIssue['issueId']) ==
                                          (issue['id'] ?? issue['issueId']);
                                  final priority = issue['priority'] ?? 'Medium';
                                  final status = issue['status'] ?? 'Open';
                                  final dateStr = issue['createdDate'] != null
                                      ? DateFormat('dd MMM yyyy').format(DateTime.parse(issue['createdDate']))
                                      : 'Recent';

                                  return InkWell(
                                    onTap: () => _selectIssue(issue),
                                    borderRadius: BorderRadius.circular(10),
                                    child: Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: isSelected ? Colors.white.withOpacity(0.05) : Colors.transparent,
                                        borderRadius: BorderRadius.circular(10),
                                        border: Border.all(
                                          color: isSelected ? Colors.blueAccent.withOpacity(0.3) : Colors.transparent,
                                        ),
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
                                                  color: _getPriorityColor(priority).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(6),
                                                ),
                                                child: Text(
                                                  priority.toUpperCase(),
                                                  style: TextStyle(
                                                    color: _getPriorityColor(priority),
                                                    fontSize: 9,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                              Text(
                                                dateStr,
                                                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 10),
                                          Text(
                                            issue['title'] ?? '',
                                            style: GoogleFonts.poppins(
                                                color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            issue['description'] ?? '',
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                            style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
                                          ),
                                          const SizedBox(height: 12),
                                          Row(
                                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                            children: [
                                              Text(
                                                issue['category'] ?? 'General',
                                                style: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 11),
                                              ),
                                              Container(
                                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: _getStatusColor(status).withOpacity(0.1),
                                                  borderRadius: BorderRadius.circular(12),
                                                ),
                                                child: Text(
                                                  status,
                                                  style: TextStyle(
                                                    color: _getStatusColor(status),
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),
                          ),
                          const SizedBox(width: 20),

                          // Right Pane: Selected Issue Details
                          Expanded(
                            flex: 3,
                            child: _selectedIssue == null
                                ? const Center(child: Text("Select an issue to view details", style: TextStyle(color: Colors.white38)))
                                : _buildDetailsPane(),
                          ),
                        ],
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailsPane() {
    final status = _selectedIssue['status'] ?? 'Open';
    final priority = _selectedIssue['priority'] ?? 'Medium';
    final dateStr = _selectedIssue['createdDate'] != null
        ? DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.parse(_selectedIssue['createdDate']))
        : 'N/A';

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Upper details
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  _selectedIssue['title'] ?? '',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
              PopupMenuButton<String>(
                color: const Color(0xFF1E293B),
                icon: const Icon(Icons.more_vert, color: Colors.white60),
                onSelected: _updateStatus,
                itemBuilder: (context) => [
                  const PopupMenuItem(value: 'Open', child: Text('Mark as Open', style: TextStyle(color: Colors.white))),
                  const PopupMenuItem(value: 'In Progress', child: Text('Mark as In Progress', style: TextStyle(color: Colors.white))),
                  const PopupMenuItem(value: 'Resolved', child: Text('Mark as Resolved', style: TextStyle(color: Colors.greenAccent))),
                  const PopupMenuItem(value: 'Closed', child: Text('Mark as Closed', style: TextStyle(color: Colors.white38))),
                ],
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                "Category: ${_selectedIssue['category'] ?? 'General'} | Priority: $priority | Status: $status",
                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),

          // Description
          Text(
            "Description",
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedIssue['description'] ?? '',
            style: GoogleFonts.poppins(color: Colors.white60, fontSize: 13, height: 1.4),
          ),
          const Divider(color: Colors.white10, height: 24),

          // Comments List Section
          Text(
            "Discussion / Comments Thread",
            style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 12),
          Expanded(
            child: _isLoadingComments
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : _comments.isEmpty
                    ? Center(
                        child: Text(
                          "No comments added yet. Start the conversation below.",
                          style: GoogleFonts.poppins(color: Colors.white24, fontSize: 12),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _comments.length,
                        itemBuilder: (context, index) {
                          final c = _comments[index];
                          final role = c['authorRole'] ?? 'Staff';
                          final text = c['commentText'] ?? '';
                          final cTime = c['createdAt'] != null
                              ? DateFormat('hh:mm a, dd MMM').format(DateTime.parse(c['createdAt']))
                              : 'Recent';

                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0F172A),
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(color: Colors.white10),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      "$role Member",
                                      style: GoogleFonts.poppins(
                                          color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      cTime,
                                      style: GoogleFonts.poppins(color: Colors.white24, fontSize: 10),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  text,
                                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
          ),
          const SizedBox(height: 16),

          // Comment Input
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _commentController,
                  style: const TextStyle(color: Colors.white, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: "Add official response or comment...",
                    hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                    filled: true,
                    fillColor: const Color(0xFF0F172A),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              IconButton(
                onPressed: _submitComment,
                icon: const Icon(Icons.send, color: Colors.blueAccent),
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.report_problem_outlined, size: 64, color: Colors.white24),
          const SizedBox(height: 20),
          Text(
            "No issues reported in your department.",
            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 16),
          ),
        ],
      ),
    );
  }
}
