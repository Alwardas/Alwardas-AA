import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/theme_extensions.dart';

class DesktopAttendanceView extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DesktopAttendanceView({super.key, required this.userData});

  @override
  State<DesktopAttendanceView> createState() => _DesktopAttendanceViewState();
}

class _DesktopAttendanceViewState extends State<DesktopAttendanceView> {
  String _selectedBranch = 'Computer Engineering';
  String _selectedSemester = 'Semester 1';

  final List<String> _branches = [
    'Computer Engineering',
    'Electronics & Communication Engineering',
    'Electrical & Electronics Engineering',
    'Mechanical Engineering',
    'Civil Engineering'
  ];

  final List<String> _semesters = ['Semester 1', 'Semester 2', 'Semester 3', 'Semester 4', 'Semester 5'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.bgColor,
      padding: EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Attendance Analytics & Tracking',
                    style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Monitor branch performance, attendance compliance, and student risk assessments',
                    style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildDropdown('Branch', _selectedBranch, _branches, (val) {
                    setState(() => _selectedBranch = val!);
                  }),
                  SizedBox(width: 12),
                  _buildDropdown('Semester', _selectedSemester, _semesters, (val) {
                    setState(() => _selectedSemester = val!);
                  }),
                ],
              ),
            ],
          ),
          SizedBox(height: 24),

          // Heatmaps & Performance Row
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Attendance Heatmap Grid
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor),
                    ),
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Weekly Attendance Heatmap',
                          style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Colored grids showing daily branch attendance percentages',
                          style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11),
                        ),
                        SizedBox(height: 30),
                        Expanded(child: _buildHeatmapGrid()),
                      ],
                    ),
                  ),
                ),
                SizedBox(width: 20),

                // 2. Risk Indicators (Low Attendance list)
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor),
                    ),
                    padding: EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Low Attendance Alerts (<75%)',
                          style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Students who require alert triggers to parents',
                          style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11),
                        ),
                        SizedBox(height: 20),
                        Expanded(child: _buildLowAttendanceList()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeatmapGrid() {
    final List<String> days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
    final List<String> subjects = ['Maths', 'Java OOP', 'Data Struct', 'Networks', 'COA', 'Web Tech'];

    return GridView.builder(
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: days.length + 1,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 2.0,
      ),
      itemCount: (subjects.length + 1) * (days.length + 1),
      itemBuilder: (context, index) {
        final row = index ~/ (days.length + 1);
        final col = index % (days.length + 1);

        if (row == 0 && col == 0) {
          return Center(child: Text(''));
        }

        // Days Headers (First Row)
        if (row == 0) {
          return Center(
            child: Text(
              days[col - 1],
              style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          );
        }

        // Subjects Labels (First Column)
        if (col == 0) {
          return Align(
            alignment: Alignment.centerLeft,
            child: Text(
              subjects[row - 1],
              style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis,
            ),
          );
        }

        // Heatmap Cells
        // Generate mock percentage values based on subject/day index
        final double percentage = 70.0 + ((row * 7 + col * 13) % 28);
        Color cellColor;
        if (percentage >= 90) {
          cellColor = Colors.green.withOpacity(0.7);
        } else if (percentage >= 75) {
          cellColor = Colors.orange.withOpacity(0.7);
        } else {
          cellColor = Colors.red.withOpacity(0.7);
        }

        return Container(
          decoration: BoxDecoration(
            color: cellColor,
            borderRadius: BorderRadius.circular(6),
          ),
          child: Center(
            child: Text(
              '${percentage.toInt()}%',
              style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
            ),
          ),
        );
      },
    );
  }

  Widget _buildLowAttendanceList() {
    final List<Map<String, dynamic>> lowAttenders = [
      {'name': 'Rohan Das', 'id': 'ADM2026114', 'percent': '68%', 'branch': 'CSE'},
      {'name': 'Swapna Sen', 'id': 'ADM2026118', 'percent': '72%', 'branch': 'ECE'},
      {'name': 'Nikhil Gowda', 'id': 'ADM2026122', 'percent': '64%', 'branch': 'MECH'},
      {'name': 'Karthik Raja', 'id': 'ADM2026131', 'percent': '71%', 'branch': 'CIVIL'},
    ];

    return ListView.builder(
      itemCount: lowAttenders.length,
      itemBuilder: (context, index) {
        final student = lowAttenders[index];
        return Card(
          color: context.bgColor,
          margin: EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: EdgeInsets.all(16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        student['name'],
                        style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 2),
                      Text(
                        '${student['id']} • ${student['branch']}',
                        style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Row(
                  children: [
                    Text(
                      student['percent'],
                      style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(width: 14),
                    IconButton(
                      icon: Icon(Icons.mail_outline, color: Colors.blueAccent, size: 18),
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('Attendance alert notification queued for ${student['name']}\'s parent.')),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildDropdown(String label, String val, List<String> options, ValueChanged<String?> onChanged) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.borderColor),
      ),
      padding: EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: val,
          dropdownColor: context.cardColor,
          style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12),
          onChanged: onChanged,
          items: options.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }
}

