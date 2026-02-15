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
    // Mocking Faculty Subject Requests as per user requirement
    await Future.delayed(const Duration(seconds: 1));
    if (mounted) {
      setState(() {
        _requests = [
          {
            'id': '101',
            'type': 'subject_request',
            'faculty_name': 'S ALIELU',
            'subject_name': 'Advanced Mathematics',
            'status': 'PENDING',
          },
          {
            'id': '102',
            'type': 'subject_request',
            'faculty_name': 'Dr. P. Smith',
            'subject_name': 'Thermodynamics',
            'status': 'PENDING',
          },
           {
            'id': '103',
            'type': 'subject_request',
            'faculty_name': 'A. Johnson',
            'subject_name': 'Data Structures',
            'status': 'APPROVED',
          },
        ];
        _loading = false;
      });
    }
  }

  Future<void> _handleAction(String requestId, String action) async {
    // Mock API call
    setState(() {
       final index = _requests.indexWhere((r) => r['id'] == requestId);
       if (index != -1) {
         if (action == 'APPROVE') {
            _requests[index]['status'] = 'APPROVED';
            _showSnackBar("Request Approved");
         } else {
            _requests.removeAt(index); // Remove on reject
            _showSnackBar("Request Rejected");
         }
       }
    });
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
    
    // Custom header colors from screenshot/style
    final headerColor = isDark ? Colors.white : const Color(0xFF1A1A2E);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.getAdaptiveOverlayStyle(isDark),
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text("Requests", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: headerColor)),
          centerTitle: true,
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: IconButton(
            icon: Icon(Icons.arrow_back, color: headerColor),
            onPressed: () => Navigator.pop(context),
          ),
        ),
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight),
          ),
          child: SafeArea(
            child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _requests.isEmpty
              ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.assignment_turned_in_outlined, size: 64, color: subTextColor),
                      const SizedBox(height: 20),
                      Text("No pending requests", style: GoogleFonts.poppins(color: subTextColor, fontSize: 16)),
                    ],
                  ),
                )
              : ListView.builder(
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
                      onAction: _handleAction,
                    );
                  },
                ),
          ),
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
  final Function(String, String) onAction;

  const _RequestCard({
    required this.r,
    required this.cardColor,
    required this.textColor,
    required this.subTextColor,
    required this.tint,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    bool isApproved = r['status'] == 'APPROVED';

    return Container(
      padding: const EdgeInsets.all(20),
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 15, offset: const Offset(0, 5)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header: Icon + Check + Title
          Row(
            children: [
               Icon(Icons.assignment_ind_outlined, color: tint, size: 28), // Form Icon
               if (isApproved) ...[
                 const SizedBox(width: 8),
                 Container(
                   decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                   padding: const EdgeInsets.all(2),
                   child: const Icon(Icons.check, size: 12, color: Colors.white),
                 ),
               ],
               const SizedBox(width: 12),
               Expanded(
                 child: Text(
                   "Faculty Course Request",
                   style: GoogleFonts.poppins(
                     fontSize: 16, // Increased size
                     fontWeight: FontWeight.bold, // Prominent
                     color: textColor, // Use main text color
                   ),
                 ),
               ),
            ],
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: "${r['faculty_name'] ?? 'Faculty'}", 
                  style: GoogleFonts.poppins(fontSize: 16, color: textColor, fontWeight: FontWeight.bold)
                ),
                TextSpan(
                  text: " requested for the subject",
                  style: GoogleFonts.poppins(fontSize: 16, color: subTextColor, fontWeight: FontWeight.normal)
                ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(
            r['subject_name'] ?? 'Subject',
            style: GoogleFonts.poppins(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: tint, // Highlight subject name
            ),
          ),
          
          const SizedBox(height: 20),
          
          // Action Buttons (Hide if approved, or keep as per user "below approval rejct or accept")
          // User said "below approval rejct or accept", implying they want to see them.
          // But if approved, typically we disable or show status.
          // I will show them but disabled or changed if approved.
          if (!isApproved)
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => onAction(r['id'], 'REJECT'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: Colors.red,
                    side: const BorderSide(color: Colors.red),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Reject'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => onAction(r['id'], 'APPROVE'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.green,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  child: const Text('Approve'),
                ),
              ),
            ],
          )
          else
            Container(
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
    );
  }
}
