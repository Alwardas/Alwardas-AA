import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/helpers/announcement_theme_helper.dart';
import 'coordinator_announcements_screen.dart';

class CoordinatorCreateAnnouncementScreen extends StatefulWidget {
  const CoordinatorCreateAnnouncementScreen({super.key});

  @override
  State<CoordinatorCreateAnnouncementScreen> createState() =>
      _CoordinatorCreateAnnouncementScreenState();
}

class _CoordinatorCreateAnnouncementScreenState
    extends State<CoordinatorCreateAnnouncementScreen> {
  // Form State
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  AnnouncementType _selectedType = AnnouncementType.general;
  AnnouncementPriority _selectedPriority = AnnouncementPriority.normal;
  final List<String> _selectedAudience = [];
  DateTime _startDate = DateTime.now();
  TimeOfDay _startTime = TimeOfDay.now();
  DateTime _endDate = DateTime.now().add(const Duration(days: 7));
  bool _sendPush = true;
  bool _sendInApp = true;

  // Targeting filters
  List<String> _departments = [];
  List<String> _selectedBranches = [];
  final List<String> _years = ['1st Year', '2nd Year', '3rd Year'];
  List<String> _selectedYears = [];
  List<String> _sections = ['Section A', 'Section B'];
  List<String> _selectedSections = [];

  // UI State
  bool _isAutoSaving = false;
  Timer? _autoSaveTimer;

  // Constants
  final List<String> _audienceOptions = [
    'Students',
    'Faculty',
    'HODs',
    'Principal',
    'Coordinator',
    'Incharges',
    'Parents',
    'All'
  ];

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
    // Auto-save Setup
    _autoSaveTimer = Timer.periodic(const Duration(seconds: 10), (timer) {
      if (_titleController.text.isNotEmpty) {
        setState(() => _isAutoSaving = true);
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) setState(() => _isAutoSaving = false);
        });
      }
    });

    _titleController.addListener(() => setState(() {}));
    _descController.addListener(() => setState(() {}));
  }

  Future<void> _fetchDepartments() async {
    try {
      final res = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/departments'));
      if (res.statusCode == 200) {
        final List data = json.decode(res.body);
        if (mounted) {
          setState(() {
             _departments = data.map((d) => d['branch'].toString()).toList();
          });
        }
      }
    } catch (_) {}
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    _titleController.dispose();
    _descController.dispose();
    super.dispose();
  }

  bool get _isValid =>
      _titleController.text.isNotEmpty &&
      _descController.text.isNotEmpty &&
      _selectedAudience.isNotEmpty;

  Future<void> _handlePublish() async {
    setState(() => _isAutoSaving = true);

    try {
      final userData = await AuthService.getUserSession();
      if (userData == null) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('User session not found')));
        return;
      }

      final creatorId = userData['id'];

      final startDateTime = DateTime(_startDate.year, _startDate.month,
              _startDate.day, _startTime.hour, _startTime.minute)
          .toUtc()
          .toIso8601String();

      final endDateTime = _endDate.toUtc().toIso8601String();

      List<String> finalAudience = List.from(_selectedAudience);
      if (finalAudience.contains('Students')) {
         if (_selectedBranches.isNotEmpty) finalAudience.add("Branches: ${_selectedBranches.join(', ')}");
         if (_selectedYears.isNotEmpty) finalAudience.add("Years: ${_selectedYears.join(', ')}");
         if (_selectedSections.isNotEmpty) finalAudience.add("Sections: ${_selectedSections.join(', ')}");
      }

      final body = {
        "title": _titleController.text,
        "description": _descController.text,
        "type": _selectedType.toString().split('.').last,
        "audience": finalAudience,
        "priority": _selectedPriority.toString().split('.').last,
        "start_date": startDateTime,
        "end_date": endDateTime,
        "isPinned": false,
        "creatorId": creatorId,
        "sendPush": _sendPush,
        "sendInApp": _sendInApp
      };

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/announcement'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      if (response.statusCode == 201) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('Announcement Published Successfully!')));
          Navigator.pop(context, true);
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Failed: ${response.body}')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isAutoSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      backgroundColor:
          isDark ? const Color(0xFF020617) : Colors.grey[50], // Keep consistent
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.close, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Create Announcement',
            style: GoogleFonts.poppins(
                color: isDark ? Colors.white : Colors.black,
                fontWeight: FontWeight.bold)),
        actions: [
          if (_isAutoSaving)
            Padding(
              padding: const EdgeInsets.only(right: 15),
              child: Center(
                  child: Text("Saving Draft...",
                      style: GoogleFonts.poppins(
                          color: Colors.grey, fontSize: 12))),
            ),
          Padding(
            padding: const EdgeInsets.only(right: 15),
            child: Center(
              child: ElevatedButton(
                onPressed: _isValid && !_isAutoSaving ? _handlePublish : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF2563EB),
                  disabledBackgroundColor: Colors.grey.withValues(alpha: 0.3),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                  padding:
                      const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                ),
                child: _isAutoSaving
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            color: Colors.white, strokeWidth: 2))
                    : Text('Publish',
                        style: GoogleFonts.poppins(
                            color: Colors.white, fontWeight: FontWeight.bold)),
              ),
            ),
          )
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 1. LIVE PREVIEW CARD
            Text("LIVE PREVIEW",
                style: GoogleFonts.poppins(
                    color: Colors.grey,
                    fontSize: 12,
                    letterSpacing: 1.5,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            _buildLivePreviewCard(isDark),
            const SizedBox(height: 30),

            // 2. FORM FIELDS
            _buildFormSection(
                "Content",
                [
                  _buildTextField("Title", _titleController, isDark,
                      maxLines: 1),
                  const SizedBox(height: 15),
                  _buildTextField(
                      "Description / Message", _descController, isDark,
                      maxLines: 5),
                ],
                isDark),

            const SizedBox(height: 20),

            _buildFormSection(
                "Categorization",
                [
                  Text("Type / Category",
                      style: GoogleFonts.poppins(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 12)),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 15),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E293B) : Colors.white,
                      borderRadius: BorderRadius.circular(15),
                      border: Border.all(
                          color: isDark
                              ? const Color(0xFF334155)
                              : Colors.grey.shade300),
                    ),
                    child: DropdownButtonHideUnderline(
                      child: DropdownButton<AnnouncementType>(
                        value: _selectedType,
                        dropdownColor:
                            isDark ? const Color(0xFF1E293B) : Colors.white,
                        isExpanded: true,
                        items: AnnouncementType.values
                            .map((e) => DropdownMenuItem(
                                  value: e,
                                  child: Text(
                                      e
                                          .toString()
                                          .split('.')
                                          .last
                                          .toUpperCase(),
                                      style: TextStyle(
                                          color: isDark
                                              ? Colors.white
                                              : Colors.black)),
                                ))
                            .toList(),
                        onChanged: (val) =>
                            setState(() => _selectedType = val!),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text("Priority",
                      style: GoogleFonts.poppins(
                          color: isDark ? Colors.white70 : Colors.black54,
                          fontSize: 12)),
                  const SizedBox(height: 8),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: AnnouncementPriority.values.map((p) {
                      final isSelected = _selectedPriority == p;
                      Color color;
                      switch (p) {
                        case AnnouncementPriority.urgent:
                          color = Colors.red;
                          break;
                        case AnnouncementPriority.important:
                          color = Colors.orange;
                          break;
                        default:
                          color = Colors.blue;
                      }
                      return GestureDetector(
                        onTap: () => setState(() => _selectedPriority = p),
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? color.withValues(alpha: 0.2)
                                : Colors.transparent,
                            border: Border.all(
                                color: isSelected ? color : Colors.grey),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                              p.toString().split('.').last.toUpperCase(),
                              style: TextStyle(
                                  color: isSelected ? color : Colors.grey,
                                  fontWeight: FontWeight.bold)),
                        ),
                      );
                    }).toList(),
                  )
                ],
                isDark),

            const SizedBox(height: 20),

            _buildFormSection(
                "Target Audience",
                [
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: _audienceOptions.map((role) {
                      final isSelected = _selectedAudience.contains(role);
                      return FilterChip(
                        label: Text(role),
                        selected: isSelected,
                        onSelected: (val) {
                          setState(() {
                            if (role == 'All') {
                              if (val) {
                                _selectedAudience.clear();
                                _selectedAudience.add(role);
                              } else {
                                _selectedAudience.remove(role);
                              }
                            } else {
                              _selectedAudience.remove('All');
                              if (val)
                                _selectedAudience.add(role);
                              else
                                _selectedAudience.remove(role);
                            }
                          });
                        },
                        backgroundColor:
                            isDark ? const Color(0xFF1E293B) : Colors.white,
                        selectedColor: const Color(0xFF2563EB),
                        labelStyle: TextStyle(
                            color: isSelected
                                ? Colors.white
                                : (isDark ? Colors.white70 : Colors.black87)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                              color: isSelected
                                  ? Colors.transparent
                                  : Colors.grey.withValues(alpha: 0.3)),
                        ),
                      );
                    }).toList(),
                  ),
                  if (_selectedAudience.contains('Students')) ...[
                     const SizedBox(height: 15),
                     Row(
                       children: [
                         _buildMultiSelectDropdown("Branches", _departments, _selectedBranches, (val) => setState(() => _selectedBranches = val), isDark),
                         const SizedBox(width: 10),
                         _buildMultiSelectDropdown("Years", _years, _selectedYears, (val) => setState(() => _selectedYears = val), isDark),
                         const SizedBox(width: 10),
                         _buildMultiSelectDropdown("Sections", _sections, _selectedSections, (val) => setState(() => _selectedSections = val), isDark),
                       ],
                     ),
                  ]
                ],
                isDark),

            const SizedBox(height: 20),

            _buildFormSection(
                "Schedule",
                [
                  Row(
                    children: [
                      Expanded(
                          child: _buildDateTimePicker("Start Date", _startDate,
                              (d) => setState(() => _startDate = d), isDark)),
                      const SizedBox(width: 10),
                      Expanded(
                          child: _buildTimePicker("Start Time", _startTime,
                              (t) => setState(() => _startTime = t), isDark)),
                    ],
                  ),
                  const SizedBox(height: 15),
                  _buildDateTimePicker("Expiry Date (Auto-hide)", _endDate,
                      (d) => setState(() => _endDate = d), isDark),
                ],
                isDark),

            const SizedBox(height: 20),


            _buildFormSection(
                "Notifications",
                [
                  SwitchListTile(
                    title: Text("Send Push Notification",
                        style: GoogleFonts.poppins(
                            color: isDark ? Colors.white : Colors.black)),
                    value: _sendPush,
                    onChanged: (v) => setState(() => _sendPush = v),
                    activeColor: Colors.cyan,
                  ),
                  SwitchListTile(
                    title: Text("Show In-App Alert",
                        style: GoogleFonts.poppins(
                            color: isDark ? Colors.white : Colors.black)),
                    value: _sendInApp,
                    onChanged: (v) => setState(() => _sendInApp = v),
                    activeColor: Colors.cyan,
                  ),
                ],
                isDark),

            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildFormSection(String title, List<Widget> children, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(),
            style: GoogleFonts.poppins(
                color: Colors.grey,
                fontSize: 12,
                fontWeight: FontWeight.bold,
                letterSpacing: 1.2)),
        const SizedBox(height: 10),
        ...children,
      ],
    );
  }

  Widget _buildTextField(
      String label, TextEditingController controller, bool isDark,
      {int maxLines = 1}) {
    return TextField(
      controller: controller,
      maxLines: maxLines,
      style: TextStyle(color: isDark ? Colors.white : Colors.black),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: TextStyle(color: Colors.grey),
        filled: true,
        fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: BorderSide.none),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(15),
            borderSide: const BorderSide(color: Colors.blueAccent)),
      ),
    );
  }

  Widget _buildDateTimePicker(String label, DateTime current,
      Function(DateTime) onChange, bool isDark) {
    return GestureDetector(
      onTap: () async {
        final d = await showDatePicker(
            context: context,
            initialDate: current,
            firstDate: DateTime.now(),
            lastDate: DateTime(2030));
        if (d != null) onChange(d);
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(15)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 5),
            Text(DateFormat('MMM dd, yyyy').format(current),
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold))
          ],
        ),
      ),
    );
  }

  Widget _buildTimePicker(String label, TimeOfDay current,
      Function(TimeOfDay) onChange, bool isDark) {
    return GestureDetector(
      onTap: () async {
        final t = await showTimePicker(context: context, initialTime: current);
        if (t != null) onChange(t);
      },
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(15)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: const TextStyle(fontSize: 10, color: Colors.grey)),
            const SizedBox(height: 5),
            Text(current.format(context),
                style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontWeight: FontWeight.bold))
          ],
        ),
      ),
    );
  }

  Widget _buildLivePreviewCard(bool isDark) {
    final themeData = AnnouncementThemeHelper.getTheme(
        _selectedType.toString().split('.').last, isDark);

    Color typeColorStart = themeData.cardGradient.first;
    Color typeColorEnd = themeData.cardGradient.last;
    IconData typeIcon = themeData.typeIcon;

    final dt = DateTime(_startDate.year, _startDate.month, _startDate.day,
        _startTime.hour, _startTime.minute);
    final daysLeft = dt.difference(DateTime.now()).inDays;
    String daysLeftStr = daysLeft == 0 ? "Today" : "$daysLeft days left";
    if (daysLeft < 0) daysLeftStr = "Expired";

    // Determine text color for 'days left' based on urgency, but ensure visibility on colored bg
    // On a colored gradient, white is usually best.
    Color remainingColor = Colors.white;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () {
          setState(() {
            final values = AnnouncementType.values;
            final nextIndex =
                (values.indexOf(_selectedType) + 1) % values.length;
            _selectedType = values[nextIndex];
          });
        },
        child: Container(
          width: double.infinity,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [typeColorStart, typeColorEnd],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: typeColorStart.withValues(alpha: 0.3),
                blurRadius: 15,
                offset: const Offset(0, 8),
              )
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(20),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(
                                  alpha: 0.2), // Semi-transparent white
                              shape: BoxShape.circle,
                            ),
                            child:
                                Icon(typeIcon, color: Colors.white, size: 22),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  _titleController.text.isEmpty
                                      ? "Announcement Title"
                                      : _titleController.text,
                                  style: GoogleFonts.poppins(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  _selectedAudience.isEmpty
                                      ? "Target Audience"
                                      : (() {
                                          List<String> previewAudience = List.from(_selectedAudience);
                                          if (previewAudience.contains('Students')) {
                                               if (_selectedBranches.isNotEmpty) previewAudience.add("(${_selectedBranches.take(2).join(',')}${_selectedBranches.length > 2 ? '...' : ''})");
                                               if (_selectedYears.isNotEmpty) previewAudience.add("(${_selectedYears.take(2).join(',')}${_selectedYears.length > 2 ? '...' : ''})");
                                          }
                                          return previewAudience.join(", ");
                                        })(),
                                  style: GoogleFonts.poppins(
                                      color: Colors.white70, fontSize: 13),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const SizedBox(width: 10),
                              const Icon(Icons.calendar_today_outlined,
                                  size: 14, color: Colors.white70),
                              const SizedBox(width: 5),
                              Text(
                                DateFormat('EEE, MMM d, yyyy')
                                    .format(_startDate),
                                style: GoogleFonts.poppins(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                          Text(
                            "${_startTime.format(context)} • $daysLeftStr",
                            style: GoogleFonts.poppins(
                                color: remainingColor,
                                fontSize: 12,
                                fontWeight: FontWeight.w500),
                          )
                        ],
                      )
                    ],
                  ),
                ),
                if (_selectedPriority == AnnouncementPriority.urgent)
                  Positioned(
                    top: 12,
                    right: 12,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text('URGENT',
                          style: GoogleFonts.poppins(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold)),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildMultiSelectDropdown(String title, List<String> options, List<String> selectedItems, Function(List<String>) onChanged, bool isDark) {
     return Expanded(
       child: GestureDetector(
         onTap: () async {
            if (options.isEmpty) return;
            final result = await showDialog<List<String>>(
               context: context,
               builder: (ctx) {
                  List<String> tempSelected = List.from(selectedItems);
                  return StatefulBuilder(
                    builder: (context, setDialogState) {
                       return AlertDialog(
                          backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                          title: Text('Select $title', style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.bold)),
                          content: SizedBox(
                             width: double.maxFinite,
                             child: ListView(
                                shrinkWrap: true,
                                children: options.map((opt) {
                                   return CheckboxListTile(
                                      title: Text(opt, style: TextStyle(color: isDark ? Colors.white : Colors.black, fontSize: 14)),
                                      value: tempSelected.contains(opt),
                                      activeColor: const Color(0xFF2563EB),
                                      checkColor: Colors.white,
                                      controlAffinity: ListTileControlAffinity.leading,
                                      onChanged: (val) {
                                         setDialogState(() {
                                            if (val == true) {
                                               tempSelected.add(opt);
                                            } else {
                                               tempSelected.remove(opt);
                                            }
                                         });
                                      }
                                   );
                                }).toList()
                             )
                          ),
                          actions: [
                             TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                             ElevatedButton(
                                onPressed: () => Navigator.pop(ctx, tempSelected), 
                                style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF2563EB)),
                                child: const Text('Confirm', style: TextStyle(color: Colors.white))
                             ),
                          ]
                       );
                    }
                  );
               }
            );
            if (result != null) {
               onChanged(result);
            }
         },
         child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 12),
            decoration: BoxDecoration(
               color: isDark ? const Color(0xFF1E293B) : Colors.white,
               borderRadius: BorderRadius.circular(10),
               border: Border.all(color: Colors.grey.withValues(alpha: 0.3)),
            ),
            child: Row(
               mainAxisAlignment: MainAxisAlignment.spaceBetween,
               children: [
                  Expanded(
                    child: Text(
                      selectedItems.isEmpty ? title : '${selectedItems.length} selected', 
                      overflow: TextOverflow.ellipsis, 
                      style: TextStyle(color: isDark ? Colors.white70 : Colors.black87, fontSize: 12)
                    )
                  ),
                  const Icon(Icons.arrow_drop_down, color: Colors.grey, size: 16)
               ]
            )
         )
       )
     );
  }
}
