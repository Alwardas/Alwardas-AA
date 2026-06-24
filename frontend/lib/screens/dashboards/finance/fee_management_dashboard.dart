import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'dart:math' as math;
import 'package:file_picker/file_picker.dart';
import 'dart:convert';

import '../../../core/api_config.dart';
import '../../../core/api_constants.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../auth/login_screen.dart';
import '../../../core/services/auth_service.dart';

class FeeManagementDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const FeeManagementDashboard({super.key, required this.userData});

  @override
  State<FeeManagementDashboard> createState() => _FeeManagementDashboardState();
}

class _FeeManagementDashboardState extends State<FeeManagementDashboard> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool _isLoadingStats = true;
  Map<String, dynamic>? _stats;
  String _userRole = 'Admin';
  String _userName = 'Administrator';
  String _userId = '';

  @override
  void initState() {
    super.initState();
    _userRole = widget.userData['role']?.toString() ?? 'Admin';
    _userName = widget.userData['full_name']?.toString() ?? 'Administrator';
    _userId = widget.userData['id']?.toString() ?? widget.userData['login_id']?.toString() ?? '';

    // Determine tab count based on role permissions
    // Accountant: Analytics, Student Roster, Bulk, Excel, Workflows, Audits
    // Admin: Analytics, Student Roster, Bulk, Excel, Workflows, Audits
    // Principal: Analytics, Student Roster, Workflows, Audits
    _tabController = TabController(length: _getTabCount(), vsync: this);
    _fetchStats();
  }

  int _getTabCount() {
    if (_userRole.toLowerCase() == 'principal') {
      return 4; // Analytics, Student Roster, Workflows, Audits
    }
    return 6; // Accountant/Admin: Analytics, Student Roster, Bulk, Excel, Workflows, Audits
  }

  List<Tab> _getTabs() {
    final List<Tab> tabs = [
      const Tab(icon: Icon(Icons.analytics_outlined), text: 'Analytics'),
      const Tab(icon: Icon(Icons.people_alt_outlined), text: 'Student Roster'),
    ];

    if (_userRole.toLowerCase() != 'principal') {
      tabs.add(const Tab(icon: Icon(Icons.library_add_outlined), text: 'Bulk Adjust'));
      tabs.add(const Tab(icon: Icon(Icons.upload_file_outlined), text: 'Excel Import'));
    }

    tabs.add(const Tab(icon: Icon(Icons.rule_folder_outlined), text: 'Workflows'));
    tabs.add(const Tab(icon: Icon(Icons.history_edu_outlined), text: 'Audits'));
    return tabs;
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchStats() async {
    setState(() => _isLoadingStats = true);
    try {
      final res = await ApiConfig.get('${ApiConstants.baseUrl}/api/finance/dashboard-stats');
      if (res.success && res.data != null) {
        setState(() {
          _stats = res.data;
          _isLoadingStats = false;
        });
      } else {
        setState(() => _isLoadingStats = false);
      }
    } catch (e) {
      debugPrint("Error fetching dashboard stats: $e");
      setState(() => _isLoadingStats = false);
    }
  }

  void _logout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : const Color(0xFF1F2937);
    final cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Fee Transparency System',
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 22, color: textColor),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh Stats',
            onPressed: _fetchStats,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'Logout',
            onPressed: _logout,
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: themeProvider.isDarkMode ? Colors.cyan : const Color(0xFF3B5998),
          unselectedLabelColor: Colors.grey,
          indicatorColor: themeProvider.isDarkMode ? Colors.cyan : const Color(0xFF3B5998),
          tabs: _getTabs(),
        ),
      ),
      body: _isLoadingStats
          ? const Center(child: CircularProgressIndicator())
          : TabBarView(
              controller: _tabController,
              children: _getTabViews(cardColor, textColor, isDark),
            ),
    );
  }

  List<Widget> _getTabViews(Color cardColor, Color textColor, bool isDark) {
    final List<Widget> views = [
      _buildAnalyticsTab(cardColor, textColor, isDark),
      StudentRosterTab(cardColor: cardColor, textColor: textColor, isDark: isDark, userRole: _userRole, userId: _userId),
    ];

    if (_userRole.toLowerCase() != 'principal') {
      views.add(BulkAdjustTab(cardColor: cardColor, textColor: textColor, isDark: isDark, userId: _userId));
      views.add(ExcelImportTab(cardColor: cardColor, textColor: textColor, isDark: isDark, userId: _userId));
    }

    views.add(WorkflowsTab(cardColor: cardColor, textColor: textColor, isDark: isDark, userRole: _userRole, userId: _userId));
    views.add(AuditsTab(cardColor: cardColor, textColor: textColor, isDark: isDark));
    return views;
  }

  Widget _buildAnalyticsTab(Color cardColor, Color textColor, bool isDark) {
    if (_stats == null) {
      return const Center(child: Text("Unable to load financial analytics."));
    }

    final double demand = _stats!['totalFeeDemand']?.toDouble() ?? 0.0;
    final double collected = _stats!['totalFeeCollected']?.toDouble() ?? 0.0;
    final double pending = _stats!['pendingFees']?.toDouble() ?? 0.0;
    final double today = _stats!['todaysCollection']?.toDouble() ?? 0.0;
    final double scholarship = _stats!['scholarshipAmount']?.toDouble() ?? 0.0;
    final double fine = _stats!['fineAmount']?.toDouble() ?? 0.0;
    final double collRate = _stats!['collectionPercentage']?.toDouble() ?? 0.0;

    final List<dynamic> monthlyData = _stats!['monthlyCollection'] ?? [];
    final List<dynamic> deptData = _stats!['departmentCollection'] ?? [];
    final List<dynamic> courseData = _stats!['courseCollection'] ?? [];

    return RefreshIndicator(
      onRefresh: _fetchStats,
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          // Row of Overview Statistics Cards
          LayoutBuilder(
            builder: (context, constraints) {
              final crossCount = constraints.maxWidth > 800 ? 4 : 2;
              return GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: crossCount,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.5,
                ),
                children: [
                  _buildStatCard(
                    "Total Demand",
                    "₹${NumberFormat('#,##,###').format(demand)}",
                    Icons.account_balance,
                    Colors.indigoAccent,
                    cardColor,
                    textColor,
                  ),
                  _buildStatCard(
                    "Total Collected",
                    "₹${NumberFormat('#,##,###').format(collected)}",
                    Icons.check_circle_outline,
                    Colors.green,
                    cardColor,
                    textColor,
                  ),
                  _buildStatCard(
                    "Pending Fees",
                    "₹${NumberFormat('#,##,###').format(pending)}",
                    Icons.pending_actions,
                    Colors.orange,
                    cardColor,
                    textColor,
                  ),
                  _buildStatCard(
                    "Today's Collection",
                    "₹${NumberFormat('#,##,###').format(today)}",
                    Icons.today,
                    Colors.cyan,
                    cardColor,
                    textColor,
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 24),

          // Collection Rate & Additional Metrics Row
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                flex: 3,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(
                      color: isDark ? Colors.white.withValues(alpha: 0.22) : const Color(0xFFD1D5DB),
                      width: 1.2,
                    ),
                    boxShadow: [
                      BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 15)
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Collection Rate",
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: textColor),
                      ),
                      const SizedBox(height: 20),
                      Row(
                        children: [
                          Stack(
                            alignment: Alignment.center,
                            children: [
                              SizedBox(
                                width: 100,
                                height: 100,
                                child: CircularProgressIndicator(
                                  value: collRate / 100.0,
                                  strokeWidth: 12,
                                  backgroundColor: Colors.grey.withValues(alpha: 0.15),
                                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.green),
                                ),
                              ),
                              Text(
                                "${collRate.toStringAsFixed(1)}%",
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20, color: textColor),
                              ),
                            ],
                          ),
                          const SizedBox(width: 28),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                _buildMetricRow("Scholarship Granted", "₹${NumberFormat('#,##,###').format(scholarship)}", Colors.indigoAccent, textColor),
                                const SizedBox(height: 8),
                                _buildMetricRow("Fines Collected", "₹${NumberFormat('#,##,###').format(fine)}", Colors.redAccent, textColor),
                                const SizedBox(height: 8),
                                _buildMetricRow("Student Count", "${_stats!['totalStudents'] ?? 0}", Colors.orange, textColor),
                              ],
                            ),
                          )
                        ],
                      )
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Custom Painted Charts Section
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth > 900) {
                // Side by side charts
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _buildChartCard(
                        "Monthly Collection Trend",
                        CustomPaint(
                          size: const Size(double.infinity, 220),
                          painter: LineChartPainter(monthlyData, isDark),
                        ),
                        cardColor,
                        textColor,
                        isDark,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildChartCard(
                        "Department Distribution",
                        CustomPaint(
                          size: const Size(double.infinity, 220),
                          painter: BarChartPainter(deptData, isDark),
                        ),
                        cardColor,
                        textColor,
                        isDark,
                      ),
                    ),
                  ],
                );
              } else {
                // Stacked charts
                return Column(
                  children: [
                    _buildChartCard(
                      "Monthly Collection Trend",
                      CustomPaint(
                        size: const Size(double.infinity, 200),
                        painter: LineChartPainter(monthlyData, isDark),
                      ),
                      cardColor,
                      textColor,
                      isDark,
                    ),
                    const SizedBox(height: 16),
                    _buildChartCard(
                      "Department Distribution",
                      CustomPaint(
                        size: const Size(double.infinity, 200),
                        painter: BarChartPainter(deptData, isDark),
                      ),
                      cardColor,
                      textColor,
                      isDark,
                    ),
                  ],
                );
              }
            },
          ),
          const SizedBox(height: 16),
          // Category Distribution Chart
          _buildChartCard(
            "Fee Category / Course Distribution",
            Row(
              children: [
                Expanded(
                  child: CustomPaint(
                    size: const Size(180, 180),
                    painter: DoughnutChartPainter(courseData, isDark),
                  ),
                ),
                const SizedBox(width: 24),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: courseData.take(5).map((point) {
                      final label = point['label']?.toString() ?? '';
                      final value = point['value']?.toDouble() ?? 0.0;
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: Row(
                          children: [
                            Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: _getChartColor(courseData.indexOf(point)),
                                shape: BoxShape.circle,
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                "$label (₹${NumberFormat('#,##,###').format(value)})",
                                style: GoogleFonts.poppins(fontSize: 12, color: textColor),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
            cardColor,
            textColor,
            isDark,
          ),
        ],
      ),
      ),
    );
  }

  Widget _buildStatCard(String title, String val, IconData icon, Color color, Color bg, Color text) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: bg == Colors.white
              ? const Color(0xFFD1D5DB)
              : Colors.white.withValues(alpha: 0.22),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: bg == Colors.white ? 0.05 : 0.2), blurRadius: 10)
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title, style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[500], fontWeight: FontWeight.w500)),
                const SizedBox(height: 8),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(val, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: text)),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 28),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricRow(String label, String value, Color color, Color text) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
            const SizedBox(width: 10),
            Text(label, style: GoogleFonts.poppins(fontSize: 13, color: text)),
          ],
        ),
        Text(value, style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: text)),
      ],
    );
  }

  Widget _buildChartCard(String title, Widget chart, Color bg, Color text, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: isDark ? Colors.white.withValues(alpha: 0.22) : const Color(0xFFD1D5DB),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05), blurRadius: 15)
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: text)),
          const SizedBox(height: 20),
          chart,
        ],
      ),
    );
  }
}

