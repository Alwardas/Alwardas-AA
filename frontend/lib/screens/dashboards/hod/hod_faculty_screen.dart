import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import '../../../core/api_constants.dart'; 
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import 'hod_faculty_detail_screen.dart';

// Note: Reusing the same name as the original data class for compatibility if needed, 
// or simpler, just using maps since the backend returns JSON.
// Or defining a local model.
import '../../../core/models/faculty_model.dart';


class HodFacultyScreen extends StatefulWidget {
  final String branch;
  const HodFacultyScreen({super.key, required this.branch});

  @override
  State<HodFacultyScreen> createState() => _HodFacultyScreenState();
}

class _HodFacultyScreenState extends State<HodFacultyScreen> {
  String _searchQuery = '';
  List<BackendFacultyMember> _facultyList = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetchFaculty();
  }

  Future<void> _fetchFaculty() async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConstants.baseUrl}/api/faculty/by-branch?branch=${widget.branch}'),
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
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;

    final filteredList = _facultyList.where((f) => 
      f.name.toLowerCase().contains(_searchQuery.toLowerCase()) || 
      f.loginId.toLowerCase().contains(_searchQuery.toLowerCase())
    ).toList();

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Our Faculty", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: iconBg),
                  ),
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
              Expanded(
                child: _isLoading 
                  ? Center(child: CircularProgressIndicator(color: tint))
                  : _error != null 
                    ? Center(child: Text(_error!, style: TextStyle(color: Colors.red)))
                    : filteredList.isEmpty
                      ? Center(child: Text("No faculty found", style: TextStyle(color: subTextColor)))
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: filteredList.length,
                          itemBuilder: (ctx, index) {
                            final faculty = filteredList[index];
                            // Faculty Detail Navigation Logic

                            bool isHod = faculty.role == 'HOD';
                            // Gold colors for HOD
                            final hodBgColor = const Color(0xFFFFF8E1); // Light amber
                            final hodBorderColor = const Color(0xFFFFC107); // Amber
                            
                            return GestureDetector(
                              onTap: () {
                                Navigator.push(
                                  context, 
                                  MaterialPageRoute(builder: (_) => HodFacultyDetailScreen(faculty: faculty))
                                );
                              },
                              child: Container(
                                margin: const EdgeInsets.only(bottom: 16),
                                padding: EdgeInsets.all(isHod ? 3 : 16),
                                decoration: BoxDecoration(
                                  color: isHod ? hodBgColor : cardColor,
                                  gradient: isHod ? const LinearGradient(colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)]) : null,
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
                                  padding: isHod ? const EdgeInsets.all(16) : EdgeInsets.zero,
                                  child: Row(
                                    children: [
                                      Stack(
                                        children: [
                                          CircleAvatar(
                                            radius: 30,
                                            backgroundColor: isHod ? Colors.white.withOpacity(0.6) : tint.withOpacity(0.1),
                                            child: Text(
                                              faculty.name.isNotEmpty ? faculty.name[0].toUpperCase() : '?', 
                                              style: TextStyle(
                                                color: isHod ? Colors.amber[900] : tint, 
                                                fontWeight: FontWeight.bold, 
                                                fontSize: 24
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
                                      const SizedBox(width: 16),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Row(
                                              children: [
                                                Expanded(child: Text(faculty.name, style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: isHod ? Colors.amber[900] : textColor))),
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
                                              isHod ? "Head of Department" : "ID-${faculty.loginId}", 
                                              style: GoogleFonts.poppins(
                                                fontSize: 14, 
                                                color: isHod ? Colors.amber[800] : subTextColor,
                                                fontWeight: isHod ? FontWeight.w600 : FontWeight.normal
                                              )
                                            ),
                                            const SizedBox(height: 8),
                                            Row(
                                              children: [
                                                Icon(Icons.email_outlined, size: 14, color: isHod ? Colors.amber[900] : tint),
                                                const SizedBox(width: 4),
                                                Expanded(child: Text(faculty.email, style: TextStyle(fontSize: 12, color: isHod ? Colors.brown[400] : subTextColor), overflow: TextOverflow.ellipsis)),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ),
                                      IconButton(
                                        icon: Icon(Icons.info_outline, color: isHod ? Colors.amber[900] : tint),
                                        onPressed: () => _showFacultyDetails(faculty),
                                      ),
                                    ],
                                  ),
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
    );
  }

  void _showFacultyDetails(BackendFacultyMember faculty) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
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
              Center(
                child: Container(
                  width: 40, height: 4, decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                ),
              ),
              const SizedBox(height: 20),
              Text(faculty.name, style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold)),
              // Designation in modal (User said "exact like demo"). 
              // Since backend doesn't have explicit designation yet, we show "Faculty" or "Professor" if guessed, 
              // but "Faculty" is safer. Or just the Department.
              // Use "Faculty Member" as subtitle.
              Text("Faculty Member", style: GoogleFonts.poppins(fontSize: 16, color: Colors.grey)),
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
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
