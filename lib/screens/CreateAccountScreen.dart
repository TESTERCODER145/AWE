import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import 'VerifyPasswordCodeScreen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:flutter_facebook_auth/flutter_facebook_auth.dart';
import 'package:downloadsplatform/Models/auth_provider.dart';
import 'package:provider/provider.dart';

class CreateAccountScreen extends StatefulWidget {
  @override
  _CreateAccountScreenState createState() => _CreateAccountScreenState();
}

class _CreateAccountScreenState extends State<CreateAccountScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _agreeToTerms = false;
  bool _checkboxError = false; // To track checkbox validation error
  bool _isLoading = false; // To track if the request is in progress

  String handleError(String responseBody) {
    final Map<String, dynamic> responseJson = jsonDecode(responseBody);
    final String errorMessage = responseJson['error'];
    return errorMessage; // سيتم عرض النص باللغة العربية
  }

  Future<void> _createAccount() async {
    if (_formKey.currentState!.validate()) {
      if (!_agreeToTerms) {
        setState(() {
          _checkboxError = true; // Show checkbox error
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('يرجى الموافقة على الشروط والأحكام')),
        );
        return;
      }

      setState(() {
        _isLoading = true; // Disable the button
      });

      final email = _emailController.text;
      final password = _passwordController.text;

      final url = Uri.parse('https://downloadsplatform.com/api/auth/register');
      try {
        final response = await http.post(
          url,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode({
            'email': email,
            'password': password,
          }),
        );
        print(response.body);

        if (response.statusCode == 201) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('تم ارسال كود التحقق بنجاح!')),
          );
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => VerifyPasswordCodeScreen(
                email: email,
                type: 'verification',
              ),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('فشل إنشاء الحساب '),
            ),
          );
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الاتصال بالخادم')),
        );
      } finally {
        setState(() {
          _isLoading = false; // Re-enable the button
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

          Navigator.pushReplacementNamed(context, '/welcome');
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

              Navigator.pushReplacementNamed(context, '/welcome');
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
          Navigator.pushReplacementNamed(context, '/welcome');
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
        SnackBar(content: Text('حدث خطأ أثناء تسجيل الدخول باستخدام Facebook ')),
      );
    }
  }


  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<UserProvider>(context, listen: false);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'انشاء حساب',
          style: TextStyle(fontSize: 25, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
        automaticallyImplyLeading: false, // Hide the back button
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
                  'قم بأنشاء حساب حتي يمكنك الاستمتاع بجميع ميزات التطبيق',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16),
                ),
                SizedBox(height: 30),
                // Email Input
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: TextFormField(
                    textDirection: TextDirection.rtl,
                    controller: _emailController,
                    decoration: InputDecoration(
                      labelText: 'البريد الإلكتروني او رقم الموبيل',
                      border: OutlineInputBorder(),
                      hintTextDirection: TextDirection.rtl,
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'يرجى إدخال البريد الإلكتروني او رقم الموبيل';
                      }
                      if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                          .hasMatch(value)) {
                        return 'يرجى إدخال بريد إلكتروني صحيح';
                      }
                      return null;
                    },
                  ),
                ),
                SizedBox(height: 20),
                // Password Input
                Directionality(
                  textDirection: TextDirection.rtl,
                  child: TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: InputDecoration(
                      labelText: 'كلمة السر',
                      border: OutlineInputBorder(),
                      hintTextDirection: TextDirection.rtl,
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
                SizedBox(height: 20),
                // Agree to Terms Checkbox
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    Flexible(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          Flexible(
                            child: TextButton(
                              onPressed: () => {},
                              child: Text(
                                "اتفاقية المستخدم وسياسة الخصوصيه",
                                style: TextStyle(
                                  fontSize: 16,
                                  decoration: TextDecoration.underline,
                                  decorationColor: Colors.green,
                                ),
                                softWrap: true,
                                textAlign: TextAlign.right,
                              ),
                            ),
                          ),
                          Text('أوافق على '),
                        ],
                      ),
                    ),
                    Checkbox(
                      value: _agreeToTerms,
                      onChanged: (value) {
                        setState(() {
                          _agreeToTerms = value ?? false;
                          _checkboxError = false;
                        });
                      },
                    ),
                  ],
                ),
                if (_checkboxError) // Show error message if checkbox is not checked
                  Padding(
                    padding: const EdgeInsets.only(right: 16.0),
                    child: Text(
                      'يرجى الموافقة على الشروط والأحكام',
                      style: TextStyle(color: Colors.red),
                      textAlign: TextAlign.end,
                    ),
                  ),
                SizedBox(height: 20),
                // Create Account Button
                ElevatedButton(
                  onPressed:
                      _isLoading ? null : _createAccount, // Disable if loading
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blue,
                    padding: EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? CircularProgressIndicator(
                          color: Colors.white, // Show loading indicator
                        )
                      : Text(
                          'انشاء حساب',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.w900,
                            color: Colors.white,
                          ),
                        ),
                ),
                SizedBox(height: 10),
                // Guest Login
                TextButton(
                  onPressed: () {
                    authProvider.signOut();
                    // Navigate to guest login screen
                    Navigator.pushReplacementNamed(context, '/home');
                  },
                  child: Text(
                    'الدخول كضيف',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
                SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: Divider(
                        color: Colors.grey, // Line color
                        thickness: 1, // Line thickness
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Text(
                        'أو',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                          fontSize: 20,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Divider(
                        color: Colors.grey, // Line color
                        thickness: 1, // Line thickness
                      ),
                    ),
                  ],
                ),
                SizedBox(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // Facebook Icon
                    IconButton(
                      icon: Icon(Icons.facebook, color: Colors.blue),
                      onPressed: _signInWithFacebook,
                    ),
                    // Google Icon
                    IconButton(
                      icon: Icon(Icons.g_mobiledata_rounded, color: Colors.red),
                      onPressed: _signInWithGoogle,
                    ),
                    // Apple Icon

                  ],
                ),
                SizedBox(height: 10),
                // Already Have an Account
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    TextButton(
                      onPressed: () {
                        // Navigate to login screen
                        Navigator.pushNamed(context, '/login');
                      },
                      child: Text(
                        'أدخل',
                        style: TextStyle(color: Colors.blue),
                      ),
                    ),
                    Text(
                      'بالفعل لدي حساب ؟',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
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
