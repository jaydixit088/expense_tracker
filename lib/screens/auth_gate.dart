import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:expense_tracker/screens/expenses_screen.dart';
import 'package:expense_tracker/screens/welcome_screen.dart';

/// A top-level widget that acts as a gatekeeper for authentication.
///
/// This widget listens to the Firebase authentication state and directs the user
/// to the appropriate screen: [WelcomeScreen] if logged out, or [ExpensesScreen]
/// if logged in. This is the standard and best-practice way to handle auth flow.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      // Listen to the stream of authentication state changes from Firebase.
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // --- State 1: User is not signed in ---
        // `snapshot.hasData` is false when the user is null (logged out).
        if (!snapshot.hasData) {
          return const WelcomeScreen();
        }

        // --- State 2: User is signed in ---
        // If we have data, it means the user is logged in.
        // We show the main app screen.
        // ExpensesScreen is not constant because it will likely manage state.
        return const ExpensesScreen();
      },
    );
  }
}
