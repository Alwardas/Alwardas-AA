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
      
      // Filter for files in assets/curriculum/ that are .json
      final List<String> curriculumFiles = manifest.keys
          .where((path) => (path.toLowerCase().startsWith('assets/curriculum/') || path.toLowerCase().startsWith('assets\\curriculum\\')) && path.toLowerCase().endsWith('.json'))
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
          String branch = _normalizeBranch(data['branch'] ?? (parts.length > 3 ? parts[3] : 'Unknown'));
          String regulation = data['regulation'] ?? (parts.length > 2 ? parts[2] : 'C23');
          String type = data['type'] ?? (parts.length > 5 ? parts[5] : 'Theory');
          
          // Normalize semester to match the format expected by UI screens
          String semester = _normalizeSemester(data['semester']?.toString() ?? (parts.length > 4 ? parts[4] : ''));

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

  static String _normalizeBranch(String b) {
    String upper = b.trim().toUpperCase();
    if (upper == 'CME' || upper == 'CM' || upper.contains('COMPUTER')) return 'Computer Engineering';
    if (upper == 'CIV' || upper == 'CIVIL' || upper == 'CE') return 'Civil Engineering';
    if (upper == 'ECE' || upper == 'EC' || upper.contains('ELECTRONICS')) return 'Electronics & Communication Engineering';
    if (upper == 'EEE' || upper == 'EE' || upper.contains('ELECTRICAL')) return 'Electrical and Electronics Engineering';
    if (upper == 'MECH' || upper == 'MEC' || upper == 'ME' || upper.contains('MECHANICAL')) return 'Mechanical Engineering';
    return b.trim();
  }

  static String _normalizeSemester(String sem) {
    String s = sem.toLowerCase();
    if (s.contains('1') && !s.contains('3') && !s.contains('5')) return 'Semester 1';
    if (s.contains('2') && !s.contains('4') && !s.contains('6')) return 'Semester 2';
    if (s.contains('3')) return 'Semester 3';
    if (s.contains('4')) return 'Semester 4';
    if (s.contains('5')) return 'Semester 5';
    if (s.contains('6')) return 'Semester 6';
    return sem.trim();
  }

  static String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1).toLowerCase();
  }
}

