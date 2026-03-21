import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/api_constants.dart';
import '../../../core/models/parent_request_model.dart';
import 'package:intl/intl.dart';

class ParentRequestsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  final String? studentId;
  final String? studentBranch;

  const ParentRequestsScreen({super.key, required this.userData, this.studentId, this.studentBranch});

  @override
  State<ParentRequestsScreen> createState() => _ParentRequestsScreenState();
}

class _ParentRequestsScreenState extends State<ParentRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<ParentRequest> _requests = [];
  bool _isLoading = true;
  String? _error;

  final _formKey = GlobalKey<FormState>();
  final _subjectController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _durationController = TextEditingController();
  String _selectedType = "Leave Application";
  bool _isSubmitting = false;

  final List<String> _requestTypes = [
    "Leave Application",
    "Late Arrival Permission",
    "Appointment Request",
    "Meeting Request",
    "Other"
  ];

  List<String> _selectedRoles = [];
  List<Map<String, dynamic>> _facultyList = [];
  List<String> _selectedFacultyIds = [];
  bool _isLoadingFaculty = false;
  final List<String> _availableRoles = ["Faculty", "HOD", "Principal", "Coordinator"];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchRequests();
  }

  Future<void> _fetchRequests() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final parentId = widget.userData['id'];
      final uri = Uri.parse(ApiConstants.getParentRequests).replace(queryParameters: {
        'parentId': parentId.toString(),
      });
      
      final response = await http.get(uri);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        setState(() {
          _requests = data.map((json) => ParentRequest.fromJson(json)).toList();
          _isLoading = false;
        });
      } else {
        setState(() {
          _error = "Failed to load requests: ${response.statusCode}";
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = "Error: $e";
        _isLoading = false;
      });
    }
  }

  Future<void> _fetchFacultyMembers() async {
    if (widget.studentBranch == null || widget.studentBranch!.isEmpty) return;
    setState(() => _isLoadingFaculty = true);
    try {
      final uri = Uri.parse(ApiConstants.facultyByBranch).replace(queryParameters: {
        'branch': widget.studentBranch
      });
      final response = await http.get(uri);
      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        if (mounted) {
          setState(() {
            _facultyList = data.map((e) => e as Map<String, dynamic>).toList();
          });
        }
      }
    } catch (e) {
      debugPrint("Error fetching faculty: $e");
    } finally {
      if (mounted) setState(() => _isLoadingFaculty = false);
    }
  }

  Future<void> _submitRequest() async {
    if (!_formKey.currentState!.validate()) return;
    if (widget.studentId == null) {
       ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Critical: Student ID missing")));
       return;
    }

    setState(() => _isSubmitting = true);

    try {
      final response = await http.post(
        Uri.parse(ApiConstants.submitParentRequest),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'parentId': widget.userData['id'],
          'studentId': widget.studentId,
          'requestType': _selectedType,
          'subject': _subjectController.text,
          'description': _descriptionController.text,
          'dateDuration': _durationController.text,
          'targetRoles': _selectedRoles.isNotEmpty ? _selectedRoles : null,
          'targetFacultyIds': _selectedFacultyIds.isNotEmpty ? _selectedFacultyIds : null,
        }),
      );

      if (response.statusCode == 200) {
        _subjectController.clear();
        _descriptionController.clear();
        _durationController.clear();
        setState(() {
           _selectedRoles.clear();
           _selectedFacultyIds.clear();
        });
        _fetchRequests();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Request Submitted Successfully!"), backgroundColor: Colors.green),
        );
        _tabController.animateTo(0);
      } else {
         ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Submission failed: ${response.statusCode}"), backgroundColor: Colors.red),
        );
      }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red),
      );
    } finally {
      setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;
     final cardColor = isDark ? const Color(0xFF1E1E24) : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: Text("Requests & Permissions", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: "History"),
            Tab(text: "New Request"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // History Tab
          _isLoading 
            ? const Center(child: CircularProgressIndicator())
            : _error != null
              ? Center(child: Text(_error!, style: GoogleFonts.poppins(color: Colors.red)))
              : _requests.isEmpty
                ? Center(child: Text("No requests found", style: GoogleFonts.poppins(color: Colors.grey)))
                : RefreshIndicator(
                    onRefresh: _fetchRequests,
                    child: ListView.builder(
                      padding: const EdgeInsets.all(20),
                      itemCount: _requests.length,
                      itemBuilder: (context, index) {
                        final req = _requests[index];
                        Color statusColor = Colors.orange;
                        if (req.status == 'Approved' || req.status == 'Completed') statusColor = Colors.green;
                        if (req.status == 'Rejected') statusColor = Colors.red;

                        return Container(
                          margin: const EdgeInsets.only(bottom: 15),
                          padding: const EdgeInsets.all(20),
                          decoration: BoxDecoration(
                            color: cardColor,
                            borderRadius: BorderRadius.circular(15),
                            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)]
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(req.requestType, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                    decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                                    child: Text(req.status, style: GoogleFonts.poppins(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                                  )
                                ],
                              ),
                              const SizedBox(height: 8),
                              Text(req.subject, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
                              Text(req.description, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
                              const SizedBox(height: 12),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Text(req.dateDuration, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
                                  Text(DateFormat('dd MMM yyyy').format(req.createdAt), style: GoogleFonts.poppins(fontSize: 11, color: Colors.grey)),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),

          // New Request Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text("Raise a New Request", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  _buildDropdown("Request Type", _requestTypes),
                  const SizedBox(height: 20),
                  _buildTextField("Subject", "Brief subject of the request", _subjectController),
                  const SizedBox(height: 20),
                  _buildTextField("Description", "Detailed explanation...", _descriptionController, maxLines: 4),
                  const SizedBox(height: 20),
                   _buildTextField("Date/Duration", "e.g. 12th Oct to 14th Oct", _durationController),
                  const SizedBox(height: 20),
                  _buildRoleSelector(),
                  if (_selectedRoles.contains('Faculty')) ...[
                     const SizedBox(height: 20),
                     _buildFacultySelector(),
                  ],
                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: _isSubmitting ? null : _submitRequest,
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      backgroundColor: Theme.of(context).primaryColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                    ),
                    child: _isSubmitting 
                      ? const CircularProgressIndicator(color: Colors.white)
                      : Text("Submit Request", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                  )
                ],
              ),
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String hint, TextEditingController controller, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(16)
          ),
          validator: (v) => v!.isEmpty ? "Required" : null,
        ),
      ],
    );
  }

  Widget _buildDropdown(String label, List<String> items) {
     return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
             color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : Colors.grey[100],
             borderRadius: BorderRadius.circular(12)
          ),
          child: DropdownButtonHideUnderline(
            child: DropdownButton<String>(
              isExpanded: true,
              value: _selectedType,
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.poppins()))).toList(),
              onChanged: (val) {
                if (val != null) {
                  setState(() => _selectedType = val);
                }
              },
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRoleSelector() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Send Request To", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: _availableRoles.map((role) {
            final isSelected = _selectedRoles.contains(role);
            return FilterChip(
              label: Text(role, style: GoogleFonts.poppins(color: isSelected ? Colors.white : (Theme.of(context).brightness == Brightness.dark ? Colors.white70 : Colors.black87))),
              selected: isSelected,
              selectedColor: Theme.of(context).primaryColor,
              backgroundColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : Colors.grey.withOpacity(0.1),
              onSelected: (bool selected) {
                setState(() {
                  if (selected) {
                    _selectedRoles.add(role);
                    if (role == 'Faculty' && _facultyList.isEmpty) {
                      _fetchFacultyMembers();
                    }
                  } else {
                    _selectedRoles.remove(role);
                    if (role == 'Faculty') {
                      _selectedFacultyIds.clear();
                    }
                  }
                });
              },
            );
          }).toList(),
        ),
      ],
    );
  }

  Widget _buildFacultySelector() {
    if (_isLoadingFaculty) {
      return const Center(child: Padding(padding: EdgeInsets.all(10), child: CircularProgressIndicator()));
    }
    if (_facultyList.isEmpty) {
      return Text("No faculty members found for this branch.", style: GoogleFonts.poppins(color: Colors.red));
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text("Select Faculty Member(s)", style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
           decoration: BoxDecoration(
             color: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : Colors.grey[100],
             borderRadius: BorderRadius.circular(12)
          ),
          child: Column(
            children: _facultyList.map((fac) {
              final id = fac['id'].toString();
              final name = fac['full_name'] ?? 'Unknown';
              final isSelected = _selectedFacultyIds.contains(id);
              
              return CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(name, style: GoogleFonts.poppins(fontSize: 14)),
                value: isSelected,
                activeColor: Theme.of(context).primaryColor,
                onChanged: (bool? val) {
                  setState(() {
                    if (val == true) {
                      _selectedFacultyIds.add(id);
                    } else {
                      _selectedFacultyIds.remove(id);
                    }
                  });
                },
              );
            }).toList(),
          )
        )
      ],
    );
  }
}
