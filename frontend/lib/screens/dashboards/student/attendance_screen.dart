import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shimmer/shimmer.dart';
import '../../../core/api_constants.dart';

class AttendanceScreen extends StatefulWidget {
  final VoidCallback? onBack;
  final Map<String, dynamic>? userData; // Added userData

  const AttendanceScreen({super.key, this.onBack, this.userData});

  @override
  State<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends State<AttendanceScreen> {
  // State variables
  bool _loading = true;
  List<Map<String, dynamic>> _attendanceData = [];
  int _selectedMonth = DateTime.now().month;
  int _selectedYear = DateTime.now().year;

  // Stats
  Map<String, dynamic> _stats = {
    'present': 0,
    'absent': 0,
    'percentage': 0.0,
    'totalWorkingDays': 0,
  };

  // Dispute Modal Logic
  bool _modalVisible = false;
  final TextEditingController _disputeReasonController = TextEditingController();
  bool _submitting = false;
  
  // Selection Mode Logic
  bool _isSelectionMode = false;
  final Set<String> _selectedRequestDates = {}; // "yyyy-MM-dd"
  // For modal: Map of Date -> List<String> (sessions)
  Map<String, List<String>> _sessionsToCorrect = {}; 

  final List<String> _months = [
    "January", "February", "March", "April", "May", "June",
    "July", "August", "September", "October", "November", "December"
  ];
  
  List<int> _years = [];

  @override
  void initState() {
    super.initState();
    _calculateYears();
    _fetchAttendance();
  }

  @override
  void didUpdateWidget(covariant AttendanceScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Check if user changed to re-calc years and fetch attendance
    if (oldWidget.userData?['id'] != widget.userData?['id'] || 
        oldWidget.userData?['login_id'] != widget.userData?['login_id'] ||
        oldWidget.userData?['batch_no'] != widget.userData?['batch_no'] ||
        oldWidget.userData?['batchNo'] != widget.userData?['batchNo']) {
      
      _calculateYears();
      _fetchAttendance();
    }
  }

  void _calculateYears() {
    List<int> generatedYears = [];
    // Check both keys for robustness
    String? batch = widget.userData?['batch_no'] ?? widget.userData?['batchNo'];
    
    // Debug print
    debugPrint("Calculating years for batch: $batch");

    if (batch != null && batch.contains('-')) {
       try {
          final parts = batch.split('-');
          if (parts.length == 2) {
             int start = int.parse(parts[0].trim());
             int end = int.parse(parts[1].trim());
             if (end >= start && (end - start) < 10) { // Sanity check
                generatedYears = List.generate(end - start + 1, (i) => start + i);
             }
          }
       } catch (e) {
          debugPrint("Error parsing batch year: $e");
       }
    }
    
    if (generatedYears.isEmpty) {
       generatedYears = List.generate(6, (index) => DateTime.now().year - 4 + index);
    }
    
    setState(() {
      _years = generatedYears;
      
      // Ensure selectedYear is valid
      if (!_years.contains(_selectedYear)) {
         if (_years.isNotEmpty) {
             // If current year is in range, select it. Else select last (latest).
             int current = DateTime.now().year;
             if (_years.contains(current)) {
                _selectedYear = current;
             } else if (_selectedYear > _years.last) {
                _selectedYear = _years.last;
             } else if (_selectedYear < _years.first) {
                _selectedYear = _years.first;
             } else {
                _selectedYear = _years.last;
             }
         }
      }
    });
  }

  @override
  void dispose() {
    _disputeReasonController.dispose();
    super.dispose();
  }



  // Real API Call
  Future<void> _fetchAttendance() async {
    setState(() => _loading = true);
    
    final studentId = widget.userData?['id']?.toString() ?? widget.userData?['login_id']?.toString();
    
    if (studentId == null) {
       setState(() => _loading = false);
       return; 
    }

    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/attendance?studentId=$studentId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> history = data['history'] ?? [];
        final List<Map<String, dynamic>> mappedHistory = [];
        
        double totalPresentCount = 0;
        double totalAbsentCount = 0;
        Set<String> allUniqueDates = {};
        
        // Group by date first
        Map<String, List<Map<String, dynamic>>> recordsByDate = {};

        for (var record in history) {
           String rawDate = record['date'];
           String dateOnly = rawDate.split('T')[0];
           
           allUniqueDates.add(dateOnly);
           
           if (!recordsByDate.containsKey(dateOnly)) {
             recordsByDate[dateOnly] = [];
           }
           
           String statusRaw = (record['status'] as String).toUpperCase();
           String status = statusRaw.startsWith('P') ? 'PRESENT' : 'ABSENT';
           String session = (record['session'] ?? 'MORNING').toString().toUpperCase();

           recordsByDate[dateOnly]!.add({
             'status': status,
             'session': session,
           });

           mappedHistory.add({
             'date': rawDate, 
             'session': session, 
             'status': status, 
             'markedBy': 'Faculty',
             'subject': record['subjectName']
           });
        }
        
        for (String date in allUniqueDates) {
          final dayRecords = recordsByDate[date] ?? [];
          bool hasMorning = dayRecords.any((r) => r['session'] == 'MORNING');
          bool hasAfternoon = dayRecords.any((r) => r['session'] == 'AFTERNOON');
          
          bool morningPresent = dayRecords.any((r) => r['session'] == 'MORNING' && r['status'] == 'PRESENT');
          bool afternoonPresent = dayRecords.any((r) => r['session'] == 'AFTERNOON' && r['status'] == 'PRESENT');
          
          // If a student is absent morning and afternoon, that is 1 absent day.
          // If a student is absent one session, that is 0.5 absent days.
          // Same for present. Count valid recorded sessions.
          double dayPresent = 0.0;
          double dayAbsent = 0.0;
          
          bool isSingleSessionDay = (hasMorning && !hasAfternoon) || (!hasMorning && hasAfternoon);
          
          if (hasMorning) {
             if (morningPresent) {
               dayPresent += isSingleSessionDay ? 1.0 : 0.5;
             } else {
               dayAbsent += 0.5;
             }
          }
          if (hasAfternoon) {
             if (afternoonPresent) {
               dayPresent += isSingleSessionDay ? 1.0 : 0.5;
             } else {
               dayAbsent += 0.5;
             }
          }
          
          totalPresentCount += dayPresent;
          totalAbsentCount += dayAbsent;
        }
        
        final totalDays = totalPresentCount + totalAbsentCount;
        final percentage = totalDays > 0 ? (totalPresentCount / totalDays) * 100 : 0.0;

        if (mounted) {
          setState(() {
            _attendanceData = mappedHistory;
            // Format to remove .0 if it's a whole number
            String presentDisplay = totalPresentCount == totalPresentCount.toInt() ? totalPresentCount.toInt().toString() : totalPresentCount.toString();
            String absentDisplay = totalAbsentCount == totalAbsentCount.toInt() ? totalAbsentCount.toInt().toString() : totalAbsentCount.toString();

            _stats = {
              'present': presentDisplay, 
              'absent': absentDisplay,
              'percentage': percentage.toStringAsFixed(1),
              'totalWorkingDays': totalDays 
            };
            _loading = false;
          });
        }
      } else {
         debugPrint("Failed to fetch attendance: ${response.statusCode}");
         if (mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint("Attendance Network Error: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _handleDayTap(String dateStr, Map<String, dynamic>? morning, Map<String, dynamic>? afternoon) {
    if (dateStr.isEmpty) return;
    
    // Check if day has any absent session
    bool morningAbsent = morning?['status'] == 'ABSENT';
    bool afternoonAbsent = afternoon?['status'] == 'ABSENT'; 

    if (!morningAbsent && !afternoonAbsent) {
      if (_isSelectionMode) {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
           content: Text("Only absent days can be selected."), 
           duration: Duration(milliseconds: 500)
         ));
      }
      return;
    }

    if (_isSelectionMode) {
      setState(() {
        if (_selectedRequestDates.contains(dateStr)) {
          _selectedRequestDates.remove(dateStr);
        } else {
          _selectedRequestDates.add(dateStr);
        }
      });
    } else {
      // Prompt to enable selection mode
       ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Click 'Raise Request' to select days.")),
      );
    }
  }

