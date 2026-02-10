import 'package:flutter/material.dart';

class AppColors {
  // Login Screen Gradient
  static const List<Color> loginGradient = [
    Color(0xFF005EB8),
    Color(0xFFc3c9cf),
    Color(0xFF001F3F),
  ];

  // Signup Screen Gradient
  static const List<Color> signupGradient = [
    Color(0xFF4c669f),
    Color(0xFF3b5998),
    Color(0xFF192f6a),
  ];

  // Forgot Password Gradient (Same as Login)
  static const List<Color> forgotPasswordGradient = loginGradient;

  // Text Colors
  static const Color textPrimary = Color(0xFF333333);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textHint = Color(0xFF999999);

  // Button Colors
  static const Color primaryButton = Color(0xFF3B5998);
  static const Color secondaryButton = Color(0xFF28a745);
  static const Color otpButton = Color(0xFFff6f00);
  
  // Input Fields
  static const Color inputFill = Color(0xFFF5F5F5);
  static const Color inputBorder = Color(0xFFEEEEEE);
}
