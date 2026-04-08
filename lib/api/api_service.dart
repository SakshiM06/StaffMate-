import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';
import 'package:staff_mate/services/session_manger.dart';
import 'package:pointycastle/export.dart';

class ApiService {
  static const String baseUrl =
      "https://test.smartcarehis.com:8443/security/auth/login";
  static const String refreshUrl =
      "https://test.smartcarehis.com:8443/security/auth/refresh";

  static String? accessToken;
  static String? refreshToken;
  static DateTime? tokenExpiryTime;
  static String? _tokenPrefix;
  static Timer? _autoRefreshTimer;

  static const String _cryptoJSPassphrase = 'sclyte_security';

  static String _encryptCryptoJS(String plainText) {
    try {
      final salt = _secureRandomBytes(8);
      final derived = _evpBytesToKey(
        Uint8List.fromList(utf8.encode(_cryptoJSPassphrase)),
        salt,
      );
      final key = derived.sublist(0, 32);
      final iv  = derived.sublist(32, 48);
      final plainBytes  = Uint8List.fromList(utf8.encode(plainText));
      final paddedBytes = _pkcs7Pad(plainBytes);
      final cipher = CBCBlockCipher(AESEngine())
        ..init(
          true,
          ParametersWithIV(
            KeyParameter(Uint8List.fromList(key)),
            Uint8List.fromList(iv),
          ),
        );
      final cipherBytes = Uint8List(paddedBytes.length);
      for (var off = 0; off < paddedBytes.length; off += 16) {
        cipher.processBlock(paddedBytes, off, cipherBytes, off);
      }
      final out = Uint8List(16 + cipherBytes.length);
      out.setRange(0,  8,  utf8.encode('Salted__'));
      out.setRange(8,  16, salt);
      out.setRange(16, out.length, cipherBytes);

      final encoded = base64.encode(out);
      debugPrint('✅ Encrypted "$plainText" → $encoded');
      return encoded;
    } catch (e, st) {
      debugPrint('🔴 Encryption failed: $e\n$st');
      return plainText;
    }
  }

  static Uint8List _evpBytesToKey(Uint8List password, Uint8List salt) {
    final out = <int>[];
    var prev = Uint8List(0);
    while (out.length < 48) {
      final md5 = MD5Digest();
      final input = Uint8List.fromList([...prev, ...password, ...salt]);
      final hash  = Uint8List(md5.digestSize);
      md5.update(input, 0, input.length);
      md5.doFinal(hash, 0);
      out.addAll(hash);
      prev = hash;
    }
    return Uint8List.fromList(out);
  }

  static Uint8List _secureRandomBytes(int n) {
    final rng = Random.secure();
    return Uint8List.fromList(List.generate(n, (_) => rng.nextInt(256)));
  }

  static Uint8List _pkcs7Pad(Uint8List data) {
    final pad = 16 - (data.length % 16);
    return Uint8List.fromList([...data, ...List.filled(pad, pad)]);
  }

  // ── Login ───────────────────────────────────────────────────────────────────
  static Future<Map<String, dynamic>?> loginUser(
      String userName, String password) async {
    try {
      final encryptedUsername = _encryptCryptoJS(userName.trim());
      final encryptedPassword  = _encryptCryptoJS(password.trim());

      final body = {
        "userName":   encryptedUsername,
        "password":   encryptedPassword,
        "forceLogin": false,
        "remoteAddr": "test.smartcarehis.com",
      };

      debugPrint("📤 Sending login request to: $baseUrl");
      debugPrint("📤 Encrypted username: $encryptedUsername");

      final response = await http.post(
        Uri.parse(baseUrl),
        headers: const {"Content-Type": "application/json"},
        body: jsonEncode(body),
      );

      debugPrint("📥 Status Code: ${response.statusCode}");
      debugPrint("📥 Body: ${response.body}");

      if (response.statusCode == 200) {
        final responseData = jsonDecode(response.body) as Map<String, dynamic>;

        await _extractAndStoreTokens(response.headers, responseData);

        await SessionManager.saveTokens(
          accessToken: accessToken,
          refreshToken: refreshToken,
          expiryTime: tokenExpiryTime,
        );

        final data = responseData['data'];
        if (data != null) {
          await SessionManager.saveSession(
            bearer: data['bearer'] ?? '',
            token:  data['token']  ?? '',
            clinicId: data['clinicid'] ?? '',
            subscriptionRemainingDays: data['subscription_remaining_days'] ?? 0,
            userId:   data['userId']   ?? '',
            zoneid:   data['zoneid']   ?? '',
            expiryTime: data['expirytime'] ?? '',
            branchId:   1,
            refreshToken: refreshToken,
            tokenExpiry:  tokenExpiryTime,
          );
        }

        _startAutoRefreshTimer();
        return responseData;
      } else {
        debugPrint("❌ Login failed — status: ${response.statusCode}");
        debugPrint("❌ Body: ${response.body}");
        return null;
      }
    } catch (e) {
      debugPrint("❌ Login error: $e");
      return null;
    }
  }

