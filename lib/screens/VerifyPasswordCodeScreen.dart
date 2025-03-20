import 'package:downloadsplatform/Models/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class VerifyPasswordCodeScreen extends StatelessWidget {
  final String email;
  final String type;

  VerifyPasswordCodeScreen({required this.email, required this.type});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('كود التحقق'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            GestureDetector(
              onTap: () {
                _resendOtp(email, type, context);
              },
              child: Text(
                'أدخل كود التحقق المرسل الي البريد الإلكتروني',
                style: TextStyle(fontSize: 16),
              ),
            ),
            SizedBox(height: 20),
            VerifyCodeInputFields(email: email, type: type),
            SizedBox(height: 20),
            TextButton(
              onPressed: () {
                _resendOtp(email, type, context);
              },
              child: Text('لم تحصل علي الكود؟ أرسله مره أخرى'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _resendOtp(
      String email, String type, BuildContext context) async {
    final url = Uri.parse('https://downloadsplatform.com/api/auth/resend-otp');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': email,
          'type': type,
        }),
      );

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم إعادة إرسال الكود بنجاح')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل إعادة إرسال الكود')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الاتصال بالخادم ')),
      );
    }
  }
}

class VerifyCodeInputFields extends StatefulWidget {
  final String email;
  final String type;

  VerifyCodeInputFields({required this.email, required this.type});

  @override
  _VerifyCodeInputFieldsState createState() => _VerifyCodeInputFieldsState();
}

class _VerifyCodeInputFieldsState extends State<VerifyCodeInputFields> {
  final List<FocusNode> _focusNodes = List.generate(4, (index) => FocusNode());
  final List<TextEditingController> _controllers =
      List.generate(4, (index) => TextEditingController());
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    for (int i = 0; i < _focusNodes.length; i++) {
      _focusNodes[i].addListener(() {
        if (_focusNodes[i].hasFocus && _controllers[i].text.isEmpty) {
          _controllers[i].text = '';
        }
      });
    }
  }

  @override
  void dispose() {
    for (var node in _focusNodes) {
      node.dispose();
    }
    for (var controller in _controllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _onChanged(int index, String value) {
    if (value.isNotEmpty && index < _focusNodes.length - 1) {
      _focusNodes[index + 1].requestFocus();
    }

    if (index == _focusNodes.length - 1 && value.isNotEmpty) {
      _verifyCode();
    }
  }

  Future<void> _verifyCode() async {
    setState(() {
      _isLoading = true;
    });

    String code = _controllers.map((controller) => controller.text).join();
    print('Verifying code: $code');

    final url = Uri.parse('https://downloadsplatform.com/api/auth/verify-otp');

    try {
      final response = await http.post(
        url,
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({
          'email': widget.email,
          'type': widget.type,
          'otp': code,
        }),
      );

      setState(() {
        _isLoading = false;
      });

      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('تم التحقق بنجاح')),
        );
        // Navigate to the next screen or perform other actions
        if (widget.type == "reset") {
          Navigator.pushNamed(
            context,
            '/resetPassword',
            arguments: widget.email, // Pass the email here
          );
        } else {
          final userData = jsonDecode(response.body);
          final authProvider = Provider.of<UserProvider>(context, listen: false);
          await authProvider.signIn(userData['user']);
          // Save the token to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('authToken', userData['token']); // Assuming the token is in the response
          Navigator.pushReplacementNamed(
            context,
            '/completeProfile',
            arguments: widget.email, // Pass the email here
          );
        }
      } else {
        print("****************");
        print(response.body);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل التحقق')),
        );
      }
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء الاتصال بالخادم')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: List.generate(4, (index) {
            return Container(
              width: 50,
              child: TextField(
                controller: _controllers[index],
                focusNode: _focusNodes[index],
                textAlign: TextAlign.center,
                maxLength: 1,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(
                  counterText: '',
                  border: OutlineInputBorder(),
                ),
                onChanged: (value) => _onChanged(index, value),
              ),
            );
          }),
        ),
        if (_isLoading)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: CircularProgressIndicator(),
          ),
      ],
    );
  }
}
