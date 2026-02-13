
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../../../core/providers/theme_provider.dart';
import 'coordinator_announcements_screen.dart';

class CoordinatorAnnouncementDetailsScreen extends StatelessWidget {
  final Announcement announcement;

  const CoordinatorAnnouncementDetailsScreen({super.key, required this.announcement});

  @override
  Widget build(BuildContext context) {
    // Declare variables
    Color typeColorStart;
    Color typeColorEnd;
    IconData typeIcon;

    // Audience Color Logic
    String audience = announcement.audience.isNotEmpty ? announcement.audience.first : 'All';
    typeColorStart = Colors.grey; typeColorEnd = Colors.blueGrey;
    if (audience.toLowerCase().contains('student')) {
       typeColorStart = const Color(0xFF2E3192); typeColorEnd = const Color(0xFF1BFFFF); // Blue/Cyan
    } else if (audience.toLowerCase().contains('parent')) {
       typeColorStart = const Color(0xFFD4145A); typeColorEnd = const Color(0xFFFBB03B); // Red/Orange
    } else if (audience.toLowerCase().contains('faculty')) {
       typeColorStart = const Color(0xFF009245); typeColorEnd = const Color(0xFFFCEE21); // Green/Yellow
    } else if (audience.toLowerCase().contains('hod')) {
       typeColorStart = const Color(0xFF662D8C); typeColorEnd = const Color(0xFFED1E79); // Purple/Pink
    } else if (audience.toLowerCase().contains('principal')) {
       typeColorStart = const Color(0xFF12c2e9); typeColorEnd = const Color(0xFFc471ed); // Blue/Purple
    } else if (audience.toLowerCase().contains('all')) {
       typeColorStart = const Color(0xFFC04848); typeColorEnd = const Color(0xFF480048); // Red/Purple (Distinctive)
    }

    switch(announcement.type) {
      case AnnouncementType.exam: typeIcon = Icons.campaign_outlined; break;
      case AnnouncementType.event: typeIcon = Icons.calendar_today; break;
      case AnnouncementType.faculty: typeIcon = Icons.school; break;
      case AnnouncementType.urgent: typeIcon = Icons.warning_amber_rounded; break;
      default: typeIcon = Icons.info_outline;
    }

    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent, // Important for full screen gradient
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: isDark ? Colors.white : Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          announcement.title, 
          style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black, fontSize: 16, fontWeight: FontWeight.w500)
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
            // 1. Full Page Gradient Background
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    typeColorStart.withOpacity(0.15), // Top color
                    isDark ? const Color(0xFF050511) : Colors.white,        // Middle
                    isDark ? const Color(0xFF020205) : Colors.white         // Bottom
                  ],
                  stops: const [0.0, 0.4, 1.0],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
            ),
            
            // Background Glows (moved below gradient)
            Positioned(
                top: -100,
                left: -100,
                child: Container(
                    width: 300,
                    height: 300,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: typeColorStart.withOpacity(0.2), // Dynamic glow color
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                      child: Container(color: Colors.transparent),
                    ),
                ),
            ),
             Positioned(
                top: 50,
                right: -50,
                child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: typeColorEnd.withOpacity(0.15), // Dynamic glow color
                    ),
                    child: BackdropFilter(
                      filter: ImageFilter.blur(sigmaX: 80, sigmaY: 80),
                      child: Container(color: Colors.transparent),
                    ),
                ),
            ),
            
            // Top Gradient Line
            Positioned(
              top: 100,
              left: 20, 
              right: 20,
              child: Container(
                height: 1,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.transparent,
                      Colors.blue.withOpacity(0.5),
                      Colors.purple.withOpacity(0.5),
                      Colors.transparent
                    ]
                  )
                ),
              ),
            ),

            SingleChildScrollView(
                padding: const EdgeInsets.only(top: 120, left: 24, right: 24, bottom: 40),
                child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                        // Important Tag
                        if (announcement.priority == AnnouncementPriority.urgent || announcement.priority == AnnouncementPriority.important)
                            Container(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                                margin: const EdgeInsets.only(bottom: 16),
                                decoration: BoxDecoration(
                                    color: const Color(0xFFEAD8B1), // Beige/Goldish
                                    borderRadius: BorderRadius.circular(20),
                                ),
                                child: Text(
                                    announcement.priority == AnnouncementPriority.urgent ? 'URGENT' : 'IMPORTANT',
                                    style: GoogleFonts.poppins(
                                        color: Colors.brown[900],
                                        fontWeight: FontWeight.bold,
                                        fontSize: 10,
                                        letterSpacing: 1
                                    ),
                                ),
                            ),
                        

                        // Title
                        Text(
                            announcement.title,
                            style: GoogleFonts.poppins(
                                color: Colors.white,
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                height: 1.2
                            ),
                        ),

                        const SizedBox(height: 12),

                        // Date
                        Row(
                            children: [
                                const Icon(Icons.calendar_today_outlined, color: Colors.grey, size: 16),
                                const SizedBox(width: 8),
                                Text(
                                    DateFormat('d MMM yyyy • hh:mm a').format(announcement.startDate),
                                    style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
                                ),
                            ],
                        ),

                        const SizedBox(height: 20),

                        // Audience Chips
                        Wrap(
                            spacing: 12,
                            runSpacing: 12,
                            children: announcement.audience.map((audience) {
                                return Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    decoration: BoxDecoration(
                                        color: const Color(0xFF131728), // Dark blue-ish pill
                                        borderRadius: BorderRadius.circular(30),
                                        border: Border.all(color: Colors.white.withOpacity(0.05)),
                                    ),
                                    child: Text(
                                        audience,
                                        style: GoogleFonts.poppins(
                                            color: const Color(0xFF8BA5FA), // Light Blue text
                                            fontWeight: FontWeight.w500,
                                            fontSize: 13,
                                        ),
                                    ),
                                );
                            }).toList(),
                        ),

                        const SizedBox(height: 30),

                        // Description Card
                        Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                                color: const Color(0xFF0A0C16), // Very dark card
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.02)),
                            ),
                            child: Text(
                                announcement.description,
                                style: GoogleFonts.poppins(
                                    color: Colors.grey[400],
                                    fontSize: 14,
                                    height: 1.8,
                                ),
                            ),
                        ),

                        const SizedBox(height: 20),

                        // Attachment Card
                        Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                                color: const Color(0xFF0A0C16),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(color: Colors.white.withOpacity(0.02)),
                            ),
                            child: Row(
                                children: [
                                    Transform.rotate(
                                        angle: -0.7, // 45 degrees
                                        child: Container(
                                            padding: const EdgeInsets.all(10),
                                            decoration: BoxDecoration(
                                               color: Colors.blueAccent.withOpacity(0.1),
                                               shape: BoxShape.circle,
                                            ),
                                            child: const Icon(Icons.attach_file, color: Colors.blueAccent, size: 20)
                                        ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                        child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                                Text(
                                                    'View Attachment',
                                                    style: GoogleFonts.poppins(
                                                        color: Colors.white,
                                                        fontWeight: FontWeight.w500,
                                                        fontSize: 14,
                                                    ),
                                                ),
                                                const SizedBox(height: 2),
                                                Text(
                                                    'Final_Exam_Timetable.pdf', // Hardcoded as requested by reference image
                                                    style: GoogleFonts.poppins(
                                                        color: Colors.grey[600],
                                                        fontSize: 12,
                                                    ),
                                                ),
                                            ],
                                        ),
                                    ),
                                ],
                            ),
                        ),

                        const SizedBox(height: 30),

                        // Footer Stats
                        Container(
                            padding: const EdgeInsets.all(24),
                            decoration: BoxDecoration(
                                color: const Color(0xFF080911),
                                borderRadius: BorderRadius.circular(24),
                            ),
                            child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                    Text(
                                        "Created by",
                                        style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                        "Coordinator",
                                        style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                                    ),
                                    const SizedBox(height: 20),
                                    Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                            Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                    Text(
                                                        "Published on",
                                                        style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                        DateFormat('d MMM yyyy').format(announcement.createdAt),
                                                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                                                    ),
                                                ],
                                            ),
                                            Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                    Text(
                                                        "Expires on",
                                                        style: GoogleFonts.poppins(color: Colors.grey[600], fontSize: 12),
                                                    ),
                                                    const SizedBox(height: 4),
                                                    Text(
                                                        DateFormat('d MMM yyyy').format(announcement.endDate),
                                                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                                                    ),
                                                ],
                                            ),
                                        ],
                                    ),
                                ],
                            ),
                        ),
                        // Bottom spacer
                        const SizedBox(height: 20),
                    ],
                ),
            )
        ],
      )
    );
  }
}

