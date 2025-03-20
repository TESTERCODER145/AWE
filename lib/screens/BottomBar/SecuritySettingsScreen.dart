import 'package:downloadsplatform/screens/HomeScreen.dart';
import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AppLifecycleObserver with WidgetsBindingObserver {
  final BuildContext context;
  bool _wasInBackground = false;

  AppLifecycleObserver(this.context) {
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
        _wasInBackground = true;
        break;
      case AppLifecycleState.resumed:
        if (_wasInBackground) {
          _wasInBackground = false;
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => LockScreen(
                child: HomeScreen(),
              ),
            ),
          );
        }
        break;
      default:
        break;
    }
  }

  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
  }
}

class LockScreen extends StatefulWidget {
  final Widget child;
  const LockScreen({Key? key, required this.child}) : super(key: key);

  @override
  _LockScreenState createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  bool _isAuthenticated = false;
  String _password = '';
  late AppLifecycleObserver _lifecycleObserver;

  Future<bool> _checkFingerprintSupport() async {
    try {
      final biometrics = await _localAuth.getAvailableBiometrics();
      print('[DEBUG] Available biometrics: $biometrics');
      return biometrics.contains(BiometricType.fingerprint) ||
          biometrics.contains(BiometricType.strong);
    } catch (e) {
      print('Error checking biometrics: $e');
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _lifecycleObserver = AppLifecycleObserver(context);
    _checkAuthenticationStatus();
  }

  @override
  void dispose() {
    _lifecycleObserver.dispose();
    super.dispose();
  }

  Future<void> _checkAuthenticationStatus() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isLockEnabled = prefs.getBool('isLockEnabled') ?? false;

      if (!isLockEnabled) {
        setState(() => _isAuthenticated = true);
        return;
      }
      final hasPassword = await _storage.containsKey(key: 'app_password');
      if (!hasPassword) {
        setState(() => _isAuthenticated = true);
        return;
      }
      _showAuthenticationDialog();
    } catch (e) {
      print('Error checking auth status: $e');
      setState(() => _isAuthenticated = true);
    }
  }

  Future<bool> _authenticateWithBiometrics() async {
    try {
      if (!await _checkFingerprintSupport()) return false;

      return await _localAuth.authenticate(
        localizedReason: 'قم بإدخال البصمة للمتابعة',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      print('Biometric auth error: $e');
      return false;
    }
  }

  Future<bool> _verifyPassword(String password) async {
    try {
      final storedPassword = await _storage.read(key: 'app_password');
      return password == storedPassword;
    } catch (e) {
      print('Password verification error: $e');
      return false;
    }
  }

  void _showAuthenticationDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('تسجيل الدخول'),
        content: StatefulBuilder(
          builder: (context, setState) => Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                decoration: const InputDecoration(
                  labelText: 'كلمة المرور',
                ),
                obscureText: true,
                keyboardType: TextInputType.number,
                onChanged: (value) => _password = value,
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  if (await _verifyPassword(_password)) {
                    Navigator.pop(context);
                    setState(() => _isAuthenticated = true);
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('كلمة المرور غير صحيحة')),
                    );
                  }
                },
                child: const Text('تأكيد'),
              ),
              FutureBuilder<bool>(
                future: _checkFingerprintSupport(),
                builder: (context, snapshot) {
                  if (snapshot.hasData && snapshot.data!) {
                    return Column(
                      children: [
                        const SizedBox(height: 16),
                        ElevatedButton.icon(
                          icon: const Icon(Icons.fingerprint),
                          label: const Text('استخدام البصمة'),
                          onPressed: () async {
                            if (await _authenticateWithBiometrics()) {
                              Navigator.pop(context);
                              setState(() => _isAuthenticated = true);
                            }
                          },
                        ),
                      ],
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return _isAuthenticated ? widget.child : Scaffold(
      body: Center(
        child: HomeScreen(),
      ),
    );
  }
}

class SecuritySettings extends StatefulWidget {
  const SecuritySettings({Key? key}) : super(key: key);

  @override
  _SecuritySettingsState createState() => _SecuritySettingsState();
}

class _SecuritySettingsState extends State<SecuritySettings> {
  final LocalAuthentication _localAuth = LocalAuthentication();
  final _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
  );
  bool _isBiometricAvailable = false;
  bool _isPasswordEnabled = false;

  Future<bool> _checkFingerprintSupport() async {
    try {
      final biometrics = await _localAuth.getAvailableBiometrics();
      print('[DEBUG] Available biometrics: $biometrics');
      return biometrics.contains(BiometricType.fingerprint) ||
          biometrics.contains(BiometricType.strong);
    } catch (e) {
      print('Error checking biometrics: $e');
      return false;
    }
  }

  @override
  void initState() {
    super.initState();
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    try {
      final hasPassword = await _storage.containsKey(key: 'app_password');

      setState(() async{
        _isBiometricAvailable = await _checkFingerprintSupport();
        _isPasswordEnabled = hasPassword;
      });
    } catch (e) {
      print('Error loading settings: $e');
    }
  }

  Future<bool> _authenticateWithBiometrics() async {
    try {
      if (!await _checkFingerprintSupport()) return false;

      return await _localAuth.authenticate(
        localizedReason: 'قم بإدخال البصمة للمتابعة',
        options: const AuthenticationOptions(
          stickyAuth: true,
          biometricOnly: true,
        ),
      );
    } catch (e) {
      print('Biometric auth error: $e');
      return false;
    }
  }

  Future<bool> _savePassword(String password) async {
    try {
      await _storage.write(key: 'app_password', value: password);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLockEnabled', true);
      setState(() => _isPasswordEnabled = true);
      return true;
    } catch (e) {
      print('Error saving password: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('حدث خطأ أثناء حفظ كلمة المرور')),
      );
      return false;
    }
  }

  Future<void> _disableLock() async {
    try {
      await _storage.delete(key: 'app_password');
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('isLockEnabled', false);
      setState(() => _isPasswordEnabled = false);
    } catch (e) {
      print('Error disabling lock: $e');
    }
  }

  void _showPasswordSetupDialog() {
    String password = '';
    String confirmPassword = '';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('تأكيد كلمة مرور'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              decoration: const InputDecoration(
                labelText: 'كلمة المرور',
              ),
              obscureText: true,
              keyboardType: TextInputType.number,
              onChanged: (value) => password = value,
            ),
            const SizedBox(height: 16),
            TextField(
              decoration: const InputDecoration(
                labelText: 'تأكيد كلمة المرور',
              ),
              keyboardType: TextInputType.number,
              obscureText: true,
              onChanged: (value) => confirmPassword = value,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('إلغاء'),
          ),
          TextButton(
            onPressed: () async {
              if (password.isEmpty || password != confirmPassword) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('كلمات المرور غير متطابقة')),
                );
                return;
              }
              final success = await _savePassword(password);
              if (success) {
                Navigator.pop(context);
              }
            },
            child: const Text('حفظ'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'اعدادات الحماية',
          style: TextStyle(fontSize: 20),
        ),
        centerTitle: true,
      ),
      body: Directionality(
        textDirection: TextDirection.rtl,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SwitchListTile(
              value: _isPasswordEnabled,
              onChanged: (value) {
                if (value) {
                  _showPasswordSetupDialog();
                } else {
                  _disableLock();
                }
              },
              title: const Text('كلمة مرور التطبيق'),
              subtitle: const Text('قم بالتعيين لحماية التطبيق'),
            ),
            if (_isBiometricAvailable)
              ListTile(
                title: const Text('البصمة'),
                subtitle: const Text('استخدم البصمة لفتح التطبيق'),
                trailing: const Icon(Icons.fingerprint),
                onTap: () async {
                  final authenticated = await _authenticateWithBiometrics();
                  if (authenticated) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('تم تفعيل البصمة بنجاح')),
                    );
                  }
                },
              ),
          ],
        ),
      ),
    );
  }
}