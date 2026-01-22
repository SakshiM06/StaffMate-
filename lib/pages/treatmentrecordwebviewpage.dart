import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:http/http.dart' as storage;
import 'package:webview_flutter/webview_flutter.dart';
// import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:staff_mate/models/patient.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class TreatmentRecordWebViewPage extends StatefulWidget {
  final Patient patient;
  const TreatmentRecordWebViewPage({super.key, required this.patient});

  @override
  State<TreatmentRecordWebViewPage> createState() => _TreatmentRecordWebViewPageState();
}

class _TreatmentRecordWebViewPageState extends State<TreatmentRecordWebViewPage> {
  late WebViewController _webViewController;
  bool _isLoading = true;
  double _progress = 0;
  bool _loginAttempted = false;
  final storage = const FlutterSecureStorage();

  @override
  void initState() {
    super.initState();
    _initializeWebView();
  }

  void _initializeWebView() {
    _webViewController = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (String url) {
            setState(() {
              _isLoading = true;
            });
          },
          onProgress: (int progress) {
            setState(() {
              _progress = progress / 100;
              _isLoading = progress < 100;
            });
          },
          onPageFinished: (String url) async {
            setState(() {
              _isLoading = false;
            });

            // Check if we're on login page and attempt auto-login
            if (url.contains('login') && !_loginAttempted) {
              _loginAttempted = true;
              await _attemptAutoLogin();
            }
            
            // If we successfully navigated away from login, reload treatment records
            if (!url.contains('login') && _loginAttempted) {
              await Future.delayed(const Duration(seconds: 2));
              await _webViewController.loadRequest(Uri.parse(_treatmentRecordsUrl));
            }
          },
        ),
      )
      ..loadRequest(Uri.parse(_treatmentRecordsUrl));
  }

  // Direct treatment records URL
  String get _treatmentRecordsUrl {
    const baseUrl = "https://test.smartcarehis.com:8443/sclyte/patientTreatmentRecords";
    final admissionId = widget.patient.admissionId?.toString() ?? '';
    
    if (admissionId.isNotEmpty) {
      return '$baseUrl?admissionId=$admissionId';
    }
    return baseUrl;
  }

  // Login URL (if needed)
  String get _loginUrl {
    return "https://test.smartcarehis.com:8443/sclyte/login";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: Text(
          "Treatment Record - ${widget.patient.patientname}",
          style: GoogleFonts.poppins(fontSize: 16, fontWeight: FontWeight.w600),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        backgroundColor: const Color(0xFF1A237E),
        foregroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (_isLoading)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  value: _progress,
                  strokeWidth: 2,
                  valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              ),
            ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () {
              _loginAttempted = false;
              _webViewController.loadRequest(Uri.parse(_treatmentRecordsUrl));
            },
          ),
        ],
      ),
      body: WebViewWidget(controller: _webViewController),
    );
  }

  Future<void> _attemptAutoLogin() async {
    try {
      // Get saved credentials
      final username = await storage.read(key: 'web_username');
      final password = await storage.read(key: 'web_password');
      
      if (username != null && password != null) {
        final loginScript = '''
          // Wait for page to load
          setTimeout(function() {
            // Find login form elements
            const usernameField = document.querySelector('input[name="username"], input[name="email"], input[type="text"][placeholder*="user"], input[placeholder*="email"]');
            const passwordField = document.querySelector('input[name="password"], input[type="password"]');
            const submitButton = document.querySelector('button[type="submit"], input[type="submit"], button:contains("Login"), button:contains("Sign in")');
            
            if (usernameField && passwordField) {
              // Fill credentials
              usernameField.value = '$username';
              passwordField.value = '$password';
              
              // Trigger input events
              usernameField.dispatchEvent(new Event('input', { bubbles: true }));
              passwordField.dispatchEvent(new Event('input', { bubbles: true }));
              
              // Submit form
              if (submitButton) {
                submitButton.click();
              } else {
                // Try to submit the form directly
                const form = usernameField.closest('form');
                if (form) form.submit();
              }
            }
          }, 2000);
        ''';
        
        await Future.delayed(const Duration(seconds: 1));
        await _webViewController.runJavaScript(loginScript);
      } else {
        // No saved credentials - show message
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Please login manually'),
              duration: Duration(seconds: 3),
            ),
          );
        }
      }
    } catch (e) {
      debugPrint('Auto-login error: $e');
    }
  }
}