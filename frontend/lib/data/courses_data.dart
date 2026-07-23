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
      final AssetManifest assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      
      final List<String> curriculumFiles = assetManifest.listAssets()
          .where((path) => path.toLowerCase().contains('curriculum/') && path.toLowerCase().endsWith('.json'))
          .toList();

      debugPrint("Found ${curriculumFiles.length} curriculum files dynamically.");
      if (curriculumFiles.isEmpty) {
          debugPrint("Asset manifest returned empty for curriculum/");
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

    // Sort by Branch, then Semester, then Code
    all.sort((a, b) {
      int cmp = a['branch'].compareTo(b['branch']);
      if (cmp != 0) return cmp;
      cmp = a['semester'].compareTo(b['semester']);
      if (cmp != 0) return cmp;
      return a['code'].compareTo(b['code']);
    });

    _cachedCourses = all;
    return all;
  }

  static Future<Map<String, dynamic>?> getSubjectDetails(String subjectCode) async {
    try {
      final AssetManifest assetManifest = await AssetManifest.loadFromAssetBundle(rootBundle);
      
      final List<String> curriculumFiles = assetManifest.listAssets()
          .where((path) => path.toLowerCase().contains('curriculum/') && path.toLowerCase().endsWith('.json'))
          .toList();

      for (String path in curriculumFiles) {
        try {
          final String content = await rootBundle.loadString(path);
          final Map<String, dynamic> data = json.decode(content);
          if (data['subjectCode']?.toString().toUpperCase() == subjectCode.toUpperCase()) {
            return data;
          }
        } catch (e) {
          // Skip invalid files quietly
        }
      }
    } catch (e) {
      debugPrint("Error fetching subject details for $subjectCode: $e");
    }
    return null;
  }

  /// Retrieves formatted original curriculum topics for a given subject code, merging real API schedule/completion data
  static Future<List<Map<String, dynamic>>> getCurriculumTopicsForSubject(
    String subjectCode, {
    Map<String, dynamic>? apiTopicsMap,
  }) async {
    final details = await getSubjectDetails(subjectCode);
    if (details == null || details['units'] == null || details['units'] is! List) {
      return [];
    }

    List<Map<String, dynamic>> topics = [];
    final List<dynamic> units = details['units'];
    int globalTopicIdx = 0;

    for (var u in units) {
      final int unitNo = (u['unitNo'] ?? 1).toInt();
      final String unitTitle = u['title']?.toString() ?? 'Unit $unitNo';
      final List<dynamic> tList = (u['topics'] != null && u['topics'] is List) ? u['topics'] : [];

      if (tList.isNotEmpty) {
        for (var t in tList) {
          globalTopicIdx++;
          final String topicId = (t['id'] ?? '').toString().toLowerCase();
          final apiData = (apiTopicsMap != null && topicId.isNotEmpty) ? apiTopicsMap[topicId] : null;

          final String sno = t['sno']?.toString() ?? '$unitNo.$globalTopicIdx';
          final String topicText = t['topic']?.toString() ?? unitTitle;
          final int period = (t['period'] ?? 1).toInt();
          final String type = t['type']?.toString() ?? 'theory';

          final bool isDone = apiData?['completed'] == true;
          final String? schedDate = apiData?['scheduleDate']?.toString();
          final String? compDate = apiData?['completedDate']?.toString();
          final String? remarks = apiData?['comments']?.toString() ?? apiData?['remarks']?.toString();

          topics.add({
            'id': t['id'],
            'unitNo': unitNo,
            'unitTitle': unitTitle,
            'sno': sno,
            'topicName': 'Unit $unitNo ($sno): $topicText',
            'period': period,
            'type': type,
            'assignedDate': (schedDate != null && schedDate.isNotEmpty) ? schedDate : 'Not Assigned',
            'completed': isDone,
            'completedDate': isDone 
                ? ((compDate != null && compDate.isNotEmpty) ? compDate : (schedDate != null ? 'Completed ($schedDate)' : 'Completed')) 
                : ((schedDate != null && schedDate.isNotEmpty) ? 'Sched: $schedDate' : 'Not Completed'),
            'scheduleDate': schedDate ?? 'Not Scheduled',
            'comments': (remarks != null && remarks.isNotEmpty) 
                ? remarks 
                : (isDone ? 'Topic completed per curriculum schedule.' : 'No faculty remarks logged.'),
          });
        }
      } else {
        globalTopicIdx++;
        topics.add({
          'unitNo': unitNo,
          'unitTitle': unitTitle,
          'sno': '$unitNo.1',
          'topicName': 'Unit $unitNo: $unitTitle',
          'period': 10,
          'type': 'theory',
          'assignedDate': 'Not Assigned',
          'completed': false,
          'completedDate': 'Not Completed',
          'scheduleDate': 'Not Scheduled',
          'comments': 'No faculty remarks logged.',
        });
      }
    }

    return topics;
  }

  static String normalizeBranch(String b) {
    String upper = b.trim().toUpperCase();
    if (upper == 'CME' || upper == 'CM' || upper.contains('COMPUTER')) return 'Computer Engineering';
    if (upper == 'CIV' || upper == 'CIVIL' || upper == 'CE') return 'Civil Engineering';
    if (upper == 'EEE' || upper == 'EE' || upper.contains('ELECTRICAL')) return 'Electrical & Electronics Engineering';
    if (upper == 'ECE' || upper == 'EC' || upper.contains('ELECTRONICS')) return 'Electronics & Communication Engineering';
    if (upper == 'MECH' || upper == 'MEC' || upper == 'ME' || upper.contains('MECHANICAL')) return 'Mechanical Engineering';
    if (upper == 'AIML' || upper == 'AI' || upper.contains('INTELLIGENCE') || upper.contains('MACHINE LEARNING')) return 'Artificial Intelligence and Machine Learning';
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

