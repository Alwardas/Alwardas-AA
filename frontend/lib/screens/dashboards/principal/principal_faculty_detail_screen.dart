import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/models/faculty_model.dart';

class PrincipalFacultyDetailScreen extends StatefulWidget {
  final BackendFacultyMember faculty;

  const PrincipalFacultyDetailScreen({super.key, required this.faculty});

  @override
  State<PrincipalFacultyDetailScreen> createState() => _PrincipalFacultyDetailScreenState();
}

class _PrincipalFacultyDetailScreenState extends State<PrincipalFacultyDetailScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? ThemeColors.darkBackground : ThemeColors.lightBackground;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Faculty Profile", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Faculty Header Card
              Container(
                margin: const EdgeInsets.fromLTRB(20, 10, 20, 20),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5)),
                  ],
                  border: Border.all(color: iconBg.withOpacity(0.5)),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(4),
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: tint, width: 2),
                          ),
                          child: CircleAvatar(
                            radius: 32,
                            backgroundColor: tint.withOpacity(0.1),
                            child: Text(
                              widget.faculty.name.isNotEmpty ? widget.faculty.name[0].toUpperCase() : '?', 
                              style: TextStyle(color: tint, fontWeight: FontWeight.bold, fontSize: 26)
                            ),
                          ),
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(widget.faculty.name, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  color: tint.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  "ID: ${widget.faculty.loginId}", 
                                  style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w600, color: tint)
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        _buildInfoItem(Icons.email_outlined, widget.faculty.email, subTextColor),
                        _buildInfoItem(Icons.phone_outlined, widget.faculty.phone, subTextColor),
                      ],
                    ),
                  ],
                ),
              ),

              // 2. Tab Bar
              Container(
                height: 50,
                margin: const EdgeInsets.symmetric(horizontal: 20),
                decoration: BoxDecoration(
                  color: cardColor,
                  borderRadius: BorderRadius.circular(25),
                  border: Border.all(color: iconBg.withOpacity(0.5)),
                ),
                child: TabBar(
                  controller: _tabController,
                  indicator: BoxDecoration(
                    borderRadius: BorderRadius.circular(25),
                    color: tint,
                    boxShadow: [
                      BoxShadow(color: tint.withOpacity(0.3), blurRadius: 8, offset: const Offset(0, 2))
                    ],
                  ),
                  labelColor: Colors.white,
                  unselectedLabelColor: subTextColor,
                  labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13),
                  padding: const EdgeInsets.all(4),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  tabs: const [
                    Tab(text: "Performance"),
                    Tab(text: "Classes"),
                    Tab(text: "Schedule"),
                    Tab(text: "Notes"),
                  ],
                ),
              ),

              const SizedBox(height: 20),

              // 3. Tab View
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildPlaceholderTab(context, Icons.insights, "Work Performance", "Insightful metrics and performance data for ${widget.faculty.name}."),
                    _buildPlaceholderTab(context, Icons.class_outlined, "Regular Classes", "List of all active classes and subjects handled."),
                    _buildPlaceholderTab(context, Icons.calendar_month_outlined, "Weekly Schedule", "Teaching hours and availability throughout the week."),
                    _buildPlaceholderTab(context, Icons.edit_note, "Principal Notes", "Private assessments and administrative notes."),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoItem(IconData icon, String text, Color color) {
    return Expanded(
      child: Row(
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 8),
          Expanded(
            child: Text(text, overflow: TextOverflow.ellipsis, style: GoogleFonts.poppins(fontSize: 12, color: color)),
          ),
        ],
      ),
    );
  }

  Widget _buildPlaceholderTab(BuildContext context, IconData icon, String title, String subtitle) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? ThemeColors.darkCard : ThemeColors.lightCard,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: tint.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: tint),
          ),
          const SizedBox(height: 24),
          Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 20)),
          const SizedBox(height: 12),
          Text(subtitle, textAlign: TextAlign.center, style: TextStyle(color: subTextColor, fontSize: 15, height: 1.5)),
        ],
      ),
    );
  }
}
