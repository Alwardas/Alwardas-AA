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

class HodRequestsScreen extends StatefulWidget {
  const HodRequestsScreen({super.key});

  @override
  _HodRequestsScreenState createState() => _HodRequestsScreenState();
}

class _HodRequestsScreenState extends State<HodRequestsScreen> {
  List<dynamic> _requests = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    final user = await AuthService.getUserSession();
    if (user == null) return;

    try {
      // Show all pending users for the HOD's branch (Students, Faculty, Parents)
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/admin/users?is_approved=false&branch=${user['branch']}'),
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
        Uri.parse('${ApiConstants.baseUrl}/api/admin/approve'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'user_id': userId,
          'action': action
        }),
      );

      if (response.statusCode == 200) {
        _showSnackBar(action == 'APPROVE' ? "Faculty Approved" : "Request Rejected");
        _fetchRequests();
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
          title: Text("Branch Requests", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
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
                      Icon(Icons.people_outline, size: 64, color: iconBg),
                      const SizedBox(height: 20),
                      Text("No pending requests for your branch", style: GoogleFonts.poppins(color: subTextColor, fontSize: 16)),
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
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: tint.withOpacity(0.1), shape: BoxShape.circle),
                child: Icon(Icons.badge, color: tint, size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['full_name'] ?? 'Faculty Name', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 4),
                    Text("ID: ${r['login_id']} | ${r['branch']}", style: TextStyle(fontSize: 13, color: subTextColor, fontWeight: FontWeight.w500)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => onAction(r['id'], 'REJECT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withOpacity(0.1),
                    foregroundColor: Colors.red,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Reject', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => onAction(r['id'], 'APPROVE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: tint,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Approve', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
