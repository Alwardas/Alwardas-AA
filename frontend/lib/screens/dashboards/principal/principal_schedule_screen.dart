import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';

class PrincipalScheduleScreen extends StatelessWidget {
  const PrincipalScheduleScreen({super.key});

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

    final List<Map<String, String>> agenda = [
      {'time': '09:00 AM', 'title': 'HOD Meeting', 'desc': 'Weekly departmental review', 'location': 'Conference Room A'},
      {'time': '11:30 AM', 'title': 'Infrastructure Audit', 'desc': 'Inspection of new Lab wing', 'location': 'Wing B - 1st Floor'},
      {'time': '01:30 PM', 'title': 'Lunch Break', 'desc': 'Executive dining', 'location': 'Cafeteria'},
      {'time': '02:30 PM', 'title': 'Sponsorship Meeting', 'desc': 'Annual sports fest budget', 'location': 'Principal Office'},
      {'time': '04:00 PM', 'title': 'Faculty Orientation', 'desc': 'Session for new joiners', 'location': 'Auditorium'},
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("My Schedule", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(icon: Icon(Icons.calendar_today, color: tint), onPressed: () {}),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text("Today's Agenda", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                    Text("Wednesday, 27 Dec 2025", style: GoogleFonts.poppins(fontSize: 14, color: tint, fontWeight: FontWeight.w600)),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: agenda.length,
                  itemBuilder: (ctx, index) {
                    final item = agenda[index];
                    return _buildAgendaItem(item, cardColor, textColor, subTextColor, tint, iconBg);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {},
        backgroundColor: tint,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _buildAgendaItem(Map<String, String> item, Color cardColor, Color textColor, Color subTextColor, Color tint, Color iconBg) {
    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 70,
            child: Text(item['time']!, style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: subTextColor)),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: cardColor,
                borderRadius: BorderRadius.circular(16),
                border: Border(left: BorderSide(color: tint, width: 4), top: BorderSide(color: iconBg), right: BorderSide(color: iconBg), bottom: BorderSide(color: iconBg)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text(item['title']!, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
                   const SizedBox(height: 4),
                   Text(item['desc']!, style: GoogleFonts.poppins(fontSize: 13, color: subTextColor)),
                   const SizedBox(height: 8),
                   Row(
                     children: [
                       Icon(Icons.location_on_outlined, size: 14, color: tint),
                       const SizedBox(width: 4),
                       Text(item['location']!, style: GoogleFonts.poppins(fontSize: 12, color: tint, fontWeight: FontWeight.w500)),
                     ],
                   ),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
