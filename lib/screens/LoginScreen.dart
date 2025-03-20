import 'package:downloadsplatform/Models/auth_provider.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';


import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

class LoginScreen extends StatefulWidget {
  @override
  _LoginScreenState createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  Future<void> _login() async {
    if (_formKey.currentState!.validate()) {
      setState(() {
        _isLoading = true;
      });

      final email = _emailController.text;
      final password = _passwordController.text;

      try {
        final url = Uri.parse('https://downloadsplatform.com/api/auth/login');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
          }),
        );
        print(response.body);

        if (response.statusCode == 200) {
          final userData = jsonDecode(response.body);
          final authProvider = Provider.of<UserProvider>(context, listen: false);
          await authProvider.signIn(userData['user']);
          // Save the token to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('authToken', userData['token']); // Assuming the token is in the response
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم التسجيل بنجاح !')),
          );

          Navigator.pushReplacementNamed(context, '/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل تسجيل الدخول'),
            ),
          );
        }
      } catch (e) {
        print("Error signing in: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الاتصال بالخادم')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _signInWithGoogle() async {

    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return;

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;

      final OAuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final UserCredential userCredential = await FirebaseAuth.instance.signInWithCredential(credential);
      setState(() {
        _isLoading = true;
      });
      try {
        final url = Uri.parse('https://downloadsplatform.com/api/auth/social-login');
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': userCredential.user!.email,
            'firstName': userCredential.user!.displayName?.split(" ")[0],
            'lastName': userCredential.user!.displayName?.split(" ")[1],
          }),
        );
        print(response.body);

        if (response.statusCode == 200) {
          final userData = jsonDecode(response.body);
          final authProvider = Provider.of<UserProvider>(context, listen: false);
          await authProvider.signIn(userData['user']);
          // Save the token to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setString('authToken', userData['token']); // Assuming the token is in the response
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم التسجيل بنجاح !')),
          );

          Navigator.pushReplacementNamed(context, '/home');
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل تسجيل الدخول '),
            ),
          );
        }
      } catch (e) {
        print("Error signing in: $e");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الاتصال بالخادم')),
        );
      } finally {
        setState(() {
          _isLoading = false;
        });
      }
      print("User signed in with Google");
      Navigator.pushReplacementNamed(context, '/home');
    } catch (e) {
      print("Error signing in with Google: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('فشل تسجيل الدخول باستخدام Google ')),
      );
    }
  }

  Future<void> _signInWithFacebook() async {
    try {
      // Print debug information
      print("Attempting Facebook Login");

      final LoginResult result = await FacebookAuth.instance.login(
          permissions: ['email', 'public_profile']
      );

      print("Facebook Login Result: ${result.status}");

      if (result.status == LoginStatus.success) {
        final AccessToken? accessToken = result.accessToken;

        if (accessToken != null) {
          final OAuthCredential facebookAuthCredential =
          FacebookAuthProvider.credential(accessToken.tokenString);

          final UserCredential userCredential =
          await FirebaseAuth.instance.signInWithCredential(facebookAuthCredential);
          setState(() {
            _isLoading = true;
          });
          try {
            final url = Uri.parse('https://downloadsplatform.com/api/auth/social-login');
            final response = await http.post(
              url,
              headers: {'Content-Type': 'application/json'},
              body: jsonEncode({
                'email': userCredential.user!.email,
                'firstName': userCredential.user!.displayName?.split(" ")[0],
                'lastName': userCredential.user!.displayName?.split(" ")[1],
              }),
            );
            print(response.body);

            if (response.statusCode == 200) {
              final userData = jsonDecode(response.body);
              final authProvider = Provider.of<UserProvider>(context, listen: false);
              await authProvider.signIn(userData['user']);
              // Save the token to SharedPreferences
              final prefs = await SharedPreferences.getInstance();
              await prefs.setString('authToken', userData['token']); // Assuming the token is in the response
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('تم التسجيل بنجاح !')),
              );

              Navigator.pushReplacementNamed(context, '/home');
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('فشل تسجيل الدخول '),
                ),
              );
            }
          } catch (e) {
            print("Error signing in: $e");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('حدث خطأ أثناء الاتصال بالخادم')),
            );
          } finally {
            setState(() {
              _isLoading = false;
            });
          }

          print("User signed in with Facebook: ${userCredential.user}");
          Navigator.pushReplacementNamed(context, '/home');
        } else {
          print("Facebook access token is null");
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('فشل الحصول على رمز الوصول')),
          );
        }
      } else {
        print("Facebook login failed: ${result.status}");
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('فشل تسجيل الدخول باستخدام Facebook')),
        );
      }
    } catch (e) {
      print("Detailed Facebook Login Error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('حدث خطأ أثناء تسجيل الدخول باستخدام Facebook')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('تسجيل الدخول', style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
        automaticallyImplyLeading: false,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  'مرحبا بعودتك مرة أخرى',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: 20),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: TextFormField(
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'البريد الإلكتروني',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى إدخال البريد الإلكتروني';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                        return 'يرجى إدخال بريد إلكتروني صحيح';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 20),
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'كلمة السر',
                      border: OutlineInputBorder(),
                    ),
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
                ),
                SizedBox(height: 10),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/forgotPassword');
                    },
                    child: Text(
                      'نسيت كلمة السر؟',
                      style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                ElevatedButton(
                  onPressed: _isLoading ? null : _login,
                  child: _isLoading
                      ? CircularProgressIndicator(color: Colors.white)
                      : Text('تسجيل الدخول', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: Divider(color: Colors.grey, thickness: 1),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text('أو'),
                    ),
                    Expanded(
                      child: Divider(color: Colors.grey, thickness: 1),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                      icon: Icon(Icons.facebook, color: Colors.blue),
                      onPressed: _signInWithFacebook,
                    ),
                    IconButton(
                      icon: Icon(Icons.g_mobiledata_rounded, color: Colors.red),
                      onPressed: _signInWithGoogle,
                    ),

                  ],
                ),
                SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        Navigator.pushNamed(context, '/createAccount');
                      },
                      child: Text('انشاء الحساب', style: TextStyle(color: Colors.blue)),
                    ),
                    Text('ليس لدي حساب ؟', style: TextStyle(fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}