  void _startRequest() {
     if (_selectedRequestDates.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one absent day.")));
        return;
     }
     
     // Prepare sessions map
     Map<String, List<String>> initialSessions = {};
     for (String date in _selectedRequestDates) {
       // Default to absent sessions
       final dayStats = _getDayStatus(date);
       List<String> sessions = [];
       if (dayStats['morning']?['status'] == 'ABSENT') sessions.add('MORNING');
       if (dayStats['afternoon']?['status'] == 'ABSENT') sessions.add('AFTERNOON');
       if(sessions.isEmpty) {
           // Fallback if marked absent in grid but data mismatch (shouldn't happen due to tap check)
           sessions.add('MORNING');
       }
       initialSessions[date] = sessions;
     }

     setState(() {
       _sessionsToCorrect = initialSessions;
       _disputeReasonController.text = "";
       _modalVisible = true;
     });
  }

  Future<void> _submitRequest() async {
    if (_disputeReasonController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please enter a reason.")));
      return;
    }
    
    // Filter out unchecked sessions
    List<Map<String, String>> items = [];
    _sessionsToCorrect.forEach((date, sessions) {
      for (var session in sessions) {
        items.add({'date': date, 'session': session});
      }
    });

    if (items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select at least one session.")));
        return;
    }

    setState(() => _submitting = true);
    
    final studentId = widget.userData?['id']?.toString() ?? widget.userData?['login_id']?.toString();

    try {
      final body = {
        'userId': studentId,
        'items': items,
        'reason': _disputeReasonController.text
      };

      final response = await http.post(
         Uri.parse('${ApiConstants.baseUrl}/api/user/request-attendance-correction'),
         headers: {'Content-Type': 'application/json'},
         body: json.encode(body)
      );

      if (response.statusCode == 200) {
         if (mounted) {
            setState(() {
              _submitting = false;
              _modalVisible = false;
              _isSelectionMode = false;
              _selectedRequestDates.clear();
            });
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Correction request sent successfully.")));
         }
      } else {
         if(mounted) setState(() => _submitting = false);
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed: ${response.statusCode}")));
      }
    } catch (e) {
      if(mounted) setState(() => _submitting = false);
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final textColor = theme.colorScheme.onSurface;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        systemOverlayStyle: theme.brightness == Brightness.dark 
            ? SystemUiOverlayStyle.light 
            : SystemUiOverlayStyle.dark,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: widget.onBack ?? () => Navigator.of(context).pop(),
        ),
        title: Text(
          "Attendance",
          style: GoogleFonts.poppins(
            color: textColor,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        actions: [
          if (_isSelectionMode)
           TextButton(
             onPressed: () => setState(() {
               _isSelectionMode = false;
               _selectedRequestDates.clear();
             }),
             child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.red)),
           )
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Month/Year Selectors
                    _buildSelectors(textColor, theme.cardColor),
                    const SizedBox(height: 20),

                    // Stats Cards
                    _buildStatsRow(textColor, theme.cardColor),
                    const SizedBox(height: 20),
                    
                    if (_isSelectionMode)
                      Container(
                        padding: const EdgeInsets.all(10),
                        margin: const EdgeInsets.only(bottom: 15),
                        decoration: BoxDecoration(color: Colors.red.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(8)),
                        child: Row(
                          children: [
                            const Icon(Icons.info_outline, color: Colors.red, size: 20),
                            const SizedBox(width: 10),
                            Expanded(child: Text("Tap on absent days inside the red marks to select them for correction.", style: GoogleFonts.poppins(fontSize: 12, color: Colors.red))),
                          ],
                        ),
                      ),

                    // Calendar
                  _loading 
                    ? _buildSkeletonCalendar(theme.cardColor, textColor)
                    : _buildCalendarGrid(textColor, theme.colorScheme.error),
                  
                  const SizedBox(height: 30),
                    
                    // Request Button
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _isSelectionMode ? (_selectedRequestDates.isEmpty ? Colors.grey : Colors.green) : theme.primaryColor,
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        if (!_isSelectionMode) {
                          setState(() => _isSelectionMode = true);
                        } else {
                          _startRequest();
                        }
                      },
                      child: Text(
                        _isSelectionMode ? "Proceed to Request (${_selectedRequestDates.length})" : "Raise Correction Request",
                        style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                    
                    const SizedBox(height: 15),
                    
                    // Track Button
                    if (!_isSelectionMode)
                      Center(
                        child: TextButton.icon(
                          onPressed: _showTrackRequestsModal,
                          icon: const Icon(Icons.history, color: Colors.blue),
                          label: Text("Track Requests", style: GoogleFonts.poppins(color: Colors.blue, fontWeight: FontWeight.bold)),
                        ),
                      ),
                    
                    const SizedBox(height: 40), 
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
      bottomSheet: _modalVisible ? _buildBottomSheetForm() : null, // Using bottom sheet logic or custom modal
    );
  }

