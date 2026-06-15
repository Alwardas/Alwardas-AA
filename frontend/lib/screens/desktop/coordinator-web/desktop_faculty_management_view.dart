import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class DesktopFacultyManagementView extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DesktopFacultyManagementView({super.key, required this.userData});

  @override
  State<DesktopFacultyManagementView> createState() => _DesktopFacultyManagementViewState();
}

class _DesktopFacultyManagementViewState extends State<DesktopFacultyManagementView> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

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
                    'Faculty Workload & Scheduling Center',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Manage faculty profiles, monitor lecture workloads, track syllabus completion progress, and approve leave requests',
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Tabs headers
          TabBar(
            controller: _tabController,
            isScrollable: true,
            tabAlignment: TabAlignment.start,
            labelColor: Colors.blueAccent,
            unselectedLabelColor: Colors.white38,
            indicatorColor: Colors.blueAccent,
            dividerColor: Colors.white10,
            labelStyle: GoogleFonts.poppins(fontSize: 13, fontWeight: FontWeight.bold),
            tabs: const [
              Tab(text: 'Faculty Directory'),
              Tab(text: 'Syllabus Workloads'),
              Tab(text: 'Leave Approvals'),
            ],
          ),
          const SizedBox(height: 20),

          // Tabs Views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                _buildFacultyDirectory(),
                _buildSyllabusWorkloads(),
                _buildLeaveApprovals(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFacultyDirectory() {
    final List<Map<String, dynamic>> faculty = [
      {'id': 'FAC2026301', 'name': 'Dr. V. Rama Rao', 'dept': 'Computer Engineering', 'designation': 'HOD & Professor', 'email': 'ramarao.v@gmail.com', 'phone': '+91 9440123456'},
      {'id': 'FAC2026302', 'name': 'Mrs. K. Shanti', 'dept': 'Computer Engineering', 'designation': 'Assistant Professor', 'email': 'shanti.k@gmail.com', 'phone': '+91 9440654321'},
      {'id': 'FAC2026303', 'name': 'Mr. P. Srinivas', 'dept': 'Electronics & Communication', 'designation': 'Senior Lecturer', 'email': 'srinivas.p@gmail.com', 'phone': '+91 9885123456'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF0F172A).withOpacity(0.4),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(flex: 2, child: Text('Faculty ID', style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('Name', style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('Department', style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('Designation', style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('Email ID', style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 2, child: Text('Contact Phone', style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: faculty.length,
              itemBuilder: (context, index) {
                final item = faculty[index];
                return Container(
                  height: 48,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  decoration: const BoxDecoration(
                    border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
                  ),
                  child: Row(
                    children: [
                      Expanded(flex: 2, child: Text(item['id'], style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12))),
                      Expanded(flex: 3, child: Text(item['name'], style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                      Expanded(flex: 3, child: Text(item['dept'], style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12))),
                      Expanded(flex: 3, child: Text(item['designation'], style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12))),
                      Expanded(flex: 3, child: Text(item['email'], style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12))),
                      Expanded(flex: 2, child: Text(item['phone'], style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12))),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSyllabusWorkloads() {
    final List<Map<String, dynamic>> progress = [
      {'name': 'Dr. V. Rama Rao', 'subject': 'Java Programming', 'lectures': '32 / 45', 'completion': 0.71},
      {'name': 'Mrs. K. Shanti', 'subject': 'Data Structures', 'lectures': '40 / 45', 'completion': 0.88},
      {'name': 'Mr. P. Srinivas', 'subject': 'Digital Design', 'lectures': '18 / 45', 'completion': 0.40},
    ];

    return ListView.builder(
      itemCount: progress.length,
      itemBuilder: (context, index) {
        final item = progress[index];
        return Card(
          color: const Color(0xFF1E293B),
          margin: const EdgeInsets.only(bottom: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(item['name'], style: GoogleFonts.poppins(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 4),
                      Text(item['subject'], style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12)),
                    ],
                  ),
                ),
                Expanded(
                  flex: 1,
                  child: Text(
                    'Lectures: ${item['lectures']}',
                    style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13),
                  ),
                ),
                Expanded(
                  flex: 4,
                  child: Row(
                    children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: item['completion'],
                            backgroundColor: Colors.white10,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              item['completion'] > 0.8 ? Colors.greenAccent : (item['completion'] > 0.5 ? Colors.blueAccent : Colors.orangeAccent),
                            ),
                            minHeight: 8,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '${(item['completion'] * 100).toInt()}%',
                        style: GoogleFonts.poppins(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.bold),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildLeaveApprovals() {
    final List<Map<String, dynamic>> requests = [
      {'name': 'Mrs. K. Shanti', 'dates': '2026-06-18 to 2026-06-20', 'reason': 'Family emergency', 'status': 'Pending'},
    ];

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF1E293B),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white10),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          Container(
            color: const Color(0xFF0F172A).withOpacity(0.4),
            height: 44,
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(flex: 3, child: Text('Faculty Name', style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 3, child: Text('Requested Dates', style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                Expanded(flex: 4, child: Text('Reason', style: const TextStyle(color: Colors.white38, fontSize: 11, fontWeight: FontWeight.bold))),
                const SizedBox(width: 160), // action spacer
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          Expanded(
            child: requests.isEmpty
                ? Center(child: Text('No pending leave requests.', style: GoogleFonts.poppins(color: Colors.white38)))
                : ListView.builder(
                    itemCount: requests.length,
                    itemBuilder: (context, index) {
                      final item = requests[index];
                      return Container(
                        height: 52,
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        decoration: const BoxDecoration(
                          border: Border(bottom: BorderSide(color: Colors.white10, width: 0.5)),
                        ),
                        child: Row(
                          children: [
                            Expanded(flex: 3, child: Text(item['name'], style: GoogleFonts.poppins(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                            Expanded(flex: 3, child: Text(item['dates'], style: GoogleFonts.poppins(color: Colors.white70, fontSize: 12))),
                            Expanded(flex: 4, child: Text(item['reason'], style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12))),
                            Row(
                              children: [
                                TextButton(
                                  onPressed: () {},
                                  child: const Text('Reject', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                                ),
                                const SizedBox(width: 8),
                                ElevatedButton(
                                  onPressed: () {
                                    ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(content: Text('Leave request approved. Notification sent.')),
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blueAccent, foregroundColor: Colors.white),
                                  child: const Text('Approve', style: TextStyle(fontSize: 12)),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
