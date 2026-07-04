import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/theme_extensions.dart';

class DesktopAuditLogsView extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DesktopAuditLogsView({super.key, required this.userData});

  @override
  State<DesktopAuditLogsView> createState() => _DesktopAuditLogsViewState();
}

class _DesktopAuditLogsViewState extends State<DesktopAuditLogsView> {
  @override
  Widget build(BuildContext context) {
    final List<Map<String, dynamic>> logs = [
      {'user': 'Admin Ramesh', 'role': 'Admin', 'action': 'Change Role Permission', 'prev': 'View Only', 'new': 'Full Control', 'time': '2026-06-15 11:32:00', 'ip': '192.168.1.45'},
      {'user': 'HOD Dr. Rama Rao', 'role': 'HOD', 'action': 'Approve Lesson Schedule', 'prev': 'Pending', 'new': 'Approved', 'time': '2026-06-15 10:15:12', 'ip': '192.168.1.12'},
      {'user': 'Accountant Jyothi', 'role': 'Accounts Staff', 'action': 'Bulk Fee Adjustment', 'prev': '₹0 adjustment', 'new': '₹-5,000 scholarship', 'time': '2026-06-14 15:44:00', 'ip': '192.168.1.99'},
    ];

    return Container(
      color: context.bgColor,
      padding: EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Security Audit Trails & Change Logs',
            style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
          ),
          Text(
            'Chronological system activity log capturing data mutations and administrative actions',
            style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12),
          ),
          SizedBox(height: 24),

          // Audit Table
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderColor),
              ),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  Container(
                    color: context.bgColor.withOpacity(0.4),
                    height: 44,
                    padding: EdgeInsets.symmetric(horizontal: 20),
                    child: Row(
                      children: [
                        Expanded(flex: 2, child: Text('User / Actor', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                        Expanded(flex: 1, child: Text('Role', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                        Expanded(flex: 3, child: Text('Action Performed', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Previous Value', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('New Value', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('Timestamp', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                        Expanded(flex: 2, child: Text('IP Address', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                      ],
                    ),
                  ),
                  Divider(color: context.borderColor, height: 1),
                  Expanded(
                    child: ListView.builder(
                      itemCount: logs.length,
                      itemBuilder: (context, index) {
                        final item = logs[index];
                        return Container(
                          height: 52,
                          padding: EdgeInsets.symmetric(horizontal: 20),
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: context.borderColor, width: 0.5)),
                          ),
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: Text(item['user'], style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.bold))),
                              Expanded(flex: 1, child: Text(item['role'], style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12))),
                              Expanded(flex: 3, child: Text(item['action'], style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 12))),
                              Expanded(flex: 2, child: Text(item['prev'], style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12))),
                              Expanded(flex: 2, child: Text(item['new'], style: GoogleFonts.poppins(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.w500))),
                              Expanded(flex: 2, child: Text(item['time'], style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11))),
                              Expanded(flex: 2, child: Text(item['ip'], style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11))),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

