import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';

class PrincipalMasterTimetableScreen extends StatefulWidget {
  const PrincipalMasterTimetableScreen({super.key});

  @override
  State<PrincipalMasterTimetableScreen> createState() => _PrincipalMasterTimetableScreenState();
}

class _PrincipalMasterTimetableScreenState extends State<PrincipalMasterTimetableScreen> {
  String _selectedBranch = 'Computer Engineering';

  final List<String> _branches = [
    'Computer Engineering', 
    'Civil Engineering', 
    'Mechanical Engineering', 
    'Electronics and Communication Engineering',
    'Electrical and Electronics Engineering',
    'Basic Sciences & Humanities'
  ];
  
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
        title: Text("Global Master Timetable", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
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
                child: Column(
                  children: [
                    _buildDropdown(
                      "Select Branch", 
                      _selectedBranch, 
                      _branches, 
                      (val) => setState(() => _selectedBranch = val!), 
                      isDark ? const Color(0xFF1E1E1E) : Colors.white, // Opaque Background
                      textColor, 
                      subTextColor, 
                      iconBg
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  padding: const EdgeInsets.all(30),
                  decoration: BoxDecoration(
                    color: cardColor,
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: iconBg),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.table_view_outlined, size: 60, color: tint.withValues(alpha: 0.5)),
                      const SizedBox(height: 20),
                      Text("Timetable Ready", style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 8),
                      Text(
                        "Viewing Master Table for $_selectedBranch",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(color: subTextColor, fontSize: 13),
                      ),
                      const SizedBox(height: 30),
                      ElevatedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.visibility),
                        label: const Text("View Full Table"),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: tint,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 15),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          elevation: 0,
                        ),
                      ),
                      const SizedBox(height: 15),
                      TextButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.download, size: 18),
                        label: const Text("Download PDF"),
                        style: TextButton.styleFrom(foregroundColor: subTextColor),
                      )
                    ],
                  ),
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
