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
      print("Fetching profile for UserID: $userId");
      final response = await http.get(Uri.parse('${ApiConstants.studentProfile}?userId=$userId'));
      
      print("Profile API Status: ${response.statusCode}");
      print("Profile API Body: ${response.body}");

      if (response.statusCode == 200) {
        _profileData = json.decode(response.body);
        if (_profileData!['pendingUpdate'] == true) {
             _pendingRequest = {'status': 'PENDING'};
        } else {
             _pendingRequest = null;
        }
      } else {
        // Fallback to locally available data
        print("API Failed, using local userData");
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
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    final Color textColor = theme.colorScheme.onSurface;
    final Color subTextColor = theme.colorScheme.secondary;

    return Scaffold(
      backgroundColor: Colors.transparent, 
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text("My Profile", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold)),
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
                       Icon(Icons.school, size: 100, color: subTextColor.withOpacity(0.3)),
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
                  
                  const SizedBox(height: 40),

                  // Footer
                  Column(
                    children: [
                      GestureDetector(
                        onTap: widget.onLogout, // Use widget.onLogout
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.logout, color: Colors.red, size: 24),
                              const SizedBox(width: 10),
                              Text("Logout", style: GoogleFonts.poppins(color: Colors.red, fontSize: 16, fontWeight: FontWeight.bold)),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 5),
                      Text("App Version 1.0.0", style: GoogleFonts.poppins(fontSize: 12, color: subTextColor)),
                      const SizedBox(height: 40),
                    ],
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
        opacity: 0.1, // Subtle glass for profile
      ),
      child: _buildProfileContent(textColor, subTextColor, isDark),
    );
  }

  Widget _buildProfileContent(Color textColor, Color subTextColor, bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionLabel(text: "Full Name", color: subTextColor),
        if (_isEditing)
            _buildTextField(_fullNameController, "Enter Full Name", isDark)
        else
            _ValueText(text: _fullNameController.text, color: textColor, isHeader: true),
        
        Divider(color: Colors.grey.withOpacity(0.2), height: 30),
        
        // Row for Student ID & DOB
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                   _SectionLabel(text: "Student ID", color: subTextColor),
                   if (_isEditing)
                      _buildTextField(_studentIdController, "Enter ID", isDark)
                   else
                      _ValueText(text: _studentIdController.text, color: textColor),
                ],
              ),
            ),
            const SizedBox(width: 15),
            Expanded(
               child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                     _SectionLabel(text: "Date of Birth", color: subTextColor),
                     if (_isEditing)
                        GestureDetector(
                          onTap: () => _selectDate(context),
                          child: AbsorbPointer(
                            child: _buildTextField(_dobController, "YYYY-MM-DD", isDark, icon: Icons.calendar_today),
                          ),
                        )
                     else
                        _ValueText(text: _dobController.text, color: textColor),
                  ],
               ),
             ),
          ],
        ),

        Divider(color: Colors.grey.withOpacity(0.2), height: 30),

        _SectionLabel(text: "Branch", color: subTextColor),
         if (_isEditing)
             GestureDetector(
               onTap: () => _showSelectionDialog("Select Branch", _branchOptions, _branchController),
               child: AbsorbPointer(
                 child: _buildTextField(_branchController, "Select Branch", isDark, icon: Icons.arrow_drop_down),
               ),
             )
         else
            _ValueText(text: _branchController.text, color: textColor),

        Divider(color: Colors.grey.withOpacity(0.2), height: 30),

        // Row for Year and Batch No
        Row(
           children: [
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   _SectionLabel(text: "Current Year", color: subTextColor),
                    if (_isEditing)
                        GestureDetector(
                          onTap: () => _showSelectionDialog("Select Year", _yearOptions, _yearController),
                          child: AbsorbPointer(
                            child: _buildTextField(_yearController, "Select Year", isDark, icon: Icons.arrow_drop_down),
                          ),
                        )
                    else
                       _ValueText(text: _yearController.text, color: textColor),
                 ],
               ),
             ),
             const SizedBox(width: 15),
             Expanded(
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   _SectionLabel(text: "Batch No", color: subTextColor),
                    if (_isEditing)
                        _buildTextField(_batchNoController, "Enter Batch No", isDark)
                    else
                       _ValueText(text: _batchNoController.text, color: textColor),
                 ],
               ),
             ),
           ],
        ),

        Divider(color: Colors.grey.withOpacity(0.2), height: 30),

        // Row for Semester
        Row(
            children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       _SectionLabel(text: "Semester", color: subTextColor),
                        if (_isEditing)
                          GestureDetector(
                            onTap: () {
                               // Dynamically filter options based on year
                               List<String> options = [];
                               String selectedYear = _yearController.text.trim();
                               if (selectedYear == '1st Year') {
                                   options = ['1st Year'];
                               } else if (selectedYear == '2nd Year') {
                                   options = ['3rd Semester', '4th Semester'];
                               } else if (selectedYear == '3rd Year') {
                                   options = ['5th Semester', '6th Semester'];
                               } else {
                                   // Fallback if no year selected or some other value
                                   options = ['1st Year', '3rd Semester', '4th Semester', '5th Semester', '6th Semester'];
                               }
                               _showSelectionDialog("Select Semester", options, _semesterController);
                            },
                            child: AbsorbPointer(
                              child: _buildTextField(_semesterController, "Select Semester", isDark, icon: Icons.arrow_drop_down),
                            ),
                          )
                       else
                          _ValueText(text: _semesterController.text, color: textColor),
                    ],
                  ),
                ),
                // Spacer or another field if needed
                const SizedBox(width: 15),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                       _SectionLabel(text: "Section", color: subTextColor),
                        if (_isEditing)
                           GestureDetector(
                             onTap: () => _showSelectionDialog("Select Section", ['Section A', 'Section B', 'Section C'], _sectionController),
                             child: AbsorbPointer(
                               child: _buildTextField(_sectionController, "Section", isDark, icon: Icons.arrow_drop_down),
                             ),
                           )
                        else
                           _ValueText(text: _sectionController.text, color: textColor),
                    ],
                  ),
                ), 
            ]
        ),
        
        const SizedBox(height: 25),

         if (_isEditing)
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
                child: Text("Submit Correction Request", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
              ),
            )
         else if (_pendingRequest != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.amber.withOpacity(0.2),
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
      ],
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
      padding: const EdgeInsets.only(bottom: 5),
      child: Text(
        text.toUpperCase(),
        style: GoogleFonts.poppins(color: color, fontSize: 11, letterSpacing: 1.5, fontWeight: FontWeight.w500),
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
      style: GoogleFonts.poppins(color: color, fontSize: isHeader ? 20 : 16, fontWeight: isHeader ? FontWeight.bold : FontWeight.w600),
    );
  }
}
