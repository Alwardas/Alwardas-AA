import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../auth/login_screen.dart';

class PrincipalProfileScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const PrincipalProfileScreen({super.key, required this.userData});

  @override
  _PrincipalProfileScreenState createState() => _PrincipalProfileScreenState();
}

class _PrincipalProfileScreenState extends State<PrincipalProfileScreen> {
  Map<String, dynamic>? _profileData;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  Future<void> _fetchProfileData() async {
    final user = await AuthService.getUserSession();
    if (user == null) return;

    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/user/profile?userId=${user['id']}'));
      if (response.statusCode == 200) {
        setState(() {
          _profileData = json.decode(response.body);
        });
      }
    } catch (e) {
      print("Error fetching profile: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _logout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (context) => const LoginScreen()), (route) => false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? ThemeColors.darkBackground : ThemeColors.lightBackground;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final dividerColor = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Profile", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _fetchProfileData,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  // College Logo
                  Column(
                    children: [
                      Image.asset(
                        'assets/images/college_logo.png', 
                        width: 120, height: 120,
                        errorBuilder: (context, error, stackTrace) => const Icon(Icons.school, size: 80, color: Colors.blue),
                      ),
                      const SizedBox(height: 10),
                      Text(
                        "Alwardas Polytechnic",
                        style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 1),
                      ),
                    ],
                  ),
                  const SizedBox(height: 40),

                  // Profile Details
                  _buildProfileSection("Full Name", _profileData?['fullName'] ?? 'Loading...', textColor, subTextColor),
                  _buildDivider(dividerColor),
                  
                  Row(
                    children: [
                      Expanded(child: _buildProfileSection("ID", _profileData?['employeeId'] ?? 'N/A', textColor, subTextColor)),
                      Expanded(child: _buildProfileSection("Role", _profileData?['role'] ?? 'N/A', textColor, subTextColor)),
                    ],
                  ),
                  _buildDivider(dividerColor),

                  Row(
                    children: [
                      Expanded(child: _buildProfileSection("Experience", 
                          (_profileData?['experience']?.toString().contains('Year') ?? false)
                              ? (_profileData?['experience'] ?? 'N/A')
                              : "${_profileData?['experience'] ?? 'N/A'} - Years",
                          textColor, subTextColor)),
                      Expanded(child: _buildProfileSection("Phone", _profileData?['phone'] ?? 'N/A', textColor, subTextColor)),
                    ],
                  ),
                  _buildDivider(dividerColor),

                  _buildProfileSection("Email", _profileData?['email'] ?? 'N/A', textColor, subTextColor),
                  const SizedBox(height: 40),

                  // Footer
                  GestureDetector(
                    onTap: _logout,
                    child: Padding(
                      padding: const EdgeInsets.all(10),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.logout, color: Colors.red, size: 24),
                          const SizedBox(width: 8),
                          Text("Logout", style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text("App Version 1.0.0", style: GoogleFonts.poppins(fontSize: 12, color: subTextColor)),
                  const SizedBox(height: 30),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProfileSection(String label, String value, Color textColor, Color labelColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label.toUpperCase(), style: GoogleFonts.poppins(fontSize: 10, color: labelColor.withOpacity(0.7), letterSpacing: 1)),
          const SizedBox(height: 4),
          Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
        ],
      ),
    );
  }

  Widget _buildDivider(Color color) {
    return Container(height: 1, width: double.infinity, color: color, margin: const EdgeInsets.symmetric(vertical: 15));
  }
}
