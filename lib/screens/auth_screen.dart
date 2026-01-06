import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
// We will need to create this service file in a later step.
// For now, let's assume it exists.
import 'package:expense_tracker/services/firestore_service.dart'; 

class AuthScreen extends StatefulWidget {
  final bool isLogin;
  const AuthScreen({super.key, required this.isLogin});

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final _formKey = GlobalKey<FormState>();
  late bool _isLogin;

  // Form fields
  String _email = '';
  String _password = '';
  String _displayName = ''; // Added for sign-up

  // UI State
  bool _isLoading = false;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _isLogin = widget.isLogin;
  }

  /// Shows a standardized error message to the user.
  void _showErrorSnackbar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Theme.of(context).colorScheme.error,
      ),
    );
  }

  /// Main submission handler for all authentication methods.
  Future<void> _submit(Future<UserCredential> authFuture) async {
    setState(() => _isLoading = true);
    try {
      final userCredential = await authFuture;
      final user = userCredential.user;

      if (user == null) throw Exception('Authentication failed: User is null');

      // After sign-up, create a user profile document in Firestore.
      if (!_isLogin) {
        await FirestoreService().createUserProfile(
          uid: user.uid,
          displayName: _displayName,
          email: user.email,
        );
      }

      // If successful, pop all routes until the first one (AuthGate will handle the redirect).
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } on FirebaseAuthException catch (e) {
      _showErrorSnackbar(e.message ?? 'An authentication error occurred.');
    } catch (e) {
      _showErrorSnackbar('An unexpected error occurred. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  /// Handles the form submission for email/password auth.
  void _submitForm() {
    final isValid = _formKey.currentState!.validate();
    FocusScope.of(context).unfocus();

    if (!isValid) return;
    _formKey.currentState!.save();
    
    if (_isLogin) {
      _submit(FirebaseAuth.instance.signInWithEmailAndPassword(email: _email, password: _password));
    } else {
      _submit(FirebaseAuth.instance.createUserWithEmailAndPassword(email: _email, password: _password));
    }
  }

  /// Handles the Google Sign-In flow.
  Future<void> _googleSignIn() async {
    try {
      final GoogleSignInAccount? googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) return; // User cancelled

      final GoogleSignInAuthentication googleAuth = await googleUser.authentication;
      final AuthCredential credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      
      // We still wrap this in our main _submit handler for consistent logic.
      await _submit(FirebaseAuth.instance.signInWithCredential(credential));
    } catch (e) {
      // Catch errors specific to the Google Sign-In process itself.
      if (mounted) _showErrorSnackbar('Google Sign-In failed. Please try again.');
    }
  }
  
  /// Handles the password reset flow.
  Future<void> _resetPassword() async {
    _formKey.currentState?.save();
    if (_email.isEmpty) {
        _showErrorSnackbar('Please enter your email address to reset your password.');
        return;
    }
    try {
        await FirebaseAuth.instance.sendPasswordResetEmail(email: _email);
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password reset link sent to $_email.')));
    } on FirebaseAuthException catch (e) {
        _showErrorSnackbar(e.message ?? 'Failed to send reset link.');
    }
  }


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFC107),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // --- Header ---
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back, color: Colors.black),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _isLogin = !_isLogin),
                    child: Text(_isLogin ? 'Register' : 'Sign In', style: const TextStyle(color: Colors.black, fontSize: 16)),
                  )
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text(_isLogin ? 'Sign In' : 'Create Account', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold, color: Colors.black)),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32.0),
              child: Text('Please fill the details to continue.', style: TextStyle(fontSize: 16, color: Colors.grey[800])),
            ),
            const SizedBox(height: 30),
            // --- Form Body ---
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(32),
                decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.only(topLeft: Radius.circular(40), topRight: Radius.circular(40))),
                child: SingleChildScrollView(
                  child: Form(
                    key: _formKey,
                    child: Column(
                      children: [
                        // --- Name field (only for sign-up) ---
                        if (!_isLogin) ...[
                          TextFormField(
                            key: const ValueKey('displayName'),
                            validator: (value) => (value == null || value.isEmpty) ? 'Please enter your name.' : null,
                            onSaved: (value) => _displayName = value!,
                            decoration: InputDecoration(hintText: 'Display Name', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
                          ),
                          const SizedBox(height: 20),
                        ],
                        // --- Email Field ---
                        TextFormField(
                          key: const ValueKey('email'),
                          validator: (value) => (value != null && value.contains('@')) ? null : 'Please enter a valid email.',
                          onSaved: (value) => _email = value!,
                          keyboardType: TextInputType.emailAddress,
                          decoration: InputDecoration(hintText: 'Email', filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none)),
                        ),
                        const SizedBox(height: 20),
                        // --- Password Field ---
                        TextFormField(
                          key: const ValueKey('password'),
                          validator: (value) => (value != null && value.length > 6) ? null : 'Password must be at least 7 characters.',
                          onSaved: (value) => _password = value!,
                          obscureText: _obscurePassword,
                          decoration: InputDecoration(
                            hintText: 'Password',
                            filled: true,
                            fillColor: Colors.grey[100],
                            border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
                            suffixIcon: IconButton(icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey), onPressed: () => setState(() => _obscurePassword = !_obscurePassword)),
                          ),
                        ),
                        if (_isLogin)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(onPressed: _resetPassword, child: const Text('Forgot Password?')),
                          ),
                        const SizedBox(height: 20),
                        // --- Buttons & Loading Indicator ---
                        if (_isLoading)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 40.0),
                            child: CircularProgressIndicator(),
                          )
                        else
                          Column(
                            children: [
                              ElevatedButton(
                                onPressed: _submitForm,
                                style: ElevatedButton.styleFrom(backgroundColor: Colors.black, minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                                child: Text(_isLogin ? 'Sign In' : 'Sign Up'),
                              ),
                              const SizedBox(height: 20),
                              const Text('OR'),
                              const SizedBox(height: 20),
                              OutlinedButton.icon(
                                icon: Image.asset('assets/google_logo.png', height: 24),
                                label: const Text('Continue with Google'),
                                onPressed: _googleSignIn,
                                style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 56), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)), side: BorderSide(color: Colors.grey.shade300)),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }
}

