import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:url_launcher/url_launcher.dart';

class MobileLoginCard extends StatefulWidget {
  final TextEditingController loginIdController;
  final TextEditingController passwordController;
  final bool isLoading;
  final VoidCallback onLogin;
  final VoidCallback onForgotPassword;
  final VoidCallback onCreateNewId;

  const MobileLoginCard({
    super.key,
    required this.loginIdController,
    required this.passwordController,
    required this.isLoading,
    required this.onLogin,
    required this.onForgotPassword,
    required this.onCreateNewId,
  });

  @override
  State<MobileLoginCard> createState() => _MobileLoginCardState();
}

class _MobileLoginCardState extends State<MobileLoginCard> {
  bool _obscureText = true;

  @override
  Widget build(BuildContext context) {
    const Color darkText = Color(0xFF1E2B57);
    const Color lightText = Color(0xFF6B7280);
    const Color primaryBlue = Color(0xFF2F5AA8);
    const Color buttonColor = Color(0xFF3B5998); // Muted slate-blue button color from screenshot
    const Color inputBgColor = Color(0xFFF3F4F6); // Soft light grey/blue background for input fields

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(28),
        boxShadow: const [
          BoxShadow(
            color: Colors.black12,
            blurRadius: 15,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title: Welcome Back
          Center(
            child: Text(
              'Welcome Back',
              style: GoogleFonts.poppins(
                fontSize: 26,
                fontWeight: FontWeight.w700,
                color: darkText,
                letterSpacing: -0.5,
              ),
            ),
          ),
          const SizedBox(height: 4),
          // Subtitle: Sign in to continue
          Center(
            child: Text(
              'Sign in to continue',
              style: GoogleFonts.poppins(
                fontSize: 14,
                color: lightText,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Login ID Label
          Text(
            'Login ID',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: darkText,
            ),
          ),
          const SizedBox(height: 6),
          // Login ID Input
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: inputBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: TextField(
                controller: widget.loginIdController,
                style: GoogleFonts.poppins(
                  fontSize: 15,
                  color: darkText,
                  fontWeight: FontWeight.w500,
                ),
                decoration: InputDecoration(
                  hintText: 'Enter your ID',
                  hintStyle: GoogleFonts.poppins(
                    color: lightText.withValues(alpha: 0.6),
                    fontSize: 14,
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                ),
              ),
            ),
          ),
          const SizedBox(height: 14),

          // Password Label
          Text(
            'Password',
            style: GoogleFonts.poppins(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: darkText,
            ),
          ),
          const SizedBox(height: 6),
          // Password Input
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: inputBgColor,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextField(
              controller: widget.passwordController,
              obscureText: _obscureText,
              textAlignVertical: TextAlignVertical.center,
              style: GoogleFonts.poppins(
                fontSize: 15,
                color: darkText,
                fontWeight: FontWeight.w500,
              ),
              decoration: InputDecoration(
                hintText: 'Enter Password',
                hintStyle: GoogleFonts.poppins(
                  color: lightText.withValues(alpha: 0.6),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(horizontal: 16),
                suffixIcon: IconButton(
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                  icon: Icon(
                    _obscureText
                        ? Icons.visibility_outlined
                        : Icons.visibility_off_outlined,
                    color: lightText.withValues(alpha: 0.6),
                    size: 20,
                  ),
                  onPressed: () {
                    setState(() {
                      _obscureText = !_obscureText;
                    });
                  },
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // Forgot Password link (aligned right)
          Align(
            alignment: Alignment.centerRight,
            child: GestureDetector(
              onTap: widget.onForgotPassword,
              child: Text(
                'Forgot Password?',
                style: GoogleFonts.poppins(
                  color: primaryBlue,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                ),
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Login Button
          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              onPressed: widget.isLoading ? null : widget.onLogin,
              style: ElevatedButton.styleFrom(
                backgroundColor: buttonColor,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                elevation: 0,
              ),
              child: widget.isLoading
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(
                        color: Colors.white,
                        strokeWidth: 2.0,
                      ),
                    )
                  : Text(
                      'Login',
                      style: GoogleFonts.poppins(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.5,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 24),

          // Footer: Don't have an ID? Create New ID
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                "Don't have an ID? ",
                style: GoogleFonts.poppins(
                  color: lightText,
                  fontSize: 13,
                  fontWeight: FontWeight.w500,
                ),
              ),
              GestureDetector(
                onTap: widget.onCreateNewId,
                child: Text(
                  'Create New ID',
                  style: GoogleFonts.poppins(
                    color: primaryBlue,
                    fontWeight: FontWeight.w700,
                    fontSize: 13,
                  ),
                ),
              ),
            ],
          ),
          if (kIsWeb) ...[
            const SizedBox(height: 16),
            Center(
              child: TextButton.icon(
                onPressed: () async {
                  final url = Uri.parse('${Uri.base.origin}/app-release.apk');
                  if (await canLaunchUrl(url)) {
                    await launchUrl(url, mode: LaunchMode.externalApplication);
                  }
                },
                icon: const Icon(Icons.android, color: Colors.green, size: 20),
                label: Text(
                  'Download Android App',
                  style: GoogleFonts.poppins(
                    color: primaryBlue,
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
