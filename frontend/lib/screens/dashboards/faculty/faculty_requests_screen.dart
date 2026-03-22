import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../widgets/parent_requests_viewer.dart';

class FacultyRequestsScreen extends StatefulWidget {
  final Map<String, dynamic> userData;
  const FacultyRequestsScreen({super.key, required this.userData});

  @override
  State<FacultyRequestsScreen> createState() => _FacultyRequestsScreenState();
}

class _FacultyRequestsScreenState extends State<FacultyRequestsScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    bool isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: Text("Requests", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        centerTitle: true,
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        bottom: TabBar(
          controller: _tabController,
          labelColor: Theme.of(context).primaryColor,
          unselectedLabelColor: Colors.grey,
          indicatorColor: Theme.of(context).primaryColor,
          tabs: const [
            Tab(text: "Parent Requests"),
            Tab(text: "Student Requests"),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDark 
                ? [const Color(0xFF0F172A), const Color(0xFF1E293B)] 
                : [Colors.grey[50]!, Colors.white],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: TabBarView(
          controller: _tabController,
          children: [
            ParentRequestsViewer(userData: widget.userData, requestFrom: 'Parent'),
            ParentRequestsViewer(userData: widget.userData, requestFrom: 'Student'),
          ],
        ),
      ),
    );
  }
}
