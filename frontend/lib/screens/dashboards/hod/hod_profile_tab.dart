import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';
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
               _dobController.text = DateFormat('dd MMM yyyy').format(DateTime.parse(data['dob']));
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
             apiDob = DateFormat('yyyy-MM-dd').format(DateFormat('dd MMM yyyy').parse(apiDob));
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
           Uri.parse('${ApiConstants.baseUrl}/api/faculty/request-update'),
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
                TextField(controller: dobC, decoration: const InputDecoration(labelText: "Date of Birth (dd MMM yyyy)"), readOnly: true, onTap: () async {
                   final DateTime? picked = await showDatePicker(
                      context: context,
                      initialDate: DateTime.now(),
                      firstDate: DateTime(1950),
                      lastDate: DateTime.now(),
                    );
                    if (picked != null) {
                        dobC.text = DateFormat('dd MMM yyyy').format(picked);
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

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    // Explicitly using colors mapped from the requested light theme for the exact look
    // but allowing dark mode adaptations if standard variables are used.
    final Color bgColor = isDark ? const Color(0xFF111827) : const Color(0xFFfafafa);
    final Color cardBg = isDark ? const Color(0xFF1f2937) : Colors.white;
    final Color textColor = isDark ? Colors.white : const Color(0xFF1f2937);
    final Color subTextColor = isDark ? Colors.grey[400]! : const Color(0xFF6B7280);
    final Color borderColor = isDark ? Colors.grey[800]! : const Color(0xFFe5e7eb);
    final Color mainLightBlue = isDark ? Colors.blue[900]! : const Color(0xFFe0f2fe);
    final Color mainBlueIcon = isDark ? Colors.blue[300]! : const Color(0xFF0369a1);

    return Scaffold(
      backgroundColor: bgColor,
      appBar: AppBar(
        title: Text("My Profile", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 20)),
        backgroundColor: bgColor,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textColor),
        actions: [
          IconButton(
            icon: Icon(Icons.notifications_outlined, color: textColor),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const HodNotificationsScreen())),
          ),
          PopupMenuButton<String>(
            icon: Icon(Icons.more_vert, color: textColor),
            onSelected: (val) {
              if (val == 'edit') {
                _showEditProfileDialog();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'edit',
                child: Row(children: [Icon(Icons.edit, size: 18), SizedBox(width: 8), Text('Edit Profile')]),
              ),
            ],
          ),
          const SizedBox(width: 10),
        ],
      ),
      body: _loading 
        ? const Center(child: CircularProgressIndicator())
        : Stack(
            children: [
              // Subtle background splash like the image
              if (!isDark)
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: Container(
                   height: 200,
                   decoration: BoxDecoration(
                     gradient: RadialGradient(
                       colors: [Colors.blue.withValues(alpha: 0.1), Colors.transparent],
                       radius: 1.5,
                     )
                   ),
                ),
              ),

              SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Column(
                    children: [
                      // College Logo & Name
                      Center(
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(4),
                              decoration: const BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.white,
                              ),
                              child: Image.asset('assets/images/college logo.png', width: 90, height: 90, fit: BoxFit.contain),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              "Alwardas Polytechnic", 
                              style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              "Est. 2017",
                              style: GoogleFonts.poppins(fontSize: 12, color: subTextColor, fontWeight: FontWeight.w500),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),

                      // Main Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(
                              color: isDark ? Colors.black26 : Colors.black.withValues(alpha: 0.03),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            )
                          ],
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Header Area inside Card
                            Text(
                              _fullNameController.text.toUpperCase(),
                              style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.w800, color: textColor, letterSpacing: 0.5),
                            ),
                            const SizedBox(height: 12),
                            
                            // Badges Row
                            Wrap(
                              spacing: 12,
                              runSpacing: 10,
                              children: [
                                // ID Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: mainLightBlue,
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text("Employee ID", style: GoogleFonts.poppins(fontSize: 12, color: mainBlueIcon, fontWeight: FontWeight.w600)),
                                      const SizedBox(width: 8),
                                      Text(_idController.text, style: GoogleFonts.poppins(fontSize: 13, color: textColor, fontWeight: FontWeight.bold)),
                                      const SizedBox(width: 6),
                                      GestureDetector(
                                        onTap: () {
                                          Clipboard.setData(ClipboardData(text: _idController.text));
                                          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('ID Copied')));
                                        },
                                        child: Icon(Icons.copy_rounded, size: 14, color: textColor),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // Status Badge
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                  decoration: BoxDecoration(
                                    color: isDark ? Colors.green[900]!.withValues(alpha: 0.4) : const Color(0xFFdcfce7),
                                    borderRadius: BorderRadius.circular(20),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Container(
                                         width: 6, height: 6,
                                         decoration: const BoxDecoration(color: Color(0xFF16a34a), shape: BoxShape.circle),
                                      ),
                                      const SizedBox(width: 6),
                                      Text("Active HOD", style: GoogleFonts.poppins(fontSize: 12, color: const Color(0xFF16a34a), fontWeight: FontWeight.w600)),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 24),

                            // Grid Items exactly like the design
                            GridView.count(
                              crossAxisCount: 2,
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              mainAxisSpacing: 12,
                              crossAxisSpacing: 12,
                              childAspectRatio: 2.2, // Adjusted for typical 2-column layout to fit text clearly
                              children: [
                                _buildGridCard(
                                  icon: Icons.calendar_month_outlined, 
                                  iconBg: const Color(0xFFe0f2fe), 
                                  iconColor: const Color(0xFF0284c7), 
                                  label: "Date of Birth", 
                                  value: _dobController.text.isNotEmpty ? _dobController.text : "Not Provided",
                                  cardBg: cardBg, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor
                                ),
                                _buildGridCard(
                                  icon: Icons.computer_outlined, 
                                  iconBg: const Color(0xFFf3e8ff), 
                                  iconColor: const Color(0xFF9333ea), 
                                  label: "Department", 
                                  value: _deptController.text.isNotEmpty ? _deptController.text : "N/A",
                                  cardBg: cardBg, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor
                                ),
                                _buildGridCard(
                                  icon: Icons.business_center_outlined, 
                                  iconBg: const Color(0xFFdcfce7), 
                                  iconColor: const Color(0xFF16a34a), 
                                  label: "Experience", 
                                  value: _experienceController.text.isNotEmpty ? "${_experienceController.text} Years" : "N/A",
                                  cardBg: cardBg, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor
                                ),
                                _buildGridCard(
                                  icon: Icons.verified_user_outlined, 
                                  iconBg: const Color(0xFFffedd5), 
                                  iconColor: const Color(0xFFea580c), 
                                  label: "Role", 
                                  value: widget.userData['role'] ?? 'HOD',
                                  cardBg: cardBg, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor
                                ),
                              ],
                            ),
                            
                            const SizedBox(height: 12),
                            
                            // Full width cards at bottom
                            _buildFullWidthCard(
                               icon: Icons.phone_outlined, 
                               iconBg: const Color(0xFFe0f2fe), 
                               iconColor: const Color(0xFF2563eb), 
                               label: "Contact", 
                               value: _phoneController.text.isNotEmpty ? _phoneController.text : "Not Provided",
                               cardBg: cardBg, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor
                            ),
                            const SizedBox(height: 12),
                            
                            _buildFullWidthCard(
                               icon: Icons.email_outlined, 
                               iconBg: const Color(0xFFf3e8ff), 
                               iconColor: const Color(0xFF9333ea), 
                               label: "Email", 
                               value: _emailController.text.isNotEmpty ? _emailController.text : "Not Provided",
                               cardBg: cardBg, borderColor: borderColor, textColor: textColor, subTextColor: subTextColor
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // Logout Button
                      SizedBox(
                        width: double.infinity,
                        child: OutlinedButton(
                          onPressed: widget.onLogout,
                          style: OutlinedButton.styleFrom(
                            backgroundColor: isDark ? const Color(0xFF450a0a) : const Color(0xFFfef2f2),
                            side: BorderSide(color: const Color(0xFFef4444).withValues(alpha: 0.3)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.logout_rounded, color: Color(0xFFef4444), size: 20),
                              const SizedBox(width: 8),
                              Text("Logout", style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: const Color(0xFFef4444))),
                            ],
                          ),
                        ),
                      ),
                      
                      const SizedBox(height: 40),
                    ],
                  ),
                ),
            ],
          ),
    );
  }

  Widget _buildGridCard({
    required IconData icon, required Color iconBg, required Color iconColor, 
    required String label, required String value,
    required Color cardBg, required Color borderColor, required Color textColor, required Color subTextColor
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
             padding: const EdgeInsets.all(8),
             decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(10)),
             child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: GoogleFonts.poppins(fontSize: 10, color: subTextColor, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  value, 
                  style: GoogleFonts.poppins(fontSize: 13, color: textColor, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildFullWidthCard({
    required IconData icon, required Color iconBg, required Color iconColor, 
    required String label, required String value,
    required Color cardBg, required Color borderColor, required Color textColor, required Color subTextColor
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Container(
             padding: const EdgeInsets.all(10),
             decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(12)),
             child: Icon(icon, color: iconColor, size: 22),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(label, style: GoogleFonts.poppins(fontSize: 12, color: subTextColor, fontWeight: FontWeight.w500)),
                const SizedBox(height: 2),
                Text(
                  value, 
                  style: GoogleFonts.poppins(fontSize: 14, color: textColor, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
