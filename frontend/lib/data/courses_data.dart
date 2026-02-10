import 'dart:convert';
import 'package:flutter/services.dart';

class CoursesData {
  static List<dynamic>? _cachedCourses;

  /// Loads all courses from multiple JSON files.
  /// Branches: Civil, CME, ECE, EEE, Mech
  static Future<List<dynamic>> getAllCourses() async {
    if (_cachedCourses != null) return _cachedCourses!;

    List<dynamic> all = [];
    final branches = ['civil.json', 'cme.json', 'ece.json', 'eee.json', 'mech.json'];

    print("Loading courses from ${branches.length} files...");
    for (String file in branches) {
      try {
        final String content = await rootBundle.loadString('assets/data/json/$file');
        final Map<String, dynamic> data = json.decode(content);
        final String branchName = data['branch_name'] ?? 'Unknown';
        int subjectsCount = 0;
        
        if (data['semesters'] != null) {
          final Map<String, dynamic> semesters = data['semesters'];
          semesters.forEach((semName, types) {
             // Normalize semester name (e.g., "1st year" -> "1st Year")
             String normalizedSem = semName.toLowerCase();
             if (normalizedSem.contains("1st")) {
               normalizedSem = "1st Year";
             } else if (normalizedSem.contains("2nd")) normalizedSem = "2nd Semester";
             else if (normalizedSem.contains("3rd")) normalizedSem = "3rd Semester";
             else if (normalizedSem.contains("4th")) normalizedSem = "4th Semester";
             else if (normalizedSem.contains("5th")) normalizedSem = "5th Semester";
             else if (normalizedSem.contains("6th")) normalizedSem = "6th Semester";
             else normalizedSem = semName; 

             if (types is Map<String, dynamic>) {
               // Theory
               if (types['theory'] != null && types['theory'] is List) {
                 for (var sub in types['theory']) {
                    if (sub is Map && sub['id'] != null) {
                      all.add({
                        'id': sub['id'],
                        'code': sub['id'],
                        'name': sub['name'] ?? 'Unnamed Subject',
                        'branch': branchName,
                        'semester': normalizedSem,
                        'type': 'Theory'
                      });
                      subjectsCount++;
                    }
                 }
               }
               // Practical
               if (types['practical'] != null && types['practical'] is List) {
                 for (var sub in types['practical']) {
                    if (sub is Map && sub['id'] != null) {
                      all.add({
                        'id': sub['id'],
                        'code': sub['id'],
                        'name': sub['name'] ?? 'Unnamed Subject',
                        'branch': branchName,
                        'semester': normalizedSem,
                        'type': 'Practical'
                      });
                      subjectsCount++;
                    }
                 }
               }
             }
          });
        }
        print("Loaded $subjectsCount subjects from $file ($branchName)");
      } catch (e) {
        print("Error loading course data from $file: $e");
        print("Make sure $file exists in assets/data/json/ and is listed in pubspec.yaml assets.");
      }
    }

    // Secondary processing: Ensure IDs are unique if branches share codes (though usually branch specific)
    // Actually, the teacher might teach different subjects, so they should be unique in the list.
    
    // Sort by Branch, then Semester, then Name
    all.sort((a, b) {
      int cmp = a['branch'].compareTo(b['branch']);
      if (cmp != 0) return cmp;
      cmp = a['semester'].compareTo(b['semester']);
      if (cmp != 0) return cmp;
      return a['name'].compareTo(b['name']);
    });

    _cachedCourses = all;
    return all;
  }
}