// Line Chart Painter
class LineChartPainter extends CustomPainter {
  final List<dynamic> data;
  final bool isDark;

  LineChartPainter(this.data, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final paint = Paint()
      ..color = Colors.cyan
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05)
      ..strokeWidth = 1;

    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    // Draw horizontal grid lines
    const gridLines = 4;
    final gridSpacing = size.height / gridLines;
    for (int i = 0; i <= gridLines; i++) {
      final y = gridSpacing * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Find max value
    double maxVal = 0.0;
    for (var point in data) {
      final val = point['value']?.toDouble() ?? 0.0;
      if (val > maxVal) maxVal = val;
    }
    if (maxVal == 0) maxVal = 1;

    final stepX = size.width / (data.length - 1);
    final path = Path();
    final fillPath = Path();

    // Map point to coords
    Offset getCoord(int index) {
      final x = stepX * index;
      final val = data[index]['value']?.toDouble() ?? 0.0;
      final y = size.height - (val / maxVal * (size.height - 20));
      return Offset(x, y);
    }

    final start = getCoord(0);
    path.moveTo(start.dx, start.dy);
    fillPath.moveTo(start.dx, size.height);
    fillPath.lineTo(start.dx, start.dy);

    for (int i = 1; i < data.length; i++) {
      final p = getCoord(i);
      path.lineTo(p.dx, p.dy);
      fillPath.lineTo(p.dx, p.dy);
    }

    fillPath.lineTo(size.width, size.height);
    fillPath.close();

    // Draw area fill
    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.cyan.withOpacity(0.3), Colors.cyan.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    // Draw dots and labels
    for (int i = 0; i < data.length; i++) {
      final p = getCoord(i);
      canvas.drawCircle(p, 5, Paint()..color = Colors.cyanAccent);
      canvas.drawCircle(p, 3, Paint()..color = Colors.white);

      // Label
      final label = data[i]['label']?.toString() ?? '';
      textPainter.text = TextSpan(
        text: label,
        style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(p.dx - textPainter.width / 2, size.height - 15));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Bar Chart Painter
class BarChartPainter extends CustomPainter {
  final List<dynamic> data;
  final bool isDark;

  BarChartPainter(this.data, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    final gridPaint = Paint()
      ..color = isDark ? Colors.white.withOpacity(0.07) : Colors.black.withOpacity(0.05)
      ..strokeWidth = 1;

    // Grid lines
    const gridLines = 4;
    final gridSpacing = size.height / gridLines;
    for (int i = 0; i <= gridLines; i++) {
      final y = gridSpacing * i;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    double maxVal = 0.0;
    for (var point in data) {
      final val = point['value']?.toDouble() ?? 0.0;
      if (val > maxVal) maxVal = val;
    }
    if (maxVal == 0) maxVal = 1;

    final barWidth = (size.width / data.length) * 0.6;
    final spacing = (size.width / data.length) * 0.4;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < data.length; i++) {
      final val = data[i]['value']?.toDouble() ?? 0.0;
      final h = val / maxVal * (size.height - 40);
      final x = spacing / 2 + (barWidth + spacing) * i;
      final y = size.height - h - 20;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, h),
        const Radius.circular(6),
      );

      final barPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6B48FF), Color(0xFF1EC9F8)],
        ).createShader(Rect.fromLTWH(x, y, barWidth, h))
        ..style = PaintingStyle.fill;

