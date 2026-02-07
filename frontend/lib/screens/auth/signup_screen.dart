import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart'; // Persistence
import '../../widgets/custom_text_field.dart';
import '../../widgets/custom_modal_dropdown.dart';
import '../../theme/app_colors.dart';
import '../../core/api_constants.dart';
import '../../core/theme/app_theme.dart';
import '../../core/providers/theme_provider.dart';

class SignupScreen extends StatefulWidget {
  final int initialStep; 
  final String? forcedRole;

  const SignupScreen({super.key, this.initialStep = 1, this.forcedRole});

  @override
  State<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends State<SignupScreen> {
  int _currentStep = 1;
  String? _selectedRole;

  @override
  void initState() {
    super.initState();
    _currentStep = widget.initialStep;
    if (widget.forcedRole != null) {
      _selectedRole = widget.forcedRole;
    }
  }

  // Controllers
  final _fullNameController = TextEditingController();
  final _idController = TextEditingController();
  final _phoneController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  // New Controllers for strict requirements
  final _experienceController = TextEditingController();
  final _emailController = TextEditingController();
  final _dobController = TextEditingController();

  // Options
  final List<String> _roles = ['Student', 'Parent', 'Faculty', 'HOD', 'Principal', 'Admin'];
  final List<String> _branches = [
    'Computer Engineering',
    'Civil Engineering',
    'Electrical & Electronics Engineering',
    'Electronics & Communication Engineering',
    'Mechanical Engineering',
    'Basic Sciences & Humanities'
  ];
  
  final List<String> _years = [
    '1st Year',
    '2nd Year',
    '3rd Year',
  ];

  String? _selectedBranch;
  String? _selectedYear;
  String? _selectedSemester; 
  String? _selectedSection; 
  
  List<String> _sections = ['Section A']; 
  List<String> _availableSemesters = [];



  void _updateSemesters() {
    if (_selectedYear == '1st Year') {
       _availableSemesters = ['1st Semester'];
    } else if (_selectedYear == '2nd Year') {
       _availableSemesters = ['3rd Semester', '4th Semester'];
    } else if (_selectedYear == '3rd Year') {
       _availableSemesters = ['5th Semester', '6th Semester'];
    } else {
       _availableSemesters = [];
    }
    // Reset selection if not in new list
    if (_selectedSemester != null && !_availableSemesters.contains(_selectedSemester)) {
      _selectedSemester = null;
    }
    setState(() {});
  }

  Future<void> _loadSections() async {
     if (_selectedBranch == null || _selectedYear == null) {
        setState(() => _sections = ['Section A']); // Default fallback
        return;
     }
     
     final prefs = await SharedPreferences.getInstance();
     // Key format matches HodYearSectionsScreen: 'sections_${branch}_${year}'
     final key = 'sections_${_selectedBranch}_${_selectedYear}';
     List<String>? stored = prefs.getStringList(key);
     
     setState(() {
       _sections = stored ?? ['Section A']; // User requirement: "by default show only one section" (Section A) unless HOD updated it
     });
  }

  bool _otpSent = false;
  
  bool _isSigningUp = false;

  void _nextStep() {
    if (_currentStep == 1) {
      _checkUserExistence();
      return;
    } else if (_currentStep == 2) {
      // Logic from requirements
      
      // 1. Name Check (Moved to Step 2)
       if (_fullNameController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Full Name')));
        return;
      }

      // 2. Branch Check
      bool isBranchRequired = ['Student', 'Parent', 'Faculty', 'HOD'].contains(_selectedRole);
      if (isBranchRequired && _selectedBranch == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Branch')));
        return;
      }

      // 3. Year Check
      bool isYearRequired = ['Student', 'Parent'].contains(_selectedRole);
      if (isYearRequired && _selectedYear == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Course Year')));
        return;
      }
      
      // 3.5 Semester Check (New)
      bool isSemesterRequired = ['Student', 'Parent'].contains(_selectedRole);
      if (isSemesterRequired && _selectedSemester == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Semester')));
        return;
      }

      // 4. Section Check
      bool isSectionRequired = ['Student'].contains(_selectedRole);
      if (isSectionRequired && _selectedSection == null) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a Section')));
        return;
      }
      
      // 5. DOB Check
      bool isDobRequired = ['Student', 'Faculty', 'HOD', 'Principal'].contains(_selectedRole);
      if (isDobRequired && _dobController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Date of Birth')));
        return;
      }
      
      // 5. Professional Details Check (Experience & Email)
      bool isProfessionalDetailsRequired = ['Faculty', 'HOD', 'Principal'].contains(_selectedRole);
      if (isProfessionalDetailsRequired) {
        if (_experienceController.text.isEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Years of Experience')));
           return;
        }
        if (_emailController.text.isEmpty) {
           ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter Email ID')));
           return;
        }
      }
      
      // Auto-prepend P- for Parent role if not already present
      if (_selectedRole == 'Parent' && !_idController.text.startsWith('P-')) {
        _idController.text = 'P-${_idController.text.trim()}';
      }
      
    }
    setState(() => _currentStep++);
  }

