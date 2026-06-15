import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import '../../../core/api_config.dart';
import '../../../core/api_constants.dart';
class DesktopHodAdmissionView extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DesktopHodAdmissionView({super.key, required this.userData});

  @override
  State<DesktopHodAdmissionView> createState() => _DesktopHodAdmissionViewState();
}

class _DesktopHodAdmissionViewState extends State<DesktopHodAdmissionView> {
  final _formKey = GlobalKey<FormState>();
  int _activeStep = 0;

  // Step Controllers & Data
  // 1. Personal Info
  final _fullNameCtrl = TextEditingController();
  final _aadhaarCtrl = TextEditingController();
  final _dobCtrl = TextEditingController();
  final _mobileCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _marksCtrl1 = TextEditingController();
  final _marksCtrl2 = TextEditingController();
  String? _selectedGender;
  String? _selectedBloodGroup;

  // 2. Parent Info
  final _fatherNameCtrl = TextEditingController();
  final _motherNameCtrl = TextEditingController();
  final _parentMobileCtrl = TextEditingController();
  final _parentOccupationCtrl = TextEditingController();
  final _fatherAadhaarCtrl = TextEditingController();
  final _motherAadhaarCtrl = TextEditingController();
  // Bank details
  final _studentBankAccCtrl = TextEditingController();
  final _studentBankNameCtrl = TextEditingController();
  final _studentBankBranchCtrl = TextEditingController();
  final _studentBankIfscCtrl = TextEditingController();

  // 3. Academic Info
  bool _cetQualified = true;
  String _typeOfAdmission = 'CQ'; // CQ or SPOT
  final _hallTicketCtrl = TextEditingController();
  final _rankCtrl = TextEditingController();
  String _previousQualification = 'SSC';
  final _schoolNameCtrl = TextEditingController();
  final _schoolAddressCtrl = TextEditingController();
  final _schoolGradeCtrl = TextEditingController();
  final _schoolCgpaCtrl = TextEditingController();

  // 4. College Info
  String? _selectedBranch;
  String? _selectedSection = 'A';
  String? _selectedAcademicYear = '2025-2026';
  final _admissionDateCtrl = TextEditingController();

  // 5. Documents (Mock / Real path storage)
  Map<String, String> _uploadedDocs = {};

  final List<Map<String, dynamic>> _steps = [
    {'title': 'Personal Information', 'subtitle': 'Basic student details', 'icon': Icons.person_outline},
    {'title': 'Parent Information', 'subtitle': 'Parent / Guardian details', 'icon': Icons.people_outline},
    {'title': 'Academic Information', 'subtitle': 'Previous academic details', 'icon': Icons.school_outlined},
    {'title': 'College Information', 'subtitle': 'Course & admission details', 'icon': Icons.business_outlined},
    {'title': 'Documents', 'subtitle': 'Upload required documents', 'icon': Icons.description_outlined},
  ];

  @override
  void initState() {
    super.initState();
    _selectedBranch = widget.userData['branch'] ?? 'Computer Engineering';
    _admissionDateCtrl.text = DateFormat('yyyy-MM-dd').format(DateTime.now());
  }

