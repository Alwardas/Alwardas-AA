import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DesktopUserManagementView extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DesktopUserManagementView({super.key, required this.userData});

  @override
  State<DesktopUserManagementView> createState() => _DesktopUserManagementViewState();
}

class _DesktopUserManagementViewState extends State<DesktopUserManagementView> {
  String _selectedRole = 'Faculty';

  final List<String> _roles = [
    'Super Admin',
    'Admin',
    'Principal',
    'Coordinator',
    'HOD',
    'Faculty',
    'Accounts Staff'
  ];

  final Map<String, List<String>> _permissions = {
    'View': ['Student Profile', 'Attendance Logs', 'Marks Ledger', 'Fee Balances'],
    'Create': ['New Admissions', 'Timetable Slots', 'Announcements'],
    'Edit': ['Marks Update', 'Attendance Correct'],
    'Delete': ['Users Remove', 'Subject Clearance'],
    'Approve': ['Fee Adjustments', 'Leave Requests', 'Profile Updates'],
  };

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF0F172A),
      padding: const EdgeInsets.all(30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'User Management & Role Access Control (RBAC)',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Approve user registration requests and adjust role permissions matrix',
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main split
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Role-based permissions matrix
                Expanded(
                  flex: 3,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Permissions Matrix Configurations',
                              style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                            ),
                            Container(
                              height: 38,
                              padding: const EdgeInsets.symmetric(horizontal: 10),
                              decoration: BoxDecoration(
                                color: const Color(0xFF0F172A),
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: Colors.white10),
                              ),
                              child: DropdownButtonHideUnderline(
                                child: DropdownButton<String>(
                                  value: _selectedRole,
                                  dropdownColor: const Color(0xFF1E293B),
                                  style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12),
                                  onChanged: (val) {
                                    setState(() => _selectedRole = val!);
                                  },
                                  items: _roles.map<DropdownMenuItem<String>>((String value) {
                                    return DropdownMenuItem<String>(
                                      value: value,
                                      child: Text(value),
                                    );
                                  }).toList(),
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Expanded(child: _buildPermissionsMatrix()),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 20),

                // 2. Pending Approvals list
                Expanded(
                  flex: 2,
                  child: Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF1E293B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white10),
                    ),
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pending Registration Approvals',
                          style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Verify institution affiliation before activation',
                          style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11),
                        ),
                        const SizedBox(height: 20),
                        Expanded(child: _buildPendingApprovalsList()),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPermissionsMatrix() {
    return ListView(
      children: _permissions.keys.map((category) {
        final subPerms = _permissions[category]!;
        return Padding(
          padding: const EdgeInsets.only(bottom: 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                category,
                style: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 13, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: subPerms.map((perm) {
                  return Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF0F172A),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.white10),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(perm, style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12)),
                        const SizedBox(width: 10),
                        const Icon(Icons.check_circle, color: Colors.greenAccent, size: 16),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildPendingApprovalsList() {
    final List<Map<String, dynamic>> pending = [
      {'name': 'Ramesh Kumar', 'id': 'FAC-PRE-812', 'role': 'Faculty'},
      {'name': 'Jyothi Sen', 'id': 'ACC-PRE-304', 'role': 'Accounts Staff'},
    ];

    return ListView.builder(
      itemCount: pending.length,
      itemBuilder: (context, index) {
        final item = pending[index];
        return Card(
          color: const Color(0xFF0F172A),
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item['name'], style: GoogleFonts.poppins(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold)),
                Text('${item['id']} • ${item['role']}', style: GoogleFonts.poppins(color: Colors.white38, fontSize: 11)),
                const SizedBox(height: 12),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(onPressed: () {}, child: const Text('Reject', style: TextStyle(color: Colors.redAccent, fontSize: 12))),
                    const SizedBox(width: 8),
                    ElevatedButton(
                      onPressed: () {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(content: Text('User ${item['name']} approved. Login credentials activated.')),
                        );
                      },
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                      child: const Text('Approve', style: TextStyle(fontSize: 12)),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
