import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart'; 
import '../../../core/api_constants.dart';
import '../../../core/providers/theme_provider.dart';
import 'package:provider/provider.dart';
import '../../../core/theme/app_theme.dart';

class StudentProfileTab extends StatefulWidget {
  final Map<String, dynamic> userData; 
  final VoidCallback onLogout;

  const StudentProfileTab({
    super.key,
    required this.userData,
    required this.onLogout,
  });

  @override
  State<StudentProfileTab> createState() => _StudentProfileTabState();
}

class _StudentProfileTabState extends State<StudentProfileTab> {
  // State Variables
  bool _isLoading = false;
  bool _isEditing = false;
  Map<String, dynamic>? _profileData;
  Map<String, dynamic>? _pendingRequest;
  
  // Form Controllers
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _branchController = TextEditingController();
  final TextEditingController _yearController = TextEditingController();
  final TextEditingController _semesterController = TextEditingController();
  final TextEditingController _dobController = TextEditingController();
  final TextEditingController _batchNoController = TextEditingController();
  final TextEditingController _sectionController = TextEditingController();

  // Dropdown Options
  final List<String> _branchOptions = [
    'Computer Engineering',
    'Civil Engineering',
    'Electrical & Electronics Engineering',
    'Electronics & Communication Engineering',
    'Mechanical Engineering',
    'Basic Sciences & Humanities'
  ];
  final List<String> _yearOptions = ['1st Year', '2nd Year', '3rd Year'];
  // _semesterOptions will now be dynamically derived, but we keep the master list if needed or just remove it if unused.
  // We will generate the specific list in logic.

  @override
  void initState() {
    super.initState();
    _fetchProfileData();
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _studentIdController.dispose();
    _branchController.dispose();
    _yearController.dispose();
    _semesterController.dispose();
    _dobController.dispose();
    _batchNoController.dispose();
    _sectionController.dispose();
    super.dispose();
  }

  // Hook for duration - usually 3 years for polytechnic
  final int _batchDuration = 3;

  void _calculateBatch() {
     if (_yearController.text.isEmpty) return;
     
     // Current Academic Year logic:
     // If 1st Year -> Started in 2025 (current acad start)
     // If 2nd Year -> Started in 2024
     // If 3rd Year -> Started in 2023
     
     int yearNum = 1;
     if (_yearController.text.contains('1st')) yearNum = 1;
     if (_yearController.text.contains('2nd')) yearNum = 2;
     if (_yearController.text.contains('3rd')) yearNum = 3;
     
     // Reference year for 1st years is 2025
     int startYear = 2026 - yearNum; 
     int endYear = startYear + _batchDuration;
     
     setState(() {
       _batchNoController.text = "$startYear-$endYear";
     });
  }

