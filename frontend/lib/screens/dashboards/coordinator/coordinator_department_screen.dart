import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'add_department_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class CoordinatorDepartmentScreen extends StatefulWidget {
  const CoordinatorDepartmentScreen({super.key});

  @override
  State<CoordinatorDepartmentScreen> createState() => _CoordinatorDepartmentScreenState();
}

class _CoordinatorDepartmentScreenState extends State<CoordinatorDepartmentScreen> {
  // Initial hardcoded list to ensure default branches are always visible quickly
  List<Map<String, dynamic>> branches = [
    {
      'name': 'Civil Engineering',
      'code': 'CIVIL',
      'icon': Icons.construction_rounded,
      'color': const Color(0xFFE65100), // Orange
      'gradient': [const Color(0xFFFF9800), const Color(0xFFF57C00)],
    },
    {
      'name': 'Computer Engineering',
      'code': 'CME',
      'icon': Icons.computer_rounded,
      'color': const Color(0xFF1565C0), // Blue
      'gradient': [const Color(0xFF2196F3), const Color(0xFF1976D2)],
    },
    {
      'name': 'Electronics & Communication',
      'code': 'ECE',
      'icon': Icons.memory_rounded,
      'color': const Color(0xFF6A1B9A), // Purple
      'gradient': [const Color(0xFF9C27B0), const Color(0xFF7B1FA2)],
    },
    {
      'name': 'Electrical & Electronics',
      'code': 'EEE',
      'icon': Icons.electrical_services_rounded,
      'color': const Color(0xFFF9A825), // Yellow/Amber
      'gradient': [const Color(0xFFFFC107), const Color(0xFFFFA000)],
    },
    {
      'name': 'Mechanical Engineering',
      'code': 'MECH',
      'icon': Icons.settings_rounded,
      'color': const Color(0xFFC62828), // Red
      'gradient': [const Color(0xFFF44336), const Color(0xFFD32F2F)],
    },
  ];

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      final String? baseUrl = prefs.getString('api_base_url') ?? 'http://10.0.2.2:3001';
      final url = Uri.parse('$baseUrl/api/departments');

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        setState(() {
          for (var item in data) {
            String branchName = item['branch'] ?? 'Unknown';
            // Simple check to avoid creating duplicates if the name matches 'CME' or 'Computer Engineering' roughly.
            // For now, exact match check or partial containment.
            
            bool exists = branches.any((test) => 
               test['name'] == branchName || 
               test['code'] == branchName ||
               (test['name'] as String).contains(branchName)
            );

            if (!exists) {
              // Add new dynamic branch
              branches.add({
                'name': branchName,
                'code': _generateShortCode(branchName),
                'icon': Icons.school_rounded, // Default icon for dynamic branches
                'color': const Color(0xFF43A047), // Default Green theme for new branches
                'gradient': [const Color(0xFF66BB6A), const Color(0xFF2E7D32)],
              });
            }
          }
        });
      }
    } catch (e) {
      debugPrint("Error fetching departments: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _generateShortCode(String name) {
    if (name.isEmpty) return "OC";
    var words = name.split(' ');
    if (words.length > 1) {
      return words.map((e) => e.isNotEmpty ? e[0] : '').join().toUpperCase();
    }
    return name.substring(0, name.length > 3 ? 3 : name.length).toUpperCase();
  }

  void _navigateToAddDepartment() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const CoordinatorAddDepartmentScreen()),
    );

    if (result == true) {
      _fetchDepartments(); // Refresh list after adding
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        title: Text(
          "Departments",
          style: GoogleFonts.poppins(
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.black54),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 16),
            decoration: BoxDecoration(
              color: Colors.blueAccent.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.blueAccent),
              tooltip: "Add Department",
              onPressed: _navigateToAddDepartment,
            ),
          ),
        ],
      ),
      body: _isLoading && branches.length <= 5 
        ? const Center(child: CircularProgressIndicator()) 
        : AnimationLimiter(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: RefreshIndicator(
            onRefresh: _fetchDepartments,
            child: GridView.builder(
              physics: const AlwaysScrollableScrollPhysics(parent: BouncingScrollPhysics()),
              itemCount: branches.length,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 16,
                mainAxisSpacing: 16,
                childAspectRatio: 0.85, 
              ),
              itemBuilder: (context, index) {
                final branch = branches[index];
                return AnimationConfiguration.staggeredGrid(
                  position: index,
                  duration: const Duration(milliseconds: 500),
                  columnCount: 2,
                  child: ScaleAnimation(
                    scale: 0.9,
                    child: FadeInAnimation(
                      child: _buildDepartmentCard(context, branch),
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDepartmentCard(BuildContext context, Map<String, dynamic> branch) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: (branch['color'] as Color).withOpacity(0.1),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () {
            // Future navigation to branch details?
            ScaffoldMessenger.of(context).showSnackBar(
               SnackBar(content: Text("Selected: ${branch['name']}")),
            );
          },
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: branch['gradient'] as List<Color>,
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: (branch['gradient'][0] as Color).withOpacity(0.3),
                      blurRadius: 8,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  branch['icon'] as IconData,
                  size: 32,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Text(
                  branch['code'],
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12.0),
                child: Text(
                  branch['name'],
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.poppins(
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                    color: Colors.grey[600],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
