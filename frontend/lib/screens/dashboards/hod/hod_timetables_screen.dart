import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/services/auth_service.dart';
import 'hod_class_timetable_screen.dart'; // New Screen
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/api_constants.dart';

// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------
// ---------------------------------------------------------------------------
// Data models
// ---------------------------------------------------------------------------
class SectionData {
  String branch;
  String label;
  String type;
  bool isPinned;

  SectionData({
    required this.branch, 
    required this.label, 
    this.type = 'class',
    this.isPinned = false,
  });
}

class YearData {
  String name;
  List<SectionData> sections;
  bool isPinned;

  YearData({
    required this.name, 
    required this.sections,
    this.isPinned = false,
  });
}

// ---------------------------------------------------------------------------
// Timetables screen
// ---------------------------------------------------------------------------
class HodTimetablesScreen extends StatefulWidget {
  const HodTimetablesScreen({super.key});

  @override
  _HodTimetablesScreenState createState() => _HodTimetablesScreenState();
}

enum TimetableView { main, labs, classes, sections, master }

class _HodTimetablesScreenState extends State<HodTimetablesScreen> {
  // Navigation State
  TimetableView _currentView = TimetableView.main;
  YearData? _selectedYearForSections;

  // Data
  String? _userBranch;
  
  // Labs Data
  List<Map<String, String>> _labs = [];
  
  // Classes Data
  List<YearData> _years = [];
  bool _isLoading = false;

