import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/api_constants.dart';
import '../../../core/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../common/change_password_screen.dart';

class ParentProfileTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final Map<String, String> currentChild;
  final VoidCallback onLogout;
  final VoidCallback onWebSwitch;

  const ParentProfileTab({
    super.key,
    required this.userData,
    required this.currentChild,
    required this.onLogout,
    required this.onWebSwitch,
  });

  @override
  State<ParentProfileTab> createState() => _ParentProfileTabState();
}

class _ParentProfileTabState extends State<ParentProfileTab> {
  // State Variables
  bool _isLoading = false;
  bool _isEditing = false;
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _studentData;
  Map<String, dynamic>? _pendingRequest;

  // Form Controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _fetchProfileData() async {
    setState(() => _isLoading = true);

    final userId = widget.userData['id'] ?? widget.userData['userId'];
    if (userId == null) {
      setState(() => _isLoading = false);
      return;
    }

    try {
      final response = await http.get(
        Uri.parse("${ApiConstants.baseUrl}/api/parent/profile?userId=$userId"),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);

        setState(() {
          _profileData = data;
          // Map API response keys to what controllers expect
          _profileData!['full_name'] = data['fullName'];
          _profileData!['phone'] = data['phoneNumber'] ?? '';

          if (data['student'] != null) {
            _studentData = data['student'];
          }
        });
        _populateControllers();
      } else {
        debugPrint("Failed to fetch profile: ${response.statusCode}");
        // Fallback to widget data if API fails
        _profileData = widget.userData;
        _populateControllers();
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
      _profileData = widget.userData;
      _populateControllers();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateControllers() {
    if (_profileData == null) return;
    _fullNameController.text =
        _profileData!['full_name'] ?? _profileData!['fullName'] ?? '';
    _phoneController.text =
        _profileData!['phone'] ?? _profileData!['phoneNumber'] ?? '';
  }

  Future<void> _handleSubmitCorrection() async {
    if (_fullNameController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Full Name is required")),
      );
      return;
    }

    final userId = widget.userData['id'] ?? widget.userData['userId'];
    final body = {
      'userId': userId,
      'fullName': _fullNameController.text,
      'phone': _phoneController
          .text, // Backend likely expects 'phoneNumber' or 'phone' depending on handler
      // Update handler usually expects keys matching the DTO: fullName, phoneNumber, email, etc.
      // Let's ensure we match UpdateUserRequest in backend:
      // userId, fullName, phoneNumber, email, experience, dob
      'phoneNumber': _phoneController.text,
    };

    try {
      setState(() => _isLoading = true);
      final response = await http.post(
        Uri.parse("${ApiConstants.baseUrl}/api/user/update"),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(body),
      );

      setState(() => _isLoading = false);

      if (response.statusCode == 200) {
        setState(() {
          _isEditing = false;
          _pendingRequest = null; // Clear any pending
          if (_profileData != null) {
            _profileData!['full_name'] = _fullNameController.text;
            _profileData!['phone'] = _phoneController.text;
            _profileData!['fullName'] = _fullNameController.text;
            _profileData!['phoneNumber'] = _phoneController.text;
          }
        });
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Profile updated successfully.')));
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update profile')));
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _toggleEditMode() {
    if (_pendingRequest != null && !_isEditing) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('You already have a pending change request.')));
      return;
    }
    setState(() {
      _isEditing = !_isEditing;
      if (_isEditing) {
        _populateControllers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final Color textColor = theme.colorScheme.onSurface;
    final Color subTextColor = theme.colorScheme.secondary;

    // AppBar Text Style
    final appBarOrNameStyle = GoogleFonts.poppins(
      color: textColor,
      fontWeight: FontWeight.bold,
      fontSize: 20,
    );

    // Determine info to show in App Bar (Student ID)
    String studentIdDisplay = widget.currentChild['id'] ?? "Student";
    if (_studentData != null) {
      studentIdDisplay =
          _studentData!['loginId'] ?? widget.currentChild['id'] ?? "Student";
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false,
        title: Text(
          "Profile",
          style: appBarOrNameStyle,
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: textColor),
            onPressed: () {},
          ),
          Theme(
            data: Theme.of(context).copyWith(
              cardColor: isDark ? const Color(0xFF222240) : Colors.white,
            ),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: textColor),
              onSelected: (value) {
                if (value == 'update_profile') {
                  _toggleEditMode();
                } else if (value == 'change_password') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => ChangePasswordScreen(
                                userId: widget.userData['id'] ??
                                    widget.userData['userId'] ??
                                    'unknown',
                                userRole: 'Parent', // Or dynamic if available
                              )));
                } else if (value == 'logout') {
                  widget.onLogout();
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'update_profile',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: textColor, size: 20),
                      const SizedBox(width: 8),
                      Text('Update Profile',
                          style: TextStyle(color: textColor)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'change_password',
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, color: textColor, size: 20),
                      const SizedBox(width: 8),
                      Text('Change Password',
                          style: TextStyle(color: textColor)),
                    ],
                  ),
                ),
                const PopupMenuDivider(),
                const PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      Icon(Icons.logout, color: Color(0xFFDC2626), size: 20),
                      SizedBox(width: 8),
                      Text('Logout',
                          style: TextStyle(color: Color(0xFFDC2626))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: theme.primaryColor))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Column(
                children: [
                  const SizedBox(height: 20),
                  Image.asset(
                    'assets/images/college logo.png',
                    height: 120,
                    width: 120,
                    errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.school,
                        size: 100,
                        color: subTextColor.withValues(alpha: 0.3)),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    "Alwardas Polytechnic",
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                      letterSpacing: 1,
                    ),
                  ),
                  const SizedBox(height: 25),
                  _buildProfileCard(textColor, subTextColor, isDark),
                  if (!_isEditing)
                    Padding(
                      padding: const EdgeInsets.only(top: 40, bottom: 30),
                      child: Column(
                        children: [
                          const SizedBox(height: 5),
                          Text("App Version 1.0.0",
                              style: GoogleFonts.poppins(
                                  color: subTextColor, fontSize: 12)),
                        ],
                      ),
                    ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard(Color textColor, Color subTextColor, bool isDark) {
    // Determine Student Details (Prefer _studentData, fallback to widget.currentChild)
    String studentName = widget.currentChild['name'] ?? 'N/A';
    String studentBranch = widget.currentChild['branch'] ?? 'N/A';
    String studentId = widget.currentChild['id'] ?? 'N/A';
    String studentYear = widget.currentChild['year'] ?? '';
    String studentSem = widget.currentChild['sem'] ?? '';

    if (_studentData != null) {
      studentName = _studentData!['fullName'] ?? studentName;
      studentBranch = _studentData!['branch'] ?? studentBranch;
      studentId = _studentData!['loginId'] ?? studentId;
      studentYear = _studentData!['year'] ?? studentYear;
      // Semester might not be in _studentData directly if not calculated by backend,
      // but 'year' often contains it (e.g. "2nd Year 3rd Semester")
    }

    String semesterDisplay = "$studentYear $studentSem".trim();
    if (semesterDisplay.isEmpty) semesterDisplay = "N/A";

    final contact = _phoneController.text.isNotEmpty
        ? _phoneController.text
        : '+91 XXXXX XXXXX';
    final email = _profileData?['email'] ?? 'Not Provided';
    final String displayName = _fullNameController.text.isNotEmpty
        ? _fullNameController.text.toUpperCase()
        : 'PARENT NAME';
    String parentId = widget.userData['login_id'] ?? 'N/A';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Name and ID Card
        Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
          decoration: BoxDecoration(
              color: isDark ? const Color(0xFF1E293B) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: isDark
                  ? []
                  : [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 20,
                        offset: const Offset(0, 10),
                      )
                    ]),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                displayName,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: textColor,
                  letterSpacing: 0.5,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark
                          ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                          : const Color(0xFFEFF6FF),
                      borderRadius: const BorderRadius.only(
                          topLeft: Radius.circular(20),
                          bottomLeft: Radius.circular(20)),
                    ),
                    child: Text(
                      "Parent ID",
                      style: GoogleFonts.inter(
                          color: isDark
                              ? const Color(0xFF60A5FA)
                              : const Color(0xFF3B82F6),
                          fontWeight: FontWeight.w700,
                          fontSize: 12),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: parentId));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('ID copied to clipboard'),
                          duration: Duration(seconds: 2)));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        border: Border.all(
                            color: isDark
                                ? const Color(0xFF1E3A8A).withValues(alpha: 0.3)
                                : const Color(0xFFEFF6FF),
                            width: 1.5),
                        borderRadius: const BorderRadius.only(
                            topRight: Radius.circular(20),
                            bottomRight: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            parentId,
                            style: GoogleFonts.inter(
                                color: textColor,
                                fontWeight: FontWeight.w800,
                                fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.copy_outlined,
                              size: 16, color: subTextColor),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),

        const SizedBox(height: 24),

        // STUDENT DETAILS Section
        _buildSection(
            title: "STUDENT DETAILS",
            lineColor: const Color(0xFF3B82F6), // Blue
            child: Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E293B) : Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                      color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                      width: 1.5),
                ),
                child: Column(children: [
                  _buildRowItem(
                      icon: Icons.person_outline,
                      iconColor: const Color(0xFF8B5CF6),
                      label: "Student Name",
                      value: studentName,
                      isDark: isDark),
                  _buildRowItem(
                      icon: Icons.badge_outlined,
                      iconColor: const Color(0xFFF59E0B),
                      label: "Student ID",
                      value: studentId,
                      isDark: isDark,
                      showCopy: true),
                  _buildRowItem(
                      icon: Icons.computer,
                      iconColor: const Color(0xFF10B981),
                      label: "Branch",
                      value: studentBranch,
                      isDark: isDark),
                  _buildRowItem(
                      icon: Icons.class_outlined,
                      iconColor: const Color(0xFF3B82F6),
                      label: "Year & Section",
                      value:
                          "$semesterDisplay - ${widget.userData['section'] ?? 'A'}",
                      isDark: isDark,
                      showBorder: false),
                ]))),

        const SizedBox(height: 24),

        // PERSONAL DETAILS Section
        _buildSection(
          title: "PERSONAL DETAILS",
          lineColor: const Color(0xFF10B981), // Teal
          child: Container(
              decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                    color: isDark ? Colors.white12 : const Color(0xFFF1F5F9),
                    width: 1.5),
              ),
              child: Column(children: [
                _buildRowItem(
                    icon: Icons.phone,
                    iconColor: const Color(0xFF8B5CF6),
                    label: "Phone",
                    value: contact,
                    isDark: isDark,
                    showCopy: true),
                _buildRowItem(
                    icon: Icons.email_outlined,
                    iconColor: const Color(0xFFEC4899),
                    label: "Email",
                    value: email,
                    isDark: isDark,
                    showBorder: false,
                    showCopy: true),
              ])),
        ),
      ],
    );
  }

  Widget _buildSection(
      {required String? title,
      required Color lineColor,
      required Widget child}) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            width: 3.5,
            decoration: BoxDecoration(
              color: lineColor,
              borderRadius: BorderRadius.circular(4),
            ),
            margin: const EdgeInsets.only(right: 16),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (title != null) ...[
                  Text(title,
                      style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                          color: const Color(0xFF64748B))),
                  const SizedBox(height: 12),
                ],
                child,
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRowItem({
    required IconData icon,
    required Color iconColor,
    required String label,
    String? value,
    bool isDark = false,
    bool showCopy = false,
    bool showBorder = true,
  }) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: iconColor.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, color: iconColor, size: 18),
              ),
              const SizedBox(width: 16),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: isDark
                      ? Colors.white70
                      : (value == null
                          ? const Color(0xFF1E293B)
                          : const Color(0xFF475569)),
                  fontSize: 13,
                  fontWeight: value == null ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (value != null) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: showCopy
                        ? () {
                            Clipboard.setData(ClipboardData(text: value));
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                content: Text('$label copied to clipboard'),
                                duration: const Duration(seconds: 2)));
                          }
                        : null,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            textAlign: TextAlign.right,
                            softWrap: true,
                            style: GoogleFonts.inter(
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (showCopy) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.copy_outlined,
                              size: 16, color: Color(0xFF94A3B8)),
                        ]
                      ],
                    ),
                  ),
                )
              ]
            ],
          ),
        ),
        if (showBorder)
          Divider(
              height: 1,
              thickness: 1,
              color: isDark ? Colors.white10 : const Color(0xFFF1F5F9),
              indent: 56,
              endIndent: 16),
      ],
    );
  }
}
