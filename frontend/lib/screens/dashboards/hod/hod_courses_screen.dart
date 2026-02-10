import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../data/courses_data.dart';
import 'hod_lesson_plan_screen.dart';

class HodCoursesScreen extends StatefulWidget {
  const HodCoursesScreen({super.key});

  @override
  _HodCoursesScreenState createState() => _HodCoursesScreenState();
}

class _HodCoursesScreenState extends State<HodCoursesScreen> {
  List<dynamic> _mySubjects = [];
  bool _loading = true;
  bool _isSelectMode = false;
  final Set<String> _selectedForDelete = {};
  
  // Search state
  final String _searchQuery = "";
  List<dynamic> _allCourses = [];

  @override
  void initState() {
    super.initState();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    final courses = await CoursesData.getAllCourses();
    if (mounted) {
      setState(() {
        _allCourses = courses;
      });
    }
    _fetchMySubjects();
  }

  Future<void> _fetchMySubjects() async {
    final user = await AuthService.getUserSession();
    if (user == null) return;

    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/faculty/subjects?userId=${user['id']}'),
      );
      if (response.statusCode == 200) {
        setState(() {
          _mySubjects = json.decode(response.body);
          _loading = false;
        });
      } else {
        setState(() => _loading = false);
      }
    } catch (e) {
      print("Error fetching subjects: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  void _toggleDeleteSelection(String id) {
    setState(() {
      if (_selectedForDelete.contains(id)) {
        _selectedForDelete.remove(id);
      } else {
        _selectedForDelete.add(id);
      }
    });
  }

  Future<void> _confirmDelete() async {
    if (_selectedForDelete.isEmpty) {
      setState(() => _isSelectMode = false);
      return;
    }

    bool? confirm = await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Remove Subjects"),
        content: Text("Are you sure you want to remove ${_selectedForDelete.length} subject(s)?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Remove", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    final user = await AuthService.getUserSession();
    if (user == null) return;

    try {
      for (String id in _selectedForDelete) {
        await http.delete(
          Uri.parse('${ApiConstants.baseUrl}/api/faculty/subjects'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({'userId': user['id'], 'subjectId': id}),
        );
      }
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Subjects removed successfully.")));
      _fetchMySubjects();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network error.")));
    } finally {
      setState(() {
        _isSelectMode = false;
        _selectedForDelete.clear();
      });
    }
  }

  void _openAddModal() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _AddSubjectModal(
        allCourses: _allCourses,
        currentSubjects: _mySubjects,
        onAdded: _fetchMySubjects,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? ThemeColors.darkBackground : ThemeColors.lightBackground;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(_isSelectMode ? "Selected (${_selectedForDelete.length})" : "My Courses", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        leading: _isSelectMode
            ? TextButton(onPressed: () => setState(() => _isSelectMode = false), child: Text("Cancel", style: TextStyle(color: textColor, fontSize: 13)))
            : null,
        actions: [
          if (!_isSelectMode) ...[
            IconButton(icon: Icon(Icons.add_circle, color: tint, size: 30), onPressed: _openAddModal),
            if (_mySubjects.isNotEmpty)
              IconButton(icon: Icon(Icons.delete_outline, color: textColor), onPressed: () => setState(() => _isSelectMode = true)),
          ] else
            IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: _confirmDelete),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _mySubjects.isEmpty
                  ? _buildEmptyState(subTextColor, tint)
                  : ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _mySubjects.length,
                      itemBuilder: (ctx, index) {
                        final item = _mySubjects[index];
                        return _buildCourseCard(item, cardColor, textColor, subTextColor, tint, iconBg);
                      },
                    ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color subTextColor, Color tint) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          GestureDetector(onTap: _openAddModal, child: Icon(Icons.add_circle, size: 80, color: tint)),
          const SizedBox(height: 20),
          Text("No courses added yet.", style: GoogleFonts.poppins(fontSize: 18, color: subTextColor)),
          Text("Tap the icon to add subjects.", style: GoogleFonts.poppins(fontSize: 14, color: subTextColor)),
        ],
      ),
    );
  }

  Widget _buildCourseCard(dynamic item, Color cardColor, Color textColor, Color subTextColor, Color tint, Color iconBg) {
    final isSelected = _selectedForDelete.contains(item['id']);
    final percentage = item['percentage'] ?? 0;
    final statusTag = item['statusTag'] ?? 'NORMAL';

    Color statusColor = Colors.green;
    if (statusTag == 'LAGGING') statusColor = Colors.red;
    if (statusTag == 'OVERFAST') statusColor = Colors.orange;

    return GestureDetector(
      onTap: () {
        if (_isSelectMode) {
          _toggleDeleteSelection(item['id']);
        } else {
          Navigator.push(context, MaterialPageRoute(builder: (_) => HodLessonPlanScreen(subjectId: item['id'], subjectName: item['name'])));
        }
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: isSelected ? Colors.red : iconBg, width: isSelected ? 2 : 1),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(color: tint.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                  child: Text(item['code'] ?? item['id'], style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: tint)),
                ),
                if (_isSelectMode)
                  Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank, color: isSelected ? Colors.red : subTextColor)
                else
                  Row(
                    children: [
                      Text(statusTag, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: statusColor)),
                      const SizedBox(width: 10),
                      Stack(
                        alignment: Alignment.center,
                        children: [
                          SizedBox(width: 35, height: 35, child: CircularProgressIndicator(value: percentage / 100, strokeWidth: 3, backgroundColor: statusColor.withOpacity(0.2), valueColor: AlwaysStoppedAnimation(statusColor))),
                          Text("$percentage%", style: GoogleFonts.poppins(fontSize: 9, fontWeight: FontWeight.bold, color: statusColor)),
                        ],
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(item['name'], style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: textColor)),
            const SizedBox(height: 12),
            Row(
              children: [
                _buildTag(item['branch'], tint.withOpacity(0.1), tint),
                _buildTag(item['semester'], Colors.purple.withOpacity(0.1), Colors.purple),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTag(String label, Color bg, Color text) {
    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: GoogleFonts.poppins(fontSize: 11, fontWeight: FontWeight.w600, color: text)),
    );
  }
}