  // Modals
  bool _addModalVisible = false;
  final TextEditingController _addController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserBranch();
  }

  Future<void> _loadUserBranch() async {
    final user = await AuthService.getUserSession();
    if (user != null && user['branch'] != null) {
      if (mounted) {
        setState(() {
          _userBranch = user['branch'];
        });
        await _initData();
      }
    }
  }

  Future<void> _initData() async {
    if (_userBranch == null) return;
    
    setState(() => _isLoading = true);

    // Default Labs
    _labs = [
      {'name': 'Computer Lab 1', 'branch': _userBranch!},
    ];

    // Fetch Years and Sections dynamically
    List<String> yearNames = ['1st Year', '2nd Year', '3rd Year'];
    List<YearData> loadedYears = [];

    for (String yearName in yearNames) {
      List<SectionData> sectionsForYear = [];
      try {
        final url = Uri.parse('${ApiConstants.baseUrl}/api/sections?branch=${Uri.encodeComponent(_userBranch!)}&year=${Uri.encodeComponent(yearName)}');
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          final List<dynamic> fetched = json.decode(response.body);
          if (fetched.isNotEmpty) {
            for (var sec in fetched) {
               sectionsForYear.add(SectionData(branch: _userBranch!, label: sec.toString()));
            }
          } else {
             sectionsForYear.add(SectionData(branch: _userBranch!, label: 'Section A'));
          }
        } else {
           sectionsForYear.add(SectionData(branch: _userBranch!, label: 'Section A'));
        }
      } catch (e) {
        debugPrint("Error fetching sections for $yearName: $e");
        sectionsForYear.add(SectionData(branch: _userBranch!, label: 'Section A'));
      }
      loadedYears.add(YearData(name: yearName, sections: sectionsForYear));
    }

    if (mounted) {
      setState(() {
        _years = loadedYears;
        _isLoading = false;
      });
    }
  }

  // ---------------------------------------------------------------------------
  // Handlers
  // ---------------------------------------------------------------------------

  void _navigateBack() {
    if (_currentView == TimetableView.sections) {
      setState(() => _currentView = TimetableView.classes);
    } else if (_currentView != TimetableView.main) {
      setState(() => _currentView = TimetableView.main);
    }
  }

  void _addLab() {
    if (_addController.text.trim().isEmpty) return;
    setState(() {
      _labs.add({'name': _addController.text.trim(), 'branch': _userBranch!});
      _addModalVisible = false;
      _addController.clear();
    });
  }

  // _addSection removed as management is moved to Department page

  void _openTimetable(String title, String subtitle) {
     Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HodClassTimetableScreen(
          branch: _userBranch ?? '',
          year: title,
          section: subtitle,
        ),
      ),
    );
  }

  void _togglePinYear(YearData year) {
    setState(() {
      year.isPinned = !year.isPinned;
      _sortYears();
    });
  }

  void _togglePinSection(SectionData section) {
    setState(() {
      section.isPinned = !section.isPinned;
      // Triggers rebuild which sorts due to helper logic or manual sort here if needed
      // Sections are sorted in build view, so setState is enough
    });
  }

  void _deleteSection(SectionData section) {
    if (_selectedYearForSections == null) return;
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Section?"),
        content: const Text("This cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedYearForSections!.sections.remove(section);
              });
              Navigator.pop(ctx);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      )
    );
  }

  // _renameSection removed as management is moved to Department page

  void _sortYears() {
    _years.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return a.name.compareTo(b.name);
    });
  }

  // ---------------------------------------------------------------------------
  // Builders
  // ---------------------------------------------------------------------------

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? ThemeColors.darkBackground : ThemeColors.lightBackground;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;

    // Determine Title based on View
    String title = 'Timetables';
    if (_currentView == TimetableView.labs) title = 'Labs';
    if (_currentView == TimetableView.classes) title = 'Classes';
    if (_currentView == TimetableView.master) title = 'Master Timetable';
    if (_currentView == TimetableView.sections) title = '${_selectedYearForSections?.name ?? ''} Sections';

    return PopScope(
      canPop: _currentView == TimetableView.main,
      onPopInvoked: (didPop) {
        if (didPop) return;
        _navigateBack();
      },
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
          backgroundColor: Colors.transparent,
          elevation: 0,
          leading: _currentView != TimetableView.main 
            ? IconButton(icon: Icon(Icons.arrow_back, color: textColor), onPressed: _navigateBack)
            : IconButton(icon: Icon(Icons.arrow_back, color: textColor), onPressed: () => Navigator.pop(context)),
          centerTitle: true,
          actions: [
            // Add Button specific to view (Labs Only)
            if (_addModalVisible == false && _currentView == TimetableView.labs)
              IconButton(
                icon: CircleAvatar(backgroundColor: tint, radius: 14, child: const Icon(Icons.add, color: Colors.white, size: 16)),
                onPressed: () => setState(() => _addModalVisible = true),
              )
          ],
        ),
        body: Container(
          decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
          child: SafeArea(
            child: _buildBody(context),
          ),
        ),
        bottomSheet: _addModalVisible ? _buildAddModal(context) : null,
      ),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_isLoading || _userBranch == null) return const Center(child: CircularProgressIndicator());

    switch (_currentView) {
      case TimetableView.main:
        return _buildMainView(context);
      case TimetableView.labs:
        return _buildLabsView(context);
      case TimetableView.classes:
        return _buildClassesView(context);
      case TimetableView.sections:
        return _buildSectionsView(context);
      case TimetableView.master:
        return _buildMasterView(context);
    }
  }

  // 1. Main View (Three Cards)
  Widget _buildMainView(BuildContext context) {
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _buildBigCard(context, "Classes", Icons.class_, Colors.blue, () => setState(() => _currentView = TimetableView.classes)),
            const SizedBox(height: 20),
            _buildBigCard(context, "Labs", Icons.science, Colors.orange, () => setState(() => _currentView = TimetableView.labs)),
            const SizedBox(height: 20),
            _buildBigCard(context, "Master Timetable", Icons.grid_view_rounded, Colors.purple, () => setState(() => _currentView = TimetableView.master)),
          ],
        ),
      ),
    );
  }

  Widget _buildBigCard(BuildContext context, String title, IconData icon, Color color, VoidCallback onTap) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        height: 160,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: color.withValues(alpha: 0.2), blurRadius: 15, offset: const Offset(0, 5))],
          border: Border.all(color: color.withValues(alpha: 0.3), width: 1.5),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: color.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(icon, size: 40, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }

  // 2. Classes View (List Years with Pinning)
  Widget _buildClassesView(BuildContext context) {
    // Sort logic
    final sortedYears = List<YearData>.from(_years);
    sortedYears.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return a.name.compareTo(b.name);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sortedYears.length,
      itemBuilder: (ctx, index) {
        final year = sortedYears[index];
        return _buildListItem(
          context, 
          year.name, 
          "${year.sections.length} Sections Active", 
          Icons.calendar_today,
          () {
            setState(() {
              _selectedYearForSections = year;
              _currentView = TimetableView.sections;
            });
          },
          isPinned: year.isPinned,
          onPin: () => _togglePinYear(year),
        );
      },
    );
  }

  // 3. Sections View (List Sections with Pin/Delete)
  Widget _buildSectionsView(BuildContext context) {
    final sections = _selectedYearForSections?.sections ?? [];
    
    // Sort logic
    final sortedSections = List<SectionData>.from(sections);
    sortedSections.sort((a, b) {
      if (a.isPinned && !b.isPinned) return -1;
      if (!a.isPinned && b.isPinned) return 1;
      return a.label.compareTo(b.label);
    });

    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: sortedSections.length,
      itemBuilder: (ctx, index) {
        final section = sortedSections[index];
        return _buildListItem(
          context, 
          section.label, // Just label, no "Section " prefix
          "${section.branch} - Class Timetable", 
          Icons.people_alt_outlined,
          () => _openTimetable(_selectedYearForSections!.name, section.label),
          isPinned: section.isPinned,
          onPin: () => _togglePinSection(section),
          // onEdit: () => _renameSection(section), // Managed by Dept Page
          // onDelete: () => _deleteSection(section), // Managed by Dept Page
        );
      },
    );
  }

  // 4. Labs View (List Labs)
  Widget _buildLabsView(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _labs.length,
      itemBuilder: (ctx, index) {
        final lab = _labs[index];
        return _buildListItem(
          context, 
          lab['name']!, 
          "Lab Timetable", 
          Icons.science_outlined,
          () => _openTimetable("Lab", lab['name']!)
        );
      },
    );
  }

  // 5. Master View
  Widget _buildMasterView(BuildContext context) {
    return ListView.builder(
      padding: const EdgeInsets.all(20),
      itemCount: _years.length,
      itemBuilder: (ctx, index) {
        final year = _years[index];
        return _buildListItem(
          context, 
          "Master Timetable - ${year.name}", 
          "Consolidated View", 
          Icons.grid_on,
          () => _openTimetable(year.name, "All Sections")
        );
      },
    );
  }

  // Reusable List Item with Actions
  Widget _buildListItem(
    BuildContext context, 
    String title, 
    String subtitle, 
    IconData icon, 
    VoidCallback onTap, 
    {bool isPinned = false, VoidCallback? onPin, VoidCallback? onEdit, VoidCallback? onDelete}
  ) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black87;
    final primary = Theme.of(context).primaryColor;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10)],
          border: isPinned ? Border.all(color: primary, width: 2) : null,
        ),
        child: Row(
          children: [
            Icon(icon, color: primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                  Text(subtitle, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: isDark ? Colors.white70 : Colors.black54),
              onSelected: (value) {
                if (value == 'pin' && onPin != null) onPin();
                if (value == 'rename' && onEdit != null) onEdit();
                if (value == 'delete' && onDelete != null) onDelete();
              },
              itemBuilder: (BuildContext context) {
                return [
                  if (onPin != null)
                    PopupMenuItem<String>(
                      value: 'pin',
                      child: Row(
                        children: [
                          Icon(isPinned ? Icons.push_pin_outlined : Icons.push_pin, color: primary, size: 20),
                          const SizedBox(width: 10),
                          Text(isPinned ? "Unpin" : "Pin"),
                        ],
                      ),
                    ),
                  if (onEdit != null)
                    const PopupMenuItem<String>(
                      value: 'rename',
                      child: Row(
                        children: [
                          Icon(Icons.edit_outlined, color: Colors.blue, size: 20),
                          SizedBox(width: 10),
                          Text("Rename"),
                        ],
                      ),
                    ),
                  if (onDelete != null)
                    const PopupMenuItem<String>(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(Icons.delete_outline, color: Colors.red, size: 20),
                          SizedBox(width: 10),
                          Text("Delete"),
                        ],
                      ),
                    ),
                ];
              },
            ),
          ],
        ),
      ),
    );
  }

  // Add Modal
  Widget _buildAddModal(BuildContext context) {
    final isLab = _currentView == TimetableView.labs;
    if (!isLab) return const SizedBox.shrink(); // Should not happen given appBar logic
    
    final title = "Add New Lab";
    final hint = "Lab Name (e.g. Physics Lab)";

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 20)],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          TextField(
            controller: _addController,
            autofocus: true,
            decoration: InputDecoration(
              labelText: hint,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _addLab,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: const Text("Add"),
          ),
          const SizedBox(height: 10), // Padding for keyboard
        ],
      ),
    );
  }
}
