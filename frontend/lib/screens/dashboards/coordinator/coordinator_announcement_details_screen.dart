import 'dart:ui';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import '../../../../core/providers/theme_provider.dart';
import '../../../../core/helpers/announcement_theme_helper.dart';
import 'coordinator_announcements_screen.dart';

class CoordinatorAnnouncementDetailsScreen extends StatelessWidget {
  final Announcement announcement;

  const CoordinatorAnnouncementDetailsScreen({super.key, required this.announcement});

  @override
  Widget build(BuildContext context) {
    final isDark = Provider.of<ThemeProvider>(context).isDarkMode;
    final themeData = AnnouncementThemeHelper.getTheme(announcement.type.toString().split('.').last, isDark);

    final List<String> availableTabs = ['All', 'Students', 'Faculty', 'Parents', 'HODs', 'Principal'];
    final activeTab = announcement.audience.isNotEmpty ? announcement.audience.first : 'All';

    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 28),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          themeData.pageTitle,
          style: GoogleFonts.inter(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
        ),
        centerTitle: false,
      ),
      body: Stack(
        children: [
          // Background Gradient Base
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: themeData.backgroundGradient,
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          // Dark Mode Glows
          if (isDark) ...[
            Positioned(
              top: 50,
              left: -100,
              child: Container(
                width: 300,
                height: 300,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: themeData.darkGlow1.withOpacity(0.5),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
            Positioned(
              top: 250,
              right: -100,
              child: Container(
                width: 350,
                height: 350,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: themeData.darkGlow2.withOpacity(0.4),
                ),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                  child: Container(color: Colors.transparent),
                ),
              ),
            ),
          ],

          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  // Date and Time
                  Row(
                    children: [
                      const Icon(Icons.calendar_today_outlined, color: Colors.white70, size: 16),
                      const SizedBox(width: 8),
                      Text(
                        DateFormat('dd MMM yyyy • hh:mm a').format(announcement.createdAt),
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.normal),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  
                  // Target Audience Chips
                  SingleChildScrollView(
                    scrollDirection: Axis.horizontal,
                    child: Row(
                      children: availableTabs.map((tab) {
                        bool isActive = (activeTab.toLowerCase() == tab.toLowerCase()) || 
                                        (tab == 'All' && announcement.audience.isEmpty) ||
                                        (tab == 'All'); // Just highlighting 'All' per screenshot design
                        // If it's the exact active tab we highlight it
                        if (activeTab != 'All') {
                           isActive = announcement.audience.any((a) => a.toLowerCase().contains(tab.toLowerCase()));
                        }
                        return Container(
                          margin: const EdgeInsets.only(right: 12),
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                          decoration: BoxDecoration(
                            color: isActive 
                                ? (isDark ? themeData.buttonGradient.first : themeData.buttonGradient.first.withOpacity(0.9))
                                : Colors.white.withOpacity(0.2), // Frosted glass for inactive
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            tab,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontWeight: isActive ? FontWeight.w600 : FontWeight.w500,
                              fontSize: 14,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ),

                  const SizedBox(height: 30),

                  // Main Announcement Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: themeData.cardGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(isDark ? 0.05 : 0.2)),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.15),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        )
                      ]
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: themeData.iconCircleBg,
                                shape: BoxShape.circle,
                                border: Border.all(color: Colors.white.withOpacity(0.2)),
                              ),
                              child: Icon(themeData.typeIcon, color: themeData.iconColor, size: 28),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    announcement.title,
                                    style: GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.w700,
                                      height: 1.3,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    announcement.description,
                                    style: GoogleFonts.inter(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 14,
                                      height: 1.5,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Action Button
                        Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: LinearGradient(colors: themeData.buttonGradient),
                            borderRadius: BorderRadius.circular(16),
                            boxShadow: [
                               BoxShadow(
                                 color: themeData.buttonGradient.last.withOpacity(0.4),
                                 blurRadius: 10,
                                 offset: const Offset(0, 4),
                               )
                            ]
                          ),
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              borderRadius: BorderRadius.circular(16),
                              onTap: () {},
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 16),
                                child: Center(
                                  child: Text(
                                    announcement.type == AnnouncementType.exam ? "View Timetable" : "View Details",
                                    style: GoogleFonts.inter(
                                      color: isDark && announcement.type == AnnouncementType.event ? Colors.black87 : Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // Real Attachment Section
                        if (announcement.attachmentUrl != null && announcement.attachmentUrl!.isNotEmpty) ...[
                          const SizedBox(height: 24),
                          Divider(color: Colors.white.withOpacity(0.1), height: 1),
                          const SizedBox(height: 20),
                          InkWell(
                            onTap: () async {
                               try {
                                 final base64Content = announcement.attachmentUrl!;
                                 final bytes = base64Decode(base64Content);
                                 final tempDir = await getTemporaryDirectory();
                                 String ext = 'pdf';
                                 if (base64Content.length > 20) {
                                    final header = base64Content.substring(0, 20);
                                    if (header.contains('/9j/')) ext = 'jpg';
                                    else if (header.contains('iVBORw0KGgo')) ext = 'png';
                                 }
                                 final file = File('${tempDir.path}/attachment_${announcement.id}.$ext');
                                 await file.writeAsBytes(bytes);
                                 await OpenFilex.open(file.path);
                               } catch (e) {
                                 ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
                               }
                            },
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(color: Colors.white.withOpacity(0.2)),
                                  ),
                                  child: Icon(
                                    announcement.attachmentUrl!.length > 100 && announcement.attachmentUrl!.substring(0, 30).contains('/9j/') 
                                      ? Icons.image 
                                      : Icons.picture_as_pdf, 
                                    color: Colors.white, 
                                    size: 20
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'View Attachment',
                                        style: GoogleFonts.inter(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Tap to open and view',
                                        style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                const Icon(Icons.open_in_new, color: Colors.white54, size: 18),
                              ],
                            ),
                          )
                        ]
                      ],
                    ),
                  ),

                  const SizedBox(height: 20),

                  // Metadata Card
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: themeData.cardGradient,
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: Colors.white.withOpacity(isDark ? 0.05 : 0.2)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Created by",
                          style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 13),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "Coordinator",
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 20),
                        Divider(color: Colors.white.withOpacity(0.1), height: 1),
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Published",
                                    style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('dd MMM yyyy').format(announcement.createdAt),
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              height: 40,
                              width: 1,
                              color: Colors.white.withOpacity(0.1),
                            ),
                            const SizedBox(width: 20),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    "Expires",
                                    style: GoogleFonts.inter(color: Colors.white.withOpacity(0.6), fontSize: 13),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    DateFormat('dd MMM yyyy').format(announcement.endDate),
                                    style: GoogleFonts.inter(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "Expires in ${announcement.endDate.difference(DateTime.now()).inDays} days",
                                    style: GoogleFonts.inter(color: Colors.white.withOpacity(0.5), fontSize: 11),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
