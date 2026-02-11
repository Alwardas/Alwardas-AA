import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:shared_preferences/shared_preferences.dart';
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
  
  // Break positions
  int _shortBreak1After = 2;
  int _lunchAfter = 4;
  int _shortBreak2After = 6;

  List<Map<String, dynamic>> _generatedPeriods = [];

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      final startHour = prefs.getInt('timing_start_hour_${widget.branch}') ?? 9;
      final startMinute = prefs.getInt('timing_start_minute_${widget.branch}') ?? 0;
      _startTime = TimeOfDay(hour: startHour, minute: startMinute);
      _classDuration = prefs.getInt('timing_class_duration_${widget.branch}') ?? 50;
      _shortBreakDuration = prefs.getInt('timing_short_break_${widget.branch}') ?? 10;
      _lunchDuration = prefs.getInt('timing_lunch_${widget.branch}') ?? 50;
    });
    _generateTimings();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('timing_start_hour_${widget.branch}', _startTime.hour);
    await prefs.setInt('timing_start_minute_${widget.branch}', _startTime.minute);
    await prefs.setInt('timing_class_duration_${widget.branch}', _classDuration);
    await prefs.setInt('timing_short_break_${widget.branch}', _shortBreakDuration);
    await prefs.setInt('timing_lunch_${widget.branch}', _lunchDuration);
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text("Timing Settings Saved Locally")),
    );
  }

  void _generateTimings() {
    List<Map<String, dynamic>> periods = [];
    DateTime current = DateTime(2026, 1, 1, _startTime.hour, _startTime.minute);
    
    int periodCount = 1;
    
    for (int i = 1; i <= 11; i++) { // Max 8 classes + breaks
       // This is a simplified loop to handle the specific logic
    }
    
    // Let's do it procedurally
    DateTime time = DateTime(2026, 1, 1, _startTime.hour, _startTime.minute);
    
    for (int p = 1; p <= 8; p++) {
       // Class
       DateTime start = time;
       time = time.add(Duration(minutes: _classDuration));
       periods.add({
         'type': 'class',
         'number': p,
         'start': DateFormat('HH:mm').format(start),
         'end': DateFormat('HH:mm').format(time),
       });
       
       // Breaks
       if (p == _shortBreak1After) {
          DateTime bStart = time;
          time = time.add(Duration(minutes: _shortBreakDuration));
          periods.add({
            'type': 'break',
            'label': 'Short Break',
            'start': DateFormat('HH:mm').format(bStart),
            'end': DateFormat('HH:mm').format(time),
          });
       } else if (p == _lunchAfter) {
          DateTime bStart = time;
          time = time.add(Duration(minutes: _lunchDuration));
          periods.add({
            'type': 'lunch',
            'label': 'Lunch Break',
            'start': DateFormat('HH:mm').format(bStart),
            'end': DateFormat('HH:mm').format(time),
          });
       } else if (p == _shortBreak2After) {
          DateTime bStart = time;
          time = time.add(Duration(minutes: _shortBreakDuration));
          periods.add({
            'type': 'break',
            'label': 'Short Break',
            'start': DateFormat('HH:mm').format(bStart),
            'end': DateFormat('HH:mm').format(time),
          });
       }
    }
    
    setState(() {
      _generatedPeriods = periods;
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
          _buildTimePickerRow("College Start Time", _startTime, (val) {
            setState(() => _startTime = val);
            _generateTimings();
          }, tint, textColor),
          const Divider(height: 30),
          _buildDurationRow("Class Duration", _classDuration, (val) {
            setState(() => _classDuration = val);
            _generateTimings();
          }, "mins", tint, textColor),
          const SizedBox(height: 15),
          _buildDurationRow("Short Break", _shortBreakDuration, (val) {
            setState(() => _shortBreakDuration = val);
            _generateTimings();
          }, "mins", tint, textColor),
          const SizedBox(height: 15),
          _buildDurationRow("Lunch Break", _lunchDuration, (val) {
            setState(() => _lunchDuration = val);
            _generateTimings();
          }, "mins", tint, textColor),
        ],
      ),
    );
  }

  Widget _buildTimePickerRow(String label, TimeOfDay time, Function(TimeOfDay) onChanged, Color tint, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w500)),
        GestureDetector(
          onTap: () async {
            final picked = await showTimePicker(context: context, initialTime: time);
            if (picked != null) onChanged(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(color: tint.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(10)),
            child: Text(time.format(context), style: TextStyle(color: tint, fontWeight: FontWeight.bold)),
          ),
        ),
      ],
    );
  }

  Widget _buildDurationRow(String label, int value, Function(int) onChanged, String unit, Color tint, Color textColor) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(label, style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.w500)),
        Row(
          children: [
             IconButton(onPressed: () => onChanged(value > 5 ? value - 5 : 0), icon: Icon(Icons.remove_circle_outline, color: tint, size: 20)),
             Container(
               width: 60,
               alignment: Alignment.center,
               child: Text("$value $unit", style: TextStyle(color: textColor, fontWeight: FontWeight.bold)),
             ),
             IconButton(onPressed: () => onChanged(value + 5), icon: Icon(Icons.add_circle_outline, color: tint, size: 20)),
          ],
        )
      ],
    );
  }

  Widget _buildPreviewList(Color cardColor, Color textColor, Color subTextColor, Color tint) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _generatedPeriods.length,
      itemBuilder: (context, index) {
        final item = _generatedPeriods[index];
        final bool isClass = item['type'] == 'class';
        
        return Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: isClass ? cardColor : tint.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(color: isClass ? tint.withValues(alpha: 0.1) : tint.withValues(alpha: 0.3)),
          ),
          child: Row(
            children: [
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
                  isClass ? "Period ${item['number']}" : "${item['label']}",
                  style: GoogleFonts.poppins(
                    fontWeight: isClass ? FontWeight.w600 : FontWeight.bold,
                    color: isClass ? textColor : tint,
                    letterSpacing: isClass ? 0 : 1
                  ),
                ),
              ),
              if (isClass) 
                Text("${_classDuration}m", style: TextStyle(fontSize: 12, color: subTextColor)),
            ],
          ),
        );
      },
    );
  }
}
