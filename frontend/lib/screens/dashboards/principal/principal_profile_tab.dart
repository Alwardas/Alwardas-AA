import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/theme/app_theme.dart';


class PrincipalProfileTab extends StatelessWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onLogout;

  const PrincipalProfileTab({super.key, required this.userData, required this.onLogout});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;

    final Map<String, dynamic> displayData = {
      'fullName': userData['full_name'] ?? 'Principal',
      'employeeId': userData['login_id'] ?? 'PR001',
      'role': userData['role'] ?? 'Principal',
      'email': userData['email'] ?? 'principal@college.edu',
      'phone': userData['phone'] ?? '+91 99999 99999',
      'experience': '25 Years'
    };

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Text("Profile", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
          ),

          // College Logo
          const SizedBox(height: 10),
          Image.asset('assets/images/college logo.png', width: 120, height: 120, errorBuilder: (c,e,s) => const Icon(Icons.school, size: 80)),
          const SizedBox(height: 10),
          Text(
            "Alwardas Polytechnic", 
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 1),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          // Profile Card
          Container(
            padding: const EdgeInsets.all(24),
            decoration: AppTheme.glassDecoration(
              isDark: isDark,
              opacity: 0.1,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSection("Full Name", displayData['fullName'], textColor, subTextColor),
                _buildDivider(iconBg),
                Row(
                  children: [
                    Expanded(child: _buildSection("ID", displayData['employeeId'], textColor, subTextColor)),
                    Expanded(child: _buildSection("Role", displayData['role'], textColor, subTextColor)),
                  ],
                ),
                _buildDivider(iconBg),
                Row(
                  children: [
                    Expanded(child: _buildSection("Experience", displayData['experience'], textColor, subTextColor)),
                    Expanded(child: _buildSection("Phone", displayData['phone'], textColor, subTextColor)),
                  ],
                ),
                _buildDivider(iconBg),
                _buildSection("Email", displayData['email'], textColor, subTextColor),
              ],
            ),
          ),

          const SizedBox(height: 40),

          // Footer
          Column(
            children: [
              GestureDetector(
                onTap: onLogout,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.logout, color: Colors.red, size: 24),
                      const SizedBox(width: 10),
                      Text("Logout", style: GoogleFonts.poppins(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 5),
              Text("App Version 1.0.0", style: GoogleFonts.poppins(fontSize: 12, color: subTextColor)),
              const SizedBox(height: 40),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String label, String value, Color textColor, Color subTextColor) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label.toUpperCase(), style: GoogleFonts.poppins(fontSize: 12, color: subTextColor.withValues(alpha: 0.7), letterSpacing: 1, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
      ],
    );
  }

  Widget _buildDivider(Color color) {
    return Container(height: 1, width: double.infinity, color: color, margin: const EdgeInsets.symmetric(vertical: 15));
  }
}
