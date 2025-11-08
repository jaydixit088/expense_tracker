import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:currency_picker/currency_picker.dart';

// Services and Providers
import 'package:expense_tracker/providers/expenses_provider.dart';
import 'package:expense_tracker/services/firestore_service.dart';
import 'package:expense_tracker/services/pdf_service.dart';
import 'package:expense_tracker/models/user_profile.dart';


class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Services and Controllers
  final _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;
  late final User _user;
  final _nameController = TextEditingController();

  // State
  DateTime? _dob;
  String? _gender;
  bool _isSaving = false;

  // Report State
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser!;
    // Initialize controller with current user's name as a fallback.
    _nameController.text = _user.displayName ?? '';
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }
  
  /// Saves the user's profile data to Firestore and Firebase Auth.
  Future<void> _saveProfile() async {
    setState(() => _isSaving = true);
    try {
      // Update display name in Firebase Auth if it has changed.
      if (_user.displayName != _nameController.text.trim()) {
        await _user.updateDisplayName(_nameController.text.trim());
      }
      
      // Create a UserProfile object and save it to Firestore.
      final profile = UserProfile(  
        uid: _user.uid,
        email: _user.email,
        displayName: _nameController.text.trim(),
        dob: _dob,
        gender: _gender,
      );
      await _firestoreService.saveUserProfile(profile);

      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile saved successfully!')));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error saving profile: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Generates a PDF report for the selected date range.
  Future<void> _generateAndProcessReport({bool share = false}) async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please select a date range first.')));
      return;
    }
    setState(() => _isGenerating = true);

    try {
      // Perform a one-time read from Firestore for the selected range.
      final querySnapshot = await _firestoreService.getExpensesForPeriod(_user.uid, _startDate!, _endDate!);
      final expenses = querySnapshot.docs.map((doc) => Expense.fromMap(doc.data() as Map<String, dynamic>)).toList();
      
      if (!mounted) return;

      if (expenses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No expenses found in the selected period.')));
        return;
      }
      
      // Generate and save the PDF.
      final pdfData = await generateExpensePdf(expenses, '${DateFormat.yMd().format(_startDate!)} - ${DateFormat.yMd().format(_endDate!)}', Provider.of<ExpensesProvider>(context, listen: false).currencySymbol);
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/Expense-Report.pdf');
      await file.writeAsBytes(pdfData);

      if (share) {
        await Share.shareXFiles([XFile(file.path)], text: 'Here is my expense report.');
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('PDF report saved to your documents.')),
        );
      }
    } catch (e) {
        if(mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed to generate report: ${e.toString()}')));
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile & Settings'), 
        actions: [
          if (_isSaving) 
            const Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: Colors.white)) 
          else 
            IconButton(icon: const Icon(Icons.save), onPressed: _saveProfile, tooltip: 'Save Profile')
        ]
      ),
      // Use a FutureBuilder to fetch the user's profile once.
      body: FutureBuilder<UserProfile?>(
        future: _firestoreService.getUserProfile(_user.uid),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          // Once data is fetched, populate the form fields.
          if (snapshot.hasData && snapshot.data != null) {
            final profile = snapshot.data!;
            _nameController.text = profile.displayName;
            _dob = profile.dob;
            _gender = profile.gender;
          }

          return ListView(
            padding: const EdgeInsets.all(16.0),
            children: [
              _buildUserInfoHeader(),
              const SizedBox(height: 20),
              _buildPersonalInfoCard(context),
              const Divider(height: 30),
              _buildSettingsCard(context),
              const Divider(height: 30),
              _buildReportsCard(context),
              const SizedBox(height: 30),
              _buildLogoutButton(context),
            ],
          );
        },
      ),
    );
  }

  Widget _buildUserInfoHeader() {
    return Center(child: Text(_user.email ?? 'No email associated', style: const TextStyle(color: Colors.grey, fontSize: 16)));
  }

  Widget _buildPersonalInfoCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Personal Information', style: Theme.of(context).textTheme.titleLarge),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Display Name', icon: Icon(Icons.person))),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cake),
                  title: const Text('Date of Birth'),
                  trailing: Text(_dob == null ? 'Not Set' : DateFormat.yMd().format(_dob!)),
                  onTap: () async {
                    final pickedDate = await showDatePicker(context: context, initialDate: _dob ?? DateTime(2000), firstDate: DateTime(1920), lastDate: DateTime.now());
                    if (pickedDate != null) setState(() => _dob = pickedDate);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.wc),
                  title: const Text('Gender'),
                  trailing: DropdownButton<String>(
                    value: _gender,
                    hint: const Text('Select'),
                    items: ['Male', 'Female', 'Other'].map((label) => DropdownMenuItem(value: label, child: Text(label))).toList(),
                    onChanged: (value) => setState(() => _gender = value),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSettingsCard(BuildContext context) {
    // Use a Consumer here to listen for changes to the currency symbol
    return Consumer<ExpensesProvider>(
      builder: (context, expensesProvider, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Security & Settings', style: Theme.of(context).textTheme.titleLarge),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.attach_money),
                    title: const Text('Currency'),
                    trailing: Text(expensesProvider.currencySymbol),
                    onTap: () => showCurrencyPicker(context: context, onSelect: (currency) => expensesProvider.setCurrency(currency.symbol)),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Change Password'),
                    onTap: () {
                      if (_user.email != null) {
                        _auth.sendPasswordResetEmail(email: _user.email!);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Password reset link sent to ${_user.email}')));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('This option is only available for email accounts.')));
                      }
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
  
  Widget _buildReportsCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Expense Reports', style: Theme.of(context).textTheme.titleLarge),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_startDate == null ? 'Start Date' : DateFormat.yMd().format(_startDate!)),
                      onPressed: () async {
                        final pickedDate = await showDatePicker(context: context, initialDate: _startDate ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime.now());
                        if (pickedDate != null) setState(() => _startDate = pickedDate);
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_endDate == null ? 'End Date' : DateFormat.yMd().format(_endDate!)),
                      onPressed: () async {
                        final pickedDate = await showDatePicker(context: context, initialDate: _endDate ?? _startDate ?? DateTime.now(), firstDate: _startDate ?? DateTime(2020), lastDate: DateTime.now());
                        if (pickedDate != null) setState(() => _endDate = pickedDate);
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (_isGenerating)
                  const CircularProgressIndicator()
                else
                  Row(
                    children: [
                      Expanded(child: OutlinedButton.icon(icon: const Icon(Icons.download), label: const Text('Download'), onPressed: () => _generateAndProcessReport(share: false))),
                      const SizedBox(width: 16),
                      Expanded(child: ElevatedButton.icon(icon: const Icon(Icons.share), label: const Text('Share'), onPressed: () => _generateAndProcessReport(share: true))),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLogoutButton(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.logout, color: Colors.white),
      label: const Text('Logout', style: TextStyle(color: Colors.white)),
      style: ElevatedButton.styleFrom(backgroundColor: Colors.red.shade400, padding: const EdgeInsets.symmetric(vertical: 16)),
      onPressed: () async {
        await GoogleSignIn().signOut();
        await _auth.signOut();
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      },
    );
  }
}
