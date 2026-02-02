import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';

class StudentDetailsScreen extends StatefulWidget {
  final String userId;
  final String userName; // For immediate display while loading

  const StudentDetailsScreen({super.key, required this.userId, required this.userName});

  @override
  State<StudentDetailsScreen> createState() => _StudentDetailsScreenState();
}

class _StudentDetailsScreenState extends State<StudentDetailsScreen> {
  bool _loading = true;
  Map<String, dynamic>? _studentData;

  // Edit Controllers
  final _nameController = TextEditingController();
  final _idController = TextEditingController();
  final _branchController = TextEditingController();
  final _yearController = TextEditingController();
  final _semesterController = TextEditingController();
  final _batchController = TextEditingController();
  final _dobController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchStudentDetails();
  }

  Future<void> _fetchStudentDetails() async {
    setState(() => _loading = true);
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/student/profile').replace(queryParameters: {'userId': widget.userId});
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _studentData = json.decode(response.body);
            _loading = false;
          });
        }
      } else {
        throw Exception('Failed to load profile');
      }
    } catch (e) {
      if (mounted) {
        setState(() => _loading = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    }
  }

  Future<void> _updateStudent() async {
    // Basic Validation
    if (_nameController.text.isEmpty || _idController.text.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Name and ID are required")));
        return;
    }

    try {
      final body = {
        'userId': widget.userId,
        'fullName': _nameController.text,
        'loginId': _idController.text,
        'branch': _branchController.text,
        'year': _yearController.text,
        'semester': _semesterController.text,
        'batchNo': _batchController.text,
        'dob': _dobController.text, // Ensure YYYY-MM-DD
      };

      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/user/update'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode(body),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          Navigator.pop(context); // Close dialog
          _fetchStudentDetails(); // Refresh
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Profile Updated Successfully")));
        }
      } else {
        throw Exception('Failed to update: ${response.body}');
      }
    } catch (e) {
      if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    }
  }

  void _showEditDialog() {
    if (_studentData == null) return;

    final themeProvider = Provider.of<ThemeProvider>(context, listen: false);
    final isDark = themeProvider.isDarkMode;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final dialogBg = isDark ? const Color(0xFF1E293B) : Colors.white;

    _nameController.text = _studentData!['fullName'] ?? '';
    _idController.text = _studentData!['loginId'] ?? '';
    _branchController.text = _studentData!['branch'] ?? '';
    _yearController.text = _studentData!['year'] ?? '';
    _semesterController.text = _studentData!['semester'] ?? '';
    _batchController.text = _studentData!['batchNo'] ?? '';
    _dobController.text = _studentData!['dob'] ?? '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: dialogBg,
        title: Text("Edit Student Details", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildTextField("Full Name", _nameController, textColor, subTextColor),
              const SizedBox(height: 10),
              _buildTextField("Student ID", _idController, textColor, subTextColor),
              const SizedBox(height: 10),
              _buildTextField("Branch", _branchController, textColor, subTextColor),
              const SizedBox(height: 10),
              _buildTextField("Year", _yearController, textColor, subTextColor),
              const SizedBox(height: 10),
              _buildTextField("Semester", _semesterController, textColor, subTextColor),
              const SizedBox(height: 10),
              _buildTextField("Batch", _batchController, textColor, subTextColor),
              const SizedBox(height: 10),
              _buildTextField("Date of Birth (YYYY-MM-DD)", _dobController, textColor, subTextColor),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancel"),
          ),
          ElevatedButton(
            onPressed: _updateStudent,
            child: const Text("Save"),
          ),
        ],
      ),
    );
  }

  Widget _buildTextField(String label, TextEditingController controller, Color textColor, Color subTextColor) {
    return TextField(
      controller: controller,
      style: GoogleFonts.poppins(color: textColor),
      decoration: InputDecoration(
        labelText: label,
        labelStyle: GoogleFonts.poppins(color: subTextColor),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: subTextColor.withOpacity(0.3))),
        enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: subTextColor.withOpacity(0.3))),
        focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: const BorderSide(color: Colors.blueAccent)),
        isDense: true,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    final textColor = theme.colorScheme.onSurface;
    final subTextColor = theme.colorScheme.secondary;
    final cardColor = theme.cardColor;

    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text("Student Profile", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold)),
        backgroundColor: const Color(0xFF1a4ab2),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit, color: Colors.white),
            onPressed: _showEditDialog,
            tooltip: "Edit Details",
          )
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _studentData == null
              ? Center(child: Text("No Data Found", style: GoogleFonts.poppins(color: textColor)))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Card
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(24),
                        decoration: BoxDecoration(
                          color: cardColor,
                          borderRadius: BorderRadius.circular(24),
                          boxShadow: [
                            BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15, offset: const Offset(0, 5))
                          ],
                        ),
                        child: Column(
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundColor: Colors.blueAccent.withOpacity(0.1),
                              child: Text(
                                (_studentData!['fullName'] ?? 'S')[0].toUpperCase(),
                                style: GoogleFonts.poppins(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.blueAccent),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              _studentData!['fullName'] ?? 'Unknown Name',
                              textAlign: TextAlign.center,
                              style: GoogleFonts.poppins(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: textColor,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              _studentData!['loginId'] ?? 'No ID',
                              style: GoogleFonts.poppins(
                                fontSize: 16,
                                color: subTextColor,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                      ),
                      
                      const SizedBox(height: 24),
                      Text("Academic Details", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 16),

                      GridView.count(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        crossAxisCount: 2,
                        childAspectRatio: 1.5,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        children: [
                          _buildDetailCard("Access Batch", _studentData!['batchNo'] ?? 'N/A', Icons.group, cardColor, textColor, subTextColor),
                          _buildDetailCard("Semester", _studentData!['semester'] ?? 'N/A', Icons.timeline, cardColor, textColor, subTextColor),
                          _buildDetailCard("Branch", _studentData!['branch'] ?? 'N/A', Icons.account_tree, cardColor, textColor, subTextColor),
                          _buildDetailCard("Year", _studentData!['year'] ?? 'N/A', Icons.calendar_today, cardColor, textColor, subTextColor),
                          _buildDetailCard("Date of Birth", _studentData!['dob'] ?? 'N/A', Icons.cake, cardColor, textColor, subTextColor),
                        ],
                      ),
                    ],
                  ),
                ),
    );
  }

  Widget _buildDetailCard(String title, String value, IconData icon, Color cardColor, Color textColor, Color subTextColor) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
         boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 10, offset: const Offset(0, 4))
         ]
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.blueAccent),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: GoogleFonts.poppins(fontSize: 12, color: subTextColor),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600, color: textColor),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
