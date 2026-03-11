import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../hod/hod_timetables_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/api_constants.dart';
import 'principal_labs_screen.dart';
import 'principal_master_timetable_screen.dart';

class PrincipalTimetablesScreen extends StatefulWidget {
  const PrincipalTimetablesScreen({super.key});

  @override
  _PrincipalTimetablesScreenState createState() => _PrincipalTimetablesScreenState();
}

class _PrincipalTimetablesScreenState extends State<PrincipalTimetablesScreen> {
  List<String> branches = [];

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
            branches = data.map((d) => d['branch']?.toString() ?? '').where((b) => b.isNotEmpty).toList();
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
      branches = [
        "Computer Engineering",
        "Civil Engineering",
        "Mechanical Engineering",
        "Electronics & Communication Engineering",
        "Electrical & Electronics Engineering"
      ];
    });
  }

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
        width: double.infinity,
        height: double.infinity,
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
                           builder: (_) => HodTimetablesScreen(branch: branch)
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
                    // Master Table removed as per requested
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
