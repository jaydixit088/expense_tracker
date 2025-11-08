import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:google_fonts/google_fonts.dart'; // Import Google Fonts

import 'package:expense_tracker/providers/expenses_provider.dart';
import 'package:expense_tracker/screens/auth_gate.dart'; // Import AuthGate
import 'firebase_options.dart';

void main() async {
  // Ensure that all Flutter bindings are initialized before running the app.
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase with the platform-specific options.
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  
  // Run the app.
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    // The ChangeNotifierProvider makes the ExpensesProvider available to the entire widget tree.
    return ChangeNotifierProvider(
      create: (context) => ExpensesProvider(),
      child: MaterialApp(
        title: 'Expense Tracker',
        debugShowCheckedModeBanner: false,
        
        // --- THEME DATA ---
        // Applying a consistent theme using Google Fonts for a professional look.
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFFFFC107), // Amber
            brightness: Brightness.light,
            primary: const Color(0xFFFFC107),
            secondary: Colors.black,
          ),
          scaffoldBackgroundColor: Colors.grey[100],
          // Use GoogleFonts to apply a consistent and reliable font.
          textTheme: GoogleFonts.robotoTextTheme(Theme.of(context).textTheme),
          appBarTheme: AppBarTheme(
            backgroundColor: const Color(0xFFFFC107),
            foregroundColor: Colors.black,
            elevation: 0,
            centerTitle: true,
            titleTextStyle: GoogleFonts.roboto(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.black),
          ),
          cardTheme: CardTheme(
            color: Colors.white,
            elevation: 1,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
          ),
          elevatedButtonTheme: ElevatedButtonThemeData(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            ),
          ),
        ),

        // --- STARTING POINT ---
        // The AuthGate will handle whether to show the WelcomeScreen or ExpensesScreen.
        // This is the correct entry point for an app with authentication.
        home: const SplashScreen(),
      ),
    );
  }
}
