import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/providers/theme_provider.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api_constants.dart';
import '../../auth/login_screen.dart';
import 'admin_users_screen.dart';
import 'admin_requests_screen.dart';

class AdminDashboard extends StatefulWidget {
  final Map<String, dynamic> userData;

  const AdminDashboard({super.key, required this.userData});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  bool _loading = true;
  Map<String, dynamic> _stats = {
    'total_users': 0,
    'pending_approvals': 0,
    'total_students': 0,
    'total_faculty': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchStats();
  }

  Future<void> _fetchStats() async {
    try {
      final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/admin/stats'));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _stats = json.decode(response.body);
            _loading = false;
          });
        }
      } else {
        throw Exception('Failed to load stats');
      }
    } catch (e) {
      debugPrint("Error fetching stats: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

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
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final Color textColor = theme.colorScheme.onSurface;
    final Color subTextColor = theme.colorScheme.secondary;
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.getAdaptiveOverlayStyle(true), 
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        body: Container(
           decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isDark ? AppTheme.darkBodyGradient : AppTheme.lightBodyGradient,
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Column(
          children: [
            // 1. Header Section
            Container(
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 10, 
                bottom: 30, 
                left: 24, 
                right: 24
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark ? AppTheme.darkHeaderGradient : [const Color(0xFF1a4ab2), const Color(0xFF3b82f6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
              ),
              child: Column(
                 children: [
                   Row(
                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
                     children: [
                       Expanded(
                         child: Column(
                           crossAxisAlignment: CrossAxisAlignment.start,
                           children: [
                             Text(
                               'Welcome Back,', 
                               style: GoogleFonts.poppins(
                                 color: Colors.white70,
                                 fontSize: 18,
                                 fontWeight: FontWeight.w600,
                               ),
                             ),
                             FittedBox(
                               fit: BoxFit.scaleDown,
                               alignment: Alignment.centerLeft,
                               child: Text(
                                 widget.userData['full_name'] ?? 'Administrator',
                                 style: GoogleFonts.poppins(
                                   color: Colors.white,
                                   fontSize: 26,
                                   fontWeight: FontWeight.bold,
                                 ),
                               ),
                             ),
                             const SizedBox(height: 4),
                             Text(
                               'System Admin',
                               style: GoogleFonts.poppins(
                                 color: Colors.white70,
                                 fontSize: 14,
                               ),
                             ),
                           ],
                         ),
                       ),
                       Row(
                         children: [
                           GestureDetector(
                             onTap: () => themeProvider.toggleTheme(),
                             child: _buildHeaderIcon(themeProvider.isDarkMode ? Icons.wb_sunny_outlined : Icons.nightlight_round),
                           ),
                           const SizedBox(width: 10),
                           GestureDetector(
                             onTap: () => _logout(context),
                             child: _buildHeaderIcon(Icons.logout),
                           ),
                         ],
                       ),
                     ],
                   )
                 ],
               ),
            ),
            
            // Quick Stats Section 
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
                children: [
                  Expanded(child: _buildStatItem("Total Users", _stats['total_users'].toString(), Icons.people, Colors.blue, textColor)),
                  Container(height: 40, width: 1, color: Colors.grey.withValues(alpha: 0.2)),
                  Expanded(
                    child: GestureDetector(
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminRequestsScreen())),
                      child: _buildStatItem("Pending Requests", _stats['pending_approvals'].toString(), Icons.pending_actions, Colors.orange, textColor),
                    ),
                  ),
                ],
              ),
            ),

            // Menu Grid
            Expanded(
              child: _loading 
                ? const Center(child: CircularProgressIndicator())
                : GridView.count(
                    padding: const EdgeInsets.all(24),
                    crossAxisCount: 2,
                    crossAxisSpacing: 15,
                    mainAxisSpacing: 15,
                    childAspectRatio: 1.2,
                    children: [
                      _buildMenuCard(
                        'User Management', 
                        'Manage access',
                        Icons.manage_accounts_outlined, 
                        Colors.blueAccent, 
                        cardColor, 
                        textColor, 
                        subTextColor,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminUsersScreen()))
                      ),
                      _buildMenuCard(
                        'System Stats', 
                        'View insights',
                        Icons.insights_outlined, 
                        Colors.purpleAccent, 
                        cardColor, 
                        textColor, 
                        subTextColor,
                        onTap: () {},
                      ),
                      _buildMenuCard(
                        'Coordinator Requests', 
                        'Approve/Reject',
                        Icons.pending_actions_rounded, 
                        Colors.orange, 
                        cardColor, 
                        textColor, 
                        subTextColor,
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminRequestsScreen())),
                      ),
                      _buildMenuCard(
                        'Database', 
                        'Backup/Restore',
                        Icons.storage_rounded, 
                        Colors.tealAccent, 
                        cardColor, 
                        textColor, 
                        subTextColor,
                        onTap: () {},
                      ),
                      _buildMenuCard(
                        'Settings', 
                        'Configuration',
                        Icons.settings_suggest_outlined, 
                        Colors.orangeAccent, 
                        cardColor, 
                        textColor, 
                        subTextColor,
                        onTap: () {},
                      ),
                    ],
                  ),
            ),
          ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeaderIcon(IconData icon) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.2),
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white.withValues(alpha: 0.5), width: 1),
      ),
      child: Icon(icon, color: Colors.white, size: 20),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color, Color textColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(color: textColor, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(color: textColor.withValues(alpha: 0.7), fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMenuCard(String title, String subtitle, IconData icon, Color iconColor, Color cardColor, Color textColor, Color subTextColor, {VoidCallback? onTap}) {
    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
             color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.03),
             width: 1,
          ),
          boxShadow: [
            BoxShadow(
              color: isDark ? Colors.black.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1),
              blurRadius: 15,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: iconColor.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 26),
            ),
            const SizedBox(height: 10),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(color: subTextColor, fontSize: 10),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