      canvas.drawRRect(rect, barPaint);

      // Label
      final label = data[i]['label']?.toString() ?? '';
      textPainter.text = TextSpan(
        text: label.length > 8 ? '${label.substring(0, 6)}..' : label,
        style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + (barWidth - textPainter.width) / 2, size.height - 15));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

// Doughnut Chart Painter
class DoughnutChartPainter extends CustomPainter {
  final List<dynamic> data;
  final bool isDark;

  DoughnutChartPainter(this.data, this.isDark);

  @override
  void paint(Canvas canvas, Size size) {
    if (data.isEmpty) return;

    double total = 0.0;
    for (var point in data) {
      total += point['value']?.toDouble() ?? 0.0;
    }
    if (total == 0) total = 1;

    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 10;
    final rect = Rect.fromCircle(center: center, radius: radius);

    double startAngle = -math.pi / 2;

    for (int i = 0; i < data.length; i++) {
      final val = data[i]['value']?.toDouble() ?? 0.0;
      final sweepAngle = (val / total) * 2 * math.pi;

      final paint = Paint()
        ..color = _getChartColor(i)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 24;

      canvas.drawArc(rect, startAngle, sweepAngle, false, paint);
      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

Color _getChartColor(int index) {
  const colors = [
    Colors.tealAccent,
    Colors.purpleAccent,
    Colors.orangeAccent,
    Colors.pinkAccent,
    Colors.blueAccent,
    Colors.greenAccent,
    Colors.cyanAccent,
  ];
  return colors[index % colors.length];
}

// ------------------- TABS IMPLEMENTATIONS -------------------

// Tab 2: Student Ledger Roster
class StudentRosterTab extends StatefulWidget {
  final Color cardColor;
  final Color textColor;
  final bool isDark;
  final String userRole;
  final String userId;

  const StudentRosterTab({
    super.key,
    required this.cardColor,
    required this.textColor,
    required this.isDark,
    required this.userRole,
    required this.userId,
  });

  @override
  State<StudentRosterTab> createState() => _StudentRosterTabState();
}

class _StudentRosterTabState extends State<StudentRosterTab> {
  bool _isLoading = false;
  List<dynamic> _students = [];
  int _currentPage = 1;
  int _totalPages = 1;
  int _totalCount = 0;
  final int _limit = 10;

  final TextEditingController _searchController = TextEditingController();
  String _selectedBranch = 'All';
  String _selectedYear = 'All';
  String _selectedStatus = 'All';

  final List<String> _branches = ['All', 'Computer Engineering', 'Electronics & Communication', 'Mechanical Engineering', 'Civil Engineering', 'Electrical Engineering'];
  final List<String> _years = ['All', '1st Year', '2nd Year', '3rd Year', '4th Year'];
  final List<String> _statuses = ['All', 'Cleared', 'Unpaid', 'Partially Paid'];

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() => _isLoading = true);
    try {
      final Map<String, String> queryParams = {
        'page': _currentPage.toString(),
        'limit': _limit.toString(),
      };

      if (_searchController.text.isNotEmpty) {
        final query = _searchController.text.trim();
        // Check if ID or name
        if (RegExp(r'^\d').hasMatch(query)) {
          queryParams['studentId'] = query;
        } else {
          queryParams['studentName'] = query;
        }
      }

      if (_selectedBranch != 'All') queryParams['department'] = _selectedBranch;
      if (_selectedYear != 'All') queryParams['year'] = _selectedYear;
      if (_selectedStatus != 'All') queryParams['feeStatus'] = _selectedStatus;

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/finance/students').replace(queryParameters: queryParams);
      final res = await ApiConfig.get(uri.toString());

      if (res.success && res.data != null) {
        setState(() {
          _students = res.data['students'] ?? [];
          _totalCount = res.data['totalCount'] ?? 0;
          _totalPages = (_totalCount / _limit).ceil();
          if (_totalPages == 0) _totalPages = 1;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching student roster: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Roster Filters Row
        Padding(
          padding: const EdgeInsets.all(16),
          child: Wrap(
            spacing: 12,
            runSpacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 250,
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: widget.textColor),
                  decoration: InputDecoration(
                    hintText: "Search Name / ID...",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                  ),
                  onSubmitted: (_) {
                    setState(() => _currentPage = 1);
                    _fetchStudents();
                  },
                ),
              ),
              DropdownButton<String>(
                value: _selectedBranch,
                dropdownColor: widget.cardColor,
                style: TextStyle(color: widget.textColor),
                items: _branches.map((b) => DropdownMenuItem(value: b, child: Text(b))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedBranch = val!;
                    _currentPage = 1;
                  });
                  _fetchStudents();
                },
              ),
              DropdownButton<String>(
                value: _selectedYear,
                dropdownColor: widget.cardColor,
                style: TextStyle(color: widget.textColor),
                items: _years.map((y) => DropdownMenuItem(value: y, child: Text(y))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedYear = val!;
                    _currentPage = 1;
                  });
                  _fetchStudents();
                },
              ),
              DropdownButton<String>(
                value: _selectedStatus,
                dropdownColor: widget.cardColor,
                style: TextStyle(color: widget.textColor),
                items: _statuses.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                onChanged: (val) {
                  setState(() {
                    _selectedStatus = val!;
                    _currentPage = 1;
                  });
                  _fetchStudents();
                },
              ),
              ElevatedButton(
                onPressed: () {
                  setState(() => _currentPage = 1);
                  _fetchStudents();
                },
                child: const Text("Apply"),
              )
            ],
          ),
        ),

        // List Grid
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _students.isEmpty
                  ? const Center(child: Text("No student fee records found."))
                  : ListView.builder(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      itemCount: _students.length,
                      itemBuilder: (ctx, index) {
                        final s = _students[index];
                        final double total = s['totalFee']?.toDouble() ?? 0.0;
                        final double paid = s['paidAmount']?.toDouble() ?? 0.0;
                        final double pending = s['pendingAmount']?.toDouble() ?? 0.0;
                        final status = s['status']?.toString() ?? 'Pending';
                        final isCleared = status.toLowerCase().contains('clear');

                        return Card(
                          color: widget.cardColor,
                          margin: const EdgeInsets.only(bottom: 12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          child: ListTile(
                            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                            title: Text(
                              s['studentName'] ?? 'No Name',
                              style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: widget.textColor),
                            ),
                            subtitle: Text("ID: ${s['studentId']} | ${s['department'] ?? ''}"),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                Text("₹${NumberFormat('#,##,###').format(total)}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: widget.textColor)),
                                const SizedBox(height: 4),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: (isCleared ? Colors.green : Colors.orange).withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    isCleared ? "Cleared" : "Pending ₹${NumberFormat('#,##,###').format(pending)}",
                                    style: TextStyle(color: isCleared ? Colors.green : Colors.orange, fontSize: 11, fontWeight: FontWeight.bold),
                                  ),
                                )
                              ],
                            ),
                            onTap: () => _showLedgerDetail(s['studentId']),
                          ),
                        );
                      },
                    ),
        ),

        // Pagination Row
        Container(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Showing ${(_currentPage - 1) * _limit + 1} - ${math.min(_currentPage * _limit, _totalCount)} of $_totalCount"),
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back_ios),
                    onPressed: _currentPage > 1
                        ? () {
                            setState(() => _currentPage--);
                            _fetchStudents();
                          }
                        : null,
                  ),
                  Text("$_currentPage / $_totalPages"),
                  IconButton(
                    icon: const Icon(Icons.arrow_forward_ios),
                    onPressed: _currentPage < _totalPages
                        ? () {
                            setState(() => _currentPage++);
                            _fetchStudents();
                          }
                        : null,
                  ),
                ],
              )
            ],
          ),
        )
      ],
    );
  }

  void _showLedgerDetail(String studentId) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(
            maxWidth: 700,
            maxHeight: 700,
          ),
          padding: const EdgeInsets.all(28),
          child: LedgerDetailModal(
            studentId: studentId,
            userRole: widget.userRole,
            userId: widget.userId,
            onRefreshList: _fetchStudents,
          ),
        ),
      ),
    );
  }
}