class _AddSubjectModal extends StatefulWidget {
  final List<dynamic> allCourses;
  final List<dynamic> currentSubjects;
  final VoidCallback onAdded;

  const _AddSubjectModal({required this.allCourses, required this.currentSubjects, required this.onAdded});

  @override
  __AddSubjectModalState createState() => __AddSubjectModalState();
}

class __AddSubjectModalState extends State<_AddSubjectModal> {
  String _searchQuery = "";
  final Set<String> _selectedIds = {};
  bool _submitting = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF1C1C1E) : Colors.white;
    final textColor = isDark ? Colors.white : Colors.black;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;

    final filtered = widget.allCourses.where((c) {
      final q = _searchQuery.toLowerCase();
      return c['name'].toLowerCase().contains(q) || c['code'].toLowerCase().contains(q) || c['branch'].toLowerCase().contains(q);
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.red))),
                Text("Add Subjects", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                TextButton(
                  onPressed: _selectedIds.isEmpty || _submitting ? null : _handleAdd,
                  child: Text(_submitting ? "..." : "Done (${_selectedIds.length})", style: TextStyle(color: _selectedIds.isEmpty ? subTextColor : tint, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
          // Search
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration: BoxDecoration(color: isDark ? Colors.white10 : Colors.black.withOpacity(0.05), borderRadius: BorderRadius.circular(12)),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                style: TextStyle(color: textColor),
                decoration: InputDecoration(icon: Icon(Icons.search, color: subTextColor), hintText: "Search subjects...", hintStyle: TextStyle(color: subTextColor), border: InputBorder.none),
              ),
            ),
          ),
          const SizedBox(height: 10),
          // List
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              itemCount: filtered.length,
              itemBuilder: (ctx, index) {
                final item = filtered[index];
                final isAdded = widget.currentSubjects.any((s) => s['id'] == item['id']);
                final isSelected = _selectedIds.contains(item['id']);

                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("${item['code']} - ${item['name']}", style: TextStyle(color: isAdded ? subTextColor : textColor, fontWeight: FontWeight.w600)),
                  subtitle: Text("${item['branch']} • ${item['semester']}", style: TextStyle(color: subTextColor, fontSize: 12)),
                  trailing: isAdded
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : Icon(isSelected ? Icons.check_box : Icons.check_box_outline_blank, color: isSelected ? tint : subTextColor),
                  onTap: isAdded
                      ? null
                      : () {
                          setState(() {
                            if (isSelected) {
                              _selectedIds.remove(item['id']);
                            } else {
                              _selectedIds.add(item['id']);
                            }
                          });
                        },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleAdd() async {
    final user = await AuthService.getUserSession();
    if (user == null) return;

    setState(() => _submitting = true);
    try {
      for (String id in _selectedIds) {
        final subject = widget.allCourses.firstWhere((c) => c['id'] == id);
        await http.post(
          Uri.parse('${ApiConstants.baseUrl}/api/faculty/subjects'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'userId': user['id'],
            'subjectId': id,
            'subjectName': subject['name'],
            'branch': subject['branch'],
          }),
        );
      }
      widget.onAdded();
      if (mounted) Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Failed to add subjects.")));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }
}
