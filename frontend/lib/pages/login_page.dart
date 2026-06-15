import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'package:go_router/go_router.dart';

import '../core/api_constants.dart';
import '../core/services/auth_service.dart';
import '../core/services/hive_service.dart';
import '../widgets/login_card.dart';
import '../widgets/branding_section.dart';
import '../widgets/footer_section.dart';
import '../screens/auth/signup_screen.dart';
import '../screens/auth/forgot_password_screen.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  double _opacity = 0.0;

  @override
  void initState() {
    super.initState();
    // Fade-in animation on page load
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        setState(() {
          _opacity = 1.0;
        });
      }
    });
  }

  @override
  void dispose() {
    _loginIdController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    final inputId = _loginIdController.text.trim();
    final inputPass = _passwordController.text.trim();

    if (inputId.isEmpty || inputPass.isEmpty) {
      _showPopupResponse(
        title: 'Input Error',
        message: 'Please enter both Login ID and Password.',
        isError: true,
      );
      return;
    }

    setState(() => _isLoading = true);

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
      ).timeout(const Duration(seconds: 10));

      debugPrint("Login Response Status: ${response.statusCode}");
      debugPrint("Login Response Body: ${response.body}");

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final String? message = data['message'];
        final bool isSuccess = message != null && message.toLowerCase().contains('success');

        if (isSuccess || data['id'] != null) {
          final userData = {
            'id': data['id'],
            'full_name': data['full_name'],
            'role': data['role'],
            'login_id': data['login_id'],
            'branch': data['branch'],
            'year': data['year'],
            'semester': data['semester'],
            'batch_no': data['batch_no'],
            'section': data['section'],
          };

          // Check for profile update request (Self-Verification)
          if (mounted) {
            try {
              final checkUpdateUri = Uri.parse('${ApiConstants.baseUrl}/api/user/my-pending-update?userId=${userData['id'] ?? ''}');
              debugPrint("Checking for updates: $checkUpdateUri");
              final checkRes = await http.get(checkUpdateUri);

              if (checkRes.statusCode == 200) {
                final checkData = jsonDecode(checkRes.body);
                if (checkData['exists'] == true) {
                  bool? confirmUpdate = await showDialog<bool>(
                    context: context,
                    barrierDismissible: false,
                    builder: (ctx) => AlertDialog(
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      title: Text("Profile Update Pending", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      content: Text("You have requested to update your profile details. Do you want to apply these changes now?", style: GoogleFonts.poppins()),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, null),
                          child: Text("Reject", style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.w600)),
                        ),
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: Text("Later", style: GoogleFonts.poppins(color: Colors.grey[700])),
                        ),
                        ElevatedButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFF2F5AA8),
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                          child: Text("Yes, Update", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                        ),
                      ],
                    ),
                  );

                  if (confirmUpdate == true) {
                    final acceptUri = Uri.parse('${ApiConstants.baseUrl}/api/user/accept-my-update');
                    final acceptRes = await http.post(
                      acceptUri,
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({'userId': userData['id']}),
                    );

                    if (acceptRes.statusCode == 200) {
                      if (mounted) {
                        _showPopupResponse(
                          title: 'Profile Updated',
                          message: 'Your profile has been updated successfully. Please login with your new credentials.',
                          isError: false,
                        );
                        setState(() => _isLoading = false);
                        return; // Stop login flow, require re-login
                      }
                    } else {
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('Failed to update profile. Please try again later.', style: GoogleFonts.poppins()),
                            backgroundColor: Colors.redAccent,
                          ),
                        );
                      }
                    }
                  } else if (confirmUpdate == null) {
                    // REJECT -> Delete Request
                    final rejectUri = Uri.parse('${ApiConstants.baseUrl}/api/user/reject-my-update');
                    await http.post(
                      rejectUri,
                      headers: {'Content-Type': 'application/json'},
                      body: jsonEncode({'userId': userData['id']}),
                    );
                  }
                }
              }
            } catch (e) {
              debugPrint("Error checking pending updates: $e");
            }
          }

          if (mounted) {
            _showPopupResponse(
              title: 'Login Successful',
              message: 'Welcome back, ${userData['full_name']}!',
              isError: false,
            );

            await Future.delayed(const Duration(milliseconds: 1000));
            await AuthService.saveUserSession(userData);
            await HiveService.saveSession(userData);

            if (mounted) {
              context.go('/dashboard');
            }
          }
        } else {
          if (mounted) {
            _showPopupResponse(
              title: 'Access Denied',
              message: data['message'] ?? 'Invalid ID or Password.',
              isError: true,
            );
          }
        }
      } else {
        if (mounted) {
          String title = 'Login Failed';
          String msg = 'Something went wrong. Please try again.';

          if (response.statusCode == 401) {
            title = 'Access Denied';
            msg = 'Invalid ID or Password. Please try again.';
          } else {
            try {
              final errData = jsonDecode(response.body);
              if (errData['message'] != null) {
                String serverMsg = errData['message'];
                if (serverMsg.toLowerCase().contains('pending') ||
                    serverMsg.toLowerCase().contains('approved') ||
                    serverMsg.toLowerCase().contains('activated')) {
                  title = 'Account Pending';
                  msg = 'Your account is currently waiting for approval from the institution.';
                }
              }
            } catch (_) {}
          }

          _showPopupResponse(title: title, message: msg, isError: true);
        }
      }
    } catch (e) {
      debugPrint("Login Error: $e");
      if (mounted) {
        _showPopupResponse(
          title: 'Connection Error',
          message: 'Could not connect to the backend server. Please verify your connection.',
          isError: true,
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showPopupResponse({required String title, required String message, required bool isError}) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          width: 400,
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: (isError ? Colors.red : Colors.green).withValues(alpha: 0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isError ? Icons.error_outline_rounded : Icons.check_circle_outline_rounded,
                  color: isError ? Colors.red : Colors.green,
                  size: 48,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                title,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                  color: const Color(0xFF1E2B57),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                message,
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: const Color(0xFF6B7280),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 54,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: isError ? const Color(0xFF1E2B57) : const Color(0xFF2F5AA8),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    elevation: 0,
                  ),
                  child: Text(
                    isError ? 'Try Again' : 'Continue',
                    style: GoogleFonts.poppins(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedOpacity(
        duration: const Duration(milliseconds: 800),
        opacity: _opacity,
        child: Stack(
          children: [
            // 1. Full-screen Base Gradient (Sky & Backdrop)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Color(0xFF2F5AA8),
                      Color(0xFF4A86D9),
                      Color(0xFF1D4F91),
                    ],
                  ),
                ),
              ),
            ),

            // 2. Building Image aligned to the bottom (covers 48% height)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              height: MediaQuery.of(context).size.height * 0.48,
              child: Image.asset(
                'assets/images/alwar_das_background.png',
                fit: BoxFit.cover,
                alignment: const Alignment(0, -0.35),
                errorBuilder: (context, error, stackTrace) {
                  return const SizedBox.shrink();
                },
              ),
            ),

            // 3. Main Dark Blue Gradient Overlay (tints both sky and bottom building)
            Positioned.fill(
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xCC4A86D9),
                      Color(0xBB3E78C7),
                      Color(0xCC1D4F91),
                    ],
                  ),
                ),
              ),
            ),

            // 3. Main Content Scrollable Layer
            Positioned.fill(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final double width = constraints.maxWidth;
                  final bool isDesktop = width > 1200;
                  final bool isTablet = width >= 800 && width <= 1200;

                  return SafeArea(
                    child: Column(
                      children: [
                        Expanded(
                          child: SingleChildScrollView(
                            padding: const EdgeInsets.symmetric(vertical: 40),
                            child: Center(
                              child: isDesktop
                                  ? _buildDesktopLayout()
                                  : isTablet
                                      ? _buildTabletLayout()
                                      : _buildMobileLayout(),
                            ),
                          ),
                        ),
                        const FooterSection(),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopLayout() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 80),
      constraints: const BoxConstraints(maxWidth: 1400),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Expanded(
            flex: 11, // 55% Branding Section
            child: BrandingSection(isTablet: false),
          ),
          const SizedBox(width: 40),
          Expanded(
            flex: 9, // 45% Login Card Section
            child: Center(
              child: LoginCard(
                loginIdController: _loginIdController,
                passwordController: _passwordController,
                isLoading: _isLoading,
                onLogin: _handleLogin,
                onForgotPassword: _onForgotPassword,
                onCreateNewId: _onCreateNewId,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTabletLayout() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const BrandingSection(isTablet: true),
          const SizedBox(height: 48),
          LoginCard(
            loginIdController: _loginIdController,
            passwordController: _passwordController,
            isLoading: _isLoading,
            onLogin: _handleLogin,
            onForgotPassword: _onForgotPassword,
            onCreateNewId: _onCreateNewId,
          ),
        ],
      ),
    );
  }

  Widget _buildMobileLayout() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: LoginCard(
        loginIdController: _loginIdController,
        passwordController: _passwordController,
        isLoading: _isLoading,
        onLogin: _handleLogin,
        onForgotPassword: _onForgotPassword,
        onCreateNewId: _onCreateNewId,
      ),
    );
  }

  void _onForgotPassword() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const ForgotPasswordScreen()),
    );
  }

  void _onCreateNewId() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const SignupScreen()),
    );
  }
}
