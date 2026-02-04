import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';

class PrincipalRequestsScreen extends StatefulWidget {
  const PrincipalRequestsScreen({super.key});

  @override
  State<PrincipalRequestsScreen> createState() => _PrincipalRequestsScreenState();
}

class _PrincipalRequestsScreenState extends State<PrincipalRequestsScreen> {
  List<dynamic> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/admin/users?role=HOD&is_approved=false'),
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
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleAction(String userId, String action) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/principal/approve-hod'),
        headers: const {'Content-Type': 'application/json'},
        body: json.encode({'user_id': userId, 'action': action}),
      );

      if (response.statusCode == 200) {
        _showSnackBar("Agent ${action == 'APPROVE' ? 'Approved' : 'Rejected'} successfully!");
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
        title: Text("Approval Requests", style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Stack(
        children: [
          Positioned.fill(
            child: RepaintBoundary(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
              ),
            ),
          ),
          SafeArea(
            child: _loading 
            ? const Center(child: CircularProgressIndicator())
            : _requests.isEmpty 
            ? Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.check_circle_outline, size: 80, color: tint.withOpacity(0.5)),
                    const SizedBox(height: 20),
                    Text("All Caught Up!", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                    Text("No pending HOD requests.", style: TextStyle(color: subTextColor)),
                  ],
                ),
              )
            : RefreshIndicator(
                onRefresh: _fetchRequests,
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                  itemCount: _requests.length,
                  itemBuilder: (ctx, index) {
                    final r = _requests[index];
                    return _RequestCard(
                      r: r,
                      cardColor: cardColor,
                      textColor: textColor,
                      subTextColor: subTextColor,
                      tint: tint,
                      iconBg: iconBg,
                      onAction: _handleAction,
                    );
                  },
                ),
              ),
          ),
        ],
      ),
    );
  }
}

class _RequestCard extends StatelessWidget {
  final dynamic r;
  final Color cardColor;
  final Color textColor;
  final Color subTextColor;
  final Color tint;
  final Color iconBg;
  final Function(String, String) onAction;

  const _RequestCard({
    required this.r,
    required this.cardColor,
    required this.textColor,
    required this.subTextColor,
    required this.tint,
    required this.iconBg,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: iconBg.withOpacity(0.2)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 6)),
        ],
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
                    Text(r['full_name'] ?? 'Unknown', 
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                    Text("HOD - ${r['branch'] ?? 'N/A'}", 
                      style: TextStyle(fontSize: 12, color: tint, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Text(r['login_id'] ?? '', style: TextStyle(fontSize: 12, color: subTextColor)),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            "New HOD account request for ${r['branch'] ?? 'administration'}. Approval required to enable login access.",
            style: TextStyle(fontSize: 14, color: subTextColor),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onAction(r['id'], 'REJECT'),
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
                  onPressed: () => onAction(r['id'], 'APPROVE'),
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


