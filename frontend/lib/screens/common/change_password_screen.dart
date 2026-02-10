import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../core/api_constants.dart';

class ChangePasswordScreen extends StatefulWidget {
  final String userId;
  final String userRole;

  const ChangePasswordScreen({super.key, required this.userId, required this.userRole});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _oldPasswordController = TextEditingController(); // Re-added
  final TextEditingController _newPasswordController = TextEditingController();
  final TextEditingController _confirmPasswordController = TextEditingController();
  bool _isLoading = false;
  bool _obscureOld = true; // Re-added
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  @override
  void dispose() {
    _oldPasswordController.dispose(); // Re-added
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _updatePassword() async {
    if (!_formKey.currentState!.validate()) return;

    if (_newPasswordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("New passwords do not match")),
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

      // Handle response code
      if (mounted) {
        setState(() => _isLoading = false);
        
        if (response.statusCode == 200) {
           showDialog(
            context: context,
            builder: (context) => AlertDialog(
              title: Text("Success", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              content: Text("Your password has been updated successfully.", style: GoogleFonts.poppins()),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context); // Close dialog
                    Navigator.pop(context); // Go back
                  },
                  child: const Text("OK"),
                )
              ],
            ),
          );
        } else {
          String errorMessage = "Failed to update password";
          try {
            if (response.body.isNotEmpty) {
              final data = jsonDecode(response.body);
              errorMessage = data['error'] ?? errorMessage;
            } else {
              errorMessage += " (Empty Response)";
            }
          } catch (_) {
             errorMessage += " (Invalid Response)";
          }
          
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(errorMessage)),
          );
        }
      }
    } catch (e) {
      if (mounted) {
         setState(() => _isLoading = false);
         ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e")),
         );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    
    return Scaffold(
      appBar: AppBar(
        title: Text("Change Password", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        iconTheme: IconThemeData(color: theme.iconTheme.color), 
         titleTextStyle: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Secure Your Account",
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Create a new password for your account. Make sure it's strong and secure.",
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 30),

              // Added Old Password Field check back
              _buildPasswordField(
                controller: _oldPasswordController,
                label: "Old Password",
                hint: "Enter current password",
                obscureText: _obscureOld,
                onToggleVisiblity: () => setState(() => _obscureOld = !_obscureOld),
                isDark: isDark,
                requireLength: false,
              ),
              const SizedBox(height: 20),

              _buildPasswordField(
                controller: _newPasswordController,
                label: "New Password",
                hint: "Enter new password",
                obscureText: _obscureNew,
                onToggleVisiblity: () => setState(() => _obscureNew = !_obscureNew),
                isDark: isDark,
                requireLength: true,
              ),
              const SizedBox(height: 20),

              _buildPasswordField(
                controller: _confirmPasswordController,
                label: "Confirm New Password",
                hint: "Re-enter new password",
                obscureText: _obscureConfirm,
                onToggleVisiblity: () => setState(() => _obscureConfirm = !_obscureConfirm),
                isDark: isDark,
                requireLength: true,
              ),

              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: _isLoading ? null : _updatePassword,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: _isLoading 
                    ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : Text("Update Password", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required bool obscureText,
    required VoidCallback onToggleVisiblity,
    required bool isDark,
    bool requireLength = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          validator: (val) {
             if (val == null || val.isEmpty) return "Please enter $label";
             if (requireLength && val.length < 6) return "Password must be at least 6 characters";
             return null;
          },
          style: GoogleFonts.poppins(),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.grey),
            prefixIcon: const Icon(Icons.lock_outline, color: Colors.grey),
            suffixIcon: IconButton(
              icon: Icon(obscureText ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: Colors.grey),
              onPressed: onToggleVisiblity,
            ),
            filled: true,
            fillColor: isDark ? const Color(0xFF1C1C2E) : Colors.grey[100],
             border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blueAccent),
            ),
          ),
        ),
      ],
    );
  }
}