// Ledger Detail Modal Helper
class LedgerDetailModal extends StatefulWidget {
  final String studentId;
  final String userRole;
  final String userId;
  final VoidCallback onRefreshList;

  const LedgerDetailModal({
    super.key,
    required this.studentId,
    required this.userRole,
    required this.userId,
    required this.onRefreshList,
  });

  @override
  State<LedgerDetailModal> createState() => _LedgerDetailModalState();
}

class _LedgerDetailModalState extends State<LedgerDetailModal> {
  bool _isLoading = true;
  Map<String, dynamic>? _ledger;

  @override
  void initState() {
    super.initState();
    _fetchLedger();
  }

  Future<void> _fetchLedger() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiConfig.get('${ApiConstants.baseUrl}/api/finance/student/${widget.studentId}/ledger');
      if (res.success && res.data != null) {
        setState(() {
          _ledger = res.data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching ledger: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_ledger == null) {
      return const Center(child: Text("Ledger detail not found."));
    }

    final double total = _ledger!['totalFee']?.toDouble() ?? 0.0;
    final double paid = _ledger!['paidAmount']?.toDouble() ?? 0.0;
    final double pending = _ledger!['pendingAmount']?.toDouble() ?? 0.0;
    final double scholarship = _ledger!['scholarshipAmount']?.toDouble() ?? 0.0;
    final double fine = _ledger!['fineAmount']?.toDouble() ?? 0.0;

    final breakdown = List<dynamic>.from(_ledger!['breakdown'] ?? []);
    final payments = List<dynamic>.from(_ledger!['paymentHistory'] ?? []);
    final changes = List<dynamic>.from(_ledger!['changeHistory'] ?? []);

    final bool isAdmin = widget.userRole.toLowerCase() == 'admin';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_ledger!['studentName'] ?? 'Ledger Details', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)),
                Text("ID: ${widget.studentId} | Dept: ${_ledger!['department'] ?? ''}"),
              ],
            ),
            IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.pop(context),
            )
          ],
        ),
        const Divider(height: 24),
        Expanded(
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Financial Overview
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _buildLedgerMetric("Demand", total, Colors.indigoAccent),
                    _buildLedgerMetric("Paid", paid, Colors.green),
                    _buildLedgerMetric("Pending", pending, Colors.orange),
                    _buildLedgerMetric("Scholarship", scholarship, Colors.purple),
                  ],
                ),
                const SizedBox(height: 24),

                // Breakdown list
                _buildSectionHeader("Fee Breakdown"),
                const SizedBox(height: 8),
                Table(
                  columnWidths: const {
                    0: FlexColumnWidth(2),
                    1: FlexColumnWidth(1),
                    2: FlexColumnWidth(1),
                    3: FlexColumnWidth(1.5),
                  },
                  children: [
                    TableRow(
                      decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1)),
                      children: [
                        _tableCell("Category", isHeader: true),
                        _tableCell("Amount", isHeader: true),
                        _tableCell("Scholarship", isHeader: true),
                        _tableCell("Remarks", isHeader: true),
                      ],
                    ),
                    ...breakdown.map((item) => TableRow(
                          children: [
                            _tableCell(item['category'] ?? ''),
                            _tableCell("₹${NumberFormat('#,###').format(item['amount'] ?? 0.0)}"),
                            _tableCell("₹${NumberFormat('#,###').format(item['scholarship'] ?? 0.0)}"),
                            _tableCell(item['remarks'] ?? ''),
                          ],
                        )),
                  ],
                ),
                const SizedBox(height: 24),

                // Payment History
                _buildSectionHeader("Payment Receipts"),
                const SizedBox(height: 8),
                payments.isEmpty
                    ? const Padding(padding: EdgeInsets.all(8.0), child: Text("No simulated payments completed yet."))
                    : Table(
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1)),
                            children: [
                              _tableCell("Receipt No", isHeader: true),
                              _tableCell("Amount", isHeader: true),
                              _tableCell("Method", isHeader: true),
                              _tableCell("Date", isHeader: true),
                            ],
                          ),
                          ...payments.map((receipt) {
                            final date = DateTime.tryParse(receipt['transactionDate'] ?? '');
                            final dateStr = date != null ? DateFormat('dd/MM/yyyy').format(date) : '';
                            return TableRow(
                              children: [
                                _tableCell(receipt['receiptNumber'] ?? ''),
                                _tableCell("₹${NumberFormat('#,###').format(receipt['amount'] ?? 0.0)}"),
                                _tableCell(receipt['paymentMode'] ?? ''),
                                _tableCell(dateStr),
                              ],
                            );
                          }),
                        ],
                      ),
                const SizedBox(height: 24),

                // Change/Adjustment Logs
                _buildSectionHeader("Adjustment Audits"),
                const SizedBox(height: 8),
                changes.isEmpty
                    ? const Padding(padding: EdgeInsets.all(8.0), child: Text("No adjustments logged for this student."))
                    : Table(
                        children: [
                          TableRow(
                            decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1)),
                            children: [
                              _tableCell("Category", isHeader: true),
                              _tableCell("Prev", isHeader: true),
                              _tableCell("New", isHeader: true),
                              _tableCell("Reason", isHeader: true),
                              _tableCell("Actor", isHeader: true),
                            ],
                          ),
                          ...changes.map((log) => TableRow(
                                children: [
                                  _tableCell(log['category'] ?? ''),
                                  _tableCell("₹${NumberFormat('#,###').format(log['previousAmount'] ?? 0.0)}"),
                                  _tableCell("₹${NumberFormat('#,###').format(log['newAmount'] ?? 0.0)}"),
                                  _tableCell(log['reason'] ?? ''),
                                  _tableCell(log['updatedByName'] ?? ''),
                                ],
                              )),
                        ],
                      ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Bottom Actions Bar
        Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [
            ElevatedButton.icon(
              icon: const Icon(Icons.payment),
              label: const Text("Simulate Payment"),
              style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
              onPressed: _showSimulatePaymentDialog,
            ),
            if (isAdmin) ...[
              const SizedBox(width: 12),
              ElevatedButton.icon(
                icon: const Icon(Icons.edit_note),
                label: const Text("Adjust Fee"),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.indigoAccent, foregroundColor: Colors.white),
                onPressed: _showAdjustFeeDialog,
              )
            ]
          ],
        )
      ],
    );
  }

  Widget _buildLedgerMetric(String label, double val, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        const SizedBox(height: 4),
        Text("₹${NumberFormat('#,##,###').format(val)}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: color)),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15));
  }

  Widget _tableCell(String text, {bool isHeader = false}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: isHeader ? 12 : 11,
        ),
      ),
    );
  }

  void _showSimulatePaymentDialog() {
    final amountController = TextEditingController();
    final remarkController = TextEditingController();
    String method = 'Net Banking';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Simulate Student Payment"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: "Amount (₹)"),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: method,
              decoration: const InputDecoration(labelText: "Payment Mode"),
              items: ['Net Banking', 'UPI', 'Debit/Credit Card', 'Cash']
                  .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                  .toList(),
              onChanged: (val) => method = val!,
            ),
            TextField(
              controller: remarkController,
              decoration: const InputDecoration(labelText: "Remarks (Optional)"),
            )
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final double? amt = double.tryParse(amountController.text);
              if (amt == null || amt <= 0) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Invalid amount")));
                return;
              }
              Navigator.pop(ctx);
              _submitSimulatedPayment(amt, method, remarkController.text);
            },
            child: const Text("Pay"),
          )
        ],
      ),
    );
  }

  Future<void> _submitSimulatedPayment(double amount, String mode, String remarks) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiConfig.post(
        '${ApiConstants.baseUrl}/api/finance/pay-simulated',
        body: {
          'studentId': widget.studentId,
          'amount': amount,
          'paymentMode': mode,
          'remarks': remarks.isNotEmpty ? remarks : null,
        },
      );

      if (res.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Receipt simulated successfully")));
        }
        widget.onRefreshList();
        _fetchLedger();
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
        }
      }
    } catch (e) {
      debugPrint("Simulated payment failed: $e");
      setState(() => _isLoading = false);
    }
  }

  void _showAdjustFeeDialog() {
    final amountController = TextEditingController();
    final scholarController = TextEditingController(text: "0");
    final fineController = TextEditingController(text: "0");
    final reasonController = TextEditingController();
    String category = 'Tuition Fee';

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Single Student Fee Adjustment"),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<String>(
                value: category,
                decoration: const InputDecoration(labelText: "Category"),
                items: ['Tuition Fee', 'Lab Fee', 'Exam Fee', 'Transport Fee']
                    .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                    .toList(),
                onChanged: (val) => category = val!,
              ),
              TextField(
                controller: amountController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "New Demand Amount (₹)"),
              ),
              TextField(
                controller: scholarController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Scholarship Offset (₹)"),
              ),
              TextField(
                controller: fineController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: "Fine Offset (₹)"),
              ),
              TextField(
                controller: reasonController,
                decoration: const InputDecoration(labelText: "Reason for Modification"),
              )
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final double? amt = double.tryParse(amountController.text);
              final double? sch = double.tryParse(scholarController.text);
              final double? fne = double.tryParse(fineController.text);

              if (amt == null || sch == null || fne == null || reasonController.text.trim().isEmpty) {
                ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("All fields are required")));
                return;
              }

              Navigator.pop(ctx);
              _submitSingleAdjustment(category, amt, sch, fne, reasonController.text.trim());
            },
            child: const Text("Submit"),
          )
        ],
      ),
    );
  }

  Future<void> _submitSingleAdjustment(String category, double amt, double sch, double fne, String reason) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiConfig.post(
        '${ApiConstants.baseUrl}/api/finance/student/${widget.studentId}/update',
        body: {
          'category': category,
          'amount': amt,
          'scholarship': sch,
          'fine': fne,
          'reason': reason,
          'updatedBy': widget.userId,
        },
      );

      if (res.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Modification applied / queued successfully")));
        }
        widget.onRefreshList();
        _fetchLedger();
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
        }
      }
    } catch (e) {
      debugPrint("Single adjustment submit failed: $e");
      setState(() => _isLoading = false);
    }
  }
}