  // ── Token Extraction ────────────────────────────────────────────────────────
  static Future<void> _extractAndStoreTokens(
      Map<String, String> headers,
      Map<String, dynamic> responseData) async {
    final data = responseData['data'];
    if (data == null) return;

    _tokenPrefix  = data['bearer']       ?? "SmartCare ";
    accessToken   = data['token']        ?? data['accessToken'];
    refreshToken  = data['refreshToken'] ?? data['refresh_token'];

    if (data['expirytime'] != null) {
      try {
        tokenExpiryTime = DateTime.parse(
          (data['expirytime'] as String).replaceFirst(' ', 'T'),
        );
      } catch (_) {
        tokenExpiryTime = DateTime.now().add(const Duration(minutes: 15));
      }
    }

    debugPrint("✅ Access token: ${accessToken != null ? '${accessToken!.substring(0, min(20, accessToken!.length))}...' : 'null'}");
    debugPrint("✅ Expiry: $tokenExpiryTime");
  }

  // ── Auto Refresh Timer ──────────────────────────────────────────────────────
  static void _startAutoRefreshTimer() {
    _autoRefreshTimer?.cancel();
    if (tokenExpiryTime == null) return;

    final timeUntilExpiry = tokenExpiryTime!.difference(DateTime.now());
    final refreshDelay    = timeUntilExpiry.inSeconds - 120; 

    if (refreshDelay > 0) {
      debugPrint("⏰ Auto-refresh scheduled in $refreshDelay s");
      _autoRefreshTimer = Timer(Duration(seconds: refreshDelay), refreshUserToken);
    } else if (timeUntilExpiry.inSeconds > 0) {
      debugPrint("⚠️ Token expiring very soon — refreshing now");
      refreshUserToken();
    }
  }

