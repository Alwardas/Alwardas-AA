import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../../../core/providers/theme_provider.dart';
import '../../../core/theme/app_theme.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import 'student_details_screen.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  final TextEditingController _searchController = TextEditingController();
  
  // Drill-down State
  int _viewLevel = 0; // 0: Branches, 1: Category, 2: Year, 3: User List
  String? _selectedBranch;
  String? _selectedCategory; // "student", "parent", "staff"
  String? _selectedYear;
  
  bool _loading = false;
  List<dynamic> _users = [];

  final List<String> _branches = ['CME', 'EEE', 'ECE', 'Civil', 'Mech', 'BS & H'];
  final List<String> _years = ['1st Year', '2nd Year', '3rd Year'];
  
  final Map<String, String> _branchFullNames = {
    'CME': 'Computer Engineering',
    'EEE': 'Electrical & Electronics Engineering',
    'ECE': 'Electronics & Communication Engineering',
    'Civil': 'Civil Engineering',
    'Mech': 'Mechanical Engineering',
    'BS & H': 'Basic Science & Humanities'
  };

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  // --- Actions ---

  void _onBranchSelected(String branch) {
    setState(() {
      _selectedBranch = branch;
      if (branch == 'BS & H') {
        // BS & H has only Faculty, strictly no students/parents tabs
        _selectedCategory = 'staff';
        _viewLevel = 3; // Jump to list
        _fetchUsers();
      } else {
        _viewLevel = 1; // Go to Category selection
      }
    });
  }

  void _onCategorySelected(String category) {
    setState(() {
      _selectedCategory = category;
      if (category == 'staff') {
        _viewLevel = 3; // Staff doesn't need Year, go to list
        _fetchUsers();
      } else {
        _viewLevel = 2; // Go to Year selection
      }
    });
  }

  void _onYearSelected(String year) {
    setState(() {
      _selectedYear = year;
      _viewLevel = 3; // Go to list
      _fetchUsers();
    });
  }

  void _navigateBack() {
    setState(() {
      if (_viewLevel == 3) {
         // Back from list
         if (_selectedBranch == 'BS & H' || _selectedCategory == 'staff') {
             // If we skipped levels, go back appropriately
             if (_selectedBranch == 'BS & H') {
                _viewLevel = 0;
                _selectedBranch = null;
                _selectedCategory = null;
             } else {
                _viewLevel = 1; // Back to category
                _selectedCategory = null;
             }
         } else {
             // Standard Path (Student/Parent)
             _viewLevel = 2; // Back to year
             _selectedYear = null;
         }
         _users = [];
      } else if (_viewLevel == 2) {
         _viewLevel = 1; // Back to category
         _selectedCategory = null;
      } else if (_viewLevel == 1) {
         _viewLevel = 0; // Back to branch
         _selectedBranch = null;
      }
      _searchController.clear();
    });
  }

  Future<void> _fetchUsers({String? query}) async {
    setState(() => _loading = true);
    try {
      final queryParams = <String, String>{};
      
      // If searching globally (override drill down if search is present)
      if (query != null && query.isNotEmpty) {
         queryParams['search'] = query;
      } else {
         // Drill down params
         if (_selectedCategory != null) queryParams['category'] = _selectedCategory!;
         if (_selectedBranch != null) {
            queryParams['branch'] = _branchFullNames[_selectedBranch] ?? _selectedBranch!;
         }
         if (_selectedYear != null) queryParams['year'] = _selectedYear!;
      }

      final uri = Uri.parse('${ApiConstants.baseUrl}/api/admin/users').replace(queryParameters: queryParams);
      
      final response = await http.get(uri);
      
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            _users = json.decode(response.body);
            _loading = false;
          });
        }
      } else {
        throw Exception('Failed to load users');
      }
    } catch (e) {
      print("Error fetching users: $e");
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _handleUserAction(Map<String, dynamic> user, String action) async {
      bool confirm = await showDialog(
        context: context, 
        builder: (context) => AlertDialog(
          title: Text(action == 'APPROVE' ? "Approve User?" : "Delete User?", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
          content: Text(
            action == 'APPROVE' 
              ? "Are you sure you want to approve ${user['full_name']}?" 
              : "This will permanently delete ${user['full_name']}'s account. This action cannot be undone.",
            style: GoogleFonts.poppins()
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: Text("Cancel", style: GoogleFonts.poppins()),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(foregroundColor: action == 'DELETE' ? Colors.red : Colors.green),
              child: Text(action == 'APPROVE' ? "Approve" : "Delete", style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
            ),
          ],
        )
      ) ?? false;

      if (!confirm) return;

      try {
        final response = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/api/admin/users/approve'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'user_id': user['id'],
            'action': action
          }),
        );

        if (response.statusCode == 200) {
          if(mounted) {
             ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Success!", style: GoogleFonts.poppins())));
             _fetchUsers(query: _searchController.text); 
          }
        }
      } catch (e) {
         if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e", style: GoogleFonts.poppins())));
      }
  }

  Color _getRoleColor(String? role) {
    switch (role) {
      case 'Student': return Colors.blue;
      case 'Faculty': return Colors.purple;
      case 'HOD': return Colors.deepOrange;
      case 'Principal': return Colors.red;
      case 'Admin': return Colors.black;
      case 'Parent': return Colors.teal;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    
    final textColor = theme.colorScheme.onSurface;
    final subTextColor = theme.colorScheme.secondary;
    final cardColor = theme.cardColor;

    String titleText = "User Management";
    if (_viewLevel > 0 && _selectedBranch != null) {
      titleText = _selectedBranch!;
      if (_selectedCategory != null) {
         // Capitalize category
         String cat = _selectedCategory![0].toUpperCase() + _selectedCategory!.substring(1);
         if (_selectedCategory == 'staff') cat = "Faculty & Staff";
         titleText += " > $cat";
      }
      if (_selectedYear != null) {
         titleText += " > $_selectedYear";
      }
    }

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: AppTheme.getAdaptiveOverlayStyle(true), // Blue header
      child: Scaffold(
        backgroundColor: theme.scaffoldBackgroundColor,
        appBar: AppBar(
          title: Text(titleText, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
          backgroundColor: const Color(0xFF1a4ab2), // Match Blue Header
          elevation: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
            onPressed: () {
              if (_viewLevel == 0) {
                Navigator.pop(context);
              } else {
                _navigateBack();
              }
            },
          ),
        ),
        body: WillPopScope(
          onWillPop: () async {
            if (_viewLevel > 0) {
              _navigateBack();
              return false;
            }
            return true;
          },
          child: Column(
            children: [
              // Search Bar - Only show on list view or top level? 
              // Actually user might want to search anytime. Let's keep it but if they search, we show list.
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: TextField(
                  controller: _searchController,
                  style: GoogleFonts.poppins(color: textColor),
                  onSubmitted: (value) {
                     if (value.isNotEmpty) {
                        setState(() {
                          _viewLevel = 3; // Force list view
                          _fetchUsers(query: value);
                        });
                     } else {
                       _searchController.clear();
                       // Optionally reset to current drill down state or fetch without search
                       _fetchUsers();
                     }
                  },
                  decoration: InputDecoration(
                    hintText: "Search name, ID...",
                    hintStyle: GoogleFonts.poppins(color: subTextColor),
                    prefixIcon: Icon(Icons.search, color: subTextColor),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                    filled: true,
                    fillColor: cardColor,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                    suffixIcon: IconButton(
                      icon: Icon(Icons.clear, color: subTextColor),
                      onPressed: () {
                          _searchController.clear();
                          // Reload current context
                          if (_viewLevel == 3) _fetchUsers();
                      },
                    )
                  ),
                ),
              ),
              
              Expanded(
                child: _buildBody(textColor, cardColor, subTextColor),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildBody(Color textColor, Color cardColor, Color subTextColor) {
    if (_loading) return const Center(child: CircularProgressIndicator());

    // LEVEL 0: BRANCH SELECTION
    if (_viewLevel == 0) {
       return _buildGrid(
          items: _branches,
          itemBuilder: (item) => _buildCard(item, textColor, cardColor),
          onTap: (item) => _onBranchSelected(item),
       );
    }

    // LEVEL 1: CATEGORY SELECTION
    if (_viewLevel == 1) {
       return _buildGrid(
          items: ['Students', 'Parents', 'Staff'],
          itemBuilder: (item) => _buildCard(item.toUpperCase(), textColor, cardColor, icon: _getCategoryIcon(item)),
          onTap: (item) => _onCategorySelected(item.toLowerCase() == 'students' ? 'student' : item.toLowerCase() == 'parents' ? 'parent' : 'staff'),
       );
    }

    // LEVEL 2: YEAR SELECTION
    if (_viewLevel == 2) {
       return _buildGrid(
          items: _years,
          itemBuilder: (item) => _buildCard(item.toUpperCase(), textColor, cardColor, icon: Icons.calendar_today),
          onTap: (item) => _onYearSelected(item),
       );
    }

    // LEVEL 3: USER LIST
    if (_users.isEmpty) {
       return Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.person_off_outlined, size: 60, color: subTextColor.withOpacity(0.5)),
              const SizedBox(height: 10),
              Text("No users found", style: GoogleFonts.poppins(color: subTextColor)),
            ],
          ),
        );
    }

    return ListView.separated(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.all(20),
      itemCount: _users.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _UserListItem(
          user: _users[index],
          textColor: textColor,
          cardColor: cardColor,
          subTextColor: subTextColor,
          roleColor: _getRoleColor(_users[index]['role'] as String?),
          onAction: (action) => _handleUserAction(_users[index], action),
          onTap: () {
             if (_users[index]['role'] == 'Student') {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => StudentDetailsScreen(
                      userId: _users[index]['id'],
                      userName: _users[index]['full_name'] ?? 'Student',
                    ),
                  ),
                ).then((_) => _fetchUsers(query: _searchController.text));
             }
          },
        );
      },
    );
  }

  Widget _buildGrid<T>({required List<T> items, required Widget Function(T) itemBuilder, required Function(T) onTap}) {
    return GridView.builder(
       padding: const EdgeInsets.all(20),
       gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
         crossAxisCount: 2,
         crossAxisSpacing: 15,
         mainAxisSpacing: 15,
         childAspectRatio: 1.3,
       ),
       itemCount: items.length,
       itemBuilder: (context, index) {
         final item = items[index];
         return GestureDetector(
           onTap: () => onTap(item),
           child: itemBuilder(item),
         );
       },
    );
  }

  Widget _buildCard(String title, Color textColor, Color cardColor, {IconData? icon}) {
    return Container(
       decoration: BoxDecoration(
         color: cardColor,
         borderRadius: BorderRadius.circular(20),
         border: Border.all(color: const Color(0xFF2563eb).withOpacity(0.1)),
         boxShadow: [
           BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 10, offset: const Offset(0, 5))
         ]
       ),
       child: Column(
         mainAxisAlignment: MainAxisAlignment.center,
         children: [
           if (icon != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Icon(icon, size: 30, color: const Color(0xFF2563eb)),
              ),
           Text(
             title.toUpperCase(),
             textAlign: TextAlign.center,
             style: TextStyle(
               fontSize: 14, 
               fontWeight: FontWeight.bold, 
               color: textColor,
               letterSpacing: 0.5,
             ),
           ),
         ],
       ),
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'students': return Icons.school;
      case 'parents': return Icons.family_restroom;
      case 'staff': return Icons.work;
      default: return Icons.category;
    }
  }
}

