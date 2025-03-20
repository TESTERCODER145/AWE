import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

class FingerprintScreen extends StatelessWidget {
  final Function() onAuthSuccess;

   FingerprintScreen({required this.onAuthSuccess});
  final LocalAuthentication _localAuth = LocalAuthentication();

  Future<void> _authenticate(BuildContext context) async {
    try {
      bool authenticated = await _localAuth.authenticate(
        localizedReason: 'المس مستشعر البصمة للفتح',
        options: const AuthenticationOptions(
          biometricOnly: true, // للسماح فقط بالبصمة وليس PIN/Password
        ),
      );

      if (authenticated) {
        onAuthSuccess();
      }
    } catch (e) {
      print('Error: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل المصادقة')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fingerprint, size: 64),
            Text('أدخل البصمة'),
            ElevatedButton(
              onPressed: () => _authenticate(context),
              child: Text('محاولة مرة أخرى'),
            ),
          ],
        ),
      ),
    );
  }
}