  // ── Token Helpers ───────────────────────────────────────────────────────────
  static bool isTokenExpired(String token) {
    try {
      final parts = token.split('.');
      if (parts.length == 3) {
        final payload = jsonDecode(
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1]))),
        );
        return DateTime.now().isAfter(
          DateTime.fromMillisecondsSinceEpoch((payload['exp'] as int) * 1000),
        );
      }
    } catch (e) {
      debugPrint("⚠️ Token decode error: $e");
    }
    return false;
  }

  static Future<bool> refreshUserToken() async {
    try {
      debugPrint("======= REFRESH TOKEN =======");

      refreshToken    ??= await SessionManager.getRefreshToken();
      accessToken     ??= await SessionManager.getAccessToken();
      tokenExpiryTime ??= await SessionManager.getTokenExpiry();

      if (refreshToken?.isEmpty ?? true) {
        debugPrint("❌ No refresh token");
        return false;
      }

      final response = await http.post(
        Uri.parse(refreshUrl),
        headers: const {
          "Content-Type": "application/json",
          "Accept":        "application/json",
        },
        body: jsonEncode({
          "refereshToken": refreshToken, 
          "remoteAddr":    "test.smartcarehis.com",
        }),
      ).timeout(const Duration(minutes: 15));

      debugPrint("📥 Refresh status: ${response.statusCode}");

      if (response.statusCode == 200) {
        final newData = (jsonDecode(response.body) as Map<String, dynamic>)['data'];
        if (newData != null) {
          if (newData['bearer']       != null) _tokenPrefix = newData['bearer'];
          if (newData['token']        != null) accessToken  = newData['token'];
          if (newData['refreshToken'] != null) refreshToken = newData['refreshToken'];
          if (newData['expirytime']   != null) {
            try {
              tokenExpiryTime = DateTime.parse(
                (newData['expirytime'] as String).replaceFirst(' ', 'T'),
              );
            } catch (_) {
              tokenExpiryTime = DateTime.now().add(const Duration(minutes: 15));
            }
          }

          await SessionManager.saveTokens(
            accessToken:  accessToken,
            refreshToken: refreshToken,
            expiryTime:   tokenExpiryTime,
          );

          debugPrint("✅ Token refreshed. New expiry: $tokenExpiryTime");
          _startAutoRefreshTimer();
          SessionManager.updateUserActivity();
          return true;
        }
      }

      debugPrint("❌ Refresh failed: ${response.statusCode}");
      return false;
    } catch (e) {
      debugPrint("❌ Refresh error: $e");
      return false;
    }
  }

  static Future<bool> checkAndRefreshToken() async {
    if (tokenExpiryTime != null && accessToken != null) {
      final remaining = tokenExpiryTime!.difference(DateTime.now());
      if (remaining.inMinutes < 15) {
        SessionManager.updateUserActivity();
        return await refreshUserToken();
      }
      return true;
    }
    return false;
  }

  static void updateUserActivity() => SessionManager.updateUserActivity();

  static void clearSession() {
    accessToken     = null;
    refreshToken    = null;
    tokenExpiryTime = null;
    _tokenPrefix    = null;
    _autoRefreshTimer?.cancel();
    debugPrint("🧹 Session cleared");
  }

  // ── Authenticated Request ───────────────────────────────────────────────────
  static Future<http.Response?> authenticatedRequest(
    String url, {
    String method = 'GET',
    Map<String, String>? headers,
    dynamic body,
  }) async {
    try {
      SessionManager.updateUserActivity();

      accessToken     ??= await SessionManager.getAccessToken();
      refreshToken    ??= await SessionManager.getRefreshToken();
      tokenExpiryTime ??= await SessionManager.getTokenExpiry();

      final isValid = await checkAndRefreshToken();
      if (!isValid && accessToken == null) {
        debugPrint("❌ No valid token");
        return null;
      }

      final authHeader = (_tokenPrefix?.isNotEmpty == true
              ? _tokenPrefix!
              : "SmartCare ") +
          (accessToken ?? "");

      final requestHeaders = <String, String>{
        'Content-Type':  'application/json',
        'Accept':        'application/json',
        'Authorization': authHeader,
        if (headers != null) ...headers,
      };

      var response = await _makeRequest(method, Uri.parse(url), requestHeaders, body);

      // Retry once on 401
      if (response?.statusCode == 401) {
        debugPrint("⚠️ 401 — refreshing and retrying");
        if (await refreshUserToken() && accessToken != null) {
          requestHeaders['Authorization'] =
              (_tokenPrefix?.isNotEmpty == true ? _tokenPrefix! : "SmartCare ") +
                  accessToken!;
          response = await _makeRequest(method, Uri.parse(url), requestHeaders, body);
        }
      }

      return response;
    } catch (e) {
      debugPrint("❌ Request error: $e");
      return null;
    }
  }

  static Future<http.Response?> _makeRequest(
    String method, Uri uri, Map<String, String> headers, dynamic body) async {
    final encoded = body != null ? jsonEncode(body) : null;
    switch (method.toUpperCase()) {
      case 'GET':    return http.get(uri, headers: headers);
      case 'POST':   return http.post(uri,   headers: headers, body: encoded);
      case 'PUT':    return http.put(uri,    headers: headers, body: encoded);
      case 'DELETE': return http.delete(uri, headers: headers);
      default: throw Exception('Unsupported HTTP method: $method');
    }
  }
}