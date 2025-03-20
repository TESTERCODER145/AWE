import 'package:flutter/material.dart';

// Onboarding Screen 3
class OnboardingScreen3 extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Image(image: AssetImage("assets/images/Illustration2.png")),
              Text(
                'ابداء الآن',
                textAlign: TextAlign.center,
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
                    ],
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pushReplacementNamed(context, '/createAccount');
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

