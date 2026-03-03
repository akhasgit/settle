import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Stack(
                  children: [
                    Image.asset(
                      'lib/assets/applogo.png',
                      height: 400,
                      fit: BoxFit.contain,
                    ),
                    Positioned(
                      top: 320,
                      left: 120,
                      right: 0,
                      bottom: 0,
                      child: Text(
                        'Settle',
                        style: TextStyle(fontSize: 48, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
                // Image.asset(
                //   'lib/assets/applogo.png',
                //   height: 400,
                //   fit: BoxFit.contain,
                // ),

                
                // const SizedBox(height: 12),
                // Text(
                //   'Please select an option to continue',
                //   style: TextStyle(
                //     fontSize: 16,
                //     color: Colors.grey,
                //   ),
                //   textAlign: TextAlign.center,
                // ),
                const SizedBox(height: 48),
                ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const LoginScreen(),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text('Login'),
                ),
                const SizedBox(height: 16),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const SignUpScreen(),
                      ),
                    );
                  },
                  child: const Text(
                    'Sign Up',
                    style: TextStyle(color: Colors.black),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
