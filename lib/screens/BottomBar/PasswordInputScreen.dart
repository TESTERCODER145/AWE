import 'package:flutter/material.dart';

class PasswordInputScreen extends StatefulWidget {
  final bool isConfirm;
  final String? initialPassword;
  final Function() onSuccess;


  PasswordInputScreen({this.isConfirm = false, this.initialPassword, required  this.onSuccess});

  @override
  _PasswordInputScreenState createState() => _PasswordInputScreenState();
}

class _PasswordInputScreenState extends State<PasswordInputScreen> {
  String _enteredPassword = '';

  void _onNumberPressed(String number) {
    if (_enteredPassword.length < 4) {
      setState(() {
        _enteredPassword += number;
      });
    }
  }

  void _onDeletePressed() {
    if (_enteredPassword.isNotEmpty) {
      setState(() {
        _enteredPassword = _enteredPassword.substring(0, _enteredPassword.length - 1);
      });
    }
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
        appBar: AppBar(title: Text(widget.isConfirm ? 'تأكيد كلمة المرور' : 'أدخل كلمة المرور')),
        body: Column(
          children: [
        Expanded(
            child: Center(
            child: Text(
              '●' * _enteredPassword.length,
              style: TextStyle(fontSize: 24),
            ),
        ),
        ),
        _buildNumpad(),
    ],
    ),
    );
  }

  Widget _buildNumpad() {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 3,
      children: [
        _buildButton('1', 'ABC'),
        _buildButton('2', 'DEF'),
        _buildButton('3', 'GHI'),
        _buildButton('4', 'JKL'),
        _buildButton('5', 'MNO'),
        _buildButton('6', 'PORS'),
        _buildButton('7', 'TUV'),
        _buildButton('8', 'WXYZ'),
        _buildButton('9', ''),
        _buildButton('+%#', ''),
        _buildButton('0', ''),
        IconButton(
          icon: Icon(Icons.backspace),
          onPressed: _onDeletePressed,
        ),
      ],
    );
  }

  Widget _buildButton(String number, String letters) {
    return InkWell(
      onTap: () => _onNumberPressed(number),
      child: Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(number, style: TextStyle(fontSize: 24)),
              Text(letters, style: TextStyle(fontSize: 12)),
            ]),
      ),
    );
  }
}