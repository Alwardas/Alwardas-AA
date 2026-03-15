import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/api_constants.dart';
import '../admin/student_details_screen.dart';
import '../student/attendance_screen.dart';
import '../student/student_feedback_screen.dart';
import '../student/student_marks_screen.dart';

class HodStudentProfileScreen extends StatefulWidget {
  final String userId;
  final String studentId;
  final String studentName;

  const HodStudentProfileScreen({
    super.key,
    required this.userId,
    required this.studentId,
    required this.studentName,
  });

  @override
  State<HodStudentProfileScreen> createState() => _HodStudentProfileScreenState();
}

class _HodStudentProfileScreenState extends State<HodStudentProfileScreen> {
  bool _isLoading = true;
  String? _errorMessage;
  Map<String, dynamic>? _studentData;

  @override
  void initState() {
    super.initState();
    _fetchStudentProfile();
  }

  Future<void> _fetchStudentProfile() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/student/profile').replace(queryParameters: {'userId': widget.userId});
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _studentData = json.decode(response.body);
            _isLoading = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _errorMessage = "Error: Failed to load profile";
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = "Error: Network issue or Failed to load profile";
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _launchUrlStr(String uriString) async {
    try {
      final uri = Uri.parse(uriString);
      
      // For mailto, we use a more direct approach as canLaunchUrl can be 
      // unreliable even with correct manifest queries on some devices.
      if (uri.scheme == 'mailto') {
        final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
        if (!launched && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open email app')));
        }
        return;
      }

      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not perform action')));
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final primaryColor = Theme.of(context).primaryColor;
    final bgColor = isDark ? const Color(0xFF151517) : const Color(0xFFF5F7FA);
    final cardColor = isDark ? const Color(0xFF1E1E2C) : Colors.white;
    final textColor = isDark ? Colors.white : const Color(0xFF2D3748);
    final subTextColor = isDark ? Colors.white70 : (Colors.grey[600] ?? Colors.grey);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("Student Profile", style: GoogleFonts.inter(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(Icons.edit, color: primaryColor),
            onPressed: () async {
              // Push to StudentDetailsScreen (used for editing globally)
              await Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentDetailsScreen(userId: widget.userId, userName: _studentData?['fullName'] ?? widget.studentName),
                ),
              );
              // Refresh on return
              _fetchStudentProfile();
            },
            tooltip: "Edit",
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: primaryColor))
          : _errorMessage != null || _studentData == null
              ? Center(
                  child: Text(
                    _errorMessage ?? "Error: Failed to load profile",
                    style: GoogleFonts.inter(fontSize: 16, color: Colors.red),
                  ),
                )
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // 1. Basic Student Details Card
                      _buildBasicDetailsCard(cardColor, textColor, subTextColor, primaryColor),
                      const SizedBox(height: 20),

                      // 2. Contact Details Section
                      _buildContactDetails(cardColor, textColor, subTextColor),
                      const SizedBox(height: 20),

                      // 3. Parent Details Section & Quick Contact
                      _buildParentDetails(cardColor, textColor, subTextColor),
                      const SizedBox(height: 20),

