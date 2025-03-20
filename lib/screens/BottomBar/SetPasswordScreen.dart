import 'package:downloadsplatform/screens/BottomBar/PasswordInputScreen.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SetPasswordScreen extends StatefulWidget {
  @override
  _SetPasswordScreenState createState() => _SetPasswordScreenState();
}

class _SetPasswordScreenState extends State<SetPasswordScreen> {
  String? _password;

  void _onPasswordEntered(String password) async {
    if (_password == null) {
      setState(() => _password = password);
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => PasswordInputScreen(
            isConfirm: true,
            initialPassword: password, onSuccess: () {  },
          ),
        ),
      );
    } else {
      if (_password == password) {
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('appPassword', password);
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('كلمة المرور غير متطابقة')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return PasswordInputScreen(
      isConfirm: false,
      initialPassword: null,
      onSuccess: () {},
    );
  }
}