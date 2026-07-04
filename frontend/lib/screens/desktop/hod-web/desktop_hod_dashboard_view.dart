import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme_extensions.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/api_config.dart';
import '../../../core/api_constants.dart';
import '../../../core/providers/desktop_providers.dart';

class DesktopHodDashboardView extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DesktopHodDashboardView({super.key, required this.userData});

  @override
  State<DesktopHodDashboardView> createState() => _DesktopHodDashboardViewState();
}

class _DesktopHodDashboardViewState extends State<DesktopHodDashboardView> {
  bool _isLoading = true;
  int _studentCount = 420;
  int _facultyCount = 38;
  int _absentCount = 0;
  double _syllabusProgress = 74.0;
  List<dynamic> _recentActivities = [];

  @override
  void initState() {
    super.initState();
    _loadDashboardData();
  }

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    final branch = widget.userData['branch'] ?? 'Computer Engineering';
    final dateStr = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      // 1. Fetch Today's Attendance Stats
      final statsUri = '${ApiConstants.baseUrl}/api/attendance/stats?branch=${Uri.encodeComponent(branch)}&date=$dateStr&session=Morning';
      final statsRes = await ApiConfig.get(statsUri);
      if (statsRes.success && statsRes.data != null) {
        _absentCount = statsRes.data['totalAbsent'] ?? 0;
      }

      // 2. Fetch Syllabus Progress
      final progressUri = '${ApiConstants.baseUrl}/api/hod/syllabus/branch-progress?branch=${Uri.encodeComponent(branch)}&courseId=C-23';
      final progressRes = await ApiConfig.get(progressUri);
      if (progressRes.success && progressRes.data != null) {
        if (progressRes.data is List && (progressRes.data as List).isNotEmpty) {
          double total = 0;
          for (var d in progressRes.data) {
            total += (d['overall_progress'] ?? d['progress'] ?? 0.0).toDouble();
          }
          _syllabusProgress = total / (progressRes.data as List).length;
        }
      }

      // 3. Fetch notifications for recent activities
      final notifUri = '${ApiConstants.baseUrl}/api/notifications?userId=${widget.userData['id']}&role=HOD&branch=${Uri.encodeComponent(branch)}';
      final notifRes = await ApiConfig.get(notifUri);
      if (notifRes.success && notifRes.data != null) {
        _recentActivities = notifRes.data;
      }

      // 4. Fallback/Simulated counts for students/faculty if needed
      final studentsUri = '${ApiConstants.baseUrl}/api/students?branch=${Uri.encodeComponent(branch)}';
      final studentsRes = await ApiConfig.get(studentsUri);
      if (studentsRes.success && studentsRes.data != null && studentsRes.data is List) {
        _studentCount = (studentsRes.data as List).length;
      }

