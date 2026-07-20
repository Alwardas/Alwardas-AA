import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme_extensions.dart';
import '../../../core/api_config.dart';
import '../../../core/api_constants.dart';
import '../../../widgets/desktop_skeleton_loading.dart';

class DesktopDashboardView extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DesktopDashboardView({super.key, required this.userData});

  @override
  State<DesktopDashboardView> createState() => _DesktopDashboardViewState();
}

class _DesktopDashboardViewState extends State<DesktopDashboardView> {
  bool _isLoading = true;
  bool _isFinanceRole = false;
  Map<String, dynamic>? _financeStats;
  Map<String, dynamic>? _coordinatorStats;

  @override
  void initState() {
    super.initState();
    final role = widget.userData['role']?.toString().toLowerCase() ?? 'staff';
    _isFinanceRole = role == 'accountant' || role == 'accounts manager' || role == 'finance';
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    if (_isFinanceRole) {
      try {
        final res = await ApiConfig.get('${ApiConstants.baseUrl}/api/finance/dashboard-stats');
        if (res.success && res.data != null) {
          _financeStats = res.data;
        }
      } catch (e) {
        debugPrint("Error loading finance dashboard stats: $e");
      }
    } else {
      try {
        final res = await ApiConfig.get('${ApiConstants.baseUrl}/api/coordinator/dashboard-stats');
        if (res.success && res.data != null) {
          _coordinatorStats = res.data is Map<String, dynamic>
              ? (res.data['data'] is Map<String, dynamic> ? res.data['data'] : res.data)
              : null;
        }
      } catch (e) {
        debugPrint("Error loading coordinator dashboard stats: $e");
      }
    }
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  String _formatCurrency(num value) {
    return '₹' + NumberFormat('#,##,###').format(value);
  }

  String _formatStudents() {
    final val = _coordinatorStats?['totalStudents'];
    if (val != null && val is num && val > 0) {
      return NumberFormat('#,##,###').format(val);
    }
    return '0';
  }

  String _formatFaculty() {
    final val = _coordinatorStats?['totalFaculty'];
    if (val != null && val is num && val > 0) {
      return NumberFormat('#,##,###').format(val);
    }
    return '0';
  }

  String _formatAttendance() {
    final val = _coordinatorStats?['attendancePercentage'];
    if (val != null && val is num) {
      return '${val.toDouble().toStringAsFixed(1)}%';
    }
    return '0.0%';
  }

  String _formatActiveCourses() {
    final val = _coordinatorStats?['activeCourses'];
    if (val != null && val is num && val > 0) {
      return val.toString();
    }
    return '0';
  }

  String _formatActiveComplaints() {
    final val = _coordinatorStats?['activeComplaints'];
    if (val != null && val is num && val > 0) {
      return val.toString();
    }
    return '0';
  }

  String _formatCollectedToday() {
    final val = _coordinatorStats?['collectedToday'];
    if (val != null && val is num && val > 0) {
      return _formatCurrency(val);
    }
    return '-';
  }

  String _formatPendingFees() {
    final val = _coordinatorStats?['pendingFees'];
    if (val != null && val is num && val > 0) {
      return _formatCurrency(val);
    }
    return '-';
  }

  String _formatPlacementRate() {
    final val = _coordinatorStats?['placementRate'];
    if (val != null && val is num && val > 0) {
      return '${val.toDouble().toStringAsFixed(1)}%';
    }
    return '-';
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const DesktopSkeletonDashboard();
    }

    if (_isFinanceRole) {
      return _buildFinanceDashboard();
    }

    return _buildGenericDashboard();
  }

