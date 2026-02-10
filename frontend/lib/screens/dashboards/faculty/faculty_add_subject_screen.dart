import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../theme/theme_constants.dart';

class FacultyAddSubjectScreen extends StatefulWidget {
  final List<dynamic> allCourses;
  final List<dynamic> existingSubjects;

  const FacultyAddSubjectScreen({
    super.key, 
    required this.allCourses, 
    required this.existingSubjects
  });

  @override
  _FacultyAddSubjectScreenState createState() => _FacultyAddSubjectScreenState();
}

class _FacultyAddSubjectScreenState extends State<FacultyAddSubjectScreen> {
  String _searchQuery = '';
  final List<String> _selectedIds = [];
  
  @override
  Widget build(BuildContext context) {
    // Access theme info (we can just use AppTheme constants or context if ThemeProvider is global)
    // Assuming simple dark detection via brightness for now to match main screen style
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;
    
    // Filter Logic
    final filtered = _searchQuery.isEmpty ? widget.allCourses : widget.allCourses.where((c) {
      final q = _searchQuery.toLowerCase();
      final words = q.split(' ').where((w) => w.isNotEmpty).toList();
      final content = "${c['name']} ${c['code'] ?? c['id']} ${c['branch']} ${c['semester']}".toLowerCase();
      return words.every((word) => content.contains(word));
    }).toList();

    return Scaffold(
      backgroundColor: isDark ? ThemeColors.darkBackground.first : ThemeColors.lightBackground.first,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: textColor),
          onPressed: () => Navigator.pop(context), // Return null
        ),
        title: Text(
          "Add Subjects",
          style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold),
        ),
        actions: [
          TextButton(
             onPressed: _selectedIds.isEmpty ? null : () {
               // Return selected IDs to previous screen
               Navigator.pop(context, _selectedIds);
             },
             child: Text(
               "Done (${_selectedIds.length})",
               style: GoogleFonts.poppins(
                 color: _selectedIds.isEmpty ? subTextColor : tint, 
                 fontWeight: FontWeight.bold
               )
             ),
          )
        ],
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 15),
              decoration: BoxDecoration(
                color: isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05),
                borderRadius: BorderRadius.circular(15),
              ),
              child: TextField(
                style: TextStyle(color: textColor),
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: InputDecoration(
                  icon: Icon(Icons.search, color: subTextColor),
                  hintText: "Search by code, Name, Branch...",
                  hintStyle: TextStyle(color: subTextColor, fontSize: 14),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          
          // List
          Expanded(
            child: ListView.separated(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: subTextColor.withOpacity(0.1)),
              itemBuilder: (ctx, index) {
                final item = filtered[index];
                final isSelected = _selectedIds.contains(item['id']);
                final isAlreadyAdded = widget.existingSubjects.any((f) => f['id'].toString() == item['id'].toString() || f['subjectId'].toString() == item['id'].toString());
                
                final code = item['code'] ?? item['id'];

                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(vertical: 4),
                  title: Text(
                    code != null ? "$code - ${item['name']}" : item['name'], 
                    style: GoogleFonts.poppins(fontSize: 15, fontWeight: FontWeight.w600, color: isAlreadyAdded ? subTextColor : textColor)
                  ),
                  subtitle: Text(
                    "${item['branch']} • ${item['semester']}", 
                    style: TextStyle(color: subTextColor, fontSize: 12)
                  ),
                  trailing: isAlreadyAdded
                      ? const Icon(Icons.check_circle, color: Colors.green)
                      : Checkbox(
                          value: isSelected,
                          activeColor: tint,
                          side: BorderSide(color: subTextColor),
                          onChanged: (v) {
                            setState(() {
                              if (v == true) {
                                _selectedIds.add(item['id']);
                              } else {
                                _selectedIds.remove(item['id']);
                              }
                            });
                          },
                        ),
                  onTap: isAlreadyAdded ? null : () {
                    setState(() {
                      if (isSelected) {
                        _selectedIds.remove(item['id']);
                      } else {
                        _selectedIds.add(item['id']);
                      }
                    });
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
