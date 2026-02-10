import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../hod/hod_class_timetable_screen.dart';

class PrincipalLabsScreen extends StatefulWidget {
  const PrincipalLabsScreen({super.key});

  @override
  State<PrincipalLabsScreen> createState() => _PrincipalLabsScreenState();
}

class _PrincipalLabsScreenState extends State<PrincipalLabsScreen> {
  String _selectedBranch = 'Computer Engineering';
  final List<String> _branches = [
    'Computer Engineering', 
    'Civil Engineering', 
    'Mechanical Engineering', 
    'Electronics and Communication Engineering',
    'Electrical and Electronics Engineering',
    'Basic Sciences & Humanities'
  ];

  // Dummy Data for Labs (Default 1 Lab per branch matches HOD default)
  final Map<String, List<String>> _labsData = {
    'Computer Engineering': ['Computer Lab 1'],
    'Civil Engineering': ['Civil Lab 1'],
    'Mechanical Engineering': ['Mechanical Lab 1'],
    'Electronics and Communication Engineering': ['Electronics Lab 1'],
    'Electrical and Electronics Engineering': ['Electrical Lab 1'],
  };

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? ThemeColors.darkBackground : ThemeColors.lightBackground;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;

    final currentLabs = _labsData[_selectedBranch] ?? ['General Lab 1'];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("College Labs", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
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
