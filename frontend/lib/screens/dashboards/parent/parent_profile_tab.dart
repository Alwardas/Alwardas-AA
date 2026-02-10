import 'package:flutter/material.dart';
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
    _fullNameController.text = _profileData!['full_name'] ?? _profileData!['fullName'] ?? '';
    _phoneController.text = _profileData!['phone'] ?? _profileData!['phoneNumber'] ?? '';
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
      'phone': _phoneController.text, // Backend likely expects 'phoneNumber' or 'phone' depending on handler
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
         if(mounted) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully.')));
         }
       } else {
         ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Failed to update profile')));
       }

    } catch (e) {
      if(mounted) setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  void _toggleEditMode() {
    if (_pendingRequest != null && !_isEditing) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('You already have a pending change request.')));
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
        studentIdDisplay = _studentData!['loginId'] ?? widget.currentChild['id'] ?? "Student";
    }

    return Scaffold(
      backgroundColor: Colors.transparent, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        automaticallyImplyLeading: false, 
        title: GestureDetector(
          onTap: widget.onWebSwitch,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
               Text(
                 studentIdDisplay,
                 style: appBarOrNameStyle,
               ),
               const SizedBox(width: 5),
               Icon(Icons.keyboard_arrow_down, color: textColor),
            ],
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: textColor),
            onPressed: () { },
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
                   Navigator.push(context, MaterialPageRoute(builder: (_) => ChangePasswordScreen(
                     userId: widget.userData['id'] ?? widget.userData['userId'] ?? 'unknown',
                     userRole: 'Parent', // Or dynamic if available
                   )));
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                 PopupMenuItem<String>(
                  value: 'update_profile',
                  child: Row(
                    children: [
                      Icon(Icons.edit, color: textColor, size: 20),
                      const SizedBox(width: 8),
                       Text('Update Profile', style: TextStyle(color: textColor)),
                    ],
                  ),
                ),
                PopupMenuItem<String>(
                  value: 'change_password',
                  child: Row(
                    children: [
                      Icon(Icons.lock_outline, color: textColor, size: 20),
                      const SizedBox(width: 8),
                       Text('Change Password', style: TextStyle(color: textColor)),
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
                    errorBuilder: (context, error, stackTrace) =>
                       Icon(Icons.school, size: 100, color: subTextColor.withValues(alpha: 0.3)),
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
                          TextButton.icon(
                            onPressed: widget.onLogout,
                            icon: const Icon(Icons.logout, color: Color(0xFFFF4B4B)),
                            label: Text("Logout", style: GoogleFonts.poppins(color: const Color(0xFFFF4B4B), fontSize: 16, fontWeight: FontWeight.w600)),
                          ),
                          const SizedBox(height: 5),
                          Text("App Version 1.0.0", style: GoogleFonts.poppins(color: subTextColor, fontSize: 12)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard(Color textColor, Color subTextColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: AppTheme.glassDecoration(
        isDark: isDark,
        opacity: 0.1, 
      ),
      child: _buildProfileContent(textColor, subTextColor, isDark),
    );
  }

  Widget _buildProfileContent(Color textColor, Color subTextColor, bool isDark) {
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        // Parent Details
        _SectionLabel(text: "Parent Name", color: subTextColor),
        if (_isEditing)
            _buildTextField(_fullNameController, "Enter Full Name", isDark)
        else
            _ValueText(text: _fullNameController.text, color: textColor, isHeader: true),
        
        const SizedBox(height: 15),
        
        _SectionLabel(text: "Phone Number", color: subTextColor),
         if (_isEditing)
             _buildTextField(_phoneController, "Enter Phone", isDark)
         else
            _ValueText(text: _phoneController.text, color: textColor),

        Divider(color: Colors.grey.withValues(alpha: 0.2), height: 20),

        // Student Details
        _SectionLabel(text: "Student Name", color: subTextColor),
        _ValueText(text: studentName, color: textColor),

        const SizedBox(height: 15),

        _SectionLabel(text: "Branch", color: subTextColor),
         _ValueText(text: studentBranch, color: textColor),

        const SizedBox(height: 15),

        // Row for Student ID and Year/Sem
        const SizedBox(height: 15),

        _SectionLabel(text: "Student ID", color: subTextColor),
        _ValueText(text: studentId, color: textColor),

        const SizedBox(height: 15),

        _SectionLabel(text: "Year & Sem", color: subTextColor),
        _ValueText(text: semesterDisplay, color: textColor),
        
        // ... (Edit buttons etc logic stays the same)
         if (_isEditing) ...[
            const SizedBox(height: 20),
            Column(
              children: [
                 SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: _handleSubmitCorrection,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: isDark ? Colors.white : const Color(0xFF4B7FFB),
                      foregroundColor: isDark ? const Color(0xFF4B7FFB) : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 15),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text("Save Changes", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  ),
                ),
                TextButton(onPressed: _toggleEditMode, child: const Text("Cancel"))
              ],
            )
         ] else if (_pendingRequest != null)
            Padding(
               padding: const EdgeInsets.only(top: 15),
               child: Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.amber),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.hourglass_empty, color: Colors.amber, size: 20),
                    const SizedBox(width: 8),
                    Text("Update Pending Approval", style: GoogleFonts.poppins(color: Colors.amber, fontWeight: FontWeight.bold)),
                  ],
                ),
              ),
            ),
      ],
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, bool isDark, {IconData? icon, int maxLines=1}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C2E) : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!)
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
        maxLines: maxLines,
        decoration: InputDecoration(
          hintText: hint,
          hintStyle: TextStyle(color: isDark ? Colors.white54 : Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
          suffixIcon: icon != null ? Icon(icon, color: isDark ? Colors.white54 : Colors.grey) : null,
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final Color color;
  const _SectionLabel({required this.text, required this.color});
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 2),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.poppins(color: color, fontSize: 10, letterSpacing: 1.2, fontWeight: FontWeight.w500),
      ),
    );
  }
}

class _ValueText extends StatelessWidget {
  final String text;
  final Color color;
  final bool isHeader;
  const _ValueText({required this.text, required this.color, this.isHeader = false});
  @override
  Widget build(BuildContext context) {
    return Text(
      text.isEmpty ? "N/A" : text,
      style: GoogleFonts.poppins(color: color, fontSize: isHeader ? 18 : 15, fontWeight: isHeader ? FontWeight.bold : FontWeight.w600),
    );
  }
}
