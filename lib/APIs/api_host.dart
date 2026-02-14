// lib/core/api/api_host.dart

class ApiHost {
  // Your LOCAL_DEV_9 from React config
  static const String host = 'test.smartcarehis.com';
  static const int port = 8443;
  static const int loginPort = 443;
  
  // Base URLs - similar to your React smHost, prHost, empHost
  static final String baseUrl = 'https://$host:$port/';
  static final String loginBaseUrl = 'https://$host:$loginPort/';
  
  // Different modules based on your Flutter services
  static final String smartcaremainUrl = '${baseUrl}smartcaremain/';
  static final String ipdUrl = '${baseUrl}ipd/';
  static final String billingUrl = '${baseUrl}billing/';
  static final String masterUrl = '${baseUrl}master/';
  
  // Helper method to generate URLs (like your React generateApiUrl)
  static String generateUrl(String host, String path) {
    return '$host$path';
  }
}