  Future<void> _fetchProfileData() async {
    setState(() => _isLoading = true);
    final userId = widget.userData['id'] ?? widget.userData['userId'];
    if (userId == null) {
      if (mounted) setState(() => _isLoading = false);
      return;
    }

    try {
      debugPrint("Fetching profile for UserID: $userId");
      final response = await http.get(Uri.parse('${ApiConstants.studentProfile}?userId=$userId'));
      
      debugPrint("Profile API Status: ${response.statusCode}");
      debugPrint("Profile API Body: ${response.body}");

      if (response.statusCode == 200) {
        _profileData = json.decode(response.body);
        if (_profileData!['pendingUpdate'] == true) {
             _pendingRequest = {'status': 'PENDING'};
        } else {
             _pendingRequest = null;
        }
      } else {
        // Fallback to locally available data
        debugPrint("API Failed, using local userData");
        _profileData = widget.userData;
        _pendingRequest = null;
      }
      
      _populateControllers(); 

    } catch (e) {
      debugPrint('Error fetching profile: $e');
      _profileData = widget.userData;
       _populateControllers();
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _populateControllers() {
    if (_profileData == null) return;
    _fullNameController.text = _profileData!['full_name'] ?? _profileData!['fullName'] ?? '';
    
    // Check for camelCase 'loginId' first (backend standard), then snake_case fallback
    _studentIdController.text = _profileData!['studentId'] ?? _profileData!['loginId'] ?? _profileData!['login_id'] ?? '';
    
    _branchController.text = _profileData!['branch'] ?? '';
    _yearController.text = _profileData!['year'] ?? '';
    _semesterController.text = _profileData!['semester'] ?? '';
    _sectionController.text = _profileData!['section'] ?? 'Section A'; // Default if missing
    
    // Handle Date Format: YYYY-MM-DD -> DD-MM-YYYY
    String rawDob = _profileData!['dob'] ?? _profileData!['date_of_birth'] ?? '';
    if (rawDob.isNotEmpty) {
      try {
        // Backend returns YYYY-MM-DD
        DateTime date = DateTime.parse(rawDob);
        _dobController.text = DateFormat('dd-MM-yyyy').format(date);
      } catch (e) {
        _dobController.text = rawDob; // Fallback to raw if parsing fails
      }
    } else {
      _dobController.text = '';
    }
    
    _batchNoController.text = _profileData!['batch_no'] ?? _profileData!['batchNo'] ?? '';
    
    // Auto calculate if empty
    if (_batchNoController.text.isEmpty || _batchNoController.text == 'N/A') {
      _calculateBatch();
    }
  }

  Future<void> _handleSubmitCorrection() async {
    if (_fullNameController.text.isEmpty ||
        _studentIdController.text.isEmpty ||
        _branchController.text.isEmpty ||
        _yearController.text.isEmpty ||
        _dobController.text.isEmpty ||
        _batchNoController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("All fields are required")),
      );
      return;
    }

    final userId = widget.userData['id'] ?? widget.userData['userId'];
     
    // Convert Date Format from DD-MM-YYYY to YYYY-MM-DD
    String dobToSend = _dobController.text;
    try {
        if (dobToSend.isNotEmpty && dobToSend.contains('-')) {
           final parts = dobToSend.split('-');
           if (parts.length == 3) {
              dobToSend = "${parts[2]}-${parts[1]}-${parts[0]}";
           }
        }
    } catch (_) {}

     final body = {
      'userId': userId,
      'newFullName': _fullNameController.text,
      'newStudentId': _studentIdController.text,
      'newBranch': _branchController.text,
      'newYear': _yearController.text,
      'newSemester': _semesterController.text,
      'newDob': dobToSend,
      'newBatchNo': _batchNoController.text,
      'newSection': _sectionController.text,
    };

    try {
       setState(() => _isLoading = true);
       final response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/api/user/request-update'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body)
       );

       setState(() => _isLoading = false);

       if (response.statusCode == 200) {
           setState(() {
             _isEditing = false;
             _pendingRequest = body; 
           });
           if(mounted) {
             ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Correction request sent for approval.')));
           }
       } else {
           if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to send request: ${response.statusCode}')));
       }

    } catch (e) {
       if(mounted) setState(() => _isLoading = false);
       if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
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
  
  Future<void> _selectDate(BuildContext context) async {
    if (!_isEditing) return;
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() {
        _dobController.text = DateFormat('dd-MM-yyyy').format(picked);
      });
    }
  }

  void _showSelectionDialog(String title, List<String> options, TextEditingController controller) {
    if (!_isEditing) return;
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              return ListTile(
                title: Text(options[index]),
                onTap: () {
                  controller.text = options[index];
                  if (title.contains("Year")) {
                    _calculateBatch();
                  }
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
      ),
    );
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
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text("My Profile", style: GoogleFonts.inter(color: textColor, fontWeight: FontWeight.w700, fontSize: 20)),
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
                   ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Feature coming soon')));
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
          ? Center(child: CircularProgressIndicator(color: Theme.of(context).primaryColor))
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  // Logo Section
                  SizedBox(
                    height: 200,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Image.asset(
                          'assets/images/college logo.png', 
                          height: 110,
                          width: 110,
                          errorBuilder: (context, error, stackTrace) => 
                             Icon(Icons.school, size: 100, color: subTextColor.withValues(alpha: 0.3)),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          "Alwardas Polytechnic",
                          style: GoogleFonts.inter(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textColor,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white12 : Colors.grey.shade200,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            "Est. 2017",
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: subTextColor,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  // Main Profile Content
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    child: _isEditing 
                         ? _buildEditProfileForm(textColor, subTextColor, isDark)
                         : _buildProfileCard(textColor, subTextColor, isDark),
                  ),
                  
                  const SizedBox(height: 40),

                  // Logout Button
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 40),
                    child: ElevatedButton.icon(
                      onPressed: widget.onLogout,
                      icon: const Icon(Icons.logout, color: Color(0xFFDC2626)),
                      label: Text("Logout", style: GoogleFonts.inter(color: const Color(0xFFDC2626), fontSize: 16, fontWeight: FontWeight.bold)),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFFEF2F2),
                        elevation: 0,
                        shadowColor: Colors.transparent,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                          side: const BorderSide(color: Color(0xFFFECACA), width: 1.5),
                        ),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 40),
                ],
              ),
            ),
    );
  }

  Widget _buildProfileCard(Color textColor, Color subTextColor, bool isDark) {
    // Determine the phone and email fallback since they are not always present in model. 
    // Usually retrieved from widget.userData or _profileData
    final contact = _profileData?['phone_number'] ?? _profileData?['phoneNumber'] ?? '+91 XXXXX XXXXX';
    final email = _profileData?['email'] ?? 'Not Provided';

    return Stack(
      children: [
        // The main white card background containing everything
        Container(
          width: double.infinity,
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF1E293B) : Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: [
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
              // --- TOP SECTION ---
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _fullNameController.text.toUpperCase(),
                      style: GoogleFonts.inter(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                        color: textColor,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // Student ID Row with Copy Icon
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: const BoxDecoration(
                            color: Color(0xFFEFF6FF),
                            borderRadius: BorderRadius.only(topLeft: Radius.circular(20), bottomLeft: Radius.circular(20)),
                          ),
                          child: Text(
                            "Student ID",
                            style: GoogleFonts.inter(color: const Color(0xFF3B82F6), fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.only(left: 10, right: 12, top: 6, bottom: 6),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            border: Border.all(color: const Color(0xFFEFF6FF), width: 1.5),
                            borderRadius: const BorderRadius.only(topRight: Radius.circular(20), bottomRight: Radius.circular(20)),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _studentIdController.text,
                                style: GoogleFonts.inter(color: const Color(0xFF1E293B), fontWeight: FontWeight.w700, fontSize: 13),
                              ),
                              const SizedBox(width: 8),
                              const Icon(Icons.copy, size: 14, color: Color(0xFF64748B)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    // Active Status Badge
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFECFDF5),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8, height: 8,
                            decoration: const BoxDecoration(color: Color(0xFF10B981), shape: BoxShape.circle),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            "Active Student",
                            style: GoogleFonts.inter(color: const Color(0xFF059669), fontWeight: FontWeight.w600, fontSize: 13),
                          )
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // --- GRID SECTION ---
              // Applying a different background color to the bottom grid area to separate it slightly, or keeping it same
              Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
                  borderRadius: const BorderRadius.only(bottomLeft: Radius.circular(24), bottomRight: Radius.circular(24)),
                ),
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(child: _buildInfoCard(icon: Icons.calendar_month, iconColor: const Color(0xFF3B82F6), label: "Date of Birth", value: _dobController.text, isDark: isDark)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInfoCard(icon: Icons.computer, iconColor: const Color(0xFF8B5CF6), label: "Branch", value: _branchController.text, isDark: isDark)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildInfoCard(icon: Icons.apartment, iconColor: const Color(0xFF10B981), label: "Current Year", value: _yearController.text, isDark: isDark)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInfoCard(icon: Icons.date_range, iconColor: const Color(0xFFF59E0B), label: "Batch", value: _batchNoController.text, isDark: isDark)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildInfoCard(icon: Icons.account_tree, iconColor: const Color(0xFFF59E0B), label: "Semester", value: _semesterController.text, isDark: isDark)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInfoCard(icon: Icons.grid_view_rounded, iconColor: const Color(0xFFEC4899), label: "Section", value: _sectionController.text, isDark: isDark)),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Expanded(child: _buildInfoCard(icon: Icons.phone, iconColor: const Color(0xFF3B82F6), label: "Contact", value: contact, isDark: isDark)),
                        const SizedBox(width: 12),
                        Expanded(child: _buildInfoCard(icon: Icons.email_outlined, iconColor: const Color(0xFF8B5CF6), label: "Email", value: email, isDark: isDark)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildInfoCard({required IconData icon, required Color iconColor, required String label, required String value, required bool isDark}) {
    return Container(
      height: 95, // Consistent equal size for all cards
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: isDark ? Colors.white12 : Colors.grey.shade200),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white70 : const Color(0xFF64748B),
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value.isEmpty ? "N/A" : value,
                  style: GoogleFonts.inter(
                    color: isDark ? Colors.white : const Color(0xFF1E293B),
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  // Fallback Edit Form - Keep old UI structure for editing mode so logic remains intact
  Widget _buildEditProfileForm(Color textColor, Color subTextColor, bool isDark) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E293B) : Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 20,
            offset: const Offset(0, 10),
          )
        ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _SectionLabel(text: "Full Name", color: subTextColor),
          _buildTextField(_fullNameController, "Enter Full Name", isDark),
          const SizedBox(height: 20),
          
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     _SectionLabel(text: "Student ID", color: subTextColor),
                     _buildTextField(_studentIdController, "Enter ID", isDark),
                  ],
                ),
              ),
              const SizedBox(width: 15),
              Expanded(
                 child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       _SectionLabel(text: "Date of Birth", color: subTextColor),
                       GestureDetector(
                         onTap: () => _selectDate(context),
                         child: AbsorbPointer(
                           child: _buildTextField(_dobController, "YYYY-MM-DD", isDark, icon: Icons.calendar_today),
                         ),
                       )
                    ],
                 ),
               ),
            ],
          ),
          const SizedBox(height: 20),

          _SectionLabel(text: "Branch", color: subTextColor),
          GestureDetector(
            onTap: () => _showSelectionDialog("Select Branch", _branchOptions, _branchController),
            child: AbsorbPointer(
              child: _buildTextField(_branchController, "Select Branch", isDark, icon: Icons.arrow_drop_down),
            ),
          ),
          const SizedBox(height: 20),

          Row(
             children: [
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     _SectionLabel(text: "Current Year", color: subTextColor),
                      GestureDetector(
                        onTap: () => _showSelectionDialog("Select Year", _yearOptions, _yearController),
                        child: AbsorbPointer(
                          child: _buildTextField(_yearController, "Select Year", isDark, icon: Icons.arrow_drop_down),
                        ),
                      )
                   ],
                 ),
               ),
               const SizedBox(width: 15),
               Expanded(
                 child: Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     _SectionLabel(text: "Batch No", color: subTextColor),
                     _buildTextField(_batchNoController, "Enter Batch No", isDark),
                   ],
                 ),
               ),
             ],
          ),
          const SizedBox(height: 20),

          Row(
              children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         _SectionLabel(text: "Semester", color: subTextColor),
                         GestureDetector(
                           onTap: () {
                              List<String> options = [];
                              String selectedYear = _yearController.text.trim();
                              if (selectedYear == '1st Year') {
                                  options = ['1st Year'];
                              } else if (selectedYear == '2nd Year') {
                                  options = ['3rd Semester', '4th Semester'];
                              } else if (selectedYear == '3rd Year') {
                                  options = ['5th Semester', '6th Semester'];
                              } else {
                                  options = ['1st Year', '3rd Semester', '4th Semester', '5th Semester', '6th Semester'];
                              }
                              _showSelectionDialog("Select Semester", options, _semesterController);
                           },
                           child: AbsorbPointer(
                             child: _buildTextField(_semesterController, "Select Semester", isDark, icon: Icons.arrow_drop_down),
                           ),
                         )
                      ],
                    ),
                  ),
                  const SizedBox(width: 15),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                         _SectionLabel(text: "Section", color: subTextColor),
                         GestureDetector(
                           onTap: () => _showSelectionDialog("Select Section", ['Section A', 'Section B', 'Section C'], _sectionController),
                           child: AbsorbPointer(
                             child: _buildTextField(_sectionController, "Section", isDark, icon: Icons.arrow_drop_down),
                           ),
                         )
                      ],
                    ),
                  ), 
              ]
          ),
          
          const SizedBox(height: 25),

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
              child: Text("Submit Correction Request", style: GoogleFonts.inter(fontWeight: FontWeight.bold)),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, bool isDark, {IconData? icon}) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1C1C2E) : Colors.grey[100],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isDark ? Colors.white10 : Colors.grey[300]!)
      ),
      child: TextField(
        controller: controller,
        style: TextStyle(color: isDark ? Colors.white : Colors.black87),
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
      padding: const EdgeInsets.only(bottom: 6),
      child: Text(
        text,
        style: GoogleFonts.inter(color: color, fontSize: 13, fontWeight: FontWeight.w600),
      ),
    );
  }
}
