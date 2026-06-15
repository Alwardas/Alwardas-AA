import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';

class DesktopPrincipalAnalyticsView extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DesktopPrincipalAnalyticsView({super.key, required this.userData});

  @override
  State<DesktopPrincipalAnalyticsView> createState() => _DesktopPrincipalAnalyticsViewState();
}

class _DesktopPrincipalAnalyticsViewState extends State<DesktopPrincipalAnalyticsView> {
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
                    'Principal Executive Analytics Center',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Evaluate campus divisions performance, placement stats, and configure institutional alerts',
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main layout split
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Department Metrics comparison table & placements trend
                Expanded(
                  flex: 3,
                  child: Column(
                    children: [
                      // Department comparison
                      Container(
                        height: 240,
                        decoration: BoxDecoration(
                          color: const Color(0xFF1E293B),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.white10),
                        ),
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Department Performance Index',
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 14),
                            Expanded(child: _buildDepartmentPerformanceTable()),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Placements trend
                      Expanded(
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
                                'Historical Campus Placements Trend',
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 20),
                              Expanded(child: _buildLineChart()),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                // 2. Proactive Warnings & Alerts center
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
                          'Proactive Security & Compliance Alerts',
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Automated warning triggers generated by system anomalies',
                          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
                        ),
                        const SizedBox(height: 24),
                        Expanded(
                          child: ListView(
                            children: [
                              _buildWarningCard('Low Attendance Risk', '14 Students in Mechanical division under 75% attendance.', Colors.redAccent),
                              _buildWarningCard('Outstanding Fee Liability', '₹12,45,000 pending collections. Risk index: Medium.', Colors.orangeAccent),
                              _buildWarningCard('Academic Progression Warning', 'HOD Computer Engineering flagged syllabus completion delays in CSE Sec-B.', Colors.amberAccent),
                            ],
                          ),
                        ),
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

  Widget _buildDepartmentPerformanceTable() {
    final List<Map<String, dynamic>> depts = [
      {'name': 'Computer Engineering', 'pass': '91%', 'att': '94.2%', 'place': '88.2%'},
      {'name': 'Electronics & Communication', 'pass': '88%', 'att': '91.8%', 'place': '84.5%'},
      {'name': 'Mechanical Engineering', 'pass': '82%', 'att': '88.4%', 'place': '74.2%'},
    ];

    return Column(
      children: [
        Container(
          color: const Color(0xFF0F172A).withOpacity(0.4),
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: const Row(
            children: [
              Expanded(flex: 3, child: Text('Department', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Pass %', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Attendance %', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
              Expanded(flex: 2, child: Text('Placement %', style: TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
            ],
          ),
        ),
        const Divider(color: Colors.white10, height: 1),
        Expanded(
          child: ListView.builder(
            itemCount: depts.length,
            itemBuilder: (context, index) {
              final item = depts[index];
              return Container(
                height: 42,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: const BoxDecoration(
                  border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
                ),
                child: Row(
                  children: [
                    Expanded(flex: 3, child: Text(item['name'], style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                    Expanded(flex: 2, child: Text(item['pass'], style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12))),
                    Expanded(flex: 2, child: Text(item['att'], style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12))),
                    Expanded(flex: 2, child: Text(item['place'], style: GoogleFonts.poppins(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold))),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildWarningCard(String title, String details, Color color) {
    return Card(
      color: const Color(0xFF0F172A),
      margin: const EdgeInsets.only(bottom: 16),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(Icons.warning_amber_rounded, color: color, size: 20),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 4),
                  Text(details, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLineChart() {
    return LineChart(
      LineChartData(
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}%', style: const TextStyle(color: Colors.white38, fontSize: 10));
              },
              reservedSize: 32,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const years = ['2023', '2024', '2025', '2026'];
                if (value.toInt() >= 0 && value.toInt() < years.length) {
                  return Text(years[value.toInt()], style: const TextStyle(color: Colors.white38, fontSize: 10));
                }
                return const Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 3,
        minY: 60,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: const [
              FlSpot(0, 78),
              FlSpot(1, 82),
              FlSpot(2, 85),
              FlSpot(3, 88.5),
            ],
            isCurved: true,
            color: Colors.greenAccent,
            barWidth: 4,
            belowBarData: BarAreaData(
              show: true,
              color: Colors.greenAccent.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }
}
