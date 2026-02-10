import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class StudentMarksScreen extends StatelessWidget {
  const StudentMarksScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black;

    return Scaffold(
      appBar: AppBar(
        title: Text("Academics & Marks", style: GoogleFonts.poppins(color: textColor, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: IconThemeData(color: textColor),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        physics: const BouncingScrollPhysics(),
        children: [
          _buildSemesterCard(context, "Semester 1", "SGPA: 8.5", [
            {"subject": "Engineering Mathematics-I", "grade": "A+", "score": "92/100"},
            {"subject": "Engineering Chemistry", "grade": "A", "score": "85/100"},
            {"subject": "Basic Electronics", "grade": "B+", "score": "78/100"},
            {"subject": "Computer Programming", "grade": "O", "score": "95/100"},
          ]),
          const SizedBox(height: 20),
          _buildSemesterCard(context, "Semester 2 (Ongoing)", "Current Avg: 82%", [
            {"subject": "Engineering Mathematics-II", "grade": "-", "score": "88/100 (Internal)"},
            {"subject": "Engineering Physics", "grade": "-", "score": "75/100 (Internal)"},
             {"subject": "Data Structures", "grade": "-", "score": "90/100 (Internal)"},
          ]),
        ],
      ),
    );
  }

  Widget _buildSemesterCard(BuildContext context, String title, String subtitle, List<Map<String, String>> subjects) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardColor = isDark ? const Color(0xFF1E1E24) : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.05), blurRadius: 10, offset: const Offset(0, 5))
        ]
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          title: Text(title, style: GoogleFonts.poppins(fontWeight: FontWeight.bold, fontSize: 16)),
          subtitle: Text(subtitle, style: GoogleFonts.poppins(color: Colors.green, fontWeight: FontWeight.w600)),
          children: [
            ...subjects.map((s) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: Colors.grey.withValues(alpha: 0.1)))
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s['subject']!, style: GoogleFonts.poppins(fontWeight: FontWeight.w500)),
                      Text("Score: ${s['score']}", style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey)),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(10)
                    ),
                    child: Text(s['grade']!, style: GoogleFonts.poppins(fontWeight: FontWeight.bold)),
                  )
                ],
              ),
            ))
          ],
        ),
      ),
    );
  }
}
