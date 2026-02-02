import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class ParentRequestsScreen extends StatefulWidget {
  const ParentRequestsScreen({super.key});

  @override
  State<ParentRequestsScreen> createState() => _ParentRequestsScreenState();
}

class _ParentRequestsScreenState extends State<ParentRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final List<Map<String, String>> _requests = [
    {"type": "Leave", "date": "Oct 12, 2024", "status": "Approved", "desc": "Family function"},
    {"type": "Permission", "date": "Nov 05, 2024", "status": "Pending", "desc": "Late arrival due to doctor appointment"},
    {"type": "Meeting", "date": "Sep 20, 2024", "status": "Completed", "desc": "Parent-Teacher meeting request"},
  ];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
          ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: _requests.length,
            itemBuilder: (context, index) {
              final req = _requests[index];
              Color statusColor = Colors.orange;
              if (req['status'] == 'Approved' || req['status'] == 'Completed') statusColor = Colors.green;
              if (req['status'] == 'Rejected') statusColor = Colors.red;

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
                        Text(req['type']!, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                          child: Text(req['status']!, style: GoogleFonts.poppins(color: statusColor, fontSize: 12, fontWeight: FontWeight.bold)),
                        )
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text(req['desc']!, style: GoogleFonts.poppins(color: Colors.grey, fontSize: 13)),
                    const SizedBox(height: 12),
                    Text(req['date']!, style: GoogleFonts.poppins(fontSize: 12, fontWeight: FontWeight.w500)),
                  ],
                ),
              );
            },
          ),

          // New Request Tab
          SingleChildScrollView(
            padding: const EdgeInsets.all(25),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text("Raise a New Request", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 20),
                _buildDropdown("Request Type", ["Leave Application", "Late Arrival Permission", "Appointment Request", "Other"]),
                const SizedBox(height: 20),
                _buildTextField("Subject", "Brief subject of the request"),
                const SizedBox(height: 20),
                _buildTextField("Description", "Detailed explanation...", maxLines: 4),
                const SizedBox(height: 20),
                 _buildTextField("Date/Duration", "e.g. 12th Oct to 14th Oct"),
                const SizedBox(height: 30),
                ElevatedButton(
                  onPressed: () {
                     ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Request Submitted Successfully!")));
                     _tabController.animateTo(0);
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Theme.of(context).primaryColor,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))
                  ),
                  child: Text("Submit Request", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                )
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _buildTextField(String label, String hint, {int maxLines = 1}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 14)),
        const SizedBox(height: 8),
        TextField(
          maxLines: maxLines,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: GoogleFonts.poppins(color: Colors.grey, fontSize: 13),
            filled: true,
            fillColor: Theme.of(context).brightness == Brightness.dark ? const Color(0xFF2C2C2E) : Colors.grey[100],
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
            contentPadding: const EdgeInsets.all(16)
          ),
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
              value: items[0],
              items: items.map((e) => DropdownMenuItem(value: e, child: Text(e, style: GoogleFonts.poppins()))).toList(),
              onChanged: (val) {},
            ),
          ),
        ),
      ],
    );
  }
}
