
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class FacultyAnnouncementsScreen extends StatelessWidget {
  const FacultyAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Announcements", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: 3,
        itemBuilder: (context, index) {
          return Container(
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  "Announcement Title ${index + 1}",
                  style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                Text(
                  "This is a sample announcement description. It contains important information for faculty members.",
                  style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 14),
                ),
                const SizedBox(height: 12),
                Text(
                  "Posted on: ${DateTime.now().toString().split(' ')[0]}",
                  style: GoogleFonts.poppins(color: Colors.grey[400], fontSize: 12),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
