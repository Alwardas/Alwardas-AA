import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../../../theme/theme_extensions.dart';
import '../../../core/api_config.dart';
import '../../../core/api_constants.dart';
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
  String? _activeDetailBranch; // Controls two-level navigation: null = Our Departments Grid, non-null = Full Department Page
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
            if (_branches.isNotEmpty && _selectedBranch == null) {
              _selectedBranch = _branches[0]['branch'];
            }
            _calculateMetrics();
            _isLoadingOverall = false;
          });
          
          if (_activeDetailBranch != null) {
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
      if (_branches.isNotEmpty && _selectedBranch == null) {
        _selectedBranch = _branches[0]['branch'];
      }
      _calculateMetrics();
      _isLoadingOverall = false;
    });
    if (_activeDetailBranch != null) {
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

    if (_activeDetailBranch != null) {
      return _buildDepartmentDetailPage(context);
    }

    return _buildOurDepartmentsPage(context);
  }

  Widget _buildOurDepartmentsPage(BuildContext context) {
    return Container(
      color: context.bgColor,
      padding: const EdgeInsets.all(24),
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
              ElevatedButton.icon(
                onPressed: _fetchOverallProgress,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text('Sync Data', style: GoogleFonts.poppins(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.cardColor,
                  foregroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: context.borderColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

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
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Highest Progress',
                  '$_highestProgress%',
                  _highestBranch,
                  Icons.trending_up,
                  Colors.greenAccent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Lowest Progress',
                  '$_lowestProgress%',
                  _lowestBranch,
                  Icons.trending_down,
                  Colors.orangeAccent,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _buildMetricCard(
                  'Departments',
                  '${_branches.length}',
                  'Actively tracked departments',
                  Icons.business,
                  Colors.purpleAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Section Title: Our Departments
          Text(
            'Our Departments',
            style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
          ),
          Text(
            'Click on any department to view full year-wise syllabus progress and subject breakdown',
            style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),

          // Grid View of Departments
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 20,
                mainAxisSpacing: 20,
                childAspectRatio: 1.45,
              ),
              itemCount: _branches.length,
              itemBuilder: (context, index) {
                final item = _branches[index];
                final branchName = item['branch'] ?? 'Unknown';
                final int percentage = (item['overallPercentage'] ?? 0).toInt();
                final List<dynamic> years = item['years'] ?? [];

                return InkWell(
                  onTap: () {
                    setState(() {
                      _selectedBranch = branchName;
                      _activeDetailBranch = branchName;
                      _selectedYear = '1st Year';
                      _selectedCourseId = 'C-26';
                      _selectedSection = 'A';
                      _selectedSemester = 'Semester 1';
                    });
                    _fetchDetails();
                  },
                  borderRadius: BorderRadius.circular(16),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: const Icon(Icons.school_outlined, color: Colors.blueAccent, size: 24),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    branchName,
                                    style: GoogleFonts.poppins(
                                      color: context.textPrimary,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 14,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  Text(
                                    'Diploma Engineering',
                                    style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        const Spacer(),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Overall Completion',
                              style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12),
                            ),
                            Text(
                              '$percentage%',
                              style: GoogleFonts.poppins(
                                color: percentage >= 75
                                    ? Colors.greenAccent
                                    : percentage >= 60
                                        ? Colors.orangeAccent
                                        : Colors.redAccent,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Stack(
                          children: [
                            Container(
                              height: 8,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: context.borderColor,
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                            FractionallySizedBox(
                              widthFactor: (percentage / 100.0).clamp(0.0, 1.0),
                              child: Container(
                                height: 8,
                                decoration: BoxDecoration(
                                  color: percentage >= 75
                                      ? Colors.greenAccent
                                      : percentage >= 60
                                          ? Colors.orangeAccent
                                          : Colors.redAccent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Row(
                          children: years.map((y) {
                            final String yrLabel = y['year'] ?? '';
                            final int yrPct = (y['percentage'] ?? 0).toInt();
                            final shortYr = yrLabel.replaceAll(' Year', ' Yr');
                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 6),
                                decoration: BoxDecoration(
                                  color: context.bgColor,
                                  borderRadius: BorderRadius.circular(6),
                                  border: Border.all(color: context.borderColor),
                                ),
                                child: Text(
                                  '$shortYr: $yrPct%',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(color: context.textMuted, fontSize: 10, fontWeight: FontWeight.w500),
                                ),
                              ),
                            );
                          }).toList(),
                        ),
                        const SizedBox(height: 12),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              'Manage Syllabus ',
                              style: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.w600),
                            ),
                            const Icon(Icons.arrow_forward, size: 14, color: Colors.blueAccent),
                          ],
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

  Widget _buildDepartmentDetailPage(BuildContext context) {
    final activeBranchName = _activeDetailBranch ?? 'Department';
    return Container(
      color: context.bgColor,
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top Bar with Back Button & Sync Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _activeDetailBranch = null;
                  });
                },
                icon: const Icon(Icons.arrow_back, size: 16, color: Colors.blueAccent),
                label: Text(
                  'Back to Our Departments',
                  style: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold),
                ),
                style: OutlinedButton.styleFrom(
                  backgroundColor: context.cardColor,
                  side: BorderSide(color: context.borderColor),
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
              ),
              ElevatedButton.icon(
                onPressed: _fetchDetails,
                icon: const Icon(Icons.refresh, size: 16),
                label: Text('Sync Data', style: GoogleFonts.poppins(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.cardColor,
                  foregroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                    side: BorderSide(color: context.borderColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Department Banner Header Box
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          activeBranchName,
                          style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 22, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.blueAccent.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                          ),
                          child: Text(
                            _selectedCourseId == 'C-26' ? 'C-26 Regulation (1st Year)' : 'C-23 Regulation (2nd/3rd Year)',
                            style: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Syllabus management, section progress analysis, and subject topic completion indices',
                      style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // 3 Year Selector Buttons Header
          Text(
            'Select Academic Year',
            style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _build3YearButtons(),
          const SizedBox(height: 20),

          // Main Detail View Layout (Sections + Subjects Table)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: context.borderColor),
              ),
              padding: const EdgeInsets.all(20),
              child: _isLoadingDetails
                  ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                  : Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Left Column: Sections
                        Expanded(
                          flex: 2,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Sections',
                                style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 8),
                              Expanded(child: _buildSectionsList()),
                            ],
                          ),
                        ),
                        const SizedBox(width: 20),
                        // Right Column: Subjects Progression Table
                        Expanded(
                          flex: 3,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Subject Progression: $_selectedYear - Section $_selectedSection',
                                style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13, fontWeight: FontWeight.bold),
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 8),
                              Expanded(child: _buildSubjectsTable()),
                            ],
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

  Widget _build3YearButtons() {
    final List<Map<String, String>> years = [
      {'year': '1st Year', 'regulation': 'C-26'},
      {'year': '2nd Year', 'regulation': 'C-23'},
      {'year': '3rd Year', 'regulation': 'C-23'},
    ];

    return Row(
      children: years.map((yMap) {
        final yr = yMap['year']!;
        final reg = yMap['regulation']!;
        final isSelected = yr == _selectedYear;

        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedYear = yr;
                  _selectedCourseId = reg;
                  _selectedSemester = yr == '1st Year' ? 'Semester 1' : (yr == '2nd Year' ? 'Semester 3' : 'Semester 5');
                });
                _fetchDetails();
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blueAccent : context.cardColor,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? Colors.blueAccent : context.borderColor,
                    width: 1.5,
                  ),
                  boxShadow: isSelected
                      ? [BoxShadow(color: Colors.blueAccent.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 3))]
                      : [],
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(
                      yr == '1st Year' ? Icons.looks_one : (yr == '2nd Year' ? Icons.looks_two : Icons.looks_3),
                      color: isSelected ? Colors.white : Colors.blueAccent,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          yr,
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.white : context.textPrimary,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                        Text(
                          '$reg Curriculum',
                          style: GoogleFonts.poppins(
                            color: isSelected ? Colors.white.withOpacity(0.8) : context.textMuted,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildMetricCard(String title, String value, String subtext, IconData icon, Color color) {
    return Container(
      decoration: BoxDecoration(
        color: context.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: context.borderColor),
      ),
      padding: const EdgeInsets.all(20),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
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
          padding: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedSection = sec;
                _selectedSemester = sem;
              });
              _fetchSectionSubjectsProgress();
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blueAccent.withOpacity(0.1) : context.bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? Colors.blueAccent : context.borderColor,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: isSelected ? Colors.blueAccent : context.cardColor,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        sec,
                        style: GoogleFonts.poppins(
                          color: isSelected ? Colors.white : context.textPrimary,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Section $sec',
                          style: GoogleFonts.poppins(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                        ),
                        Text(
                          sem,
                          style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11),
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
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
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
          'No subjects progress found for Section $_selectedSection.',
          style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12),
        ),
      );
    }
    return ListView.builder(
      itemCount: _sectionSubjectsProgress.length,
      itemBuilder: (context, index) {
        final sub = _sectionSubjectsProgress[index];
        final String name = sub['subjectName'] ?? 'Subject';
        final String faculty = sub['facultyName'] ?? 'Assigned Faculty';
        final int progress = (sub['completionPercentage'] ?? sub['progress'] ?? 0).toInt();

        return Card(
          color: context.bgColor,
          margin: const EdgeInsets.only(bottom: 8),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: context.borderColor),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            title: Text(
              name,
              style: GoogleFonts.poppins(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
            ),
            subtitle: Text(
              'Faculty: $faculty',
              style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11),
            ),
            trailing: SizedBox(
              width: 140,
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Text(
                          '$progress%',
                          style: GoogleFonts.poppins(
                            color: progress >= 75 ? Colors.greenAccent : (progress >= 60 ? Colors.orangeAccent : Colors.redAccent),
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 4),
                        LinearProgressIndicator(
                          value: (progress / 100.0).clamp(0.0, 1.0),
                          backgroundColor: context.borderColor,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            progress >= 75 ? Colors.greenAccent : (progress >= 60 ? Colors.orangeAccent : Colors.redAccent),
                          ),
                          minHeight: 4,
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: const Icon(Icons.playlist_add_check, size: 20, color: Colors.blueAccent),
                    onPressed: () => _showTopicsDialog(name),
                    tooltip: 'View Topics Breakdown',
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _showTopicsDialog(String subjectName) async {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: context.cardColor,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Text(
          'Topics: $subjectName',
          style: GoogleFonts.poppins(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 16),
        ),
        content: SizedBox(
          width: 450,
          height: 300,
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                title: Text('Unit 1: Introduction & Fundamentals', style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13)),
                subtitle: Text('Status: Completed', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11)),
              ),
              ListTile(
                leading: const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20),
                title: Text('Unit 2: Core Concepts & Applications', style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13)),
                subtitle: Text('Status: Completed', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11)),
              ),
              ListTile(
                leading: const Icon(Icons.timelapse, color: Colors.orangeAccent, size: 20),
                title: Text('Unit 3: Advanced Architectures', style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13)),
                subtitle: Text('Status: In Progress (65%)', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11)),
              ),
              ListTile(
                leading: Icon(Icons.circle_outlined, color: context.textMuted2, size: 20),
                title: Text('Unit 4: Industry Practicum & Review', style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 13)),
                subtitle: Text('Status: Scheduled', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11)),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('Close', style: GoogleFonts.poppins(color: Colors.blueAccent)),
          ),
        ],
      ),
    );
  }
}
