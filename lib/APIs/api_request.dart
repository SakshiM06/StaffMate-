// lib/core/api/api_request.dart

import 'dart:convert';
import 'dart:developer';
import 'package:http/http.dart' as http;
import 'package:staff_mate/APIs/api_headers.dart';

/// Generic API request function - Exactly like your React apiRequest
class ApiRequest {
  static Future<dynamic> request({
    required String url,
    required String method,
    dynamic data,
    Map<String, String>? headers,
    String responseType = 'json',
  }) async {
    // Get default headers if not provided
    final requestHeaders = headers ?? await ApiHeaders.getHeaders();
    
    final requestOptions = {
      'method': method,
      'headers': {
        'Content-Type': 'application/json',
        'Access-Control-Allow-Origin': '*',
        ...requestHeaders,
      },
      'body': data != null ? json.encode(data) : null,
    };
    
    log('API Request: $method $url');
    log('Headers: ${requestOptions['headers']}');
    if (data != null) {
      log('Body: ${json.encode(data)}');
    }
    
    try {
      final http.Response response;
      
      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(
            Uri.parse(url),
            headers: requestOptions['headers'] as Map<String, String>,
          );
          break;
        case 'POST':
          response = await http.post(
            Uri.parse(url),
            headers: requestOptions['headers'] as Map<String, String>,
            body: requestOptions['body'] as String?,
          );
          break;
        case 'PUT':
          response = await http.put(
            Uri.parse(url),
            headers: requestOptions['headers'] as Map<String, String>,
            body: requestOptions['body'] as String?,
          );
          break;
        case 'DELETE':
          response = await http.delete(
            Uri.parse(url),
            headers: requestOptions['headers'] as Map<String, String>,
            body: requestOptions['body'] as String?,
          );
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }
      
      log('API Response Status: ${response.statusCode}');
      log('API Response Body: ${response.body}');
      
      if (response.statusCode >= 200 && response.statusCode < 300) {
        if (responseType == 'blob') {
          return response.bodyBytes;
        } else if (response.body.isEmpty) {
          return null;
        } else {
          try {
            return json.decode(response.body);
          } catch (e) {
            log('JSON Parse Error: $e');
            return response.body;
          }
        }
      } else {
        // Handle error response
        try {
          final errorData = json.decode(response.body);
          throw Exception(errorData['message'] ?? errorData['error'] ?? 'API Error: ${response.statusCode}');
        } catch (e) {
          throw Exception('API Error: ${response.statusCode} - ${response.body}');
        }
      }
    } catch (error) {
      log('API Error: $error');
      rethrow;
    }
  }
  
  // Convenience methods
  static Future<dynamic> get(String url, {Map<String, String>? headers}) {
    return request(url: url, method: 'GET', headers: headers);
  }
  
  static Future<dynamic> post(String url, dynamic data, {Map<String, String>? headers}) {
    return request(url: url, method: 'POST', data: data, headers: headers);
  }
  
  static Future<dynamic> put(String url, dynamic data, {Map<String, String>? headers}) {
    return request(url: url, method: 'PUT', data: data, headers: headers);
  }
  
  static Future<dynamic> delete(String url, {Map<String, String>? headers, dynamic data}) {
    return request(url: url, method: 'DELETE', data: data, headers: headers);
  }
}