// Tab 3: Bulk Adjustments Tab
class BulkAdjustTab extends StatefulWidget {
  final Color cardColor;
  final Color textColor;
  final bool isDark;
  final String userId;

  const BulkAdjustTab({
    super.key,
    required this.cardColor,
    required this.textColor,
    required this.isDark,
    required this.userId,
  });

  @override
  State<BulkAdjustTab> createState() => _BulkAdjustTabState();
}

class _BulkAdjustTabState extends State<BulkAdjustTab> {
  final _formKey = GlobalKey<FormState>();
  bool _isLoading = false;

  String _scope = 'Department';
  final List<String> _scopes = ['Department', 'Year', 'College', 'Section'];

  final _targetValueController = TextEditingController();
  final _amountController = TextEditingController();
  final _reasonController = TextEditingController();

  String _operationType = 'Add Fee';
  final List<String> _operations = ['Add Fee', 'Reduce Fee', 'Apply Scholarship', 'Add Fine', 'Fee Adjustment'];

  String _category = 'Tuition Fee';
  final List<String> _categories = ['Tuition Fee', 'Lab Fee', 'Exam Fee', 'Transport Fee'];

  Map<String, dynamic>? _previewData;

  Future<void> _previewBulk() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _previewData = null;
    });

    try {
      final res = await ApiConfig.post(
        '${ApiConstants.baseUrl}/api/finance/bulk-adjust/preview',
        body: {
          'scope': _scope,
          'targetValue': _targetValueController.text.trim().isNotEmpty ? _targetValueController.text.trim() : null,
          'operationType': _operationType,
          'category': _category,
          'amount': double.parse(_amountController.text.trim()),
          'reason': _reasonController.text.trim(),
          'createdBy': widget.userId,
        },
      );

      if (res.success && res.data != null) {
        setState(() {
          _previewData = res.data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
        }
      }
    } catch (e) {
      debugPrint("Error previewing bulk adjust: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitBulk() async {
    if (_previewData == null) return;
    setState(() => _isLoading = true);

    try {
      final res = await ApiConfig.post(
        '${ApiConstants.baseUrl}/api/finance/bulk-adjust/submit',
        body: {
          'scope': _scope,
          'targetValue': _targetValueController.text.trim().isNotEmpty ? _targetValueController.text.trim() : null,
          'operationType': _operationType,
          'category': _category,
          'amount': double.parse(_amountController.text.trim()),
          'reason': _reasonController.text.trim(),
          'createdBy': widget.userId,
        },
      );

      if (res.success) {
        setState(() {
          _previewData = null;
          _targetValueController.clear();
          _amountController.clear();
          _reasonController.clear();
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Bulk adjustment workflow submitted successfully!")));
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
        }
      }
    } catch (e) {
      debugPrint("Error submitting bulk adjustment: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Initiate Bulk Adjustments", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: widget.textColor)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _scope,
                    dropdownColor: widget.cardColor,
                    style: TextStyle(color: widget.textColor),
                    decoration: const InputDecoration(labelText: "Adjustment Scope"),
                    items: _scopes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                    onChanged: (val) => setState(() => _scope = val!),
                  ),
                ),
                SizedBox(
                  width: 250,
                  child: TextFormField(
                    controller: _targetValueController,
                    style: TextStyle(color: widget.textColor),
                    decoration: const InputDecoration(
                      labelText: "Target Value (e.g. 'Computer Engineering')",
                      hintText: "Leave blank for College-wide",
                    ),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _operationType,
                    dropdownColor: widget.cardColor,
                    style: TextStyle(color: widget.textColor),
                    decoration: const InputDecoration(labelText: "Operation"),
                    items: _operations.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                    onChanged: (val) => setState(() => _operationType = val!),
                  ),
                ),
                SizedBox(
                  width: 200,
                  child: DropdownButtonFormField<String>(
                    value: _category,
                    dropdownColor: widget.cardColor,
                    style: TextStyle(color: widget.textColor),
                    decoration: const InputDecoration(labelText: "Category"),
                    items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                    onChanged: (val) => setState(() => _category = val!),
                  ),
                ),
                SizedBox(
                  width: 150,
                  child: TextFormField(
                    controller: _amountController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: widget.textColor),
                    decoration: const InputDecoration(labelText: "Amount (₹)"),
                    validator: (val) {
                      if (val == null || double.tryParse(val) == null) return "Required double";
                      return null;
                    },
                  ),
                ),
                SizedBox(
                  width: 400,
                  child: TextFormField(
                    controller: _reasonController,
                    style: TextStyle(color: widget.textColor),
                    decoration: const InputDecoration(labelText: "Justification Reason"),
                    validator: (val) {
                      if (val == null || val.trim().isEmpty) return "Required";
                      return null;
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                ElevatedButton.icon(
                  icon: const Icon(Icons.preview),
                  label: const Text("Generate Preview"),
                  onPressed: _isLoading ? null : _previewBulk,
                ),
                const SizedBox(width: 16),
                if (_previewData != null)
                  ElevatedButton.icon(
                    icon: const Icon(Icons.send),
                    label: const Text("Submit Staged Changes"),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                    onPressed: _isLoading ? null : _submitBulk,
                  ),
              ],
            ),
            const SizedBox(height: 28),
            if (_isLoading) const Center(child: CircularProgressIndicator()),
            if (_previewData != null) ...[
              const Divider(),
              const SizedBox(height: 16),
              Text("Differential Review Dashboard", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 20,
                runSpacing: 20,
                children: [
                  _buildPreviewMetric("Students Affected", "${_previewData!['affectedStudents']}"),
                  _buildPreviewMetric("Current Grand Total", "₹${NumberFormat('#,##,###').format(_previewData!['currentTotalAmount'])}"),
                  _buildPreviewMetric("Projected Grand Total", "₹${NumberFormat('#,##,###').format(_previewData!['updatedTotalAmount'])}"),
                  _buildPreviewMetric("Net Impact Margin", "₹${NumberFormat('#,##,###').format(_previewData!['difference'])}", isDiff: true, isNegative: _previewData!['difference'] < 0),
                ],
              )
            ]
          ],
        ),
      ),
    );
  }

  Widget _buildPreviewMetric(String label, String value, {bool isDiff = false, bool isNegative = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      decoration: BoxDecoration(
        color: widget.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
          const SizedBox(height: 6),
          Text(
            value,
            style: GoogleFonts.poppins(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: isDiff ? (isNegative ? Colors.indigoAccent : Colors.redAccent) : widget.textColor,
            ),
          ),
        ],
      ),
    );
  }
}

