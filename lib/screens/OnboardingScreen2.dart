import 'package:flutter/material.dart';

// Onboarding Screen 2
class OnboardingScreen2 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Image(image: AssetImage("assets/images/Illustration1.png")),
              Text(
                'تدعم جميع منصات',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 20),
              Text(
                'قم باصق الرابط الخاص بك من أي منصة وحمل مباشرة',
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
                    child: Text('تخطي'),
                  ),
                  Row(
                    children: [
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
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushNamed(context, '/onboarding3');
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