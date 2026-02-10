import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';
import '../../../core/api_constants.dart';
import '../../../core/services/auth_service.dart';

class HODAnnouncementsScreen extends StatefulWidget {
  const HODAnnouncementsScreen({super.key});

  @override
  _HODAnnouncementsScreenState createState() => _HODAnnouncementsScreenState();
}

class _HODAnnouncementsScreenState extends State<HODAnnouncementsScreen> {
  List<dynamic> _announcements = [];
  bool _loading = true;
  bool _refreshing = false;
  
  // Modal State
  bool _modalVisible = false;
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _descController = TextEditingController();
  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.now();
  final List<String> _targetRoles = [];
  bool _submitting = false;

  final List<String> _rolesList = ['STUDENT', 'FACULTY', 'PRINCIPAL'];

  @override
  void initState() {
    super.initState();
    _fetchAnnouncements();
  }

  Future<void> _fetchAnnouncements() async {
    final user = await AuthService.getUserSession();
    if (user == null) return;
    
    try {
      final res = await http.get(Uri.parse('${ApiConstants.baseUrl}/api/announcements?userId=${user['id']}&mode=authored'));
      if (res.statusCode == 200) {
        final List<dynamic> data = json.decode(res.body);
        data.sort((a, b) => DateTime.parse(b['eventDate']).compareTo(DateTime.parse(a['eventDate'])));
        setState(() => _announcements = data);
      }
    } catch (e) {
      debugPrint("Error fetching announcements: $e");
    } finally {
      if (mounted) setState(() { _loading = false; _refreshing = false; });
    }
  }