      final facultyUri = '${ApiConstants.baseUrl}/api/faculty/by-branch?branch=${Uri.encodeComponent(branch)}';
      final facultyRes = await ApiConfig.get(facultyUri);
      if (facultyRes.success && facultyRes.data != null && facultyRes.data is List) {
        _facultyCount = (facultyRes.data as List).length;
      }

    } catch (e) {
      debugPrint("Error loading HOD dashboard stats: $e");
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }

    final branchName = widget.userData['branch'] ?? 'Computer Engineering';
    final hodName = widget.userData['full_name'] ?? 'HOD User';

    return Consumer(
      builder: (context, ref, child) {
        return SingleChildScrollView(
          physics: BouncingScrollPhysics(),
          padding: EdgeInsets.all(30),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting & Info Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Welcome Back, $hodName',
                        style: GoogleFonts.poppins(
                          color: context.textPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Department Workspace for $branchName',
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

              // KPI Cards Grid (HOD specific)
              GridView.count(
                shrinkWrap: true,
                physics: NeverScrollableScrollPhysics(),
                crossAxisCount: 4,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.8,
                children: [
                  _buildKpiCard('Total Students', '$_studentCount', Icons.people_outline, Colors.blueAccent),
                  _buildKpiCard('Total Faculty', '$_facultyCount', Icons.badge_outlined, Colors.greenAccent),
                  _buildKpiCard("Today's Absentees", '$_absentCount', Icons.event_busy_outlined, Colors.redAccent),
                  _buildKpiCard('Syllabus Completion', '${_syllabusProgress.toStringAsFixed(1)}%', Icons.menu_book_outlined, Colors.amberAccent),
                ],
              ),
              SizedBox(height: 30),

              // Quick Actions & Charts Row
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Quick Access Panels
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
                            'Administrative Quick Actions',
                            style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text('Direct shortcuts to manage department functions', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11)),
                          SizedBox(height: 24),
                          Expanded(
                            child: GridView.count(
                              crossAxisCount: 2,
                              crossAxisSpacing: 16,
                              mainAxisSpacing: 16,
                              childAspectRatio: 2.2,
                              children: [
                                _buildActionButton(ref, 'Requests', Icons.mail_outline, Colors.orangeAccent),
                                _buildActionButton(ref, 'Syllabus', Icons.menu_book_outlined, Colors.amberAccent),
                                _buildActionButton(ref, 'Timetable', Icons.schedule_outlined, Colors.blueAccent),
                                _buildActionButton(ref, 'Issues', Icons.report_problem_outlined, Colors.redAccent),
                                _buildActionButton(ref, 'Attendance', Icons.fact_check_outlined, Colors.greenAccent),
                                _buildActionButton(ref, 'Communication', Icons.chat_bubble_outline, Colors.cyanAccent),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: 20),

                  // Syllabus Progress chart (Bar / Circular Indicator representation)
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
                            'Department Syllabus Status',
                            style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 4),
                          Text('Syllabus completion percentage representation', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11)),
                          SizedBox(height: 40),
                          Expanded(
                            child: Center(
                              child: Stack(
                                alignment: Alignment.center,
                                children: [
                                  SizedBox(
                                    width: 160,
                                    height: 160,
                                    child: CircularProgressIndicator(
                                      value: _syllabusProgress / 100.0,
                                      strokeWidth: 16,
                                      backgroundColor: context.borderColor,
                                      valueColor: const AlwaysStoppedAnimation<Color>(Colors.amberAccent),
                                    ),
                                  ),
                                  Column(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        '${_syllabusProgress.toStringAsFixed(1)}%',
                                        style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 28, fontWeight: FontWeight.bold),
                                      ),
                                      Text(
                                        'Completed',
                                        style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
              SizedBox(height: 30),

              // Recent Activities Feed
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
                      'Department Live Activities Feed',
                      style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 16),
                    if (_recentActivities.isEmpty)
                      Padding(
                        padding: EdgeInsets.symmetric(vertical: 20),
                        child: Center(
                          child: Text(
                            'No recent notifications or approval requests.',
                            style: GoogleFonts.poppins(color: context.textMuted, fontSize: 13),
                          ),
                        ),
                      )
                    else
                      ListView.separated(
                        shrinkWrap: true,
                        physics: NeverScrollableScrollPhysics(),
                        itemCount: _recentActivities.length > 5 ? 5 : _recentActivities.length,
                        separatorBuilder: (context, index) => Divider(color: context.borderColor, height: 1),
                        itemBuilder: (context, index) {
                          final item = _recentActivities[index];
                          final String title = _getNotificationTitle(item['type']);
                          final String desc = item['message'] ?? 'Notification received';
                          final String time = item['createdAt'] != null
                              ? DateFormat('hh:mm a, dd MMM').format(DateTime.parse(item['createdAt']))
                              : 'Recent';
                          return _buildActivityRow(title, desc, time, Icons.info_outline, Colors.blueAccent);
                        },
                      ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
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

  Widget _buildActionButton(WidgetRef ref, String label, IconData icon, Color color) {
    return InkWell(
      onTap: () {
        ref.read(desktopNavigationProvider.notifier).state = label;
      },
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: context.bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: context.borderColor),
        ),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Icon(icon, color: color, size: 20),
            SizedBox(width: 12),
            Text(
              label,
              style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13, fontWeight: FontWeight.bold),
            ),
          ],
        ),
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

  String _getNotificationTitle(String? type) {
    switch (type) {
      case 'USER_APPROVAL':
        return 'New User Signup';
      case 'PROFILE_UPDATE_REQUEST':
        return 'Profile Update Request';
      case 'SUBJECT_APPROVAL':
        return 'Subject Request';
      case 'ATTENDANCE_CORRECTION':
        return 'Attendance Correction';
      case 'ISSUE_ASSIGNED':
        return 'Issue Reported';
      default:
        return 'HOD Notice';
    }
  }
}

