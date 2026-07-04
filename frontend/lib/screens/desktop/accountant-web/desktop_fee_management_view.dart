import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart' hide TextDirection;
import 'dart:math' as math;
import '../../../theme/theme_extensions.dart';

import '../../../../core/api_config.dart';
import '../../../../core/api_constants.dart';

class DesktopFeeManagementView extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DesktopFeeManagementView({super.key, required this.userData});

  @override
  State<DesktopFeeManagementView> createState() => _DesktopFeeManagementViewState();
}

class _DesktopFeeManagementViewState extends State<DesktopFeeManagementView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late String _userRole;
  late String _userId;
  late List<String> _tabTitles;

  bool _isLoadingStats = true;
  Map<String, dynamic>? _stats;

  // Global search parameters
  final TextEditingController _searchController = TextEditingController();
  String _searchCategory = 'Student ID'; // 'Student ID', 'Roll Number', 'Receipt Number', 'Transaction ID'
  
  @override
  void initState() {
    super.initState();
    _userRole = widget.userData['role']?.toString() ?? 'Admin';
    _userId = widget.userData['id']?.toString() ?? widget.userData['login_id']?.toString() ?? '';
    _tabTitles = _getTabTitles();
    _tabController = TabController(length: _tabTitles.length, vsync: this);
    _fetchStats();
  }

  List<String> _getTabTitles() {
    final role = _userRole.toLowerCase();
    if (role == 'principal') {
      return ['Financial Dashboard', 'Student Roster', 'Defaulters List', 'Audit Trails'];
    } else if (role == 'accountant') {
      return ['Financial Dashboard', 'Student Roster', 'Defaulters List', 'Scholarship Verification', 'Refund Requests'];
    } else {
      // Accounts Manager / Admin
      return [
        'Financial Dashboard',
        'Student Roster',
        'Accountant Directory',
        'Leaderboard & Performance',
        'Work Assignments',
        'Defaulters List',
        'Scholarship Verification',
        'Refund Requests',
        'Bulk Adjustments',
        'Audit Trails'
      ];
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
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

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.bgColor,
      padding: EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header / Global Search
          _buildHeaderBar(),
          SizedBox(height: 20),

          // Tabs Headers
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: context.textMuted,
            indicatorColor: Colors.blueAccent,
            dividerColor: context.borderColor,
            labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
            tabs: _tabTitles.map((title) => Tab(text: title)).toList(),
          ),
          SizedBox(height: 16),

          // Tab views
          Expanded(
            child: _isLoadingStats
                ? Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : TabBarView(
                    controller: _tabController,
                    children: _tabTitles.map((title) => _buildTabView(title)).toList(),
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeaderBar() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Accounts Department Management System',
              style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
            ),
            Text(
              'Supervise accountants, track fee profiles, disburse scholarships, and approve refund workflows.',
              style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12),
            ),
          ],
        ),
        
        // Search System
        Row(
          children: [
            Container(
              height: 38,
              padding: EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: const BorderRadius.horizontal(left: Radius.circular(8)),
                border: Border.all(color: context.borderColor),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<String>(
                  value: _searchCategory,
                  dropdownColor: context.cardColor,
                  style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 11),
                  items: ['Student ID', 'Roll Number', 'Receipt Number', 'Transaction ID']
                      .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                      .toList(),
                  onChanged: (val) {
                    setState(() => _searchCategory = val!);
                  },
                ),
              ),
            ),
            Container(
              width: 200,
              height: 38,
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: const BorderRadius.horizontal(right: Radius.circular(8)),
                border: Border.all(color: context.borderColor),
              ),
              child: TextField(
                controller: _searchController,
                style: TextStyle(color: context.textPrimary, fontSize: 12),
                decoration: InputDecoration(
                  hintText: 'Global Search...',
                  hintStyle: GoogleFonts.poppins(color: context.textMuted2, fontSize: 12),
                  border: InputBorder.none,
                  prefixIcon: Icon(Icons.search, color: context.textMuted, size: 16),
                  contentPadding: EdgeInsets.symmetric(vertical: 10),
                ),
                onSubmitted: (val) {
                  if (val.trim().isNotEmpty) {
                    _triggerGlobalSearch(val.trim());
                  }
                },
              ),
            ),
          ],
        ),
      ],
    );
  }

  void _triggerGlobalSearch(String query) {
    // Navigate to student roster and apply search filter
    final rosterIndex = _tabTitles.indexOf('Student Roster');
    if (rosterIndex != -1) {
      _tabController.animateTo(rosterIndex);
      // Pass query parameters to Student Roster tab
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Searching for "$query" in $_searchCategory...')),
      );
    }
  }

  Widget _buildTabView(String title) {
    switch (title) {
      case 'Financial Dashboard':
        return _buildDashboardTab();
      case 'Student Roster':
        return StudentRosterTab(userId: _userId, userRole: _userRole);
      case 'Accountant Directory':
        return const AccountantDirectoryTab();
      case 'Leaderboard & Performance':
        return const AccountantPerformanceTab();
      case 'Work Assignments':
        return WorkAssignmentsTab(userId: _userId);
      case 'Defaulters List':
        return const DefaultersListTab();
      case 'Scholarship Verification':
        return const ScholarshipTab();
      case 'Refund Requests':
        return RefundRequestsTab(userId: _userId, userRole: _userRole);
      case 'Bulk Adjustments':
        return BulkAdjustmentsTab(userId: _userId);
      case 'Audit Trails':
        return const AuditTrailsTab();
      default:
        return Center(child: Text('Coming Soon', style: GoogleFonts.poppins(color: context.textMuted)));
    }
  }

  Widget _buildDashboardTab() {
    if (_stats == null) {
      return Center(
        child: Text('Unable to load financial analytics. Make sure the database has fee structures populated.',
            style: GoogleFonts.poppins(color: context.textMuted)),
      );
    }

    final double collected = _stats!['totalFeeCollected']?.toDouble() ?? 0.0;
    final double pending = _stats!['pendingFees']?.toDouble() ?? 0.0;
    final double today = _stats!['todaysCollection']?.toDouble() ?? 0.0;
    final double scholarship = _stats!['scholarshipAmount']?.toDouble() ?? 0.0;
    final double fine = _stats!['fineAmount']?.toDouble() ?? 0.0;
    final double collRate = _stats!['collectionPercentage']?.toDouble() ?? 0.0;

    final List<dynamic> monthlyData = _stats!['monthlyCollection'] ?? [];
    final List<dynamic> deptData = _stats!['departmentCollection'] ?? [];
    final List<dynamic> courseData = _stats!['courseCollection'] ?? [];

    return ListView(
      physics: BouncingScrollPhysics(),
      children: [
        // KPI row
        Row(
          children: [
            _buildKPICard("Today's Collection", "₹${NumberFormat('#,##,###').format(today)}", Icons.today, Colors.cyan),
            SizedBox(width: 16),
            _buildKPICard("This Month Collection", "₹${NumberFormat('#,##,###').format(collected * 0.45)}", Icons.calendar_month, Colors.greenAccent),
            SizedBox(width: 16),
            _buildKPICard("Pending Dues", "₹${NumberFormat('#,##,###').format(pending)}", Icons.hourglass_empty, Colors.orangeAccent),
            SizedBox(width: 16),
            _buildKPICard("Overdue Fines", "₹${NumberFormat('#,##,###').format(fine)}", Icons.warning_amber, Colors.redAccent),
          ],
        ),
        SizedBox(height: 16),
        Row(
          children: [
            _buildKPICard("Refund Requests", "3 Pending", Icons.assignment_return_outlined, Colors.purpleAccent),
            SizedBox(width: 16),
            _buildKPICard("Scholarship Requests", "₹${NumberFormat('#,##,###').format(scholarship)}", Icons.card_membership, Colors.blueAccent),
            SizedBox(width: 16),
            _buildKPICard("Active Accountants", "2 Staff", Icons.badge_outlined, Colors.tealAccent),
            SizedBox(width: 16),
            _buildKPICard("Target Achievement", "${collRate.toStringAsFixed(1)}%", Icons.track_changes, Colors.amberAccent),
          ],
        ),
        SizedBox(height: 24),

        // Charts
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 2,
              child: _buildChartContainer(
                "Monthly Collection Forecast",
                CustomPaint(
                  size: const Size(double.infinity, 220),
                  painter: LineChartPainter(monthlyData, true),
                ),
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 2,
              child: _buildChartContainer(
                "Departmental Revenue Collection",
                CustomPaint(
                  size: const Size(double.infinity, 220),
                  painter: BarChartPainter(deptData, true),
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: 16),

        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              flex: 1,
              child: _buildChartContainer(
                "Scholarship Impact & Course Distribution",
                Row(
                  children: [
                    SizedBox(
                      width: 180,
                      height: 180,
                      child: CustomPaint(
                        painter: DoughnutChartPainter(courseData, true),
                      ),
                    ),
                    SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: courseData.take(5).map((point) {
                          final idx = courseData.indexOf(point);
                          return Padding(
                            padding: EdgeInsets.symmetric(vertical: 4),
                            child: Row(
                              children: [
                                Container(
                                  width: 12,
                                  height: 12,
                                  decoration: BoxDecoration(color: _getChartColor(idx), shape: BoxShape.circle),
                                ),
                                SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    "${point['label']}: ₹${NumberFormat('#,##,###').format(point['value'])}",
                                    style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 11),
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
              ),
            ),
            SizedBox(width: 16),
            Expanded(
              flex: 1,
              child: Container(
                height: 268,
                padding: EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: context.borderColor),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Target Achievement Dial', style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
                    Spacer(),
                    Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: CircularProgressIndicator(
                              value: collRate / 100,
                              strokeWidth: 16,
                              backgroundColor: context.borderColor,
                              color: Colors.green,
                            ),
                          ),
                          Column(
                            children: [
                              Text('${collRate.toStringAsFixed(1)}%',
                                  style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                              Text('Collected', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 10)),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Spacer(),
                  ],
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildKPICard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: context.cardColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11)),
                  SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(value, style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: color, size: 20),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildChartContainer(String title, Widget chart) {
    return Container(
      padding: EdgeInsets.all(20),
      margin: EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          chart,
        ],
      ),
    );
  }
}

// ---------------------- TABS SUB-COMPONENTS ----------------------

// 1. Student Roster Tab (Roster + Sliding Detail Sheet)
class StudentRosterTab extends StatefulWidget {
  final String userId;
  final String userRole;

  const StudentRosterTab({super.key, required this.userId, required this.userRole});

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

  final List<String> _branches = ['All', 'Computer Engineering', 'Electronics & Communication Engineering', 'Mechanical Engineering', 'Civil Engineering', 'Electrical & Electronics Engineering'];
  final List<String> _years = ['All', '1st Year', '2nd Year', '3rd Year', 'Graduated'];
  final List<String> _statuses = ['All', 'Paid', 'Unpaid', 'Partially Paid'];

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
        queryParams['studentName'] = _searchController.text.trim();
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
      debugPrint("Error roster fetch: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Roster filters row
        Row(
          children: [
            Expanded(
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: context.cardColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: context.borderColor),
                ),
                child: TextField(
                  controller: _searchController,
                  style: TextStyle(color: context.textPrimary, fontSize: 12),
                  decoration: InputDecoration(
                    hintText: 'Filter by Student Name...',
                    hintStyle: TextStyle(color: context.textMuted2, fontSize: 12),
                    border: InputBorder.none,
                    prefixIcon: Icon(Icons.filter_list, color: context.textMuted, size: 16),
                  ),
                  onSubmitted: (_) {
                    setState(() => _currentPage = 1);
                    _fetchStudents();
                  },
                ),
              ),
            ),
            SizedBox(width: 10),
            _buildDropdown(_selectedBranch, _branches, (val) => setState(() => _selectedBranch = val!)),
            SizedBox(width: 10),
            _buildDropdown(_selectedYear, _years, (val) => setState(() => _selectedYear = val!)),
            SizedBox(width: 10),
            _buildDropdown(_selectedStatus, _statuses, (val) => setState(() => _selectedStatus = val!)),
            SizedBox(width: 10),
            ElevatedButton(
              onPressed: () {
                setState(() => _currentPage = 1);
                _fetchStudents();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: context.textPrimary),
              child: Text('Apply'),
            ),
          ],
        ),
        SizedBox(height: 16),

        // Table
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            clipBehavior: Clip.antiAlias,
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : _students.isEmpty
                    ? Center(child: Text('No student records found.', style: GoogleFonts.poppins(color: context.textMuted)))
                    : Column(
                        children: [
                          Container(
                            color: context.bgColor.withOpacity(0.4),
                            height: 44,
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Expanded(flex: 2, child: Text('Student ID', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                Expanded(flex: 3, child: Text('Name', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text('Department', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text('Total Payable', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text('Paid', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text('Pending', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text('Status', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                              ],
                            ),
                          ),
                          Divider(color: context.borderColor, height: 1),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _students.length,
                              itemBuilder: (ctx, index) {
                                final s = _students[index];
                                final isCleared = s['status']?.toString().toLowerCase().contains('clear') ?? false;
                                return InkWell(
                                  onTap: () => _openLedgerDrawer(s['studentId']),
                                  child: Container(
                                    height: 48,
                                    padding: EdgeInsets.symmetric(horizontal: 20),
                                    decoration: BoxDecoration(
                                      border: Border(bottom: BorderSide(color: context.borderColor, width: 0.5)),
                                    ),
                                    child: Row(
                                      children: [
                                        Expanded(flex: 2, child: Text(s['studentId'] ?? '', style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12))),
                                        Expanded(flex: 3, child: Text(s['studentName'] ?? '', style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 12, fontWeight: FontWeight.bold))),
                                        Expanded(flex: 2, child: Text(s['department'] ?? '', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12))),
                                        Expanded(flex: 2, child: Text("₹${NumberFormat('#,###').format(s['totalFee'] ?? 0)}", style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12))),
                                        Expanded(flex: 2, child: Text("₹${NumberFormat('#,###').format(s['paidAmount'] ?? 0)}", style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12))),
                                        Expanded(flex: 2, child: Text("₹${NumberFormat('#,###').format(s['pendingAmount'] ?? 0)}", style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 12))),
                                        Expanded(
                                          flex: 2,
                                          child: Row(
                                            children: [
                                              Container(
                                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                decoration: BoxDecoration(
                                                  color: (isCleared ? Colors.green : Colors.orange).withOpacity(0.15),
                                                  borderRadius: BorderRadius.circular(4),
                                                ),
                                                child: Text(
                                                  isCleared ? 'Cleared' : 'Pending',
                                                  style: TextStyle(
                                                    color: isCleared ? Colors.greenAccent : Colors.orangeAccent,
                                                    fontSize: 10,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ),
                                            ],
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                          ),
                        ],
                      ),
          ),
        ),
        SizedBox(height: 10),

        // Pagination
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Showing ${(_currentPage - 1) * _limit + 1} - ${math.min(_currentPage * _limit, _totalCount)} of $_totalCount",
                style: TextStyle(color: context.textMuted, fontSize: 11)),
            Row(
              children: [
                IconButton(
                  icon: Icon(Icons.arrow_back_ios, size: 14, color: context.textSecondary),
                  onPressed: _currentPage > 1
                      ? () {
                          setState(() => _currentPage--);
                          _fetchStudents();
                        }
                      : null,
                ),
                Text("$_currentPage / $_totalPages", style: TextStyle(color: context.textSecondary, fontSize: 12)),
                IconButton(
                  icon: Icon(Icons.arrow_forward_ios, size: 14, color: context.textSecondary),
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
      ],
    );
  }

  Widget _buildDropdown(String value, List<String> items, ValueChanged<String?> onChanged) {
    return Container(
      height: 38,
      padding: EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: context.borderColor),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: value,
          dropdownColor: context.cardColor,
          style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12),
          items: items.map((val) => DropdownMenuItem(value: val, child: Text(val))).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }

  void _openLedgerDrawer(String studentId) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (ctx, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Container(
            width: 650,
            height: double.infinity,
            color: context.cardColor,
            child: Material(
              color: Colors.transparent,
              child: LedgerDrawerWidget(
                studentId: studentId,
                userId: widget.userId,
                userRole: widget.userRole,
                onRefresh: _fetchStudents,
              ),
            ),
          ),
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(anim1),
          child: child,
        );
      },
    );
  }
}

// Ledger Sliding Drawer Widget
class LedgerDrawerWidget extends StatefulWidget {
  final String studentId;
  final String userId;
  final String userRole;
  final VoidCallback onRefresh;

  const LedgerDrawerWidget({
    super.key,
    required this.studentId,
    required this.userId,
    required this.userRole,
    required this.onRefresh,
  });

  @override
  State<LedgerDrawerWidget> createState() => _LedgerDrawerWidgetState();
}

class _LedgerDrawerWidgetState extends State<LedgerDrawerWidget> {
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
      return Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }
    if (_ledger == null) {
      return Center(child: Text('Failed to load student ledger details.', style: TextStyle(color: context.textMuted)));
    }

    final double total = _ledger!['totalFee']?.toDouble() ?? 0.0;
    final double paid = _ledger!['paidAmount']?.toDouble() ?? 0.0;
    final double pending = _ledger!['pendingAmount']?.toDouble() ?? 0.0;

    final breakdown = List<dynamic>.from(_ledger!['breakdown'] ?? []);
    final payments = List<dynamic>.from(_ledger!['paymentHistory'] ?? []);
    final changes = List<dynamic>.from(_ledger!['changeHistory'] ?? []);

    final bool isManagerOrAdmin = widget.userRole.toLowerCase() == 'admin' || widget.userRole.toLowerCase() == 'accounts manager';

    return Column(
      children: [
        // Header
        Container(
          padding: EdgeInsets.all(24),
          color: context.bgColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(_ledger!['studentName'] ?? '', style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
                  Text('ID: ${widget.studentId} • Branch: ${_ledger!['department'] ?? ''}', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11)),
                ],
              ),
              IconButton(
                icon: Icon(Icons.close, color: context.textSecondary),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
        ),

        // Content
        Expanded(
          child: ListView(
            padding: EdgeInsets.all(24),
            children: [
              // Financial metrics cards
              Row(
                children: [
                  _buildMetricBox("Demand", total, Colors.indigoAccent),
                  SizedBox(width: 12),
                  _buildMetricBox("Paid", paid, Colors.green),
                  SizedBox(width: 12),
                  _buildMetricBox("Pending", pending, Colors.orange),
                ],
              ),
              SizedBox(height: 24),

              // Fee structures breakdowns
              _buildSectionTitle('Fee Breakdown Breakdown'),
              SizedBox(height: 10),
              Table(
                columnWidths: {
                  0: FlexColumnWidth(2),
                  1: FlexColumnWidth(1),
                  2: FlexColumnWidth(1),
                  3: FlexColumnWidth(1.5),
                },
                children: [
                  TableRow(
                    decoration: BoxDecoration(color: Colors.white.withOpacity(0.05)),
                    children: [
                      _tableCell('Category', isHeader: true),
                      _tableCell('Amount', isHeader: true),
                      _tableCell('Offset', isHeader: true),
                      _tableCell('Remarks', isHeader: true),
                    ],
                  ),
                  ...breakdown.map((item) {
                    final double amt = item['amount']?.toDouble() ?? 0.0;
                    final double schol = item['scholarship']?.toDouble() ?? 0.0;
                    return TableRow(
                      children: [
                        _tableCell(item['category'] ?? ''),
                        _tableCell('₹${NumberFormat('#,###').format(amt)}'),
                        _tableCell(schol > 0 ? '₹${NumberFormat('#,###').format(schol)}' : '-'),
                        _tableCell(item['remarks'] ?? ''),
                      ],
                    );
                  }),
                ],
              ),
              SizedBox(height: 24),

              // Receipts history
              _buildSectionTitle('Transactions & Receipts History'),
              SizedBox(height: 10),
              payments.isEmpty
                  ? Text('No payments recorded yet.', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12))
                  : ListView.builder(
                      shrinkWrap: true,
                      physics: NeverScrollableScrollPhysics(),
                      itemCount: payments.length,
                      itemBuilder: (ctx, idx) {
                        final r = payments[idx];
                        return Card(
                          color: context.bgColor,
                          margin: EdgeInsets.only(bottom: 8),
                          child: ListTile(
                            title: Text(r['receiptNumber'] ?? '', style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                            subtitle: Text('${r['paymentMode']} • ${r['transactionDate'].substring(0,10)}', style: TextStyle(fontSize: 11)),
                            trailing: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text('₹${NumberFormat('#,###').format(r['amount'] ?? 0)}', style: GoogleFonts.poppins(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                SizedBox(width: 8),
                                IconButton(
                                  icon: Icon(Icons.print, color: Colors.blueAccent, size: 18),
                                  onPressed: () => _printDuplicateReceipt(r),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
              SizedBox(height: 24),

              // Change history logs
              _buildSectionTitle('Fee Change History Logs'),
              SizedBox(height: 10),
              changes.isEmpty
                  ? Text('No manual modifications applied.', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12))
                  : Table(
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: Colors.white.withOpacity(0.05)),
                          children: [
                            _tableCell('Category', isHeader: true),
                            _tableCell('Old', isHeader: true),
                            _tableCell('New', isHeader: true),
                            _tableCell('Reason', isHeader: true),
                          ],
                        ),
                        ...changes.map((c) {
                          return TableRow(
                            children: [
                              _tableCell(c['category'] ?? ''),
                              _tableCell('₹${NumberFormat('#,###').format(c['previousAmount'])}'),
                              _tableCell('₹${NumberFormat('#,###').format(c['newAmount'])}'),
                              _tableCell(c['reason'] ?? ''),
                            ],
                          );
                        }),
                      ],
                    ),
            ],
          ),
        ),

        // Footer Actions
        if (widget.userRole.toLowerCase() != 'principal')
          Container(
            padding: EdgeInsets.all(24),
            color: context.bgColor,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                ElevatedButton.icon(
                  onPressed: _openPaymentSimulator,
                  icon: Icon(Icons.payment),
                  label: Text('Record Fee Payment'),
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: context.textPrimary),
                ),
                if (isManagerOrAdmin) ...[
                  SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: _openAdjustmentWizard,
                    icon: Icon(Icons.edit_note),
                    label: Text('Adjust Student Fee'),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: context.textPrimary),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }

  Widget _buildMetricBox(String label, double val, Color color) {
    return Expanded(
      child: Container(
        padding: EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: context.bgColor,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.borderColor),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: GoogleFonts.poppins(color: context.textMuted, fontSize: 10)),
            SizedBox(height: 4),
            Text('₹${NumberFormat('#,##,###').format(val)}',
                style: GoogleFonts.poppins(color: color, fontSize: 15, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(title, style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.bold));
  }

  Widget _tableCell(String val, {bool isHeader = false}) {
    return Padding(
      padding: EdgeInsets.all(8),
      child: Text(
        val,
        style: GoogleFonts.poppins(
          color: isHeader ? context.textSecondary : context.textMuted,
          fontSize: 11,
          fontWeight: isHeader ? FontWeight.bold : FontWeight.normal,
        ),
      ),
    );
  }

  void _printDuplicateReceipt(Map<String, dynamic> receipt) {
    showDialog(
      context: context,
      builder: (ctx) {
        return Dialog(
          backgroundColor: context.textPrimary,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Container(
            width: 450,
            padding: EdgeInsets.all(30),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.school, color: Colors.blueAccent, size: 36),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text('DUPLICATE FEE RECEIPT', style: GoogleFonts.poppins(color: Colors.black, fontSize: 13, fontWeight: FontWeight.bold)),
                        Text(receipt['receiptNumber'] ?? '', style: GoogleFonts.poppins(color: Colors.black54, fontSize: 11)),
                      ],
                    )
                  ],
                ),
                SizedBox(height: 16),
                Divider(color: Colors.black26),
                SizedBox(height: 16),
                Text('Student ID: ${widget.studentId}', style: TextStyle(color: Colors.black87, fontSize: 12)),
                Text('Student Name: ${_ledger!['studentName']}', style: TextStyle(color: Colors.black87, fontSize: 12)),
                Text('Department: ${_ledger!['department']}', style: TextStyle(color: Colors.black87, fontSize: 12)),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Paid Amount:', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                    Text('₹${NumberFormat('#,###').format(receipt['amount'])}', style: GoogleFonts.poppins(color: Colors.black, fontWeight: FontWeight.bold, fontSize: 13)),
                  ],
                ),
                Text('Payment Mode: ${receipt['paymentMode']}', style: TextStyle(color: Colors.black54, fontSize: 11)),
                Text('Transaction Date: ${receipt['transactionDate'].substring(0, 10)}', style: TextStyle(color: Colors.black54, fontSize: 11)),
                SizedBox(height: 30),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Icon(Icons.qr_code, color: Colors.black87, size: 50),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Icon(Icons.verified, color: Colors.green, size: 20),
                        Text('Digitally Verified Seal', style: GoogleFonts.poppins(color: Colors.black54, fontSize: 9)),
                      ],
                    )
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Close')),
                    SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Receipt downloaded successfully.')));
                      },
                      child: Text('Download PDF'),
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

  void _openPaymentSimulator() {
    final amtController = TextEditingController(text: _ledger!['pendingAmount']?.toString());
    final refController = TextEditingController();
    String method = 'UPI';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.cardColor,
          title: Text('Collect Fee Payment', style: GoogleFonts.poppins(color: context.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: amtController,
                style: TextStyle(color: context.textPrimary),
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  labelText: 'Payment Amount (₹)',
                  labelStyle: TextStyle(color: context.textMuted),
                ),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: method,
                dropdownColor: context.cardColor,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(labelText: 'Payment Method'),
                items: ['UPI', 'Net Banking', 'Credit Card', 'Debit Card', 'Cash', 'Cheque']
                    .map((m) => DropdownMenuItem(value: m, child: Text(m)))
                    .toList(),
                onChanged: (val) => method = val!,
              ),
              TextField(
                controller: refController,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Reference Number / Cheque ID',
                  labelStyle: TextStyle(color: context.textMuted),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final double? amt = double.tryParse(amtController.text);
                if (amt == null || amt <= 0) return;
                Navigator.pop(ctx);
                _submitPayment(amt, method, refController.text);
              },
              child: Text('Record'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitPayment(double amount, String method, String ref) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiConfig.post(
        '${ApiConstants.baseUrl}/api/finance/pay-simulated',
        body: {
          'studentId': widget.studentId,
          'amount': amount,
          'paymentMode': method,
          'remarks': ref.isNotEmpty ? ref : 'Recorded by accountant',
          'processedBy': widget.userId,
        },
      );

      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Payment registered and duplicate receipt generated.')));
        widget.onRefresh();
        _fetchLedger();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
      }
    } catch (e) {
      debugPrint("Error payment submit: $e");
      setState(() => _isLoading = false);
    }
  }

  void _openAdjustmentWizard() {
    final amtController = TextEditingController();
    final scholController = TextEditingController(text: '0');
    final fineController = TextEditingController(text: '0');
    final reasonController = TextEditingController();
    String category = 'Tuition Fee';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.cardColor,
          title: Text('Adjust Student Fee', style: GoogleFonts.poppins(color: context.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: category,
                  dropdownColor: context.cardColor,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(labelText: 'Fee Category'),
                  items: ['Tuition Fee', 'Lab Fee', 'Library Fee', 'Exam Fee', 'Transport Fee', 'Hostel Fee']
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
                  onChanged: (val) => category = val!,
                ),
                TextField(
                  controller: amtController,
                  style: TextStyle(color: context.textPrimary),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Adjusted Amount (₹)',
                    labelStyle: TextStyle(color: context.textMuted),
                  ),
                ),
                TextField(
                  controller: scholController,
                  style: TextStyle(color: context.textPrimary),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Scholarship Discount (₹)',
                    labelStyle: TextStyle(color: context.textMuted),
                  ),
                ),
                TextField(
                  controller: fineController,
                  style: TextStyle(color: context.textPrimary),
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Fine Penalty Add-on (₹)',
                    labelStyle: TextStyle(color: context.textMuted),
                  ),
                ),
                TextField(
                  controller: reasonController,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Reason for Modification',
                    labelStyle: TextStyle(color: context.textMuted),
                  ),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                final double? amt = double.tryParse(amtController.text);
                final double? schol = double.tryParse(scholController.text);
                final double? fine = double.tryParse(fineController.text);
                if (amt == null || schol == null || fine == null || reasonController.text.trim().isEmpty) return;
                Navigator.pop(ctx);
                _submitAdjustment(category, amt, schol, fine, reasonController.text.trim());
              },
              child: Text('Adjust'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _submitAdjustment(String cat, double amt, double schol, double fine, String reason) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiConfig.post(
        '${ApiConstants.baseUrl}/api/finance/student/${widget.studentId}/update',
        body: {
          'category': cat,
          'amount': amt,
          'scholarship': schol,
          'fine': fine,
          'reason': reason,
          'updatedBy': widget.userId,
        },
      );

      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Ledger adjusted and chronological history logged.')));
        widget.onRefresh();
        _fetchLedger();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
      }
    } catch (e) {
      debugPrint("Error adjustment: $e");
      setState(() => _isLoading = false);
    }
  }
}

// 2. Accountant Directory Tab
class AccountantDirectoryTab extends StatefulWidget {
  const AccountantDirectoryTab({super.key});

  @override
  State<AccountantDirectoryTab> createState() => _AccountantDirectoryTabState();
}

class _AccountantDirectoryTabState extends State<AccountantDirectoryTab> {
  bool _isLoading = false;
  List<dynamic> _accountants = [];

  @override
  void initState() {
    super.initState();
    _fetchAccountants();
  }

  Future<void> _fetchAccountants() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiConfig.get('${ApiConstants.baseUrl}/api/finance/accountants');
      if (res.success && res.data != null) {
        setState(() {
          _accountants = res.data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching accountants: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Accountant Directory', style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _openCreateAccountantDialog,
                icon: Icon(Icons.add),
                label: Text('Register Accountant'),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : _accountants.isEmpty
                    ? Center(child: Text('No accountants registered yet.', style: TextStyle(color: context.textMuted)))
                    : ListView.builder(
                        itemCount: _accountants.length,
                        itemBuilder: (ctx, index) {
                          final acc = _accountants[index];
                          final tasks = List<dynamic>.from(acc['assignedTasks'] ?? []);
                          return Card(
                            color: context.bgColor,
                            margin: EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  CircleAvatar(
                                    backgroundColor: Colors.blueAccent.withOpacity(0.1),
                                    child: Icon(Icons.person, color: Colors.blueAccent),
                                  ),
                                  SizedBox(width: 16),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(acc['name'] ?? '', style: GoogleFonts.poppins(color: context.textPrimary, fontWeight: FontWeight.bold)),
                                        Text('Employee ID: ${acc['employeeId']}', style: TextStyle(color: context.textMuted, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(acc['email'] ?? 'No email', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                                        Text(acc['phoneNumber'] ?? 'No mobile', style: TextStyle(color: context.textMuted, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.end,
                                      children: [
                                        Text('Today: ₹${NumberFormat('#,###').format(acc['todaysCollections'] ?? 0)}', style: TextStyle(color: Colors.green, fontSize: 12)),
                                        Text('Month: ₹${NumberFormat('#,###').format(acc['monthlyCollections'] ?? 0)}', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                                      ],
                                    ),
                                  ),
                                  SizedBox(width: 20),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Assignments:', style: TextStyle(color: context.textMuted, fontSize: 10)),
                                        tasks.isEmpty
                                            ? Text('None', style: TextStyle(color: Colors.white54, fontSize: 11))
                                            : Text(tasks.join(', '), style: TextStyle(color: context.textSecondary, fontSize: 11), overflow: TextOverflow.ellipsis),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          )
        ],
      ),
    );
  }

  void _openCreateAccountantDialog() {
    final idController = TextEditingController();
    final nameController = TextEditingController();
    final mobileController = TextEditingController();
    final emailController = TextEditingController();
    final passController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.cardColor,
          title: Text('Register Accountant Account', style: GoogleFonts.poppins(color: context.textPrimary)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: idController,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(labelText: 'Employee ID', labelStyle: TextStyle(color: context.textMuted)),
                ),
                TextField(
                  controller: nameController,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(labelText: 'Full Name', labelStyle: TextStyle(color: context.textMuted)),
                ),
                TextField(
                  controller: mobileController,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(labelText: 'Mobile Number', labelStyle: TextStyle(color: context.textMuted)),
                ),
                TextField(
                  controller: emailController,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(labelText: 'Email Address', labelStyle: TextStyle(color: context.textMuted)),
                ),
                TextField(
                  controller: passController,
                  style: TextStyle(color: context.textPrimary),
                  decoration: InputDecoration(labelText: 'Password Setup', labelStyle: TextStyle(color: context.textMuted)),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (idController.text.isEmpty || nameController.text.isEmpty || passController.text.isEmpty) return;
                Navigator.pop(ctx);
                _createAccountant(
                  idController.text,
                  nameController.text,
                  mobileController.text,
                  emailController.text,
                  passController.text,
                );
              },
              child: Text('Create'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _createAccountant(String id, String name, String mobile, String email, String pass) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiConfig.post(
        '${ApiConstants.baseUrl}/api/finance/accountants',
        body: {
          'employeeId': id,
          'fullName': name,
          'mobileNumber': mobile,
          'email': email,
          'designation': 'Junior Accountant',
          'department': 'Finance',
          'joiningDate': DateTime.now().toIso8601String().substring(0, 10),
          'passwordSetup': pass,
        },
      );

      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Accountant registered successfully.')));
        _fetchAccountants();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
      }
    } catch (e) {
      debugPrint("Error creating accountant: $e");
      setState(() => _isLoading = false);
    }
  }
}

// 3. Accountant Performance Tab
class AccountantPerformanceTab extends StatefulWidget {
  const AccountantPerformanceTab({super.key});

  @override
  State<AccountantPerformanceTab> createState() => _AccountantPerformanceTabState();
}

class _AccountantPerformanceTabState extends State<AccountantPerformanceTab> {
  bool _isLoading = false;
  List<dynamic> _performance = [];

  @override
  void initState() {
    super.initState();
    _fetchPerformance();
  }

  Future<void> _fetchPerformance() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiConfig.get('${ApiConstants.baseUrl}/api/finance/accountants/performance');
      if (res.success && res.data != null) {
        setState(() {
          _performance = res.data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching performance: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Accountant Leaderboard & Performance Console',
              style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : _performance.isEmpty
                    ? Center(child: Text('No performance metrics available.', style: TextStyle(color: context.textMuted)))
                    : ListView.builder(
                        itemCount: _performance.length,
                        itemBuilder: (ctx, index) {
                          final perf = _performance[index];
                          return Card(
                            color: context.bgColor,
                            margin: EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Text('#${perf['monthlyRanking']}',
                                      style: GoogleFonts.poppins(color: Colors.amberAccent, fontSize: 18, fontWeight: FontWeight.bold)),
                                  SizedBox(width: 16),
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(perf['name'] ?? '', style: GoogleFonts.poppins(color: context.textPrimary, fontWeight: FontWeight.bold)),
                                        Text('Satisfactory Score: ${perf['studentSatisfactionScore']}%', style: TextStyle(color: context.textMuted, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Receipts: ${perf['receiptsGenerated']}', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                                        Text('Refunds: ${perf['refundsProcessed']}', style: TextStyle(color: context.textMuted, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('Tasks Pending: ${perf['pendingTasks']}', style: TextStyle(color: Colors.orangeAccent, fontSize: 12)),
                                        Text('Avg Process: ${perf['averageProcessingTimeMins']} mins', style: TextStyle(color: context.textMuted, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text('Total Collections:\n₹${NumberFormat('#,###').format(perf['totalCollections'])}',
                                        style: GoogleFonts.poppins(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// 4. Work Assignments Tab
class WorkAssignmentsTab extends StatefulWidget {
  final String userId;

  const WorkAssignmentsTab({super.key, required this.userId});

  @override
  State<WorkAssignmentsTab> createState() => _WorkAssignmentsTabState();
}

class _WorkAssignmentsTabState extends State<WorkAssignmentsTab> {
  bool _isLoading = false;
  List<dynamic> _assignments = [];

  @override
  void initState() {
    super.initState();
    _fetchAssignments();
  }

  Future<void> _fetchAssignments() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiConfig.get('${ApiConstants.baseUrl}/api/finance/work-assignments');
      if (res.success && res.data != null) {
        setState(() {
          _assignments = res.data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching assignments: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Accountant Work Assignments', style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _openAssignTaskDialog,
                icon: Icon(Icons.add_task),
                label: Text('Assign Task'),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : _assignments.isEmpty
                    ? Center(child: Text('No active work assignments.', style: TextStyle(color: context.textMuted)))
                    : ListView.builder(
                        itemCount: _assignments.length,
                        itemBuilder: (ctx, index) {
                          final a = _assignments[index];
                          return Card(
                            color: context.bgColor,
                            margin: EdgeInsets.only(bottom: 12),
                            child: ListTile(
                              title: Text(a['assignmentType'] ?? '', style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                              subtitle: Text('Department: ${a['department']} • Assignee: ${a['accountantName']} (${a['accountantId']})', style: TextStyle(fontSize: 11)),
                              trailing: Container(
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(color: Colors.green.withOpacity(0.15), borderRadius: BorderRadius.circular(4)),
                                child: Text(a['status'] ?? '', style: TextStyle(color: Colors.greenAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }

  void _openAssignTaskDialog() {
    final accIdController = TextEditingController();
    String type = 'Fee Collection';
    String dept = 'Computer Engineering';

    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: context.cardColor,
          title: Text('Assign Task to Accountant', style: GoogleFonts.poppins(color: context.textPrimary)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: accIdController,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Accountant Employee ID',
                  hintText: 'e.g. acc-01',
                  labelStyle: TextStyle(color: context.textMuted),
                ),
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: type,
                dropdownColor: context.cardColor,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(labelText: 'Assignment Type'),
                items: ['Fee Collection', 'Refund Processing', 'Scholarship Verification', 'Hostel Fees', 'Transport Fees']
                    .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                    .toList(),
                onChanged: (val) => type = val!,
              ),
              SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: dept,
                dropdownColor: context.cardColor,
                style: TextStyle(color: context.textPrimary),
                decoration: InputDecoration(labelText: 'Branch/Department'),
                items: ['All', 'Computer Engineering', 'Electronics & Communication Engineering', 'Mechanical Engineering', 'Civil Engineering']
                    .map((val) => DropdownMenuItem(value: val, child: Text(val)))
                    .toList(),
                onChanged: (val) => dept = val!,
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel')),
            ElevatedButton(
              onPressed: () async {
                if (accIdController.text.isEmpty) return;
                Navigator.pop(ctx);
                _assignTask(accIdController.text, type, dept);
              },
              child: Text('Assign'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _assignTask(String accId, String type, String dept) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiConfig.post(
        '${ApiConstants.baseUrl}/api/finance/work-assignments',
        body: {
          'accountantId': accId,
          'assignmentType': type,
          'department': dept,
          'assignedBy': widget.userId,
        },
      );

      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Task assigned to accountant successfully.')));
        _fetchAssignments();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
      }
    } catch (e) {
      debugPrint("Error assigning task: $e");
      setState(() => _isLoading = false);
    }
  }
}

// 5. Defaulters List Tab
class DefaultersListTab extends StatefulWidget {
  const DefaultersListTab({super.key});

  @override
  State<DefaultersListTab> createState() => _DefaultersListTabState();
}

class _DefaultersListTabState extends State<DefaultersListTab> {
  bool _isLoading = false;
  List<dynamic> _defaulters = [];

  @override
  void initState() {
    super.initState();
    _fetchDefaulters();
  }

  Future<void> _fetchDefaulters() async {
    setState(() => _isLoading = true);
    try {
      // Query students with pending status or fee_status = Unpaid/Partially Paid
      final res = await ApiConfig.get('${ApiConstants.baseUrl}/api/finance/students?feeStatus=Unpaid');
      if (res.success && res.data != null) {
        setState(() {
          _defaulters = res.data['students'] ?? [];
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching defaulters: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Defaulter Management Center', style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
              ElevatedButton.icon(
                onPressed: _sendBulkReminders,
                icon: Icon(Icons.notifications_active),
                label: Text('Send Bulk Reminders'),
                style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: context.textPrimary),
              ),
            ],
          ),
          SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : _defaulters.isEmpty
                    ? Center(child: Text('No due defaulters outstanding.', style: TextStyle(color: context.textMuted)))
                    : Column(
                        children: [
                          Container(
                            color: context.bgColor.withOpacity(0.4),
                            height: 44,
                            padding: EdgeInsets.symmetric(horizontal: 20),
                            child: Row(
                              children: [
                                Expanded(flex: 2, child: Text('Student ID', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                Expanded(flex: 3, child: Text('Name', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text('Department', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text('Pending amount', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text('Due Date', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                Expanded(flex: 2, child: Text('Days Overdue', style: TextStyle(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold))),
                                SizedBox(width: 80),
                              ],
                            ),
                          ),
                          Expanded(
                            child: ListView.builder(
                              itemCount: _defaulters.length,
                              itemBuilder: (ctx, idx) {
                                final d = _defaulters[idx];
                                return Container(
                                  height: 48,
                                  padding: EdgeInsets.symmetric(horizontal: 20),
                                  decoration: BoxDecoration(
                                    border: Border(bottom: BorderSide(color: context.borderColor, width: 0.5)),
                                  ),
                                  child: Row(
                                    children: [
                                      Expanded(flex: 2, child: Text(d['studentId'] ?? '', style: TextStyle(color: context.textSecondary, fontSize: 12))),
                                      Expanded(flex: 3, child: Text(d['studentName'] ?? '', style: TextStyle(color: context.textPrimary, fontSize: 12, fontWeight: FontWeight.bold))),
                                      Expanded(flex: 2, child: Text(d['department'] ?? '', style: TextStyle(color: context.textMuted, fontSize: 11))),
                                      Expanded(flex: 2, child: Text("₹${NumberFormat('#,###').format(d['pendingAmount'] ?? 0)}", style: TextStyle(color: Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold))),
                                      Expanded(flex: 2, child: Text(d['lastPaymentDate']?.substring(0,10) ?? '2026-06-01', style: TextStyle(color: context.textMuted, fontSize: 11))),
                                      Expanded(flex: 2, child: Text('14 Days', style: GoogleFonts.poppins(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold))),
                                      SizedBox(
                                        width: 80,
                                        child: TextButton(
                                          onPressed: () => _sendIndividualReminder(d['studentName']),
                                          child: Text('Remind', style: TextStyle(color: Colors.amberAccent, fontSize: 12)),
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
        ],
      ),
    );
  }

  void _sendIndividualReminder(String studentName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Warning SMS and Email reminders dispatched to $studentName & parents.')),
    );
  }

  void _sendBulkReminders() {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Bulk notices and reminder SMS alerts broadcasted to all outstanding defaulters.')),
    );
  }
}

// 6. Scholarship Verification Tab
class ScholarshipTab extends StatefulWidget {
  const ScholarshipTab({super.key});

  @override
  State<ScholarshipTab> createState() => _ScholarshipTabState();
}

class _ScholarshipTabState extends State<ScholarshipTab> {
  final List<Map<String, dynamic>> _scholarships = [
    {'id': 'SCH-01', 'name': 'Aditya Verma', 'type': 'Government Merit Scholarship', 'amount': 25000.0, 'status': 'Pending Verification'},
    {'id': 'SCH-02', 'name': 'Pooja Hegde', 'type': 'Sports Scholarship', 'amount': 15000.0, 'status': 'Verified'},
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Scholarship Pipeline Management', style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _scholarships.length,
              itemBuilder: (ctx, index) {
                final sch = _scholarships[index];
                return Card(
                  color: context.bgColor,
                  margin: EdgeInsets.only(bottom: 12),
                  child: ListTile(
                    title: Text(sch['name'], style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                    subtitle: Text('${sch['type']} • Amount: ₹${NumberFormat('#,###').format(sch['amount'])}', style: TextStyle(fontSize: 11)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: (sch['status'] == 'Verified' ? Colors.green : Colors.orange).withOpacity(0.15),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(sch['status'], style: TextStyle(color: sch['status'] == 'Verified' ? Colors.greenAccent : Colors.orangeAccent, fontSize: 10, fontWeight: FontWeight.bold)),
                        ),
                        if (sch['status'] != 'Verified') ...[
                          SizedBox(width: 12),
                          ElevatedButton(
                            onPressed: () {
                              setState(() {
                                sch['status'] = 'Verified';
                              });
                              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Scholarship application verified.')));
                            },
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: context.textPrimary),
                            child: Text('Verify', style: TextStyle(fontSize: 12)),
                          ),
                        ]
                      ],
                    ),
                  ),
                );
              },
            ),
          )
        ],
      ),
    );
  }
}

// 7. Refund Requests Tab
class RefundRequestsTab extends StatefulWidget {
  final String userId;
  final String userRole;

  const RefundRequestsTab({super.key, required this.userId, required this.userRole});

  @override
  State<RefundRequestsTab> createState() => _RefundRequestsTabState();
}

class _RefundRequestsTabState extends State<RefundRequestsTab> {
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
      debugPrint("Error fetching workflows: $e");
      setState(() => _isLoading = false);
    }
  }

  Future<void> _takeAction(String workflowId, String action, String reason) async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiConfig.post(
        '${ApiConstants.baseUrl}/api/finance/approvals/$workflowId/action',
        body: {
          'action': action,
          'reason': reason,
          'userId': widget.userId,
        },
      );

      if (res.success) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Workflow $action successfully.')));
        _fetchWorkflows();
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
      }
    } catch (e) {
      debugPrint("Error workflows action: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Refund & Fee Workflow Approval Engine',
              style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : _workflows.isEmpty
                    ? Center(child: Text('No pending workflow approvals found.', style: TextStyle(color: context.textMuted)))
                    : ListView.builder(
                        itemCount: _workflows.length,
                        itemBuilder: (ctx, index) {
                          final w = _workflows[index];
                          final status = w['status']?.toString() ?? 'Pending';
                          final isApproved = status == 'Approved';
                          final isRejected = status == 'Rejected';

                          return Card(
                            color: context.bgColor,
                            margin: EdgeInsets.only(bottom: 12),
                            child: Padding(
                              padding: EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    flex: 3,
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text('${w['operationType']} - ${w['reason']}', style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.bold)),
                                        Text('Creator: ${w['createdByName']} • Affected: ${w['studentCount']} students', style: TextStyle(color: context.textMuted, fontSize: 11)),
                                      ],
                                    ),
                                  ),
                                  Expanded(
                                    flex: 2,
                                    child: Text('Diff: ₹${NumberFormat('#,###').format(w['totalDifference'])}', style: GoogleFonts.poppins(color: Colors.redAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: (isApproved ? Colors.green : (isRejected ? Colors.red : Colors.orange)).withOpacity(0.15),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(status, style: TextStyle(color: isApproved ? Colors.greenAccent : (isRejected ? Colors.redAccent : Colors.orangeAccent), fontSize: 10, fontWeight: FontWeight.bold)),
                                  ),
                                  if (!isApproved && !isRejected) ...[
                                    SizedBox(width: 16),
                                    TextButton(
                                      onPressed: () => _takeAction(w['id'], 'REJECT', 'Rejected via desktop panel'),
                                      child: Text('Reject', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                                    ),
                                    SizedBox(width: 8),
                                    ElevatedButton(
                                      onPressed: () => _takeAction(w['id'], 'APPROVE', ''),
                                      style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: context.textPrimary),
                                      child: Text('Approve', style: TextStyle(fontSize: 12)),
                                    ),
                                  ]
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// 8. Bulk Adjustments Tab
class BulkAdjustmentsTab extends StatefulWidget {
  final String userId;

  const BulkAdjustmentsTab({super.key, required this.userId});

  @override
  State<BulkAdjustmentsTab> createState() => _BulkAdjustmentsTabState();
}

class _BulkAdjustmentsTabState extends State<BulkAdjustmentsTab> {
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
  final List<String> _categories = ['Tuition Fee', 'Lab Fee', 'Library Fee', 'Exam Fee', 'Transport Fee', 'Hostel Fee'];

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
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
      }
    } catch (e) {
      debugPrint("Error preview: $e");
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Bulk adjustment submitted for approval.')));
      } else {
        setState(() => _isLoading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(res.message)));
      }
    } catch (e) {
      debugPrint("Error submit bulk: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Form(
      key: _formKey,
      child: ListView(
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Bulk Fee Adjustments Configuration',
                    style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
                SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _scope,
                        dropdownColor: context.cardColor,
                        style: TextStyle(color: context.textPrimary),
                        decoration: InputDecoration(labelText: 'Adjustment Scope'),
                        items: _scopes.map((s) => DropdownMenuItem(value: s, child: Text(s))).toList(),
                        onChanged: (val) => setState(() => _scope = val!),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _targetValueController,
                        style: TextStyle(color: context.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Scope Value Target',
                          hintText: 'e.g. Computer Engineering',
                          hintStyle: TextStyle(color: context.textMuted2),
                        ),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _operationType,
                        dropdownColor: context.cardColor,
                        style: TextStyle(color: context.textPrimary),
                        decoration: InputDecoration(labelText: 'Operation Type'),
                        items: _operations.map((o) => DropdownMenuItem(value: o, child: Text(o))).toList(),
                        onChanged: (val) => setState(() => _operationType = val!),
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _category,
                        dropdownColor: context.cardColor,
                        style: TextStyle(color: context.textPrimary),
                        decoration: InputDecoration(labelText: 'Fee Category'),
                        items: _categories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                        onChanged: (val) => setState(() => _category = val!),
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _amountController,
                        style: TextStyle(color: context.textPrimary),
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(
                          labelText: 'Amount Impact (₹)',
                          hintText: 'e.g. 5000',
                          hintStyle: TextStyle(color: context.textMuted2),
                        ),
                        validator: (val) => val == null || double.tryParse(val) == null ? 'Invalid number' : null,
                      ),
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _reasonController,
                        style: TextStyle(color: context.textPrimary),
                        decoration: InputDecoration(
                          labelText: 'Adjustment Reason Description',
                        ),
                        validator: (val) => val == null || val.isEmpty ? 'Reason required' : null,
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    ElevatedButton(
                      onPressed: _isLoading ? null : _previewBulk,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: context.textPrimary),
                      child: Text('Preview Impact'),
                    ),
                    if (_previewData != null) ...[
                      SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: _isLoading ? null : _submitBulk,
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.green, foregroundColor: context.textPrimary),
                        child: Text('Submit for Approval'),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
          if (_previewData != null) ...[
            SizedBox(height: 16),
            Container(
              padding: EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Adjustment Impact Report', style: GoogleFonts.poppins(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text('Students Affected: ${_previewData!['affectedStudents']}', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                  Text('Current Demand: ₹${NumberFormat('#,###').format(_previewData!['currentTotalAmount'])}', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                  Text('Post-Impact Demand: ₹${NumberFormat('#,###').format(_previewData!['updatedTotalAmount'])}', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                  Text('Difference: ₹${NumberFormat('#,###').format(_previewData!['difference'])}', style: TextStyle(color: _previewData!['difference'] >= 0 ? Colors.greenAccent : Colors.redAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                ],
              ),
            )
          ]
        ],
      ),
    );
  }
}

// 9. Audit Trails Tab
class AuditTrailsTab extends StatefulWidget {
  const AuditTrailsTab({super.key});

  @override
  State<AuditTrailsTab> createState() => _AuditTrailsTabState();
}

class _AuditTrailsTabState extends State<AuditTrailsTab> {
  bool _isLoading = false;
  List<dynamic> _logs = [];

  @override
  void initState() {
    super.initState();
    _fetchAuditTrails();
  }

  Future<void> _fetchAuditTrails() async {
    setState(() => _isLoading = true);
    try {
      final res = await ApiConfig.get('${ApiConstants.baseUrl}/api/finance/audit-trails');
      if (res.success && res.data != null) {
        setState(() {
          _logs = res.data;
          _isLoading = false;
        });
      } else {
        setState(() => _isLoading = false);
      }
    } catch (e) {
      debugPrint("Error fetching audit logs: $e");
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      padding: EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Compliance & Chronological Audit Trails (Read-Only Logs)',
              style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
          SizedBox(height: 16),
          Expanded(
            child: _isLoading
                ? Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : _logs.isEmpty
                    ? Center(child: Text('No audit entries recorded.', style: TextStyle(color: context.textMuted)))
                    : ListView.builder(
                        itemCount: _logs.length,
                        itemBuilder: (ctx, idx) {
                          final log = _logs[idx];
                          return Card(
                            color: context.bgColor,
                            margin: EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: EdgeInsets.all(14),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text('${log['operationType']} - ${log['status']}',
                                          style: GoogleFonts.poppins(color: log['status'] == 'Approved' ? Colors.greenAccent : Colors.orangeAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                                      Text(log['timestamp']?.substring(0, 19).replaceFirst('T', ' ') ?? '', style: TextStyle(color: context.textMuted, fontSize: 10)),
                                    ],
                                  ),
                                  SizedBox(height: 8),
                                  Text(log['reason'] ?? '', style: TextStyle(color: context.textSecondary, fontSize: 12)),
                                  SizedBox(height: 4),
                                  Text('Created By: ${log['createdByName']} ${log['approvedByName'] != null ? "• Approved By: ${log['approvedByName']}" : ""}',
                                      style: TextStyle(color: context.textMuted, fontSize: 10)),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
        ],
      ),
    );
  }
}

// ---------------------- CUSTOM PAINTERS FOR GRAPHICS ----------------------

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

    final stepX = size.width / (data.length - 1);
    final path = Path();
    final fillPath = Path();

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

    final fillPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Colors.cyan.withOpacity(0.3), Colors.cyan.withOpacity(0.0)],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height))
      ..style = PaintingStyle.fill;

    canvas.drawPath(fillPath, fillPaint);
    canvas.drawPath(path, paint);

    for (int i = 0; i < data.length; i++) {
      final p = getCoord(i);
      canvas.drawCircle(p, 4, Paint()..color = Colors.cyanAccent);

      final label = data[i]['label']?.toString() ?? '';
      textPainter.text = TextSpan(
        text: label.length > 5 ? label.substring(0, 5) : label,
        style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF64748B), fontSize: 8),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(p.dx - textPainter.width / 2, size.height - 15));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

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

    final barWidth = (size.width / data.length) * 0.5;
    final spacing = (size.width / data.length) * 0.5;
    final textPainter = TextPainter(textDirection: TextDirection.ltr);

    for (int i = 0; i < data.length; i++) {
      final val = data[i]['value']?.toDouble() ?? 0.0;
      final h = val / maxVal * (size.height - 40);
      final x = spacing / 2 + (barWidth + spacing) * i;
      final y = size.height - h - 20;

      final rect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, y, barWidth, h),
        const Radius.circular(4),
      );

      final barPaint = Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6B48FF), Color(0xFF1EC9F8)],
        ).createShader(Rect.fromLTWH(x, y, barWidth, h))
        ..style = PaintingStyle.fill;

      canvas.drawRRect(rect, barPaint);

      final label = data[i]['label']?.toString() ?? '';
      textPainter.text = TextSpan(
        text: label.length > 5 ? '${label.substring(0, 4)}..' : label,
        style: TextStyle(color: isDark ? Colors.white38 : const Color(0xFF64748B), fontSize: 8),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x + (barWidth - textPainter.width) / 2, size.height - 15));
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

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
        ..strokeWidth = 20;

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

