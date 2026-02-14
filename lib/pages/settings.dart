import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

ValueNotifier<double> fontSizeNotifier = ValueNotifier<double>(16.0);
ValueNotifier<bool> darkModeNotifier = ValueNotifier<bool>(false);

Future<void> updateAppFontSize(double newFontSize) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setDouble('fontSize', newFontSize);
  fontSizeNotifier.value = newFontSize;
}

Future<void> updateAppTheme(bool isDarkMode) async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.setBool('darkMode', isDarkMode);
  darkModeNotifier.value = isDarkMode;
}

class _SettingsPageState extends State<SettingsPage> {
  double _fontSize = 16.0;
  double _tempFontSize = 16.0; 
  static const double _minFontSize = 12.0;
  static const double _maxFontSize = 24.0;
  bool _fontSizeChanged = false;
  
  Color _selectedColor = const Color(0xFF1A237E);
  final List<Color> _colorOptions = [
    const Color(0xFF1A237E), 
    const Color(0xFF283593), 
    const Color(0xFF00C897), 
    const Color(0xFF66D7EE), 
    const Color(0xFFE53935), 
    Colors.purple,
    Colors.green,
  ];
  
  bool _isDarkMode = false;
  bool _enableBiometric = false;
  bool _enableFaceID = false;
  String _appLockTimeout = "30 minutes";
  final List<String> _timeoutOptions = [
    "Immediately",
    "1 minute",
    "5 minutes",
    "15 minutes",
    "30 minutes",
    "1 hour",
    "Never"
  ];
  
  @override
  void initState() {
    super.initState();
    _loadSettings();
    
    darkModeNotifier.addListener(_onThemeChanged);
  }
  
  @override
  void dispose() {
    darkModeNotifier.removeListener(_onThemeChanged);
    super.dispose();
  }
  
