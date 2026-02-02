import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import 'hod_notifications_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';

class HodProfileTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onLogout;

  const HodProfileTab({super.key, required this.userData, required this.onLogout});

  @override
  State<HodProfileTab> createState() => _HodProfileTabState();
}

class _HodProfileTabState extends State<HodProfileTab> {
  Map<String, dynamic> _profileData = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _profileData = widget.userData;
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = await AuthService.getUserSession();
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final userId = user['id'];

    try {
      // Reusing the faculty profile endpoint as HOD is also a user in users table
      final url = Uri.parse('${ApiConstants.baseUrl}/api/faculty/profile?userId=$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _profileData = data;
            _loading = false;
          });
        }
      } else {
        if (mounted) setState(() => _loading = false);
        print("Failed to fetch profile: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) setState(() => _loading = false);
      print("Error fetching profile: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;

    String formattedDob = 'Not Set';
    if (_profileData['dob'] != null && _profileData['dob'].toString().isNotEmpty) {
      try {
        formattedDob = DateFormat('dd-MM-yyyy').format(DateTime.parse(_profileData['dob']));
      } catch (_) {
        formattedDob = _profileData['dob'];
      }
    }

    final Map<String, dynamic> displayData = {
      'fullName': _profileData['fullName'] ?? _profileData['full_name'] ?? 'Dr. HOD',
      'employeeId': 'ID-${_profileData['facultyId'] ?? _profileData['login_id'] ?? 'HOD001'}',
      'department': _profileData['branch'] ?? 'Computer Science',
      'email': _profileData['email'] ?? 'hod.cs@college.edu',
      'phone': _profileData['phoneNumber'] ?? _profileData['phone'] ?? '+91 98765 43210',
      'experience': (_profileData['experience']?.toString().contains('Year') ?? false) 
          ? (_profileData['experience'] ?? '15 - Years') 
          : "${_profileData['experience'] ?? '15'} - Years",
      'dob': formattedDob
    };

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 20),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text("My Profile", style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold, color: textColor)),
                GestureDetector(
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HodNotificationsScreen())),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
                    child: Icon(Icons.notifications_none, size: 24, color: textColor),
                  ),
                ),
              ],
            ),
          ),

          // College Logo
          const SizedBox(height: 10),
          Image.asset('assets/images/college logo.png', width: 120, height: 120),
          const SizedBox(height: 10),
          Text(
            "Alwardas Polytechnic", 
            style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor, letterSpacing: 1),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 30),

          // Profile Card
          _loading 
            ? const Center(child: CircularProgressIndicator())
            : Container(
                padding: const EdgeInsets.all(24),
                decoration: AppTheme.glassDecoration(isDark: isDark),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _buildSection("Full Name", displayData['fullName'], textColor, subTextColor),
                    _buildDivider(iconBg),
                    Row(
                      children: [
                        Expanded(child: _buildSection("HOD ID", displayData['employeeId'], textColor, subTextColor)),
                        Expanded(child: _buildSection("Department", displayData['department'], textColor, subTextColor)),
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
                    Row(
                      children: [
                       Expanded(child: _buildSection("Date of Birth", displayData['dob'], textColor, subTextColor)),
                       Expanded(child:  _buildSection("Email", displayData['email'], textColor, subTextColor)),
                      ],
                    ),
                  ],
                ),
              ),

          const SizedBox(height: 40),

          // Footer
          Column(
            children: [
              GestureDetector(
                onTap: widget.onLogout,
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
        Text(label.toUpperCase(), style: GoogleFonts.poppins(fontSize: 12, color: subTextColor.withOpacity(0.7), letterSpacing: 1, fontWeight: FontWeight.w600)),
        const SizedBox(height: 5),
        Text(value, style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor)),
      ],
    );
  }

  Widget _buildDivider(Color color) {
    return Container(height: 1, width: double.infinity, color: color, margin: const EdgeInsets.symmetric(vertical: 15));
  }
}
