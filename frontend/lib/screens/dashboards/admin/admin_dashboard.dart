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
      print("Error fetching stats: $e");
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
    // Standard Theme Colors
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final Color textColor = theme.colorScheme.onSurface;
    final Color subTextColor = theme.colorScheme.secondary;
    final Color cardColor = isDark ? const Color(0xFF1E293B) : Colors.white;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.getAdaptiveOverlayStyle(true), // Header is dark (blue), so light icons
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
            // Standard App Header (Blue Gradient)
            Container(
              padding: EdgeInsets.fromLTRB(24, MediaQuery.of(context).padding.top + 20, 24, 30),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: isDark ? AppTheme.darkHeaderGradient : [const Color(0xFF1a4ab2), const Color(0xFF3b82f6)],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
                borderRadius: BorderRadius.only(
                  bottomLeft: Radius.circular(40),
                  bottomRight: Radius.circular(40),
                ),
                boxShadow: [
                  BoxShadow(color: Colors.black26, blurRadius: 20, offset: Offset(0, 10))
                ]
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ADMIN CONSOLE',
                            style: GoogleFonts.poppins(color: Colors.white.withOpacity(0.8), fontSize: 12, letterSpacing: 1.5, fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            widget.userData['full_name'] ?? 'Administrator',
                            style: GoogleFonts.poppins(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Row(
                        children: [
                          IconButton(
                            onPressed: () => themeProvider.toggleTheme(),
                            icon: Icon(isDark ? Icons.light_mode : Icons.dark_mode, color: Colors.white, size: 24),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                            child: IconButton(
                              onPressed: () {
                                // Notification Action placeholder
                                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Notifications")));
                              },
                              icon: const Icon(Icons.notifications, color: Colors.white, size: 24),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
                            child: IconButton(
                              onPressed: () => _logout(context),
                              icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 24),
                              tooltip: "Logout",
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  // Stats removed as requested
                ],
              ),
            ),
            
            
            // Quick Stats Section (Moved to Body)
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 24, 24, 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly, 
                children: [
                  _buildStatItem("Total Users", _stats['total_users'].toString(), Icons.people, Colors.blue, textColor, subTextColor),
                  Container(height: 40, width: 1, color: Colors.grey.withOpacity(0.2)),
                  GestureDetector(
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminRequestsScreen())),
                    child: _buildStatItem("Pending", _stats['pending_approvals'].toString(), Icons.pending_actions, Colors.orange, textColor, subTextColor),
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
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 20,
                    childAspectRatio: 1.1,
                    children: [
                      _buildMenuCard(
                        context, 
                        'User Management', 
                        Icons.manage_accounts_outlined, 
                        Colors.blueAccent, 
                        cardColor, 
                        textColor, 
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminUsersScreen()))
                      ),
                      _buildMenuCard(
                        context, 
                        'System Stats', 
                        Icons.insights_outlined, 
                        Colors.purpleAccent, 
                        cardColor, 
                        textColor, 
                        () {},
                      ),
                      _buildMenuCard(
                        context, 
                        'Coordinator Requests', 
                        Icons.pending_actions_rounded, 
                        Colors.orange, 
                        cardColor, 
                        textColor, 
                        () => Navigator.push(context, MaterialPageRoute(builder: (context) => const AdminRequestsScreen())),
                      ),
                      _buildMenuCard(
                        context, 
                        'Database', 
                        Icons.storage_rounded, 
                        Colors.tealAccent, 
                        cardColor, 
                        textColor, 
                        () {},
                      ),
                      _buildMenuCard(
                        context, 
                        'Settings', 
                        Icons.settings_suggest_outlined, 
                        Colors.orangeAccent, 
                        cardColor, 
                        textColor, 
                        () {},
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

  Widget _buildStatItem(String label, String value, IconData icon, Color color, Color valueColor, Color labelColor) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 24),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: GoogleFonts.poppins(color: valueColor, fontSize: 20, fontWeight: FontWeight.bold),
        ),
        Text(
          label,
          style: GoogleFonts.poppins(color: labelColor, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, IconData icon, Color iconColor, Color cardColor, Color textColor, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.grey.withOpacity(0.2), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, 10),
            )
          ]
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: iconColor.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: iconColor, size: 32),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w600, fontSize: 14),
            ),
          ],
        ),
      ),
    );
  }
}
