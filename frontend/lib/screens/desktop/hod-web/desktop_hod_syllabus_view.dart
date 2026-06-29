import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/api_config.dart';
import '../../../core/api_constants.dart';

class DesktopHodSyllabusView extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DesktopHodSyllabusView({super.key, required this.userData});

  @override
  State<DesktopHodSyllabusView> createState() => _DesktopHodSyllabusViewState();
}

class _DesktopHodSyllabusViewState extends State<DesktopHodSyllabusView> {
  bool _isLoading = true;
  List<dynamic> _courses = [];
  Map<String, dynamic>? _branchProgress;
  String? _selectedCourseId = 'C-26';
  String? _selectedYear = '1st Year';
  String? _selectedSection = 'A';
  String? _selectedSemester = '1st Year';
  
  List<dynamic> _yearSectionsProgress = [];
  List<dynamic> _sectionSubjectsProgress = [];
  bool _loadingSectionProgress = false;

  @override
  void initState() {
    super.initState();
    _fetchCourses();
    _fetchBranchProgress();
  }

  Future<void> _fetchBranchProgress() async {
    final String branch = widget.userData['branch'] ?? 'Computer Engineering';
    try {
      final response = await ApiConfig.get(
        '${ApiConstants.baseUrl}/api/hod/syllabus/branch-progress?branch=${Uri.encodeComponent(branch)}&courseId=$_selectedCourseId'
      );
      if (response.success && response.data != null) {
        setState(() {
          _branchProgress = response.data is Map ? response.data : null;
        });
        // Auto load first year details
        if (_branchProgress != null && _branchProgress!['years'] != null && (_branchProgress!['years'] as List).isNotEmpty) {
          _fetchYearSectionProgress();
        }
      }
    } catch (e) {
      debugPrint("Error fetching branch progress: $e");
    }
  }

  Future<void> _fetchCourses() async {
    try {
      final response = await ApiConfig.get('${ApiConstants.baseUrl}/api/faculty/hod-courses');
      if (response.success && response.data is List && (response.data as List).isNotEmpty) {
        setState(() {
          _courses = response.data;
          _isLoading = false;
        });
      } else {
        _loadLocalCourses();
      }
    } catch (e) {
      debugPrint("Error fetching courses: $e");
      _loadLocalCourses();
    }
  }

  void _loadLocalCourses() {
    setState(() {
      _courses = [
        {'courseId': 'C-23', 'courseName': 'C-23 Regulation'},
        {'courseId': 'C-26', 'courseName': 'C-26 Regulation'},
      ];
      _isLoading = false;
    });
  }

  Future<void> _fetchYearSectionProgress() async {
    setState(() => _loadingSectionProgress = true);
    final String branch = widget.userData['branch'] ?? 'Computer Engineering';
    try {
      final response = await ApiConfig.get(
        '${ApiConstants.baseUrl}/api/hod/syllabus/year-sections-progress?branch=${Uri.encodeComponent(branch)}&year=${Uri.encodeComponent(_selectedYear!)}&courseId=$_selectedCourseId'
      );
      if (response.success && response.data != null) {
        setState(() {
          _yearSectionsProgress = response.data is List ? response.data : [];
          if (_yearSectionsProgress.isEmpty) {
            final String defaultSem = _selectedYear == '1st Year' 
                ? 'Semester 1' 
                : (_selectedYear == '2nd Year' ? 'Semester 3' : 'Semester 5');
            _yearSectionsProgress = [
              {'section': 'A', 'percentage': 0, 'semester': defaultSem},
              {'section': 'B', 'percentage': 0, 'semester': defaultSem},
            ];
          }
        });
        if (_yearSectionsProgress.isNotEmpty) {
          final firstSec = _yearSectionsProgress[0];
          _selectedSection = firstSec['section'] ?? 'A';
          _selectedSemester = firstSec['semester'] ?? 'Semester 1';
          _fetchSectionSubjectsProgress();
        }
      } else {
        setState(() {
          final String defaultSem = _selectedYear == '1st Year' 
              ? 'Semester 1' 
              : (_selectedYear == '2nd Year' ? 'Semester 3' : 'Semester 5');
          _yearSectionsProgress = [
            {'section': 'A', 'percentage': 0, 'semester': defaultSem},
            {'section': 'B', 'percentage': 0, 'semester': defaultSem},
          ];
          _selectedSection = 'A';
          _selectedSemester = defaultSem;
          _loadingSectionProgress = false;
        });
        _fetchSectionSubjectsProgress();
      }
    } catch (e) {
      debugPrint("Error fetching year section progress: $e");
      setState(() {
        final String defaultSem = _selectedYear == '1st Year' 
            ? 'Semester 1' 
            : (_selectedYear == '2nd Year' ? 'Semester 3' : 'Semester 5');
        _yearSectionsProgress = [
          {'section': 'A', 'percentage': 0, 'semester': defaultSem},
          {'section': 'B', 'percentage': 0, 'semester': defaultSem},
        ];
        _selectedSection = 'A';
        _selectedSemester = defaultSem;
        _loadingSectionProgress = false;
      });
      _fetchSectionSubjectsProgress();
    }
  }

