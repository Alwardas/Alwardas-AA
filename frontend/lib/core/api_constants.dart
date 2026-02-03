import 'dart:io';
import 'package:flutter/foundation.dart';

class ApiConstants {
  // ---------------------------------------------------------------------------
  // NETWORK CONFIGURATION
  // ---------------------------------------------------------------------------
  // This default URL is used for the first launch.
  // 
  // NOTE: This URL is fixed for the production environment.
  //
  // Recommended Defaults:
  // - Deployed Server: 'https://alwardas-aa-production.up.railway.app'
  // - Local Android Emulator: 'http://10.0.2.2:3001'
  // - Local Physical Device: 'http://192.168.29.227:3001'
  // - Local Windows/iOS: 'http://localhost:3001'
  
  // Set this to TRUE to build an APK that allows access from ANY network 
  // (using the Railway Production Server)
  static const bool forceProduction = true;

  static String get baseUrl {
    if (forceProduction || kReleaseMode) return 'https://alwardas-aa-production.up.railway.app';
    // For Android, use the machine's LAN IP to support both Emulators and Physical Devices
    if (!kIsWeb && Platform.isAndroid) return 'http://192.168.29.227:3001';
    return 'http://localhost:3001';
  }
  
  // gRPC Configuration
  static String get grpcHost {
    if (forceProduction || kReleaseMode) return 'alwardas-aa-production.up.railway.app';
    if (!kIsWeb && Platform.isAndroid) return '192.168.29.227';
    return 'localhost';
  }

  static int get grpcPort => (forceProduction || kReleaseMode) ? 443 : 50051;
  
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
