import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiConstants {
  static const String _prodUrl = 'https://alwardas-aa-production-e288.up.railway.app';
  static const String _prodGrpcHost = 'alwardas-aa-production-e288.up.railway.app';

  static String get baseUrl {
    if (kIsWeb) {
      // In web, use the current origin (e.g., https://your-app.up.railway.app)
      return Uri.base.origin;
    }
    return _prodUrl; 
  }
  
  static String get grpcHost {
    if (kIsWeb) {
      return Uri.base.host;
    }
     return _prodGrpcHost; 
  }

  static int get grpcPort => 443; 
  
  static String get loginEndpoint => '$baseUrl/api/login';
  static String get signupEndpoint => '$baseUrl/api/signup';
  static String get forgotPasswordEndpoint => '$baseUrl/api/forgot-password';

  // Student Profile
  static String get studentProfile => '$baseUrl/api/student/profile';
  static String get studentRequestStatus => '$baseUrl/api/student/request-status';
  static String get studentRequestChange => '$baseUrl/api/student/request-change';
  static String get studentGetCourses => '$baseUrl/api/student/courses';
  static String get rejectProfileUpdate => '$baseUrl/api/user/reject-my-update';
  static String get getSections => '$baseUrl/api/sections';

  // Issue Tracking (Centralized)
  static String get submitIssue => '$baseUrl/api/issues/submit';
  static String get getIssues => '$baseUrl/api/issues';
  static String getIssueDetails(String id) => '$baseUrl/api/issues/$id';
  static String getIssueComments(String id) => '$baseUrl/api/issues/$id/comments';
  static String get submitComment => '$baseUrl/api/issues/comments/submit';
  static String assignIssue(String id) => '$baseUrl/api/issues/$id/assign';
  static String updateIssueStatus(String id) => '$baseUrl/api/issues/$id/status';

  // Faculty
  static String get facultyByBranch => '$baseUrl/api/faculty/by-branch';
  
  // HOD Courses
  static String get hodGetDepartments => '$baseUrl/api/hod/departments';
  static String get hodGetSections => '$baseUrl/api/hod/sections';
  static String get hodGetSubjects => '$baseUrl/api/hod/subjects';
  static String get hodCourseSubjects => '$baseUrl/api/hod/course-subjects';

  // Parent Requests
  static String get submitParentRequest => '$baseUrl/api/parent/requests/submit';
  static String get getParentRequests => '$baseUrl/api/parent/requests';
  static String updateParentRequestStatus(String id) => '$baseUrl/api/parent/requests/$id/status';

 }
