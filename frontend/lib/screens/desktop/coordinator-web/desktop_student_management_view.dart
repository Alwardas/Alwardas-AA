import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/providers/desktop_providers.dart';

class DesktopStudentManagementView extends ConsumerStatefulWidget {
  final Map<String, dynamic> userData;

  const DesktopStudentManagementView({super.key, required this.userData});

  @override
  ConsumerState<DesktopStudentManagementView> createState() => _DesktopStudentManagementViewState();
}

class _DesktopStudentManagementViewState extends ConsumerState<DesktopStudentManagementView> {
  bool _isLoading = true;
  List<dynamic> _students = [];
  List<dynamic> _filteredStudents = [];

  // Filter States
  String _searchQuery = '';
  String _selectedBranch = 'All';
  String _selectedYear = 'All';
  String _selectedSection = 'All';
  String _selectedStatus = 'All';

  // Sorting States
  String _sortColumn = 'name';
  bool _isAscending = true;

  // Selected for Bulk Action
  final Set<String> _selectedStudentIds = {};

  @override
  void initState() {
    super.initState();
    _fetchStudents();
  }

  Future<void> _fetchStudents() async {
    setState(() => _isLoading = true);
    try {
      final dio = ref.read(dioClientProvider);
      final response = await dio.get('/api/students', useCache: true);
      
      if (response.statusCode == 200) {
        final List<dynamic> data = response.data['data'] ?? [];
        if (mounted) {
          setState(() {
            _students = data;
            _applyFilters();
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      // Fallback Mock Data in case backend has no students or is offline
      if (mounted) {
        setState(() {
          _students = _getMockStudents();
          _applyFilters();
          _isLoading = false;
        });
      }
    }
  }

  List<dynamic> _getMockStudents() {
    return [
      {'id': '1', 'student_id': 'ADM2026101', 'full_name': 'Aravind Swamy', 'branch': 'Computer Engineering', 'year': '3rd Year', 'section': 'A', 'status': 'Active', 'admission_year': 2024},
      {'id': '2', 'student_id': 'ADM2026102', 'full_name': 'Divya Reddy', 'branch': 'Computer Engineering', 'year': '3rd Year', 'section': 'A', 'status': 'Active', 'admission_year': 2024},
      {'id': '3', 'student_id': 'ADM2026103', 'full_name': 'Bala Krishna', 'branch': 'Electronics & Communication Engineering', 'year': '2nd Year', 'section': 'B', 'status': 'Active', 'admission_year': 2025},
      {'id': '4', 'student_id': 'ADM2026104', 'full_name': 'Charan Teja', 'branch': 'Mechanical Engineering', 'year': '4th Year', 'section': 'A', 'status': 'Active', 'admission_year': 2023},
      {'id': '5', 'student_id': 'ADM2026105', 'full_name': 'Eshwar Rao', 'branch': 'Civil Engineering', 'year': '1st Year', 'section': 'C', 'status': 'Pending', 'admission_year': 2026},
      {'id': '6', 'student_id': 'ADM2026106', 'full_name': 'Haritha Kumari', 'branch': 'Electrical & Electronics Engineering', 'year': '3rd Year', 'section': 'B', 'status': 'Active', 'admission_year': 2024},
    ];
  }

  void _applyFilters() {
    setState(() {
      _filteredStudents = _students.where((student) {
        final name = (student['full_name'] ?? '').toString().toLowerCase();
        final id = (student['student_id'] ?? '').toString().toLowerCase();
        final branch = student['branch'] ?? '';
        final year = student['year'] ?? '';
        final section = student['section'] ?? '';
        final status = student['status'] ?? 'Active';

        final matchesSearch = name.contains(_searchQuery.toLowerCase()) || id.contains(_searchQuery.toLowerCase());
        final matchesBranch = _selectedBranch == 'All' || branch.toString().toLowerCase().contains(_selectedBranch.toLowerCase());
        final matchesYear = _selectedYear == 'All' || year.toString().toLowerCase().contains(_selectedYear.toLowerCase());
        final matchesSection = _selectedSection == 'All' || section.toString().toUpperCase() == _selectedSection.toUpperCase();
        final matchesStatus = _selectedStatus == 'All' || status.toString().toUpperCase() == _selectedStatus.toUpperCase();

        return matchesSearch && matchesBranch && matchesYear && matchesSection && matchesStatus;
      }).toList();

      _sortData();
    });
  }

  void _sortData() {
    _filteredStudents.sort((a, b) {
      dynamic valA, valB;
      if (_sortColumn == 'name') {
        valA = a['full_name'] ?? '';
        valB = b['full_name'] ?? '';
      } else if (_sortColumn == 'id') {
        valA = a['student_id'] ?? '';
        valB = b['student_id'] ?? '';
      } else if (_sortColumn == 'branch') {
        valA = a['branch'] ?? '';
        valB = b['branch'] ?? '';
      } else if (_sortColumn == 'section') {
        valA = a['section'] ?? '';
        valB = b['section'] ?? '';
      } else {
        valA = a['status'] ?? '';
        valB = b['status'] ?? '';
      }

      int res = valA.toString().compareTo(valB.toString());
      return _isAscending ? res : -res;
    });
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _isAscending = !_isAscending;
      } else {
        _sortColumn = column;
        _isAscending = true;
      }
      _sortData();
    });
  }

  void _showDetailsDrawer(BuildContext context, Map<String, dynamic> student) {
    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Details Drawer',
      transitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (context, anim1, anim2) {
        return Align(
          alignment: Alignment.centerRight,
          child: Material(
            color: Colors.transparent,
            child: Container(
              width: 460,
              height: double.infinity,
              decoration: const BoxDecoration(
                color: Color(0xFF1E293B),
                border: Border(left: BorderSide(color: Colors.white10)),
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(20),
                  bottomLeft: Radius.circular(20),
                ),
              ),
              padding: const EdgeInsets.all(35),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Student Profile Details',
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white60),
                          onPressed: () => Navigator.pop(context),
                        ),
                      ],
                    ),
                    const SizedBox(height: 30),

                    // Avatar block
                    Center(
                      child: Column(
                        children: [
                          CircleAvatar(
                            radius: 45,
                            backgroundColor: Colors.blueAccent.withOpacity(0.15),
                            child: const Icon(Icons.person, size: 45, color: Colors.blueAccent),
                          ),
                          const SizedBox(height: 16),
                          Text(
                            student['full_name'] ?? 'John Doe',
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                          ),
                          Text(
                            student['student_id'] ?? 'ADM2026000',
                            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Detail blocks
                    _buildDrawerSection('Academic Placement', [
                      _buildDrawerField('Branch', student['branch'] ?? 'Computer Engineering'),
                      _buildDrawerField('Year', student['year'] ?? '3rd Year'),
                      _buildDrawerField('Section', student['section'] ?? 'A'),
                      _buildDrawerField('Admission Year', (student['admission_year'] ?? 2024).toString()),
                    ]),
                    const SizedBox(height: 24),
                    _buildDrawerSection('Status Metrics', [
                      _buildDrawerField('Academic Status', student['status'] ?? 'Active'),
                      _buildDrawerField('Current Attendance %', '94.8%'),
                      _buildDrawerField('Fee Account Status', 'Paid'),
                    ]),
                    const SizedBox(height: 24),
                    _buildDrawerSection('Guardian Details', [
                      _buildDrawerField('Father\'s Name', 'Ramu Swamy'),
                      _buildDrawerField('Contact Phone', '+91 9876543210'),
                      _buildDrawerField('Email ID', 'ramu.swamy@gmail.com'),
                    ]),
                  ],
                ),
              ),
            ),
          ),
        );
      },
      transitionBuilder: (context, anim1, anim2, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(1, 0),
            end: const Offset(0, 0),
          ).animate(anim1),
          child: child,
        );
      },
    );
  }

  Widget _buildDrawerSection(String title, List<Widget> children) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: const Color(0xFF0F172A),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white10),
          ),
          padding: const EdgeInsets.all(16),
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildDrawerField(String label, String val) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12)),
          Text(val, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Table header buttons row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Student Directory',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Manage user placement, admissions verification, and profiling',
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.arrow_downward, size: 16),
                    label: Text('Export Excel', style: GoogleFonts.poppins(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1E293B),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    onPressed: () {},
                    icon: const Icon(Icons.add, size: 16),
                    label: Text('Bulk Operations', style: GoogleFonts.poppins(fontSize: 12)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF3b5998),
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Filters Card
          Container(
            decoration: BoxDecoration(
              color: const Color(0xFF1E293B),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white10),
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                // Search Input
                Expanded(
                  flex: 3,
                  child: Container(
                    height: 42,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        const Icon(Icons.search, color: Colors.white38, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                                _applyFilters();
                              });
                            },
                            style: const TextStyle(color: Colors.white, fontSize: 13),
                            decoration: InputDecoration(
                              hintText: 'Search by ID or name...',
                              hintStyle: GoogleFonts.poppins(color: Colors.white24),
                              border: InputBorder.none,
                              isDense: true,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 16),

                // Branch dropdown
                _buildDropdownFilter('Branch', _selectedBranch, [
                  'All',
                  'Computer Engineering',
                  'Electronics & Communication Engineering',
                  'Electrical & Electronics Engineering',
                  'Mechanical Engineering',
                  'Civil Engineering'
                ], (val) {
                  setState(() {
                    _selectedBranch = val!;
                    _applyFilters();
                  });
                }),
                const SizedBox(width: 16),

                // Year dropdown
                _buildDropdownFilter('Year', _selectedYear, ['All', '1st Year', '2nd Year', '3rd Year', '4th Year'], (val) {
                  setState(() {
                    _selectedYear = val!;
                    _applyFilters();
                  });
                }),
                const SizedBox(width: 16),

                // Section dropdown
                _buildDropdownFilter('Section', _selectedSection, ['All', 'A', 'B', 'C'], (val) {
                  setState(() {
                    _selectedSection = val!;
                    _applyFilters();
                  });
                }),
                const SizedBox(width: 16),

                // Status dropdown
                _buildDropdownFilter('Status', _selectedStatus, ['All', 'Active', 'Pending'], (val) {
                  setState(() {
                    _selectedStatus = val!;
                    _applyFilters();
                  });
                }),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Students List Table View
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: Colors.white10),
                    ),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        // Column Titles
                        Container(
                          height: 48,
                          color: const Color(0xFF0F172A).withOpacity(0.4),
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Row(
                            children: [
                              Checkbox(
                                value: _selectedStudentIds.length == _filteredStudents.length && _filteredStudents.isNotEmpty,
                                onChanged: (val) {
                                  setState(() {
                                    if (val == true) {
                                      _selectedStudentIds.addAll(_filteredStudents.map((s) => s['student_id'].toString()));
                                    } else {
                                      _selectedStudentIds.clear();
                                    }
                                  });
                                },
                              ),
                              const SizedBox(width: 10),
                              Expanded(flex: 2, child: _buildSortHeader('ID', 'id')),
                              Expanded(flex: 3, child: _buildSortHeader('Name', 'name')),
                              Expanded(flex: 4, child: _buildSortHeader('Branch / Department', 'branch')),
                              Expanded(flex: 1, child: _buildSortHeader('Section', 'section')),
                              Expanded(flex: 2, child: _buildSortHeader('Status', 'status')),
                              const SizedBox(width: 50), // spacer for actions
                            ],
                          ),
                        ),
                        const Divider(color: Colors.white10, height: 1),

                        // Table Body Rows
                        Expanded(
                          child: _filteredStudents.isEmpty
                              ? Center(
                                  child: Text(
                                    'No students found matching filters.',
                                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13),
                                  ),
                                )
                              : ListView.builder(
                                  itemCount: _filteredStudents.length,
                                  itemBuilder: (context, index) {
                                    final student = _filteredStudents[index];
                                    final id = (student['student_id'] ?? '').toString();
                                    final name = (student['full_name'] ?? '').toString();
                                    final branch = (student['branch'] ?? 'Unassigned').toString();
                                    final section = (student['section'] ?? 'N/A').toString();
                                    final status = (student['status'] ?? 'Active').toString();
                                    final isRowChecked = _selectedStudentIds.contains(id);

                                    return InkWell(
                                      onTap: () => _showDetailsDrawer(context, student),
                                      child: Container(
                                        height: 52,
                                        padding: const EdgeInsets.symmetric(horizontal: 20),
                                        decoration: const BoxDecoration(
                                          border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
                                        ),
                                        child: Row(
                                          children: [
                                            Checkbox(
                                              value: isRowChecked,
                                              onChanged: (val) {
                                                setState(() {
                                                  if (val == true) {
                                                    _selectedStudentIds.add(id);
                                                  } else {
                                                    _selectedStudentIds.remove(id);
                                                  }
                                                });
                                              },
                                            ),
                                            const SizedBox(width: 10),
                                            Expanded(
                                              flex: 2,
                                              child: Text(id, style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600)),
                                            ),
                                            Expanded(
                                              flex: 3,
                                              child: Text(name, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12, fontWeight: FontWeight.bold)),
                                            ),
                                            Expanded(
                                              flex: 4,
                                              child: Text(branch, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12)),
                                            ),
                                            Expanded(
                                              flex: 1,
                                              child: Text(section, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12)),
                                            ),
                                            Expanded(
                                              flex: 2,
                                              child: Row(
                                                children: [
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                                    decoration: BoxDecoration(
                                                      color: (status == 'Active' ? Colors.green : Colors.orange).withOpacity(0.15),
                                                      borderRadius: BorderRadius.circular(4),
                                                    ),
                                                    child: Text(
                                                      status,
                                                      style: TextStyle(
                                                        color: status == 'Active' ? Colors.greenAccent : Colors.orangeAccent,
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            IconButton(
                                              icon: const Icon(Icons.keyboard_arrow_right, color: Colors.white38, size: 18),
                                              onPressed: () => _showDetailsDrawer(context, student),
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
        ],
      ),
    );
  }

  Widget _buildSortHeader(String label, String column) {
    final isCurrent = _sortColumn == column;
    return InkWell(
      onTap: () => _onSort(column),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(label, style: GoogleFonts.poppins(color: Colors.white60, fontSize: 12, fontWeight: FontWeight.bold)),
          if (isCurrent) ...[
            const SizedBox(width: 4),
            Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward, color: Colors.blueAccent, size: 12),
          ],
        ],
      ),
    );
  }

  Widget _buildDropdownFilter(String label, String val, List<String> options, ValueChanged<String?> onChanged) {
    return Container(
      height: 42,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<String>(
          value: val,
          dropdownColor: const Color(0xFF1E293B),
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
          onChanged: onChanged,
          items: options.map<DropdownMenuItem<String>>((String value) {
            return DropdownMenuItem<String>(
              value: value,
              child: Text(value),
            );
          }).toList(),
        ),
      ),
    );
  }
}
