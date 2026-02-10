import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AddChildScreen extends StatefulWidget {
  const AddChildScreen({super.key});

  @override
  State<AddChildScreen> createState() => _AddChildScreenState();
}

class _AddChildScreenState extends State<AddChildScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _studentIdController = TextEditingController();
  final TextEditingController _studentNameController = TextEditingController();
  
  String? _selectedBranch;
  String? _selectedYear;
  
  final List<String> _branches = ['Computer Engineering', 'Civil Engineering', 'Mechanical', 'Auto Mobile', 'E&C'];
  final List<String> _years = ['1st Year', '2nd Year', '3rd Year'];

  bool _isLoading = false;

  @override
  void dispose() {
    _studentIdController.dispose();
    _studentNameController.dispose();
    super.dispose();
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // TODO: Implement actual API call to send request to HOD
    // Endpoint: /api/parents/request-child-access
    // Body: { parent_id: ..., student_id: ... }
    
    await Future.delayed(const Duration(seconds: 1)); // Mock delay

    if (mounted) {
      setState(() => _isLoading = false);
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text("Request Sent", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text("Your request to add this child has been sent to the Branch HOD for approval.\n\nOnce approved, the student profile will appear in your dashboard.", style: GoogleFonts.poppins()),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to dashboard
              },
              child: Text("OK", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            )
          ],
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      appBar: AppBar(
        title: Text("Add Another Child", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        iconTheme: IconThemeData(color: theme.iconTheme.color),
        titleTextStyle: TextStyle(color: theme.textTheme.bodyLarge?.color, fontSize: 20, fontWeight: FontWeight.bold),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                "Link Student Account",
                style: GoogleFonts.poppins(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Text(
                "Enter the student details below to request access. This request will be sent to the HOD for verification.",
                style: GoogleFonts.poppins(color: Colors.grey, fontSize: 14),
              ),
              const SizedBox(height: 30),

              _buildTextField(
                controller: _studentIdController,
                label: "Student ID",
                hint: "e.g. STU-2024-001",
                icon: Icons.badge_outlined,
                validator: (value) {
                  if (value == null || value.isEmpty) return "Please enter Student ID";
                  return null;
                },
                isDark: isDark,
              ),
              const SizedBox(height: 20),
              _buildTextField(
                controller: _studentNameController,
                label: "Student Name",
                hint: "Enter student's full name",
                icon: Icons.person_outline,
                validator: (value) {
                  if (value == null || value.isEmpty) return "Please enter Student Name";
                  return null;
                },
                isDark: isDark,
              ),

              const SizedBox(height: 20),
              
              _buildDropdown(
                label: "Branch",
                hint: "Select Branch",
                icon: Icons.category_outlined,
                value: _selectedBranch,
                items: _branches,
                onChanged: (val) => setState(() => _selectedBranch = val),
                isDark: isDark,
              ),
              const SizedBox(height: 20),

              _buildDropdown(
                label: "Year",
                hint: "Select Year",
                icon: Icons.calendar_today_outlined,
                value: _selectedYear,
                items: _years,
                onChanged: (val) => setState(() => _selectedYear = val),
                isDark: isDark,
              ),

              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: _isLoading ? null : _submitRequest,
                style: ElevatedButton.styleFrom(
                  backgroundColor: theme.primaryColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  elevation: 2,
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : Text(
                      "Send Request",
                      style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    required bool isDark,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          validator: validator,
          style: GoogleFonts.poppins(),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.grey),
            prefixIcon: Icon(icon, color: Colors.grey),
            filled: true,
            fillColor: isDark ? const Color(0xFF1C1C2E) : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blueAccent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDropdown({
    required String label,
    required String hint,
    required IconData icon,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          value: value,
          items: items.map((item) => DropdownMenuItem(
            value: item,
            child: Text(item, style: GoogleFonts.poppins())
          )).toList(),
          onChanged: onChanged,
          validator: (val) => val == null ? "Please select $label" : null,
          style: GoogleFonts.poppins(color: isDark ? Colors.white : Colors.black87),
          dropdownColor: isDark ? const Color(0xFF222240) : Colors.white,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.grey),
            prefixIcon: Icon(icon, color: Colors.grey),
            filled: true,
            fillColor: isDark ? const Color(0xFF1C1C2E) : Colors.grey[100],
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
             enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: isDark ? Colors.white10 : Colors.grey[200]!),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide(color: Colors.blueAccent),
            ),
          ),
        ),
      ],
    );
  }
}
