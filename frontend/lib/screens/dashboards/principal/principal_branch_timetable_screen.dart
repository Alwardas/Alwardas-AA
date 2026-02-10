import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../hod/hod_class_timetable_screen.dart'; // Reuse HOD screen

// ---------------------------------------------------------------------------
// Data models (Copied to be self-contained or could be shared)
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
// Principal Branch Timetable Screen
// ---------------------------------------------------------------------------
class PrincipalBranchTimetableScreen extends StatefulWidget {
  final String branch; // Passed from the list
  const PrincipalBranchTimetableScreen({super.key, required this.branch});

  @override
  _PrincipalBranchTimetableScreenState createState() => _PrincipalBranchTimetableScreenState();
}

enum TimetableView { main, labs, classes, sections, master }

class _PrincipalBranchTimetableScreenState extends State<PrincipalBranchTimetableScreen> {
  // Navigation State
  TimetableView _currentView = TimetableView.main;
  YearData? _selectedYearForSections;

  // Labs Data
  List<Map<String, String>> _labs = [];
  
  // Classes Data
  List<YearData> _years = [];

  // Modals
  bool _addModalVisible = false;
  final TextEditingController _addController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initData();
  }

  void _initData() {
    // Default Labs
    _labs = [
      {'name': 'Computer Lab 1', 'branch': widget.branch},
      {'name': 'Physics Lab', 'branch': widget.branch},
      {'name': 'Chemistry Lab', 'branch': widget.branch},
    ];

    // Default Years
    _years = [
      YearData(name: '1st Year', sections: [SectionData(branch: widget.branch, label: 'Section A')]),
      YearData(name: '2nd Year', sections: [SectionData(branch: widget.branch, label: 'Section A')]),
      YearData(name: '3rd Year', sections: [SectionData(branch: widget.branch, label: 'Section A')]),
    ];
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
      _labs.add({'name': _addController.text.trim(), 'branch': widget.branch});
      _addModalVisible = false;
      _addController.clear();
    });
  }

  void _addSection() {
    if (_addController.text.trim().isEmpty || _selectedYearForSections == null) return;
    setState(() {
      _selectedYearForSections!.sections.add(
        SectionData(branch: widget.branch, label: _addController.text.trim(), type: 'class')
      );
      _addModalVisible = false;
      _addController.clear();
    });
  }

  void _openTimetable(String title, String subtitle) {
     Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => HodClassTimetableScreen(
          branch: widget.branch,
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

  void _renameSection(SectionData section) {
    if (_selectedYearForSections == null) return;
    
    final renameController = TextEditingController(text: section.label);
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Rename Section"),
        content: TextField(
          controller: renameController,
          decoration: const InputDecoration(labelText: "New Section Name"),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              if (renameController.text.trim().isNotEmpty) {
                setState(() {
                  section.label = renameController.text.trim();
                });
                Navigator.pop(ctx);
              }
            },
            child: const Text("Rename", style: TextStyle(color: Colors.blue)),
          ),
        ],
      )
    );
  }

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
    String title = widget.branch; // Default
    if (_currentView == TimetableView.main) title = widget.branch;
    if (_currentView == TimetableView.labs) title = 'Labs';
    if (_currentView == TimetableView.classes) title = 'Classes';
    if (_currentView == TimetableView.master) title = 'Master Timetable';
    if (_currentView == TimetableView.sections) title = '${_selectedYearForSections?.name ?? ''} Sections';

    return WillPopScope(
      onWillPop: () async {
        if (_currentView != TimetableView.main) {
          _navigateBack();
          return false;
        }
        return true;
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
            // Add Button specific to view
            if (_addModalVisible == false && (_currentView == TimetableView.labs || _currentView == TimetableView.sections))
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
            Text("Select Category", style: GoogleFonts.poppins(fontSize: 14, color: Colors.grey)),
            const SizedBox(height: 10),
            _buildBigCard(context, "Classes", Icons.class_, Colors.blue, () => setState(() => _currentView = TimetableView.classes)),
            // Labs removed as per user request
            // const SizedBox(height: 20),
            // _buildBigCard(context, "Labs", Icons.science, Colors.orange, () => setState(() => _currentView = TimetableView.labs)),
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
        height: 140, // Slightly smaller than HOD view
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
              child: Icon(icon, size: 36, color: color),
            ),
            const SizedBox(height: 12),
            Text(title, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: isDark ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }

  // 2. Classes View (List Years with Pinning)
  Widget _buildClassesView(BuildContext context) {
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

  // 3. Sections View 
  Widget _buildSectionsView(BuildContext context) {
    final sections = _selectedYearForSections?.sections ?? [];
    
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
          section.label, 
          "${section.branch} - Class Timetable", 
          Icons.people_alt_outlined,
          () => _openTimetable(_selectedYearForSections!.name, section.label),
          isPinned: section.isPinned,
          onPin: () => _togglePinSection(section),
          onEdit: () => _renameSection(section),
          onDelete: () => _deleteSection(section),
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
    final title = isLab ? "Add New Lab" : "Add Section to ${_selectedYearForSections?.name}";
    final hint = isLab ? "Lab Name (e.g. Physics Lab)" : "Section Name (e.g. Section A)";

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
            onPressed: isLab ? _addLab : _addSection,
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
