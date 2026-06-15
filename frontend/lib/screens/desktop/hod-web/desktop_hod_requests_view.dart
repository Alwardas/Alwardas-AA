import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/api_config.dart';
import '../../../core/api_constants.dart';
import '../../../widgets/parent_requests_viewer.dart';

class DesktopHodRequestsView extends StatefulWidget {
  final Map<String, dynamic> userData;

  const DesktopHodRequestsView({super.key, required this.userData});

  @override
  State<DesktopHodRequestsView> createState() => _DesktopHodRequestsViewState();
}

class _DesktopHodRequestsViewState extends State<DesktopHodRequestsView> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  List<dynamic> _facultyRequests = []; // Subject requests
  List<dynamic> _facultySignups = [];   // Signup approvals
  bool _loadingRequests = true;
  bool _loadingSignups = true;
  final Map<String, String> _nameCache = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _fetchRequests();
    _fetchSignups();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchRequests() async {
    setState(() => _loadingRequests = true);
    final user = widget.userData;
    final branch = user['branch']?.toString() ?? '';

    if (branch.isNotEmpty) {
      await _fetchFacultyNames(branch);
    }

    try {
      final uri = '${ApiConstants.baseUrl}/api/notifications?userId=${user['id']}&role=${user['role']}&branch=${Uri.encodeComponent(branch)}';
      final response = await ApiConfig.get(uri);
      
      if (response.success && response.data != null) {
        final List<dynamic> data = response.data;
        final List<dynamic> mappedRequests = [];

        for (var n in data) {
          if (n['type'] == 'SUBJECT_APPROVAL') {
            String senderId = n['senderId']?.toString() ?? n['sender_id']?.toString() ?? '';
            String message = n['message'] ?? '';
            
            String facultyName = _nameCache[senderId] ?? 'Faculty';
            if (facultyName == 'Faculty') {
              await _fetchIndividualName(senderId);
              facultyName = _nameCache[senderId] ?? 'Faculty';
            }

            String subjectName = "Subject";
            if (message.contains("Faculty requested subject: ")) {
              subjectName = message.split("Faculty requested subject: ").last.trim();
            } else if (message.contains("requested subject:")) {
              subjectName = message.split("requested subject:").last.trim();
            } else {
              subjectName = message;
            }

            mappedRequests.add({
              'id': n['id'],
              'senderId': senderId,
              'type': 'subject_request',
              'faculty_name': facultyName,
              'subject_name': subjectName,
              'status': n['status'] ?? 'PENDING',
              'createdAt': n['createdAt']
            });
          }
        }

        setState(() {
          _facultyRequests = mappedRequests;
          _loadingRequests = false;
        });
      } else {
        setState(() => _loadingRequests = false);
      }
    } catch (e) {
      debugPrint("Error fetching requests: $e");
      setState(() => _loadingRequests = false);
    }
  }

  Future<void> _fetchSignups() async {
    setState(() => _loadingSignups = true);
    final user = widget.userData;
    final branch = user['branch']?.toString() ?? '';

    try {
      final uri = '${ApiConstants.baseUrl}/api/admin/users?role=Faculty&is_approved=false&branch=${Uri.encodeComponent(branch)}';
      final response = await ApiConfig.get(uri);
      
      if (response.success && response.data != null) {
        setState(() {
          _facultySignups = response.data;
          _loadingSignups = false;
        });
      } else {
        setState(() => _loadingSignups = false);
      }
    } catch (e) {
      debugPrint("Error fetching signups: $e");
      setState(() => _loadingSignups = false);
    }
  }

  Future<void> _fetchFacultyNames(String branch) async {
    try {
      final uri = '${ApiConstants.baseUrl}/api/faculty/by-branch?branch=${Uri.encodeComponent(branch)}';
      final response = await ApiConfig.get(uri);
      if (response.success && response.data != null) {
        final List<dynamic> data = response.data;
        for (var f in data) {
          final id = f['id']?.toString() ?? '';
          final name = f['name'] ?? f['full_name'] ?? 'Unknown';
          if (id.isNotEmpty) _nameCache[id] = name;
          final loginId = f['login_id']?.toString() ?? '';
          if (loginId.isNotEmpty) _nameCache[loginId] = name;
        }
      }
    } catch (e) {
      debugPrint("Error fetching names: $e");
    }
  }

  Future<void> _fetchIndividualName(String id) async {
    if (id.isEmpty || _nameCache.containsKey(id)) return;
    try {
      final uri = '${ApiConstants.baseUrl}/api/users/$id';
      final response = await ApiConfig.get(uri);
      if (response.success && response.data != null) {
        final name = response.data['full_name'] ?? response.data['name'] ?? '';
        if (name.isNotEmpty) {
          _nameCache[id] = name;
        }
      }
    } catch (_) {}
  }

  Future<void> _handleAction(String requestId, String action) async {
    final index = _facultyRequests.indexWhere((r) => r['id'] == requestId);
    if (index == -1) return;
    final request = _facultyRequests[index];

    try {
      final response = await ApiConfig.post(
        '${ApiConstants.baseUrl}/api/hod/approve-subject',
        body: {
          'notificationId': requestId,
          'senderId': request['senderId'],
          'action': action
        },
      );

      if (response.success) {
        setState(() {
          if (action == 'APPROVE') {
            _facultyRequests[index]['status'] = 'APPROVED';
            _showSnackBar("Request Approved");
          } else {
            _facultyRequests.removeAt(index);
            _showSnackBar("Request Rejected");
          }
        });
      } else {
        _showSnackBar("Failed: ${response.message}");
      }
    } catch (e) {
      _showSnackBar("Network Error");
    }
  }

  Future<void> _handleSignupAction(String userId, String action) async {
    try {
      final response = await ApiConfig.post(
        '${ApiConstants.baseUrl}/api/admin/users/approve',
        body: {
          'user_id': userId,
          'action': action
        },
      );

      if (response.success) {
        _showSnackBar("Account ${action == 'APPROVE' ? 'Approved' : 'Rejected'}!");
        _fetchSignups();
      } else {
        _showSnackBar("Failed: ${response.message}");
      }
    } catch (e) {
      _showSnackBar("Network Error");
    }
  }

  void _showSnackBar(String text) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
    }
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
                    'Administrative Approvals Portal',
                    style: GoogleFonts.poppins(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Approve and manage faculty signups, course subject requests, and student leave submissions',
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
              TabBar(
                controller: _tabController,
                isScrollable: true,
                indicatorColor: Colors.blueAccent,
                labelColor: Colors.blueAccent,
                unselectedLabelColor: Colors.white38,
                labelStyle: GoogleFonts.poppins(fontWeight: FontWeight.bold),
                tabs: const [
                  Tab(text: "Faculty Signups"),
                  Tab(text: "Subject Requests"),
                  Tab(text: "Parent Requests"),
                ],
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Main Tab Content Area
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Tab 1: Faculty Signups Grid
                _loadingSignups
                    ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                    : _facultySignups.isEmpty
                        ? _buildEmptyState(Icons.person_add_disabled_outlined, "No pending signups")
                        : _buildSignupsGrid(),

                // Tab 2: Faculty Subject Requests Grid
                _loadingRequests
                    ? const Center(child: CircularProgressIndicator(color: Colors.blueAccent))
                    : _facultyRequests.isEmpty
                        ? _buildEmptyState(Icons.assignment_turned_in_outlined, "No pending requests")
                        : _buildRequestsGrid(),

                // Tab 3: Parent Requests (using standard viewer)
                ParentRequestsViewer(userData: widget.userData, requestFrom: 'Parent'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(IconData icon, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 64, color: Colors.white24),
          const SizedBox(height: 20),
          Text(
            message,
            style: GoogleFonts.poppins(color: Colors.white38, fontSize: 16),
          ),
        ],
      ),
    );
  }

  Widget _buildSignupsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.6,
      ),
      itemCount: _facultySignups.length,
      itemBuilder: (context, index) {
        final u = _facultySignups[index];
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.blueAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Faculty Registration",
                      style: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  Text(
                    u['login_id'] ?? '',
                    style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                u['full_name'] ?? 'Unknown',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                "Branch: ${u['branch'] ?? 'N/A'}",
                style: GoogleFonts.poppins(color: Colors.white38, fontSize: 12),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => _handleSignupAction(u['id'], 'REJECT'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.redAccent,
                        side: const BorderSide(color: Colors.redAccent),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Reject', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _handleSignupAction(u['id'], 'APPROVE'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      child: Text('Approve', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildRequestsGrid() {
    return GridView.builder(
      padding: const EdgeInsets.symmetric(vertical: 10),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
        childAspectRatio: 1.6,
      ),
      itemCount: _facultyRequests.length,
      itemBuilder: (context, index) {
        final r = _facultyRequests[index];
        bool isApproved = r['status'] == 'APPROVED';

        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color(0xFF1E293B),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white10),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.15),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      "Subject Request",
                      style: GoogleFonts.poppins(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.bold),
                    ),
                  ),
                  if (isApproved)
                    const Icon(Icons.check_circle_outline, color: Colors.green, size: 20),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                r['faculty_name'] ?? 'Faculty',
                style: GoogleFonts.poppins(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                r['subject_name'] ?? 'Subject',
                style: GoogleFonts.poppins(color: Colors.blueAccent, fontSize: 16, fontWeight: FontWeight.bold),
              ),
              const Spacer(),
              if (!isApproved)
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _handleAction(r['id'], 'REJECT'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.redAccent,
                          side: const BorderSide(color: Colors.redAccent),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Reject', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => _handleAction(r['id'], 'APPROVE'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                        ),
                        child: Text('Approve', style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                      ),
                    ),
                  ],
                )
              else
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.green.withOpacity(0.3)),
                  ),
                  child: Center(
                    child: Text("Approved", style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
