import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';

class StudentNotificationsScreen extends StatefulWidget {
  final String? userId;
  const StudentNotificationsScreen({super.key, this.userId});

  @override
  _StudentNotificationsScreenState createState() => _StudentNotificationsScreenState();
}

class _StudentNotificationsScreenState extends State<StudentNotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;
  
  // Selection State
  final Set<String> _selectedIds = {};
  bool _isSelectionMode = false;

  @override
  void initState() {
    super.initState();
    _fetchNotifications();
  }

  Future<void> _fetchNotifications() async {
    String? uid = widget.userId;
    if (uid == null) {
        final userData = await AuthService.getUserSession(); 
        uid = userData?['id']; 
    }

    if (uid == null) {
        setState(() => _loading = false);
        return;
    }

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/notifications?userId=$uid');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        setState(() {
          _notifications = data;
          _loading = false;
        });
      } else {
        debugPrint("Failed to fetch notifications: ${response.statusCode}");
        setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteSelectedNotifications() async {
      if (_selectedIds.isEmpty) return;

      try {
          final url = Uri.parse('${ApiConstants.baseUrl}/api/notifications/delete');
          final response = await http.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: json.encode({'ids': _selectedIds.toList()}),
          );

          if (response.statusCode == 200) {
             setState(() {
                 _notifications.removeWhere((item) => _selectedIds.contains(item['id']));
                 _selectedIds.clear();
                 _isSelectionMode = false;
             });
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notifications deleted")));
          } else {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete")));
          }
      } catch (e) {
          debugPrint("Delete Error: $e");
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Delete error")));
      }
  }

  void _toggleSelection(String id) {
      setState(() {
          if (_selectedIds.contains(id)) {
              _selectedIds.remove(id);
              if (_selectedIds.isEmpty) _isSelectionMode = false;
          } else {
              _selectedIds.add(id);
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
        title: Text(_isSelectionMode ? "${_selectedIds.length} Selected" : "Notifications", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        leading: IconButton(
          icon: Icon(_isSelectionMode ? Icons.close : Icons.arrow_back, color: textColor),
          onPressed: () {
              if (_isSelectionMode) {
                  setState(() {
                      _isSelectionMode = false;
                      _selectedIds.clear();
                  });
              } else {
                  Navigator.pop(context);
              }
          },
        ),
        actions: [
            if (_isSelectionMode) ...[
                IconButton(
                    icon: Icon(
                        _selectedIds.length == _notifications.length ? Icons.deselect : Icons.select_all, 
                        color: Colors.blue
                    ),
                    onPressed: () {
                        setState(() {
                            if (_selectedIds.length == _notifications.length) {
                                _selectedIds.clear();
                            } else {
                                for (var item in _notifications) {
                                    _selectedIds.add(item['id'].toString());
                                }
                            }
                        });
                    },
                    tooltip: _selectedIds.length == _notifications.length ? "Deselect All" : "Select All",
                ),
                IconButton(
                    icon: const Icon(Icons.delete, color: Colors.red),
                    onPressed: _deleteSelectedNotifications,
                )
            ] else 
                IconButton(
                    icon: const Icon(Icons.refresh), 
                    onPressed: () {
                        setState(() => _loading = true);
                        _fetchNotifications();
                    }
                )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: _loading 
            ? Center(child: CircularProgressIndicator(color: tint))
            : (_notifications.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_outlined, size: 80, color: subTextColor.withValues(alpha: 0.5)),
                        const SizedBox(height: 20),
                        Text("No Notifications", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                        const SizedBox(height: 8),
                        Text("You're all caught up!", style: GoogleFonts.poppins(fontSize: 14, color: subTextColor)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _notifications.length,
                    itemBuilder: (ctx, index) {
                      final item = _notifications[index];
                      // Backend fields: message, created_at, type, status
                      final id = item['id'].toString();
                      final message = item['message'] ?? 'No message';
                      final type = item['type'] ?? 'Notification';
                      final timeAgo = _timeAgo(item['created_at']);
                      
                      final isSelected = _selectedIds.contains(id);

                      return GestureDetector(
                        onLongPress: () {
                            setState(() {
                                _isSelectionMode = true;
                                _toggleSelection(id);
                            });
                        },
                        onTap: () {
                            if (_isSelectionMode) {
                                _toggleSelection(id);
                            }
                        },
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          margin: const EdgeInsets.only(bottom: 12),
                          decoration: BoxDecoration(
                            color: isSelected ? tint.withValues(alpha: 0.1) : cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: isSelected ? tint : iconBg),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Checkbox if selection mode
                              if (_isSelectionMode)
                                  Padding(
                                      padding: const EdgeInsets.only(right: 12, top: 4),
                                      child: Icon(
                                          isSelected ? Icons.check_box : Icons.check_box_outline_blank,
                                          color: isSelected ? tint : subTextColor,
                                      ),
                                  ),
                              
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(color: textColor.withValues(alpha: 0.05), shape: BoxShape.circle),
                                child: _buildNotificationIcon(type, message, tint),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(type, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: tint)),
                                    const SizedBox(height: 2),
                                    Text(message, style: GoogleFonts.poppins(fontSize: 14, color: textColor)),
                                    const SizedBox(height: 6),
                                    Text(timeAgo, style: GoogleFonts.poppins(fontSize: 11, color: subTextColor.withValues(alpha: 0.8))),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  )
            ),
        ),
      ),
    );
  }
  Widget _buildNotificationIcon(String type, String message, Color tint) {
    if (type.toUpperCase() == 'ATTENDANCE') {
      if (message.toLowerCase().contains('present')) {
        return const Icon(Icons.check_circle, color: Colors.green, size: 24);
      } else if (message.toLowerCase().contains('absent')) {
        return const Icon(Icons.cancel, color: Colors.red, size: 24);
      }
      return const Icon(Icons.calendar_today, color: Colors.orange, size: 24);
    }
    if (type.toUpperCase() == 'ANNOUNCEMENT') {
        return const Icon(Icons.campaign_rounded, color: Colors.blue, size: 24);
    }
    return Icon(Icons.notifications, color: tint, size: 24);
  }

  String _timeAgo(String? dateString) {
      if (dateString == null) return 'Just now';
      try {
          final date = DateTime.parse(dateString);
          final now = DateTime.now();
          final difference = now.difference(date);

          if (difference.inSeconds < 60) {
              return 'Just now';
          } else if (difference.inMinutes < 60) {
              return '${difference.inMinutes} mins ago';
          } else if (difference.inHours < 24) {
              return '${difference.inHours} hours ago';
          } else if (difference.inDays < 7) {
              return '${difference.inDays} days ago';
          } else {
              // Fallback to date if older than a week
              return dateString.split('T')[0];
          }
      } catch (e) {
          return 'Just now';
      }
  }
}
