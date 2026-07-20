import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme_extensions.dart';
import '../../../core/api_config.dart';
import '../../../core/api_constants.dart';
import '../../../data/courses_data.dart';
import '../../../widgets/desktop_skeleton_loading.dart';

class DesktopCoordinatorAcademicsView extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DesktopCoordinatorAcademicsView({super.key, required this.userData});

  @override
  State<DesktopCoordinatorAcademicsView> createState() => _DesktopCoordinatorAcademicsViewState();
}

class _DesktopCoordinatorAcademicsViewState extends State<DesktopCoordinatorAcademicsView> {
  bool _isLoadingOverall = true;
  bool _isLoadingDetails = false;
  List<dynamic> _branches = [];
  
  String? _selectedBranch;
  String _selectedYear = '1st Year';
  String _selectedCourseId = 'C-26';
  String? _selectedSection = 'A';
  String? _selectedSemester;
  
  List<dynamic> _yearSectionsProgress = [];
  List<dynamic> _sectionSubjectsProgress = [];

  // Institution metrics
  int _avgProgress = 0;
  String _highestBranch = 'N/A';
  int _highestProgress = 0;
  String _lowestBranch = 'N/A';
  int _lowestProgress = 100;

  @override
  void initState() {
    super.initState();
    _fetchOverallProgress();
  }

  Future<void> _fetchOverallProgress() async {
    setState(() => _isLoadingOverall = true);
    try {
      final response = await ApiConfig.get(
        '${ApiConstants.baseUrl}/api/coordinator/overall-syllabus-progress'
      );
      if (response.success && response.data != null) {
        final List<dynamic> data = response.data is List ? response.data : [];
        if (mounted) {
          setState(() {
            _branches = data;
            if (_branches.isNotEmpty) {
              // Select first branch by default
              _selectedBranch = _branches[0]['branch'];
            }
            _calculateMetrics();
            _isLoadingOverall = false;
          });
          
          if (_selectedBranch != null) {
            _fetchDetails();
          }
        }
      } else {
        _loadFallbackOverall();
      }
    } catch (e) {
      debugPrint("Error fetching overall syllabus progress: $e");
      _loadFallbackOverall();
    }
  }

  void _loadFallbackOverall() {
    if (!mounted) return;
    setState(() {
      _branches = [
        {
          'branch': 'Computer Engineering',
          'overallPercentage': 75,
          'years': [
            {'year': '1st Year', 'percentage': 80},
            {'year': '2nd Year', 'percentage': 70},
            {'year': '3rd Year', 'percentage': 75},
          ]
        },
        {
          'branch': 'Civil Engineering',
          'overallPercentage': 60,
          'years': [
            {'year': '1st Year', 'percentage': 65},
            {'year': '2nd Year', 'percentage': 55},
            {'year': '3rd Year', 'percentage': 60},
          ]
        },
        {
          'branch': 'Electronics & Communication Engineering',
          'overallPercentage': 82,
          'years': [
            {'year': '1st Year', 'percentage': 85},
            {'year': '2nd Year', 'percentage': 80},
            {'year': '3rd Year', 'percentage': 81},
          ]
        },
        {
          'branch': 'Electrical & Electronics Engineering',
          'overallPercentage': 68,
          'years': [
            {'year': '1st Year', 'percentage': 70},
            {'year': '2nd Year', 'percentage': 65},
            {'year': '3rd Year', 'percentage': 69},
          ]
        },
        {
          'branch': 'Mechanical Engineering',
          'overallPercentage': 55,
          'years': [
            {'year': '1st Year', 'percentage': 58},
            {'year': '2nd Year', 'percentage': 50},
            {'year': '3rd Year', 'percentage': 57},
          ]
        }
      ];
      if (_branches.isNotEmpty) {
        _selectedBranch = _branches[0]['branch'];
      }
      _calculateMetrics();
      _isLoadingOverall = false;
    });
    if (_selectedBranch != null) {
      _fetchDetails();
    }
  }

