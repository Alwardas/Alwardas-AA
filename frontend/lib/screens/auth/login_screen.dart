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

      try {
        final uri = Uri.parse(ApiConstants.loginEndpoint);
        debugPrint("Attempting login to: $uri");

        final response = await http.post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'login_id': inputId,
            'password': inputPass,
          }),
        );

        debugPrint("Login Response Status: ${response.statusCode}");
        debugPrint("Login Response Body: ${response.body}");

        if (response.statusCode == 200) {
          final data = jsonDecode(response.body);
          
          // Debug backend response
          debugPrint("Parsed Data Keys: ${data.keys.toList()}");

          // Backend returns: { "id": "uuid", "message": "Login Successful", "role": "Student", "fullName": "Name", "loginId": "ID", ... }
          // It does NOT return { "success": true, "user_profile": ... }
          
          final String? message = data['message'];
          final bool isSuccess = message != null && message.toLowerCase().contains('success');
          
          if (isSuccess || data['id'] != null) {
             // Extract fields directly from top-level JSON
             // Note: Rust structs use camelCase in JSON if annotated, or snake_case if default.
             // Checking models.rs: AuthResponse fields are default pub fields. 
             // BUT `signup_handler` returns Json(AuthResponse { ... }). Default serde is snake_case unless `rename_all` is used.
             // Looking at models.rs: AuthResponse doesn't have `#[serde(rename_all = "camelCase")]`.
             // So keys are likely: "full_name", "login_id", "batch_no".
             
             final userData = {
              'id': data['id'],
              'full_name': data['full_name'], // Expect snake_case from Rust default
              'role': data['role'],
              'login_id': data['login_id'],
              'branch': data['branch'],
              'year': data['year'],
              'semester': data['semester'], 
              'batch_no': data['batch_no'],
             };

             debugPrint("DEBUG: UserData constructed: $userData");

            if (mounted) {
              _showPopupResponse(
                title: 'Login Successful',
                message: 'Welcome back, ${userData['full_name']}!',
                isError: false,
              );
              await Future.delayed(const Duration(milliseconds: 800)); // Brief pause for user to see success
              await AuthService.saveUserSession(userData);
              Widget dashboard = _getDashboardForRole(userData['role'], userData);
              if (mounted) {
                Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => dashboard));
              }
            }
          } else {
             if (mounted) {
              _showPopupResponse(
                title: 'Access Denied',
                message: data['message'] ?? 'Invalid ID or Password',
                isError: true,
              );
             }
          }
        } else {
           if (mounted) {
            String msg = 'The server returned an error (${response.statusCode})';
            String title = 'Server Error';
            
            try {
               final errData = jsonDecode(response.body);
               if (errData['message'] != null) {
                 msg = errData['message'];
                 if (msg.toLowerCase().contains('pending') || msg.toLowerCase().contains('approved')) {
                   title = 'Account Pending';
                 }
               }
            } catch (_) {}
            
            _showPopupResponse(title: title, message: msg, isError: true);
           }
        }

      } catch (e) {
        debugPrint("Login Error: $e");
        
        String title = 'Connection Failed';
        String errorMessage = 'We couldn\'t reach the campus server.';
        
        if (e.toString().contains('SocketException') || e.toString().contains('Connection refused')) {
           errorMessage = '1. Check your internet connection.\n2. Ensure you are on the college network if required.\n3. The backend might be offline.';
        }

        if (mounted) {
          _showPopupResponse(title: title, message: errorMessage, isError: true);
        }
      } finally {
        if (mounted) setState(() => _isLoading = false);
      }
    }

  void _showPopupResponse({required String title, required String message, required bool isError}) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          padding: const EdgeInsets.all(28),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: (isError ? Colors.red : Colors.green).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                  color: isError ? Colors.red : Colors.green,
                  size: 40,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1F2937),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 14,
                  color: const Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isError ? Colors.grey[800] : const Color(0xFF3b5998),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    isError ? 'Try Again' : 'Continue',
                    style: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getDashboardForRole(String? role, Map<String, dynamic> userData) {
    debugPrint("Getting dashboard for role: '$role'");
    final normalizedRole = role?.trim() ?? '';
    
    // Case-insensitive match or direct match
    if (normalizedRole.toLowerCase() == 'student') return StudentDashboard(userData: userData);
    if (normalizedRole.toLowerCase() == 'parent') return ParentDashboard(userData: userData);
    if (normalizedRole.toLowerCase() == 'faculty') return FacultyDashboard(userData: userData);
    if (normalizedRole.toLowerCase() == 'hod') return HodDashboard(userData: userData);
    if (normalizedRole.toLowerCase() == 'principal') return PrincipalDashboard(userData: userData);
    if (normalizedRole.toLowerCase() == 'admin') return AdminDashboard(userData: userData);
    if (normalizedRole.toLowerCase() == 'coordinator') return CoordinatorDashboard(userData: userData);

    return Scaffold(
      appBar: AppBar(title: const Text("Unknown Role")),
      body: Center(child: Text("Unknown Role: '$role'")),
    );
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
