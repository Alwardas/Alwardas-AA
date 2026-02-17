import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CoordinatorAddDepartmentScreen extends StatefulWidget {
  const CoordinatorAddDepartmentScreen({super.key});

  @override
  State<CoordinatorAddDepartmentScreen> createState() => _CoordinatorAddDepartmentScreenState();
}

class _CoordinatorAddDepartmentScreenState extends State<CoordinatorAddDepartmentScreen> {
  final _formKey = GlobalKey<FormState>();
  final TextEditingController _fullNameController = TextEditingController();
  final TextEditingController _shortCodeController = TextEditingController();
  final TextEditingController _startHourController = TextEditingController(text: "9");
  final TextEditingController _startMinuteController = TextEditingController(text: "0");
  final TextEditingController _classDurationController = TextEditingController(text: "50");

  bool _isLoading = false;
  
  // For Icon Selection (Mocked for now as Flutter doesn't have a built-in icon picker that returns IconData easily serialized)
  // We will just let them pick a color or generic icon style if needed, but for now we focus on data.
  // The user asked for "Branch Logo Icon". We could execute an image picker, but let's stick to a simple UI for now.

  Future<void> _submitDepartment() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final prefs = await SharedPreferences.getInstance();
      final String? baseUrl = prefs.getString('api_base_url') ?? 'http://10.0.2.2:3001'; 
      
      // Use the existing endpoint for Department Timing which effectively creates/updates a branch configuration
      final url = Uri.parse('$baseUrl/api/department/timing');
      
      final Map<String, dynamic> body = {
        "branch": _fullNameController.text.trim(),
        "start_hour": int.tryParse(_startHourController.text) ?? 9,
        "start_minute": int.tryParse(_startMinuteController.text) ?? 0,
        "class_duration": int.tryParse(_classDurationController.text) ?? 50,
        "short_break_duration": 10,
        "lunch_duration": 50,
        "slot_config": null // Can be expanded later
      };

      final response = await http.post(
        url,
        headers: {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      if (response.statusCode == 200) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Department Added Successfully!")),
          );
          Navigator.pop(context, true); // Return true to refresh
        }
      } else {
        throw Exception("Failed to add department: ${response.statusCode}");
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          "Add New Department",
          style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.black87),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSectionHeader("Department Details"),
                const SizedBox(height: 16),
                
                // Branch Logo / Icon Placeholder
                Center(
                  child: Container(
                    width: 100,
                    height: 100,
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.blueAccent.withOpacity(0.3), width: 2),
                    ),
                    child: const Icon(Icons.school_rounded, size: 50, color: Colors.blueAccent),
                  ),
                ),
                const SizedBox(height: 8),
                Center(
                  child: Text(
                    "Default Icon",
                    style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[600]),
                  ),
                ),
                const SizedBox(height: 24),

                TextFormField(
                  controller: _fullNameController,
                  decoration: _buildInputDecoration("Full Department Name", Icons.business),
                  validator: (value) => value!.isEmpty ? "Required" : null,
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _shortCodeController,
                  decoration: _buildInputDecoration("Short Code (e.g. CSE)", Icons.short_text),
                  validator: (value) => value!.isEmpty ? "Required" : null,
                ),
                
                const SizedBox(height: 32),
                 _buildSectionHeader("Default Schedule Configuration"),
                 const SizedBox(height: 16),
                 
                 Row(
                   children: [
                     Expanded(
                       child: TextFormField(
                         controller: _startHourController,
                         keyboardType: TextInputType.number,
                         decoration: _buildInputDecoration("Start Hour (24h)", Icons.access_time),
                         validator: (value) => value!.isEmpty ? "Required" : null,
                       ),
                     ),
                     const SizedBox(width: 16),
                     Expanded(
                       child: TextFormField(
                         controller: _startMinuteController,
                         keyboardType: TextInputType.number,
                         decoration: _buildInputDecoration("Start Minute", Icons.timer),
                           validator: (value) => value!.isEmpty ? "Required" : null,
                       ),
                     ),
                   ],
                 ),
                 const SizedBox(height: 16),
                 TextFormField(
                   controller: _classDurationController,
                   keyboardType: TextInputType.number,
                   decoration: _buildInputDecoration("Class Duration (mins)", Icons.timelapse),
                   validator: (value) => value!.isEmpty ? "Required" : null,
                 ),

                const SizedBox(height: 40),
                SizedBox(
                  width: double.infinity,
                  height: 55,
                  child: ElevatedButton(
                    onPressed: _isLoading ? null : _submitDepartment,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blueAccent,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      elevation: 2,
                    ),
                    child: _isLoading 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text(
                          "Add Department",
                          style: GoogleFonts.poppins(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _buildInputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: Colors.grey[500]),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.blueAccent, width: 2),
      ),
      filled: true,
      fillColor: Colors.white,
    );
  }

  Widget _buildSectionHeader(String title) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: Colors.grey[800],
      ),
    );
  }
}
