import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/api_constants.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../hod/hod_class_timetable_screen.dart';

class PrincipalLabsScreen extends StatefulWidget {
  const PrincipalLabsScreen({super.key});

  @override
  State<PrincipalLabsScreen> createState() => _PrincipalLabsScreenState();
}

class _PrincipalLabsScreenState extends State<PrincipalLabsScreen> {
  String _selectedBranch = 'Basic Science & Humanities';
  List<String> _branches = ['Basic Science & Humanities'];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchBranches();
  }

  Future<void> _fetchBranches() async {
    try {
      final res = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/departments'));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _branches = ['Basic Science & Humanities'];
            _branches.addAll(data.map((d) => d['name']?.toString() ?? d['branch']?.toString() ?? '').where((b) => b.isNotEmpty).toList());
            _isLoading = false;
          });
        }
      } else {
         _fallbackBranches();
      }
    } catch (e) {
      _fallbackBranches();
    }
  }

  void _fallbackBranches() {
    if (!mounted) return;
    setState(() {
      _branches = [
        'Basic Science & Humanities',
        'Computer Engineering', 
        'Civil Engineering', 
        'Mechanical Engineering', 
        'Electronics and Communication Engineering',
        'Electrical and Electronics Engineering'
      ];
      _isLoading = false;
    });
  }

  List<String> get currentLabs {
    if (_selectedBranch == 'Basic Science & Humanities') return ['Physics Lab', 'Chemistry Lab', 'English Comm Lab', 'Basic IT Lab'];
    return ['$_selectedBranch Lab 1'];
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? ThemeColors.darkBackground : ThemeColors.lightBackground;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;



    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("College Labs", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: _isLoading ? const Center(child: CircularProgressIndicator()) : Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: _buildDropdown(
                  "Select Branch", 
                  _selectedBranch, 
                  _branches, 
                  (val) => setState(() => _selectedBranch = val!), 
                  isDark ? const Color(0xFF1E1E1E) : Colors.white, // Opaque Background
                  textColor, 
                  subTextColor, 
                  iconBg
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: currentLabs.length,
                  itemBuilder: (context, index) {
                    final labName = currentLabs[index];
                    return GestureDetector(
                      onTap: () {
                         Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HodClassTimetableScreen(
                              branch: _selectedBranch,
                              year: 'Lab',
                              section: labName, // Passing Lab Name as section/id
                            ),
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 15),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: iconBg),
                        ),
                        child: Row(
                          children: [
                             Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(color: Colors.orange.withValues(alpha: 0.1), shape: BoxShape.circle),
                              child: const Icon(Icons.science, color: Colors.orange),
                            ),
                            const SizedBox(width: 15),
                            Expanded(
                              child: Text(
                                labName, 
                                style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, size: 16, color: subTextColor)
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
    );
  }

  Widget _buildDropdown(String label, String value, List<String> items, ValueChanged<String?> onChanged, Color cardColor, Color textColor, Color subTextColor, Color iconBg) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: subTextColor)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(color: cardColor, borderRadius: BorderRadius.circular(12), border: Border.all(color: iconBg)),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              value: value,
              isExpanded: true,
              dropdownColor: cardColor,
              icon: Icon(Icons.arrow_drop_down, color: subTextColor),
              style: GoogleFonts.poppins(color: textColor, fontSize: 13), // Slightly smaller font to fit long names
              items: items.map((i) => DropdownMenuItem(
                value: i, 
                child: Text(
                  i, 
                  style: TextStyle(color: textColor),
                  overflow: TextOverflow.ellipsis, // Fix overflow issues
                  maxLines: 1,
                )
              )).toList(),
              onChanged: onChanged,
            ),
          ),
        ),
      ],
    );
  }
}
