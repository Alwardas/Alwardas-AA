import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import 'hod_syllabus_year_details_screen.dart';

class HodSyllabusYearSelectionScreen extends StatelessWidget {
  final String courseId;
  final String courseName;
  final Map<String, dynamic> userData;

  const HodSyllabusYearSelectionScreen({
    super.key, 
    required this.courseId, 
    required this.courseName,
    required this.userData,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bgColors = isDark 
        ? [const Color(0xFF1a1a2e), const Color(0xFF16213e)] 
        : [const Color(0xFFF8F9FA), Colors.white];

    final years = [
      {'label': '1st Year', 'icon': Icons.looks_one},
      {'label': '2nd Year', 'icon': Icons.looks_two},
      {'label': '3rd Year', 'icon': Icons.looks_3},
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text('Select Year', style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(colors: bgColors, begin: Alignment.topCenter, end: Alignment.bottomCenter),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(courseName, style: GoogleFonts.poppins(fontSize: 16, color: textColor.withValues(alpha: 0.7))),
                    const SizedBox(height: 10),
                    Text("Select Academic Year", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                  ],
                ),
              ),
              Expanded(
                child: GridView.builder(
                  padding: const EdgeInsets.all(20),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 1,
                    childAspectRatio: 3,
                    mainAxisSpacing: 15,
                  ),
                  itemCount: years.length,
                  itemBuilder: (context, index) {
                    final year = years[index];
                    return _buildYearCard(context, year, isDark, textColor);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildYearCard(BuildContext context, Map<String, dynamic> year, bool isDark, Color textColor) {
    final cardColor = isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white;

    return GestureDetector(
      onTap: () {
        Navigator.push(context, MaterialPageRoute(builder: (_) => HodSyllabusYearDetailsScreen(
          courseId: courseId,
          courseName: courseName,
          year: year['label'],
          userData: userData,
        )));
      },
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.blue.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(color: Colors.blue.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 5))
          ]
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.blue.withValues(alpha: 0.1), shape: BoxShape.circle),
              child: Icon(year['icon'] as IconData, color: Colors.blue, size: 28),
            ),
            const SizedBox(width: 20),
            Text(
              year['label'] as String,
              style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
            ),
            const Spacer(),
            Icon(Icons.arrow_forward_ios, size: 16, color: textColor.withValues(alpha: 0.5)),
          ],
        ),
      ),
    );
  }
}
