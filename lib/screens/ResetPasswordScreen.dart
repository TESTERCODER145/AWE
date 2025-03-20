import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class ResetPasswordScreen extends StatelessWidget {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  Future<void> _resetPassword(BuildContext context, String email) async {
    if (_formKey.currentState!.validate()) {
      final password = _passwordController.text;

      // Make the HTTP POST request
      final url = Uri.parse('https://downloadsplatform.com/api/auth/reset-password');
      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'new_password': password,
          }),
        );

        if (response.statusCode == 200) {
          // Password reset successful
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم إعادة تعيين كلمة السر بنجاح')),
          );
          Navigator.pushReplacementNamed(context, '/home'); // Go back to the previous screen
        } else {
          // Handle error
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل إعادة تعيين كلمة السر')),
          );
        }
      } catch (e) {
        // Handle network error
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الاتصال بالخادم')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Retrieve the email argument passed from the previous screen
    final email = ModalRoute.of(context)!.settings.arguments as String;

    return Scaffold(
      appBar: AppBar(
        title: Text('إعادة تعيين كلمة السر',style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              Text(
                'من فضلك قم بتعيين كلمة سر جديدة لتسجيل الدخول',
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 20),
              TextFormField(
                controller: _passwordController,
                decoration: InputDecoration(
                  labelText: 'كلمة السر',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى إدخال كلمة السر';
                  }
                  if (value.length < 8) {
                    return 'كلمة السر يجب أن تكون على الأقل 8 أحرف';
                  }
                  return null;
                },
              ),
              SizedBox(height: 10),
              TextFormField(
                controller: _confirmPasswordController,
                decoration: InputDecoration(
                  labelText: 'تأكيد كلمة السر',
                  border: OutlineInputBorder(),
                ),
                obscureText: true,
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'يرجى تأكيد كلمة السر';
                  }
                  if (value != _passwordController.text) {
                    return 'كلمة السر غير متطابقة';
                  }
                  return null;
                },
              ),
              SizedBox(height: 20),
              SizedBox(
                width: double.infinity, // This makes the button full width
                child: ElevatedButton(
                  onPressed: () => _resetPassword(context, email),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10), // Rounded corners
                    ),
                  ),
                  child: Text(
                    'إعادة تعيين',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),

            ],
          ),
        ),
      ),
    );
  }
}