  Widget _buildSelectors(Color textColor, Color cardColor) {
    return Row(
      children: [
        Expanded(
          child: _buildDropdownButton(
            text: _months[_selectedMonth - 1],
            onTap: () => _showSelectionModal(
              items: _months,
              onSelect: (item) {
                setState(() {
                  _selectedMonth = _months.indexOf(item) + 1;
                });
                _fetchAttendance();
              },
            ),
            textColor: textColor,
            bgColor: cardColor,
          ),
        ),
        const SizedBox(width: 15),
        Expanded(
          child: _buildDropdownButton(
            text: _selectedYear.toString(),
            onTap: () => _showSelectionModal(
              items: _years.map((e) => e.toString()).toList(),
              onSelect: (item) {
                setState(() {
                  _selectedYear = int.parse(item);
                });
                 _fetchAttendance();
              },
            ),
            textColor: textColor,
            bgColor: cardColor,
          ),
        ),
      ],
    );
  }

  Widget _buildDropdownButton({required String text, required VoidCallback onTap, required Color textColor, required Color bgColor}) {
    // Add border for visibility if cardColor is same as bg
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey.withValues(alpha: 0.2)),
          boxShadow: [
             BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 5, offset: const Offset(0, 2))
          ]
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              text, 
              style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 16, color: textColor)
            ),
            Icon(Icons.keyboard_arrow_down, size: 16, color: textColor.withValues(alpha: 0.7)),
          ],
        ),
      ),
    );
  }

  void _showSelectionModal({required List<String> items, required Function(String) onSelect}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        backgroundColor: Theme.of(context).cardColor,
        child: Container(
          padding: const EdgeInsets.all(20),
          constraints: const BoxConstraints(maxHeight: 400),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text("Select Option", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    return ListTile(
                      title: Text(items[index], textAlign: TextAlign.center),
                      onTap: () {
                        onSelect(items[index]);
                        Navigator.pop(context);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsRow(Color textColor, Color cardColor) {
    return Row(
      children: [
        _buildStatCard(
          value: "${_stats['present']}",
          label: "Days",
          subLabel: "Present",
          color: Colors.green, // Fixed Standard Color
          cardColor: cardColor,
          textColor: textColor
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          value: "${_stats['percentage']}%",
          label: "",
          subLabel: "Overall",
          color: Theme.of(context).primaryColor,
          isCenter: true,
          cardColor: cardColor,
          textColor: textColor
        ),
        const SizedBox(width: 10),
        _buildStatCard(
          value: "${_stats['absent']}",
          label: "Days",
          subLabel: "Absent",
          color: Colors.red, // Fixed Standard Color
          cardColor: cardColor,
          textColor: textColor
        ),
      ],
    );
  }

  Widget _buildStatCard({
    required String value, 
    required String label, 
    required String subLabel, 
    required Color color, 
    required Color cardColor,
    required Color textColor,
    bool isCenter = false
  }) {
    return Expanded(
      child: Column(
        children: [
          Container(
            width: isCenter ? 80 : 70,
            height: isCenter ? 80 : 70,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: color, width: 4),
              color: cardColor,
              boxShadow: isCenter ? [
                 BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 10, spreadRadius: 2)
              ] : null
            ),
            alignment: Alignment.center,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  value,
                  style: GoogleFonts.poppins(
                    fontWeight: FontWeight.bold, 
                    fontSize: isCenter ? 18 : 16,
                    color: textColor
                  ),
                ),
                if (label.isNotEmpty)
                  Text(
                    label,
                    style: GoogleFonts.poppins(fontSize: 10, color: textColor.withValues(alpha: 0.7)),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 5),
          Text(subLabel, style: GoogleFonts.poppins(fontWeight: FontWeight.w500, fontSize: 14, color: textColor.withValues(alpha: 0.8))),
        ],
      ),
    );
  }

  Widget _buildCalendarGrid(Color textColor, Color errorColor) {
    final daysInMonth = DateUtils.getDaysInMonth(_selectedYear, _selectedMonth);
    final firstDayDate = DateTime(_selectedYear, _selectedMonth, 1);
    final startOffset = (firstDayDate.weekday == 7) ? 0 : firstDayDate.weekday;
    
    final totalSlots = daysInMonth + startOffset;

    return Column(
      children: [
        // Days Header
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'].map((d) => 
            Expanded(child: Text(d, textAlign: TextAlign.center, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor.withValues(alpha: 0.7))))
          ).toList(),
        ),
        const SizedBox(height: 10),
        // Grid
        GridView.builder(
           shrinkWrap: true,
           physics: const NeverScrollableScrollPhysics(),
           gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
             crossAxisCount: 7,
             childAspectRatio: 0.85, 
             mainAxisSpacing: 8,
             crossAxisSpacing: 8,
           ),
           itemCount: totalSlots,
           itemBuilder: (context, index) {
             if (index < startOffset) return const SizedBox();
             
             final dayNum = index - startOffset + 1;
             if (dayNum > daysInMonth) return const SizedBox();

             // Check status
             final dateStr = DateFormat('yyyy-MM-dd').format(DateTime(_selectedYear, _selectedMonth, dayNum));
             final dayStats = _getDayStatus(dateStr);
             final morning = dayStats['morning'] as Map<String, dynamic>?;
             final afternoon = dayStats['afternoon'] as Map<String, dynamic>?;
             
             // Logic for Visuals
             bool mPresent = morning?['status'] == 'PRESENT';
             bool aPresent = afternoon?['status'] == 'PRESENT';
             bool mAbsent = morning?['status'] == 'ABSENT';
             bool aAbsent = afternoon?['status'] == 'ABSENT';
             bool mRecorded = morning != null && morning.isNotEmpty;
             bool aRecorded = afternoon != null && afternoon.isNotEmpty;

             bool fullPresent = mPresent && aPresent;
             bool fullAbsent = mAbsent && aAbsent;
             bool partial = (mPresent && aAbsent) || (mAbsent && aPresent) || 
                            (mRecorded && !aRecorded) || (!mRecorded && aRecorded);
             
             // Selection State
             bool isSelected = _selectedRequestDates.contains(dateStr);

             // Border color
             Color borderColor = Colors.grey.withValues(alpha: 0.3);
             if (fullAbsent) borderColor = errorColor.withValues(alpha: 0.5);
             if (fullPresent) borderColor = Colors.greenAccent.withValues(alpha: 0.8);
             if (isSelected) borderColor = Colors.blue;

             Color morningColor = mRecorded ? (mPresent ? Colors.greenAccent.withValues(alpha: 0.4) : Colors.red) : Colors.transparent;
             Color afternoonColor = aRecorded ? (aPresent ? Colors.greenAccent.withValues(alpha: 0.4) : Colors.red) : Colors.transparent;

             return GestureDetector(
               onTap: (mAbsent || aAbsent) ? () => _handleDayTap(dateStr, morning, afternoon) : null,
               child: Stack(
                 children: [
                   Container(
                     alignment: Alignment.center,
                     decoration: BoxDecoration(
                       borderRadius: BorderRadius.circular(8),
                       color: fullPresent ? Colors.greenAccent.withValues(alpha: 0.4) : (fullAbsent ? Colors.red : null),
                       gradient: partial ? LinearGradient(
                          colors: [morningColor, afternoonColor],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          stops: const [0.5, 0.5] 
                       ) : null,
                       border: Border.all(
                         color: isSelected ? Colors.blue : borderColor, 
                         width: isSelected ? 3 : 1,
                       )
                     ),
                     child: Text(
                       "$dayNum",
                       style: GoogleFonts.poppins(
                         color: fullAbsent ? Colors.white : textColor,
                         fontWeight: FontWeight.w600,
                       ),
                     ),
                   ),
                   if (isSelected)
                     const Positioned(
                       top: 2,
                       right: 2,
                       child: Icon(Icons.check_circle, color: Colors.blue, size: 16),
                     )
                 ],
               ),
             );
           },
        ),
      ],
    );
  }

  Widget _buildSkeletonCalendar(Color cardColor, Color textColor) {
    return Shimmer.fromColors(
      baseColor: cardColor,
      highlightColor: cardColor.withValues(alpha: 0.5),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: ['Su', 'Mo', 'Tu', 'We', 'Th', 'Fr', 'Sa'].map((d) => 
              Expanded(child: Container(height: 20, margin: const EdgeInsets.symmetric(horizontal: 10), color: Colors.white))
            ).toList(),
          ),
          const SizedBox(height: 10),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 7,
              childAspectRatio: 0.85, 
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
            ),
            itemCount: 35, // Typical calendar grid size
            itemBuilder: (context, index) {
              return Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Map<String, dynamic> _getDayStatus(String dateStr) {
    final records = _attendanceData.where((d) => d['date'].startsWith(dateStr) || d['date'].split('T')[0] == dateStr).toList();
    final morning = records.firstWhere((d) => d['session'] == 'MORNING', orElse: () => {});
    final afternoon = records.firstWhere((d) => d['session'] == 'AFTERNOON', orElse: () => {});
    
    final mStatus = morning.isNotEmpty ? morning['status'] : null;
    final aStatus = afternoon.isNotEmpty ? afternoon['status'] : null;
    final isAbsent = mStatus == 'ABSENT' || aStatus == 'ABSENT';
    
    return {
      'isAbsent': isAbsent,
      'morning': morning.isNotEmpty ? morning : null,
      'afternoon': afternoon.isNotEmpty ? afternoon : null,
    };
  }

  // Bottom Sheet instead of Dialog for Request Form
  Widget _buildBottomSheetForm() {
    return Container(
       padding: const EdgeInsets.all(25),
       height: MediaQuery.of(context).size.height * 0.7,
       decoration: BoxDecoration(
         color: Theme.of(context).cardColor,
         borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
         boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 20)]
       ),
       child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("Correction Request", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
                IconButton(onPressed: () => setState(() => _modalVisible = false), icon: const Icon(Icons.close))
              ],
            ),
            const SizedBox(height: 10),
            Text("Select sessions to correct for selected days:", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 15),
            
            Expanded(
              child: ListView.builder(
                itemCount: _sessionsToCorrect.keys.length,
                itemBuilder: (context, index) {
                   String date = _sessionsToCorrect.keys.elementAt(index);
                   List<String> sessions = _sessionsToCorrect[date]!;
                   
                   final dayStats = _getDayStatus(date);
                   bool mAvailable = dayStats['morning']?['status'] == 'ABSENT';
                   bool aAvailable = dayStats['afternoon']?['status'] == 'ABSENT';

                   return Card(
                     color: Colors.grey.withValues(alpha: 0.05),
                     margin: const EdgeInsets.only(bottom: 10),
                     shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                     child: Padding(
                       padding: const EdgeInsets.all(10),
                       child: Column(
                         crossAxisAlignment: CrossAxisAlignment.start,
                         children: [
                           Text(DateFormat.yMMMMEEEEd().format(DateTime.parse(date)), style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                           const SizedBox(height: 5),
                           Row(
                             children: [
                               if (mAvailable)
                                 Row(
                                   children: [
                                     Checkbox(
                                       value: sessions.contains('MORNING'),
                                       onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              sessions.add('MORNING');
                                            } else {
                                              sessions.remove('MORNING');
                                            }
                                          });
                                       },
                                     ),
                                     Text("Morning", style: GoogleFonts.poppins(fontSize: 13)),
                                     const SizedBox(width: 15),
                                   ],
                                 ),
                                if (aAvailable)
                                 Row(
                                   children: [
                                     Checkbox(
                                       value: sessions.contains('AFTERNOON'),
                                       onChanged: (val) {
                                          setState(() {
                                            if (val == true) {
                                              sessions.add('AFTERNOON');
                                            } else {
                                              sessions.remove('AFTERNOON');
                                            }
                                          });
                                       },
                                     ),
                                     Text("Afternoon", style: GoogleFonts.poppins(fontSize: 13)),
                                   ],
                                 ),
                             ],
                           )
                         ],
                       ),
                     ),
                   );
                },
              ),
            ),
            
            const SizedBox(height: 15),
            // Reason
            TextField(
              controller: _disputeReasonController,
              maxLines: 3,
              decoration: InputDecoration(
                hintText: "Reason for correction...",
                fillColor: Colors.grey.withValues(alpha: 0.1),
                filled: true,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10), borderSide: BorderSide.none),
              ),
            ),
            const SizedBox(height: 20),
            
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 15),
                  backgroundColor: Theme.of(context).primaryColor,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: _submitting ? null : _submitRequest,
                child: Text(_submitting ? "Submitting..." : "Submit Request", style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
              ),
            )
         ],
       ),
    );
  }
  void _showTrackRequestsModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => TrackRequestsSheet(userData: widget.userData),
    );
  }
}