// Tab 4: Excel Import Simulator Tab
class ExcelImportTab extends StatefulWidget {
  final Color cardColor;
  final Color textColor;
  final bool isDark;
  final String userId;

  const ExcelImportTab({
    super.key,
    required this.cardColor,
    required this.textColor,
    required this.isDark,
    required this.userId,
  });

  @override
  State<ExcelImportTab> createState() => _ExcelImportTabState();
}

class _ExcelImportTabState extends State<ExcelImportTab> {
  bool _isLoading = false;
  String _fileName = 'simulated_fees.csv';
  final _csvController = TextEditingController(
    text: "2026-CS-01, 5000.0, Tuition Fee, Merit Offset\n"
        "2026-CS-02, -2000.0, Tuition Fee, Merit Scholarship\n"
        "INVALID_ID_TEST, 1500.0, Lab Fee, Error Verification",
  );

  Map<String, dynamic>? _previewData;

  void _loadPreset() {
    _csvController.text = "2026-CS-01, 4000.0, Tuition Fee, Q3 Segment Correction\n"
        "2026-CS-02, 1000.0, Lab Fee, Equipment Premium\n"
        "2026-CS-03, -1500.0, Tuition Fee, Sports Discount";
  }

  Future<void> _validateExcel() async {
    if (_csvController.text.trim().isEmpty) return;
    setState(() {
      _isLoading = true;
      _previewData = null;
    });

    // Parse CSV lines into ExcelRow list
    final List<Map<String, dynamic>> rows = [];
    final lines = _csvController.text.trim().split('\n');

    for (var line in lines) {
      final parts = line.split(',');
      if (parts.length >= 3) {
        final double? amt = double.tryParse(parts[1].trim());
        rows.add({
          'studentId': parts[0].trim(),
          'amount': amt ?? 0.0,
          'feeCategory': parts[2].trim(),
          'reason': parts.length >= 4 ? parts[3].trim() : 'Excel Import Adjustment',
        });
      }
    }

    try {
      final res = await ApiConfig.post(
        '${ApiConstants.baseUrl}/api/finance/excel-upload/preview',
        body: {
          'fileName': _fileName,
          'rows': rows,
          'createdBy': widget.userId,
        },
      );

      if (res.success && res.data != null) {
        setState(() {
          _previewData = res.data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
        }
      }
    } catch (e) {
      debugPrint("Error validating Excel: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _submitExcel() async {
    if (_previewData == null) return;
    setState(() => _isLoading = true);

    final List<Map<String, dynamic>> rows = [];
    final lines = _csvController.text.trim().split('\n');

    for (var line in lines) {
      final parts = line.split(',');
      if (parts.length >= 3) {
        final double? amt = double.tryParse(parts[1].trim());
        rows.add({
          'studentId': parts[0].trim(),
          'amount': amt ?? 0.0,
          'feeCategory': parts[2].trim(),
          'reason': parts.length >= 4 ? parts[3].trim() : 'Excel Import Adjustment',
        });
      }
    }

    try {
      final res = await ApiConfig.post(
        '${ApiConstants.baseUrl}/api/finance/excel-upload/submit',
        body: {
          'fileName': _fileName,
          'rows': rows,
          'createdBy': widget.userId,
        },
      );

      if (res.success) {
        setState(() {
          _previewData = null;
          _csvController.clear();
          _isLoading = false;
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Excel workflow submitted successfully!")));
        }
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
        }
      }
    } catch (e) {
      debugPrint("Error submitting excel: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<dynamic> validations = _previewData != null ? _previewData!['validationResults'] ?? [] : [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("Excel/CSV Spreadsheet Import Simulator", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: widget.textColor)),
          const SizedBox(height: 8),
          Text(
            "Paste CSV spreadsheet records below to validate constraints (format: student_id, amount, category, reason).",
            style: TextStyle(color: Colors.grey[500], fontSize: 12),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _csvController,
                  maxLines: 5,
                  style: GoogleFonts.firaCode(fontSize: 12, color: widget.textColor),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    filled: true,
                    fillColor: widget.cardColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              ElevatedButton.icon(
                icon: const Icon(Icons.rule),
                label: const Text("Validate Data"),
                onPressed: _isLoading ? null : _validateExcel,
              ),
              const SizedBox(width: 12),
              TextButton.icon(
                icon: const Icon(Icons.settings_backup_restore),
                label: const Text("Load Demo Sheet"),
                onPressed: _loadPreset,
              ),
              const Spacer(),
              if (_previewData != null && _previewData!['isValidOverall'] == true)
                ElevatedButton.icon(
                  icon: const Icon(Icons.cloud_upload_outlined),
                  label: const Text("Submit Valid Rows"),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                  onPressed: _isLoading ? null : _submitExcel,
                )
            ],
          ),
          const SizedBox(height: 24),
          if (_isLoading) const Center(child: CircularProgressIndicator()),
          if (_previewData != null) ...[
            const Divider(),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Spreadsheet Overview Summary", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15)),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: (_previewData!['isValidOverall'] ? Colors.green : Colors.red).withOpacity(0.15),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _previewData!['isValidOverall'] ? "Ready - All Rows Valid" : "Rejected - Row Errors Found",
                    style: TextStyle(color: _previewData!['isValidOverall'] ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                _buildSummaryItem("Total Rows", "${_previewData!['totalStudents']}"),
                _buildSummaryItem("Net Diff Offset", "₹${NumberFormat('#,##,###').format(_previewData!['difference'])}"),
              ],
            ),
            const SizedBox(height: 20),
            Table(
              columnWidths: const {
                0: FlexColumnWidth(0.8),
                1: FlexColumnWidth(1.5),
                2: FlexColumnWidth(2),
                3: FlexColumnWidth(1),
                4: FlexColumnWidth(2.5),
              },
              children: [
                TableRow(
                  decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1)),
                  children: [
                    _tableCell("Row", isHeader: true),
                    _tableCell("Student ID", isHeader: true),
                    _tableCell("Student Name", isHeader: true),
                    _tableCell("Valid", isHeader: true),
                    _tableCell("Validation Diagnostic", isHeader: true),
                  ],
                ),
                ...validations.map((row) {
                  final bool isValid = row['isValid'] ?? false;
                  return TableRow(
                    children: [
                      _tableCell("${(row['rowIndex'] as int) + 1}"),
                      _tableCell(row['studentId'] ?? ''),
                      _tableCell(row['studentName'] ?? '-'),
                      _tableCell(isValid ? "✔" : "✘", color: isValid ? Colors.green : Colors.red),
                      _tableCell(row['errorMessage'] ?? 'Passed constraints verification', color: isValid ? Colors.grey : Colors.redAccent),
                    ],
                  );
                }),
              ],
            )
          ]
        ],
      ),
    );
  }

  Widget _buildSummaryItem(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: widget.cardColor, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: widget.textColor)),
        ],
      ),
    );
  }

  Widget _tableCell(String text, {bool isHeader = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Text(
        text,
        style: TextStyle(
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
          fontSize: isHeader ? 12 : 11,
          color: color,
        ),
      ),
    );
  }
}

