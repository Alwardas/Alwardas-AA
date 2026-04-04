import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class AuthService {
  static const String _userDataKey = 'user_data';

  static Future<void> saveUserSession(Map<String, dynamic> userData) async {
    final prefs = await SharedPreferences.getInstance();
    userData['session_expiry'] = DateTime.now().add(const Duration(hours: 24)).toIso8601String();
    await prefs.setString(_userDataKey, jsonEncode(userData));
  }

  static Future<Map<String, dynamic>?> getUserSession() async {
    final prefs = await SharedPreferences.getInstance();
    final jsonString = prefs.getString(_userDataKey);
    if (jsonString != null) {
      final data = jsonDecode(jsonString) as Map<String, dynamic>;
      if (data.containsKey('session_expiry')) {
         final expiry = DateTime.tryParse(data['session_expiry']);
         if (expiry != null && DateTime.now().isAfter(expiry)) {
             await logout(); // Session expired
             return null;
         }
      }
      return data;
    }
    return null;
  }

  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userDataKey);
  }
  
  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.containsKey(_userDataKey);
  }
}
