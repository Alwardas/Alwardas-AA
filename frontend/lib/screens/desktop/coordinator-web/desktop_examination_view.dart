import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

class DesktopExaminationView extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DesktopExaminationView({super.key, required this.userData});

  @override
  State<DesktopExaminationView> createState() => _DesktopExaminationViewState();
}

class _DesktopExaminationViewState extends State<DesktopExaminationView> {
  String _selectedSubject = 'Mathematics';
  String _selectedExamType = 'Internal Exam 1';

  final List<String> _subjects = ['Mathematics', 'Java Programming', 'Data Structures', 'Web Technologies'];
  final List<String> _examTypes = ['Internal Exam 1', 'Internal Exam 2', 'Semester End Exam'];

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(30),
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
                    'Examinations & Grading Management',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Monitor internal scores, final grades distribution, pass percentage metrics, and GPA rankings',
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
              Row(
                children: [
                  _buildDropdown('Subject', _selectedSubject, _subjects, (val) {
                    setState(() => _selectedSubject = val!);
                  }),
                  const SizedBox(width: 12),
                  _buildDropdown('Exam Type', _selectedExamType, _examTypes, (val) {
                    setState(() => _selectedExamType = val!);
                  }),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Core Data Cards
          Row(
            children: [
              _buildMetricCard('Subject Pass Rate', '89.4%', Icons.check_circle_outline, Colors.greenAccent),
              const SizedBox(width: 20),
              _buildMetricCard('Highest Score', '98 / 100', Icons.emoji_events_outlined, Colors.amberAccent),
              const SizedBox(width: 20),
              _buildMetricCard('Class Average GPA', '8.15 / 10', Icons.grade_outlined, Colors.blueAccent),
            ],
          ),
          const SizedBox(height: 24),

          // Marks and Grades Split Layout
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Marks List Table
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                            'Student Score Ledger',
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                          ),
                        ),
                        const Divider(color: Colors.white10, height: 1),
                        // Column Headers
                        Container(
                          color: const Color(0xFF0F172A).withOpacity(0.4),
                          height: 40,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Expanded(flex: 2, child: Text('ID', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                              Expanded(flex: 3, child: Text('Name', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                              Expanded(flex: 1, child: Text('Score', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                              Expanded(flex: 1, child: Text('Grade', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                            ],
                          ),
                        ),
                        const Divider(color: Colors.white10, height: 1),
                        // List items
                        Expanded(
                          child: ListView.builder(
                            itemCount: _getMockMarks().length,
                            itemBuilder: (context, index) {
                              final item = _getMockMarks()[index];
                              return Container(
                                height: 48,
                                padding: const EdgeInsets.symmetric(horizontal: 20),
                                decoration: const BoxDecoration(
                                  border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
                                ),
                                child: Row(
                                  children: [
                                    Expanded(flex: 2, child: Text(item['id'], style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12))),
                                    Expanded(flex: 3, child: Text(item['name'], style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                                    Expanded(flex: 1, child: Text('${item['score']}', style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12))),
                                    Expanded(
                                      flex: 1,
                                      child: Text(
                                        item['grade'],
                                        style: GoogleFonts.poppins(
                                          color: item['grade'] == 'F' ? Colors.redAccent : Colors.greenAccent,
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
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
                const SizedBox(width: 20),

                // 2. Grade Distribution (Pie Chart)
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Grade Distribution Distribution',
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Visual representation of current subject grades',
                          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
                        ),
                        const SizedBox(height: 40),
                        Expanded(child: _buildPieChart()),
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

  List<Map<String, dynamic>> _getMockMarks() {
    return [
      {'id': 'ADM2026101', 'name': 'Aravind Swamy', 'score': 94, 'grade': 'A+'},
      {'id': 'ADM2026102', 'name': 'Divya Reddy', 'score': 88, 'grade': 'A'},
      {'id': 'ADM2026103', 'name': 'Bala Krishna', 'score': 74, 'grade': 'B'},
      {'id': 'ADM2026104', 'name': 'Charan Teja', 'score': 45, 'grade': 'C'},
      {'id': 'ADM2026105', 'name': 'Eshwar Rao', 'score': 32, 'grade': 'F'},
      {'id': 'ADM2026106', 'name': 'Haritha Kumari', 'score': 92, 'grade': 'A+'},
    ];
  }

  Widget _buildMetricCard(String title, String val, IconData icon, Color color) {
    return Expanded(
      child: Container(
        decoration: BoxDecoration(
          color: const Color(0xFF1E293B),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.white10),
        ),
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(icon, color: color, size: 22),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
                  const SizedBox(height: 4),
                  Text(val, style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart() {
    return PieChart(
      PieChartData(
        sectionsSpace: 4,
        centerSpaceRadius: 50,
        sections: [
          PieChartSectionData(color: Colors.greenAccent, value: 40, title: 'A+ (40%)', radius: 45, titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          PieChartSectionData(color: Colors.blueAccent, value: 35, title: 'A (35%)', radius: 45, titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          PieChartSectionData(color: Colors.orangeAccent, value: 15, title: 'B (15%)', radius: 45, titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
          PieChartSectionData(color: Colors.redAccent, value: 10, title: 'F (10%)', radius: 45, titleStyle: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildDropdown(String label, String val, List<String> options, ValueChanged<String?> onChanged) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: val,
          dropdownColor: const Color(0xFF1E293B),
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
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