// Tab 5: Workflows Pipeline Tab
class WorkflowsTab extends StatefulWidget {
  final Color cardColor;
  final Color textColor;
  final bool isDark;
  final String userRole;
  final String userId;

  const WorkflowsTab({
    super.key,
    required this.cardColor,
    required this.textColor,
    required this.isDark,
    required this.userRole,
    required this.userId,
  });

  @override
  State<WorkflowsTab> createState() => _WorkflowsTabState();
}

class _WorkflowsTabState extends State<WorkflowsTab> {
  bool _isLoading = false;
  List<dynamic> _workflows = [];

  @override
  void initState() {
    super.initState();
    _fetchWorkflows();
  }

  Future<void> _fetchWorkflows() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiConfig.get('${ApiConstants.baseUrl}/api/finance/approvals');
      if (res.success && res.data != null) {
        setState(() {
          _workflows = res.data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching approvals: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _actionWorkflow(String id, String action) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiConfig.post(
        '${ApiConstants.baseUrl}/api/finance/approvals/$id/action',
        body: {
          'action': action,
          'userId': widget.userId,
        },
      );

      if (res.success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Workflow status updated to: $action")));
        }
        _fetchWorkflows();
      } else {
        setState(() => _isLoading = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
        }
      }
    } catch (e) {
      debugPrint("Error performing action on workflow: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _isLoading
        ? const Center(child: CircularProgressIndicator())
        : _workflows.isEmpty
            ? const Center(child: Text("No pending approval requests in pipeline."))
            : ListView.builder(
                padding: const EdgeInsets.all(16),
                itemCount: _workflows.length,
                itemBuilder: (ctx, index) {
                  final w = _workflows[index];
                  final double diff = w['totalDifference']?.toDouble() ?? 0.0;
                  final int count = w['studentCount'] ?? 1;

                  // Evaluate if Principal Sign-off needed (>10L or >100 students)
                  final bool requiresPrincipal = count > 100 || diff.abs() > 1000000;
                  final bool isPrincipal = widget.userRole.toLowerCase() == 'principal';
                  final bool isAllowedToApprove = requiresPrincipal ? isPrincipal : (widget.userRole.toLowerCase() == 'admin' || isPrincipal);

                  return Card(
                    color: widget.cardColor,
                    margin: const EdgeInsets.only(bottom: 16),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                "Workflow: ${w['operationType']}",
                                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 15, color: widget.textColor),
                              ),
                              if (requiresPrincipal)
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(color: Colors.redAccent.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                  child: const Text(
                                    "Principal Sign-Off Required",
                                    style: TextStyle(color: Colors.redAccent, fontSize: 10, fontWeight: FontWeight.bold),
                                  ),
                                )
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text("Justification: ${w['reason'] ?? ''}", style: TextStyle(color: widget.textColor)),
                          const SizedBox(height: 4),
                          Text("Requester: ${w['createdByName'] ?? 'Staff'} | Status: ${w['status']}"),
                          const SizedBox(height: 12),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Students Affected", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                  Text("$count", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: widget.textColor)),
                                ],
                              ),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text("Net Diff Margin", style: TextStyle(color: Colors.grey[500], fontSize: 11)),
                                  Text("₹${NumberFormat('#,##,###').format(diff)}", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 14, color: diff < 0 ? Colors.green : Colors.red)),
                                ],
                              ),
                              Row(
                                children: [
                                  TextButton(
                                    onPressed: isAllowedToApprove ? () => _actionWorkflow(w['id'], 'REJECT') : null,
                                    style: TextButton.styleFrom(foregroundColor: Colors.red),
                                    child: const Text("Reject"),
                                  ),
                                  const SizedBox(width: 8),
                                  ElevatedButton(
                                    onPressed: isAllowedToApprove ? () => _actionWorkflow(w['id'], 'APPROVE') : null,
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: Colors.white),
                                    child: Text(requiresPrincipal && isPrincipal ? "Sign-Off & Approve" : "Approve"),
                                  ),
                                ],
                              )
                            ],
                          )
                        ],
                      ),
                    ),
                  );
                },
              );
  }
}

