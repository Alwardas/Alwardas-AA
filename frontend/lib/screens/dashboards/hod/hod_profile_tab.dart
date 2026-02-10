import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:flutter/services.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_theme.dart';
import 'hod_notifications_screen.dart';

class HodProfileTab extends StatefulWidget {
  final Map<String, dynamic> userData;
  final VoidCallback onLogout;

  const HodProfileTab({super.key, required this.userData, required this.onLogout});

  @override
  _HodProfileTabState createState() => _HodProfileTabState();
}

class _HodProfileTabState extends State<HodProfileTab> {
  // State
  Map<String, dynamic>? _profileData;
  bool _loading = true;
  bool _isEditing = false;
  
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
      // Fallback if session missing
      if (mounted) setState(() => _loading = false);
      return;
    }
    final userId = user['id'];

    setState(() => _loading = true);
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/faculty/profile?userId=$userId');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
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
               _dobController.text = DateFormat('dd-MM-yyyy').format(DateTime.parse(data['dob']));
            } catch (e) {
               _dobController.text = data['dob'];
            }
          } else {
             _dobController.text = '';
          }
        });
      } else {
         // Fallback to widget.userData
         setState(() {
          _profileData = widget.userData;
           _fullNameController.text = widget.userData['full_name'] ?? '';
           _idController.text = 'ID-${widget.userData['login_id'] ?? ''}';
           _deptController.text = widget.userData['branch'] ?? '';
         });
      }
    } catch (e) {
      print("Error fetching profile: $e");
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1950),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  Future<void> _saveChanges() async {
     try {
       final user = await AuthService.getUserSession();
       if (user == null) return;
       
       // HOD updates might be direct or requested. Assuming direct for now or same flow as Faculty.
       // Faculty flow checks for critical fields.
       
       String apiDob = _dobController.text;
       try {
          apiDob = DateFormat('yyyy-MM-dd').format(DateFormat('dd-MM-yyyy').parse(_dobController.text));
       } catch(_) {}

       // Check if critical fields changed (Name, ID, Dept, Exp) - Request to Admin?
       // For HOD, maybe they need approval too? Or they are trusted?
       // Let's use same logic as faculty for consistency.
       bool requestToHod = false; // Actually request to Admin if HOD. But reusing logic.
       if (_fullNameController.text != (_profileData?['fullName'] ?? '') || 
           _experienceController.text != (_profileData?['experience'] ?? '')) {
            requestToHod = true;
       }

       http.Response response;
       if (requestToHod) {
          response = await http.post(
           Uri.parse('${ApiConstants.baseUrl}/api/faculty/request-update'),
           headers: {'Content-Type': 'application/json'},
           body: json.encode({
             'userId': user['id'],
             'fullName': _fullNameController.text,
             'phoneNumber': _phoneController.text,
             'experience': _experienceController.text,
             'email': _emailController.text,
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
             'fullName': _fullNameController.text,
             'phoneNumber': _phoneController.text,
             'experience': _experienceController.text,
             'email': _emailController.text,
             'dob': apiDob,
             // ID and Branch not updated here
           })
         );
       }

       if (response.statusCode == 200) {
         setState(() => _isEditing = false);
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;

    return Scaffold(
      extendBodyBehindAppBar: true, 
      appBar: AppBar(
        title: Padding(
          padding: const EdgeInsets.only(top: 15),
          child: Text("Profile", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        ),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        actions: [
           IconButton(
            icon: const Icon(Icons.notifications_none),
            color: textColor,
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HodNotificationsScreen())),
          ),
          IconButton(
            icon: Icon(_isEditing ? Icons.check : Icons.edit, color: textColor),
            onPressed: () => _isEditing ? _saveChanges() : setState(() => _isEditing = true),
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark ? AppTheme.darkBodyGradient : AppTheme.lightBodyGradient,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: _loading 
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
                child: Column(
                  children: [
                    const SizedBox(height: 10),
                    // College Logo
                    Image.asset('assets/images/college logo.png', width: 220, height: 180), 
                    const SizedBox(height: 5),
                    Text(
                      "Alwardas Polytechnic", 
                      style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 15),

                    // Profile Details Card
                    Container(
                      padding: const EdgeInsets.all(16), // Tighter padding
                      decoration: AppTheme.glassDecoration(isDark: isDark, opacity: 0.25),
                      child: Column(
                        children: [
                          _buildField("Full Name", _fullNameController, _isEditing, isDark, textColor, subTextColor),
                          Row(
                            children: [
                              Expanded(child: _buildField("HOD ID", _idController, _isEditing, isDark, textColor, subTextColor)),
                              const SizedBox(width: 12),
                              Expanded(child: _buildField("Date of Birth", _dobController, _isEditing, isDark, textColor, subTextColor, onTap: () => _selectDate(context))),
                            ],
                          ),
                          _buildDropdownField("Department", _deptController, _isEditing, isDark, textColor, subTextColor),
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 4),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text("Contact Details", style: GoogleFonts.poppins(fontSize: 11, color: subTextColor)),
                                if (_isEditing) ...[
                                  TextField(
                                    controller: _phoneController,
                                    style: TextStyle(color: textColor, fontSize: 13),
                                    decoration: const InputDecoration(hintText: 'Phone Number', isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                                  ),
                                  const SizedBox(height: 4),
                                  TextField(
                                    controller: _emailController,
                                    style: TextStyle(color: textColor, fontSize: 13),
                                    decoration: const InputDecoration(hintText: 'Email ID', isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 8)),
                                  ),
                                ] else ...[
                                  Text(_phoneController.text.isEmpty ? "N/A" : _phoneController.text, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                                  Text(_emailController.text.isEmpty ? "N/A" : _emailController.text, style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: textColor)),
                                ],
                                const Divider(height: 12, color: Colors.white10),
                              ],
                            ),
                          ),
                          _buildField("Experience", _experienceController, _isEditing, isDark, textColor, subTextColor),
                        ],
                      ),
                    ),
                    
                    const SizedBox(height: 30),
                    
                    // Logout
                    GestureDetector(
                      onTap: widget.onLogout,
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.logout, color: Colors.red.withOpacity(0.8), size: 20),
                          const SizedBox(width: 8),
                          Text("Logout Session", style: GoogleFonts.poppins(color: Colors.red.withOpacity(0.8), fontWeight: FontWeight.bold, fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 5),
                    Text("App Version 1.0.0", style: GoogleFonts.poppins(fontSize: 10, color: subTextColor)),
                    const SizedBox(height: 15),
                  ],
                ),
              ),
        ),
      ),
    );
  }

  Widget _buildField(String label, TextEditingController controller, bool isEditable, bool isDark, Color textColor, Color subTextColor, {VoidCallback? onTap}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: subTextColor)),
          if (isEditable)
            SizedBox(
              height: 30, 
              child: TextField(
                controller: controller, 
                style: TextStyle(color: textColor, fontSize: 13),
                readOnly: onTap != null,
                onTap: onTap,
                keyboardType: label == "Experience" ? TextInputType.number : TextInputType.text,
                inputFormatters: label == "Experience" ? [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(2),
                ] : null,
                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6)),
              ),
            )
          else
            Text(
              (label == "Experience" && controller.text.isNotEmpty && !controller.text.toLowerCase().contains('year')) 
                  ? "${controller.text} - Years" 
                  : controller.text,
              style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
            ),
          const Divider(height: 12, color: Colors.white10),
        ],
      ),
    );
  }

  Widget _buildDropdownField(String label, TextEditingController controller, bool isEditable, bool isDark, Color textColor, Color subTextColor) {
    final List<String> branches = [
      'Computer Engineering',
      'Civil Engineering',
      'Electrical & Electronics Engineering',
      'Electronics & Communication Engineering',
      'Mechanical Engineering',
      'Basic Sciences & Humanities'
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: GoogleFonts.poppins(fontSize: 11, color: subTextColor)),
          if (isEditable)
             SizedBox(
               height: 30,
               child: DropdownButtonFormField<String>(
                value: branches.contains(controller.text) ? controller.text : null,
                items: branches.map((b) => DropdownMenuItem(
                  value: b, 
                  child: Text(
                    b, 
                    style: TextStyle(color: textColor, fontSize: 13),
                    overflow: TextOverflow.ellipsis,
                  )
                )).toList(),
                onChanged: (val) {
                  if (val != null) setState(() => controller.text = val);
                },
                isExpanded: true,
                dropdownColor: isDark ? const Color(0xFF2C2C2C) : Colors.white,
                decoration: const InputDecoration(isDense: true, contentPadding: EdgeInsets.symmetric(vertical: 6)),
              ),
             )
          else
             Text(
               controller.text,
               style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.bold, color: textColor),
             ),
           const Divider(height: 12, color: Colors.white10),
        ],
      ),
    );
  }
}
