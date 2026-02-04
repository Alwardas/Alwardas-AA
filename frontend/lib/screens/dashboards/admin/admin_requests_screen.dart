import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';

class AdminRequestsScreen extends StatefulWidget {
  const AdminRequestsScreen({super.key});

  @override
  State<AdminRequestsScreen> createState() => _AdminRequestsScreenState();
}

class _AdminRequestsScreenState extends State<AdminRequestsScreen> {
  List<dynamic> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    try {
      // Fetch unapproved users (Prinicpals, for example)
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/admin/users?is_approved=false'),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _requests = json.decode(response.body);
            _loading = false;
          });
        }
      }
    } catch (e) {
      print("Error fetching requests: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAction(String userId, String action) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/admin/users/approve'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'action': action,
        }),
      );

      if (response.statusCode == 200) {
        _showSnackBar("User ${action == 'APPROVE' ? 'Approved' : 'Rejected'} successfully!");
        _fetchRequests();
      } else {
        _showSnackBar("Failed to process request");
      }
    } catch (e) {
      _showSnackBar("Network Error");
    }
  }

  void _showSnackBar(String message) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    }
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
        title: Text("Approval Requests", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: _loading 
          ? const Center(child: CircularProgressIndicator())
          : _requests.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: tint.withOpacity(0.5)),
                  const SizedBox(height: 20),
                  Text("All Caught Up!", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                  Text("No pending requests.", style: GoogleFonts.poppins(color: subTextColor)),
                ],
              ),
            )
          : RefreshIndicator(
              onRefresh: _fetchRequests,
              child: ListView.builder(
                padding: const EdgeInsets.all(20),
                itemCount: _requests.length,
                itemBuilder: (ctx, index) {
                  final r = _requests[index];
                  return _buildRequestCard(r, cardColor, textColor, subTextColor, tint, iconBg);
                },
              ),
            ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(dynamic r, Color cardColor, Color textColor, Color subTextColor, Color tint, Color iconBg) {
    final role = r['role'] ?? 'Unknown';
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: iconBg),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: tint.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.person_outline, color: tint, size: 20),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['full_name'] ?? 'Unknown', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                    Text("$role ${r['branch'] != null ? '- ${r['branch']}' : ''}", style: GoogleFonts.poppins(fontSize: 12, color: tint, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Text(r['login_id'] ?? '', style: GoogleFonts.poppins(fontSize: 12, color: subTextColor)),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            "Registration request for $role. Approval required to enable login and system access.",
            style: GoogleFonts.poppins(fontSize: 14, color: subTextColor),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleAction(r['id'], 'REJECT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: const Text("Reject", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => _handleAction(r['id'], 'APPROVE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: const Text("Approve", style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          )
        ],
      ),
    );
  }
}
