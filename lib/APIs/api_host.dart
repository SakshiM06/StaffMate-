// --------------------- Host Configuration ---------------------
class ApiHost {
  // Host mappings - exactly like your React HOSTS object
  static const Map<String, String> HOSTS = {
    'TEST_SERVER': '103.159.239.203',
    'SM_222': '103.159.239.222',
    'SM_139': '139.162.51.34',
    'New_Life': '192.168.29.49',
    'Aureus': '172.16.0.10',
    'Aureus_Static': '117.236.139.98',
    'RKH': '103.215.164.99',
    'RKH_LOCAL': '10.0.16.2',
    'RKH_NEW': '203.194.107.6',
    'BTGH': '103.188.18.211',
    'ABDM_222': 'saas.smartcarehis.com',
    'SECURITY_TEST': 'test.smartcarehis.com',
    'LMH_LIVE': '172.24.1.10',
    'HRMS': 'localhost',
    'NEW_SERVER': '94.136.188.27',
    'LMH_Static': '49.248.253.211',
    'LOCAL_DEV_1': '192.168.0.121',
    'LOCAL_DEV_2': '192.168.0.175',
    'LOCAL_DEV_3': '192.168.0.154',
    'LOCAL_DEV_4': '192.168.0.194',
    'LOCAL_DEV_5': '192.168.0.179',
    'LOCAL_DEV_6': '192.168.1.3',
    'LOCAL_DEV_7': '192.168.1.12',
    'LOCAL_DEV_8': '192.168.1.38',
  };

  // --------------------- Active Configuration ---------------------
  // Change this to switch environments (like CURRENT_KEY in React)
  static const String CURRENT_KEY = 'SECURITY_TEST'; // Use test.smartcarehis.com for production
  
  // Protocol and ports
  static const String PROTOCOL = 'https';
  static const int SAM_PORT = 9091;
  static const int IPD_PORT = 8443;
  static const int LOGIN_PORT = 443;
  static const int SMART_CARE_PORT = 9090; // For SMARTCARE/ endpoints

  // --------------------- Computed Properties ---------------------
  /// Get the active host based on CURRENT_KEY
  static String get activeHost => HOSTS[CURRENT_KEY] ?? HOSTS['SECURITY_TEST']!;

  // --------------------- Base URLs ---------------------
  /// Base URL for SAM APIs (port 9091)
  static String get baseUrl => '$PROTOCOL://$activeHost:$IPD_PORT/';
    /// Base URL for login (port 443)
    static String get loginBaseUrl => '$PROTOCOL://$activeHost:$LOGIN_PORT/';
  /// Base URL for IPD module (port 8443) - matches your Flutter code
  static String get ipdBaseUrl => '$PROTOCOL://$activeHost:$IPD_PORT/';
  /// SmartCare Main URL (port 9090/SMARTCARE/) - matches your React MAINDASHBOARDLINKSHOST
  static String get smartcareMainUrl => '$PROTOCOL://$activeHost:9090/SMARTCARE/';
  
  /// Billing URL
  static String get billingUrl => '$PROTOCOL://$activeHost:$SAM_PORT/billing/';
  
  /// Master URL
  static String get masterUrl => '$PROTOCOL://$activeHost:$SAM_PORT/master/';

  // --------------------- Utility Method ---------------------
  /// Build URL with path (like your React generateApiUrl)
  static String buildUrl(String base, String path) {
    final cleanBase = base.replaceAll(RegExp(r'/+$'), '');
    final cleanPath = path.replaceAll(RegExp(r'^/+'), '');
    return '$cleanBase/$cleanPath';
  }

  // --------------------- Debug Helper ---------------------
  static void printConfig() {
    // ignore: avoid_print
    print('''
    ════════════════════════════════════
        API HOST CONFIGURATION
    ════════════════════════════════════
    Current Key : $CURRENT_KEY
    Active Host : $activeHost
    Protocol    : $PROTOCOL  
    Base URL    : $baseUrl
    IPD Base URL: $ipdBaseUrl
    Login URL   : $loginBaseUrl
    SmartCare   : $smartcareMainUrl
    ════════════════════════════════════
    ''');
  }
}