  Widget _buildFinanceDashboard() {
    // Fallback/Default values if stats endpoint didn't succeed
    final double collected = _financeStats?['totalFeeCollected']?.toDouble() ?? 452000.0;
    final double demand = _financeStats?['totalFeeDemand']?.toDouble() ?? 1280000.0;
    final double pending = _financeStats?['pendingFees']?.toDouble() ?? 828000.0;
    final double today = _financeStats?['todaysCollection']?.toDouble() ?? 45200.0;
    final double scholarship = _financeStats?['scholarshipAmount']?.toDouble() ?? 150000.0;
    final double fine = _financeStats?['fineAmount']?.toDouble() ?? 24000.0;
    final double collRate = _financeStats?['collectionPercentage']?.toDouble() ?? 35.3;

    final List<dynamic> monthlyData = _financeStats?['monthlyCollection'] ?? [];
    final List<dynamic> deptData = _financeStats?['departmentCollection'] ?? [];

    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & Info banner
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Financial & Accounts Dashboard',
                    style: GoogleFonts.poppins(
                      color: context.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Real-time collection reports, fee demands, and reminders log',
                    style: GoogleFonts.poppins(color: context.textMuted, fontSize: 13),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _loadDashboardData,
                icon: Icon(Icons.refresh, size: 16),
                label: Text('Sync Data', style: GoogleFonts.poppins(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.cardColor,
                  foregroundColor: context.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          SizedBox(height: 30),

          // KPI Cards Grid (Finance Specific)
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.8,
            children: [
              _buildKpiCard("Today's Collection", _formatCurrency(today), Icons.payments_outlined, Colors.cyanAccent),
              _buildKpiCard('Total Fee Demand', _formatCurrency(demand), Icons.receipt_long_outlined, Colors.purpleAccent),
              _buildKpiCard('Total Collected', _formatCurrency(collected), Icons.account_balance_wallet_outlined, Colors.greenAccent),
              _buildKpiCard('Outstanding Dues', _formatCurrency(pending), Icons.pending_actions_outlined, Colors.redAccent),
              _buildKpiCard('Overdue Fines', _formatCurrency(fine), Icons.warning_amber_outlined, Colors.orangeAccent),
              _buildKpiCard('Scholarship Applied', _formatCurrency(scholarship), Icons.card_membership_outlined, Colors.blueAccent),
              _buildKpiCard('Collection Target', '${collRate.toStringAsFixed(1)}%', Icons.track_changes_outlined, Colors.amberAccent),
              _buildKpiCard('Pending Refunds', '3 Requests', Icons.assignment_return_outlined, Colors.pinkAccent),
            ],
          ),
          SizedBox(height: 30),

          // Charts & Analytics Segment
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Monthly Forecast (Line Chart)
              Expanded(
                flex: 2,
                child: Container(
                  height: 380,
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
                        'Monthly Collection Trend',
                        style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text('Historical and forecast fee collections', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11)),
                      SizedBox(height: 24),
                      Expanded(child: _buildFinanceLineChart(monthlyData)),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 20),

              // Fee Collection by Branch (Bar Chart)
              Expanded(
                flex: 2,
                child: Container(
                  height: 380,
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
                        'Revenue Collection by Department',
                        style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text('Comparison of collected fees per engineering division', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11)),
                      SizedBox(height: 24),
                      Expanded(child: _buildFinanceBarChart(deptData)),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 30),

          // Recent Activity Panel (Finance Specific)
          Container(
            width: double.infinity,
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
                  'Recent Financial Stream',
                  style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                _buildActivityRow('Fee Payment', 'Student ADM2026101 paid ₹25,000 semester fees online.', '3 mins ago', Icons.payment, Colors.greenAccent),
                Divider(color: context.borderColor, height: 1),
                _buildActivityRow('Fee Payment', 'Student ECE2026402 paid ₹48,000 tuition fees.', '25 mins ago', Icons.payment, Colors.greenAccent),
                Divider(color: context.borderColor, height: 1),
                _buildActivityRow('Scholarship Approved', 'Dr. B. R. Ambedkar scheme adjustment of ₹15,000 applied for Student EEE2026305.', '1 hour ago', Icons.card_membership, Colors.blueAccent),
                Divider(color: context.borderColor, height: 1),
                _buildActivityRow('Refund Initiated', 'Refund of caution deposit ₹5,000 initiated for Student CSE2022099.', '3 hours ago', Icons.assignment_return_outlined, Colors.purpleAccent),
                Divider(color: context.borderColor, height: 1),
                _buildActivityRow('Fee Reminder Sent', 'Automatic due reminder notifications sent to 12 overdue students.', '5 hours ago', Icons.notifications_active, Colors.orangeAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericDashboard() {
    return SingleChildScrollView(
      physics: BouncingScrollPhysics(),
      padding: EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Greeting & Info banner
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Administrative Overview',
                    style: GoogleFonts.poppins(
                      color: context.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    'Real-time metrics for campus analytics and activities',
                    style: GoogleFonts.poppins(color: context.textMuted, fontSize: 13),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _loadDashboardData,
                icon: Icon(Icons.refresh, size: 16),
                label: Text('Sync Data', style: GoogleFonts.poppins(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.cardColor,
                  foregroundColor: context.textPrimary,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ],
          ),
          SizedBox(height: 30),

          // KPI Cards Grid
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: 4,
            crossAxisSpacing: 20,
            mainAxisSpacing: 20,
            childAspectRatio: 1.8,
            children: [
              _buildKpiCard('Total Students', _formatStudents(), Icons.people, Colors.blueAccent),
              _buildKpiCard('Total Faculty', _formatFaculty(), Icons.badge, Colors.greenAccent),
              _buildKpiCard("Today's Attendance", _formatAttendance(), Icons.done_all, Colors.cyanAccent),
              _buildKpiCard('Active Courses', _formatActiveCourses(), Icons.class_outlined, Colors.purpleAccent),
              _buildKpiCard('Collected Today', _formatCollectedToday(), Icons.payments_outlined, Colors.orangeAccent),
              _buildKpiCard('Pending Fees', _formatPendingFees(), Icons.pending_actions_outlined, Colors.redAccent),
              _buildKpiCard('Placement Rate', _formatPlacementRate(), Icons.trending_up, Colors.pinkAccent),
              _buildKpiCard('Active Complaints', _formatActiveComplaints(), Icons.report_problem_outlined, Colors.amberAccent),
            ],
          ),
          SizedBox(height: 30),

          // Charts & Analytics Segment
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Attendance Trend (Line Chart)
              Expanded(
                flex: 2,
                child: Container(
                  height: 380,
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
                        'Monthly Attendance Trend',
                        style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text('Percentage of student attendance over last 6 months', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11)),
                      SizedBox(height: 24),
                      Expanded(child: _buildGenericLineChart()),
                    ],
                  ),
                ),
              ),
              SizedBox(width: 20),

              // Fee Collection by Branch (Bar Chart)
              Expanded(
                flex: 2,
                child: Container(
                  height: 380,
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
                        'Fee Collection by Branch (Lakhs)',
                        style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 4),
                      Text('Comparing target vs. collected fees per engineering division', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11)),
                      SizedBox(height: 24),
                      Expanded(child: _buildGenericBarChart()),
                    ],
                  ),
                ),
              ),
            ],
          ),
          SizedBox(height: 30),

          // Recent Activity Panel
          Container(
            width: double.infinity,
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
                  'Recent Activity Stream',
                  style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                ),
                SizedBox(height: 16),
                _buildActivityRow('Fee Payment', 'Student ADM2026101 paid ₹25,000 semester fees online.', '3 mins ago', Icons.payment, Colors.greenAccent),
                Divider(color: context.borderColor, height: 1),
                _buildActivityRow('Leave Request', 'Leave request submitted by Dr. V. Rama Rao (HOD - CSE).', '15 mins ago', Icons.leave_bags_at_home, Colors.orangeAccent),
                Divider(color: context.borderColor, height: 1),
                _buildActivityRow('System Update', 'Database optimizer index scheduled run completed.', '1 hour ago', Icons.sync_lock, Colors.blueAccent),
                Divider(color: context.borderColor, height: 1),
                _buildActivityRow('Placement Log', '5 new students added to the TCS recruitment drive.', '3 hours ago', Icons.star, Colors.pinkAccent),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildKpiCard(String title, String value, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      padding: EdgeInsets.all(20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  title,
                  style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: 8),
                Text(
                  value,
                  style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityRow(String title, String desc, String time, IconData icon, Color color) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: 14),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.w600)),
                SizedBox(height: 2),
                Text(desc, style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Text(time, style: GoogleFonts.poppins(color: context.textMuted2, fontSize: 11)),
        ],
      ),
    );
  }

  Widget _buildFinanceLineChart(List<dynamic> monthlyData) {
    if (monthlyData.isEmpty) {
      monthlyData = [
        {'label': 'Jan 2026', 'value': 450000.0},
        {'label': 'Feb 2026', 'value': 620000.0},
        {'label': 'Mar 2026', 'value': 890000.0},
        {'label': 'Apr 2026', 'value': 1200000.0},
        {'label': 'May 2026', 'value': 1540000.0},
        {'label': 'Jun 2026', 'value': 780000.0},
      ];
    }
    final spots = <FlSpot>[];
    double maxVal = 100000.0;
    for (int i = 0; i < monthlyData.length; i++) {
      final val = (monthlyData[i]['value'] ?? 0.0).toDouble();
      if (val > maxVal) maxVal = val;
      spots.add(FlSpot(i.toDouble(), val));
    }

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
                if (value == 0) return Text('');
                if (value >= 1000000) {
                  return Text('${(value / 1000000).toStringAsFixed(1)}M', style: TextStyle(color: context.textMuted, fontSize: 10));
                } else if (value >= 1000) {
                  return Text('${(value / 1000).toStringAsFixed(0)}K', style: TextStyle(color: context.textMuted, fontSize: 10));
                }
                return Text('${value.toInt()}', style: TextStyle(color: context.textMuted, fontSize: 10));
              },
              reservedSize: 38,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < monthlyData.length) {
                  return Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(monthlyData[idx]['label']?.toString().split(' ').first ?? '', style: TextStyle(color: context.textMuted, fontSize: 10)),
                  );
                }
                return Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: (monthlyData.length - 1).toDouble(),
        minY: 0,
        maxY: maxVal * 1.15,
        lineBarsData: [
          LineChartBarData(
            spots: spots,
            isCurved: true,
            color: Colors.blueAccent,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blueAccent.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceBarChart(List<dynamic> deptData) {
    if (deptData.isEmpty) {
      deptData = [
        {'label': 'Computer', 'value': 245000.0},
        {'label': 'ECE', 'value': 180000.0},
        {'label': 'EEE', 'value': 125000.0},
        {'label': 'Mechanical', 'value': 95000.0},
      ];
    }
    final groups = <BarChartGroupData>[];
    double maxVal = 10000.0;
    for (int i = 0; i < deptData.length; i++) {
      final val = (deptData[i]['value'] ?? 0.0).toDouble();
      if (val > maxVal) maxVal = val;
      groups.add(
        BarChartGroupData(
           x: i,
           barRods: [
             BarChartRodData(
               toY: val,
               color: Colors.blueAccent,
               width: 18,
               borderRadius: BorderRadius.circular(4),
             ),
           ],
         ),
      );
    }

    return BarChart(
      BarChartData(
        barGroups: groups,
        gridData: const FlGridData(show: true, drawVerticalLine: false),
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                if (value == 0) return Text('');
                if (value >= 1000000) {
                  return Text('${(value / 1000000).toStringAsFixed(1)}M', style: TextStyle(color: context.textMuted, fontSize: 10));
                } else if (value >= 1000) {
                  return Text('${(value / 1000).toStringAsFixed(0)}K', style: TextStyle(color: context.textMuted, fontSize: 10));
                }
                return Text('${value.toInt()}', style: TextStyle(color: context.textMuted, fontSize: 10));
              },
              reservedSize: 38,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                final idx = value.toInt();
                if (idx >= 0 && idx < deptData.length) {
                  final label = deptData[idx]['label']?.toString() ?? '';
                  final shortLabel = label.length > 8 ? label.substring(0, 8) + '..' : label;
                  return Padding(
                    padding: EdgeInsets.only(top: 4),
                    child: Text(shortLabel, style: TextStyle(color: context.textMuted, fontSize: 10)),
                  );
                }
                return Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        maxY: maxVal * 1.15,
      ),
    );
  }

  Widget _buildGenericLineChart() {
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
                return Text('${value.toInt()}%', style: TextStyle(color: context.textMuted, fontSize: 10));
              },
              reservedSize: 32,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun'];
                if (value.toInt() >= 0 && value.toInt() < months.length) {
                  return Text(months[value.toInt()], style: TextStyle(color: context.textMuted, fontSize: 10));
                }
                return Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
        minX: 0,
        maxX: 5,
        minY: 80,
        maxY: 100,
        lineBarsData: [
          LineChartBarData(
            spots: [
              FlSpot(0, 92),
              FlSpot(1, 95),
              FlSpot(2, 94),
              FlSpot(3, 91),
              FlSpot(4, 96),
              FlSpot(5, 94.2),
            ],
            isCurved: true,
            color: Colors.blueAccent,
            barWidth: 4,
            isStrokeCapRound: true,
            dotData: const FlDotData(show: true),
            belowBarData: BarAreaData(
              show: true,
              color: Colors.blueAccent.withOpacity(0.1),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGenericBarChart() {
    return BarChart(
      BarChartData(
        barGroups: [
          BarChartGroupData(x: 0, barRods: [
            BarChartRodData(toY: 12, color: Colors.greenAccent, width: 14, borderRadius: BorderRadius.circular(4)),
            BarChartRodData(toY: 10, color: Colors.blueAccent, width: 14, borderRadius: BorderRadius.circular(4)),
          ]),
          BarChartGroupData(x: 1, barRods: [
            BarChartRodData(toY: 15, color: Colors.greenAccent, width: 14, borderRadius: BorderRadius.circular(4)),
            BarChartRodData(toY: 13, color: Colors.blueAccent, width: 14, borderRadius: BorderRadius.circular(4)),
          ]),
          BarChartGroupData(x: 2, barRods: [
            BarChartRodData(toY: 8, color: Colors.greenAccent, width: 14, borderRadius: BorderRadius.circular(4)),
            BarChartRodData(toY: 6.5, color: Colors.blueAccent, width: 14, borderRadius: BorderRadius.circular(4)),
          ]),
          BarChartGroupData(x: 3, barRods: [
            BarChartRodData(toY: 10, color: Colors.greenAccent, width: 14, borderRadius: BorderRadius.circular(4)),
            BarChartRodData(toY: 9.8, color: Colors.blueAccent, width: 14, borderRadius: BorderRadius.circular(4)),
          ]),
        ],
        titlesData: FlTitlesData(
          rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                return Text('${value.toInt()}L', style: TextStyle(color: context.textMuted, fontSize: 10));
              },
              reservedSize: 28,
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              getTitlesWidget: (value, meta) {
                const branches = ['CSE', 'ECE', 'EEE', 'MECH'];
                if (value.toInt() >= 0 && value.toInt() < branches.length) {
                  return Text(branches[value.toInt()], style: TextStyle(color: context.textMuted, fontSize: 10));
                }
                return Text('');
              },
            ),
          ),
        ),
        borderData: FlBorderData(show: false),
      ),
    );
  }
}

