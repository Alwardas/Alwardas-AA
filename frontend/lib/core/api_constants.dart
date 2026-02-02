class ApiConstants {
  // ---------------------------------------------------------------------------
  // NETWORK CONFIGURATION
  // ---------------------------------------------------------------------------
  // This default URL is used for the first launch.
  // 
  // TIP: You can change this URL inside the app (Login Screen -> Settings Icon)
  // without modifying this code. The app will remember your setting.
  //
  // Recommended Defaults:
  // - Android Emulator: 'http://10.0.2.2:3001'
  // - iOS Simulator: 'http://127.0.0.1:3001'
  // - Physical Device: 'http://172.25.82.167:3001'
  static String baseUrl = 'http://172.25.82.167:3001';
  
  // gRPC Configuration
  static String grpcHost = '172.25.82.167';
  static int grpcPort = 50051;
  
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
