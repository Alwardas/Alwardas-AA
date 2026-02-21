import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AbsentStudentsPopup extends StatelessWidget {
  final List<dynamic> absents;
  final String title;

  const AbsentStudentsPopup({super.key, required this.absents, required this.title});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textColor = isDark ? Colors.white : Colors.black87;
    final bgColor = isDark ? const Color(0xFF1E1E2D) : Colors.white;
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 20,
            offset: const Offset(0, -5),
          )
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.poppins(fontSize: 20, fontWeight: FontWeight.bold, color: textColor)),
                  Text('${absents.length} students marked absent', style: GoogleFonts.poppins(fontSize: 13, color: Colors.redAccent, fontWeight: FontWeight.w500)),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                  shape: BoxShape.circle,
                ),
                child: IconButton(
                  onPressed: () => Navigator.pop(context), 
                  icon: const Icon(Icons.close, size: 20),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          if (absents.isEmpty)
             Container(
               padding: const EdgeInsets.symmetric(vertical: 40),
               width: double.infinity,
               child: Column(
                 children: [
                   Icon(Icons.people_outline, size: 48, color: Colors.grey.withValues(alpha: 0.5)),
                   const SizedBox(height: 12),
                   Text("No students absent.", style: GoogleFonts.poppins(color: Colors.grey)),
                 ],
               ),
             )
          else
            ConstrainedBox(
              constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const BouncingScrollPhysics(),
                itemCount: absents.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final s = absents[index];
                  final name = s['fullName'] ?? s['full_name'] ?? 'Unknown Student';
                  final id = s['studentId'] ?? s['student_id'] ?? '??';
                  
                  return Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.black.withValues(alpha: 0.02),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          backgroundColor: Colors.red.withValues(alpha: 0.1),
                          radius: 20,
                          child: Text(
                             id.toString().substring(id.toString().length > 2 ? id.toString().length - 2 : 0), 
                             style: const TextStyle(color: Colors.red, fontSize: 13, fontWeight: FontWeight.bold)
                          ),
                        ),
                        const SizedBox(width: 15),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: GoogleFonts.poppins(fontWeight: FontWeight.w600, fontSize: 15, color: textColor)),
                              Text(id, style: GoogleFonts.poppins(fontSize: 12, color: Colors.grey[500], letterSpacing: 0.5)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          SizedBox(height: MediaQuery.of(context).padding.bottom + 10),
        ],
      ),
    );
  }

  static void show(BuildContext context, List<dynamic> absents, String title) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => AbsentStudentsPopup(absents: absents, title: title),
    );
  }
}
