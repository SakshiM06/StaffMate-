import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/foundation.dart';

class ApiService {
  static const String baseUrl = "https://103.159.239.222:9090/sclyte";

  static Future<Map<String, dynamic>?> loginUser(
      String userName, String password) async {
    try {
      final url = Uri.parse("$baseUrl/login");

      final body = {
        "userName": userName.trim(), 
        "password": password.trim(),
      };

      debugPrint("Sending request to: $url");
      debugPrint("Body: $body");

      final response = await http.post(
        url,
        headers: const {
          "Content-Type": "application/json",
          "Accept": "application/json",
          "Access-Control-Allow-Origin": "*",
        },
        body: jsonEncode(body),
      );

      debugPrint("Status Code: ${response.statusCode}");
      debugPrint("Headers: ${response.headers}");
      debugPrint("Body: ${response.body}");

      // Handle redirect manually (302)
      if (response.statusCode == 302) {
        final location = response.headers['location'];
        debugPrint("Redirected to: $location");
        if (location != null) {
          final redirectedUrl = Uri.parse(location);
          final redirectedResponse = await http.post(
            redirectedUrl,
            headers: const {
              "Content-Type": "application/json",
              "Accept": "application/json",
            },
            body: jsonEncode(body),
          );
          debugPrint("Redirect Response Code: ${redirectedResponse.statusCode}");
          debugPrint("Redirect Body: ${redirectedResponse.body}");
          return jsonDecode(redirectedResponse.body);
        }
      }

      if (response.statusCode == 200) {
        return jsonDecode(response.body);
      } else {
        debugPrint("Login failed with status: ${response.statusCode}");
        return null;
      }
    } catch (e) {
      debugPrint("Error: $e");
      return null;
    }
  }
}
