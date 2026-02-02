import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../auth/login_screen.dart';
import 'coordinator_events_screen.dart';
import 'coordinator_activities_screen.dart';

class CoordinatorDashboard extends StatelessWidget {
  final Map<String, dynamic> userData;

  const CoordinatorDashboard({super.key, required this.userData});

  void _logout(BuildContext context) async {
    await AuthService.logout();
    if (context.mounted) {
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final Color textColor = isDark ? Colors.white : Colors.black87;
    final Color subTextColor = isDark ? Colors.white70 : Colors.black54;
    final Color cardColor = isDark ? const Color(0xFF222240) : Colors.white;

    final List<Map<String, dynamic>> menuItems = [
      {'title': 'Event Planning', 'icon': Icons.calendar_today_outlined, 'color': const Color(0xFFFF416C)},
      {'title': 'Student Activities', 'icon': Icons.sports_basketball_outlined, 'color': const Color(0xFFFF4B2B)},
      {'title': 'Approvals', 'icon': Icons.check_box_outlined, 'color': const Color(0xFF141E30)},
      {'title': 'Communications', 'icon': Icons.mail_outline, 'color': const Color(0xFF243B55)},
      {'title': 'Teams', 'icon': Icons.people_outline, 'color': const Color(0xFF606c88)},
    ];

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? AppTheme.darkBodyGradient : AppTheme.lightBodyGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header - NO SAFE AREA
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10, 
                bottom: 30, 
                left: 24, 
                right: 24
              ),
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  colors: [Color(0xFFFF416C), Color(0xFFFF4B2B)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Hello,', style: GoogleFonts.poppins(fontSize: 18, color: Colors.white.withOpacity(0.8))),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(userData['full_name'] ?? 'Coordinator', style: GoogleFonts.poppins(fontSize: 26, fontWeight: FontWeight.bold, color: Colors.white)),
                        ),
                        Text('Events & Activities', style: GoogleFonts.poppins(fontSize: 14, color: Colors.white.withOpacity(0.7))),
                      ],
                    ),
                  ),
                  GestureDetector(
                    onTap: () => _logout(context),
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), shape: BoxShape.circle),
                      child: const Icon(Icons.logout, color: Colors.white, size: 24),
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Management', style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                    const SizedBox(height: 20),
                    GridView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 1.1,
                      ),
                      itemCount: menuItems.length,
                      itemBuilder: (ctx, index) {
                        final item = menuItems[index];
                        return _buildCard(context, item, cardColor, textColor);
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context, Map<String, dynamic> item, Color cardColor, Color textColor) {
    final isDark = Provider.of<ThemeProvider>(context, listen: false).isDarkMode;
    return GestureDetector(
      onTap: () {
        if (item['title'] == 'Event Planning') {
          Navigator.push(context, MaterialPageRoute(builder: (ctx) => const CoordinatorEventsScreen()));
        } else if (item['title'] == 'Student Activities') {
          Navigator.push(context, MaterialPageRoute(builder: (ctx) => const CoordinatorActivitiesScreen()));
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Opening ${item['title']}...")));
        }
      },
      child: AppTheme.buildGlassCard(
        isDark: isDark,
        padding: const EdgeInsets.all(20),
        customColor: cardColor,
        opacity: isDark ? 0.05 : 0.4,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(color: (item['color'] as Color).withOpacity(0.2), shape: BoxShape.circle),
              child: Icon(item['icon'], size: 32, color: item['color']),
            ),
            const SizedBox(height: 12),
            Text(item['title'], textAlign: TextAlign.center, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: textColor)),
          ],
        ),
      ),
    );
  }
}
