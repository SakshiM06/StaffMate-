import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:staff_mate/services/session_manger.dart' ;// Import your SessionManager

class ApiService {
  static const String baseUrl = "https://test.smartcarehis.com:8443/security/auth/login";
  static const String refreshUrl = "https://test.smartcarehis.com:8443/security/auth/refresh";
  
  // Store tokens for reuse (in memory cache)
  static String? accessToken;
  static String? refreshToken;
  static DateTime? tokenExpiryTime;
  static String? _tokenPrefix;
  
  // Timer for auto-refresh
  static Timer? _autoRefreshTimer;

  static Future<Map<String, dynamic>?> loginUser(
      String userName, String password) async {
    try {
      final String ipHost = await _getLocalIpAddress();
      
      final body = {
        "userName": userName.trim(), 
        "password": password.trim(),
        "forceLogin": false,
        "remoteAddr": ipHost,
      };

      debugPrint("Sending request to: $baseUrl");
      debugPrint("Body: $body");

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: const {
          "Content-Type": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
        body: jsonEncode(body),
      );

      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Headers: ${response.headers}");
      debugPrint("Body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        await _extractAndStoreTokens(response.headers, responseData);
        
        // Save tokens to SessionManager
        await SessionManager.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          expiryTime: tokenExpiryTime,
        );
        
        // Save session data
        final data = responseData['data'];
        if (data != null) {
          await SessionManager.saveSession(
            bearer: data['bearer'] ?? '',
            token: data['token'] ?? '',
            clinicId: data['clinicid'] ?? '',
            subscriptionRemainingDays: data['subscription_remaining_days'] ?? 0,
            userId: data['userId'] ?? '',
            zoneid: data['zoneid'] ?? '',
            expiryTime: data['expirytime'] ?? '',
            branchId: 1, // Get from response if available
            refreshToken: refreshToken,
            tokenExpiry: tokenExpiryTime,
          );
        }
        
        // Start token auto-refresh timer
        _startAutoRefreshTimer();
        
        return responseData;
      } else {
        debugPrint("Login failed with status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("Error: $e");
      return null;
    }
  }

  static Future<void> _extractAndStoreTokens(Map<String, String> headers, Map<String, dynamic> responseData) async {
    debugPrint("======= EXTRACTING TOKENS =======");
    
    final data = responseData['data'];
    
    if (data != null) {
      _tokenPrefix = data['bearer'] ?? "SmartCare ";
      debugPrint("Token prefix extracted: '$_tokenPrefix'");
      
      accessToken = data['token'] ?? data['accessToken'];
      debugPrint("Access Token extracted: ${accessToken != null ? 'Yes' : 'No'}");
      
      refreshToken = data['refreshToken'] ?? data['refresh_token'];
      if (refreshToken?.isNotEmpty == true) {
        debugPrint("Refresh token from data: ${refreshToken!.substring(0, min(30, refreshToken!.length))}...");
      }
      
      if (data['expirytime'] != null) {
        try {
          tokenExpiryTime = DateTime.parse(data['expirytime']);
          debugPrint("Token expiry from response: $tokenExpiryTime");
        } catch (e) {
          tokenExpiryTime = DateTime.now().add(const Duration(minutes: 1));
        }
      }
    }
    
    debugPrint("==================================");
  }

  static void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    
    if (tokenExpiryTime != null) {
      final now = DateTime.now();
      final timeUntilExpiry = tokenExpiryTime!.difference(now);
      
      // Refresh 2 minutes before expiry
      final refreshDelay = timeUntilExpiry.inSeconds - 120;
      
      if (refreshDelay > 0) {
        debugPrint("Scheduling auto-refresh in $refreshDelay seconds");
        _autoRefreshTimer = Timer(Duration(seconds: refreshDelay), () {
          debugPrint("Auto-refreshing token before expiry");
          refreshUserToken();
        });
      }
    }
  }

