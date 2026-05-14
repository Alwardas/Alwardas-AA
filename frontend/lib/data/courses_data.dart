import 'package:flutter/foundation.dart';
import 'dart:convert';
import 'package:flutter/services.dart';

class CoursesData {
  static List<dynamic>? _cachedCourses;

  /// Loads all courses dynamically from the assets/curriculum/ directory.
  /// Traverses regulations, branches, semesters, and subject types.
  static Future<List<dynamic>> getAllCourses() async {
    if (_cachedCourses != null) return _cachedCourses!;

    List<dynamic> all = [];
    
    try {
      // Use AssetManifest to find all files in the curriculum folder
      final String manifestContent = await rootBundle.loadString('AssetManifest.json');
      final Map<String, dynamic> manifest = json.decode(manifestContent);
      
      debugPrint("AssetManifest contains ${manifest.keys.length} keys.");
      
      // Filter for files in curriculum folder that are .json
      final List<String> curriculumFiles = manifest.keys
          .where((path) => path.toLowerCase().contains('curriculum/') && path.toLowerCase().endsWith('.json'))
          .toList();

      debugPrint("Found ${curriculumFiles.length} curriculum files dynamically.");
      if (curriculumFiles.isEmpty) {
          debugPrint("First 10 manifest keys: ${manifest.keys.take(10).toList()}");
      }

      for (String path in curriculumFiles) {
        try {
          final String content = await rootBundle.loadString(path);
          final Map<String, dynamic> data = json.decode(content);
          
          // Handle Windows paths by normalizing backslashes to forward slashes
          final normalizedPath = path.replaceAll('\\', '/');
          final List<String> parts = normalizedPath.split('/');
          
          // Fallback values if path structure differs
          final curriculumIndex = parts.indexOf('curriculum');
          String branch = 'Unknown';
          String regulation = 'C23';
          String semester = '';
          String type = 'Theory';

          if (curriculumIndex != -1) {
              regulation = data['regulation'] ?? (parts.length > curriculumIndex + 1 ? parts[curriculumIndex + 1] : 'C23');
              branch = normalizeBranch(data['branch'] ?? (parts.length > curriculumIndex + 2 ? parts[curriculumIndex + 2] : 'Unknown'));
              semester = normalizeSemester(data['semester']?.toString() ?? (parts.length > curriculumIndex + 3 ? parts[curriculumIndex + 3] : ''));
              // Type might be at index + 4 or might be the file name parent
              type = data['type'] ?? (parts.length > curriculumIndex + 4 ? parts[curriculumIndex + 4] : 'Theory');
              if (type.toLowerCase().endsWith('.json')) type = 'Theory'; // Handle cases where type is missing
          }

          if (data['subjectCode'] != null) {
            all.add({
              'id': data['subjectCode'],
              'code': data['subjectCode'],
              'name': data['subjectName'] ?? 'Unnamed Subject',
              'branch': branch,
              'semester': semester,
              'regulation': regulation.toUpperCase(),
              'type': _capitalize(type)
            });
          }
        } catch (e) {
          debugPrint("Error parsing curriculum file at $path: $e");
        }
      }
    } catch (e) {
      debugPrint("Error loading asset manifest for curriculum: $e");
      // Fallback to empty list or handled error
    }

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

  static String normalizeBranch(String b) {
    String upper = b.trim().toUpperCase();
    if (upper == 'CME' || upper == 'CM' || upper.contains('COMPUTER')) return 'Computer Engineering';
    if (upper == 'CIV' || upper == 'CIVIL' || upper == 'CE') return 'Civil Engineering';
    if (upper == 'ECE' || upper == 'EC' || upper.contains('ELECTRONICS')) return 'Electronics & Communication Engineering';
    if (upper == 'EEE' || upper == 'EE' || upper.contains('ELECTRICAL')) return 'Electrical & Electronics Engineering';
    if (upper == 'MECH' || upper == 'MEC' || upper == 'ME' || upper.contains('MECHANICAL')) return 'Mechanical Engineering';
    return b.trim();
  }

  static String normalizeSemester(String sem) {
    String s = sem.toLowerCase().trim();
    
    // Explicit Semester strings
    if (s.contains('semester')) {
      if (s.contains('1')) return 'Semester 1';
      if (s.contains('2')) return 'Semester 2';
      if (s.contains('3')) return 'Semester 3';
      if (s.contains('4')) return 'Semester 4';
      if (s.contains('5')) return 'Semester 5';
      if (s.contains('6')) return 'Semester 6';
    }

    // Handle "1st Year", "2nd Year" etc. by guessing semester based on current month
    if (s.contains('1st year') || s.contains('1st yr')) {
      final month = DateTime.now().month;
      // Jan-June: 2nd Sem, July-Dec: 1st Sem
      return (month >= 1 && month <= 6) ? 'Semester 2' : 'Semester 1';
    }
    if (s.contains('2nd year') || s.contains('2nd yr')) {
      final month = DateTime.now().month;
      // Jan-June: 4th Sem, July-Dec: 3rd Sem
      return (month >= 1 && month <= 6) ? 'Semester 4' : 'Semester 3';
    }
    if (s.contains('3rd year') || s.contains('3rd yr')) {
      final month = DateTime.now().month;
      // Jan-June: 6th Sem, July-Dec: 5th Sem
      return (month >= 1 && month <= 6) ? 'Semester 6' : 'Semester 5';
    }

    // Handle Ordinals
    if (s.contains('1st')) return 'Semester 1';
    if (s.contains('2nd')) return 'Semester 2';
    if (s.contains('3rd')) return 'Semester 3';
    if (s.contains('4th')) return 'Semester 4';
    if (s.contains('5th')) return 'Semester 5';
    if (s.contains('6th')) return 'Semester 6';

    // Handle just numbers
    if (s == '1') return 'Semester 1';
    if (s == '2') return 'Semester 2';
    if (s == '3') return 'Semester 3';
    if (s == '4') return 'Semester 4';
    if (s == '5') return 'Semester 5';
    if (s == '6') return 'Semester 6';
    
    return sem.trim();
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}

