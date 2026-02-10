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

class PrincipalNotificationsScreen extends StatefulWidget {
  const PrincipalNotificationsScreen({super.key});

  @override
  _PrincipalNotificationsScreenState createState() => _PrincipalNotificationsScreenState();
}

class _PrincipalNotificationsScreenState extends State<PrincipalNotificationsScreen> {
  List<dynamic> _notifications = [];
  bool _loading = true;

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
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/notifications?userId=${user['id']}&role=${user['role']}'),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _notifications = json.decode(response.body);
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching notifications: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAction(dynamic notification, String action) async {
    String endpoint = '';
    Map<String, dynamic> body = {};

    if (notification['type'] == 'USER_APPROVAL') {
      endpoint = '/api/hod/approve'; // Reusing HOD logic as per React source
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
    } else {
      _showSnackBar("Info notification");
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
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
          title: Text("Notifications", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: textColor),
        ),
        body: Container(
          decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: SafeArea(
            child: _loading 
              ? const Center(child: CircularProgressIndicator()) 
              : _notifications.isEmpty 
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.inbox_outlined, size: 64, color: iconBg),
                        const SizedBox(height: 20),
                        Text("No new notifications", style: GoogleFonts.poppins(color: subTextColor, fontSize: 16)),
                      ],
                    ),
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(20),
                    itemCount: _notifications.length,
                    itemBuilder: (ctx, index) {
                      final item = _notifications[index];
                      return _buildNotificationCard(item, cardColor, textColor, subTextColor, iconBg, tint);
                    },
                  ),
          ),
        ),
      ),
    );
  }

  Widget _buildNotificationCard(dynamic item, Color cardColor, Color textColor, Color subTextColor, Color iconBg, Color tint) {
    final isActionable = item['type'] == 'USER_APPROVAL' || item['type'] == 'PROFILE_UPDATE_REQUEST';
    final status = item['status'];

    return Container(
      padding: const EdgeInsets.all(15),
      margin: const EdgeInsets.only(bottom: 15),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: iconBg),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 4, offset: const Offset(0, 2)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Icon(
                item['type'] == 'USER_APPROVAL' ? Icons.person_add : Icons.description,
                color: tint,
                size: 24,
              ),
              Text(
                "${DateTime.parse(item['createdAt']).day}/${DateTime.parse(item['createdAt']).month}/${DateTime.parse(item['createdAt']).year}",
                style: GoogleFonts.poppins(fontSize: 12, color: subTextColor),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(item['message'], style: GoogleFonts.poppins(fontSize: 16, color: textColor, height: 1.4)),
          
          if (isActionable && status == 'UNREAD')
            Padding(
              padding: const EdgeInsets.only(top: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  _buildActionButton("Reject", Colors.red, () => _handleAction(item, 'REJECT')),
                  const SizedBox(width: 10),
                  _buildActionButton("Approve", Colors.green, () => _handleAction(item, 'APPROVE')),
                ],
              ),
            )
          else if (status == 'ACCEPTED' || status == 'APPROVED')
             Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  const Icon(Icons.check_circle, color: Colors.green, size: 20),
                  const SizedBox(width: 5),
                  Text("Approved", style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          else if (status == 'REJECTED')
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(
                children: [
                  const Icon(Icons.cancel, color: Colors.red, size: 20),
                  const SizedBox(width: 5),
                  Text("Rejected", style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildActionButton(String label, Color color, VoidCallback onTap) {
    return ElevatedButton(
      onPressed: onTap,
      style: ElevatedButton.styleFrom(
        backgroundColor: color,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
    );
  }
}
