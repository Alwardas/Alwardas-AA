import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';

class PrincipalRequestsScreen extends StatefulWidget {
  const PrincipalRequestsScreen({super.key});

  @override
  State<PrincipalRequestsScreen> createState() => _PrincipalRequestsScreenState();
}

class _PrincipalRequestsScreenState extends State<PrincipalRequestsScreen> {
  final List<Map<String, dynamic>> _requests = [
    {'id': '1', 'name': 'Dr. Srinivas Rao', 'type': 'Leave Request', 'date': 'Today', 'status': 'Pending', 'reason': 'Personal emergency'},
    {'id': '2', 'name': 'Ms. Lakshmi Devi', 'type': 'Profile Update', 'date': 'Yesterday', 'status': 'Pending', 'reason': 'Address change verification'},
    {'id': '3', 'name': 'Mr. Rajesh Kumar', 'type': 'Financial Grant', 'date': '2 days ago', 'status': 'Pending', 'reason': 'Equipment purchase for Lab'},
  ];

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
          child: _requests.isEmpty 
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.check_circle_outline, size: 80, color: tint.withOpacity(0.5)),
                  const SizedBox(height: 20),
                  Text("All Caught Up!", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                  Text("No pending requests to show.", style: GoogleFonts.poppins(color: subTextColor)),
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(20),
              itemCount: _requests.length,
              itemBuilder: (ctx, index) {
                final r = _requests[index];
                return _buildRequestCard(r, cardColor, textColor, subTextColor, tint, iconBg);
              },
            ),
        ),
      ),
    );
  }

  Widget _buildRequestCard(Map<String, dynamic> r, Color cardColor, Color textColor, Color subTextColor, Color tint, Color iconBg) {
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
                child: Icon(
                  r['type'] == 'Leave Request' ? Icons.calendar_today : 
                  r['type'] == 'Profile Update' ? Icons.person_outline : Icons.attach_money,
                  color: tint, size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(r['name'], style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                    Text(r['type'], style: GoogleFonts.poppins(fontSize: 12, color: tint, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
              Text(r['date'], style: GoogleFonts.poppins(fontSize: 12, color: subTextColor)),
            ],
          ),
          const SizedBox(height: 15),
          Text(
            r['reason'],
            style: GoogleFonts.poppins(fontSize: 14, color: subTextColor),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _handleAction(r['id'], 'Rejected'),
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
                  onPressed: () => _handleAction(r['id'], 'Approved'),
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

  void _handleAction(String id, String status) {
    setState(() {
      _requests.removeWhere((r) => r['id'] == id);
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Request $status successfully!")));
  }
}
