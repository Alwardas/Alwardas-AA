import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'custom_text_field.dart';

class LoginCard extends StatefulWidget {
  final TextEditingController loginIdController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onLogin;
  final VoidCallback onForgotPassword;
  final VoidCallback onCreateNewId;

  const LoginCard({
    super.key,
    required this.loginIdController,
    required this.passwordController,
    required this.isLoading,
    required this.onLogin,
    required this.onForgotPassword,
    required this.onCreateNewId,
  });

  @override
  State<LoginCard> createState() => _LoginCardState();
}

class _LoginCardState extends State<LoginCard> {
  bool _isForgotPasswordHovered = false;
  bool _isCreateNewIdHovered = false;
  bool _isButtonHovered = false;

  @override
  Widget build(BuildContext context) {
    const Color darkText = Color(0xFF1E2B57);
    const Color lightText = Color(0xFF6B7280);
    const Color primaryBlue = Color(0xFF2F5AA8);

    return Center(
      child: Container(
        width: 580,
        constraints: const BoxConstraints(maxWidth: 580),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(24),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 15.0, sigmaY: 15.0),
            child: Container(
              padding: const EdgeInsets.all(48),
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: Colors.white.withValues(alpha: 0.2),
                  width: 1.5,
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Colors.black12,
                    blurRadius: 40,
                    offset: Offset(0, 20),
                  ),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Welcome Text
                  Text(
                    'Welcome Back',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 48,
                      fontWeight: FontWeight.w700,
                      color: darkText,
                      letterSpacing: -0.5,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Sign in to continue',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      color: lightText,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 40),

                  // Login ID Field
                  CustomTextField(
                    label: 'Login ID',
                    placeholder: 'Enter your ID',
                    controller: widget.loginIdController,
                    prefixIcon: Icons.person_outline,
                  ),

                  // Password Field
                  CustomTextField(
                    label: 'Password',
                    placeholder: 'Enter Password',
                    controller: widget.passwordController,
                    isPassword: true,
                    prefixIcon: Icons.lock_outline,
                  ),

                  // Forgot Password
                  Align(
                    alignment: Alignment.centerRight,
                    child: MouseRegion(
                      onEnter: (_) => setState(() => _isForgotPasswordHovered = true),
                      onExit: (_) => setState(() => _isForgotPasswordHovered = false),
                      cursor: SystemMouseCursors.click,
                      child: GestureDetector(
                        onTap: widget.onForgotPassword,
                        child: AnimatedDefaultTextStyle(
                          duration: const Duration(milliseconds: 200),
                          style: GoogleFonts.poppins(
                            color: primaryBlue,
                            fontWeight: FontWeight.w600,
                            fontSize: 15,
                            decoration: _isForgotPasswordHovered
                                ? TextDecoration.underline
                                : TextDecoration.none,
                          ),
                          child: const Text('Forgot Password?'),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Login Button with scale hover animation
                  MouseRegion(
                    onEnter: (_) => setState(() => _isButtonHovered = true),
                    onExit: (_) => setState(() => _isButtonHovered = false),
                    cursor: SystemMouseCursors.click,
                    child: AnimatedScale(
                      scale: _isButtonHovered ? 1.02 : 1.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: SizedBox(
                        height: 70,
                        child: ElevatedButton(
                          onPressed: widget.isLoading ? null : widget.onLogin,
                          style: ElevatedButton.styleFrom(
                            backgroundColor: primaryBlue,
                            foregroundColor: Colors.white,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            elevation: _isButtonHovered ? 8 : 2,
                            shadowColor: primaryBlue.withValues(alpha: 0.4),
                          ),
                          child: widget.isLoading
                              ? const SizedBox(
                                  height: 28,
                                  width: 28,
                                  child: CircularProgressIndicator(
                                    color: Colors.white,
                                    strokeWidth: 3,
                                  ),
                                )
                              : Text(
                                  'Login',
                                  style: GoogleFonts.poppins(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // OR Divider
                  Row(
                    children: [
                      const Expanded(
                        child: Divider(
                          color: Color(0xFFE5E7EB),
                          thickness: 1.5,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        child: Text(
                          'OR',
                          style: GoogleFonts.poppins(
                            color: const Color(0xFF9CA3AF),
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const Expanded(
                        child: Divider(
                          color: Color(0xFFE5E7EB),
                          thickness: 1.5,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),

                  // Create New ID
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        "Don't have an ID? ",
                        style: GoogleFonts.poppins(
                          color: lightText,
                          fontSize: 15,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      MouseRegion(
                        onEnter: (_) => setState(() => _isCreateNewIdHovered = true),
                        onExit: (_) => setState(() => _isCreateNewIdHovered = false),
                        cursor: SystemMouseCursors.click,
                        child: GestureDetector(
                          onTap: widget.onCreateNewId,
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: GoogleFonts.poppins(
                              color: primaryBlue,
                              fontWeight: FontWeight.w700,
                              fontSize: 15,
                              decoration: _isCreateNewIdHovered
                                  ? TextDecoration.underline
                                  : TextDecoration.none,
                            ),
                            child: const Text('Create New ID'),
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
      ),
    );
  }
}
