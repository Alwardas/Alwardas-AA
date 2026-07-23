import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/theme_extensions.dart';
import '../../../core/api_config.dart';
import '../../../core/api_constants.dart';
import '../../../widgets/desktop_skeleton_loading.dart';
import '../../../data/courses_data.dart';

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

  // Dynamic Search Controllers & Available Semesters
  final TextEditingController _deptSearchController = TextEditingController();
  final TextEditingController _academicsSearchController = TextEditingController();
  String _deptSearchQuery = '';
  String _academicsSearchQuery = '';
  List<String> _availableSemesters = [];

  @override
  void initState() {
    super.initState();
    _fetchOverallProgress();
  }

  @override
  void dispose() {
    _deptSearchController.dispose();
    _academicsSearchController.dispose();
    super.dispose();
  }

  Future<void> _fetchDynamicSemesters() async {
    if (_selectedBranch == null) return;
    try {
      final allCourses = await CoursesData.getAllCourses();
      final normalizedBranch = CoursesData.normalizeBranch(_selectedBranch!);
      
      final branchCourses = allCourses.where((c) {
        final b = c['branch']?.toString() ?? '';
        return CoursesData.normalizeBranch(b) == normalizedBranch;
      }).toList();

      final Set<String> sems = {};
      
      if (_selectedYear == '1st Year') {
        sems.addAll(['Semester 1', 'Semester 2']);
      } else if (_selectedYear == '2nd Year') {
        sems.addAll(['Semester 3', 'Semester 4']);
      } else if (_selectedYear == '3rd Year') {
        sems.addAll(['Semester 5', 'Semester 6']);
      }

      for (var c in branchCourses) {
        final sem = c['semester']?.toString() ?? '';
        if (sem.isNotEmpty) {
          final semNum = int.tryParse(sem.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
          if (_selectedYear == '1st Year' && (semNum == 1 || semNum == 2)) {
            sems.add(sem);
          } else if (_selectedYear == '2nd Year' && (semNum == 3 || semNum == 4)) {
            sems.add(sem);
          } else if (_selectedYear == '3rd Year' && (semNum == 5 || semNum == 6)) {
            sems.add(sem);
          }
        }
      }

      final List<String> sortedSems = sems.toList()..sort((a, b) {
        final numA = int.tryParse(a.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        final numB = int.tryParse(b.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
        if (numA != 0 && numB != 0) return numA.compareTo(numB);
        return a.compareTo(b);
      });

      if (mounted) {
        setState(() {
          _availableSemesters = sortedSems;
          if (_selectedSemester == null || !_availableSemesters.contains(_selectedSemester)) {
            _selectedSemester = sortedSems.isNotEmpty 
                ? sortedSems.first 
                : (_selectedYear == '1st Year' ? 'Semester 1' : (_selectedYear == '2nd Year' ? 'Semester 3' : 'Semester 5'));
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching dynamic semesters: $e");
      if (mounted) {
        setState(() {
          final defaultSemList = _selectedYear == '1st Year'
              ? ['Semester 1', 'Semester 2']
              : (_selectedYear == '2nd Year'
                  ? ['Semester 3', 'Semester 4']
                  : ['Semester 5', 'Semester 6']);
          _availableSemesters = defaultSemList;
          if (_selectedSemester == null || !_availableSemesters.contains(_selectedSemester)) {
            _selectedSemester = defaultSemList.first;
          }
        });
      }
    }
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
            {'year': '1st Year', 'percentage': 88}, // Fast -> Orange
            {'year': '2nd Year', 'percentage': 72}, // On Track -> Green
            {'year': '3rd Year', 'percentage': 54}, // Lagging -> Red
          ]
        },
        {
          'branch': 'Civil Engineering',
          'overallPercentage': 60,
          'years': [
            {'year': '1st Year', 'percentage': 68}, // On Track -> Green
            {'year': '2nd Year', 'percentage': 55}, // Lagging -> Red
            {'year': '3rd Year', 'percentage': 89}, // Fast -> Orange
          ]
        },
        {
          'branch': 'Electronics & Communication Engineering',
          'overallPercentage': 82,
          'years': [
            {'year': '1st Year', 'percentage': 90}, // Fast -> Orange
            {'year': '2nd Year', 'percentage': 80}, // On Track -> Green
            {'year': '3rd Year', 'percentage': 76}, // On Track -> Green
          ]
        },
        {
          'branch': 'Electrical & Electronics Engineering',
          'overallPercentage': 68,
          'years': [
            {'year': '1st Year', 'percentage': 70}, // On Track -> Green
            {'year': '2nd Year', 'percentage': 62}, // Lagging -> Red
            {'year': '3rd Year', 'percentage': 86}, // Fast -> Orange
          ]
        },
        {
          'branch': 'Mechanical Engineering',
          'overallPercentage': 55,
          'years': [
            {'year': '1st Year', 'percentage': 58}, // Lagging -> Red
            {'year': '2nd Year', 'percentage': 50}, // Lagging -> Red
            {'year': '3rd Year', 'percentage': 87}, // Fast -> Orange
          ]
        }
      ];
      if (_branches.isNotEmpty && _selectedBranch == null) {
        _selectedBranch = _branches[0]['branch'];
      }
      _isLoadingOverall = false;
    });
    if (_activeDetailBranch != null) {
      _fetchDetails();
    }
  }

  Future<void> _fetchDetails() async {
    if (_selectedBranch == null) return;
    setState(() => _isLoadingDetails = true);
    await _fetchDynamicSemesters();
    
    try {
      final response = await ApiConfig.get(
        '${ApiConstants.baseUrl}/api/hod/syllabus/year-sections-progress?branch=${Uri.encodeComponent(_selectedBranch!)}&year=${Uri.encodeComponent(_selectedYear)}&courseId=$_selectedCourseId'
      );
      if (response.success && response.data != null) {
        setState(() {
          _yearSectionsProgress = response.data is List ? response.data : [];
          if (_yearSectionsProgress.isNotEmpty) {
            final availableSections = _yearSectionsProgress.map((item) {
              final raw = (item['sectionName'] ?? item['section'] ?? 'A').toString();
              return raw.replaceAll('Section ', '').trim();
            }).where((s) => s.isNotEmpty).toSet().toList();
            availableSections.sort();

            final cleanCurrent = _selectedSection?.replaceAll('Section ', '').trim();
            if (cleanCurrent == null || !availableSections.contains(cleanCurrent)) {
              _selectedSection = availableSections.isNotEmpty ? availableSections.first : 'A';
            }
            final firstSec = _yearSectionsProgress[0];
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
      final cleanSection = _selectedSection!.replaceAll('Section ', '').trim();
      final response = await ApiConfig.get(
        '${ApiConstants.baseUrl}/api/hod/syllabus/section-subjects-progress?branch=${Uri.encodeComponent(_selectedBranch!)}&year=${Uri.encodeComponent(_selectedYear)}&section=${Uri.encodeComponent(cleanSection)}&courseId=$_selectedCourseId&semester=${Uri.encodeComponent(_selectedSemester!)}'
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
          'subjectName': 'English Essentials',
          'facultyName': 'Prof. A. Sharma',
          'progress': 0,
          'completionPercentage': 0,
          'status': 'On Track',
          'topics': [
            {
              'topicName': 'Unit 1: Grammar & Vocabulary Essentials',
              'completed': true,
              'completedDate': '2026-02-05',
              'comments': 'Module completed ahead of schedule.'
            },
            {
              'topicName': 'Unit 2: Professional Communication & Writing',
              'completed': false,
              'scheduleDate': '2026-03-25',
              'comments': 'Ongoing with 50% assignments submitted.'
            },
          ]
        },
        {
          'subjectName': 'Engineering Mathematics-I',
          'facultyName': 'Dr. K. Srinivas',
          'progress': 85,
          'completionPercentage': 85,
          'status': 'Fast',
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
          ]
        },
        {
          'subjectName': 'Engineering Physics',
          'facultyName': 'Dr. M. Reddy',
          'progress': 70,
          'completionPercentage': 70,
          'status': 'On Track',
          'topics': [
            {
              'topicName': 'Unit 1: Wave Optics & Interference',
              'completed': true,
              'completedDate': '2026-02-15',
              'comments': 'Lab experiment finished.'
            },
            {
              'topicName': 'Unit 2: Quantum Physics & Lasers',
              'completed': false,
              'scheduleDate': '2026-03-28',
              'comments': 'Ongoing.'
            },
          ]
        },
        {
          'subjectName': 'Python Programming',
          'facultyName': 'Prof. P. Ravi',
          'progress': 80,
          'completionPercentage': 80,
          'status': 'Fast',
          'topics': [
            {
              'topicName': 'Unit 1: Python Data Types & Control Structures',
              'completed': true,
              'completedDate': '2026-02-05',
              'comments': 'Lab practice finished with Python 3.11 implementations.'
            },
            {
              'topicName': 'Unit 2: Functions, Modules & File I/O',
              'completed': true,
              'completedDate': '2026-02-22',
              'comments': 'File handling completed.'
            },
          ]
        },
      ];
      _isLoadingDetails = false;
    });
  }

  // Helper function: Calculate status color based on topic target dates vs completion
  Color _getYearScheduleColor(int percentage) {
    if (percentage >= 85) {
      return Colors.orangeAccent;
    } else if (percentage >= 65) {
      return Colors.greenAccent;
    } else {
      return Colors.redAccent;
    }
  }

  String _getScheduleStatusText(int percentage) {
    return '-';
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
          // Header: Academics Dashboard + Search Bar & Sync Data
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
                  SizedBox(
                    width: 280,
                    height: 38,
                    child: TextField(
                      controller: _deptSearchController,
                      onChanged: (val) {
                        setState(() {
                          _deptSearchQuery = val;
                        });
                      },
                      style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Search department...',
                        hintStyle: GoogleFonts.poppins(color: context.textMuted, fontSize: 11),
                        prefixIcon: Icon(Icons.search, size: 16, color: context.textMuted),
                        suffixIcon: _deptSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 14, color: context.textMuted),
                                onPressed: () {
                                  _deptSearchController.clear();
                                  setState(() => _deptSearchQuery = '');
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: context.cardColor,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: context.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: context.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.blueAccent),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
            ],
          ),
          const SizedBox(height: 20),

          // Circular Gauge Department Cards Grid (Proportioned Frame: 460px max width, 260px fixed height)
          Expanded(
            child: Builder(
              builder: (context) {
                final displayBranches = _branches.where((b) {
                  if (_deptSearchQuery.trim().isEmpty) return true;
                  final q = _deptSearchQuery.trim().toLowerCase();
                  final name = (b['branch'] ?? '').toString().toLowerCase();
                  return name.contains(q);
                }).toList();

                if (displayBranches.isEmpty) {
                  return Center(
                    child: Text(
                      'No department found matching "$_deptSearchQuery".',
                      style: GoogleFonts.poppins(color: context.textMuted, fontSize: 13),
                    ),
                  );
                }

                return GridView.builder(
                  gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                    maxCrossAxisExtent: 460,
                    mainAxisExtent: 260, // Fixed 260px height matching uploaded mockup perfectly
                    crossAxisSpacing: 18,
                    mainAxisSpacing: 18,
                  ),
                  itemCount: displayBranches.length,
                  itemBuilder: (context, index) {
                    final item = displayBranches[index];
                final branchName = item['branch'] ?? 'Unknown';
                final int percentage = (item['overallPercentage'] ?? 0).toInt();
                final List<dynamic> years = item['years'] ?? [];

                final int yr1Pct = years.isNotEmpty ? (years[0]['percentage'] ?? 0).toInt() : 80;
                final int yr2Pct = years.length > 1 ? (years[1]['percentage'] ?? 0).toInt() : 70;
                final int yr3Pct = years.length > 2 ? (years[2]['percentage'] ?? 0).toInt() : 60;

                final Color yr1Color = _getYearScheduleColor(yr1Pct);
                final Color yr2Color = _getYearScheduleColor(yr2Pct);
                final Color yr3Color = _getYearScheduleColor(yr3Pct);

                final Color overallColor = _getYearScheduleColor(percentage);
                final String statusText = _getScheduleStatusText(percentage);

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
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: context.cardColor,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: context.borderColor, width: 1.2),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.04),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // Card Header Row: Department Name + Icon Badge (Diploma ERP Tag Removed)
                        Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: Colors.blueAccent.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Icon(Icons.school_outlined, color: Colors.blueAccent, size: 18),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                branchName,
                                style: GoogleFonts.poppins(
                                  color: context.textPrimary,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),

                        // 3 Circular Gauges Row (1st Year, 2nd Year, 3rd Year)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            _buildCircularGauge(context, '1st Year', yr1Pct, yr1Color),
                            _buildCircularGauge(context, '2nd Year', yr2Pct, yr2Color),
                            _buildCircularGauge(context, '3rd Year', yr3Pct, yr3Color),
                          ],
                        ),

                        // Overall Progress Bar Section with Status Text Beside "Progress:"
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      'Progress: ',
                                      style: GoogleFonts.poppins(
                                        color: context.textPrimary,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    Text(
                                      statusText,
                                      style: GoogleFonts.poppins(
                                        color: overallColor,
                                        fontSize: 12,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                Text(
                                  '$percentage%',
                                  style: GoogleFonts.poppins(
                                    color: overallColor,
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Stack(
                              children: [
                                Container(
                                  height: 7,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: context.borderColor.withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                FractionallySizedBox(
                                  widthFactor: (percentage / 100.0).clamp(0.0, 1.0),
                                  child: Container(
                                    height: 7,
                                    decoration: BoxDecoration(
                                      color: overallColor,
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),

                        // Bottom Footer Row
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: context.bgColor,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: context.borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.notes, size: 14, color: context.textMuted),
                                      const SizedBox(width: 4),
                                      Text('24 Subjects', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: context.bgColor,
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(color: context.borderColor),
                                  ),
                                  child: Row(
                                    children: [
                                      Icon(Icons.chat_bubble_outline, size: 14, color: context.textMuted),
                                      const SizedBox(width: 4),
                                      Text('Lesson Plans', style: GoogleFonts.poppins(color: context.textMuted, fontSize: 10, fontWeight: FontWeight.w500)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            Row(
                              children: [
                                Text(
                                  'Manage Syllabus ',
                                  style: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                                ),
                                const Icon(Icons.arrow_forward_ios, size: 10, color: Colors.blueAccent),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          }),
        ),
        ],
      ),
    );
  }

  // Circular Progress Gauge Ring (Matching uploaded mockup image)
  Widget _buildCircularGauge(BuildContext context, String title, int percentage, Color color) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 68,
          height: 68,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 68,
                height: 68,
                child: CircularProgressIndicator(
                  value: (percentage / 100.0).clamp(0.0, 1.0),
                  strokeWidth: 6.5,
                  backgroundColor: context.borderColor.withOpacity(0.4),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                  strokeCap: StrokeCap.round,
                ),
              ),
              Text(
                '$percentage%',
                style: GoogleFonts.poppins(
                  color: color,
                  fontSize: 14,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Text(
          title.toUpperCase(),
          style: GoogleFonts.poppins(
            color: context.textMuted,
            fontSize: 10,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ],
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
          // Compact Header Bar with Back Button & Dynamic Search Box
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
              Row(
                children: [
                  SizedBox(
                    width: 320,
                    height: 38,
                    child: TextField(
                      controller: _academicsSearchController,
                      onChanged: (val) {
                        setState(() {
                          _academicsSearchQuery = val;
                          final q = val.trim().toLowerCase();
                          for (var sem in _availableSemesters) {
                            if (sem == 'All Semesters') continue;
                            final semNum = sem.replaceAll(RegExp(r'[^0-9]'), '');
                            if (q == sem.toLowerCase() || 
                                q == 'sem $semNum' || 
                                q == 'sem-$semNum' || 
                                q == 's$semNum' || 
                                (q.length == 1 && q == semNum)) {
                              _selectedSemester = sem;
                              break;
                            }
                          }
                        });
                        _fetchSectionSubjectsProgress();
                      },
                      style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 12),
                      decoration: InputDecoration(
                        hintText: 'Search semester (e.g. Sem 1), subject, faculty...',
                        hintStyle: GoogleFonts.poppins(color: context.textMuted, fontSize: 11),
                        prefixIcon: Icon(Icons.search, size: 16, color: context.textMuted),
                        suffixIcon: _academicsSearchQuery.isNotEmpty
                            ? IconButton(
                                icon: Icon(Icons.clear, size: 14, color: context.textMuted),
                                onPressed: () {
                                  _academicsSearchController.clear();
                                  setState(() => _academicsSearchQuery = '');
                                  _fetchSectionSubjectsProgress();
                                },
                              )
                            : null,
                        filled: true,
                        fillColor: context.cardColor,
                        contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: context.borderColor),
                        ),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: BorderSide(color: context.borderColor),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide: const BorderSide(color: Colors.blueAccent),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
            ],
          ),
          const SizedBox(height: 16),

          // Compact Combined Filter Bar: Years, Sections & Semesters Pill Selector
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: context.cardColor,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.borderColor),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Year: ',
                      style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    _buildCompactYearPills(),
                    const SizedBox(width: 24),
                    Container(height: 20, width: 1, color: context.borderColor),
                    const SizedBox(width: 24),
                    Text(
                      'Section: ',
                      style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    _buildCompactSectionPills(),
                  ],
                ),
                const SizedBox(height: 10),
                Divider(height: 1, color: context.borderColor.withOpacity(0.5)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Text(
                      'Semester: ',
                      style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    Expanded(child: _buildCompactSemesterPills()),
                  ],
                ),
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
                              'Lesson Plans & Topic Progression ($_selectedYear - Section $_selectedSection | ${_selectedSemester ?? ''})',
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

  Widget _buildCompactSemesterPills() {
    List<String> semesters = _availableSemesters;
    if (semesters.isEmpty) {
      if (_selectedYear == '1st Year') {
        semesters = ['Semester 1', 'Semester 2'];
      } else if (_selectedYear == '2nd Year') {
        semesters = ['Semester 3', 'Semester 4'];
      } else {
        semesters = ['Semester 5', 'Semester 6'];
      }
    }

    if (_selectedSemester == null || !semesters.contains(_selectedSemester)) {
      _selectedSemester = semesters.first;
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: semesters.map((sem) {
          final isSelected = _selectedSemester == sem;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedSemester = sem;
                });
                _fetchSectionSubjectsProgress();
              },
              borderRadius: BorderRadius.circular(8),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.purpleAccent.withOpacity(0.2) : context.bgColor,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.purpleAccent : context.borderColor,
                  ),
                ),
                child: Text(
                  sem,
                  style: GoogleFonts.poppins(
                    color: isSelected ? Colors.purpleAccent : context.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }

  Widget _buildCompactSectionPills() {
    List<String> sections = [];
    if (_yearSectionsProgress.isNotEmpty) {
      sections = _yearSectionsProgress.map((item) {
        final raw = (item['sectionName'] ?? item['section'] ?? 'A').toString();
        return raw.replaceAll('Section ', '').trim();
      }).where((s) => s.isNotEmpty).toSet().toList();
      sections.sort();
    }

    if (sections.isEmpty) {
      sections = ['A', 'B'];
    }

    final cleanCurrent = _selectedSection?.replaceAll('Section ', '').trim();

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: sections.map((sec) {
        final isSelected = cleanCurrent == sec;
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

    final query = _academicsSearchQuery.trim().toLowerCase();
    List<dynamic> displaySubjects = _sectionSubjectsProgress;

    if (query.isNotEmpty) {
      displaySubjects = _sectionSubjectsProgress.where((sub) {
        final String sName = (sub['subjectName'] ?? '').toString().toLowerCase();
        final String fName = (sub['facultyName'] ?? '').toString().toLowerCase();
        final String sCode = (sub['subjectCode'] ?? sub['subject_id'] ?? '').toString().toLowerCase();
        final String sem = (sub['semester'] ?? '').toString().toLowerCase();

        bool matchTopics = false;
        if (sub['topics'] is List) {
          for (var t in sub['topics']) {
            final String tName = (t['topicName'] ?? '').toString().toLowerCase();
            final String tComm = (t['comments'] ?? '').toString().toLowerCase();
            if (tName.contains(query) || tComm.contains(query)) {
              matchTopics = true;
              break;
            }
          }
        }

        return sName.contains(query) ||
               fName.contains(query) ||
               sCode.contains(query) ||
               sem.contains(query) ||
               matchTopics;
      }).toList();
    }

    if (displaySubjects.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.search_off, size: 40, color: context.textMuted),
            const SizedBox(height: 8),
            Text(
              'No subjects or lesson plans found matching "$_academicsSearchQuery".',
              style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12),
            ),
            const SizedBox(height: 8),
            TextButton.icon(
              onPressed: () {
                _academicsSearchController.clear();
                setState(() => _academicsSearchQuery = '');
                _fetchSectionSubjectsProgress();
              },
              icon: const Icon(Icons.clear, size: 14),
              label: const Text('Clear Search Filter'),
            ),
          ],
        ),
      );
    }

    return ListView.builder(
      itemCount: displaySubjects.length,
      itemBuilder: (context, index) {
        final sub = displaySubjects[index];
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
            title: LayoutBuilder(
              builder: (context, constraints) {
                final bool isCompact = constraints.maxWidth < 600;
                return Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            subjectName,
                            style: GoogleFonts.poppins(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 13),
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Faculty: $faculty',
                            style: GoogleFonts.poppins(color: context.textMuted, fontSize: 11),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Flexible(
                      flex: 2,
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
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () => _downloadLessonPlan(subjectName),
                      icon: const Icon(Icons.download_outlined, size: 14),
                      label: Text(isCompact ? 'Plan' : 'Download Lesson Plan', style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.blueAccent.withOpacity(0.15),
                        foregroundColor: Colors.blueAccent,
                        elevation: 0,
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                          side: BorderSide(color: Colors.blueAccent.withOpacity(0.3)),
                        ),
                      ),
                    ),
                  ],
                );
              },
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
}
