import 'package:flutter/foundation.dart';
import 'dart:io';

class ApiConstants {
  // ---------------------------------------------------------------------------
  // NETWORK CONFIGURATION
  // ---------------------------------------------------------------------------
  
  // Production URL
  static const String _prodUrl = 'https://alwardas-aa-production.up.railway.app';
  static const String _prodGrpcHost = 'alwardas-aa-production.up.railway.app';

  static String get baseUrl {
    if (kReleaseMode) return _prodUrl;
    
    // Local Development
    try {
      if (Platform.isAndroid) return 'http://10.0.2.2:3001';
    } catch(e) {
      // web or other platforms where Platform.isAndroid might fail or not be relevant
    }
    return 'http://localhost:3001';
  }
  
  // gRPC Configuration
  static String get grpcHost {
     if (kReleaseMode) return _prodGrpcHost;
     if (!kIsWeb && Platform.isAndroid) return '10.0.2.2';
     return 'localhost';
  }

  static int get grpcPort => kReleaseMode ? 443 : 3001; 
  // Wait, the backend in main.rs has grpc_service multiplexed?
  // It says: .fallback(...) checks for application/grpc. 
  // So gRPC is also on port 3001 (or whatever PORT is).
  // So grpcPort should be 3001 locally.
  
  static String get loginEndpoint => '$baseUrl/api/login';
  static String get signupEndpoint => '$baseUrl/api/signup';
  static String get forgotPasswordEndpoint => '$baseUrl/api/forgot-password';

  // Student Profile
  static String get studentProfile => '$baseUrl/api/student/profile';
  static String get studentRequestStatus => '$baseUrl/api/student/request-status';
  static String get studentRequestChange => '$baseUrl/api/student/request-change';

  // Issue Tracking
  static String get studentSubmitIssue => '$baseUrl/api/issues/submit';
  static String get studentGetIssues => '$baseUrl/api/issues';
}
