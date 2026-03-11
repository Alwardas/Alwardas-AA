import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_staggered_animations/flutter_staggered_animations.dart';
import 'add_department_screen.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/api_constants.dart';
import 'coordinator_branch_details_screen.dart';

class CoordinatorDepartmentScreen extends StatefulWidget {
  const CoordinatorDepartmentScreen({super.key});

  @override
  State<CoordinatorDepartmentScreen> createState() => _CoordinatorDepartmentScreenState();
}

class _CoordinatorDepartmentScreenState extends State<CoordinatorDepartmentScreen> {
  List<Map<String, dynamic>> branches = [];
  bool _isLoading = false;

  final List<Map<String, dynamic>> _presets = [
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

  @override
  void initState() {
    super.initState();
    _fetchDepartments();
  }

  Future<void> _fetchDepartments() async {
    setState(() => _isLoading = true);
    try {
      final prefs = await SharedPreferences.getInstance();
      List<String> deletedPresets = prefs.getStringList('deleted_presets') ?? [];

      final url = Uri.parse('${ApiConstants.baseUrl}/api/departments');
      final response = await http.get(url);

      if (response.statusCode == 200) {
        final List<dynamic> data = json.decode(response.body);
        
        if (mounted) {
          setState(() {
            branches.clear();

            // 1. Add presets that haven't been deleted locally
            for (var preset in _presets) {
              if (!deletedPresets.contains(preset['name'])) {
                branches.add(Map.from(preset));
              }
            }

            // 2. Add or update data from the database
            for (var item in data) {
              String branchName = item['branch'] ?? 'Unknown';
              
              int existingIdx = branches.indexWhere((b) => b['name'] == branchName);
              
              if (existingIdx != -1) {
                // If the preset is already in the list, update its short code if available from DB
                if (item['short_code'] != null && item['short_code'].toString().isNotEmpty) {
                  branches[existingIdx]['code'] = item['short_code'];
                }
              } else {
                // If it doesn't exist in our current list, it's either entirely new (AI & ML)
                // or a preset we deleted locally but it exists in DB (re-added).
                // If it's in the DB, it supersedes the local deletion. We should add it.
                var matchingPreset = _presets.firstWhere(
                  (preset) => 
                    preset['name'] == branchName || 
                    preset['code'] == branchName ||
                    (preset['name'] as String).contains(branchName),
                  orElse: () => {
                    'name': branchName,
                    'code': _generateShortCode(branchName),
                    'icon': Icons.school_rounded,
                    'color': const Color(0xFF43A047),
                    'gradient': [const Color(0xFF66BB6A), const Color(0xFF2E7D32)],
                  }
                );

                branches.add({
                  ...matchingPreset,
                  'name': branchName,
                  'code': item['short_code'] ?? matchingPreset['code'] ?? _generateShortCode(branchName),
                });
                
                // If it was in deletedPresets previously but is now in the database, 
                // we should remove it from the deletedList so it persists normally.
                if (deletedPresets.contains(branchName)) {
                   deletedPresets.remove(branchName);
                   prefs.setStringList('deleted_presets', deletedPresets);
                }
              }
            }
          });
        }
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

  Future<void> _deleteDepartment(String branchName) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/departments/delete'),
        headers: {"Content-Type": "application/json"},
        body: jsonEncode({"branch": branchName}),
      );

      // 200 = Success DB delete. 404 = Not found in DB (which is fine if it's just a UI preset).
      if (response.statusCode == 200 || response.statusCode == 404) {
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Department '$branchName' deleted successfully")),
          );

          // Mark it as deleted locally so the preset doesn't reload.
          final prefs = await SharedPreferences.getInstance();
          List<String> deletedPresets = prefs.getStringList('deleted_presets') ?? [];
          if (!deletedPresets.contains(branchName)) {
             deletedPresets.add(branchName);
             await prefs.setStringList('deleted_presets', deletedPresets);
          }
          
          setState(() {
            branches.removeWhere((b) => b['name'] == branchName);
          });
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("Failed to delete department.")),
          );
        }
      }
    } catch (e) {
      if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("Error: $e")),
          );
      }
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
      body: _isLoading && branches.isEmpty 
        ? const Center(child: CircularProgressIndicator()) 
        : branches.isEmpty
          ? const Center(child: Text("No departments found. Add a department to get started."))
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
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => CoordinatorBranchDetailsScreen(
                branchName: branch['name'],
                shortCode: branch['code'],
              )),
            );
          },
          onLongPress: () {
             showDialog(
               context: context,
               builder: (ctx) => AlertDialog(
                 title: const Text("Delete Department"),
                 content: Text("Are you sure you want to delete '${branch['name']}'?"),
                 actions: [
                   TextButton(
                     onPressed: () => Navigator.pop(ctx),
                     child: const Text("Cancel"),
                   ),
                   TextButton(
                     onPressed: () {
                       Navigator.pop(ctx);
                       _deleteDepartment(branch['name']);
                     },
                     child: const Text("Delete", style: TextStyle(color: Colors.red)),
                   ),
                 ],
               ),
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