class TrackRequestsSheet extends StatefulWidget {
  final Map<String, dynamic>? userData;
  const TrackRequestsSheet({super.key, this.userData});

  @override
  State<TrackRequestsSheet> createState() => _TrackRequestsSheetState();
}

class _TrackRequestsSheetState extends State<TrackRequestsSheet> {
  List<dynamic> _requests = [];
  bool _loading = true;
  bool _isSelectionMode = false;
  final Set<String> _selectedIds = {};

  @override
  void initState() {
    super.initState();
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    final studentId = widget.userData?['id']?.toString() ?? widget.userData?['login_id']?.toString();
    if (studentId == null) {
      if(mounted) setState(() => _loading = false);
      return;
    }

    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/user/attendance-correction-requests?studentId=$studentId'));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _requests = json.decode(response.body);
            _loading = false;
          });
        }
      } else {
         if(mounted) setState(() => _loading = false);
      }
    } catch (e) {
      debugPrint("Error fetching requests: $e");
      if(mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteSelected() async {
    if (_selectedIds.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/user/attendance-correction-requests/delete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'ids': _selectedIds.toList()}),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _requests.removeWhere((r) => _selectedIds.contains(r['id']));
            _selectedIds.clear();
            _isSelectionMode = false;
          });
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Deleted successfully")));
        }
      } else {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to delete")));
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _toggleSelection(String id) {
    setState(() {
      if (_selectedIds.contains(id)) {
        _selectedIds.remove(id);
        if (_selectedIds.isEmpty) _isSelectionMode = false;
      } else {
        _selectedIds.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      initialChildSize: 0.7,
      minChildSize: 0.5,
      maxChildSize: 0.9,
      builder: (_, controller) => Container(
        decoration: BoxDecoration(
          color: Theme.of(context).cardColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        ),
        child: Column(
          children: [
             Padding(
               padding: const EdgeInsets.all(20),
               child: Row(
                 mainAxisAlignment: MainAxisAlignment.spaceBetween,
                 children: [
                   if (_isSelectionMode) ...[
                      Text("${_selectedIds.length} Selected", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue)),
                      Row(
                        children: [
                          IconButton(
                            icon: const Icon(Icons.delete, color: Colors.red),
                            onPressed: _deleteSelected,
                          ),
                          IconButton(
                            icon: const Icon(Icons.close),
                            onPressed: () => setState(() {
                              _isSelectionMode = false;
                              _selectedIds.clear();
                            }),
                          )
                        ],
                      )
                   ] else ...[
                      Text("Request History", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold)),
                      IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close))
                   ]
                 ],
               ),
             ),
             Expanded(
               child: _loading 
                 ? const Center(child: CircularProgressIndicator())
                 : _requests.isEmpty 
                    ? Center(child: Text("No requests found", style: GoogleFonts.poppins(color: Colors.grey)))
                    : ListView.builder(
                       controller: controller,
                       padding: const EdgeInsets.symmetric(horizontal: 20),
                       itemCount: _requests.length,
                       itemBuilder: (context, index) {
                          final item = _requests[index];
                          final id = item['id'];
                          final status = item['status'];
                          Color statusColor = Colors.orange;
                          if (status == 'APPROVED') statusColor = Colors.green;
                          if (status == 'REJECTED') statusColor = Colors.red;
                          
                          // Parse dates
                          List<dynamic> datesInfo = [];
                           try {
                             if (item['dates'] is String) {
                                datesInfo = json.decode(item['dates']);
                             } else {
                                datesInfo = item['dates'];
                             }
                           } catch (_) {}

                          final isSelected = _selectedIds.contains(id);

                          return GestureDetector(
                            onLongPress: () {
                              setState(() {
                                _isSelectionMode = true;
                                _toggleSelection(id);
                              });
                            },
                            onTap: _isSelectionMode ? () => _toggleSelection(id) : null,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 15),
                              padding: const EdgeInsets.all(15),
                              decoration: BoxDecoration(
                                color: isSelected ? Colors.blue.withValues(alpha: 0.1) : Theme.of(context).scaffoldBackgroundColor,
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: isSelected ? Colors.blue : Colors.grey.withValues(alpha: 0.1)),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                        decoration: BoxDecoration(color: statusColor.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(20)),
                                        child: Text(status, style: GoogleFonts.poppins(color: statusColor, fontWeight: FontWeight.bold, fontSize: 12)),
                                      ),
                                      if (_isSelectionMode)
                                        Icon(isSelected ? Icons.check_circle : Icons.circle_outlined, color: isSelected ? Colors.blue : Colors.grey)
                                      else
                                        Text(
                                          DateFormat('dd MMM yyyy').format(DateTime.parse(item['created_at'])),
                                          style: GoogleFonts.poppins(color: Colors.grey, fontSize: 12),
                                        )
                                    ],
                                  ),
                                  const SizedBox(height: 10),
                                  Text("Dates:", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                                  ...datesInfo.map((d) => Text("• ${d['date']} (${d['session']})", style: GoogleFonts.poppins(fontSize: 13, color: Colors.grey[700]))),
                                  const SizedBox(height: 10),
                                  Text("Reason: ${item['reason']}", style: GoogleFonts.poppins(fontSize: 14, fontStyle: FontStyle.italic)),
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
    );
  }
}