  Future<void> _handleCreate() async {
    if (_titleController.text.isEmpty || _targetRoles.isEmpty) {
      _showSnackBar("Title and Role required");
      return;
    }

    setState(() => _submitting = true);
    final user = await AuthService.getUserSession();
    
    // Combine date and time
    final dt = DateTime(
      _selectedDate.year, _selectedDate.month, _selectedDate.day,
      _selectedTime.hour, _selectedTime.minute
    );
    // React used simple date string 'YYYY-MM-DD' and time 'HH:MM'
    // But typically ISO is better. React code: dateStr and timeStr separate fields.
    // I'll send matches to React expectation:
    // date: "YYYY-MM-DD", time: "HH:MM", targetRoles: [...]
    
    final dateStr = "${dt.year}-${dt.month.toString().padLeft(2,'0')}-${dt.day.toString().padLeft(2,'0')}";
    final timeStr = "${dt.hour.toString().padLeft(2,'0')}:${dt.minute.toString().padLeft(2,'0')}";

    try {
      final res = await http.post(
        Uri.parse('${ApiConstants.baseUrl}/api/announcements'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'userId': user?['id'],
          'title': _titleController.text,
          'description': _descController.text,
          'date': dateStr,
          'time': timeStr,
          'targetRoles': _targetRoles
        })
      );
      
      if (res.statusCode == 200 || res.statusCode == 201) {
        _showSnackBar("Created Successfully");
        _resetForm();
        setState(() => _modalVisible = false);
        _fetchAnnouncements();
      } else {
         _showSnackBar("Failed to create");
      }
    } catch (e) {
      _showSnackBar("Network Error");
    } finally {
      setState(() => _submitting = false);
    }
  }

  Future<void> _handleMarkDone(int id) async {
    final user = await AuthService.getUserSession();
    try {
      final res = await http.patch(
        Uri.parse('${ApiConstants.baseUrl}/api/announcements/$id/complete'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'userId': user?['id']})
      );
      if (res.statusCode == 200) {
        _fetchAnnouncements();
      } else {
        _showSnackBar("Failed to mark done");
      }
    } catch (e) {
      _showSnackBar("Network Error");
    }
  }

  Future<void> _handleDelete(int id) async {
    try {
      final res = await http.delete(Uri.parse('${ApiConstants.baseUrl}/api/announcements/$id'));
      if (res.statusCode == 200) {
        _fetchAnnouncements();
      } else {
        _showSnackBar("Failed to delete");
      }
    } catch (e) {
      _showSnackBar("Network Error");
    }
  }

  void _resetForm() {
    _titleController.clear();
    _descController.clear();
    setState(() {
      _targetRoles.clear();
      _selectedDate = DateTime.now();
      _selectedTime = TimeOfDay.now();
    });
  }

  void _showSnackBar(String text) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(text)));
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime.now(), lastDate: DateTime(2030));
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(context: context, initialTime: _selectedTime);
    if (picked != null) setState(() => _selectedTime = picked);
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? ThemeColors.darkBackground : ThemeColors.lightBackground;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final iconBg = isDark ? ThemeColors.darkIconBg : ThemeColors.lightIconBg;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;
    
    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
         title: Text("Announcements", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
         backgroundColor: Colors.transparent,
         elevation: 0,
         iconTheme: IconThemeData(color: textColor),
         actions: [
            GestureDetector(
              onTap: () => setState(() => _modalVisible = true),
              child: Container(
                margin: const EdgeInsets.only(right: 20),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: tint, borderRadius: BorderRadius.circular(20)),
                child: Row(children: [const Icon(Icons.add, color: Colors.white, size: 20), Text("Create", style: GoogleFonts.poppins(color: Colors.white, fontWeight: FontWeight.bold))]),
              ),
            )
         ],
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Stack(
            children: [
               _loading 
                 ? const Center(child: CircularProgressIndicator())
                 : RefreshIndicator(
                     onRefresh: () async { setState(() => _refreshing = true); await _fetchAnnouncements(); },
                     child: _announcements.isEmpty 
                       ? Center(child: Text("No announcements", style: TextStyle(color: subTextColor)))
                       : ListView.builder(
                           padding: const EdgeInsets.all(20),
                           itemCount: _announcements.length,
                           itemBuilder: (ctx, index) {
                             final item = _announcements[index];
                             final isCompleted = item['status'] == 'COMPLETED';
                             
                             return GestureDetector(
                               onLongPress: isCompleted ? () => _handleDelete(item['id']) : null,
                               child: Container(
                                 margin: const EdgeInsets.only(bottom: 15),
                                 padding: const EdgeInsets.all(15),
                                 decoration: BoxDecoration(
                                   color: cardColor,
                                   border: Border.all(color: iconBg),
                                   borderRadius: BorderRadius.circular(15),
                                 ),
                                 child: Column(
                                   crossAxisAlignment: CrossAxisAlignment.start,
                                   children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                           Expanded(child: Text(item['title'], style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor))),
                                           if (!isCompleted)
                                             GestureDetector(
                                               onTap: () => _handleMarkDone(item['id']),
                                               child: Icon(Icons.check_circle_outline, color: tint),
                                             )
                                           else
                                             Icon(Icons.check_circle, color: Colors.green)
                                        ],
                                      ),
                                      Text(item['eventDate'], style: TextStyle(color: subTextColor, fontSize: 12)),
                                      const SizedBox(height: 10),
                                      if (item['description'] != null) Text(item['description'], style: TextStyle(color: subTextColor)),
                                      const SizedBox(height: 10),
                                      Wrap(
                                        spacing: 5,
                                        children: (item['targetRoles'] as List).map<Widget>((r) => Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                          decoration: BoxDecoration(color: iconBg, borderRadius: BorderRadius.circular(8)),
                                          child: Text(r, style: TextStyle(color: textColor, fontSize: 10)),
                                        )).toList(),
                                      ),
                                      if (isCompleted) Text("Long press to delete", style: TextStyle(color: subTextColor, fontSize: 10, fontStyle: FontStyle.italic))
                                   ],
                                 ),
                               ),
                             );
                           },
                       ),
                   ),

               if (_modalVisible)
                 _buildModal(textColor, subTextColor, isDark ? const Color(0xFF24243e) : Colors.white, tint, iconBg),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildModal(Color textColor, Color subTextColor, Color bg, Color tint, Color iconBg) {
    return Container(
      color: Colors.black54,
       alignment: Alignment.bottomCenter,
       child: Container(
         constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.8),
         padding: const EdgeInsets.all(20),
         decoration: BoxDecoration(color: bg, borderRadius: const BorderRadius.vertical(top: Radius.circular(20))),
         child: SingleChildScrollView(
           child: Column(
             crossAxisAlignment: CrossAxisAlignment.start,
             children: [
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    Text("New Announcement", style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                    IconButton(onPressed: () => setState(() => _modalVisible = false), icon: Icon(Icons.close, color: textColor))
                ]),
                const SizedBox(height: 10),
                TextField(controller: _titleController, decoration: InputDecoration(hintText: "Title", hintStyle: TextStyle(color: subTextColor)), style: TextStyle(color: textColor)),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: _pickDate,
                        child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: subTextColor), borderRadius: BorderRadius.circular(8)), child: Text("${_selectedDate.day}/${_selectedDate.month}/${_selectedDate.year}", style: TextStyle(color: textColor))),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                       child: GestureDetector(
                        onTap: _pickTime,
                        child: Container(padding: const EdgeInsets.all(12), decoration: BoxDecoration(border: Border.all(color: subTextColor), borderRadius: BorderRadius.circular(8)), child: Text(_selectedTime.format(context), style: TextStyle(color: textColor))),
                      ),
                    )
                  ],
                ),
                const SizedBox(height: 10),
                TextField(controller: _descController, maxLines: 3, decoration: InputDecoration(hintText: "Description", hintStyle: TextStyle(color: subTextColor)), style: TextStyle(color: textColor)),
                const SizedBox(height: 10),
                Text("Targets", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
                Wrap(
                  spacing: 10,
                  children: _rolesList.map((r) => FilterChip(
                    label: Text(r),
                    selected: _targetRoles.contains(r),
                    onSelected: (s) => setState(() => s ? _targetRoles.add(r) : _targetRoles.remove(r)),
                    backgroundColor: iconBg,
                    selectedColor: tint,
                    labelStyle: TextStyle(color: _targetRoles.contains(r) ? Colors.white : textColor),
                  )).toList(),
                ),
                const SizedBox(height: 20),
                SizedBox(width: double.infinity, child: ElevatedButton(onPressed: _submitting ? null : _handleCreate, style: ElevatedButton.styleFrom(backgroundColor: tint, padding: const EdgeInsets.all(15)), child: _submitting ? const CircularProgressIndicator(color: Colors.white) : const Text("Publish", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)))),
             ],
           ),
         ),
       ),
    );
  }
}
