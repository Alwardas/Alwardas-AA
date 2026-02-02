import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:grpc/grpc.dart';
import '../../core/services/grpc/auth.pbgrpc.dart';
import '../../widgets/custom_text_field.dart';
import '../../theme/app_colors.dart';
import 'signup_screen.dart';
import 'forgot_password_screen.dart';

import '../../core/api_constants.dart';
import '../../core/services/auth_service.dart';
import 'package:provider/provider.dart';
import '../../core/providers/theme_provider.dart';
import '../../core/theme/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Import Dashboards
import '../dashboards/student/student_dashboard.dart';
import '../dashboards/parent/parent_dashboard.dart';
import '../dashboards/faculty/faculty_dashboard.dart';
import '../dashboards/hod/hod_dashboard.dart';
import '../dashboards/principal/principal_dashboard.dart';
import '../dashboards/admin/admin_dashboard.dart';
import '../dashboards/coordinator/coordinator_dashboard.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _loginIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  Future<void> _handleLogin() async {
    if (_loginIdController.text.isEmpty || _passwordController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter ID and Password')));
      return;
    }

    setState(() => _isLoading = true);

    final inputId = _loginIdController.text.trim();
    final inputPass = _passwordController.text.trim();

    // Proceed directly to API login for ALL users including demo ones
    // This ensures we get the real UUID from the database.

      // Parse host from baseUrl to ensure consistency with user settings
      final uri = Uri.parse(ApiConstants.baseUrl);
      final grpcHost = uri.host;
      final grpcPort = 50051; // Keep port fixed for now or parse if needed, but usually 50051

      final channel = ClientChannel(
        grpcHost,
        port: grpcPort,
        options: const ChannelOptions(
          credentials: ChannelCredentials.insecure(),
        ),
      );

      final stub = AuthServiceClient(channel);

      try {
        final request = LoginRequest()
          ..loginId = inputId
          ..password = inputPass;

        final response = await stub.login(request);

        if (response.success) {
          final userData = {
            'id': response.userId,
            'full_name': response.userProfile.name,
            'role': response.userProfile.role,
            'login_id': response.userProfile.loginId,
            'branch': response.userProfile.branch,
            'year': response.userProfile.year,
            'semester': response.userProfile.semester, 
            'batch_no': response.userProfile.batchNo,
          };

          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Login Successful')));

          Widget dashboard = _getDashboardForRole(response.userProfile.role, userData);

          if (mounted) {
             await AuthService.saveUserSession(userData);
             Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => dashboard));
          }
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(response.message)));
        }
      } catch (e) {
        debugPrint("Login Error: $e");
        
        String errorMessage = 'Connection Error';
        String suggestion = 'Please check your internet connection.';
        
        if (e.toString().contains('SocketException') || e.toString().contains('110') || e.toString().contains('111')) {
           errorMessage = 'Server Not Reachable';
           suggestion = '1. Check if the Backend is running.\n'
                        '2. different Networks? Ensure devices are on the same Wi-Fi.\n'
                        '3. Firewall? Windows Firewall might be blocking. Allow port 3001 & 50051.\n'
                        '4. Wrong IP? Check Settings against PC IP.';
        }

        if (mounted) {
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text(errorMessage, style: const TextStyle(color: Colors.red)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   Text("The app could not connect to the server at '$grpcHost'."),
                   const SizedBox(height: 10),
                   const Text("Suggestions:", style: TextStyle(fontWeight: FontWeight.bold)),
                   Text(suggestion),
                   const SizedBox(height: 10),
                   const Text("Technical Details:", style: TextStyle(fontSize: 10, color: Colors.grey)),
                   Text(e.toString(), style: const TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("OK")),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _showServerConfigDialog();
                  }, 
                  child: const Text("Change IP Settings")
                ),
              ],
            ),
          );
        }
      } finally {
        await channel.shutdown();
        if (mounted) setState(() => _isLoading = false);
      }
    }

  void _showServerConfigDialog() {
    final TextEditingController urlController = TextEditingController(text: ApiConstants.baseUrl);
    
    showDialog(
      context: context, 
      builder: (context) => AlertDialog(
        title: const Text("Server Configuration"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text("Enter the full API Base URL (e.g. http://192.168.1.5:3001)"),
            const SizedBox(height: 10),
            TextField(
              controller: urlController,
              decoration: const InputDecoration(
                border: OutlineInputBorder(),
                hintText: "http://ip:port",
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
               // Reset to code defaults (useful if IP changed)
               final prefs = await SharedPreferences.getInstance();
               await prefs.remove('api_base_url');
               
               setState(() {
                 // Force reload from constants (which we update in code)
                 // You might need to reload the app completely or just re-assign here:
                 // ApiConstants.baseUrl = 'http://172.25.82.167:3001'; // Hard to know dynamic value here without reflection
                 // Better to just tell user to restart or manually clear
                 ApiConstants.baseUrl = 'http://172.25.82.167:3001'; // Fallback
               });
               
               if (mounted) {
                   Navigator.pop(context);
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Reset to Default. Please Restart App.")));
               }
            },
            child: const Text("Reset Default"),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: () async {
              String newUrl = urlController.text.trim();
              if (newUrl.isNotEmpty) {
                 // Remove trailing slash if present
                 if (newUrl.endsWith('/')) {
                   newUrl = newUrl.substring(0, newUrl.length - 1);
                 }

                 // Save to prefs
                 final prefs = await SharedPreferences.getInstance();
                 await prefs.setString('api_base_url', newUrl);
                 
                 // Update runtime constants
                 setState(() {
                   ApiConstants.baseUrl = newUrl;
                 });
                 
                 if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Server URL updated to: $newUrl")));
                    Navigator.pop(context);
                 }
              }
            }, 
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _getDashboardForRole(String role, Map<String, dynamic> userData) {
    switch (role) {
      case 'Student': return StudentDashboard(userData: userData);
      case 'Parent': return ParentDashboard(userData: userData);
      case 'Faculty': return FacultyDashboard(userData: userData); // Ensure this exists or placeholder
      case 'HOD': return HodDashboard(userData: userData);
      case 'Principal': return PrincipalDashboard(userData: userData); // Ensure this exists or placeholder
      case 'Admin': return AdminDashboard(userData: userData);
      case 'Coordinator': return CoordinatorDashboard(userData: userData);
      default: return Scaffold(body: Center(child: Text("Unknown Role: $role")));
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      body: Stack(
        children: [
          // 1. Fixed Background
          Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF005EB8), // #005EB8
                  Color(0xFFC3C9CF), // #c3c9cfff
                  Color(0xFF001F3F), // #001F3F
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          
          // Settings Button (Top Right)
          Positioned(
            top: 40,
            right: 20,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.settings, color: Colors.white70),
                onPressed: _showServerConfigDialog,
                tooltip: "Change Server URL",
              ),
            ),
          ),
          
          // 2. Scrollable Content (Logo + Card)
          Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
            child: SingleChildScrollView(
              physics: const ClampingScrollPhysics(),
              child: SizedBox(
                height: MediaQuery.of(context).size.height,
              child: Column(
                children: [
                  const Spacer(flex: 3),
                  
                  // App Logo in the middle area
                  Image.asset(
                    'assets/images/logo.png',
                    height: 140,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) =>
                        const Icon(Icons.school, size: 80, color: Colors.white),
                  ),
                  
                  const Spacer(flex: 2),
                  
                  // Login Fields Card at Bottom
                  Container(
                    margin: const EdgeInsets.fromLTRB(24, 0, 24, 30),
                    padding: const EdgeInsets.all(32),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(35),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.12),
                          blurRadius: 15,
                          offset: const Offset(0, 8),
                        ),
                      ],
                    ),
                    child: _LoginFields(
                      loginIdController: _loginIdController,
                      passwordController: _passwordController,
                      isLoading: _isLoading,
                      onLogin: _handleLogin,
                      isDark: isDark,
                    ),
                  ),
                ],
              ),
            ),
          ),
          ),

          // Server Info (Bottom Center)
          Positioned(
            bottom: 20,
            left: 0,
            right: 0,
            child: SafeArea(
              child: Center(
                child: GestureDetector(
                  onTap: _showServerConfigDialog,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.dns, color: Colors.white70, size: 14),
                        const SizedBox(width: 6),
                        Text(
                          "Server: ${ApiConstants.baseUrl}",
                          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LoginFields extends StatefulWidget {
  final TextEditingController loginIdController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onLogin;
  final bool isDark;

  const _LoginFields({
    required this.loginIdController,
    required this.passwordController,
    required this.isLoading,
    required this.onLogin,
    required this.isDark,
  });

  @override
  State<_LoginFields> createState() => _LoginFieldsState();
}

class _LoginFieldsState extends State<_LoginFields> {
  bool _obscurePassword = true;

  @override
  Widget build(BuildContext context) {
    const cardTextColor = Color(0xFF1f2937); 
    const cardSubTextColor = Color(0xFF6b7280);
    const inputFillColor = Color(0xFFf3f4f6);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Welcome Back',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 28,
            fontWeight: FontWeight.bold,
            color: cardTextColor,
          ),
        ),
        Text(
          'Sign in to continue',
          textAlign: TextAlign.center,
          style: GoogleFonts.poppins(
            fontSize: 14,
            color: cardSubTextColor,
          ),
        ),
        const SizedBox(height: 35),
        
        // Login ID Field
        Text(
          'Login ID',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cardTextColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.loginIdController,
          style: const TextStyle(color: cardTextColor, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Enter your ID',
            hintStyle: GoogleFonts.poppins(color: cardSubTextColor, fontSize: 14),
            filled: true,
            fillColor: inputFillColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        const SizedBox(height: 20),
        
        // Password Field
        Text(
          'Password',
          style: GoogleFonts.poppins(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: cardTextColor,
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: widget.passwordController,
          obscureText: _obscurePassword,
          style: const TextStyle(color: cardTextColor, fontSize: 16),
          decoration: InputDecoration(
            hintText: 'Enter Password',
            hintStyle: GoogleFonts.poppins(color: cardSubTextColor, fontSize: 14),
            filled: true,
            fillColor: inputFillColor,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            suffixIcon: IconButton(
              icon: Icon(
                _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                color: cardSubTextColor,
                size: 20,
              ),
              onPressed: () {
                setState(() {
                  _obscurePassword = !_obscurePassword;
                });
              },
            ),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(15),
              borderSide: BorderSide.none,
            ),
          ),
        ),
        
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
              );
            },
            child: Text(
              'Forgot Password?',
              style: GoogleFonts.poppins(
                color: const Color(0xFF2563eb),
                fontWeight: FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),
        
        // Login Button
        ElevatedButton(
          onPressed: widget.isLoading ? null : widget.onLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFF3b5998),
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 18),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
            elevation: 0,
          ),
          child: widget.isLoading
              ? const SizedBox(
                  height: 24, 
                  width: 24, 
                  child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                )
              : Text(
                  'Login',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold),
                ),
        ),
        const SizedBox(height: 25),
        
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text("Don't have an ID? ", style: GoogleFonts.poppins(color: cardSubTextColor, fontSize: 13)),
            GestureDetector(
              onTap: () {
                Navigator.push(context, MaterialPageRoute(builder: (context) => const SignupScreen()));
              },
              child: Text(
                'Create New ID',
                style: GoogleFonts.poppins(
                  color: const Color(0xFF2563eb), 
                  fontWeight: FontWeight.bold,
                  fontSize: 13,
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