  void _calculateMetrics() {
    if (_branches.isEmpty) return;
    int total = 0;
    int maxP = -1;
    int minP = 101;
    String maxB = 'N/A';
    String minB = 'N/A';

    for (var b in _branches) {
      final int p = (b['overallPercentage'] ?? 0).toInt();
      final String name = b['branch'] ?? 'Unknown';
      total += p;
      if (p > maxP) {
        maxP = p;
        maxB = name;
      }
      if (p < minP) {
        minP = p;
        minB = name;
      }
    }
    _avgProgress = (total / _branches.length).round();
    _highestBranch = maxB;
    _highestProgress = maxP;
    _lowestBranch = minB;
    _lowestProgress = minP;
  }

  Future<void> _fetchDetails() async {
    if (_selectedBranch == null) return;
    setState(() => _isLoadingDetails = true);
    
    // Fetch Year sections progress
    try {
      final response = await ApiConfig.get(
        '${ApiConstants.baseUrl}/api/hod/syllabus/year-sections-progress?branch=${Uri.encodeComponent(_selectedBranch!)}&year=${Uri.encodeComponent(_selectedYear)}&courseId=$_selectedCourseId'
      );
      if (response.success && response.data != null) {
        setState(() {
          _yearSectionsProgress = response.data is List ? response.data : [];
          if (_yearSectionsProgress.isNotEmpty) {
            final firstSec = _yearSectionsProgress[0];
            _selectedSection = firstSec['sectionName'] ?? firstSec['section'] ?? 'A';
            _selectedSemester = firstSec['semester'] ?? (_selectedYear == '1st Year' ? 'Semester 1' : (_selectedYear == '2nd Year' ? 'Semester 3' : 'Semester 5'));
          } else {
            _selectedSection = 'A';
            _selectedSemester = _selectedYear == '1st Year' ? 'Semester 1' : (_selectedYear == '2nd Year' ? 'Semester 3' : 'Semester 5');
            _yearSectionsProgress = [
              {'sectionName': 'A', 'percentage': 0, 'semester': _selectedSemester},
              {'sectionName': 'B', 'percentage': 0, 'semester': _selectedSemester},
            ];
          }
        });
        _fetchSectionSubjectsProgress();
      } else {
        _loadFallbackDetails();
      }
    } catch (e) {
      debugPrint("Error fetching year sections details: $e");
      _loadFallbackDetails();
    }
  }

  void _loadFallbackDetails() {
    setState(() {
      final String defaultSem = _selectedYear == '1st Year' 
          ? 'Semester 1' 
          : (_selectedYear == '2nd Year' ? 'Semester 3' : 'Semester 5');
      _yearSectionsProgress = [
        {'section': 'A', 'percentage': _selectedYear == '1st Year' ? 82 : 72, 'semester': defaultSem},
        {'section': 'B', 'percentage': _selectedYear == '1st Year' ? 78 : 68, 'semester': defaultSem},
      ];
      _selectedSection = 'A';
      _selectedSemester = defaultSem;
    });
    _fetchSectionSubjectsProgress();
  }

  Future<void> _fetchSectionSubjectsProgress() async {
    if (_selectedBranch == null || _selectedSection == null || _selectedSemester == null) return;
    try {
      final response = await ApiConfig.get(
        '${ApiConstants.baseUrl}/api/hod/syllabus/section-subjects-progress?branch=${Uri.encodeComponent(_selectedBranch!)}&year=${Uri.encodeComponent(_selectedYear)}&section=${Uri.encodeComponent(_selectedSection!)}&courseId=$_selectedCourseId&semester=${Uri.encodeComponent(_selectedSemester!)}'
      );
      if (response.success && response.data != null) {
        setState(() {
          _sectionSubjectsProgress = response.data is List ? response.data : [];
          _isLoadingDetails = false;
        });
      } else {
        _loadFallbackSubjects();
      }
    } catch (e) {
      debugPrint("Error fetching subjects progress: $e");
      _loadFallbackSubjects();
    }
  }