  static bool isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])))
        );
        final expiry = DateTime.fromMillisecondsSinceEpoch(payload['exp'] * 1000);
        final isExpired = DateTime.now().isAfter(expiry);
        return isExpired;
      }
    } catch (e) {
      debugPrint("Error decoding token: $e");
    }
    return false;
  }

  static Future<bool> refreshUserToken() async {
    try {
      debugPrint("======= REFRESH TOKEN CALLED =======");
      
      // Try to get tokens from SessionManager if not in memory
      if (refreshToken == null) {
        refreshToken = await SessionManager.getRefreshToken();
      }
      if (accessToken == null) {
        accessToken = await SessionManager.getAccessToken();
      }
      if (tokenExpiryTime == null) {
        tokenExpiryTime = await SessionManager.getTokenExpiry();
      }
      
      debugPrint("Access Token present: ${accessToken != null}");
      debugPrint("Refresh Token present: ${refreshToken != null}");
      
      if (refreshToken?.isEmpty ?? true) {
        debugPrint("❌ No refresh token available - cannot refresh");
        return false;
      }

      final String ipHost = await _getLocalIpAddress();
      
      // Send refresh token in body with key "refereshToken"
      debugPrint("Sending refresh token in body with key 'refereshToken'");
      final response = await http.post(
        Uri.parse(refreshUrl),
        headers: {
          "Content-Type": "application/json",
          "Accept": "application/json",
        },
        body: jsonEncode({
          "refereshToken": refreshToken,
          "remoteAddr": ipHost,
        }),
      ).timeout(const Duration(minutes: 15));

      debugPrint("Refresh Status Code: ${response.statusCode}");
      
      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body);
        final newData = responseData['data'];
        
        if (newData != null) {
          // Update token prefix
          if (newData['bearer'] != null) {
            _tokenPrefix = newData['bearer'];
          }
          
          // Update tokens
          accessToken = newData['token'];
          if (newData['expirytime'] != null) {
            tokenExpiryTime = DateTime.parse(newData['expirytime']);
          }
          if (newData['refreshToken'] != null) {
            refreshToken = newData['refreshToken'];
          }
          
          // Save updated tokens to SessionManager
          await SessionManager.saveTokens(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiryTime: tokenExpiryTime,
          );
          
          debugPrint("✅ Token refreshed successfully");
          debugPrint("New expiry: $tokenExpiryTime");
          
          // Reschedule auto-refresh timer
          _startAutoRefreshTimer();
          
          // Update user activity in SessionManager (prevents popup)
          SessionManager.updateUserActivity();
          
          return true;
        }
      }
      
      debugPrint("❌ Token refresh failed with status: ${response.statusCode}");
      return false;

    } catch (e) {
      debugPrint("❌ Error refreshing token: $e");
      return false;
    }
  }

  static Future<bool> checkAndRefreshToken() async {
    if (tokenExpiryTime != null && accessToken != null) {
      final now = DateTime.now();
      final timeUntilExpiry = tokenExpiryTime!.difference(now);
      
      // Refresh if token expires in less than 2 minutes
      if (timeUntilExpiry.inMinutes < 15) {
        debugPrint("Token expiring soon, refreshing...");
        
        // Update user activity before refresh to prevent popup
        SessionManager.updateUserActivity();
        
        return await refreshUserToken();
      }
      return true;
    }
    return false;
  }

  static void updateUserActivity() {
    // Update activity in SessionManager
    SessionManager.updateUserActivity();
  }

  static void clearSession() {
    accessToken = null;
    refreshToken = null;
    tokenExpiryTime = null;
    _tokenPrefix = null;
    _autoRefreshTimer?.cancel();
    debugPrint("ApiService session cleared");
  }

  static Future<String> _getLocalIpAddress() async {
    try {
      for (var interface in await NetworkInterface.list()) {
        for (var addr in interface.addresses) {
          if (addr.address != '127.0.0.1' && 
              addr.address != '::1' && 
              addr.address.isNotEmpty) {
            return addr.address;
          }
        }
      }
    } catch (e) {
      debugPrint("Error getting IP address: $e");
    }
    return 'unknown';
  }

  static Future<http.Response?> authenticatedRequest(
    String url, {
    String method = 'GET',
    Map<String, String>? headers,
    dynamic body,
  }) async {
    try {
      // Update user activity on every request (prevents popup)
      SessionManager.updateUserActivity();
      
      // Ensure we have fresh tokens
      if (accessToken == null) {
        accessToken = await SessionManager.getAccessToken();
        refreshToken = await SessionManager.getRefreshToken();
        tokenExpiryTime = await SessionManager.getTokenExpiry();
      }
      
      final isValid = await checkAndRefreshToken();
      if (!isValid && accessToken == null) {
        debugPrint("No valid token available");
        return null;
      }

      final String authHeader = (_tokenPrefix?.isNotEmpty == true ? _tokenPrefix! : "SmartCare ") + (accessToken ?? "");
      
      final Map<String, String> requestHeaders = {
        'Content-Type': 'application/json',
        'Accept': 'application/json',
        if (accessToken != null) 'Authorization': authHeader,
        if (headers != null) ...headers,
      };

      http.Response? response;
      final uri = Uri.parse(url);

      switch (method.toUpperCase()) {
        case 'GET':
          response = await http.get(uri, headers: requestHeaders);
          break;
        case 'POST':
          response = await http.post(
            uri,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'PUT':
          response = await http.put(
            uri,
            headers: requestHeaders,
            body: body != null ? jsonEncode(body) : null,
          );
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: requestHeaders);
          break;
        default:
          throw Exception('Unsupported HTTP method: $method');
      }

      if (response.statusCode == 401) {
        debugPrint("Token expired, attempting refresh...");
        final refreshSuccess = await refreshUserToken();
        if (refreshSuccess && accessToken != null) {
          final newAuthHeader = (_tokenPrefix?.isNotEmpty == true ? _tokenPrefix! : "SmartCare ") + accessToken!;
          requestHeaders['Authorization'] = newAuthHeader;
          
          // Retry the request
          switch (method.toUpperCase()) {
            case 'GET':
              response = await http.get(uri, headers: requestHeaders);
              break;
            case 'POST':
              response = await http.post(
                uri,
                headers: requestHeaders,
                body: body != null ? jsonEncode(body) : null,
              );
              break;
            case 'PUT':
              response = await http.put(
                uri,
                headers: requestHeaders,
                body: body != null ? jsonEncode(body) : null,
              );
              break;
            case 'DELETE':
              response = await http.delete(uri, headers: requestHeaders);
              break;
          }
        }
      }

      return response;
    } catch (e) {
      debugPrint("Authenticated request error: $e");
      return null;
    }
  }
}