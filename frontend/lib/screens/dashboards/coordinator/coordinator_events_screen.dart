import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';

class CoordinatorEventsScreen extends StatelessWidget {
  const CoordinatorEventsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? ThemeColors.darkBackground : ThemeColors.lightBackground;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;

    final List<Map<String, String>> upcomingEvents = [
      {'title': 'Annual Sports Day', 'date': '15 Jan 2026', 'status': 'Planning'},
      {'title': 'Tech Fest 2026', 'date': '22 Feb 2026', 'status': 'Approved'},
      {'title': 'Cultural Night', 'date': '05 Mar 2026', 'status': 'Draft'},
    ];

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Event Planning", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text("Manage Institutional Events", style: GoogleFonts.poppins(fontSize: 16, color: subTextColor)),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  itemCount: upcomingEvents.length,
                  itemBuilder: (ctx, index) {
                    final event = upcomingEvents[index];
                    return Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: cardColor,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: tint.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(color: tint.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(12)),
                            child: Icon(Icons.event, color: tint),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(event['title']!, style: GoogleFonts.poppins(fontSize: 17, fontWeight: FontWeight.bold, color: textColor)),
                                Text(event['date']!, style: GoogleFonts.poppins(fontSize: 13, color: subTextColor)),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: event['status'] == 'Approved' ? Colors.green.withValues(alpha: 0.1) : Colors.orange.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              event['status']!,
                              style: TextStyle(
                                color: event['status'] == 'Approved' ? Colors.green : Colors.orange,
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
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
}
