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

class CoordinatorRequestsScreen extends StatefulWidget {
  const CoordinatorRequestsScreen({super.key});

  @override
  _CoordinatorRequestsScreenState createState() => _CoordinatorRequestsScreenState();
}

class _CoordinatorRequestsScreenState extends State<CoordinatorRequestsScreen> {
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
        Uri.parse('${ApiConstants.baseUrl}/api/admin/users?role=Principal&is_approved=false'),
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
        _showSnackBar(action == 'APPROVE' ? "Principal Approved" : "Request Rejected");
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
          title: Text("Principal Approvals", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back_ios_new, color: textColor, size: 20),
            onPressed: () => Navigator.pop(context),
          ),
          actions: [
            IconButton(
              icon: Icon(Icons.refresh, color: textColor),
              onPressed: _fetchRequests,
            )
          ],
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
                      Container(
                         padding: const EdgeInsets.all(30),
                         decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
                         child: Icon(Icons.check_circle_outline, size: 60, color: subTextColor)
                      ),
                      const SizedBox(height: 20),
                      Text("All Caught Up!", style: GoogleFonts.poppins(color: textColor, fontSize: 18, fontWeight: FontWeight.w600)),
                      const SizedBox(height: 8),
                      Text("No pending principal requests found.", style: GoogleFonts.poppins(color: subTextColor, fontSize: 14)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _fetchRequests,
                  child: ListView.builder(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    itemCount: _requests.length,
                    itemBuilder: (ctx, index) {
                      final r = _requests[index];
                      return _PrincipalRequestCard(
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

class _PrincipalRequestCard extends StatelessWidget {
  final dynamic r;
  final Color cardColor;
  final Color textColor;
  final Color subTextColor;
  final Color tint;
  final Color iconBg;
  final Function(String, String) onAction;

  const _PrincipalRequestCard({
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
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: iconBg, width: 1),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: tint.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                child: Icon(Icons.school, color: tint, size: 28),
              ),
              const SizedBox(width: 15),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     Row(
                       mainAxisAlignment: MainAxisAlignment.spaceBetween,
                       children: [
                         Expanded(child: Text(r['full_name'] ?? 'Principal Name', style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor))),
                         Container(
                           padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                           decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(6)),
                           child: Text("Pending", style: GoogleFonts.poppins(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.bold)),
                         )
                       ],
                     ),
                     const SizedBox(height: 4),
                     Text(r['login_id'] ?? '', style: GoogleFonts.poppins(fontSize: 13, color: subTextColor)),
                     const SizedBox(height: 8),
                     Row(
                       children: [
                         Icon(Icons.badge_outlined, size: 14, color: subTextColor),
                         const SizedBox(width: 5),
                         Text("Role: ${r['role']}", style: GoogleFonts.poppins(fontSize: 12, color: subTextColor)),
                       ],
                     )
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  onPressed: () => onAction(r['id'], 'REJECT'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red.withValues(alpha: 0.1),
                    foregroundColor: Colors.red,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    side: BorderSide(color: Colors.red.withValues(alpha: 0.2))
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
                    shadowColor: tint.withValues(alpha: 0.4),
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
