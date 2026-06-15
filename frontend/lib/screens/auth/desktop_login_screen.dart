import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:go_router/go_router.dart';

import '../../core/api_constants.dart';
import '../../core/services/hive_service.dart';

class DesktopLoginScreen extends StatefulWidget {
  const DesktopLoginScreen({super.key});

  @override
  State<DesktopLoginScreen> createState() => _DesktopLoginScreenState();
}

class _DesktopLoginScreenState extends State<DesktopLoginScreen> {
  final _loginIdController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;

  Future<void> _handleLogin() async {
    final inputId = _loginIdController.text.trim();
    final inputPass = _passwordController.text.trim();

    if (inputId.isEmpty || inputPass.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your Login ID and Password.')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final uri = Uri.parse(ApiConstants.loginEndpoint);
      final response = await http.post(
        uri,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'login_id': inputId,
          'password': inputPass,
        }),
      );

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

          // Save Session to Hive (which GoRouter redirect uses)
          await HiveService.saveSession(userData);

          if (mounted) {
            context.go('/dashboard');
          }
        } else {
          _showErrorDialog('Access Denied', data['message'] ?? 'Invalid ID or Password.');
        }
      } else {
        _showErrorDialog('Login Failed', 'Invalid credentials or server error. Status: ${response.statusCode}');
      }
    } catch (e) {
      _showErrorDialog('Network Error', 'Could not connect to the backend server. Please verify your connection.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorDialog(String title, String message) {
    if (!mounted) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        content: Text(message, style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Background Image
          Positioned.fill(
            child: Image.network(
              'https://images.unsplash.com/photo-1541339907198-e08756dedf3f?ixlib=rb-1.2.1&auto=format&fit=crop&w=1920&q=80',
              fit: BoxFit.cover,
              color: Colors.black.withOpacity(0.3),
              colorBlendMode: BlendMode.darken,
              errorBuilder: (context, error, stackTrace) {
                return Container(color: const Color(0xFF3b5998));
              },
            ),
          ),

          // Main Layout
          Positioned.fill(
            child: Column(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      // Left Side (Logo & Text)
                      Expanded(
                        flex: 5,
                        child: Padding(
                          padding: const EdgeInsets.only(left: 80, top: 120),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Mock Logo area
                              Image.asset(
                                'assets/images/college logo.png', // Try this first
                                width: 380,
                                errorBuilder: (context, error, stackTrace) {
                                  return Image.asset(
                                    'assets/images/logo.png', // Fallback
                                    width: 380,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'alwar das group',
                                            style: GoogleFonts.poppins(
                                              color: const Color(0xFF2563EB),
                                              fontSize: 48,
                                              fontWeight: FontWeight.bold,
                                              height: 1.1,
                                            ),
                                          ),
                                          Text(
                                            'free mind through education',
                                            style: GoogleFonts.caveat(
                                              color: const Color(0xFFDC2626),
                                              fontSize: 32,
                                              height: 1.2,
                                            ),
                                          ),
                                        ],
                                      );
                                    },
                                  );
                                },
                              ),
                              const SizedBox(height: 60),
                              
                              // Feature Icons
                              Row(
                                children: [
                                  _buildFeatureItem(Icons.school, 'Quality\nEducation'),
                                  Container(width: 1, height: 40, color: Colors.white54, margin: const EdgeInsets.symmetric(horizontal: 24)),
                                  _buildFeatureItem(Icons.menu_book, 'Holistic\nDevelopment'),
                                  Container(width: 1, height: 40, color: Colors.white54, margin: const EdgeInsets.symmetric(horizontal: 24)),
                                  _buildFeatureItem(Icons.group, 'Bright\nFuture'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                      
                      // Right Side (Login Card)
                      Expanded(
                        flex: 5,
                        child: Center(
                          child: Container(
                            constraints: const BoxConstraints(maxWidth: 500),
                            padding: const EdgeInsets.symmetric(horizontal: 56, vertical: 48),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(20),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.15),
                                  blurRadius: 40,
                                  offset: const Offset(0, 15),
                                ),
                              ],
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Text(
                                  'Welcome Back',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Sign in to continue',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.inter(
                                    fontSize: 16,
                                    color: const Color(0xFF64748B),
                                  ),
                                ),
                                const SizedBox(height: 40),

                                // Login ID
                                Text(
                                  'Login ID',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _loginIdController,
                                  decoration: InputDecoration(
                                    hintText: 'Enter your ID',
                                    hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                                    filled: true,
                                    fillColor: const Color(0xFFF1F5F9),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    suffixIcon: const Icon(Icons.person_outline, color: Color(0xFF94A3B8)),
                                  ),
                                ),
                                const SizedBox(height: 24),

                                // Password
                                Text(
                                  'Password',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF1E293B),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                TextField(
                                  controller: _passwordController,
                                  obscureText: _obscurePassword,
                                  decoration: InputDecoration(
                                    hintText: 'Enter Password',
                                    hintStyle: GoogleFonts.inter(color: const Color(0xFF94A3B8)),
                                    filled: true,
                                    fillColor: const Color(0xFFF1F5F9),
                                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                      borderSide: BorderSide.none,
                                    ),
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                                        color: const Color(0xFF94A3B8),
                                      ),
                                      onPressed: () {
                                        setState(() {
                                          _obscurePassword = !_obscurePassword;
                                        });
                                      },
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),

                                // Forgot Password
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: TextButton(
                                    onPressed: () {},
                                    child: Text(
                                      'Forgot Password?',
                                      style: GoogleFonts.inter(
                                        color: const Color(0xFF2E518E),
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 16),

                                // Login Button
                                ElevatedButton(
                                  onPressed: _isLoading ? null : _handleLogin,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: const Color(0xFF2E518E), // Match dark blue
                                    foregroundColor: Colors.white,
                                    padding: const EdgeInsets.symmetric(vertical: 20),
                                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                    elevation: 0,
                                  ),
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 24,
                                          width: 24,
                                          child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                                        )
                                      : Text(
                                          'Login',
                                          style: GoogleFonts.inter(fontSize: 16, fontWeight: FontWeight.bold),
                                        ),
                                ),
                                const SizedBox(height: 32),

                                // OR Divider
                                Row(
                                  children: [
                                    Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                                    Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      child: Text(
                                        'OR',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF94A3B8),
                                          fontSize: 12,
                                        ),
                                      ),
                                    ),
                                    Expanded(child: Divider(color: Colors.grey[300], thickness: 1)),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Create New ID
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "Don't have an ID? ",
                                      style: GoogleFonts.inter(color: const Color(0xFF64748B), fontSize: 14),
                                    ),
                                    TextButton(
                                      onPressed: () {},
                                      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
                                      child: Text(
                                        'Create New ID',
                                        style: GoogleFonts.inter(
                                          color: const Color(0xFF2E518E),
                                          fontWeight: FontWeight.bold,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Footer
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 60, vertical: 24),
                  color: const Color(0xFF1E3A5F).withOpacity(0.95), // Dark blue footer
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '© 2025 Alwar Das Group. All Rights Reserved.',
                        style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
                      ),
                      Row(
                        children: [
                          _buildFooterLink('Privacy Policy'),
                          _buildFooterDivider(),
                          _buildFooterLink('Terms of Use'),
                          _buildFooterDivider(),
                          _buildFooterLink('Support'),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 14),
        Text(
          text,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontWeight: FontWeight.bold,
            fontSize: 15,
            height: 1.3,
          ),
        ),
      ],
    );
  }

  Widget _buildFooterLink(String text) {
    return TextButton(
      onPressed: () {},
      style: TextButton.styleFrom(padding: EdgeInsets.zero, minimumSize: const Size(0, 0)),
      child: Text(
        text,
        style: GoogleFonts.inter(color: Colors.white70, fontSize: 14),
      ),
    );
  }

  Widget _buildFooterDivider() {
    return Container(
      width: 1,
      height: 14,
      color: Colors.white30,
      margin: const EdgeInsets.symmetric(horizontal: 16),
    );
  }
}

