

// Onboarding Screen 1
import 'package:flutter/material.dart';

class OnboardingScreen1 extends StatelessWidget {

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
          Image(image: AssetImage("assets/images/Illustration.png")),
              Text(
                'مرحبا بك في منصة التحميل',
                style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
              ),
              SizedBox(height: 20),
              Text(
                'نوفر لك تجربة مميزة في تحميل جميع الوسائط بصيغ متعددة',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 16),
              ),
              SizedBox(height: 40),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/createAccount');
                    },
                    child: Text('تخطى'),
                  ),
                  Row(
                    children: [
                      Container(
                        width: 10, // Dot width
                        height: 10, // Dot height
                        margin: EdgeInsets.symmetric(horizontal: 5), // Spacing between dots
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:  Colors.black ,
                        ),
                      ),
                      Container(
                        width: 10, // Dot width
                        height: 10, // Dot height
                        margin: EdgeInsets.symmetric(horizontal: 5), // Spacing between dots
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:  Colors.grey ,
                        ),
                      ),
                      Container(
                        width: 10, // Dot width
                        height: 10, // Dot height
                        margin: EdgeInsets.symmetric(horizontal: 5), // Spacing between dots
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color:  Colors.grey ,
                        ),
                      ),
                    ],
                  ),

                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/onboarding2');
                    },
                    child: Text('التالي'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
