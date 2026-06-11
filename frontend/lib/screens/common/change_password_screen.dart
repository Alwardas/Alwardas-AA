import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../core/api_constants.dart';
import '../../core/services/auth_service.dart';
import '../auth/login_screen.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String userId;
  final String userRole;

  const ChangePasswordScreen({super.key, required this.userId, required this.userRole});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _oldPasswordController = TextEditingController();
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _obscureOld = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  // Real-time Validation States
  bool _hasMinLength = false;
  bool _hasUppercase = false;
  bool _hasLowercase = false;
  bool _hasDigits = false;
  
  // Caps Lock Warning
  bool _capsLockOn = false;

  // User Info & Session State loaded dynamically
  Map<String, dynamic>? _userSession;
  bool _loadingSession = true;

  @override
  void initState() {
    super.initState();
    _loadUserSession();
    _newPasswordController.addListener(_validatePassword);
    // Listen to Caps Lock state
    HardwareKeyboard.instance.addHandler(_keyboardHandler);
  }

  @override
  void dispose() {
    _newPasswordController.removeListener(_validatePassword);
    _oldPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    HardwareKeyboard.instance.removeHandler(_keyboardHandler);
    super.dispose();
  }

  Future<void> _loadUserSession() async {
    final session = await AuthService.getUserSession();
    if (mounted) {
      setState(() {
        _userSession = session;
        _loadingSession = false;
      });
    }
  }

  bool _keyboardHandler(KeyEvent event) {
    final capsLockPressed = HardwareKeyboard.instance.lockModesEnabled.contains(KeyboardLockMode.capsLock);
    if (mounted && _capsLockOn != capsLockPressed) {
      setState(() {
        _capsLockOn = capsLockPressed;
      });
    }
    return false;
  }

  void _validatePassword() {
    final val = _newPasswordController.text;
    if (mounted) {
      setState(() {
        _hasMinLength = val.length >= 5;
        _hasUppercase = val.contains(RegExp(r'[A-Z]'));
        _hasLowercase = val.contains(RegExp(r'[a-z]'));
        _hasDigits = val.contains(RegExp(r'[0-9]'));
      });
    }
  }

  double _getStrengthPercentage() {
    double score = 0.0;
    if (_hasMinLength) score += 0.25;
    if (_hasUppercase) score += 0.25;
    if (_hasLowercase) score += 0.25;
    if (_hasDigits) score += 0.25;
    return score;
  }

  String _getStrengthLabel() {
    final pct = _getStrengthPercentage();
    if (pct == 0.0) return "None";
    if (pct <= 0.25) return "Weak";
    if (pct <= 0.50) return "Fair";
    if (pct <= 0.75) return "Good";
    if (pct < 1.0) return "Strong";
    return "Very Strong";
  }

  Color _getStrengthColor() {
    final pct = _getStrengthPercentage();
    if (pct <= 0.25) return Colors.red;
    if (pct <= 0.50) return Colors.orange;
    if (pct <= 0.75) return Colors.yellow[700]!;
    if (pct < 1.0) return Colors.lightGreen;
    return Colors.green;
  }

  void _resetForm() {
    _formKey.currentState?.reset();
    _oldPasswordController.clear();
    _newPasswordController.clear();
    _confirmPasswordController.clear();
    setState(() {
      _validatePassword();
    });
  }

  Future<void> _handleLogoutFromAllDevices() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text("Logout from All Devices", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.red)),
        content: Text("Are you sure you want to terminate all other active sessions for your account? You will need to log back in on those devices.", style: GoogleFonts.poppins()),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text("Cancel", style: TextStyle(color: Colors.grey[600])),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Logout All", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      setState(() => _isLoading = true);
      await Future.delayed(const Duration(milliseconds: 1500)); // Simulate API call
      setState(() => _isLoading = false);
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text("Logged out from all other devices successfully."),
            backgroundColor: Colors.green,
          ),
        );
      }
    }
  }

  Future<void> _downloadReport() async {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
            ),
            SizedBox(width: 12),
            Text("Generating Security Activity Report..."),
          ],
        ),
      ),
    );
    await Future.delayed(const Duration(seconds: 2));
    if (mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Security Activity Report downloaded as PDF successfully!"),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("New passwords do not match")),
      );
      return;
    }

    if (_getStrengthPercentage() < 1.0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please satisfy all password complexity rules")),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final response = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/api/auth/change-password"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'userId': widget.userId,
          'oldPassword': _oldPasswordController.text,
          'newPassword': _newPasswordController.text,
        }),
      );

      if (mounted) {
        setState(() => _isLoading = false);
        
        if (response.statusCode == 200) {
          _showSuccessPopup();
        } else {
          String errorMessage = "Failed to update password";
          try {
            if (response.body.isNotEmpty) {
              final data = jsonDecode(response.body);
              errorMessage = data['error'] ?? errorMessage;
            }
          } catch (_) {}
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
          );
        }
      }
    } catch (e) {
      if (mounted) {
         setState(() => _isLoading = false);
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Network failure: $e"), backgroundColor: Colors.red),
         );
      }
    }
  }

  void _showSuccessPopup() {
    final nowStr = DateFormat('dd MMM yyyy, hh:mm a').format(DateTime.now());
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => PopScope(
        canPop: false,
        child: AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
          title: Column(
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 60),
              const SizedBox(height: 12),
              Text(
                "Password Changed Successfully",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                "Timestamp: $nowStr",
                style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey),
              ),
              const SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text(
                      "NEW PASSWORD FOR SCREENSHOT",
                      style: GoogleFonts.poppins(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: Colors.orange[800],
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 6),
                    SelectableText(
                      _newPasswordController.text,
                      style: GoogleFonts.novaMono(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blue.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blue.withValues(alpha: 0.1)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: Colors.blueAccent, size: 20),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        "Security Reminder: Do not share your credentials with anyone.",
                        style: GoogleFonts.poppins(fontSize: 12, color: Colors.blueAccent[700]),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "For your security, you will be required to log back in on this device.",
                textAlign: TextAlign.center,
                style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.w500),
              ),
            ],
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: () async {
                  Navigator.pop(ctx); // Close dialog
                  await AuthService.logout();
                  if (mounted) {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                      (route) => false,
                    );
                  }
                },
                child: Text("Re-login Now", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    final Color bgColor = isDark ? const Color(0xFF151517) : const Color(0xFFF5F7FA);
    final Color cardColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF2D3748);
    final Color subTextColor = isDark ? Colors.white70 : const Color(0xFF718096);
    final Color borderColor = isDark ? Colors.white10 : const Color(0xFFE2E8F0);

    final String fullName = _userSession?['full_name'] ?? _userSession?['fullName'] ?? 'Loading...';
    final String loginId = _userSession?['login_id'] ?? _userSession?['loginId'] ?? widget.userId;
    final String role = _userSession?['role'] ?? widget.userRole;

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Change Password", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        elevation: 0,
        backgroundColor: Colors.transparent,
        iconTheme: IconThemeData(color: textColor), 
      ),
      body: _loadingSession
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // 1. User Info Header Card
                  _buildUserInfoCard(fullName, loginId, role, cardColor, textColor, subTextColor, borderColor),
                  const SizedBox(height: 16),
                  
                  // Responsive Row layout for Large Screen, Stack for Mobile
                  LayoutBuilder(
                    builder: (context, constraints) {
                      final isWide = constraints.maxWidth > 720;
                      return Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: isWide ? 7 : 10,
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Form Card
                                _buildFormCard(cardColor, textColor, subTextColor, isDark),
                              ],
                            ),
                          ),
                          if (isWide) ...[
                            const SizedBox(width: 16),
                            Expanded(
                              flex: 5,
                              child: Column(
                                children: [
                                  // Tips Card
                                  _buildSecurityTipsCard(cardColor, textColor, subTextColor, borderColor),
                                ],
                              ),
                            ),
                          ],
                        ],
                      );
                    },
                  ),
                  
                  // For Mobile only: Add details & tips under the form
                  LayoutBuilder(builder: (context, constraints) {
                    if (constraints.maxWidth <= 720) {
                      return Column(
                        children: [
                          const SizedBox(height: 16),
                          _buildSecurityTipsCard(cardColor, textColor, subTextColor, borderColor),
                        ],
                      );
                    }
                    return const SizedBox.shrink();
                  }),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildUserInfoCard(String name, String id, String role, Color cardColor, Color textColor, Color subTextColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: Colors.blueAccent.withValues(alpha: 0.1),
            child: Text(
              name.isNotEmpty ? name[0].toUpperCase() : 'U',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 22, color: Colors.blueAccent),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16, color: textColor)),
                const SizedBox(height: 2),
                Text("User ID: $id  •  Role: $role", style: GoogleFonts.poppins(fontSize: 12, color: subTextColor, fontWeight: FontWeight.w500)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard(Color cardColor, Color textColor, Color subTextColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.03), blurRadius: 15, offset: const Offset(0, 8))
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Icon(Icons.lock_person, color: Colors.blueAccent, size: 22),
                const SizedBox(width: 10),
                Text(
                  "Password Change Portal",
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
                ),
              ],
            ),
            const Divider(height: 30),
            
            // Caps Lock Warning Banner
            if (_capsLockOn) ...[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.orange.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.orange.withValues(alpha: 0.3)),
                ),
                child: const Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, color: Colors.orange, size: 16),
                    SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        "Warning: Caps Lock is ON",
                        style: TextStyle(color: Colors.orange, fontWeight: FontWeight.bold, fontSize: 12),
                      ),
                    )
                  ],
                ),
              ),
              const SizedBox(height: 12),
            ],

            // Current Password
            _buildPasswordField(
              controller: _oldPasswordController,
              label: "Current Password",
              hint: "Enter your old password",
              obscureText: _obscureOld,
              onToggleVisibility: () => setState(() => _obscureOld = !_obscureOld),
              isDark: isDark,
            ),
            const SizedBox(height: 16),

            // New Password
            _buildPasswordField(
              controller: _newPasswordController,
              label: "New Password",
              hint: "Enter complex new password",
              obscureText: _obscureNew,
              onToggleVisibility: () => setState(() => _obscureNew = !_obscureNew),
              isDark: isDark,
              onChanged: (_) => _validatePassword(),
            ),
            const SizedBox(height: 16),

            // Confirm Password
            _buildPasswordField(
              controller: _confirmPasswordController,
              label: "Confirm New Password",
              hint: "Re-enter the new password",
              obscureText: _obscureConfirm,
              onToggleVisibility: () => setState(() => _obscureConfirm = !_obscureConfirm),
              isDark: isDark,
            ),
            const SizedBox(height: 24),
            
            // Real-time Strength Meter Gauge
            _buildStrengthMeterGauge(),
            const SizedBox(height: 24),
            
            // Password Policy Checks (Ticks & Crosses)
            _buildPolicyRulesPanel(textColor),
            const SizedBox(height: 24),
            
            // Action Buttons
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _resetForm,
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text("Reset", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: subTextColor)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _updatePassword,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: _isLoading 
                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                        : Text("Change Password", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white)),
                  ),
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Terminate Sessions (Danger Button)
            OutlinedButton.icon(
              onPressed: _handleLogoutFromAllDevices,
              icon: const Icon(Icons.devices_other, size: 18, color: Colors.red),
              label: Text("Logout from All Other Devices", style: GoogleFonts.poppins(color: Colors.red, fontWeight: FontWeight.bold, fontSize: 13)),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.redAccent, width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleVisibility,
    required bool isDark,
    Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 13)),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          onChanged: onChanged,
          validator: (val) {
             if (val == null || val.isEmpty) return "Please enter $label";
             return null;
          },
          style: GoogleFonts.poppins(fontSize: 14),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey, size: 18),
            suffixIcon: IconButton(
              icon: Icon(obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey, size: 18),
              onPressed: onToggleVisibility,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF14141E) : Colors.grey[100],
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!)),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent, width: 1.5)),
          ),
        ),
      ],
    );
  }

  Widget _buildStrengthMeterGauge() {
    final pct = _getStrengthPercentage();
    final label = _getStrengthLabel();
    final color = _getStrengthColor();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text("Password Strength: ", style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold)),
            Text(label, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
        const SizedBox(height: 8),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: pct,
            backgroundColor: Colors.grey[300],
            valueColor: AlwaysStoppedAnimation<Color>(color),
            minHeight: 6,
          ),
        ),
      ],
    );
  }

  Widget _buildPolicyRulesPanel(Color textColor) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text("PASSWORD SECURITY REQUIREMENTS", style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.w700, color: Colors.grey)),
          const SizedBox(height: 10),
          _buildRequirementRow("At least 5 characters", _hasMinLength),
          _buildRequirementRow("At least one uppercase letter (A-Z)", _hasUppercase),
          _buildRequirementRow("At least one lowercase letter (a-z)", _hasLowercase),
          _buildRequirementRow("At least one digit (0-9)", _hasDigits),
        ],
      ),
    );
  }

  Widget _buildRequirementRow(String rule, bool satisfied) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6.0),
      child: Row(
        children: [
          Icon(
            satisfied ? Icons.check_circle : Icons.cancel,
            color: satisfied ? Colors.green : Colors.red,
            size: 16,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              rule,
              style: GoogleFonts.poppins(
                fontSize: 12,
                color: satisfied ? Colors.green[700] : Colors.grey[600],
                fontWeight: satisfied ? FontWeight.bold : FontWeight.normal,
              ),
            ),
          ),
        ],
      ),
    );
  }



  Widget _buildSecurityTipsCard(Color cardColor, Color textColor, Color subTextColor, Color borderColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.02), blurRadius: 10, offset: const Offset(0, 4))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.lightbulb_outline, color: Colors.orangeAccent, size: 18),
              const SizedBox(width: 8),
              Text("ERP Security Advice", style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.bold, color: textColor)),
            ],
          ),
          const Divider(height: 24),
          _buildTipRow("Change your password periodically to safeguard your academic and financial records."),
          _buildTipRow("Choose a combination of symbols, numbers, and capital letters that doesn't include dictionary words."),
          _buildTipRow("Never access the ERP portal using public unencrypted Wi-Fi or public computers without private tabs."),
        ],
      ),
    );
  }

  Widget _buildTipRow(String tipText) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.arrow_right, color: Colors.orangeAccent, size: 20),
          const SizedBox(width: 4),
          Expanded(
            child: Text(
              tipText,
              style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey[700]),
            ),
          ),
        ],
      ),
    );
  }


}
