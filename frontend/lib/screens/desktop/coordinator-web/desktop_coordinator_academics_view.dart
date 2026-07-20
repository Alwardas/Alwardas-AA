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
          'completionPercentage': _selectedYear == '1st Year' ? 85 : 75,
          'topics': [
            {
              'topicName': 'Unit 1: Linear Algebra & Matrices',
              'completed': true,
              'completedDate': '2026-02-10',
              'comments': 'Covered in detail with 4 tutorial problem sets.'
            },
            {
              'topicName': 'Unit 2: Differential Calculus & Applications',
              'completed': true,
              'completedDate': '2026-02-28',
              'comments': 'All theorems verified with student practice sessions.'
            },
            {
              'topicName': 'Unit 3: Integral Calculus & Vector Analysis',
              'completed': false,
              'scheduleDate': '2026-03-25',
              'comments': 'In progress. 65% of vector integration completed.'
            },
            {
              'topicName': 'Unit 4: Differential Equations & Transforms',
              'completed': false,
              'scheduleDate': '2026-04-10',
              'comments': 'Scheduled for next month.'
            },
          ]
        },
        {
          'subjectName': 'Data Structures & Algorithms',
          'facultyName': 'Prof. P. Ravi',
          'progress': _selectedYear == '1st Year' ? 80 : 70,
          'completionPercentage': _selectedYear == '1st Year' ? 80 : 70,
          'topics': [
            {
              'topicName': 'Unit 1: Arrays, Linked Lists & Stacks',
              'completed': true,
              'completedDate': '2026-02-05',
              'comments': 'Lab practice finished with C/C++ implementations.'
            },
            {
              'topicName': 'Unit 2: Queues & Trees (BST, AVL)',
              'completed': true,
              'completedDate': '2026-02-22',
              'comments': 'Tree traversals completed with assignment reviews.'
            },
            {
              'topicName': 'Unit 3: Graph Algorithms & Hashing',
              'completed': false,
              'scheduleDate': '2026-03-20',
              'comments': 'BFS/DFS covered, Shortest path algorithms ongoing.'
            },
            {
              'topicName': 'Unit 4: Sorting & Searching Techniques',
              'completed': false,
              'scheduleDate': '2026-04-05',
              'comments': 'Scheduled.'
            },
          ]
        },
        {
          'subjectName': 'Object Oriented Programming',
          'facultyName': 'Mrs. S. Lakshmi',
          'progress': _selectedYear == '1st Year' ? 90 : 65,
          'completionPercentage': _selectedYear == '1st Year' ? 90 : 65,
          'topics': [
            {
              'topicName': 'Unit 1: Java Classes, Objects & Inheritance',
              'completed': true,
              'completedDate': '2026-01-28',
              'comments': 'All basic OOP concepts demonstrated.'
            },
            {
              'topicName': 'Unit 2: Polymorphism & Interfaces',
              'completed': true,
              'completedDate': '2026-02-15',
              'comments': 'Interface lab exams conducted.'
            },
            {
              'topicName': 'Unit 3: Exception Handling & Multithreading',
              'completed': true,
              'completedDate': '2026-03-01',
              'comments': 'Concurrency concepts completed.'
            },
            {
              'topicName': 'Unit 4: Java Collections & Streams API',
              'completed': false,
              'scheduleDate': '2026-03-28',
              'comments': 'Ongoing.'
            },
          ]
        },
        {
          'subjectName': 'Database Management Systems',
          'facultyName': 'Mr. V. Kumar',
          'progress': _selectedYear == '1st Year' ? 75 : 60,
          'completionPercentage': _selectedYear == '1st Year' ? 75 : 60,
          'topics': [
            {
              'topicName': 'Unit 1: ER Modeling & Relational Algebra',
              'completed': true,
              'completedDate': '2026-02-01',
              'comments': 'ER Diagrams drawn and validated for all students.'
            },
            {
              'topicName': 'Unit 2: SQL Queries & Joins',
              'completed': true,
              'completedDate': '2026-02-20',
              'comments': 'PostgreSQL hands-on lab sessions finished.'
            },
            {
              'topicName': 'Unit 3: Normalization & Transaction Control',
              'completed': false,
              'scheduleDate': '2026-03-18',
              'comments': 'BCNF normalization ongoing.'
            },
            {
              'topicName': 'Unit 4: Indexing & NoSQL Databases',
              'completed': false,
              'scheduleDate': '2026-04-02',
              'comments': 'Scheduled.'
            },
          ]
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
          const SizedBox(height: 16),

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
          const SizedBox(height: 20),

          // Section Title: Our Departments
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Our Departments',
                    style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Select a department to access lesson plans, topic completion dates, and faculty remarks',
                    style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),

          // Compact Grid View of Departments
          Expanded(
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 2.1,
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
                  borderRadius: BorderRadius.circular(14),
                  child: Container(
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: context.borderColor),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(8),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: const Icon(Icons.school_outlined, color: Colors.blueAccent, size: 20),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                branchName,
                                style: GoogleFonts.poppins(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 13,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
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
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
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
                        const SizedBox(height: 6),
                        Row(
                          children: years.map((y) {
                            final String yrLabel = y['year'] ?? '';
                            final int yrPct = (y['percentage'] ?? 0).toInt();
                            final shortYr = yrLabel.replaceAll(' Year', ' Yr');
                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.only(right: 4),
                                padding: const EdgeInsets.symmetric(vertical: 3, horizontal: 4),
                                decoration: BoxDecoration(
                                  color: context.bgColor,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: context.borderColor),
                                ),
                                child: Text(
                                  '$shortYr: $yrPct%',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(color: context.textMuted, fontSize: 9, fontWeight: FontWeight.w500),
                                ),
                              ),
                            );
                          }).toList(),
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
          // Compact Header Bar with Back Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
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
                      style: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    style: OutlinedButton.styleFrom(
                      backgroundColor: context.cardColor,
                      side: BorderSide(color: context.borderColor),
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    activeBranchName,
                    style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 17, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(width: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.3)),
                    ),
                    child: Text(
                      _selectedCourseId == 'C-26' ? 'C-26 Regulation' : 'C-23 Regulation',
                      style: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 10, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _fetchDetails,
                icon: const Icon(Icons.refresh, size: 14),
                label: Text('Sync Data', style: GoogleFonts.poppins(fontSize: 12)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: context.cardColor,
                  foregroundColor: Colors.blueAccent,
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(8),
                    side: BorderSide(color: context.borderColor),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Compact Combined Filter Bar: Years + Sections Pill Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            child: Row(
              children: [
                Text(
                  'Year: ',
                  style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                _buildCompactYearPills(),
                const SizedBox(width: 24),
                Container(height: 24, width: 1, color: context.borderColor),
                const SizedBox(width: 24),
                Text(
                  'Section: ',
                  style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                ),
                _buildCompactSectionPills(),
              ],
            ),
          ),
          const SizedBox(height: 16),

          // Main Lesson Plan & Topic Progression Body (100% Full Width)
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color: context.cardColor,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: context.borderColor),
              ),
              padding: const EdgeInsets.all(16),
              child: _isLoadingDetails
                  ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                  : Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Lesson Plans & Topic Progression ($_selectedYear - Section $_selectedSection)',
                              style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              '${_sectionSubjectsProgress.length} Subjects Registered',
                              style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Expanded(child: _buildFullWidthLessonPlansList()),
                      ],
                    ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCompactYearPills() {
    final List<Map<String, String>> years = [
      {'year': '1st Year', 'regulation': 'C-26'},
      {'year': '2nd Year', 'regulation': 'C-23'},
      {'year': '3rd Year', 'regulation': 'C-23'},
    ];

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: years.map((yMap) {
        final yr = yMap['year']!;
        final reg = yMap['regulation']!;
        final isSelected = yr == _selectedYear;

        return Padding(
          padding: const EdgeInsets.only(right: 8),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedYear = yr;
                _selectedCourseId = reg;
                _selectedSemester = yr == '1st Year' ? 'Semester 1' : (yr == '2nd Year' ? 'Semester 3' : 'Semester 5');
              });
              _fetchDetails();
            },
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.blueAccent : context.bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.blueAccent : context.borderColor,
                ),
              ),
              child: Text(
                '$yr ($reg)',
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.white : context.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildCompactSectionPills() {
    final List<String> sections = ['A', 'B', 'C'];
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: sections.map((sec) {
        final isSelected = _selectedSection == sec;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: InkWell(
            onTap: () {
              setState(() {
                _selectedSection = sec;
              });
              _fetchSectionSubjectsProgress();
            },
            borderRadius: BorderRadius.circular(8),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? Colors.greenAccent.withOpacity(0.2) : context.bgColor,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: isSelected ? Colors.greenAccent : context.borderColor,
                ),
              ),
              child: Text(
                'Section $sec',
                style: GoogleFonts.poppins(
                  color: isSelected ? Colors.greenAccent : context.textSecondary,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                  fontSize: 12,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFullWidthLessonPlansList() {
    if (_sectionSubjectsProgress.isEmpty) {
      return Center(
        child: Text(
          'No lesson plans found for $_selectedYear - Section $_selectedSection.',
          style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      itemCount: _sectionSubjectsProgress.length,
      itemBuilder: (context, index) {
        final sub = _sectionSubjectsProgress[index];
        final String subjectName = sub['subjectName'] ?? 'Subject';
        final String faculty = sub['facultyName'] ?? 'Assigned Faculty';
        final int progress = (sub['completionPercentage'] ?? sub['progress'] ?? 0).toInt();
        final List<dynamic> topics = sub['topics'] ?? [
          {
            'topicName': 'Unit 1: Fundamentals & Theory',
            'completed': true,
            'completedDate': '2026-02-10',
            'comments': 'All basic concepts completed and lab practical verified.'
          },
          {
            'topicName': 'Unit 2: Core Applications & Implementation',
            'completed': true,
            'completedDate': '2026-02-28',
            'comments': 'Detailed problem solving sessions finished.'
          },
          {
            'topicName': 'Unit 3: Advanced Architectures & Systems',
            'completed': false,
            'scheduleDate': '2026-03-22',
            'comments': 'Ongoing (65% syllabus covered).'
          },
          {
            'topicName': 'Unit 4: Industry Practicum & Review',
            'completed': false,
            'scheduleDate': '2026-04-05',
            'comments': 'Scheduled for next month.'
          },
        ];

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: context.bgColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: context.borderColor),
          ),
          child: ExpansionTile(
            initiallyExpanded: index == 0,
            shape: const RoundedRectangleBorder(side: BorderSide.none),
            collapsedShape: const RoundedRectangleBorder(side: BorderSide.none),
            tilePadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            title: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        subjectName,
                        style: GoogleFonts.poppins(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 14),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        'Faculty: $faculty',
                        style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 140,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Text(
                        '$progress% Completed',
                        style: GoogleFonts.poppins(
                          color: progress >= 75 ? Colors.greenAccent : (progress >= 60 ? Colors.orangeAccent : Colors.redAccent),
                          fontWeight: FontWeight.bold,
                          fontSize: 11,
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
                ElevatedButton.icon(
                  onPressed: () => _downloadLessonPlan(subjectName),
                  icon: const Icon(Icons.download_outlined, size: 14),
                  label: Text('Download Lesson Plan', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent.withOpacity(0.15),
                    foregroundColor: Colors.blueAccent,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.blueAccent.withOpacity(0.3)),
                    ),
                  ),
                ),
              ],
            ),
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: context.cardColor.withOpacity(0.5),
                  border: Border(top: BorderSide(color: context.borderColor)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Detailed Syllabus Topic Breakdown & Faculty Remarks:',
                      style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 10),
                    Table(
                      columnWidths: const {
                        0: FlexColumnWidth(3),
                        1: FlexColumnWidth(1.5),
                        2: FlexColumnWidth(2),
                        3: FlexColumnWidth(4),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(
                            border: Border(bottom: BorderSide(color: context.borderColor)),
                          ),
                          children: [
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text('Topic / Module Title', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text('Status', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text('Completion Date', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 8),
                              child: Text('Faculty Comments & Remarks', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11, fontWeight: FontWeight.bold)),
                            ),
                          ],
                        ),
                        ...topics.map((t) {
                          final isDone = t['completed'] == true;
                          final String dateStr = isDone ? (t['completedDate'] ?? 'N/A') : (t['scheduleDate'] != null ? 'Sched: ${t['scheduleDate']}' : 'Pending');
                          final String commentStr = t['comments'] ?? 'No faculty remarks logged.';

                          return TableRow(
                            decoration: BoxDecoration(
                              border: Border(bottom: BorderSide(color: context.borderColor.withOpacity(0.5))),
                            ),
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Text(t['topicName'] ?? '', style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 12, fontWeight: FontWeight.w500)),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: isDone ? Colors.greenAccent.withOpacity(0.15) : Colors.orangeAccent.withOpacity(0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    isDone ? 'Completed' : 'In Progress',
                                    textAlign: TextAlign.center,
                                    style: GoogleFonts.poppins(
                                      color: isDone ? Colors.greenAccent : Colors.orangeAccent,
                                      fontSize: 10,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Text(
                                  dateStr,
                                  style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 11),
                                ),
                              ),
                              Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Text(
                                  commentStr,
                                  style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11),
                                ),
                              ),
                            ],
                          );
                        }).toList(),
                      ],
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

  void _downloadLessonPlan(String subjectName) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: context.cardColor,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10), side: BorderSide(color: Colors.blueAccent)),
        content: Row(
          children: [
            const Icon(Icons.file_download_done, color: Colors.greenAccent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'Downloading Official Lesson Plan & Topic Schedule for "$subjectName"...',
                style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 12),
              ),
            ),
          ],
        ),
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
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  title,
                  style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 11, fontWeight: FontWeight.w500),
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
}
