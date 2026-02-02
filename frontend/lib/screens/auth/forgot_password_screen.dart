import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../widgets/custom_text_field.dart';
import '../../theme/app_colors.dart';
import '../../core/api_constants.dart';
import '../../core/theme/app_theme.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _idController = TextEditingController();
  final _dobController = TextEditingController();
  bool _isLoading = false;

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }

  Future<void> _handleResetRequest() async {
    if (_idController.text.isEmpty || _dobController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
       return;
    }

    setState(() => _isLoading = true);

    try {
       final response = await http.post(
         Uri.parse(ApiConstants.forgotPasswordEndpoint),
         headers: {'Content-Type': 'application/json'},
         body: jsonEncode({
            'login_id': _idController.text,
            'dob': _dobController.text,
         }),
       );

       final data = jsonDecode(response.body);

       if (response.statusCode == 200) {
          String message = data['message'];
          String action = data['action'] ?? 'none';
          
          if (action == 'request_sent') {
             _showSuccessDialog("Request Sent", message);
          } else if (action == 'otp_sent') {
             _showOtpDialog(message);
          } else if (action == 'admin_contact') {
             _showErrorDialog("Admin Action Required", message);
          } else {
             _showSuccessDialog("Success", message);
          }
       } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Request Failed')));
       }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network Error')));
    } finally {
       if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSuccessDialog(String title, String message) {
     showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
           title: Text(title),
           content: Text(message),
           actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
           ],
        ),
     );
  }

  void _showErrorDialog(String title, String message) {
     showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
           title: Text(title, style: const TextStyle(color: Colors.red)),
           content: Text(message),
           actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))
           ],
        ),
     );
  }

  void _showOtpDialog(String message) {
     final otpController = TextEditingController();
     showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
           title: const Text("Enter OTP"),
           content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 Text(message),
                 const SizedBox(height: 10),
                 TextField(
                    controller: otpController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(hintText: "Enter OTP code"),
                 )
              ],
           ),
           actions: [
              TextButton(
                 onPressed: () {
                    // Start Password Reset (Verify OTP)
                    Navigator.pop(ctx);
                    // For now, simple success
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP Verified. You can now reset password.')));
                 },
                 child: const Text('Verify'),
              )
           ],
        ),
     );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.getAdaptiveOverlayStyle(true), // Gradient is dark
      child: Scaffold(
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: AppColors.forgotPasswordGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Forgot Password',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFF333333),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter your ID and Date of Birth to recover your account.',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 14,
                        color: const Color(0xFF666666),
                      ),
                    ),
                    const SizedBox(height: 30),

                    // ID Input
                    CustomTextField(
                      label: 'Login ID',
                      placeholder: 'Enter your ID',
                      controller: _idController,
                    ),

                    // DOB Input
                    CustomTextField(
                      label: 'Date of Birth',
                      placeholder: 'YYYY-MM-DD',
                      controller: _dobController,
                      readOnly: true,
                      onTap: () => _selectDate(context),
                      suffixIcon: const Icon(Icons.calendar_today, color: Color(0xFF666666)),
                    ),

                    // Submit Button
                    ElevatedButton(
                      onPressed: _isLoading ? null : _handleResetRequest,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF3B5998),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _isLoading 
                        ? const CircularProgressIndicator(color: Colors.white)
                        : Text(
                            'Submit Request',
                            style: GoogleFonts.poppins(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    ),
    );
  }
}
