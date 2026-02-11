import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import '../../../core/api_constants.dart';
import '../../../core/providers/theme_provider.dart';
import '../../../theme/theme_constants.dart';

class HodDepartmentTimingScreen extends StatefulWidget {
  final String branch;
  const HodDepartmentTimingScreen({super.key, required this.branch});

  @override
  _HodDepartmentTimingScreenState createState() => _HodDepartmentTimingScreenState();
}

class _HodDepartmentTimingScreenState extends State<HodDepartmentTimingScreen> {
  TimeOfDay _startTime = const TimeOfDay(hour: 9, minute: 0);
  int _classDuration = 50;
  int _shortBreakDuration = 10;
  int _lunchDuration = 50;
  int _periodsCount = 8;
  
  // Slot Configuration: 'P' = Period, 'SB' = Short Break, 'LB' = Lunch Break
  List<String> _slotConfig = [
    'P', 'P', 'SB', 'P', 'P', 'LB', 'P', 'P', 'SB', 'P', 'P'
  ];

  List<Map<String, dynamic>> _generatedLivePreview = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final uri = Uri.parse('${ApiConstants.baseUrl}/api/department/timing').replace(queryParameters: {'branch': widget.branch});
      final res = await http.get(uri);
      
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() {
          _startTime = TimeOfDay(hour: data['start_hour'] ?? 9, minute: data['start_minute'] ?? 0);
          _classDuration = data['class_duration'] ?? 50;
          _shortBreakDuration = data['short_break_duration'] ?? 10;
          _lunchDuration = data['lunch_duration'] ?? 50;
          
          if (data['slot_config'] != null) {
             _slotConfig = List<String>.from(data['slot_config']);
             _periodsCount = _slotConfig.where((s) => s == 'P').length;
          } else {
             // Default initialization
             _periodsCount = 8;
             _updateSlotConfig();
          }
        });
      }
    } catch (e) {
      debugPrint("Error loading timings: $e");
    }
    _generateTimings();
  }

  // rebuilds slot config based on period count, trying to keep breaks
  void _updateSlotConfig() {
      List<String> newConfig = [];
      int currentP = 0;
      
      // If we have existing config, try to respect it
      // But simpler: just rebuild default or simple list if count changes
      // Actually user requested "Number of periods" option.
      // If we change number of periods, we should probably reset or intelligently append/remove P.
      
      // Intelligent resize:
      int currentPs = _slotConfig.where((s) => s == 'P').length;
      if (_periodsCount > currentPs) {
          // Add Ps to the end
          for(int i=0; i<(_periodsCount - currentPs); i++) {
              _slotConfig.add('P');
          }
      } else if (_periodsCount < currentPs) {
          // Remove Ps from the end (reverse iteration)
          int toRemove = currentPs - _periodsCount;
          for(int i=_slotConfig.length-1; i>=0; i--) {
              if (toRemove == 0) break;
              if (_slotConfig[i] == 'P') {
                  _slotConfig.removeAt(i);
                  toRemove--;
              }
          }
      }
      _generateTimings();
  }

  Future<void> _saveSettings() async {
    try {
        final body = {
          'branch': widget.branch,
          'start_hour': _startTime.hour,
          'start_minute': _startTime.minute,
          'class_duration': _classDuration,
          'short_break_duration': _shortBreakDuration,
          'lunch_duration': _lunchDuration,
          'slot_config': _slotConfig
        };

        final res = await http.post(
          Uri.parse('${ApiConstants.baseUrl}/api/department/timing'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(body)
        );

        if (res.statusCode == 200) {
           ScaffoldMessenger.of(context).showSnackBar(
             const SnackBar(content: Text("Timing Settings Saved to Server")),
           );
        } else {
           ScaffoldMessenger.of(context).showSnackBar(
             SnackBar(content: Text("Failed to save: ${res.statusCode}")),
           );
        }
    } catch (e) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text("Network Error: $e")),
       );
    }
  }

  void _generateTimings() {
    List<Map<String, dynamic>> periods = [];
    DateTime time = DateTime(2026, 1, 1, _startTime.hour, _startTime.minute);
    String formatTime(DateTime t) => DateFormat('hh:mm a').format(t);

    int pNum = 1;
    
    for (String type in _slotConfig) {
        DateTime start = time;
        int duration = 0;
        String label = "";
        
        if (type == 'P') {
            duration = _classDuration;
            label = "Period $pNum";
        } else if (type == 'SB') {
            duration = _shortBreakDuration;
            label = "Short Break";
        } else if (type == 'LB') {
            duration = _lunchDuration;
            label = "Lunch Break";
        }
        
        time = time.add(Duration(minutes: duration));
        
        periods.add({
            'type': type, // P, SB, LB
            'label': label,
            'start': formatTime(start),
            'end': formatTime(time),
            'number': type == 'P' ? pNum : null
        });

        if (type == 'P') pNum++;
    }
    
    setState(() {
      _generatedLivePreview = periods;
    });
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;
    final bgColors = isDark ? ThemeColors.darkBackground : ThemeColors.lightBackground;
    final textColor = isDark ? ThemeColors.darkText : ThemeColors.lightText;
    final subTextColor = isDark ? ThemeColors.darkSubtext : ThemeColors.lightSubtext;
    final cardColor = isDark ? ThemeColors.darkCard : ThemeColors.lightCard;
    final tint = isDark ? ThemeColors.darkTint : ThemeColors.lightTint;

    return Scaffold(
      extendBodyBehindAppBar: true,
      appBar: AppBar(
        title: Text("Department Timing", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: Container(
        decoration: BoxDecoration(gradient: LinearGradient(colors: bgColors, begin: Alignment.topLeft, end: Alignment.bottomRight)),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildSettingsSection(cardColor, textColor, subTextColor, tint),
                      const SizedBox(height: 30),
                      Text("Generated Schedule Preview", style: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.bold, color: textColor)),
                      const SizedBox(height: 15),
                      _buildPreviewList(cardColor, textColor, subTextColor, tint),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: SizedBox(
                   width: double.infinity,
                   child: ElevatedButton(
                     onPressed: _saveSettings,
                     style: ElevatedButton.styleFrom(
                       backgroundColor: tint,
                       padding: const EdgeInsets.symmetric(vertical: 16),
                       shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                     ),
                     child: Text("Apply to Department", style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16)),
                   ),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsSection(Color cardColor, Color textColor, Color subTextColor, Color tint) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: tint.withValues(alpha: 0.1)),
      ),
      child: Column(
        children: [
          // College Start Time
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
                Text("College Start Time", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w500)),
                GestureDetector(
                  onTap: () async {
                    final picked = await showTimePicker(context: context, initialTime: _startTime);
                    if (picked != null) {
                        setState(() => _startTime = picked);
                        _generateTimings();
                    }
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(color: tint.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
                    child: Text(_startTime.format(context), style: TextStyle(color: tint, fontWeight: FontWeight.bold)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 20),
          
          _buildCounterRow("Class Duration", _classDuration, (val) {
            setState(() => _classDuration = val);
            _generateTimings();
          }, "mins", tint, textColor),
          
          const SizedBox(height: 15),
          _buildCounterRow("Number of Periods", _periodsCount, (val) {
             if (val < 1) return;
             setState(() => _periodsCount = val);
             _updateSlotConfig();
          }, "", tint, textColor),

          const Divider(height: 30),
          
          Text("Break Durations", style: TextStyle(color: subTextColor, fontSize: 12, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          
          _buildCounterRow("Short Break", _shortBreakDuration, (val) {
            setState(() => _shortBreakDuration = val);
            _generateTimings();
          }, "mins", tint, textColor),
          
          const SizedBox(height: 15),
          _buildCounterRow("Lunch Break", _lunchDuration, (val) {
            setState(() => _lunchDuration = val);
            _generateTimings();
          }, "mins", tint, textColor),
        ],
      ),
    );
  }

  Widget _buildCounterRow(String label, int value, Function(int) onChanged, String unit, Color tint, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w500)),
        Row(
          children: [
             IconButton(onPressed: () => onChanged(value - (unit.isNotEmpty ? 5 : 1)), icon: Icon(Icons.remove_circle_outline, color: tint, size: 24)),
             Container(
               constraints: const BoxConstraints(minWidth: 40),
               alignment: Alignment.center,
               child: Text("$value $unit", style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 16)),
             ),
             IconButton(onPressed: () => onChanged(value + (unit.isNotEmpty ? 5 : 1)), icon: Icon(Icons.add_circle_outline, color: tint, size: 24)),
          ],
        )
      ],
    );
  }

  Widget _buildPreviewList(Color cardColor, Color textColor, Color subTextColor, Color tint) {
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _generatedLivePreview.length,
      onReorder: (oldIndex, newIndex) {
         if (newIndex > oldIndex) newIndex -= 1;
         setState(() {
            final item = _slotConfig.removeAt(oldIndex);
            _slotConfig.insert(newIndex, item);
         });
         _generateTimings(); // Recalculate times based on new order
      },
      itemBuilder: (context, index) {
        final item = _generatedLivePreview[index];
        final type = item['type'];
        final bool isClass = type == 'P';
        
        // Use a unique key for reordering
        // If items are identical, keys must be unique. 
        // We can use index in key but that causes issues in reordering sometimes.
        // Better construct a list of unique keys corresponding to _slotConfig?
        // For simplicity, we'll try ValueKey with a unique string constructed.
        final key = ValueKey("${type}_$index"); 

        return Container(
          key: key,
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isClass ? cardColor : (type == 'LB' ? Colors.orange.withValues(alpha: 0.1) : tint.withValues(alpha: 0.05)),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isClass ? tint.withValues(alpha: 0.1) : (type=='LB' ? Colors.orange : tint).withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
              // Reorder Handle
              Icon(Icons.drag_handle, color: subTextColor),
              const SizedBox(width: 15),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(item['start'], style: GoogleFonts.poppins(fontWeight: FontWeight.bold, color: textColor)),
                  Text(item['end'], style: GoogleFonts.poppins(fontSize: 10, color: subTextColor)),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  item['label'],
                  style: GoogleFonts.poppins(
                    fontWeight: isClass ? FontWeight.w600 : FontWeight.bold,
                    color: isClass ? textColor : (type == 'LB' ? Colors.orange : tint),
                    fontSize: isClass ? 14 : 15
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
