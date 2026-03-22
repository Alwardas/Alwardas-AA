import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../core/api_constants.dart';
import '../core/models/parent_request_model.dart';
import 'package:intl/intl.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:path/path.dart' as p;

class ParentRequestsViewer extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String requestFrom; // 'Parent' or 'Student'
  const ParentRequestsViewer({super.key, required this.userData, required this.requestFrom});

  @override
  State<ParentRequestsViewer> createState() => _ParentRequestsViewerState();
}

class _ParentRequestsViewerState extends State<ParentRequestsViewer> {
  List<ParentRequest> _requests = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final role = widget.userData['role'];
      final branch = widget.userData['branch'];
      
      final Map<String, String> queryParameters = {
        'role': role.toString(),
        'userId': widget.userData['id']?.toString() ?? widget.userData['userId']?.toString() ?? '',
      };
      if (branch != null) {
        queryParameters['branch'] = branch.toString();
      }

      final uri = Uri.parse(ApiConstants.getParentRequests).replace(queryParameters: queryParameters);
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _requests = data.map((json) => ParentRequest.fromJson(json))
              .where((r) => r.parentRole == widget.requestFrom)
              .toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          if (mounted) {
            _error = "Failed to load requests: ${response.statusCode}";
            _isLoading = false;
          }
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = "Error: $e";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _updateStatus(String requestId, String status) async {
    try {
      final response = await http.post(
        Uri.parse(ApiConstants.updateParentRequestStatus(requestId)),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': status}),
      );

      if (response.statusCode == 200) {
        _fetchRequests();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Request marked as $status"), backgroundColor: status == 'Approved' ? Colors.green : Colors.red),
          );
        }
      }
    } catch (e) {
       debugPrint("Update status error: $e");
    }
  }

  Future<void> _deleteRequest(String requestId) async {
    final bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Delete Request"),
        content: const Text("Are you sure you want to delete this request permanently?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.delete(
        Uri.parse("${ApiConstants.baseUrl}/api/parent/requests/$requestId"),
      );

      if (response.statusCode == 200) {
        _fetchRequests();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Request deleted successfully"), backgroundColor: Colors.red),
          );
        }
      } else {
         debugPrint("Delete failed: ${response.statusCode}");
      }
    } catch (e) {
       debugPrint("Delete request error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: GoogleFonts.poppins(color: Colors.red)));
    if (_requests.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: Colors.grey.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text("No ${widget.requestFrom} requests", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _fetchRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final req = _requests[index];
          bool isPending = req.status == 'Pending';
          
          return GestureDetector(
            onTap: () => Navigator.push(
              context, 
              MaterialPageRoute(builder: (_) => RequestDetailsPage(request: req, userData: widget.userData))
            ),
            child: Container(
              margin: const EdgeInsets.only(bottom: 16),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          req.subject, 
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 17, color: textColor)
                        ),
                      ),
                      IconButton(
                        onPressed: () => _deleteRequest(req.id),
                        icon: const Icon(Icons.delete_outline, color: Colors.red, size: 20),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _buildDetailRow(Icons.person_outline, "From: ${widget.requestFrom == 'Parent' ? (req.parentName ?? 'Parent') : 'Student'}", isDark),
                  _buildDetailRow(Icons.school_outlined, "Student: ${req.studentName ?? 'N/A'}", isDark),
                  _buildDetailRow(Icons.badge_outlined, "Student ID: ${req.studentLoginId ?? 'N/A'}", isDark),
                  const SizedBox(height: 16),
                  if (isPending)
                  Row(
                    children: [
                      Expanded(
                        child: _buildActionButton("Reject", Colors.red, () => _updateStatus(req.id, 'Rejected')),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _buildActionButton("Approve", Colors.green, () => _updateStatus(req.id, 'Approved'), filled: true),
                      ),
                    ],
                  )
                  else
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    decoration: BoxDecoration(
                      color: (req.status == 'Approved' ? Colors.green : Colors.red).withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(req.status, style: GoogleFonts.poppins(color: req.status == 'Approved' ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 12)),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String text, bool isDark) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Icon(icon, size: 14, color: isDark ? Colors.grey[400] : Colors.grey[600]),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              text, 
              style: GoogleFonts.poppins(fontSize: 13, color: isDark ? Colors.grey[400] : Colors.grey[600])
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap, {bool filled = false}) {
    return SizedBox(
      height: 36,
      child: filled
          ? ElevatedButton(
              onPressed: onTap,
              style: ElevatedButton.styleFrom(
                backgroundColor: color,
                foregroundColor: Colors.white,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
            )
          : OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                foregroundColor: color,
                side: BorderSide(color: color),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
    );
  }
}

class RequestDetailsPage extends StatefulWidget {
  final ParentRequest request;
  final Map<String, dynamic> userData;
  const RequestDetailsPage({super.key, required this.request, required this.userData});

  @override
  State<RequestDetailsPage> createState() => _RequestDetailsPageState();
}

class _RequestDetailsPageState extends State<RequestDetailsPage> {
  late AudioPlayer _audioPlayer;
  bool _isPlaying = false;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (mounted) setState(() => _isPlaying = state == PlayerState.playing);
    });
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playVoiceNote(String base64Audio) async {
    try {
      if (_isPlaying) {
        await _audioPlayer.stop();
        return;
      }
      final bytes = base64Decode(base64Audio);
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'temp_voice_viewer_${DateTime.now().millisecondsSinceEpoch}.m4a'));
      await file.writeAsBytes(bytes);
      await _audioPlayer.play(DeviceFileSource(file.path));
    } catch (e) {
      debugPrint("Play voice note error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final req = widget.request;

    return Scaffold(
      appBar: AppBar(
        title: Text("Request Details", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.blue.withOpacity(0.05),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.blue.withOpacity(0.1)),
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
                          color: Theme.of(context).primaryColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(req.requestType, style: GoogleFonts.poppins(color: Theme.of(context).primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                      ),
                      Text(DateFormat('dd MMM yyyy, hh:mm a').format(req.createdAt), style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(req.subject, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, color: textColor)),
                  const Divider(height: 32),
                  _buildMetaItem("Requester", req.parentName ?? 'Unknown', Icons.person_outline),
                  _buildMetaItem("Student", req.studentName ?? 'N/A', Icons.school_outlined),
                  _buildMetaItem("Student ID", req.studentLoginId ?? 'N/A', Icons.badge_outlined),
                  _buildMetaItem("Duration", req.dateDuration, Icons.calendar_today_outlined),
                ],
              ),
            ),
            const SizedBox(height: 24),
            Text("Description", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05)),
              ),
              child: Text(
                req.description,
                style: GoogleFonts.poppins(color: textColor.withOpacity(0.8), fontSize: 15, height: 1.5),
              ),
            ),
            if (req.voiceNote != null) ...[
              const SizedBox(height: 24),
              Text("Voice Message", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
              const SizedBox(height: 12),
              InkWell(
                onTap: () => _playVoiceNote(req.voiceNote!),
                borderRadius: BorderRadius.circular(16),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(colors: [Colors.blue[700]!, Colors.blue[500]!]),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Icon(_isPlaying ? Icons.pause_circle_filled : Icons.play_circle_fill, color: Colors.white, size: 40),
                      const SizedBox(width: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(_isPlaying ? "Now Playing..." : "Listen to Voice Message", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
                          Text("Tap to play/pause", style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 40),
            if (req.status == 'Pending' && widget.userData['role'] != 'Parent')
            Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _updateStatus(req.id, 'Rejected');
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[50],
                      foregroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12), side: const BorderSide(color: Colors.red)),
                    ),
                    child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    onPressed: () {
                      _updateStatus(req.id, 'Approved');
                      Navigator.pop(context);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: const Text("Approve", style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _updateStatus(String requestId, String status) async {
    try {
      await http.post(
        Uri.parse(ApiConstants.updateParentRequestStatus(requestId)),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'status': status}),
      );
    } catch (e) {
      debugPrint("Update status error: $e");
    }
  }

  Widget _buildMetaItem(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.blue),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
              Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600)),
            ],
          ),
        ],
      ),
    );
  }
}
