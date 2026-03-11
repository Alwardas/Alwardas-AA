import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/api_constants.dart';
import '../hod/hod_year_sections_screen.dart';

class CoordinatorBranchDetailsScreen extends StatefulWidget {
  final String branchName;
  final String shortCode;
  
  const CoordinatorBranchDetailsScreen({
    super.key, 
    required this.branchName,
    required this.shortCode,
  });

  @override
  _CoordinatorBranchDetailsScreenState createState() => _CoordinatorBranchDetailsScreenState();
}

class _CoordinatorBranchDetailsScreenState extends State<CoordinatorBranchDetailsScreen> {
  String _hodName = "Loading...";
  bool _isLoading = true;

  List<Map<String, dynamic>> _years = [
    {
      'year': '1st Year',
      'sections': [],
    },
    {
      'year': '2nd Year',
      'sections': [],
    },
    {
      'year': '3rd Year',
      'sections': [],
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchHodAndYears();
  }

  Future<void> _fetchHodAndYears() async {
    setState(() => _isLoading = true);
    
    // 1. Fetch HOD Name
    try {
      final url = Uri.parse('${ApiConstants.baseUrl}/api/admin/users?is_approved=true');
      final response = await http.get(url);
      
      if (response.statusCode == 200) {
        final List<dynamic> users = json.decode(response.body);
        final hodUser = users.firstWhere(
          (u) => u['role']?.toString().toUpperCase() == 'HOD' && u['branch'] == widget.branchName,
          orElse: () => null
        );
        
        if (mounted) {
          setState(() {
            _hodName = hodUser != null ? (hodUser['full_name'] ?? 'Assigned (Name missing)') : 'Not Assigned';
          });
        }
      } else {
         if (mounted) setState(() => _hodName = 'Unable to fetch');
      }
    } catch (e) {
      if (mounted) setState(() => _hodName = 'Error fetching');
    }

    // 2. Fetch Section Counts
    final prefs = await SharedPreferences.getInstance();
    for (var yearData in _years) {
      final yearName = yearData['year'];
      
      try {
        final url = Uri.parse('${ApiConstants.baseUrl}/api/sections?branch=${Uri.encodeComponent(widget.branchName)}&year=${Uri.encodeComponent(yearName)}');
        final response = await http.get(url);
        
        if (response.statusCode == 200) {
          final List<dynamic> fetched = json.decode(response.body);
          if (fetched.isNotEmpty) {
            yearData['sections'] = fetched.map((e) => e.toString()).toList();
            prefs.setStringList('sections_${widget.branchName}_$yearName', yearData['sections']);
            continue; 
          }
        }
      } catch (e) {
        debugPrint("Error fetching counts for $yearName: $e");
      }

      final key = 'sections_${widget.branchName}_$yearName';
      final List<String>? stored = prefs.getStringList(key);
      if (stored != null) {
        yearData['sections'] = stored;
      } else {
        yearData['sections'] = ['Section A']; // Fallback
      }
    }

    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? AppTheme.darkBodyGradient : AppTheme.lightBodyGradient;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text(widget.shortCode, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
        centerTitle: true,
      ),
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: bgColors,
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: _isLoading 
          ? const Center(child: CircularProgressIndicator()) 
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                 top: MediaQuery.of(context).padding.top + kToolbarHeight + 10, 
                 left: 20, 
                 right: 20, 
                 bottom: 100
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildSectionHeader('Overview', textColor),
                  const SizedBox(height: 15),
                  _buildOverviewCard(isDark, textColor, subTextColor),
                  const SizedBox(height: 30),
                  _buildSectionHeader('Academic Years', textColor),
                  const SizedBox(height: 15),
                  _buildYearsList(isDark, textColor, subTextColor),
                ],
              ),
            ),
      ),
    );
  }

  Widget _buildSectionHeader(String title, Color textColor) {
    return Text(
      title,
      style: GoogleFonts.poppins(
        fontSize: 18,
        fontWeight: FontWeight.bold,
        color: textColor,
      ),
    );
  }

  Widget _buildOverviewCard(bool isDark, Color textColor, Color subTextColor) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFFF8E1), Color(0xFFFFECB3)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFFFC107).withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(color: Colors.amber.withValues(alpha: 0.2), blurRadius: 10, offset: const Offset(0, 5))
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.branchName.toUpperCase(),
            style: GoogleFonts.poppins(
              fontSize: 18, 
              fontWeight: FontWeight.w800, 
              color: Colors.amber[900],
              letterSpacing: 0.5
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
          RichText(
            text: TextSpan(
              children: [
                TextSpan(
                  text: 'HOD: ',
                  style: GoogleFonts.poppins(fontSize: 14, fontWeight: FontWeight.w600, color: Colors.amber[800]),
                ),
                TextSpan(
                  text: _hodName,
                  style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.brown[900]),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildYearsList(bool isDark, Color textColor, Color subTextColor) {
    return ListView.builder(
      physics: const NeverScrollableScrollPhysics(),
      shrinkWrap: true,
      padding: EdgeInsets.zero,
      itemCount: _years.length,
      itemBuilder: (context, index) {
        final year = _years[index];
        return GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => HodYearSectionsScreen(
                yearData: year,
                branch: widget.branchName,
                onUpdateSections: (newSections) {
                  setState(() {
                    year['sections'] = newSections;
                  });
                },
              )),
            );
          },
          child: Container(
            margin: const EdgeInsets.only(bottom: 15),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.grey.withValues(alpha: 0.1)),
              boxShadow: [
                 BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
              ]
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: Colors.blueAccent.withValues(alpha: 0.1), shape: BoxShape.circle),
                  child: const Icon(Icons.school, color: Colors.blueAccent, size: 24),
                ),
                const SizedBox(width: 20),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        year['year'],
                        style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor, fontSize: 18),
                      ),
                      Text(
                        '${(year['sections'] as List).length} Sections',
                        style: GoogleFonts.poppins(fontSize: 12, color: subTextColor),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios, size: 16, color: subTextColor),
              ],
            ),
          ),
        );
      },
    );
  }
}
