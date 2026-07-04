import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/theme_extensions.dart';

class DesktopReportsView extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DesktopReportsView({super.key, required this.userData});

  @override
  State<DesktopReportsView> createState() => _DesktopReportsViewState();
}

class _DesktopReportsViewState extends State<DesktopReportsView> {
  late String _selectedReportType;
  String _selectedFormat = 'PDF Document (.pdf)';
  late List<String> _reportTypes;

  @override
  void initState() {
    super.initState();
    final role = widget.userData['role']?.toString().toLowerCase() ?? 'staff';
    final isFinance = role == 'accountant' || role == 'accounts manager' || role == 'finance';
    
    if (isFinance) {
      _reportTypes = [
        'Fee Collection Audit',
        'Outstanding Dues Report',
        'Fee Reminders & Defaulters Log',
        'Scholarship Disbursements Summary',
        'Refund Transactions Log',
      ];
      _selectedReportType = 'Fee Collection Audit';
    } else {
      _reportTypes = [
        'Attendance Ledger',
        'Fee Collection Audit',
        'Examination Pass Analysis',
        'Faculty Workload Matrix',
      ];
      _selectedReportType = 'Attendance Ledger';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.bgColor,
      padding: EdgeInsets.all(30),
      child: Center(
        child: Container(
          constraints: BoxConstraints(maxWidth: 540),
          padding: EdgeInsets.all(40),
          decoration: BoxDecoration(
            color: context.cardColor,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: context.borderColor),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Reports Generation & Download Center',
                style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 8),
              Text(
                'Select report metrics, compile filters, and generate outputs.',
                style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12),
              ),
              SizedBox(height: 30),

              // Report Type
              DropdownButtonFormField<String>(
                value: _selectedReportType,
                dropdownColor: context.cardColor,
                style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Select Report Category',
                  labelStyle: TextStyle(color: context.textMuted),
                ),
                items: _reportTypes
                    .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                    .toList(),
                onChanged: (val) {
                  setState(() => _selectedReportType = val!);
                },
              ),
              SizedBox(height: 20),

              // Export Format
              DropdownButtonFormField<String>(
                value: _selectedFormat,
                dropdownColor: context.cardColor,
                style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'Export Format',
                  labelStyle: TextStyle(color: context.textMuted),
                ),
                items: [
                  DropdownMenuItem(value: 'PDF Document (.pdf)', child: Text('PDF Document (.pdf)')),
                  DropdownMenuItem(value: 'Excel Spreadsheet (.xlsx)', child: Text('Excel Spreadsheet (.xlsx)')),
                  DropdownMenuItem(value: 'CSV Plain Text (.csv)', child: Text('CSV Plain Text (.csv)')),
                ],
                onChanged: (val) {
                  setState(() => _selectedFormat = val!);
                },
              ),
              SizedBox(height: 40),

              // Download Button
              ElevatedButton.icon(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Compiling $_selectedReportType. Download started for $_selectedFormat.')),
                  );
                },
                icon: Icon(Icons.download, size: 18),
                label: Text('Generate & Download', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Color(0xFF3b5998),
                  foregroundColor: context.textPrimary,
                  padding: EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

