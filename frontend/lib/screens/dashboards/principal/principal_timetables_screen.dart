import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import 'principal_branch_timetable_screen.dart';
import 'principal_labs_screen.dart';
import 'principal_master_timetable_screen.dart';

class PrincipalTimetablesScreen extends StatefulWidget {
  const PrincipalTimetablesScreen({super.key});

  @override
  _PrincipalTimetablesScreenState createState() => _PrincipalTimetablesScreenState();
}

class _PrincipalTimetablesScreenState extends State<PrincipalTimetablesScreen> {
  final List<String> branches = [
    "Computer Engineering",
    "Civil Engineering",
    "Mechanical Engineering",
    "Electronics and Communication Engineering",
    "Electrical and Electronics Engineering"
  ];

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? ThemeColors.darkBackground : ThemeColors.lightBackground;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Timetables", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Select Branch", 
                  style: GoogleFonts.poppins(
                    color: subTextColor, 
                    fontSize: 16, 
                    fontWeight: FontWeight.bold
                  )
                ),
                const SizedBox(height: 15),

                // Branch Cards List
                ...branches.map((branch) {
                   return GestureDetector(
                     onTap: () {
                       Navigator.push(
                         context, 
                         MaterialPageRoute(
                           builder: (_) => PrincipalBranchTimetableScreen(branch: branch)
                         )
                       );
                     },
                     child: Container(
                       margin: const EdgeInsets.only(bottom: 15),
                       padding: const EdgeInsets.all(20),
                       decoration: BoxDecoration(
                         color: cardColor,
                         borderRadius: BorderRadius.circular(15),
                         border: Border.all(color: const Color(0xFF007BFF), width: 1.5), // Vibrant Blue Border
                         boxShadow: [
                           if(isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 5, offset: const Offset(0,2))
                         ]
                       ),
                       child: Row(
                         children: [
                            Expanded(
                              child: Text(
                                branch, 
                                style: GoogleFonts.poppins(
                                  fontSize: 16, 
                                  fontWeight: FontWeight.bold, 
                                  color: textColor
                                ),
                              ),
                            ),
                            Icon(Icons.arrow_forward_ios, size: 16, color: subTextColor)
                         ],
                       ),
                     ),
                   );
                }),
                
                const SizedBox(height: 10),
                Divider(color: subTextColor.withValues(alpha: 0.2)),
                const SizedBox(height: 20),
                
                // Additional Options (Labs, Master) - Border Colored Style
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                         onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrincipalLabsScreen())),
                         child: Container(
                           padding: const EdgeInsets.all(20),
                           decoration: BoxDecoration(
                             color: cardColor,
                             borderRadius: BorderRadius.circular(15),
                             border: Border.all(color: Colors.orange.withValues(alpha: 0.5)),
                             boxShadow: [if(isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 5)]
                           ),
                           child: Column(
                             children: [
                               Icon(Icons.science, color: Colors.orange, size: 30),
                               const SizedBox(height: 10),
                               Text("Labs", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold))
                             ]
                           ),
                         ),
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                       child: GestureDetector(
                         onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const PrincipalMasterTimetableScreen())),
                         child: Container(
                           padding: const EdgeInsets.all(20),
                           decoration: BoxDecoration(
                             color: cardColor,
                             borderRadius: BorderRadius.circular(15),
                             border: Border.all(color: Colors.purple.withValues(alpha: 0.5)),
                             boxShadow: [if(isDark) BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 5)]
                           ),
                           child: Column(
                             children: [
                               Icon(Icons.grid_view_rounded, color: Colors.purple, size: 30),
                               const SizedBox(height: 10),
                               Text("Master Table", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold))
                             ]
                           ),
                         ),
                      ),
                    ),
                  ],
                ),
                
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