  void _loadFallbackSubjects() {
    setState(() {
      _sectionSubjectsProgress = [
        {
          'subjectName': 'Engineering Mathematics',
          'facultyName': 'Dr. K. Srinivas',
          'progress': _selectedYear == '1st Year' ? 85 : 75,
          'completionPercentage': _selectedYear == '1st Year' ? 85 : 75
        },
        {
          'subjectName': 'Data Structures & Algorithms',
          'facultyName': 'Prof. P. Ravi',
          'progress': _selectedYear == '1st Year' ? 80 : 70,
          'completionPercentage': _selectedYear == '1st Year' ? 80 : 70
        },
        {
          'subjectName': 'Object Oriented Programming',
          'facultyName': 'Mrs. S. Lakshmi',
          'progress': _selectedYear == '1st Year' ? 90 : 65,
          'completionPercentage': _selectedYear == '1st Year' ? 90 : 65
        },
        {
          'subjectName': 'Database Management Systems',
          'facultyName': 'Mr. V. Kumar',
          'progress': _selectedYear == '1st Year' ? 75 : 60,
          'completionPercentage': _selectedYear == '1st Year' ? 75 : 60
        }
      ];
      _isLoadingDetails = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoadingOverall) {
      return Scaffold(
        backgroundColor: context.bgColor,
        body: const DesktopSkeletonDashboard(),
      );
    }

    return Container(
      color: context.bgColor,
      padding: EdgeInsets.all(24),
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
                    'Academics Dashboard',
                    style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Institution-wide syllabus tracking, department statistics, and subject progression indices',
                    style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _fetchOverallProgress,
                    icon: Icon(Icons.refresh, size: 16),
                    label: Text('Sync Data', style: GoogleFonts.poppins(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: context.cardColor,
                      foregroundColor: Colors.blueAccent,
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                        side: BorderSide(color: context.borderColor),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 20),

          // Institution KPI Stats Row
          Row(
            children: [
              Expanded(
                child: _buildMetricCard(
                  'Average Progress',
                  '$_avgProgress%',
                  'Overall syllabus completion',
                  Icons.auto_graph,
                  Colors.blueAccent,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Highest Progress',
                  '$_highestProgress%',
                  _highestBranch,
                  Icons.trending_up,
                  Colors.greenAccent,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Lowest Progress',
                  '$_lowestProgress%',
                  _lowestBranch,
                  Icons.trending_down,
                  Colors.orangeAccent,
                ),
              ),
              SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Departments',
                  '${_branches.length}',
                  'Actively tracked branches',
                  Icons.business,
                  Colors.purpleAccent,
                ),
              ),
            ],
          ),
          SizedBox(height: 20),

          // Main split layout
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Panel: Master Branch List
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor),
                    ),
                    padding: EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Tracked Branches',
                          style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Select a branch to view detailed section and subject reports',
                          style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11),
                        ),
                        SizedBox(height: 16),
                        Expanded(
                          child: ListView.builder(
                            itemCount: _branches.length,
                            itemBuilder: (context, index) {
                              final item = _branches[index];
                              final branchName = item['branch'] ?? 'Unknown';
                              final int percentage = (item['overallPercentage'] ?? 0).toInt();
                              final isSelected = _selectedBranch == branchName;

                              return Padding(
                                padding: EdgeInsets.only(bottom: 8),
                                child: InkWell(
                                  onTap: () {
                                    setState(() {
                                      _selectedBranch = branchName;
                                    });
                                    _fetchDetails();
                                  },
                                  borderRadius: BorderRadius.circular(12),
                                  child: Container(
                                    padding: EdgeInsets.all(16),
                                    decoration: BoxDecoration(
                                      color: isSelected ? Colors.blueAccent.withValues(alpha: 0.08) : Colors.transparent,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: isSelected ? Colors.blueAccent.withValues(alpha: 0.4) : context.borderColor,
                                        width: 1,
                                      ),
                                    ),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                          children: [
                                            Expanded(
                                              child: Text(
                                                branchName,
                                                style: GoogleFonts.poppins(
                                                  color: context.textPrimary,
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 13,
                                                ),
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ),
                                            SizedBox(width: 8),
                                            Text(
                                              '$percentage%',
                                              style: GoogleFonts.poppins(
                                                color: percentage >= 75
                                                    ? Colors.greenAccent
                                                    : percentage >= 60
                                                        ? Colors.orangeAccent
                                                        : Colors.redAccent,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ],
                                        ),
                                        SizedBox(height: 10),
                                        Stack(
                                          children: [
                                            Container(
                                              height: 6,
                                              width: double.infinity,
                                              decoration: BoxDecoration(
                                                color: context.borderColor,
                                                borderRadius: BorderRadius.circular(3),
                                              ),
                                            ),
                                            FractionallySizedBox(
                                              widthFactor: (percentage / 100.0).clamp(0.0, 1.0),
                                              child: Container(
                                                height: 6,
                                                decoration: BoxDecoration(
                                                  color: percentage >= 75
                                                      ? Colors.greenAccent
                                                      : percentage >= 60
                                                          ? Colors.orangeAccent
                                                          : Colors.redAccent,
                                                  borderRadius: BorderRadius.circular(3),
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
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
                SizedBox(width: 20),

                // Right Panel: Details (Syllabus Tracker)
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor),
                    ),
                    padding: EdgeInsets.all(20),
                    child: _selectedBranch == null
                        ? Center(child: Text('Select a department to view syllabus progress details.', style: TextStyle(color: context.textMuted)))
                        : Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Detailed Branch Header
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _selectedBranch!,
                                          style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 16, fontWeight: FontWeight.bold),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                        Text(
                                          'Syllabus & curriculum tracking details',
                                          style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Container(
                                    padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                    decoration: BoxDecoration(
                                      color: context.bgColor,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: context.borderColor),
                                    ),
                                    child: Text(
                                      _selectedCourseId == 'C-26' ? 'C-26 Regulation' : 'C-23 Regulation',
                                      style: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                    ),
                                  ),
                                ],
                              ),
                              Divider(color: context.borderColor, height: 24),

                              // Academic Year Row Selector
                              Text(
                                'Academic Year',
                                style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                              ),
                              SizedBox(height: 8),
                              _buildYearSelector(),
                              SizedBox(height: 16),

                              // Sections list & Subjects progression split or grid
                              Expanded(
                                child: _isLoadingDetails
                                    ? Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                                    : Row(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          // Sections Overview Column
                                          Expanded(
                                            flex: 2,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Sections',
                                                  style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                                                ),
                                                SizedBox(height: 8),
                                                Expanded(child: _buildSectionsList()),
                                              ],
                                            ),
                                          ),
                                          SizedBox(width: 16),
                                          // Subjects progression table
                                          Expanded(
                                            flex: 3,
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  'Subject Progression: $_selectedYear - Section $_selectedSection',
                                                  style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                                                  overflow: TextOverflow.ellipsis,
                                                ),
                                                SizedBox(height: 8),
                                                Expanded(child: _buildSubjectsTable()),
                                              ],
                                            ),
                                          ),
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

  Widget _buildMetricCard(String title, String value, String subtext, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      padding: EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                ),
                Text(
                  title,
                  style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                ),
                Text(
                  subtext,
                  style: GoogleFonts.poppins(color: context.textMuted, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelector() {
    final List<String> years = ['1st Year', '2nd Year', '3rd Year'];
    return Row(
      children: years.map((y) {
        final isSelected = y == _selectedYear;
        return Expanded(
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedYear = y;
                  _selectedCourseId = y == '1st Year' ? 'C-26' : 'C-23';
                });
                _fetchDetails();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blueAccent.withValues(alpha: 0.15) : context.bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.blueAccent : context.borderColor,
                  ),
                ),
                child: Center(
                  child: Text(
                    y,
                    style: GoogleFonts.poppins(
                      color: isSelected ? context.textPrimary : context.textSecondary,
                      fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildSectionsList() {
    if (_yearSectionsProgress.isEmpty) {
      return Center(
        child: Text(
          'No sections data.',
          style: GoogleFonts.poppins(color: context.textMuted2, fontSize: 11),
        ),
      );
    }
    return ListView.builder(
      itemCount: _yearSectionsProgress.length,
      itemBuilder: (context, index) {
        final item = _yearSectionsProgress[index];
        final sec = item['sectionName'] ?? item['section'] ?? 'A';
        final int progress = (item['percentage'] ?? 0).toInt();
        final defaultSem = _selectedYear == '1st Year' ? 'Semester 1' : (_selectedYear == '2nd Year' ? 'Semester 3' : 'Semester 5');
        final sem = item['semester'] ?? defaultSem;
        final isSelected = _selectedSection == sec;

        return Padding(
          padding: EdgeInsets.only(bottom: 6),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedSection = sec;
                _selectedSemester = sem;
              });
              _fetchSectionSubjectsProgress();
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.white.withValues(alpha: 0.04) : Colors.transparent,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: isSelected ? context.textMuted2 : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
                    radius: 16,
                    child: Text(
                      sec,
                      style: TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
                    ),
                  ),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Section $sec',
                          style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 12, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          sem,
                          style: GoogleFonts.poppins(color: context.textMuted, fontSize: 9),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '$progress%',
                    style: GoogleFonts.poppins(
                      color: progress >= 75
                          ? Colors.greenAccent
                          : progress >= 60
                              ? Colors.orangeAccent
                              : Colors.redAccent,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildSubjectsTable() {
    if (_sectionSubjectsProgress.isEmpty) {
      return Center(
        child: Text(
          'No subjects found.',
          style: GoogleFonts.poppins(color: context.textMuted2, fontSize: 11),
        ),
      );
    }
    return Container(
      decoration: BoxDecoration(
        color: context.bgColor.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.borderColor),
      ),
      clipBehavior: Clip.antiAlias,
      child: ListView(
        children: [
          DataTable(
            columnSpacing: 12,
            horizontalMargin: 12,
            headingRowHeight: 38,
            dataRowMinHeight: 38,
            dataRowMaxHeight: 52,
            columns: [
              DataColumn(
                label: Text('Subject', style: GoogleFonts.poppins(color: context.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              DataColumn(
                label: Text('Faculty', style: GoogleFonts.poppins(color: context.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              DataColumn(
                label: Text('Completion', style: GoogleFonts.poppins(color: context.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
              DataColumn(
                label: Text('Details', style: GoogleFonts.poppins(color: context.textSecondary, fontWeight: FontWeight.bold, fontSize: 12)),
              ),
            ],
            rows: _sectionSubjectsProgress.map((sub) {
              final int completion = (sub['progress'] ?? sub['completionPercentage'] ?? 0).toInt();
              final subjectId = sub['subjectId'] ?? sub['id'] ?? '';
              final subjectName = sub['subjectName'] ?? sub['name'] ?? '';
              
              return DataRow(
                cells: [
                  DataCell(
                    Text(
                      subjectName,
                      style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 11, fontWeight: FontWeight.bold),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DataCell(
                    Text(
                      sub['facultyName'] ?? 'Not Assigned',
                      style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 11),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  DataCell(
                    Row(
                      children: [
                        SizedBox(
                          width: 40,
                          child: LinearProgressIndicator(
                            value: completion / 100.0,
                            backgroundColor: context.borderColor,
                            minHeight: 4,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              completion >= 75
                                  ? Colors.greenAccent
                                  : completion >= 60
                                      ? Colors.orangeAccent
                                      : Colors.redAccent,
                            ),
                          ),
                        ),
                        SizedBox(width: 6),
                        Text(
                          '$completion%',
                          style: GoogleFonts.poppins(
                            color: completion >= 75
                                ? Colors.greenAccent
                                : completion >= 60
                                    ? Colors.orangeAccent
                                    : Colors.redAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  DataCell(
                    IconButton(
                      icon: Icon(Icons.assignment_outlined, color: Colors.blueAccent, size: 16),
                      tooltip: 'View Lesson Plan',
                      onPressed: () {
                        _showLessonPlanDialog(context, subjectId, subjectName);
                      },
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  void _showLessonPlanDialog(BuildContext context, String subjectId, String subjectName) {
    showDialog(
      context: context,
      builder: (context) {
        return _LessonPlanDialog(
          subjectId: subjectId,
          subjectName: subjectName,
          branch: _selectedBranch ?? '',
          section: _selectedSection ?? 'A',
          userData: widget.userData,
        );
      },
    );
  }
}

class _LessonPlanDialog extends StatefulWidget {
  final String subjectId;
  final String subjectName;
  final String branch;
  final String section;
  final Map<String, dynamic> userData;

  const _LessonPlanDialog({
    required this.subjectId,
    required this.subjectName,
    required this.branch,
    required this.section,
    required this.userData,
  });

  @override
  State<_LessonPlanDialog> createState() => _LessonPlanDialogState();
}

class _LessonPlanDialogState extends State<_LessonPlanDialog> {
  bool _isLoading = true;
  List<dynamic> _topics = [];
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _fetchTopics();
  }

  Future<void> _fetchTopics() async {
    Map<String, dynamic> apiTopicsMap = {};
    try {
      final response = await ApiConfig.get(
        '${ApiConstants.baseUrl}/api/faculty/hod-lesson-topics?subject_id=${Uri.encodeComponent(widget.subjectId)}&section=${Uri.encodeComponent(widget.section)}&branch=${Uri.encodeComponent(widget.branch)}'
      );
      if (response.success && response.data != null) {
        final List<dynamic> data = response.data is List ? response.data : [];
        for (var t in data) {
          if (t['id'] != null) {
            apiTopicsMap[t['id'].toString().toLowerCase()] = t;
          }
        }
      }
    } catch (e) {
      debugPrint("Error fetching lesson topics from API: $e");
    }

    try {
      final subjectDetails = await CoursesData.getSubjectDetails(widget.subjectId);
      List<dynamic> localTopics = [];

      if (subjectDetails != null && subjectDetails['units'] != null) {
        for (var unit in subjectDetails['units']) {
          localTopics.add({
            'type': 'unit',
            'topicName': 'Unit ${unit['unitNo']}: ${unit['title']}',
            'unit': 'Unit ${unit['unitNo']}',
          });

          if (unit['topics'] != null) {
            for (var t in unit['topics']) {
              final apiData = apiTopicsMap[t['id'].toString().toLowerCase()];
              localTopics.add({
                'id': t['id'],
                'type': t['type'] ?? 'topic',
                'topicName': t['topic'],
                'unit': 'Unit ${unit['unitNo']}',
                'scheduleDate': apiData?['scheduleDate'],
                'completed': apiData?['completed'] ?? false,
                'completedDate': apiData?['completedDate'],
              });
            }
          }
        }
      } else {
        // Fallback: If local JSON is not found, use whatever backend returns
        if (apiTopicsMap.isNotEmpty) {
          apiTopicsMap.forEach((key, val) {
            localTopics.add({
              'id': val['id'],
              'type': 'topic',
              'topicName': val['topic'] ?? 'Topic',
              'unit': 'General',
              'scheduleDate': val['scheduleDate'],
              'completed': val['completed'] ?? false,
              'completedDate': val['completedDate'],
            });
          });
        }
      }

      if (mounted) {
        setState(() {
          _topics = localTopics;
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Error loading topics: $e");
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  String _formatDate(dynamic dateVal) {
    if (dateVal == null) return '';
    try {
      final parsed = DateTime.parse(dateVal.toString()).toLocal();
      return DateFormat('MMM dd, yyyy').format(parsed);
    } catch (_) {
      return dateVal.toString();
    }
  }

  @override
  Widget build(BuildContext context) {
    final filteredTopics = _topics.where((t) {
      if (_searchQuery.isEmpty) return true;
      final name = (t['topicName'] ?? '').toString().toLowerCase();
      return name.contains(_searchQuery.toLowerCase());
    }).toList();

    // Calculate dynamic stats
    int totalTopics = _topics.where((t) => t['type'] != 'unit').length;
    int completedTopics = _topics.where((t) => t['type'] != 'unit' && t['completed'] == true).length;
    double progressPct = totalTopics > 0 ? completedTopics / totalTopics : 0.0;

    return Dialog(
      backgroundColor: context.cardColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Container(
        width: 650,
        height: 600,
        padding: EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Title block
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.subjectName,
                        style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        'Code: ${widget.subjectId} | Section ${widget.section} (${widget.branch})',
                        style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11),
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: Icon(Icons.close, color: context.textSecondary),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            Divider(color: context.borderColor, height: 24),

            // Completion stats
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Syllabus Coverage',
                            style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.w500),
                          ),
                          Text(
                            '${(progressPct * 100).round()}% ($completedTopics/$totalTopics topics)',
                            style: GoogleFonts.poppins(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      SizedBox(height: 6),
                      Stack(
                        children: [
                          Container(
                            height: 6,
                            width: double.infinity,
                            decoration: BoxDecoration(color: context.borderColor, borderRadius: BorderRadius.circular(3)),
                          ),
                          FractionallySizedBox(
                            widthFactor: progressPct.clamp(0.0, 1.0),
                            child: Container(
                              height: 6,
                              decoration: BoxDecoration(
                                color: Colors.greenAccent,
                                borderRadius: BorderRadius.circular(3),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            SizedBox(height: 16),

            // Search box
            Container(
              height: 38,
              decoration: BoxDecoration(
                color: context.bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: context.borderColor),
              ),
              padding: EdgeInsets.symmetric(horizontal: 12),
              child: Row(
                children: [
                  Icon(Icons.search, color: context.textMuted, size: 16),
                  SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      style: TextStyle(color: context.textPrimary, fontSize: 12),
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search topics...',
                        hintStyle: GoogleFonts.poppins(color: context.textMuted2),
                        border: InputBorder.none,
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: 16),

            // Topics List
            Expanded(
              child: _isLoading
                  ? Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                  : filteredTopics.isEmpty
                      ? Center(
                          child: Text(
                            'No topics found.',
                            style: GoogleFonts.poppins(color: context.textMuted2, fontSize: 12),
                          ),
                        )
                      : ListView.builder(
                          itemCount: filteredTopics.length,
                          itemBuilder: (context, index) {
                            final topic = filteredTopics[index];
                            final isUnit = topic['type'] == 'unit';

                            if (isUnit) {
                              return Container(
                                margin: EdgeInsets.only(top: 12, bottom: 8),
                                padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                decoration: BoxDecoration(
                                  color: Colors.blueAccent.withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.2)),
                                ),
                                child: Text(
                                  topic['topicName'] ?? '',
                                  style: GoogleFonts.poppins(
                                    color: Colors.blueAccent,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              );
                            }

                            final isCompleted = topic['completed'] == true;
                            final hasSchedule = topic['scheduleDate'] != null;

                            return Container(
                              margin: EdgeInsets.only(bottom: 4),
                              padding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.02),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: context.borderColor),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    isCompleted ? Icons.check_circle : Icons.circle_outlined,
                                    color: isCompleted ? Colors.greenAccent : context.textMuted2,
                                    size: 18,
                                  ),
                                  SizedBox(width: 12),
                                  Expanded(
                                    child: Text(
                                      topic['topicName'] ?? '',
                                      style: GoogleFonts.poppins(
                                        color: isCompleted ? context.textSecondary : context.textPrimary,
                                        fontSize: 12,
                                        decoration: isCompleted ? TextDecoration.lineThrough : null,
                                      ),
                                    ),
                                  ),
                                  SizedBox(width: 8),
                                  // Status badges
                                  if (isCompleted)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.greenAccent.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.greenAccent.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        'Completed: ${_formatDate(topic['completedDate'])}',
                                        style: GoogleFonts.poppins(color: Colors.greenAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  else if (hasSchedule)
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: Colors.blueAccent.withValues(alpha: 0.1),
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                                      ),
                                      child: Text(
                                        'Scheduled: ${_formatDate(topic['scheduleDate'])}',
                                        style: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                    )
                                  else
                                    Container(
                                      padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: context.borderColor,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        'Unscheduled',
                                        style: GoogleFonts.poppins(color: context.textMuted, fontSize: 9),
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
    );
  }
}

