import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiConstants {
  static const String _prodUrl = 'http://alwardas-aa-production.up.railway.app';
  static const String _prodGrpcHost = 'alwardas-aa-production.up.railway.app';

  static String get baseUrl {
    return _prodUrl; 
  }
  
  static String get grpcHost {
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

  // Issue Tracking
  static String get studentSubmitIssue => '$baseUrl/api/issues/submit';
  static String get studentGetIssues => '$baseUrl/api/issues';

  // Faculty
  static String get facultyByBranch => '$baseUrl/api/faculty/by-branch';
}