  void _onThemeChanged() {
    if (mounted) {
      setState(() {
        _isDarkMode = darkModeNotifier.value;
      });
    }
  }
  
  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _fontSize = fontSizeNotifier.value;
      _tempFontSize = _fontSize;
      _isDarkMode = darkModeNotifier.value;
      final colorValue = prefs.getInt('themeColor') ?? 0xFF1A237E;
      _selectedColor = Color(colorValue);
      _enableBiometric = prefs.getBool('enableBiometric') ?? false;
      _enableFaceID = prefs.getBool('enableFaceID') ?? false;
      _appLockTimeout = prefs.getString('appLockTimeout') ?? "30 minutes";
    });
  }
  
  Future<void> _saveFontSize() async {
    await updateAppFontSize(_fontSize);
    setState(() {
      _fontSizeChanged = false;
    });
    
    _showSnackBar('Font size updated to ${_fontSize.toInt()}px');
  }
  
  Future<void> _saveThemeMode() async {
    await updateAppTheme(_isDarkMode);
    _showSnackBar('Theme changed to ${_isDarkMode ? 'Dark' : 'Light'} mode');
  }
  
  Future<void> _saveThemeColor() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('themeColor', _selectedColor.value);
  }
  
  Future<void> _saveBiometricSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('enableBiometric', _enableBiometric);
    await prefs.setBool('enableFaceID', _enableFaceID);
    await prefs.setString('appLockTimeout', _appLockTimeout);
    
    _showSnackBar('Security settings updated');
  }
  
  void _showSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFF1A237E),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 2),
      ),
    );
  }
  
  Color _getBackgroundColor() {
    return _isDarkMode ? const Color(0xFF121212) : const Color(0xFFF5F7FA);
  }
  
  Color _getCardColor() {
    return _isDarkMode ? const Color(0xFF1E1E1E) : Colors.white;
  }
  
  Color _getTextColor() {
    return _isDarkMode ? Colors.white : const Color(0xFF1A237E);
  }
  
  Color _getBodyTextColor() {
    return _isDarkMode ? const Color(0xFFB0BEC5) : const Color(0xFF90A4AE);
  }
  
  Color _getWarningColor() {
    return _isDarkMode ? Colors.orange.shade300 : Colors.orange.shade700;
  }
  
  void _showTimeoutDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: _getCardColor(),
          title: Text(
            'Select App Lock Timeout',
            style: TextStyle(
              color: _getTextColor(),
              fontWeight: FontWeight.bold,
            ),
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: _timeoutOptions.length,
              itemBuilder: (context, index) {
                final option = _timeoutOptions[index];
                return ListTile(
                  title: Text(
                    option,
                    style: TextStyle(
                      color: _getTextColor(),
                    ),
                  ),
                  trailing: _appLockTimeout == option
                      ? Icon(Icons.check, color: _selectedColor)
                      : null,
                  onTap: () {
                    setState(() {
                      _appLockTimeout = option;
                    });
                    _saveBiometricSettings();
                    Navigator.pop(context);
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(color: _getBodyTextColor()),
              ),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Settings',
          style: TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
        backgroundColor: _selectedColor,
        elevation: 4,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: Container(
        color: _getBackgroundColor(),
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            // _buildSectionHeader("4.1 Appearance"),
            
            
            _buildSettingCard(
              icon: Icons.format_size_rounded,
              title: 'Font Size',
              subtitle: 'Adjust text size for entire app',
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    decoration: BoxDecoration(
                      color: _selectedColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Current Size:',
                          style: TextStyle(
                            fontSize: 14,
                            color: _getBodyTextColor(),
                          ),
                        ),
                        Text(
                          '${_tempFontSize.toInt()} px',
                          style: TextStyle(
                            fontSize: _tempFontSize,
                            color: _getTextColor(),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                  
                  const SizedBox(height: 10),
                  
                  Row(
                    children: [
                      IconButton(
                        onPressed: () {
                          if (_tempFontSize > _minFontSize) {
                            setState(() {
                              _tempFontSize -= 1;
                              _fontSizeChanged = true;
                            });
                          }
                        },
                        icon: Icon(
                          Icons.remove,
                          color: _selectedColor,
                          size: 20,
                        ),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        tooltip: 'Decrease',
                      ),
                      
                      Expanded(
                        child: Slider(
                          value: _tempFontSize,
                          min: _minFontSize,
                          max: _maxFontSize,
                          divisions: 12,
                          label: '${_tempFontSize.toInt()}px',
                          activeColor: _selectedColor,
                          inactiveColor: _isDarkMode ? Colors.grey[700] : Colors.grey[300],
                          onChanged: (value) {
                            setState(() {
                              _tempFontSize = value;
                              _fontSizeChanged = true;
                            });
                          },
                        ),
                      ),
                      
                      IconButton(
                        onPressed: () {
                          if (_tempFontSize < _maxFontSize) {
                            setState(() {
                              _tempFontSize += 1;
                              _fontSizeChanged = true;
                            });
                          }
                        },
                        icon: Icon(
                          Icons.add,
                          color: _selectedColor,
                          size: 20,
                        ),
                        padding: const EdgeInsets.all(6),
                        constraints: const BoxConstraints(),
                        tooltip: 'Increase',
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 6),
                  
                  // Size labels
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Small',
                        style: TextStyle(
                          fontSize: 10,
                          color: _getBodyTextColor(),
                        ),
                      ),
                      Text(
                        'Medium',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getBodyTextColor(),
                        ),
                      ),
                      Text(
                        'Large',
                        style: TextStyle(
                          fontSize: 14,
                          color: _getBodyTextColor(),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Save button for font size
                  if (_fontSizeChanged)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () {
                          setState(() {
                            _fontSize = _tempFontSize;
                          });
                          _saveFontSize();
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: _selectedColor,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(8),
                          ),
                          elevation: 2,
                        ),
                        child: const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.check, size: 18),
                            SizedBox(width: 8),
                            Text('Save Font Size'),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // Dark/Light Theme Setting
            _buildSettingCard(
              icon: _isDarkMode ? Icons.dark_mode_rounded : Icons.light_mode_rounded,
              title: 'App Theme',
              subtitle: 'Switch between dark and light mode (Applies to entire app)',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _isDarkMode ? 'Dark Mode' : 'Light Mode',
                              style: TextStyle(
                                color: _getTextColor(),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _isDarkMode 
                                  ? 'Easier on eyes in low light' 
                                  : 'Clear visibility in bright light',
                              style: TextStyle(
                                color: _getBodyTextColor(),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _isDarkMode,
                        activeColor: _selectedColor,
                        inactiveTrackColor: _isDarkMode ? Colors.grey[700] : Colors.grey[300],
                        onChanged: (value) {
                          setState(() {
                            _isDarkMode = value;
                          });
                          _saveThemeMode();
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _selectedColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, size: 16, color: _selectedColor),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Theme change applies immediately to entire application',
                            style: TextStyle(
                              fontSize: 11,
                              color: _getBodyTextColor(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // // Color Theme Setting (Commented but visible)
            // _buildSettingCard(
            //   icon: Icons.color_lens_rounded,
            //   title: 'Color Theme',
            //   subtitle: 'Choose your preferred accent color',
            //   child: Column(
            //     crossAxisAlignment: CrossAxisAlignment.start,
            //     children: [
            //       Text(
            //         'Feature Coming Soon',
            //         style: TextStyle(
            //           color: _getBodyTextColor(),
            //           fontSize: 12,
            //           fontStyle: FontStyle.italic,
            //         ),
            //       ),
            //       const SizedBox(height: 8),
            //       Wrap(
            //         spacing: 8,
            //         runSpacing: 8,
            //         children: _colorOptions.map((color) {
            //           return Container(
            //             width: 40,
            //             height: 40,
            //             decoration: BoxDecoration(
            //               color: color,
            //               shape: BoxShape.circle,
            //               border: Border.all(
            //                 color: _selectedColor == color 
            //                     ? Colors.white 
            //                     : Colors.transparent,
            //                 width: 2,
            //               ),
            //             ),
            //             child: _selectedColor == color
            //                 ? const Icon(Icons.check, color: Colors.white, size: 18)
            //                 : null,
            //           );
            //         }).toList(),
            //       ),
            //       const SizedBox(height: 8),
            //       Text(
            //         'This feature will allow you to customize the primary color of the app',
            //         style: TextStyle(
            //           color: _getBodyTextColor(),
            //           fontSize: 11,
            //         ),
            //       ),
            //     ],
            //   ),
            // ),
            
            const SizedBox(height: 20),
            
            // Section: 4.2 Security
            // _buildSectionHeader("4.2 Security"),
            
            // Biometric Authentication
            _buildSettingCard(
              icon: Icons.fingerprint_rounded,
              title: 'Biometric Authentication',
              subtitle: 'Enable fingerprint or device biometrics',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Enable Biometric Login',
                              style: TextStyle(
                                color: _getTextColor(),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Use fingerprint or device biometrics for quick login',
                              style: TextStyle(
                                color: _getBodyTextColor(),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch(
                        value: _enableBiometric,
                        activeColor: _selectedColor,
                        inactiveTrackColor: _isDarkMode ? Colors.grey[700] : Colors.grey[300],
                        onChanged: (value) {
                          setState(() {
                            _enableBiometric = value;
                          });
                          _saveBiometricSettings();
                        },
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 12),
                  
                  // Face ID / Face Authentication (only if biometric is enabled)
                  if (_enableBiometric)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(Icons.face_retouching_natural, 
                                        size: 18, 
                                        color: _getBodyTextColor(),
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Enable Face ID / Face Authentication',
                                        style: TextStyle(
                                          color: _getTextColor(),
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Padding(
                                    padding: const EdgeInsets.only(left: 24.0),
                                    child: Text(
                                      'Use facial recognition for authentication',
                                      style: TextStyle(
                                        color: _getBodyTextColor(),
                                        fontSize: 12,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch(
                              value: _enableFaceID,
                              activeColor: _selectedColor,
                              inactiveTrackColor: _isDarkMode ? Colors.grey[700] : Colors.grey[300],
                              onChanged: (value) {
                                setState(() {
                                  _enableFaceID = value;
                                });
                                _saveBiometricSettings();
                              },
                            ),
                          ],
                        ),
                        
                        const SizedBox(height: 8),
                        
                        // Info message about biometrics
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: _selectedColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.info_outline, 
                                size: 18, 
                                color: _selectedColor,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Biometric settings will be used on the login screen. '
                                  'Make sure your device supports biometric authentication.',
                                  style: TextStyle(
                                    color: _getBodyTextColor(),
                                    fontSize: 11,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 12),
            
            // App Lock Timeout
            _buildSettingCard(
              icon: Icons.lock_clock_rounded,
              title: 'App Lock Timeout',
              subtitle: 'Set when the app should automatically lock',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Auto Lock Time',
                              style: TextStyle(
                                color: _getTextColor(),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Lock app after period of inactivity',
                              style: TextStyle(
                                color: _getBodyTextColor(),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      InkWell(
                        onTap: _showTimeoutDialog,
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          decoration: BoxDecoration(
                            color: _selectedColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _selectedColor.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            children: [
                              Text(
                                _appLockTimeout,
                                style: TextStyle(
                                  color: _getTextColor(),
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Icon(
                                Icons.arrow_drop_down,
                                color: _getBodyTextColor(),
                                size: 20,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Description of current timeout
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _isDarkMode ? Colors.grey[800] : Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _appLockTimeout == "Immediately" 
                        ? 'App will lock immediately when minimized'
                        : _appLockTimeout == "Never"
                          ? 'App will never auto-lock (less secure)'
                          : 'App will lock after $_appLockTimeout of inactivity',
                      style: TextStyle(
                        color: _getBodyTextColor(),
                        fontSize: 12,
                      ),
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  // Security warning for "Never" option
                  if (_appLockTimeout == "Never")
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: _getWarningColor().withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                          color: _getWarningColor().withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded, 
                            size: 18, 
                            color: _getWarningColor(),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Warning: Disabling auto-lock reduces app security. '
                              'Anyone with access to your device can open the app.',
                              style: TextStyle(
                                color: _getWarningColor(),
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
            
            const SizedBox(height: 24),
            
            // Apply All Changes Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  // Save any pending font size changes
                  if (_fontSizeChanged) {
                    setState(() {
                      _fontSize = _tempFontSize;
                      _fontSizeChanged = false;
                    });
                    await _saveFontSize();
                  }
                  
                  // Save all other settings
                  await _saveThemeMode();
                  await _saveBiometricSettings();
                  
                  _showSnackBar('All settings applied successfully');
                },
                icon: const Icon(Icons.save_rounded, size: 20),
                label: const Text('Apply All Changes'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedColor,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
              ),
            ),
            
            const SizedBox(height: 16),
            
            // Reset Settings Button
            Center(
              child: ElevatedButton.icon(
                onPressed: () async {
                  showDialog(
                    context: context,
                    builder: (context) => AlertDialog(
                      backgroundColor: _getCardColor(),
                      title: Text(
                        'Reset Settings',
                        style: TextStyle(
                          color: _getTextColor(),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      content: Text(
                        'Are you sure you want to reset all settings to default?',
                        style: TextStyle(
                          color: _getBodyTextColor(),
                        ),
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: Text(
                            'Cancel',
                            style: TextStyle(color: _getBodyTextColor()),
                          ),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(context);
                            final prefs = await SharedPreferences.getInstance();
                            await prefs.clear();
                            
                            // Reset global notifiers
                            fontSizeNotifier.value = 16.0;
                            darkModeNotifier.value = false;
                            
                            _loadSettings();
                            _showSnackBar('All settings reset to default');
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: const Color(0xFFE53935),
                            foregroundColor: Colors.white,
                          ),
                          child: const Text('Reset'),
                        ),
                      ],
                    ),
                  );
                },
                icon: const Icon(Icons.restart_alt_rounded, size: 20),
                label: const Text('Reset to Default'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isDarkMode ? Colors.grey[700] : Colors.grey[300],
                  foregroundColor: _getTextColor(),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 14,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Text(
        title,
        style: TextStyle(
          color: _selectedColor,
          fontSize: 18,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }
  
  Widget _buildSettingCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Widget child,
  }) {
    return Card(
      elevation: 2,
      color: _getCardColor(),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _selectedColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    color: _selectedColor,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: TextStyle(
                          color: _getTextColor(),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        subtitle,
                        style: TextStyle(
                          color: _getBodyTextColor(),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            const Divider(
              height: 1,
              color: Color(0xFFE0E0E0),
            ),
            const SizedBox(height: 12),
            child,
          ],
        ),
      ),
    );
  }
}