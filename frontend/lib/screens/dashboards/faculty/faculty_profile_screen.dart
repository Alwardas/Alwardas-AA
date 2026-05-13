import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../auth/login_screen.dart';
import 'faculty_notifications_screen.dart';

class FacultyProfileScreen extends StatefulWidget {
  final Map<String, dynamic>? userData;

  const FacultyProfileScreen({super.key, this.userData});

  @override
  _FacultyProfileScreenState createState() => _FacultyProfileScreenState();
}

class _FacultyProfileScreenState extends State<FacultyProfileScreen> {
  // State
  Map<String, dynamic>? _profileData;
  bool _loading = true;

  // Edit Form
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _phoneController = TextEditingController();
  final TextEditingController _idController = TextEditingController();
  final TextEditingController _deptController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _experienceController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchProfile();
  }

  Future<void> _fetchProfile() async {
    final user = await AuthService.getUserSession();
    if (user == null) {
      if (mounted) setState(() => _loading = false);
      return;
    }
    final userId = user['id'];

    setState(() => _loading = true);
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/faculty/profile?userId=$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        if (responseData['success'] == true && responseData['data'] != null) {
          final data = responseData['data'];
          setState(() {
            _profileData = data;
            _fullNameController.text = data['fullName'] ?? '';
            _phoneController.text = data['phoneNumber'] ?? '';
            _experienceController.text = data['experience'] ?? '';
            _idController.text = 'ID-${data['facultyId'] ?? ''}';
            _deptController.text = data['branch'] ?? '';
            _emailController.text = data['email'] ?? '';
            if (data['dob'] != null && data['dob'].toString().isNotEmpty) {
              try {
                 _dobController.text = DateFormat('dd/MM/yyyy').format(DateTime.parse(data['dob']));
              } catch (e) {
                 _dobController.text = data['dob'];
              }
            } else {
               _dobController.text = '';
            }
          });
        } else {
           if (widget.userData != null) {
             setState(() {
               _profileData = widget.userData;
               _fullNameController.text = widget.userData!['full_name'] ?? '';
               _idController.text = 'ID-${widget.userData!['login_id'] ?? ''}';
               _deptController.text = widget.userData!['branch'] ?? '';
             });
           }
        }
      } else {
         if (widget.userData != null) {
           setState(() {
             _profileData = widget.userData;
             _fullNameController.text = widget.userData!['full_name'] ?? '';
             _idController.text = 'ID-${widget.userData!['login_id'] ?? ''}';
             _deptController.text = widget.userData!['branch'] ?? '';
           });
         }
      }
    } catch (e) {
      debugPrint("Error fetching profile: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _saveChanges(Map<String, String> updates) async {
     try {
       final user = await AuthService.getUserSession();
       if (user == null) return;
       
       String apiDob = updates['dob'] ?? '';
       try {
          if (apiDob.isNotEmpty) {
             apiDob = DateFormat('yyyy-MM-dd').format(DateFormat('dd/MM/yyyy').parse(apiDob));
          }
       } catch(_) {}

       bool requestToHod = false; 
       if ((updates['fullName'] ?? '') != (_profileData?['fullName'] ?? '') || 
           (updates['experience'] ?? '') != (_profileData?['experience'] ?? '')) {
            requestToHod = true;
       }

       http.Response response;
       if (requestToHod) {
          response = await http.post(
           Uri.parse('${ApiConstants.baseUrl}/api/user/request-update'),
           headers: {'Content-Type': 'application/json'},
           body: json.encode({
             'userId': user['id'],
             'fullName': updates['fullName'],
             'phoneNumber': updates['phoneNumber'],
             'experience': updates['experience'],
             'email': updates['email'],
             'dob': apiDob,
             'facultyId': _idController.text.replaceAll('ID-', ''),
             'branch': _deptController.text
           })
         );
       } else {
         response = await http.post(
           Uri.parse('${ApiConstants.baseUrl}/api/user/update'),
           headers: {'Content-Type': 'application/json'},
           body: json.encode({
             'userId': user['id'],
             'fullName': updates['fullName'],
             'phoneNumber': updates['phoneNumber'],
             'experience': updates['experience'],
             'email': updates['email'],
             'dob': apiDob,
           })
         );
       }

       if (response.statusCode == 200) {
         String message = "Profile Updated!";
         if (requestToHod) {
           message = "Profile change request sent for approval.";
         }
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(message),
              backgroundColor: requestToHod ? Colors.orange : Colors.green,
            ));
         }
         if (!requestToHod) _fetchProfile();
       } else {
         if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update Failed: ${response.statusCode}")));
         }
       }
     } catch (e) {
       if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Network Error")));
       }
     }
  }

  void _showEditProfileDialog() {
    final TextEditingController nameC = TextEditingController(text: _fullNameController.text);
    final TextEditingController phoneC = TextEditingController(text: _phoneController.text);
    final TextEditingController emailC = TextEditingController(text: _emailController.text);
    final TextEditingController expC = TextEditingController(text: _experienceController.text);
    final TextEditingController dobC = TextEditingController(text: _dobController.text);

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text("Edit Profile", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: nameC, decoration: const InputDecoration(labelText: "Full Name")),
                TextField(controller: dobC, decoration: const InputDecoration(labelText: "Date of Birth (dd/MM/yyyy)"), readOnly: true, onTap: () async {
                   final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                        dobC.text = DateFormat('dd/MM/yyyy').format(picked);
                    }
                }),
                TextField(controller: expC, decoration: const InputDecoration(labelText: "Experience (Years)"), keyboardType: TextInputType.number),
                TextField(controller: phoneC, decoration: const InputDecoration(labelText: "Phone Number"), keyboardType: TextInputType.phone),
                TextField(controller: emailC, decoration: const InputDecoration(labelText: "Email ID"), keyboardType: TextInputType.emailAddress),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
            ElevatedButton(
              onPressed: () {
                Navigator.pop(context);
                _saveChanges({
                  'fullName': nameC.text,
                  'phoneNumber': phoneC.text,
                  'experience': expC.text,
                  'email': emailC.text,
                  'dob': dobC.text,
                });
              }, 
              child: const Text("Save")
            )
          ],
        );
      }
    );
  }

  Future<void> _logout() async {
    await AuthService.logout();
    if (mounted) {
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const LoginScreen()),
        (route) => false,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final Color bgColor = isDark ? const Color(0xFF1E1E2C) : const Color(0xFFF8FAFC);
    final Color textColor = isDark ? Colors.white : const Color(0xFF1E293B);
    final Color subTextColor = isDark ? Colors.white70 : const Color(0xFF64748B);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        automaticallyImplyLeading: false,
        title: Text("My Profile", style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w700, fontSize: 20)),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: textColor),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FacultyNotificationsScreen())),
          ),
          Theme(
            data: Theme.of(context).copyWith(
               cardColor: isDark ? const Color(0xFF222240) : Colors.white,
            ),
            child: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert, color: textColor),
              onSelected: (value) {
                if (value == 'update_profile') {
                  _showEditProfileDialog();
                } else if (value == 'change_password') {
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature coming soon')));
                } else if (value == 'logout') {
                   _logout();
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
                const PopupMenuDivider(),
                PopupMenuItem<String>(
                  value: 'logout',
                  child: Row(
                    children: [
                      const Icon(Icons.logout, color: Color(0xFFDC2626), size: 20),
                      const SizedBox(width: 8),
                       const Text('Logout', style: TextStyle(color: Color(0xFFDC2626))),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      body: _loading 
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Logo Section
                  SizedBox(
                    height: 240,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const SizedBox(height: 16),
                        Image.asset(
                          'assets/images/college logo.png', 
                          height: 140,
                          width: 140,
                          errorBuilder: (context, error, stackTrace) => 
                             Icon(Icons.school, size: 100, color: subTextColor.withValues(alpha: 0.3)),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          "Alwardas Polytechnic",
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                    ),
                  ),
                  
                  // Main Profile Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _buildProfileCard(textColor, subTextColor, isDark),
                  ),
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard(Color textColor, Color subTextColor, bool isDark) {
    final contact = _phoneController.text.isNotEmpty ? _phoneController.text : '+91 XXXXX XXXXX';
    final email = _emailController.text.isNotEmpty ? _emailController.text : 'Not Provided';
    final String displayName = _fullNameController.text.toUpperCase();
    String rawRole = widget.userData?['role'] ?? 'Faculty';
    final String role = rawRole;
    final String department = _deptController.text.isNotEmpty ? _deptController.text : 'N/A';
    final String experience = _experienceController.text.isNotEmpty ? "${_experienceController.text} Years" : 'N/A';
    final String dob = _dobController.text.isNotEmpty ? _dobController.text : 'Not Provided';

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
            boxShadow: isDark ? [] : [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.04),
                blurRadius: 20,
                offset: const Offset(0, 10),
              )
            ]
          ),
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
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    decoration: BoxDecoration(
                      color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF),
                      borderRadius: const BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                    ),
                    child: Text(
                      "Employee ID",
                      style: GoogleFonts.inter(color: isDark ? const Color(0xFF60A5FA) : const Color(0xFF3B82F6), fontWeight: FontWeight.w700, fontSize: 12),
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Clipboard.setData(ClipboardData(text: _idController.text));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID copied to clipboard'), duration: Duration(seconds: 2)));
                    },
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isDark ? const Color(0xFF0F172A) : Colors.white,
                        border: Border.all(color: isDark ? const Color(0xFF1E3A8A).withValues(alpha: 0.3) : const Color(0xFFEFF6FF), width: 1.5),
                        borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
                      ),
                      child: Row(
                        children: [
                          Text(
                            _idController.text,
                            style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w800, fontSize: 12),
                          ),
                          const SizedBox(width: 8),
                          Icon(Icons.copy_outlined, size: 16, color: subTextColor),
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

        // PROFESSIONAL Section
        _buildSection(
          title: "PROFESSIONAL",
          lineColor: const Color(0xFF3B82F6), // Blue
          child: Container(
             decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFF1F5F9), width: 1.5),
             ),
             child: Column(
                children: [
                   _buildRowItem(icon: Icons.computer, iconColor: const Color(0xFF8B5CF6), label: department, isDark: isDark),
                   _buildRowItem(icon: Icons.verified_user_outlined, iconColor: const Color(0xFFF59E0B), label: "Role", value: role, isDark: isDark),
                   _buildRowItem(icon: Icons.business_center_outlined, iconColor: const Color(0xFF10B981), label: "Experience", value: experience, isDark: isDark, showBorder: false),
                ]
             )
          )
        ),
        
        const SizedBox(height: 24),

        // PERSONAL Section
        _buildSection(
          title: "PERSONAL",
          lineColor: const Color(0xFF10B981), // Teal
          child: Container(
             decoration: BoxDecoration(
                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: isDark ? Colors.white12 : const Color(0xFFF1F5F9), width: 1.5),
             ),
             child: Column(
                children: [
                   _buildRowItem(icon: Icons.calendar_today, iconColor: const Color(0xFF3B82F6), label: "Date of Birth", value: dob, isDark: isDark),
                   _buildRowItem(icon: Icons.phone, iconColor: const Color(0xFF8B5CF6), label: "Phone", value: contact, isDark: isDark, showCopy: true),
                   _buildRowItem(icon: Icons.email_outlined, iconColor: const Color(0xFFEC4899), label: "Email", value: email, isDark: isDark, showBorder: false, showCopy: true),
                ]
              )
           ),
        ),
      ],
    );
  }

  Widget _buildSection({required String? title, required Color lineColor, required Widget child}) {
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
                  Text(title, style: GoogleFonts.inter(fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: 1.2, color: const Color(0xFF64748B))),
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
                  color: isDark ? Colors.white70 : (value == null ? const Color(0xFF1E293B) : const Color(0xFF475569)),
                  fontSize: 13,
                  fontWeight: value == null ? FontWeight.w600 : FontWeight.w500,
                ),
              ),
              if (value != null) ...[
                Expanded(
                  child: GestureDetector(
                    onTap: showCopy ? () {
                      Clipboard.setData(ClipboardData(text: value));
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied to clipboard'), duration: const Duration(seconds: 2)));
                    } : null,
                    behavior: HitTestBehavior.opaque,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Flexible(
                          child: Text(
                            value,
                            textAlign: TextAlign.right,
                            overflow: TextOverflow.ellipsis,
                            maxLines: 1,
                            style: GoogleFonts.inter(
                              color: isDark ? Colors.white : const Color(0xFF1E293B),
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        if (showCopy) ...[
                          const SizedBox(width: 8),
                          const Icon(Icons.copy_outlined, size: 16, color: Color(0xFF94A3B8)),
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
           Divider(height: 1, thickness: 1, color: isDark ? Colors.white10 : const Color(0xFFF1F5F9), indent: 56, endIndent: 16),
      ],
    );
  }
}

