import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';

class HodNotificationsScreen extends StatefulWidget {
  const HodNotificationsScreen({super.key});

  @override
  _HodNotificationsScreenState createState() => _HodNotificationsScreenState();
}

class _HodNotificationsScreenState extends State<HodNotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;
  final Set<String> _selectedItems = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    final user = await AuthService.getUserSession();
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }

    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/notifications').replace(queryParameters: {
        'userId': user['id'].toString(),
        'role': user['role']?.toString() ?? '',
        'branch': user['branch']?.toString() ?? ''
      });
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _notifications = json.decode(response.body);
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
        debugPrint("API Error: ${response.statusCode}");
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleSelectionMode() {
    setState(() {
      _isSelectionMode = !_isSelectionMode;
      _selectedItems.clear();
    });
  }

  void _toggleItemSelection(String id) {
    setState(() {
      if (_selectedItems.contains(id)) {
        _selectedItems.remove(id);
      } else {
        _selectedItems.add(id);
      }
    });
  }

  void _selectAll() {
    setState(() {
      if (_selectedItems.length == _notifications.length) {
        _selectedItems.clear();
      } else {
        for (var n in _notifications) {
          _selectedItems.add(n['id'].toString());
        }
      }
    });
  }

  Future<void> _deleteSelected() async {
    if (_selectedItems.isEmpty) return;

    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Notifications"),
        content: Text("Are you sure you want to delete ${_selectedItems.length} notifications?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/notifications/delete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ids': _selectedItems.toList()}),
      );

      if (response.statusCode == 200) {
        _fetchNotifications();
        _toggleSelectionMode();
        _showSnackBar("Notifications deleted successfully");
      } else {
         _showSnackBar("Failed to delete notifications");
      }
    } catch (e) {
      _showSnackBar("Failed to delete notifications");
    }
  }

  Future<void> _handleAction(dynamic notification, String action) async {
    String endpoint = '';
    Map<String, dynamic> body = {};

    if (notification['type'] == 'USER_APPROVAL') {
      endpoint = '/api/hod/approve';
      body = {
        'requestId': notification['id'],
        'senderId': notification['senderId'],
        'action': action
      };
    } else if (notification['type'] == 'PROFILE_UPDATE_REQUEST') {
      endpoint = '/api/hod/approve-profile-change';
      body = {
        'notificationId': notification['id'],
        'senderId': notification['senderId'],
        'action': action
      };
    } else if (notification['type'] == 'SUBJECT_APPROVAL') {
       endpoint = '/api/hod/approve-subject';
       body = {
         'notificationId': notification['id'], 
         'senderId': notification['senderId'], 
         'action': action
       };
    } else if (notification['type'] == 'ATTENDANCE_CORRECTION_REQUEST') {
       endpoint = '/api/hod/approve-attendance-correction'; 
       body = {
         'senderId': notification['senderId'],
         'notificationId': notification['id'], 
         'action': action
       };
    } else {
      _showSnackBar("Notification marked as read");
      return;
    }

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}$endpoint'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        _showSnackBar("Request ${action == 'APPROVE' ? 'Approved' : 'Rejected'}");
        _fetchNotifications();
      } else {
        final err = json.decode(response.body);
        _showSnackBar(err['error'] ?? "Failed to process request");
      }
    } catch (e) {
      _showSnackBar("Network Error");
    }
  }

  void _showSnackBar(String text) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.getAdaptiveOverlayStyle(isDark),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(_isSelectionMode ? "${_selectedItems.length} Selected" : "Requests", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
          actions: [
            TextButton(
              onPressed: _toggleSelectionMode,
              child: Text(_isSelectionMode ? "Cancel" : "Select", style: TextStyle(color: tint, fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
        body: Container(
          decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: SafeArea(
            child: Column(
              children: [
                if (_isSelectionMode)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        GestureDetector(
                          onTap: _selectAll,
                          child: Row(
                            children: [
                              Icon(_selectedItems.length == _notifications.length && _notifications.isNotEmpty ? Icons.check_box : Icons.check_box_outline_blank, color: textColor),
                              const SizedBox(width: 8),
                              Text("Select All", style: TextStyle(color: textColor)),
                            ],
                          ),
                        ),
                        if (_selectedItems.isNotEmpty)
                          ElevatedButton.icon(
                            onPressed: _deleteSelected,
                            icon: const Icon(Icons.delete, color: Colors.white, size: 18),
                            label: Text("Delete (${_selectedItems.length})", style: const TextStyle(color: Colors.white)),
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.red, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                          ),
                      ],
                    ),
                  ),
                Expanded(
                  child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _notifications.isEmpty
                      ? _buildEmptyState(subTextColor)
                      : ListView.builder(
                          padding: const EdgeInsets.all(20),
                          itemCount: _notifications.length,
                          itemBuilder: (ctx, index) {
                            final item = _notifications[index];
                            return _buildNotificationCard(item, cardColor, textColor, subTextColor, iconBg, tint);
                          },
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color color) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.inbox, size: 60, color: color.withValues(alpha: 0.5)),
          const SizedBox(height: 10),
          Text("No notifications", style: TextStyle(color: color, fontSize: 16)),
        ],
      ),
    );
  }

  void _handleLongPress(String id) {
    if (!_isSelectionMode) {
      setState(() {
        _isSelectionMode = true;
        _selectedItems.add(id);
      });
    }
  }

  Widget _buildNotificationCard(dynamic item, Color cardColor, Color textColor, Color subTextColor, Color iconBg, Color tint) {
    var isSelected = _selectedItems.contains(item['id'].toString());
    return NotificationCard(
      key: ValueKey(item['id']),
      item: item,
      cardColor: cardColor,
      textColor: textColor,
      subTextColor: subTextColor,
      iconBg: iconBg,
      tint: tint,
      isSelectionMode: _isSelectionMode,
      isSelected: isSelected,
      onSelect: () => _toggleItemSelection(item['id'].toString()),
      onLongPress: () => _handleLongPress(item['id'].toString()),
      onAction: _handleAction,
    );
  }
}

class NotificationCard extends StatefulWidget {
  final dynamic item;
  final Color cardColor;
  final Color textColor;
  final Color subTextColor;
  final Color iconBg;
  final Color tint;
  final bool isSelectionMode;
  final bool isSelected;
  final VoidCallback onSelect;
  final VoidCallback onLongPress;
  final Function(dynamic, String) onAction;

  const NotificationCard({
    super.key,
    required this.item,
    required this.cardColor,
    required this.textColor,
    required this.subTextColor,
    required this.iconBg,
    required this.tint,
    required this.isSelectionMode,
    required this.isSelected,
    required this.onSelect,
    required this.onLongPress,
    required this.onAction,
  });

  @override
  State<NotificationCard> createState() => _NotificationCardState();
}

class _NotificationCardState extends State<NotificationCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    final isActionable = item['type'] == 'USER_APPROVAL' || item['type'] == 'PROFILE_UPDATE_REQUEST' || item['type'] == 'SUBJECT_APPROVAL' || item['type'] == 'ATTENDANCE_CORRECTION_REQUEST';
    final status = item['status'];
    final bool isApproved = status == 'APPROVED' || status == 'ACCEPTED';
    
    // Parse message
    String fullMessage = item['message'] ?? '';
    bool isAttendance = item['type'] == 'ATTENDANCE_CORRECTION_REQUEST';
    bool isSubjectRequest = item['type'] == 'SUBJECT_APPROVAL';
    
    String title = fullMessage;
    String details = "";
    
    // Parsed fields for Subject Request - ROBUST LOGIC
    String facultyName =  item['senderName'] ?? 
                          item['sender_name'] ?? 
                          item['user_name'] ?? 
                          item['faculty_name'] ?? 
                          ""; 
    
    // If name is still empty, try to parse from message
    if (facultyName.isEmpty && fullMessage.toLowerCase().contains("requested for")) {
       final pattern = RegExp(r"^(.*?)\s+requested for", caseSensitive: false);
       final match = pattern.firstMatch(fullMessage);
       if (match != null && match.group(1) != null) {
          facultyName = match.group(1)!.trim();
       }
    }
    
    if (facultyName.isEmpty || facultyName.toLowerCase() == "faculty") {
       facultyName = "Unknown Faculty"; // Fallback to indicate missing data
    }

    String subjectName = "Subject";

    if (isAttendance) {
        if (fullMessage.contains("requests attendance correction for:")) {
           final parts = fullMessage.split("requests attendance correction for:");
           title = "${parts[0].trim()} - Attendance Correction Request";
           if (parts.length > 1) {
              details = "Correction on: ${parts[1].trim()}";
              details = details.replaceAll(". Reason:", "\nReason:");
           }
        }
    } else if (isSubjectRequest) {
        // Parse Subject Name safely
        if (fullMessage.toLowerCase().contains("requested for")) {
           final pattern = RegExp(r"requested for\s+(.*)", caseSensitive: false);
           final match = pattern.firstMatch(fullMessage);
           if (match != null && match.group(1) != null) {
              subjectName = match.group(1)!.trim();
              
              // Remove "the subject" prefix if present
              subjectName = subjectName.replaceAll(RegExp(r"^the subject\s+", caseSensitive: false), "");
           }
        } else {
           subjectName = fullMessage;
        }
    }

    return GestureDetector(
      onLongPress: widget.onLongPress,
      onTap: widget.isSelectionMode ? widget.onSelect : () {
        if (isAttendance) {
            setState(() => _expanded = !_expanded);
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12), // Reduced padding
        margin: const EdgeInsets.only(bottom: 15),
        decoration: BoxDecoration(
          color: widget.cardColor,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: widget.isSelected ? widget.tint : widget.iconBg, width: widget.isSelected ? 2 : 1),
          boxShadow: [
             BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
             // Header Row
             Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Row(
                    children: [
                      if (widget.isSelectionMode)
                        Padding(
                          padding: const EdgeInsets.only(right: 10),
                          child: Icon(widget.isSelected ? Icons.check_box : Icons.check_box_outline_blank, color: widget.tint),
                        ),
                      
                      // Custom Icon & Title for Subject Request
                      if (isSubjectRequest) ...[
                         Icon(Icons.assignment_ind_outlined, color: widget.tint, size: 20), // Smaller Icon
                         if (isApproved) ...[
                           const SizedBox(width: 8),
                           Container(
                             decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                             padding: const EdgeInsets.all(2),
                             child: const Icon(Icons.check, size: 10, color: Colors.white),
                           ),
                         ],
                         const SizedBox(width: 8),
                         Expanded(
                           child: Text(
                             "Faculty Course Request",
                             style: GoogleFonts.poppins(
                               fontSize: 10, // Reduced to small size per request
                               fontWeight: FontWeight.bold, 
                               color: widget.textColor
                             ),
                           ),
                         ),
                      ] else ...[
                         // Default Header
                         Icon(item['type'] == 'USER_APPROVAL' ? Icons.person_add : Icons.description, color: widget.tint, size: 24),
                         const SizedBox(width: 10),
                         if (isApproved)
                           const Icon(Icons.check_circle, color: Colors.green, size: 18)
                         else if (status == 'REJECTED')
                           const Icon(Icons.cancel, color: Colors.red, size: 18),
                      ]
                    ],
                  ),
                ),
                
                // Show date for ALL types including subject request
                Row(
                  children: [
                     Text(
                       "${DateTime.parse(item['createdAt']).day}/${DateTime.parse(item['createdAt']).month}/${DateTime.parse(item['createdAt']).year}",
                       style: GoogleFonts.poppins(fontSize: 10, color: widget.subTextColor), // Date size 10
                     ),
                     if (isAttendance)
                        Icon(_expanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down, color: widget.subTextColor)
                  ],
                )
              ],
            ),
            
            const SizedBox(height: 8), // Reduced spacing
            
            // Content
            if (isSubjectRequest) ...[
               Text(
                 facultyName, 
                 style: GoogleFonts.poppins(fontSize: 12, color: widget.textColor, fontWeight: FontWeight.bold)
               ),
               const SizedBox(height: 1),
               Text(
                 subjectName,
                 maxLines: 1, 
                 overflow: TextOverflow.ellipsis,
                 style: GoogleFonts.poppins(
                   fontSize: 12, // Subject Name
                   fontWeight: FontWeight.normal, 
                   color: widget.textColor, 
                 ),
               ),
            ] else ...[
               // Default Content
               Text(isAttendance ? title : fullMessage, style: GoogleFonts.poppins(fontSize: 14, color: widget.textColor, height: 1.4, fontWeight: isAttendance ? FontWeight.w600 : FontWeight.normal)),
               if (isAttendance && _expanded && details.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 10),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: widget.iconBg.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                  child: Text(details, style: GoogleFonts.poppins(fontSize: 14, color: widget.textColor)),
                ),
            ],

             // Action Buttons
            if (isActionable && !['APPROVED', 'REJECTED', 'ACCEPTED'].contains(status) && !widget.isSelectionMode)
              Padding(
                padding: const EdgeInsets.only(top: 15),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.end, // or Start as per request
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => widget.onAction(item, 'REJECT'),
                        style: OutlinedButton.styleFrom(
                           foregroundColor: Colors.red, 
                           side: const BorderSide(color: Colors.red),
                           padding: const EdgeInsets.symmetric(vertical: 12),
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => widget.onAction(item, 'APPROVE'),
                        style: ElevatedButton.styleFrom(
                           backgroundColor: Colors.green, 
                           padding: const EdgeInsets.symmetric(vertical: 12), 
                           shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        child: const Text("Approve", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                ),
              ),
              
             if (isSubjectRequest && isApproved)
                Container(
                  margin: const EdgeInsets.only(top: 15),
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: Colors.green.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.green.withValues(alpha: 0.3)),
                  ),
                  child: Center(child: Text("Approved", style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.bold))),
                ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    // Helper not used in new design, but kept if needed for other types
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(backgroundColor: color, padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}

