import 'package:flutter/material.dart';
import 'package:expense_tracker/screens/auth_screen.dart';

/// The landing screen for users who are not authenticated.
/// It provides a visually appealing entry point with options to sign in or sign up.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // --- Best Practice: Define repeated values as constants. ---
    const primaryColor = Color(0xFFFFC107); // Amber color

    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Decorative circle in the top-right corner for visual flair.
          Positioned(
            top: -50,
            right: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                color: primaryColor.withOpacity(0.8),
                shape: BoxShape.circle,
              ),
            ),
          ),
          SafeArea(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Spacer(),
                  const Icon(Icons.wallet_outlined, size: 80, color: Colors.black),
                  const SizedBox(height: 10),
                  const Text('Expense Tracker', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  // The main content card with a distinct background color.
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20.0),
                    child: Container(
                      padding: const EdgeInsets.all(24),
                      decoration: BoxDecoration(
                        color: primaryColor,
                        borderRadius: BorderRadius.circular(30),
                      ),
                      child: Column(
                        children: [
                          const Text('Welcome', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            'Track your expenses, manage your budget, and achieve your financial goals.',
                            textAlign: TextAlign.center,
                            style: TextStyle(fontSize: 16, color: Colors.grey[800]),
                          ),
                          const SizedBox(height: 30),
                          // Row containing the Sign In and Sign Up buttons.
                          Row(
                            children: [
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    // Navigate to the AuthScreen in 'login' mode.
                                    Navigator.of(context).push(MaterialPageRoute(
                                      builder: (ctx) => const AuthScreen(isLogin: true),
                                    ));
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.black, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                                  child: const Text('Sign In'),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: ElevatedButton(
                                  onPressed: () {
                                    // Navigate to the AuthScreen in 'signup' mode.
                                    Navigator.of(context).push(MaterialPageRoute(
                                      builder: (ctx) => const AuthScreen(isLogin: false),
                                    ));
                                  },
                                  style: ElevatedButton.styleFrom(backgroundColor: Colors.white, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 16), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                                  child: const Text('Sign Up'),
                                ),
                              ),
                            ],
                          )
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                ],
              ),
            ),
          )
        ],
      ),
    );
  }
}
