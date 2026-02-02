import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'principal_faculty_detail_screen.dart';
import '../../../core/models/faculty_model.dart';
import 'package:http/http.dart' as http;
import '../../../core/api_constants.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';


class PrincipalFacultyScreen extends StatefulWidget {
  const PrincipalFacultyScreen({super.key});

  @override
  State<PrincipalFacultyScreen> createState() => _PrincipalFacultyScreenState();
}

class _PrincipalFacultyScreenState extends State<PrincipalFacultyScreen> {
  String _selectedDept = 'All';
  String _searchQuery = '';
  final List<String> _departments = [
    'All', 
    'Computer Engineering', 
    'Civil Engineering', 
    'Mechanical Engineering',
    'Electronics & Communication Engineering',
    'Electrical & Electronics Engineering',
    'General'
  ];

  List<BackendFacultyMember> _facultyList = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFaculty();
  }

  Future<void> _fetchFaculty() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      // Use "All" to get everyone, or the specific branch
      final branchParam = _selectedDept == 'All' ? 'All' : _selectedDept;
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/faculty/by-branch?branch=$branchParam'),
      );

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _facultyList = data.map((json) => BackendFacultyMember.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Failed to load faculty: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error: $e";
        _isLoading = false;
      });
    }
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

    final filteredFaculty = _facultyList.where((f) {
      final matchesSearch = f.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
                           f.branch.toLowerCase().contains(_searchQuery.toLowerCase()) ||
                           f.loginId.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch;
    }).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Faculty Directory", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: textColor),
            onPressed: _fetchFaculty,
          )
        ],
      ),
      body: Container(
        height: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Column(
            children: [
              // Search Bar
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 10),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(16), border: Border.all(color: iconBg)),
                  child: TextField(
                    onChanged: (val) => setState(() => _searchQuery = val),
                    style: TextStyle(color: textColor),
                    decoration: InputDecoration(
                      icon: Icon(Icons.search, color: subTextColor),
                      hintText: "Search faculty...",
                      hintStyle: TextStyle(color: subTextColor),
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              // Department Filter (Horizontal Chips)
              SizedBox(
                height: 50,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 15),
                  itemCount: _departments.length,
                  itemBuilder: (ctx, index) {
                    final dept = _departments[index];
                    final isSelected = _selectedDept == dept;
                    return GestureDetector(
                      onTap: () {
                        if (!isSelected) {
                          setState(() {
                            _selectedDept = dept;
                          });
                          _fetchFaculty();
                        }
                      },
                      child: Container(
                        margin: const EdgeInsets.symmetric(horizontal: 5, vertical: 8),
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        decoration: BoxDecoration(
                          color: isSelected ? tint : Colors.transparent,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: isSelected ? tint : iconBg),
                        ),
                        child: Center(
                          child: Text(
                            dept, 
                            style: TextStyle(color: isSelected ? Colors.white : subTextColor, fontWeight: isSelected ? FontWeight.bold : FontWeight.normal, fontSize: 13)
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              // Faculty List
              Expanded(
                child: _isLoading 
                  ? Center(child: CircularProgressIndicator(color: tint))
                  : _error != null
                    ? Center(child: Padding(
                        padding: const EdgeInsets.all(20.0),
                        child: Text(_error!, style: const TextStyle(color: Colors.red), textAlign: TextAlign.center),
                      ))
                    : filteredFaculty.isEmpty
                      ? Center(child: Text("No faculty found", style: TextStyle(color: subTextColor)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                          itemCount: filteredFaculty.length,
                          itemBuilder: (ctx, index) {
                            final f = filteredFaculty[index];
                            return GestureDetector(
                              onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(builder: (_) => PrincipalFacultyDetailScreen(faculty: f))
                              ),
                              child: _buildFacultyItem(f, cardColor, textColor, subTextColor, tint, iconBg),
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

  Widget _buildFacultyItem(BackendFacultyMember f, Color cardColor, Color textColor, Color subTextColor, Color tint, Color iconBg) {
    bool isHod = f.role == 'HOD';
    // Gold colors for HOD
    final hodBgColor = const Color(0xFFFFF8E1); // Light amber
    final hodBorderColor = const Color(0xFFFFC107); // Amber
    final hodGradient = [const Color(0xFFFFD54F), const Color(0xFFFFB300)]; // Amber 300-600

    return Container(
      margin: const EdgeInsets.only(bottom: 15),
      padding: const EdgeInsets.all(3), // Space for gradient border effect if needed, or simple margin inside
      decoration: BoxDecoration(
        color: isHod ? hodBgColor : cardColor, 
        gradient: isHod ? LinearGradient(colors: [const Color(0xFFFFF8E1), const Color(0xFFFFECB3)]) : null,
        borderRadius: BorderRadius.circular(20),
        border: isHod ? Border.all(color: hodBorderColor, width: 2) : Border.all(color: iconBg),
        boxShadow: [
          if (isHod) 
             BoxShadow(color: Colors.amber.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 4))
          else 
             BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Stack(
              children: [
                CircleAvatar(
                  radius: 28,
                  backgroundColor: isHod ? Colors.white.withOpacity(0.6) : tint.withOpacity(0.1),
                  child: Text(
                    f.name.isNotEmpty ? f.name[0].toUpperCase() : '?', 
                    style: TextStyle(
                      color: isHod ? Colors.amber[900] : tint, 
                      fontWeight: FontWeight.bold, 
                      fontSize: 22
                    )
                  ),
                ),
                if (isHod)
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                        color: Colors.amber, 
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 2)]
                      ),
                      child: const Icon(Icons.star, color: Colors.white, size: 10),
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 15),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          f.name, 
                          style: GoogleFonts.poppins(
                            fontSize: 17, 
                            fontWeight: FontWeight.bold, 
                            color: isHod ? Colors.amber[900] : textColor
                          )
                        )
                      ),
                      if (isHod)
                        Container(
                          margin: const EdgeInsets.only(left: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: Colors.amber[800],
                            borderRadius: BorderRadius.circular(10)
                          ),
                          child: const Text("HOD", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                        )
                    ],
                  ),
                  Text(
                    f.role == 'HOD' ? "Head of Department" : "Faculty Member", 
                    style: GoogleFonts.poppins(
                      fontSize: 13, 
                      color: isHod ? Colors.amber[800] : tint, 
                      fontWeight: FontWeight.w600
                    )
                  ),
                  const SizedBox(height: 2),
                  Text(f.branch, style: GoogleFonts.poppins(fontSize: 12, color: isHod ? Colors.brown[400] : subTextColor)),
                ],
              ),
            ),
            IconButton(
              icon: Icon(Icons.info_outline, color: isHod ? Colors.amber[900] : subTextColor, size: 22),
              onPressed: () => _showFacultyDetails(f),
            ),
          ],
        ),
      ),
    );
  }


  void _showFacultyDetails(BackendFacultyMember faculty) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        final isDark = Theme.of(context).brightness == Brightness.dark;
        return Container(
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E1E1E) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 20),
              Text(faculty.name, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
              Text("Faculty Member", style: GoogleFonts.poppins(fontSize: 16, color: ThemeColors.lightTint, fontWeight: FontWeight.w600)),
              const Divider(height: 32),
              _detailRow(Icons.badge_outlined, "Faculty ID", "ID-${faculty.loginId}"),
              _detailRow(Icons.business, "Department", faculty.branch),
              _detailRow(Icons.work_outline, "Experience", faculty.experience),
              _detailRow(Icons.email_outlined, "Email", faculty.email),
              _detailRow(Icons.phone_outlined, "Phone", faculty.phone),
              const SizedBox(height: 20),
            ],
          ),
        );
      },
    );
  }

  Widget _detailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, size: 20, color: ThemeColors.lightTint),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}
