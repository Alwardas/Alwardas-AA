import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/theme_extensions.dart';
import '../../../core/api_config.dart';
import '../../../core/api_constants.dart';

class DesktopHodTimetableView extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DesktopHodTimetableView({super.key, required this.userData});

  @override
  State<DesktopHodTimetableView> createState() => _DesktopHodTimetableViewState();
}

class _DesktopHodTimetableViewState extends State<DesktopHodTimetableView> {
  final List<String> _days = ['Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];
  late String _selectedDay;
  bool _isLoading = false;
  bool _isSaving = false;

  List<dynamic> _rows = [];
  List<dynamic> _labRows = [];
  List<dynamic> _clashes = [];
  List<Map<String, dynamic>> _allStaff = [];

  @override
  void initState() {
    super.initState();
    int weekday = DateTime.now().weekday;
    if (weekday > 6) weekday = 1;
    _selectedDay = _days[weekday - 1];
    _fetchMasterTimetable();
    _fetchStaff();
  }

  Future<void> _fetchMasterTimetable() async {
    setState(() => _isLoading = true);
    final branch = widget.userData['branch'] ?? 'Computer Engineering';
    try {
      final uri = '${ApiConstants.baseUrl}/api/hod/master-timetable?branch=${Uri.encodeComponent(branch)}&day=$_selectedDay';
      final res = await ApiConfig.get(uri);
      if (res.success && res.data != null) {
        setState(() {
          _rows = res.data['rows'] ?? [];
          _labRows = res.data['labRows'] ?? [];
          _clashes = res.data['facultyClashes'] ?? [];
        });
      }
    } catch (e) {
      debugPrint("Master Timetable Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _fetchStaff() async {
    try {
      final res = await ApiConfig.get('${ApiConstants.baseUrl}/api/staff/all');
      if (res.success && res.data != null) {
        final List<dynamic> rawStaff = res.data['data'] ?? [];
        setState(() {
          _allStaff = List<Map<String, dynamic>>.from(rawStaff);
        });
      }
    } catch (e) {
      debugPrint("Staff Error: $e");
    }
  }

  Future<void> _showAssignDialog(String className, int periodIndex, dynamic currentPeriod) async {
    // Determine year, section from className e.g. "CSE 1st Year Sec A" or "CSE - 2nd Year - Sec B"
    // Let's parse className to find year and section
    String year = "1st Year";
    if (className.contains("2nd")) year = "2nd Year";
    if (className.contains("3rd")) year = "3rd Year";

    String section = "A";
    if (className.contains("Sec B") || className.contains("- B")) section = "B";
    if (className.contains("Sec C") || className.contains("- C")) section = "C";

    final branch = widget.userData['branch'] ?? 'Computer Engineering';
    final TextEditingController subjectController = TextEditingController(
      text: currentPeriod != null ? currentPeriod['subject'] ?? '' : ''
    );
    String? selectedFacultyId = currentPeriod != null ? currentPeriod['facultyId'] ?? currentPeriod['faculty_id'] : null;

    final result = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return AlertDialog(
              backgroundColor: context.cardColor,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: Text(
                "Assign Slot: Period P$periodIndex",
                style: GoogleFonts.poppins(color: context.textPrimary, fontWeight: FontWeight.bold),
              ),
              content: Container(
                width: 450,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Class: $className | Day: $_selectedDay",
                      style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 13),
                    ),
                    SizedBox(height: 20),

                    // Subject Input
                    Text(
                      "Subject Name",
                      style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    TextField(
                      controller: subjectController,
                      style: TextStyle(color: context.textPrimary),
                      decoration: InputDecoration(
                        hintText: "e.g. Data Structures",
                        hintStyle: TextStyle(color: context.textMuted2),
                        filled: true,
                        fillColor: context.bgColor,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                    SizedBox(height: 20),

                    // Faculty Selection
                    Text(
                      "Assign Faculty Member",
                      style: GoogleFonts.poppins(color: context.textSecondary, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 8),
                    Container(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      decoration: BoxDecoration(
                        color: context.bgColor,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: selectedFacultyId,
                          dropdownColor: context.cardColor,
                          isExpanded: true,
                          hint: Text("Select Faculty", style: TextStyle(color: context.textMuted2)),
                          icon: Icon(Icons.keyboard_arrow_down, color: Colors.blueAccent),
                          items: _allStaff.map((staff) {
                            return DropdownMenuItem<String>(
                              value: staff['id']?.toString() ?? staff['login_id']?.toString(),
                              child: Text(
                                "${staff['name']} (${staff['role']})",
                                style: TextStyle(color: context.textPrimary, fontSize: 13),
                              ),
                            );
                          }).toList(),
                          onChanged: (val) {
                            setModalState(() {
                              selectedFacultyId = val;
                            });
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                if (currentPeriod != null)
                  TextButton(
                    onPressed: () async {
                      Navigator.pop(context, false); // Signifies Clear
                    },
                    child: Text("Clear Assignment", style: GoogleFonts.poppins(color: Colors.redAccent)),
                  ),
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text("Cancel", style: GoogleFonts.poppins(color: context.textMuted)),
                ),
                ElevatedButton(
                  onPressed: () {
                    if (subjectController.text.trim().isEmpty || selectedFacultyId == null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please complete all fields")),
                      );
                      return;
                    }
                    Navigator.pop(context, true); // Signifies Assign
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: context.textPrimary,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  child: Text("Save", style: GoogleFonts.poppins()),
                ),
              ],
            );
          },
        );
      },
    );

    if (result == null) return;

    setState(() => _isSaving = true);

    try {
      if (result == true) {
        // ASSIGN
        final body = {
          'facultyId': selectedFacultyId,
          'branch': branch,
          'year': year,
          'section': section,
          'day': _selectedDay,
          'periodIndex': periodIndex,
          'subject': subjectController.text.trim(),
        };
        final res = await ApiConfig.post('${ApiConstants.baseUrl}/api/timetable/assign', body: body);
        if (res.success) {
          _showSnackBar("Slot assigned successfully!");
          _fetchMasterTimetable();
        } else {
          _showSnackBar("Failed to assign: ${res.message}");
        }
      } else {
        // CLEAR
        final body = {
          'branch': branch,
          'year': year,
          'section': section,
          'day': _selectedDay,
          'periodIndex': periodIndex,
        };
        final res = await ApiConfig.post('${ApiConstants.baseUrl}/api/timetable/clear', body: body);
        if (res.success) {
          _showSnackBar("Slot cleared successfully!");
          _fetchMasterTimetable();
        } else {
          _showSnackBar("Failed to clear slot: ${res.message}");
        }
      }
    } catch (e) {
      _showSnackBar("Connection error occurred.");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showSnackBar(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final allRows = [..._rows, ..._labRows];

    return Container(
      color: context.bgColor,
      padding: EdgeInsets.all(30),
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
                    'Department Master Timetable',
                    style: GoogleFonts.poppins(color: context.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'View and schedule period assignments and resolve faculty conflicts for your branch',
                    style: GoogleFonts.poppins(color: context.textMuted, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          SizedBox(height: 24),

          // Day Selection row
          Row(
            children: _days.map((day) {
              final isSelected = day == _selectedDay;
              return Padding(
                padding: EdgeInsets.only(right: 12),
                child: ChoiceChip(
                  label: Text(day),
                  selected: isSelected,
                  selectedColor: Colors.blueAccent,
                  backgroundColor: context.cardColor,
                  labelStyle: GoogleFonts.poppins(
                    color: isSelected ? context.textPrimary : context.textSecondary,
                    fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                    fontSize: 13,
                  ),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _selectedDay = day);
                      _fetchMasterTimetable();
                    }
                  },
                ),
              );
            }).toList(),
          ),
          SizedBox(height: 20),

          // Clash Warnings
          if (_clashes.isNotEmpty) _buildClashWarning(),

          // Table / Schedule Grid
          Expanded(
            child: _isLoading || _isSaving
                ? Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                : allRows.isEmpty
                    ? _buildEmptyState()
                    : SingleChildScrollView(
                        scrollDirection: Axis.vertical,
                        physics: BouncingScrollPhysics(),
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            color: context.cardColor,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.borderColor),
                          ),
                          child: DataTable(
                            columnSpacing: 20,
                            horizontalMargin: 20,
                            headingRowColor: WidgetStateProperty.all(context.bgColor.withOpacity(0.4)),
                            columns: [
                              DataColumn(
                                  label: Text('Class / Lab',
                                      style: GoogleFonts.poppins(color: context.textPrimary, fontWeight: FontWeight.bold))),
                              ...List.generate(
                                  8,
                                  (i) => DataColumn(
                                      label: Text('P${i + 1}',
                                          style: GoogleFonts.poppins(
                                              color: context.textPrimary, fontWeight: FontWeight.bold)))),
                            ],
                            rows: allRows.map((row) {
                              final String className = row['className'] ?? '';
                              final periods = row['periods'] as List? ?? [];
                              return DataRow(
                                cells: [
                                  DataCell(
                                    Text(
                                      className,
                                      style: GoogleFonts.poppins(color: context.textSecondary, fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                  ),
                                  ...List.generate(8, (i) {
                                    final p = i < periods.length ? periods[i] : null;
                                    return DataCell(
                                      InkWell(
                                        onTap: () => _showAssignDialog(className, i + 1, p),
                                        child: _buildCellWidget(p),
                                      ),
                                    );
                                  }),
                                ],
                              );
                            }).toList(),
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }

  Widget _buildCellWidget(dynamic p) {
    if (p == null) {
      return Center(
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.02),
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: Colors.white.withOpacity(0.05)),
          ),
          child: Text(
            "-",
            style: GoogleFonts.poppins(color: context.textMuted2, fontSize: 12),
          ),
        ),
      );
    }

    return Container(
      padding: EdgeInsets.all(6),
      margin: EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: Colors.blueAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.blueAccent.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            p['subject'] ?? 'Unknown',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(color: context.textPrimary, fontWeight: FontWeight.bold, fontSize: 11),
          ),
          Text(
            p['facultyName'] ?? 'N/A',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.poppins(color: context.textMuted, fontSize: 9),
          ),
        ],
      ),
    );
  }

  Widget _buildClashWarning() {
    return Container(
      margin: EdgeInsets.only(bottom: 20),
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.redAccent, size: 20),
              SizedBox(width: 8),
              Text(
                "Active Faculty Schedule Conflicts",
                style: GoogleFonts.poppins(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 14),
              ),
            ],
          ),
          SizedBox(height: 8),
          ..._clashes.map((c) {
            return Padding(
              padding: EdgeInsets.only(bottom: 4),
              child: Text(
                "• ${c['facultyName']} is double-assigned to ${c['classes']?.join(', ')} in Period P${c['periodIndex']}",
                style: GoogleFonts.poppins(color: Colors.redAccent.withOpacity(0.8), fontSize: 12),
              ),
            );
          }).toList(),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.schedule, size: 64, color: context.textMuted2),
          SizedBox(height: 20),
          Text(
            "No master timetable available for $_selectedDay",
            style: GoogleFonts.poppins(color: context.textMuted, fontSize: 16),
          ),
        ],
      ),
    );
  }
}