  // ... (Prev Step, Date Picker, Send OTP unchanged)
  void _prevStep() {
    if (_currentStep > 1) setState(() => _currentStep--);
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
        _dobController.text = "${picked.year}-${picked.month.toString().padLeft(2, '0')}-${picked.day.toString().padLeft(2, '0')}";
      });
    }
  }
  
  void _sendOtp() {
    if (_phoneController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter phone number first')));
      return;
    }
    // Simulate OTP
    setState(() => _otpSent = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('OTP Sent: 1234')));
  }

  Future<void> _handleSignup() async {
    if (_passwordController.text != _confirmPasswordController.text) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Passwords do not match')));
      return;
    }

    setState(() => _isSigningUp = true);

    try {
      String finalLoginId = _idController.text.trim();
      if (_selectedRole == 'Parent' && !finalLoginId.startsWith('P-')) {
        finalLoginId = 'P-$finalLoginId';
        _idController.text = finalLoginId;
      }

      final Map<String, dynamic> payload = {
          'full_name': _fullNameController.text,
          'role': _selectedRole,
          'login_id': finalLoginId,
          'password': _passwordController.text,
          'branch': _selectedBranch,
          'year': _selectedYear,
          'semester': _selectedSemester, // New field 
          'phone_number': _phoneController.text.isNotEmpty ? _phoneController.text : null,
          'dob': _dobController.text.isNotEmpty ? _dobController.text : null,
          'experience': _experienceController.text,
          'email': _emailController.text,
          'section': _selectedSection, 
      };

  // ... (Rest of handleSignup unchanged until buildStep2)
      final response = await http.post(
        Uri.parse(ApiConstants.signupEndpoint),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (ctx) => AlertDialog(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Request Status'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (data['message']?.toString().contains('login with your CURRENT credentials') == true) ...[
                     const Text('Please login with your CURRENT (OLD) password to verify this request.', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.bold)),
                     const SizedBox(height: 15),
                     Text('Update Request: ${_idController.text}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ] else ...[
                     const Text('Please Screenshot or Remember your credentials!', style: TextStyle(color: Colors.red)),
                     const SizedBox(height: 15),
                     Text('Login ID: ${_idController.text}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                     Text('Password: ${_passwordController.text}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  ],
                  const SizedBox(height: 15),
                  Text(data['message'] ?? 'Signup Successful'),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.pop(context);
                  },
                  child: const Text('OK'),
                ),
              ],
            ),
          );
      } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(data['message'] ?? 'Signup Failed')));
      }

    } catch (e) {
      print(e);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Network Error. Is Backend running?')));
    } finally {
      if (mounted) setState(() => _isSigningUp = false);
    }
  }

  // ... (Check User Existence - Needs minor update for Semester)

  bool _checkingUser = false;
  bool _userFound = false;

  Future<void> _checkUserExistence() async {
     // ... (Validations)
     if (_selectedRole == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select Role first')));
       return;
     }
     if (_idController.text.isEmpty) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please enter ID')));
       return;
     }
     
     setState(() => _checkingUser = true);
     
     try {
       String checkId = _idController.text.trim();
       if (_selectedRole == 'Parent' && !checkId.startsWith('P-')) {
         checkId = 'P-$checkId';
       }

       final response = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/auth/check?loginId=$checkId'));
       
       if (response.statusCode == 200) {
          final data = json.decode(response.body);
          if (data['exists'] == true) {
             setState(() {
               _userFound = true;
               _fullNameController.text = data['fullName'] ?? '';

               if (data['branch'] != null) _selectedBranch = data['branch'];
               if (data['year'] != null) {
                 // Check if stored year is old format ("2nd Year 3rd Semester")
                 // If so, split it. If not, use as is.
                 String rawYear = data['year'];
                 if (rawYear.contains("Semester")) {
                    // Try to guess? Or just set Year part if it starts with it.
                    // Assuming distinct Year & Semester now in backend (from previous analysis), 
                    // we should look for 'semester' field in response.
                 } else {
                    _selectedYear = rawYear;
                 }
               }
               // Assuming backend returns 'semester' now if available
                if (data['semester'] != null) _selectedSemester = data['semester'];

               if (data['phone'] != null) _phoneController.text = data['phone'];
               if (data['email'] != null) _emailController.text = data['email'];
               if (data['dob'] != null) _dobController.text = data['dob'];
               if (data['experience'] != null) _experienceController.text = data['experience'].toString(); 
               if (data['section'] != null) _selectedSection = data['section']; 
               
               // Trigger updates
               if (_selectedYear != null) {
                 _updateSemesters();
                 _loadSections(); // Try to load sections based on this
               }
             });
             
             // ... (Dialog)
             if (mounted) {
                await showDialog(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text("Account Found"),
                    content: Column( // ... 
                         mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text("Is this you?", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        Text("Name: ${data['fullName']}"),
                        Text("ID: ${_maskId(checkId)}"),
                        if (data['branch'] != null) Text("Branch: ${data['branch']}"),
                        Text("Role: ${data['role'] ?? _selectedRole}"),
                        const SizedBox(height: 20),
                        const Text("We found your profile. Proceed to setup your account details?", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("No, Cancel", style: TextStyle(color: Colors.red))),
                      ElevatedButton(onPressed: () { Navigator.pop(ctx); _moveToStep2(); }, child: const Text("Yes, Proceed")),
                    ],
                  )
                );
             }
          } else {
             setState(() {
               _userFound = false;
               _fullNameController.clear();
             });
             _moveToStep2();
          }
       } else {
          setState(() { _userFound = false; });
          _moveToStep2();
       }

     } catch (e) {
       print("Check Error: $e");
       _moveToStep2();
     } finally {
       if (mounted) setState(() => _checkingUser = false);
     }
  }

  void _moveToStep2() {
      setState(() => _currentStep = 2);
  }

  Widget _buildStep1() {
    return Column(
      children: [
        CustomModalDropdown(
          label: 'Select Role',
          value: _selectedRole,
          options: _roles,
          onChanged: (val) {
             setState(() {
                _selectedRole = val;
                // Reset role-specific fields when role changes
                _selectedBranch = null;
                _selectedYear = null;
                _userFound = false;
                _fullNameController.clear();
                _idController.clear();
                _selectedSection = null; // Reset
             });
          },
        ),
        
        if (_selectedRole != null) ...[
            const SizedBox(height: 15),
            CustomTextField(
                label: _getIdLabel(), 
                placeholder: _getIdPlaceholder(), 
                controller: _idController,
                textCapitalization: TextCapitalization.characters,
                inputFormatters: (_selectedRole == 'Student' || _selectedRole == 'Parent') 
                   ? [
                       FilteringTextInputFormatter.allow(RegExp(r'[A-Z0-9-]')),
                       LengthLimitingTextInputFormatter(16), 
                       StudentIdFormatter(isParent: _selectedRole == 'Parent'),
                     ] 
                   : [],
            ),
             const SizedBox(height: 5),
             const SizedBox(height: 5),
            Text("Format: 12345-BRANCH-123 (Check for existing record)", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
        ]
      ],
    );
  }

  String _getIdLabel() {
    if (_selectedRole == 'Student') return 'Student ID';
    if (_selectedRole == 'Parent') return 'Child\'s ID (P- auto added)';
    if (_selectedRole == 'Faculty') return 'Faculty ID';
    return 'ID';
  }
  
  String _getIdPlaceholder() {
    if (_selectedRole == 'Student') return 'e.g. 23634-CM-071';
    if (_selectedRole == 'Parent') return 'e.g. 23634-CM-071';
    return 'Enter ID';
  }

  // Step 2 Updated
  Widget _buildStep2() {
    // ... (Labels Logic Unchanged)
    String idLabel = 'ID';
    String idPlaceholder = 'Enter ID';
    // (Collapsed for brevity, keep existing logic)
    
     // Visibility Logic
    bool showBranch = ['Student', 'Parent', 'Faculty', 'HOD'].contains(_selectedRole);
    bool showYear = ['Student', 'Parent'].contains(_selectedRole);
    // bool showSemester = same as showYear
    bool showDob = ['Student', 'Faculty', 'HOD', 'Principal'].contains(_selectedRole);
    bool showProfessional = ['Faculty', 'HOD', 'Principal'].contains(_selectedRole);
    bool showPhone = ['Parent', 'Faculty', 'HOD', 'Principal'].contains(_selectedRole);
    bool showSection = ['Student'].contains(_selectedRole);

    return Column(
      children: [
        CustomTextField(
          label: 'Full Name', 
          placeholder: 'Enter Full Name', 
          controller: _fullNameController,
          readOnly: _userFound,
        ),
        if (_userFound)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Text("Name auto-filled from records", style: GoogleFonts.poppins(fontSize: 12, color: Colors.green, fontStyle: FontStyle.italic)),
          ),
        
        // Branch
        if (showBranch)
          CustomModalDropdown(
            label: 'Branch',
            value: _selectedBranch,
            options: _branches,
            onChanged: (val) {
               setState(() {
                  _selectedBranch = val;
                  // Reset dependents
                  _selectedYear = null;
                  _selectedSemester = null;
                  _selectedSection = null;
                  _sections = ['Section A']; // Reset to default
               });
            },
          ),

        // Year
        if (showYear)
          CustomModalDropdown(
            label: 'Course Year',
            value: _selectedYear,
            options: _years,
            onChanged: (val) {
               setState(() {
                  _selectedYear = val;
                  _selectedSemester = null;
                  _updateSemesters(); 
                  _loadSections(); // Fetch sections based on new year & branch
               });
            },
          ),
          
        // Semester (New)
        if (showYear && _selectedYear != null)
           CustomModalDropdown(
            label: 'Semester',
            value: _selectedSemester,
            options: _availableSemesters,
            onChanged: (val) => setState(() => _selectedSemester = val),
          ),
          
        // Section
        if (showSection && _selectedYear != null) // Only show if year selected (which loads sections)
          CustomModalDropdown(
            label: 'Section',
            value: _selectedSection,
            options: _sections, // Dynamic list
            onChanged: (val) => setState(() => _selectedSection = val),
          ),
          
        // Date of Birth
        if (showDob)
          CustomTextField(
            label: 'Date of Birth',
            placeholder: 'YYYY-MM-DD',
            controller: _dobController,
            readOnly: true,
            onTap: () => _selectDate(context),
            suffixIcon: const Icon(Icons.calendar_today, color: Color(0xFF666666)),
          ),
          
        if (showProfessional) ...[
          // ... (Experience & Email Unchanged)
           CustomTextField(
            label: 'Years of Experience',
            placeholder: 'e.g. 5',
            controller: _experienceController,
            keyboardType: TextInputType.number,
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(2),
            ],
          ),
          CustomTextField(
            label: 'Email ID',
            placeholder: 'Enter Email',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
          ),
        ],

        if (showPhone)
          CustomTextField(
            label: 'Phone Number',
            placeholder: 'Enter Phone Number',
            controller: _phoneController,
            keyboardType: TextInputType.phone,
          ),
      ],
    );
  }


  Widget _buildStep3() {
    return Column(
      children: [
        CustomTextField(
          label: 'Password',
          placeholder: 'Create Password',
          controller: _passwordController,
          isPassword: true,
        ),
        CustomTextField(
          label: 'Confirm Password',
          placeholder: 'Confirm Password',
          controller: _confirmPasswordController,
          isPassword: true,
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.getAdaptiveOverlayStyle(true), // Signup gradient is dark blue
      child: Scaffold(
        resizeToAvoidBottomInset: true, // Allow content to move up for keyboard
        extendBodyBehindAppBar: true,
        appBar: AppBar(
          leading: IconButton(
              icon: const Icon(Icons.arrow_back, color: Colors.white),
              onPressed: () => Navigator.pop(context)
            ),
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        body: Stack(
          children: [
            // Fixed Background to prevent recalculating gradient on keyboard resize
            const Positioned.fill(
              child: RepaintBoundary(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: AppColors.signupGradient,
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                    ),
                  ),
                ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  Expanded(
                    child: Center(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        padding: const EdgeInsets.all(24.0),
                        child: RepaintBoundary(
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
                                  'Create Account',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: const Color(0xFF333333),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Step $_currentStep of 3',
                                  textAlign: TextAlign.center,
                                  style: GoogleFonts.poppins(
                                    fontSize: 16,
                                    color: const Color(0xFF666666),
                                  ),
                                ),
                                const SizedBox(height: 24),
                                _buildCurrentStep(),
                                const SizedBox(height: 24),
                                _buildNavigationButtons(),
                                const SizedBox(height: 16),
                                _buildLoginLink(),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCurrentStep() {
    if (_currentStep == 1) return _buildStep1();
    if (_currentStep == 2) return _buildStep2();
    return _buildStep3();
  }

  Widget _buildNavigationButtons() {
    return Row(
      children: [
        if (_currentStep > 1) 
          Expanded(
            child: Container(
              margin: const EdgeInsets.only(right: 8),
              child: ElevatedButton(
                onPressed: _prevStep,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.grey,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: Text(
                  'Back',
                  style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                ),
              ),
            ),
          ),
        
        Expanded(
          child: ElevatedButton(
            onPressed: _currentStep < 3 ? _nextStep : (_isSigningUp ? null : _handleSignup),
            style: ElevatedButton.styleFrom(
              backgroundColor: _currentStep < 3 ?  AppColors.primaryButton : AppColors.secondaryButton,
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            child: _isSigningUp || _checkingUser
                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                : Text(
                    _currentStep < 3 ? 'Next' : 'Sign Up',
                    style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white),
                  ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginLink() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Already have an account? ",
          style: GoogleFonts.poppins(color: const Color(0xFF666666)),
        ),
        GestureDetector(
          onTap: () => Navigator.pop(context),
          child: Text(
            'Login',
            style: GoogleFonts.poppins(
              color: AppColors.primaryButton,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }
  String _maskId(String id) {
    if (id.isEmpty) return id;
    
    // Handle Parent ID (P-...)
    bool isParent = id.startsWith("P-");
    String textToMask = isParent ? id.substring(2) : id;
    
    List<String> parts = textToMask.split('-');
    if (parts.isNotEmpty) {
       // Mask first part (e.g. 23634 -> 2****)
       String firstPart = parts[0];
       if (firstPart.length > 1) {
         String maskedFirst = firstPart[0] + ('*' * (firstPart.length - 1));
         parts[0] = maskedFirst;
       }
    }
    
    String masked = parts.join('-');
    return isParent ? "P-$masked" : masked;
  }
} // End _SignupScreenState

class StudentIdFormatter extends TextInputFormatter {
  final bool isParent;
  StudentIdFormatter({this.isParent = false});

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    String text = newValue.text.toUpperCase();
    
    // Pass if empty or deleting fully
    if (text.isEmpty) return newValue;

    // Handle Parent "P-"
    if (isParent) {
       if (!text.startsWith('P-')) {
          text = 'P-$text'; // Auto-fix prefix
       }
    }
    
    // Work on the "core" ID (without P-)
    String prefix = isParent ? "P-" : "";
    String core = isParent && text.length >= 2 ? text.substring(2) : text;
    
    // Cleaning: Only keep valid chars (Digits, Letters, -)
    // Note: User deleted a character?
    bool isDeleting = newValue.text.length < oldValue.text.length;
    
    if (isDeleting) return newValue; // Allow standard deletion without logic interfering too much

    // Clean input: remove implicit chars for processing
    String clean = core.replaceAll('-', '').replaceAll(RegExp(r'[^A-Z0-9]'), '');
    
    StringBuffer formatted = StringBuffer();
    
    // 1. First 5 Digits
    for (int i = 0; i < clean.length; i++) {
        if (i == 5) formatted.write('-'); // Auto dash after 5th char
        if (i > 5) {
             // We are in Branch section
             // We need to detect when to put next dash.
             // Branch can be 1-4 chars. So we can't auto-dash strictly on count unless we know max length.
             // BUT user requirement says: "numeric automatic '-' ... alphabetic '-' again 3 digits".
             // We can detect when digits start again to insert dash?
             
             // Simple heuristic: If it was a letter and now it's a number, insert dash
             bool prevIsLetter = RegExp(r'[A-Z]').hasMatch(clean[i-1]);
             bool currIsDigit = RegExp(r'[0-9]').hasMatch(clean[i]);
             
             if (prevIsLetter && currIsDigit) {
                 formatted.write('-');
             }
        }
        
        formatted.write(clean[i]);
    }
    
    String finalResult = prefix + formatted.toString();
    
    return TextEditingValue(
      text: finalResult,
      selection: TextSelection.collapsed(offset: finalResult.length),
    );
  }
}
