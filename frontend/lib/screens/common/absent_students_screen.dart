import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../dashboards/hod/hod_student_profile_screen.dart';

class AbsentStudentsScreen extends StatelessWidget {
  final List<dynamic> absents;
  final String title;
  final DateTime? date;

  const AbsentStudentsScreen({
    super.key, 
    required this.absents, 
    required this.title,
    this.date,
  });

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? ThemeColors.darkBackground : ThemeColors.lightBackground;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;
    
    // Group absents by Year/Section if needed, but the user wants a list for screenshot.
    // They asked for smaller card size.

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18, color: textColor)),
            Text(
              "${absents.length} Students Absent • ${DateFormat('dd MMM yyyy').format(date ?? DateTime.now())}", 
              style: GoogleFonts.poppins(fontSize: 12, color: Colors.redAccent, fontWeight: FontWeight.w500)
            ),
          ],
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: const Icon(Icons.share_outlined),
            onPressed: () {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text("Take a screenshot to share the list!"))
               );
            },
          )
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: bgColors, 
            begin: Alignment.topLeft, 
            end: Alignment.bottomRight
          )
        ),
        child: SafeArea(
          child: absents.isEmpty 
          ? _buildEmptyState(textColor, subTextColor)
          : ListView.builder(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              itemCount: absents.length,
              itemBuilder: (context, index) {
                final s = absents[index];
                return _buildSmallStudentCard(context, s, isDark, textColor, subTextColor, cardColor, iconBg);
              },
            ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(Color textColor, Color subTextColor) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.check_circle_outline, size: 64, color: Colors.green.withValues(alpha: 0.5)),
          const SizedBox(height: 16),
          Text("No Absents Today!", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
          Text("All students are present.", style: GoogleFonts.poppins(color: subTextColor)),
        ],
      ),
    );
  }

  Widget _buildSmallStudentCard(BuildContext context, dynamic s, bool isDark, Color textColor, Color subTextColor, Color cardColor, Color iconBg) {
    final name = s['fullName'] ?? s['full_name'] ?? 'Unknown';
    final id = s['studentId'] ?? s['student_id'] ?? '??';
    final branch = s['branch'] ?? '';
    final year = s['year'] ?? '';
    final section = s['section'] ?? '';

    // The user wants a smaller card for easy screenshotting.
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            // Support multiple ID field variations from different APIs
            final userId = s['userId'] ?? s['id'] ?? s['user_id'] ?? s['dbId'];
            final studentId = s['studentId'] ?? s['student_id'] ?? s['loginId'] ?? id;

            if (userId != null) {
              Navigator.push(
                context, 
                MaterialPageRoute(
                  builder: (_) => HodStudentProfileScreen(
                    userId: userId.toString(), 
                    studentId: studentId.toString(), 
                    studentName: name.toString()
                  )
                )
              );
            } else {
               ScaffoldMessenger.of(context).showSnackBar(
                 const SnackBar(content: Text("Profile details unavailable for this student."))
               );
            }
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: iconBg.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                 // Compact ID Avatar
                 Container(
                   width: 32,
                   height: 32,
                   decoration: BoxDecoration(
                     color: Colors.red.withValues(alpha: 0.1),
                     shape: BoxShape.circle,
                   ),
                   alignment: Alignment.center,
                   child: Text(
                     id.toString().length > 3 ? id.toString().substring(id.toString().length - 3) : id.toString().padLeft(3, '0'),
                     style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 10),
                   ),
                 ),
                 const SizedBox(width: 12),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(
                         name, 
                         style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: textColor),
                         maxLines: 1,
                         overflow: TextOverflow.ellipsis,
                       ),
                       Text(
                         "$id • $year $section", 
                         style: GoogleFonts.poppins(fontSize: 10, color: subTextColor),
                       ),
                     ],
                   ),
                 ),
                 Icon(Icons.chevron_right, size: 16, color: subTextColor.withValues(alpha: 0.5)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