  Future<void> _pickFile(String docName) async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['jpg', 'png', 'pdf'],
      );

      if (result != null && result.files.isNotEmpty) {
        setState(() {
          _uploadedDocs[docName] = result.files.first.name;
        });
        _showSnackBar("$docName selected: ${result.files.first.name}");
      }
    } catch (e) {
      _showSnackBar("Error selecting file: $e");
    }
  }

  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _selectDate(BuildContext context, TextEditingController controller) async {
    DateTime? picked = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime(1990),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() {
        controller.text = DateFormat('yyyy-MM-dd').format(picked);
      });
    }
  }

  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Perform Mock / Real signup/admission endpoint submission
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          backgroundColor: const Color(0xFF1E293B),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: Text("Confirm Admission", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
          content: Text(
            "Are you sure you want to register ${_fullNameCtrl.text} as a new student under branch $_selectedBranch?",
            style: GoogleFonts.poppins(color: Colors.white70),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text("Cancel", style: GoogleFonts.poppins(color: Colors.white38)),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(context);
                _saveAdmissionRecord();
              },
              style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent),
              child: Text("Confirm Submit", style: GoogleFonts.poppins(color: Colors.white)),
            ),
          ],
        ),
      );
    } else {
      _showSnackBar("Please check the form for missing or invalid details.");
    }
  }

  Future<void> _saveAdmissionRecord() async {
    // Package student payload
    final payload = {
      'full_name': _fullNameCtrl.text.trim(),
      'role': 'Student',
      'login_id': 'ADM' + DateFormat('yyyyMMddHHmmss').format(DateTime.now()).substring(4, 12),
      'branch': _selectedBranch,
      'year': '1st Year',
      'section': _selectedSection,
      'password': 'password123', // Default temporary pass
    };

    try {
      final response = await ApiConfig.post('${ApiConstants.baseUrl}/api/students/create', body: payload);
      if (response.success) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: const Color(0xFF1E293B),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            title: Row(
              children: [
                const Icon(Icons.check_circle_outline, color: Colors.greenAccent, size: 28),
                const SizedBox(width: 12),
                Text("Admission Success", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
              ],
            ),
            content: Text(
              "New student ${_fullNameCtrl.text} admitted successfully!\nGenerated Login ID: ${payload['login_id']}",
              style: GoogleFonts.poppins(color: Colors.white70),
            ),
            actions: [
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  _resetForm();
                },
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                child: Text("Okay", style: GoogleFonts.poppins(color: Colors.white)),
              ),
            ],
          ),
        );
      } else {
        _showSnackBar("Failed to register student: ${response.message}");
      }
    } catch (e) {
      _showSnackBar("Error connecting to server.");
    }
  }

  void _resetForm() {
    setState(() {
      _fullNameCtrl.clear();
      _aadhaarCtrl.clear();
      _dobCtrl.clear();
      _mobileCtrl.clear();
      _emailCtrl.clear();
      _marksCtrl1.clear();
      _marksCtrl2.clear();
      _fatherNameCtrl.clear();
      _motherNameCtrl.clear();
      _parentMobileCtrl.clear();
      _parentOccupationCtrl.clear();
      _fatherAadhaarCtrl.clear();
      _motherAadhaarCtrl.clear();
      _studentBankAccCtrl.clear();
      _studentBankNameCtrl.clear();
      _studentBankBranchCtrl.clear();
      _studentBankIfscCtrl.clear();
      _hallTicketCtrl.clear();
      _rankCtrl.clear();
      _schoolNameCtrl.clear();
      _schoolAddressCtrl.clear();
      _schoolGradeCtrl.clear();
      _schoolCgpaCtrl.clear();
      _uploadedDocs.clear();
      _activeStep = 0;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.transparent, // Let dark shell background show
      padding: const EdgeInsets.all(30),
      child: Form(
        key: _formKey,
        child: Column(
          children: [
            // Top Bar
            _buildTopBar(),
            const SizedBox(height: 24),

            // Stepper and Form layout split
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left Pane: Stepper selector
                  _buildStepperSidebar(),
                  const SizedBox(width: 24),

                  // Right Pane: Active Form Card
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E293B),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white10),
                      ),
                      padding: const EdgeInsets.all(30),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: SingleChildScrollView(
                              physics: const BouncingScrollPhysics(),
                              child: _buildActiveFormSection(),
                            ),
                          ),
                          const Divider(height: 40, color: Colors.white10),
                          _buildFormActions(),
                        ],
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

  Widget _buildTopBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'New Student Admission',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              Text(
                'Fill in all the details carefully to create a new student admission record.',
                style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
              ),
            ],
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: const Color(0xFF3b5998).withOpacity(0.2),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: const Color(0xFF3b5998).withOpacity(0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.calendar_today_outlined, color: Colors.blueAccent, size: 16),
                const SizedBox(width: 8),
                Text(
                  "Admission Year: 2025 - 2026",
                  style: GoogleFonts.poppins(color: Colors.blueAccent, fontWeight: FontWeight.bold, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepperSidebar() {
    return Container(
      width: 280,
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
      child: ListView.builder(
        itemCount: _steps.length,
        itemBuilder: (context, index) {
          final step = _steps[index];
          final isSelected = _activeStep == index;
          final isCompleted = _activeStep > index;

          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              onTap: () {
                setState(() {
                  _activeStep = index;
                });
              },
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                decoration: BoxDecoration(
                  color: isSelected ? const Color(0xFF3b5998).withOpacity(0.2) : Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: isSelected ? const Color(0xFF3b5998).withOpacity(0.5) : Colors.transparent,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? Colors.blueAccent
                            : isCompleted
                                ? Colors.green.withOpacity(0.2)
                                : const Color(0xFF0F172A),
                        shape: BoxShape.circle,
                        border: Border.all(color: isSelected ? Colors.transparent : Colors.white10),
                      ),
                      child: Icon(
                        isCompleted ? Icons.check : step['icon'],
                        color: isSelected
                            ? Colors.white
                            : isCompleted
                                ? Colors.greenAccent
                                : Colors.white38,
                        size: 16,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            step['title'],
                            style: GoogleFonts.poppins(
                              color: isSelected ? Colors.blueAccent : Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                            ),
                          ),
                          Text(
                            step['subtitle'],
                            style: GoogleFonts.poppins(
                              color: Colors.white60,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildActiveFormSection() {
    switch (_activeStep) {
      case 0:
        return _buildPersonalInformationForm();
      case 1:
        return _buildParentInformationForm();
      case 2:
        return _buildAcademicInformationForm();
      case 3:
        return _buildCollegeInformationForm();
      case 4:
        return _buildDocumentsUploadForm();
      default:
        return const SizedBox();
    }
  }

  Widget _buildPersonalInformationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("1. Personal Information"),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: "Full Name *",
                controller: _fullNameCtrl,
                hint: "Enter full name",
                validator: (v) => v!.isEmpty ? "Full Name is required" : null,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildTextField(
                label: "Aadhaar Number (optional)",
                controller: _aadhaarCtrl,
                hint: "Enter Aadhaar number",
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildDatePickerField(
                label: "Date of Birth *",
                controller: _dobCtrl,
                hint: "Select date of birth",
                validator: (v) => v!.isEmpty ? "Date of birth is required" : null,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildDropdownField(
                label: "Gender *",
                value: _selectedGender,
                items: const ["Male", "Female", "Other"],
                hint: "Select gender",
                onChanged: (val) => setState(() => _selectedGender = val),
                validator: (v) => v == null ? "Gender is required" : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField(
                label: "Blood Group",
                value: _selectedBloodGroup,
                items: const ["A+", "A-", "B+", "B-", "AB+", "AB-", "O+", "O-"],
                hint: "Select blood group",
                onChanged: (val) => setState(() => _selectedBloodGroup = val),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildTextField(
                label: "Mobile Number *",
                controller: _mobileCtrl,
                hint: "Enter mobile number",
                validator: (v) => v!.isEmpty ? "Mobile number is required" : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        _buildTextField(
          label: "Email *",
          controller: _emailCtrl,
          hint: "Enter email address",
          validator: (v) => v!.isEmpty ? "Email is required" : null,
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: "Identification Mark 1",
                controller: _marksCtrl1,
                hint: "As per SSC record",
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildTextField(
                label: "Identification Mark 2",
                controller: _marksCtrl2,
                hint: "As per SSC record",
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildParentInformationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("2. Parent Information"),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: "Father Name *",
                controller: _fatherNameCtrl,
                hint: "Enter father's name",
                validator: (v) => v!.isEmpty ? "Father name is required" : null,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildTextField(
                label: "Mother Name *",
                controller: _motherNameCtrl,
                hint: "Enter mother's name",
                validator: (v) => v!.isEmpty ? "Mother name is required" : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: "Parent Mobile *",
                controller: _parentMobileCtrl,
                hint: "Enter parent mobile number",
                validator: (v) => v!.isEmpty ? "Parent mobile number is required" : null,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildTextField(
                label: "Parent Occupation",
                controller: _parentOccupationCtrl,
                hint: "Enter parent occupation",
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: "Father Aadhaar Number",
                controller: _fatherAadhaarCtrl,
                hint: "Enter father's Aadhaar",
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildTextField(
                label: "Mother Aadhaar Number",
                controller: _motherAadhaarCtrl,
                hint: "Enter mother's Aadhaar",
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionHeader("Student Bank Details"),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: "Bank Account No.",
                controller: _studentBankAccCtrl,
                hint: "Enter account number",
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildTextField(
                label: "Bank Name",
                controller: _studentBankNameCtrl,
                hint: "e.g. State Bank of India",
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: "Branch",
                controller: _studentBankBranchCtrl,
                hint: "Enter bank branch",
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildTextField(
                label: "IFSC Code",
                controller: _studentBankIfscCtrl,
                hint: "Enter IFSC code",
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildAcademicInformationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("3. Academic Information"),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("CET Qualified? *", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Theme(
                        data: ThemeData(unselectedWidgetColor: Colors.white38),
                        child: Radio<bool>(
                          value: true,
                          groupValue: _cetQualified,
                          activeColor: Colors.blueAccent,
                          onChanged: (val) => setState(() => _cetQualified = val!),
                        ),
                      ),
                      const Text("YES", style: TextStyle(color: Colors.white)),
                      const SizedBox(width: 20),
                      Theme(
                        data: ThemeData(unselectedWidgetColor: Colors.white38),
                        child: Radio<bool>(
                          value: false,
                          groupValue: _cetQualified,
                          activeColor: Colors.blueAccent,
                          onChanged: (val) => setState(() => _cetQualified = val!),
                        ),
                      ),
                      const Text("NO", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("Type of Admission *", style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Theme(
                        data: ThemeData(unselectedWidgetColor: Colors.white38),
                        child: Radio<String>(
                          value: 'CQ',
                          groupValue: _typeOfAdmission,
                          activeColor: Colors.blueAccent,
                          onChanged: (val) => setState(() => _typeOfAdmission = val!),
                        ),
                      ),
                      const Text("CQ (Counselling)", style: TextStyle(color: Colors.white)),
                      const SizedBox(width: 20),
                      Theme(
                        data: ThemeData(unselectedWidgetColor: Colors.white38),
                        child: Radio<String>(
                          value: 'SPOT',
                          groupValue: _typeOfAdmission,
                          activeColor: Colors.blueAccent,
                          onChanged: (val) => setState(() => _typeOfAdmission = val!),
                        ),
                      ),
                      const Text("SPOT", style: TextStyle(color: Colors.white)),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: "Polycet Hall Ticket Number *",
                controller: _hallTicketCtrl,
                hint: "Enter hall ticket number",
                validator: (v) => v!.isEmpty ? "Hall ticket number is required" : null,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildTextField(
                label: "Rank *",
                controller: _rankCtrl,
                hint: "Enter rank",
                validator: (v) => v!.isEmpty ? "Rank is required" : null,
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        _buildSectionHeader("Schooling Record"),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField(
                label: "Standard Board *",
                value: _previousQualification,
                items: const ["SSC", "CBSE", "ICSE"],
                hint: "Select standard board",
                onChanged: (val) => setState(() => _previousQualification = val!),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildTextField(
                label: "School Name & Address",
                controller: _schoolNameCtrl,
                hint: "Enter school details",
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildTextField(
                label: "Grade / Mark Obtained",
                controller: _schoolGradeCtrl,
                hint: "e.g. 9.8 GPA or 550 Marks",
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildTextField(
                label: "CGPA %",
                controller: _schoolCgpaCtrl,
                hint: "e.g. 98%",
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCollegeInformationForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("4. College Information"),
        const SizedBox(height: 24),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField(
                label: "Branch *",
                value: _selectedBranch,
                items: const ["Computer Engineering", "Electronics & Communication Engineering", "Electrical & Electronics Engineering", "Mechanical Engineering", "Civil Engineering"],
                hint: "Select branch",
                onChanged: (val) => setState(() => _selectedBranch = val),
                validator: (v) => v == null ? "Branch is required" : null,
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildDropdownField(
                label: "Section *",
                value: _selectedSection,
                items: const ["A", "B", "C"],
                hint: "Select section",
                onChanged: (val) => setState(() => _selectedSection = val),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Row(
          children: [
            Expanded(
              child: _buildDropdownField(
                label: "Academic Year *",
                value: _selectedAcademicYear,
                items: const ["2025-2026", "2026-2027"],
                hint: "Select academic year",
                onChanged: (val) => setState(() => _selectedAcademicYear = val),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: _buildDatePickerField(
                label: "Admission Date *",
                controller: _admissionDateCtrl,
                hint: "Select admission date",
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildDocumentsUploadForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildSectionHeader("5. Documents Upload"),
        const SizedBox(height: 8),
        Text(
          "Upload clear and valid documents. Accepted formats: JPG, PNG, PDF (Max size: 2MB each)",
          style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
        ),
        const SizedBox(height: 24),
        GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: 3,
          crossAxisSpacing: 20,
          mainAxisSpacing: 20,
          childAspectRatio: 2.2,
          children: [
            _buildUploadCard("Student Photo", Icons.person_outline),
            _buildUploadCard("SSC Memo", Icons.description_outlined),
            _buildUploadCard("Intermediate/Diploma Memo", Icons.description_outlined),
            _buildUploadCard("Transfer Certificate", Icons.card_membership_outlined),
            _buildUploadCard("Income Certificate", Icons.account_balance_wallet_outlined),
            _buildUploadCard("Caste Certificate", Icons.badge_outlined),
          ],
        ),
      ],
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        color: Colors.white,
        fontSize: 16,
        fontWeight: FontWeight.bold,
      ),
    );
  }

  Widget _buildTextField({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white10),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDatePickerField({
    required String label,
    required TextEditingController controller,
    required String hint,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          readOnly: true,
          onTap: () => _selectDate(context, controller),
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: const TextStyle(color: Colors.white38),
            filled: true,
            fillColor: const Color(0xFF0F172A),
            suffixIcon: const Icon(Icons.calendar_today_outlined, color: Colors.blueAccent, size: 18),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white10),
            ),
          ),
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildDropdownField({
    required String label,
    required String? value,
    required List<String> items,
    required String hint,
    required Function(String?) onChanged,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white70),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          dropdownColor: const Color(0xFF1E293B),
          style: GoogleFonts.poppins(color: Colors.white, fontSize: 13),
          decoration: InputDecoration(
            filled: true,
            fillColor: const Color(0xFF0F172A),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white10),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Colors.white10),
            ),
          ),
          hint: Text(hint, style: GoogleFonts.poppins(color: Colors.white38, fontSize: 13)),
          items: items.map((String item) {
            return DropdownMenuItem<String>(
              value: item,
              child: Text(item, style: GoogleFonts.poppins(color: Colors.white, fontSize: 13)),
            );
          }).toList(),
          onChanged: onChanged,
          validator: validator,
        ),
      ],
    );
  }

  Widget _buildUploadCard(String docName, IconData icon) {
    final hasFile = _uploadedDocs.containsKey(docName);
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: hasFile ? Colors.green.withOpacity(0.1) : const Color(0xFF3b5998).withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(
              hasFile ? Icons.check : icon,
              color: hasFile ? Colors.greenAccent : Colors.blueAccent,
              size: 20,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  docName + " *",
                  style: GoogleFonts.poppins(color: Colors.white, fontSize: 11, fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  hasFile ? _uploadedDocs[docName]! : "No file selected",
                  style: GoogleFonts.poppins(color: Colors.white60, fontSize: 10),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          ElevatedButton(
            onPressed: () => _pickFile(docName),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF1E293B),
              foregroundColor: Colors.white,
              elevation: 0,
              side: const BorderSide(color: Colors.white10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            ),
            child: Text(
              hasFile ? "Change" : "Upload",
              style: GoogleFonts.poppins(fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormActions() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        if (_activeStep > 0)
          OutlinedButton.icon(
            onPressed: () {
              setState(() {
                _activeStep--;
              });
            },
            icon: const Icon(Icons.arrow_back),
            label: Text("Back", style: GoogleFonts.poppins()),
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        const SizedBox(width: 12),
        if (_activeStep < _steps.length - 1)
          ElevatedButton(
            onPressed: () {
              setState(() {
                _activeStep++;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3b5998),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Row(
              children: [
                Text("Continue", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                const Icon(Icons.arrow_forward, size: 16),
              ],
            ),
          )
        else ...[
          OutlinedButton(
            onPressed: _resetForm,
            style: OutlinedButton.styleFrom(
              foregroundColor: Colors.white70,
              side: const BorderSide(color: Colors.white10),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: Text("Save as Draft", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          ),
          const SizedBox(width: 12),
          ElevatedButton.icon(
            onPressed: _submitForm,
            icon: const Icon(Icons.check),
            label: Text("Submit Admission", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF3b5998),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ],
      ],
    );
  }
}
