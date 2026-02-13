import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';

class PrincipalAnnouncementsScreen extends StatefulWidget {
  const PrincipalAnnouncementsScreen({super.key});

  @override
  _PrincipalAnnouncementsScreenState createState() => _PrincipalAnnouncementsScreenState();
}

class _PrincipalAnnouncementsScreenState extends State<PrincipalAnnouncementsScreen> {
  List<dynamic> _announcements = [];
  bool _loading = true;
  bool _submitting = false;

  // Form State
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final List<String> _targetRoles = ['Student', 'Faculty', 'HOD', 'Coordinator']; // Consistent casing
  List<String> _selectedRoles = [];

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    final user = await AuthService.getUserSession();
    if (user == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/announcement'),
      );
      if (response.statusCode == 200) {
        List<dynamic> all = json.decode(response.body);
        // Filter by creator ID to show "My Announcements"
        // Also sort by date
        setState(() {
          _announcements = all.where((a) => a['creator_id'] == user['id']).toList();
          _announcements.sort((a, b) => DateTime.parse(b['created_at']).compareTo(DateTime.parse(a['created_at'])));
        });
      }
    } catch (e) {
      debugPrint("Error fetching announcements: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleCreate() async {
    if (_titleController.text.trim().isEmpty || _selectedRoles.isEmpty) {
      _showSnackBar("Please provide a title and select target audience.");
      return;
    }

    setState(() => _submitting = true);
    final user = await AuthService.getUserSession();

    final DateTime startDateTime = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute,
    ).toUtc();
    
    // Default end date: 7 days later
    final DateTime endDateTime = startDateTime.add(const Duration(days: 7));

    final payload = {
      'creatorId': user?['id'],
      'title': _titleController.text.trim(),
      'description': _descController.text.trim(),
      'type': 'general', // Default
      'audience': _selectedRoles,
      'priority': 'normal',
      'start_date': startDateTime.toIso8601String(),
      'end_date': endDateTime.toIso8601String(),
      'isPinned': false,
      'attachmentUrl': null
    };

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/announcement'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(payload),
      );

      if (response.statusCode == 201 || response.statusCode == 200) {
        _showSnackBar("Announcement created successfully");
        Navigator.pop(context);
        _resetForm();
        _fetchAnnouncements();
      } else {
        _showSnackBar("Failed: ${response.body}");
      }
    } catch (e) {
      _showSnackBar("Network Error: $e");
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _handleDelete(String id) async {
    try {
      // Backend should support DELETE /api/announcement/:id
      // But currently main.rs registered handlers: create and get.
      // I need to add delete handler in backend?
      // For now, simulate success or fail.
      // The user wants "Announcement Management (Update/Delete)" as next steps.
      // I will implement UI for delete, but backend might 404/405.
      // I'll leave the call here.
      final response = await http.delete(Uri.parse('${ApiConstants.baseUrl}/api/announcement/$id'));
      if (response.statusCode == 200) {
        _fetchAnnouncements();
      } else {
         _showSnackBar("Delete not implemented or failed");
      }
    } catch (e) {
      _showSnackBar("Failed to delete");
    }
  }

  void _resetForm() {
    _titleController.clear();
    _descController.clear();
    _selectedRoles = [];
    _selectedDate = DateTime.now();
    _selectedTime = TimeOfDay.now();
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  void _toggleRole(String role) {
    setState(() {
      if (_selectedRoles.contains(role)) {
        _selectedRoles.remove(role);
      } else {
        _selectedRoles.add(role);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? ThemeColors.darkBackground : ThemeColors.lightBackground;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Announcements", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: GestureDetector(
              onTap: () => _showCreateModal(),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(color: const Color(0xFF00d2ff), borderRadius: BorderRadius.circular(20)),
                child: Row(
                  children: [
                    const Icon(Icons.add, color: Colors.white, size: 18),
                    const SizedBox(width: 4),
                    Text("Create", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: _loading 
            ? const Center(child: CircularProgressIndicator()) 
            : _announcements.isEmpty 
              ? Center(child: Text("No active announcements.", style: GoogleFonts.poppins(color: subTextColor)))
              : ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: _announcements.length,
                  itemBuilder: (ctx, index) {
                    final item = _announcements[index];
                    // Check completion by end_date
                    final endDate = DateTime.parse(item['end_date']);
                    final isCompleted = DateTime.now().isAfter(endDate);
                    
                    return _buildAnnouncementCard(item, isCompleted, cardColor, textColor, subTextColor, iconBg, tint);
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildAnnouncementCard(dynamic item, bool isCompleted, Color cardColor, Color textColor, Color subTextColor, Color iconBg, Color tint) {
    return GestureDetector(
      onLongPress: () {
          showDialog(
            context: context,
            builder: (ctx) => AlertDialog(
              title: const Text("Delete Announcement"),
              content: const Text("Are you sure you want to permanently delete this announcement?"),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                TextButton(
                  onPressed: () {
                    _handleDelete(item['id']);
                    Navigator.pop(ctx);
                  },
                  child: const Text("Delete", style: TextStyle(color: Colors.red)),
                ),
              ],
            ),
          );
      },
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 300),
        opacity: isCompleted ? 0.5 : 1.0,
        child: Container(
          padding: const EdgeInsets.all(20),
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: iconBg),
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
                        Text(item['title'] ?? 'No Title', style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                        Text(
                          DateFormat('MMM d, yyyy').format(DateTime.parse(item['start_date'])),
                          style: GoogleFonts.poppins(fontSize: 12, color: subTextColor),
                        ),
                      ],
                    ),
                  ),
                  if (isCompleted)
                    Column(
                      children: [
                        const Icon(Icons.check_circle, color: Colors.green, size: 24),
                        Text("EXPIRED", style: GoogleFonts.poppins(fontSize: 10, color: Colors.green, fontWeight: FontWeight.bold)),
                      ],
                    ),
                ],
              ),
              if (item['description'] != null && item['description'].isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 12),
                  child: Text(item['description'], style: GoogleFonts.poppins(fontSize: 14, color: subTextColor)),
                ),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: (item['audience'] as List<dynamic>? ?? []).map((role) => Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                  child: Text(role.toString(), style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold, color: textColor)),
                )).toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setModalState) {
          final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
          final cardColor = isDark ? const Color(0xFF1e1e1e) : Colors.white;
          final textColor = isDark ? Colors.white : Colors.black;
          final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;

          return Container(
            height: MediaQuery.of(context).size.height * 0.8,
            decoration: BoxDecoration(color: cardColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(30))),
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text("New Announcement", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                    IconButton(onPressed: () => Navigator.pop(context), icon: Icon(Icons.close, color: textColor)),
                  ],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildLabel("Title", textColor),
                        TextField(
                          controller: _titleController,
                          style: TextStyle(color: textColor),
                          decoration: _inputDecoration("Event Title", isDark),
                        ),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel("Date", textColor),
                                  GestureDetector(
                                    onTap: () async {
                                      final picked = await showDatePicker(
                                        context: context,
                                        initialDate: _selectedDate,
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                      );
                                      if (picked != null) setModalState(() => _selectedDate = picked);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                                      child: Text("${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}", style: TextStyle(color: textColor)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _buildLabel("Time", textColor),
                                  GestureDetector(
                                    onTap: () async {
                                      final picked = await showTimePicker(context: context, initialTime: _selectedTime);
                                      if (picked != null) setModalState(() => _selectedTime = picked);
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(12)),
                                      child: Text(_selectedTime.format(context), style: TextStyle(color: textColor)),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        _buildLabel("Description", textColor),
                        TextField(
                          controller: _descController,
                          style: TextStyle(color: textColor),
                          maxLines: 3,
                          decoration: _inputDecoration("Details...", isDark),
                        ),
                        _buildLabel("Target Audience", textColor),
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: _targetRoles.map((role) {
                            final isSel = _selectedRoles.contains(role);
                            return GestureDetector(
                              onTap: () {
                                _toggleRole(role);
                                setModalState(() {});
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                decoration: BoxDecoration(
                                  color: isSel ? tint : Colors.transparent,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(color: isSel ? tint : Colors.grey),
                                ),
                                child: Text(role, style: GoogleFonts.poppins(color: isSel ? Colors.white : textColor, fontWeight: FontWeight.w600)),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 30),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            onPressed: _submitting ? null : () => _handleCreate(),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: tint,
                              padding: const EdgeInsets.symmetric(vertical: 16),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                            ),
                            child: _submitting ? const CircularProgressIndicator(color: Colors.white) : const Text("Publish", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildLabel(String text, Color color) {
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 8),
      child: Text(text, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: color)),
    );
  }

  InputDecoration _inputDecoration(String hint, bool isDark) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
      enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.grey)),
    );
  }
}