class _UserListItem extends StatelessWidget {
  final Map<String, dynamic> user;
  final Color textColor;
  final Color cardColor;
  final Color subTextColor;
  final Color roleColor;
  final VoidCallback onTap;
  final Function(String) onAction;

  const _UserListItem({
    required this.user,
    required this.textColor,
    required this.cardColor,
    required this.subTextColor,
    required this.roleColor,
    required this.onTap,
    required this.onAction,
  });

  @override
  Widget build(BuildContext context) {
    final role = user['role'] as String?;
    final isApproved = user['is_approved'] == true;
    final isStudent = role == 'Student';

    return InkWell(
      onTap: isStudent ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: cardColor,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 8, offset: const Offset(0, 4))
          ]
        ),
        child: Row(
          children: [
            if (!isStudent) 
              Padding(
                padding: const EdgeInsets.only(right: 15),
                child: CircleAvatar(
                  backgroundColor: roleColor.withOpacity(0.1),
                  child: Text(
                    (user['full_name'] ?? 'U')[0].toUpperCase(),
                    style: TextStyle(color: roleColor, fontWeight: FontWeight.bold),
                  ),
                ),
              ),
            
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user['full_name'] ?? 'Unknown',
                    style: TextStyle(fontWeight: FontWeight.bold, color: textColor, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  if (isStudent)
                    Text(
                        user['login_id'] ?? '',
                        style: TextStyle(fontSize: 12, color: subTextColor, fontWeight: FontWeight.w500),
                    )
                  else ...[
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: roleColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              role?.toUpperCase() ?? 'UNKNOWN',
                              style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: roleColor),
                            ),
                          ),
                          if (user['branch'] != null) ...[
                            const SizedBox(width: 8),
                            Text(
                              "•  ${user['branch']}",
                              style: TextStyle(fontSize: 11, color: subTextColor),
                            ),
                          ]
                        ],
                      ),
                      const SizedBox(height: 2),
                      Text(
                          user['login_id'] ?? '',
                          style: TextStyle(fontSize: 11, color: subTextColor),
                      ),
                  ]
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isApproved)
                  Container(
                    margin: const EdgeInsets.only(bottom: 5),
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.orange.withOpacity(0.3))
                    ),
                    child: const Text("Pending", style: TextStyle(fontSize: 10, color: Colors.orange, fontWeight: FontWeight.w600)),
                  ),
                PopupMenuButton<String>(
                  icon: Icon(Icons.more_vert, color: subTextColor),
                  onSelected: onAction,
                  itemBuilder: (context) => [
                    if (!isApproved)
                      PopupMenuItem(
                        value: 'APPROVE',
                        child: Row(
                          children: [
                            const Icon(Icons.check_circle, color: Colors.green, size: 20),
                            const SizedBox(width: 8),
                            Text("Approve", style: TextStyle(color: textColor)),
                          ],
                        ),
                      ),
                    PopupMenuItem(
                      value: 'DELETE',
                      child: Row(
                        children: [
                          const Icon(Icons.delete, color: Colors.red, size: 20),
                          const SizedBox(width: 8),
                          Text("Delete", style: TextStyle(color: textColor)),
                        ],
                      ),
                    ),
                  ]
                )
              ],
            )
          ],
        ),
      ),
    );
  }
}