                      // 4. Feature Cards Section
                      Text(
                        "Student Activities",
                        style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                      ),
                      const SizedBox(height: 12),
                      _buildFeatureCards(),
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
    );
  }

  Widget _buildBasicDetailsCard(Color cardColor, Color textColor, Color subTextColor, Color primaryColor) {
    final String fullName = _studentData?['fullName'] ?? widget.studentName;
    final String studentId = _studentData?['loginId'] ?? widget.studentId;
    String dob = _studentData?['dob'] ?? 'N/A';

    if (dob != 'N/A') {
      try {
        final date = DateTime.parse(dob);
        dob = DateFormat('dd MMM yyyy').format(date);
      } catch (e) {
        // Fallback to original if parsing fails
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            fullName.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: textColor,
              letterSpacing: 0.5,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: primaryColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "ID",
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                studentId,
                style: GoogleFonts.inter(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: subTextColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Icon(Icons.cake_outlined, size: 16, color: subTextColor),
              const SizedBox(width: 8),
              Text(
                "Date of Birth: $dob",
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: subTextColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildContactDetails(Color cardColor, Color textColor, Color subTextColor) {
    final String phone = _studentData?['phoneNumber'] ?? _studentData?['phone'] ?? 'N/A';
    final String email = _studentData?['email'] ?? 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Contact Details",
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            children: [
              GestureDetector(
                onTap: () {
                  if (phone != 'N/A' && phone.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: phone));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number copied to clipboard')));
                  }
                },
                child: _buildDetailRow(Icons.phone, "Phone", phone, textColor, subTextColor, showCopy: true),
              ),
              const Divider(height: 30),
              GestureDetector(
                onTap: () {
                  if (email != 'N/A' && email.isNotEmpty) {
                    _launchUrlStr("mailto:$email");
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email address not available')));
                  }
                },
                child: _buildDetailRow(Icons.email, "Email", email, textColor, subTextColor, isTappable: true, showCopy: true),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildParentDetails(Color cardColor, Color textColor, Color subTextColor) {
    // Attempt to get from API if available, else omit gently or use what is available
    // Attempt to get from API if available
    final String parentName = _studentData?['parentName'] ?? 'N/A';
    final String parentPhone = _studentData?['parentPhone'] ?? 'N/A';
    final String parentEmail = _studentData?['parentEmail'] ?? 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          "Parent Details",
          style: GoogleFonts.inter(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.03),
                blurRadius: 10,
                offset: const Offset(0, 4),
              )
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDetailRow(Icons.person, "Parent Name", parentName, textColor, subTextColor),
              const Divider(height: 20),
              GestureDetector(
                onTap: () {
                  if (parentPhone != 'N/A' && parentPhone.isNotEmpty) {
                    Clipboard.setData(ClipboardData(text: parentPhone));
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Parent phone number copied to clipboard')));
                  }
                },
                child: _buildDetailRow(Icons.phone_android, "Phone", parentPhone, textColor, subTextColor, showCopy: true),
              ),
              const Divider(height: 20),
              GestureDetector(
                onTap: () {
                  if (parentEmail != 'N/A' && parentEmail.isNotEmpty) {
                    _launchUrlStr("mailto:$parentEmail");
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email address not available')));
                  }
                },
                child: _buildDetailRow(Icons.mail_outline, "Email", parentEmail, textColor, subTextColor, isTappable: true, showCopy: true),
              ),
              const SizedBox(height: 24),
              
              Text(
                "Quick Contact",
                style: GoogleFonts.inter(fontSize: 14, fontWeight: FontWeight.bold, color: subTextColor),
              ),
              const SizedBox(height: 12),
              
              // Quick Contact Buttons
              Row(
                children: [
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.call,
                      label: "Call",
                      color: Colors.green,
                      onTap: () {
                        if (parentPhone == 'N/A') {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number not available')));
                        } else {
                          _launchUrlStr("tel:$parentPhone");
                        }
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _buildActionButton(
                      icon: Icons.message,
                      label: "Message",
                      color: Colors.blue,
                      onTap: () {
                        if (parentPhone == 'N/A') {
                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Phone number not available')));
                        } else {
                          _launchUrlStr("sms:$parentPhone");
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(IconData icon, String title, String value, Color textColor, Color subTextColor, {bool isTappable = false, bool showCopy = false}) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: subTextColor.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: subTextColor, size: 20),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: GoogleFonts.inter(fontSize: 12, color: subTextColor)),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      value, 
                      style: GoogleFonts.inter(
                        fontSize: 15, 
                        fontWeight: FontWeight.w500, 
                        color: isTappable ? Theme.of(context).primaryColor : textColor,
                        decoration: isTappable ? TextDecoration.underline : null,
                      )
                    ),
                  ),
                  if (showCopy && value != 'N/A' && value.isNotEmpty)
                    Icon(Icons.copy_outlined, size: 16, color: subTextColor.withValues(alpha: 0.5)),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildActionButton({required IconData icon, required String label, required Color color, required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 4),
            Text(
              label,
              style: GoogleFonts.inter(fontSize: 12, fontWeight: FontWeight.bold, color: color),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFeatureCards() {
    return Row(
      children: [
        Expanded(
          child: _buildFeatureCard(
            title: "Attendance",
            icon: Icons.calendar_month,
            color: Colors.orange,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => AttendanceScreen(
                    userData: {
                      'id': widget.userId,
                      'login_id': widget.studentId,
                    },
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFeatureCard(
            title: "Feedbacks",
            icon: Icons.feedback,
            color: Colors.purple,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentFeedbackScreen(
                    userData: {
                      'id': widget.userId,
                      'login_id': widget.studentId,
                    },
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: _buildFeatureCard(
            title: "Marks",
            icon: Icons.analytics,
            color: Colors.blueAccent,
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => StudentMarksScreen(
                    userId: widget.userId,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required String title,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF2D2D3A) : Colors.white;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        height: 100,
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.04),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              title,
              style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600, color: color),
            ),
          ],
        ),
      ),
    );
  }
}