  Future<void> _fetchSectionSubjectsProgress() async {
    setState(() => _loadingSectionProgress = true);
    final String branch = widget.userData['branch'] ?? 'Computer Engineering';
    try {
      final response = await ApiConfig.get(
        '${ApiConstants.baseUrl}/api/hod/syllabus/section-subjects-progress?branch=${Uri.encodeComponent(branch)}&year=${Uri.encodeComponent(_selectedYear!)}&section=${Uri.encodeComponent(_selectedSection!)}&courseId=$_selectedCourseId&semester=${Uri.encodeComponent(_selectedSemester!)}'
      );
      if (response.success && response.data != null) {
        setState(() {
          _sectionSubjectsProgress = response.data is List ? response.data : [];
          _loadingSectionProgress = false;
        });
      } else {
        setState(() {
          _sectionSubjectsProgress = [];
          _loadingSectionProgress = false;
        });
      }
    } catch (e) {
      debugPrint("Error fetching subjects progress: $e");
      setState(() => _loadingSectionProgress = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: Colors.blueAccent));
    }

    final branchName = widget.userData['branch'] ?? 'Computer Engineering';

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
                    'Syllabus & Curriculum Tracker',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Track syllabus progression index across all years, sections, and subjects in $branchName',
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
              // Regulation Text Indicator
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFF1E293B),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white10),
                ),
                child: Text(
                  _selectedCourseId == 'C-26' ? 'C-26 Regulation' : 'C-23 Regulation',
                  style: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main split layout
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Left Pane: Overall Progress + Year Selector
                Expanded(
                  flex: 2,
                  child: Column(
                    children: [
                      // Branch Overall Card
                      if (_branchProgress != null) _buildBranchOverallCard(),
                      const SizedBox(height: 20),

                      // Years Selector
                      Container(
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
                              'Select Academic Year',
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                            ),
                            const SizedBox(height: 16),
                            _buildYearSelectionRow(),
                          ],
                        ),
                      ),
                      const SizedBox(height: 20),

                      // Section Selector List
                      Expanded(
                        child: Container(
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
                                'Sections Overview',
                                style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              Expanded(child: _buildSectionsList()),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 20),

                // Right Pane: Subject-wise Breakdown Table
                Expanded(
                  flex: 3,
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
                          'Subject Progression: $_selectedYear - Sec $_selectedSection',
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Detail syllabus feedback and topics completed by respective faculty members',
                          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          child: _loadingSectionProgress
                              ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                              : _buildSubjectsTable(),
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

  Widget _buildBranchOverallCard() {
    final int overall = _branchProgress!['overallPercentage'] ?? 0;
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                "Overall Branch Progress",
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              Text(
                "$overall% Completed",
                style: GoogleFonts.poppins(color: Colors.amberAccent, fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Stack(
            children: [
              Container(
                height: 8,
                width: double.infinity,
                decoration: BoxDecoration(color: Colors.white10, borderRadius: BorderRadius.circular(4)),
              ),
              FractionallySizedBox(
                widthFactor: (overall / 100.0).clamp(0.0, 1.0),
                child: Container(
                  height: 8,
                  decoration: BoxDecoration(
                    color: Colors.amberAccent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildYearSelectionRow() {
    final List<String> years = ['1st Year', '2nd Year', '3rd Year'];
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: years.map((y) {
        final isSelected = y == _selectedYear;
        return Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: InkWell(
              onTap: () {
                setState(() {
                  _selectedYear = y;
                  _selectedCourseId = y == '1st Year' ? 'C-26' : 'C-23';
                });
                _fetchYearSectionProgress();
              },
              borderRadius: BorderRadius.circular(8),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: isSelected ? Colors.blueAccent.withOpacity(0.15) : const Color(0xFF0F172A),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: isSelected ? Colors.blueAccent : Colors.white10,
                  ),
                ),
                child: Center(
                  child: Text(
                    y,
                    style: GoogleFonts.poppins(
                      color: isSelected ? Colors.white : Colors.white60,
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
          "No sections configured for this year.",
          style: GoogleFonts.poppins(color: Colors.white24, fontSize: 12),
        ),
      );
    }

    return ListView.builder(
      itemCount: _yearSectionsProgress.length,
      itemBuilder: (context, index) {
        final item = _yearSectionsProgress[index];
        final sec = item['section'] ?? 'A';
        final sem = item['semester'] ?? '';
        final int progress = item['percentage'] ?? 0;
        final isSelected = _selectedSection == sec;

        return InkWell(
          onTap: () {
            setState(() {
              _selectedSection = sec;
              _selectedSemester = sem;
            });
            _fetchSectionSubjectsProgress();
          },
          borderRadius: BorderRadius.circular(10),
          child: Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white.withOpacity(0.05) : Colors.transparent,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(
                color: isSelected ? Colors.white24 : Colors.transparent,
              ),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: Colors.blueAccent.withOpacity(0.1),
                  radius: 18,
                  child: Text(
                    sec,
                    style: const TextStyle(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Section $sec",
                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        sem,
                        style: GoogleFonts.poppins(color: Colors.white38, fontSize: 10),
                      ),
                    ],
                  ),
                ),
                Text(
                  "$progress%",
                  style: GoogleFonts.poppins(
                    color: progress >= 75 ? Colors.greenAccent : Colors.orangeAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
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
          "No subjects data found.",
          style: GoogleFonts.poppins(color: Colors.white24, fontSize: 13),
        ),
      );
    }

    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withOpacity(0.4),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      child: DataTable(
        columnSpacing: 16,
        columns: [
          DataColumn(
            label: Text('Subject', style: GoogleFonts.poppins(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          DataColumn(
            label: Text('Faculty', style: GoogleFonts.poppins(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
          DataColumn(
            label: Text('Completion', style: GoogleFonts.poppins(color: Colors.white70, fontWeight: FontWeight.bold, fontSize: 13)),
          ),
        ],
        rows: _sectionSubjectsProgress.map((sub) {
          final int completion = (sub['progress'] ?? sub['completionPercentage'] ?? 0).toInt();
          return DataRow(
            cells: [
              DataCell(
                Text(
                  sub['subjectName'] ?? sub['name'] ?? '',
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              DataCell(
                Text(
                  sub['facultyName'] ?? 'Not Assigned',
                  style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12),
                ),
              ),
              DataCell(
                Row(
                  children: [
                    SizedBox(
                      width: 50,
                      child: LinearProgressIndicator(
                        value: completion / 100.0,
                        backgroundColor: Colors.white10,
                        valueColor: AlwaysStoppedAnimation<Color>(
                          completion >= 75 ? Colors.greenAccent : Colors.orangeAccent,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      "$completion%",
                      style: GoogleFonts.poppins(
                        color: completion >= 75 ? Colors.greenAccent : Colors.orangeAccent,
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          );
        }).toList(),
      ),
    );
  }
}
