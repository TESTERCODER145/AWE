import 'package:flutter/material.dart';


// Welcome Screen
class WelcomeScreen extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            Text(
              'مرحبا بك',
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            SizedBox(height: 20),
            Text(
              'استمتع بتجربة تحميل سلسة ومتنوعة من خلال موقعنا',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 16),
            ),
            Image(image: AssetImage("assets/images/cuate.png")),
            SizedBox(height: 40),
            ElevatedButton(
              onPressed: () {
                Navigator.pushReplacementNamed(context, '/home');
              },
              child: Text('ابداء الآن'),
            ),
          ],
        ),
      ),
    );
  }
}
