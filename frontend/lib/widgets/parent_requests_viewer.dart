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
  const ParentRequestsViewer({super.key, required this.userData});

  @override
  State<ParentRequestsViewer> createState() => _ParentRequestsViewerState();
}

class _ParentRequestsViewerState extends State<ParentRequestsViewer> {
  List<ParentRequest> _requests = [];
  bool _isLoading = true;
  String? _error;
  late AudioPlayer _audioPlayer;

  @override
  void initState() {
    super.initState();
    _audioPlayer = AudioPlayer();
    _fetchRequests();
  }

  @override
  void dispose() {
    _audioPlayer.dispose();
    super.dispose();
  }

  Future<void> _playVoiceNote(String base64Audio) async {
    try {
      final bytes = base64Decode(base64Audio);
      final dir = await getTemporaryDirectory();
      final file = File(p.join(dir.path, 'temp_voice_viewer_${DateTime.now().millisecondsSinceEpoch}.m4a'));
      await file.writeAsBytes(bytes);
      await _audioPlayer.play(DeviceFileSource(file.path));
    } catch (e) {
      debugPrint("Play voice note error: $e");
    }
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
          _requests = data.map((json) => ParentRequest.fromJson(json)).toList();
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
      } else {
         if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Failed to update: ${response.statusCode}"), backgroundColor: Colors.red),
          );
         }
      }
    } catch (e) {
       if (mounted) {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
        );
       }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return Center(child: Text(_error!, style: GoogleFonts.poppins(color: Colors.red)));
    if (_requests.isEmpty) return Center(child: Text("No pending requests", style: GoogleFonts.poppins(color: Colors.grey)));

    return RefreshIndicator(
      onRefresh: _fetchRequests,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _requests.length,
        itemBuilder: (context, index) {
          final req = _requests[index];
          bool isPending = req.status == 'Pending';
          
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
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
                    Text(DateFormat('dd MMM').format(req.createdAt), style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                  ],
                ),
                const SizedBox(height: 12),
                Text("From: ${req.parentName ?? 'Parent'}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                Text("Student: ${req.studentName ?? 'Student'}", style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 12),
                Text(req.subject, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14, color: textColor)),
                Text(req.description, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
                const SizedBox(height: 8),
                Text("Duration: ${req.dateDuration}", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500, color: textColor)),
                if (req.voiceNote != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 15.0),
                    child: ElevatedButton.icon(
                      onPressed: () => _playVoiceNote(req.voiceNote!),
                      icon: const Icon(Icons.play_circle_fill, size: 20),
                      label: const Text("Listen to Voice Message"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blue[700],
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                const SizedBox(height: 20),
                if (isPending && widget.userData['role'] != 'Parent')
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _updateStatus(req.id, 'Rejected'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.red,
                          side: const BorderSide(color: Colors.red),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Reject"),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _updateStatus(req.id, 'Approved'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Approve"),
                      ),
                    ),
                  ],
                )
                else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: (req.status == 'Approved' ? Colors.green : Colors.red).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(req.status, style: GoogleFonts.poppins(color: req.status == 'Approved' ? Colors.green : Colors.red, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