// Tab 6: Audit Trails Tab
class AuditsTab extends StatefulWidget {
  final Color cardColor;
  final Color textColor;
  final bool isDark;

  const AuditsTab({
    super.key,
    required this.cardColor,
    required this.textColor,
    required this.isDark,
  });

  @override
  State<AuditsTab> createState() => _AuditsTabState();
}

class _AuditsTabState extends State<AuditsTab> {
  bool _isLoading = false;
  List<dynamic> _audits = [];

  @override
  void initState() {
    super.initState();
    _fetchAudits();
  }

  Future<void> _fetchAudits() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiConfig.get('${ApiConstants.baseUrl}/api/finance/audit-trails');
      if (res.success && res.data != null) {
        setState(() {
          _audits = res.data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching audit trails: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text("Immutable Audit Ledger", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: widget.textColor)),
              IconButton(icon: const Icon(Icons.refresh), onPressed: _fetchAudits),
            ],
          ),
        ),
        Expanded(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : _audits.isEmpty
                  ? const Center(child: Text("No audit records recorded."))
                  : SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: DataTable(
                          columns: const [
                            DataColumn(label: Text("Date")),
                            DataColumn(label: Text("Actor")),
                            DataColumn(label: Text("Operation")),
                            DataColumn(label: Text("Students")),
                            DataColumn(label: Text("Status")),
                            DataColumn(label: Text("Justification")),
                          ],
                          rows: _audits.map((a) {
                            final date = DateTime.tryParse(a['timestamp'] ?? '');
                            final dateStr = date != null ? DateFormat('dd/MM HH:mm').format(date) : '';
                            final status = a['status']?.toString() ?? 'Approved';
                            final isApproved = status.toLowerCase() == 'approved' || status.toLowerCase() == 'completed';

                            return DataRow(
                              cells: [
                                DataCell(Text(dateStr)),
                                DataCell(Text(a['createdByName'] ?? '')),
                                DataCell(Text(a['operationType'] ?? '')),
                                DataCell(Text("${a['studentCount'] ?? 1}")),
                                DataCell(
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: (isApproved ? Colors.green : Colors.red).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      status,
                                      style: TextStyle(color: isApproved ? Colors.green : Colors.red, fontSize: 10, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ),
                                DataCell(Text(a['reason'] ?? '')),
                              ],
                            );
                          }).toList(),
                        ),
                      ),
                    ),
        ),
      ],
    );
  }
}
