import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'api_constants.dart';
import 'models/api_response.dart';

class ApiConfig {
  static const Duration timeout = Duration(seconds: 15);

  /// Centralized GET request
  static Future<ApiResponse<dynamic>> get(String endpoint, {Map<String, String>? headers}) async {
    try {
      if (kDebugMode) print('GET: $endpoint');
      final response = await http.get(
        Uri.parse(endpoint),
        headers: headers ?? {'Content-Type': 'application/json'},
      ).timeout(timeout);

      if (kDebugMode) print('RESPONSE FROM $endpoint: ${response.body}');
      return _processResponse(response);
    } catch (e) {
      if (kDebugMode) print('GET Error ($endpoint): $e');
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  /// Centralized POST request
  static Future<ApiResponse<dynamic>> post(String endpoint, {Map<String, String>? headers, dynamic body}) async {
    try {
      if (kDebugMode) {
        print('POST: $endpoint');
        print('Body: $body');
      }
      final response = await http.post(
        Uri.parse(endpoint),
        headers: headers ?? {'Content-Type': 'application/json'},
        body: body != null ? json.encode(body) : null,
      ).timeout(timeout);

      if (kDebugMode) print('RESPONSE FROM $endpoint: ${response.body}');
      return _processResponse(response);
    } catch (e) {
      if (kDebugMode) print('POST Error ($endpoint): $e');
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  /// Centralized PUT request
  static Future<ApiResponse<dynamic>> put(String endpoint, {Map<String, String>? headers, dynamic body}) async {
    try {
      if (kDebugMode) {
        print('PUT: $endpoint');
        print('Body: $body');
      }
      final response = await http.put(
        Uri.parse(endpoint),
        headers: headers ?? {'Content-Type': 'application/json'},
        body: body != null ? json.encode(body) : null,
      ).timeout(timeout);

      if (kDebugMode) print('RESPONSE FROM $endpoint: ${response.body}');
      return _processResponse(response);
    } catch (e) {
      if (kDebugMode) print('PUT Error ($endpoint): $e');
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  /// Centralized PATCH request
  static Future<ApiResponse<dynamic>> patch(String endpoint, {Map<String, String>? headers, dynamic body}) async {
    try {
      if (kDebugMode) {
        print('PATCH: $endpoint');
        print('Body: $body');
      }
      final response = await http.patch(
        Uri.parse(endpoint),
        headers: headers ?? {'Content-Type': 'application/json'},
        body: body != null ? json.encode(body) : null,
      ).timeout(timeout);

      if (kDebugMode) print('RESPONSE FROM $endpoint: ${response.body}');
      return _processResponse(response);
    } catch (e) {
      if (kDebugMode) print('PATCH Error ($endpoint): $e');
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  /// Centralized DELETE request
  static Future<ApiResponse<dynamic>> delete(String endpoint, {Map<String, String>? headers, dynamic body}) async {
    try {
      if (kDebugMode) {
        print('DELETE: $endpoint');
        if (body != null) print('Body: $body');
      }
      final request = http.Request('DELETE', Uri.parse(endpoint));
      request.headers.addAll(headers ?? {'Content-Type': 'application/json'});
      if (body != null) {
        request.body = json.encode(body);
      }
      
      final streamedResponse = await request.send().timeout(timeout);
      final response = await http.Response.fromStream(streamedResponse);

      if (kDebugMode) print('RESPONSE FROM $endpoint: ${response.body}');
      return _processResponse(response);
    } catch (e) {
      if (kDebugMode) print('DELETE Error ($endpoint): $e');
      return ApiResponse(success: false, message: 'Network error: $e');
    }
  }

  /// Process HTTP response
  static ApiResponse<dynamic> _processResponse(http.Response response) {
    if (kDebugMode) {
      print('Status Code: ${response.statusCode}');
      print('Response Body: ${response.body}');
    }

    try {
      if (response.body.isEmpty) {
        return ApiResponse(
          success: response.statusCode >= 200 && response.statusCode < 300,
          message: response.statusCode >= 200 && response.statusCode < 300 ? 'Success' : 'Error',
        );
      }

      final decoded = json.decode(response.body);

      // If backend sends our standard format
      if (decoded is Map<String, dynamic> && decoded.containsKey('success')) {
        return ApiResponse.fromJson(decoded);
      }

      // If backend sends a raw list or map without success wrapper
      if (response.statusCode >= 200 && response.statusCode < 300) {
        return ApiResponse.fromFallback(decoded);
      }

      // Backend error map (e.g. {"error": "..."})
      if (decoded is Map<String, dynamic> && decoded.containsKey('error')) {
         return ApiResponse(success: false, message: decoded['error'].toString());
      }

      return ApiResponse(success: false, message: 'Failed with status ${response.statusCode}');
    } catch (e) {
      if (kDebugMode) print('JSON Parse Error: $e');
      return ApiResponse(
        success: response.statusCode >= 200 && response.statusCode < 300,
        message: 'Failed to parse response',
        data: response.body, // Fallback to raw body
      );
    }
  }
}
