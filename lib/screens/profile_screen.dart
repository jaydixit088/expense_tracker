import 'dart:io';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:currency_picker/currency_picker.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

// Services and Providers
import 'package:expense_tracker/providers/expenses_provider.dart';
import 'package:expense_tracker/services/firestore_service.dart';
import 'package:expense_tracker/services/pdf_service.dart';
import 'package:expense_tracker/models/user_profile.dart';
import 'package:expense_tracker/models/expense.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Services and Controllers
  final _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;
  User? _user;
  final _nameController = TextEditingController();

  // State
  DateTime? _dob;
  String? _gender;
  bool _isSaving = false;
  late Future<UserProfile?> _profileFuture;

  // Report State
  DateTime? _startDate;
  DateTime? _endDate;
  bool _isGenerating = false;

  @override
  void initState() {
    super.initState();
    _user = _auth.currentUser;
    if (_user != null) {
      _nameController.text = _user!.displayName ?? '';
      _profileFuture = _firestoreService.getUserProfile(_user!.uid);
    } else {
      _profileFuture = Future.value(null);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  /// Saves the user's profile data to Firestore and Firebase Auth.
  Future<void> _saveProfile() async {
    if (_user == null) return;
    setState(() => _isSaving = true);
    try {
      final name = _nameController.text.trim();

      // Update display name in Firebase Auth if it has changed.
      if (_user!.displayName != name) {
        await _user!.updateDisplayName(name);
      }

      // Create a UserProfile object and save it to Firestore.
      final profile = UserProfile(
        uid: _user!.uid,
        email: _user!.email,
        displayName: name,
        dob: _dob,
        gender: _gender,
      );
      await _firestoreService.saveUserProfile(profile);

      // Refresh the future so FutureBuilder gets the latest data.
      setState(() {
        _profileFuture = Future.value(profile);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Profile saved successfully!')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error saving profile: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  /// Generates a PDF report for the selected date range.
  Future<void> _generateAndProcessReport({bool share = false}) async {
    if (_startDate == null || _endDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a date range first.')));
      return;
    }
    if (_user == null) return;
    setState(() => _isGenerating = true);

    try {
      final querySnapshot = await _firestoreService.getExpensesForPeriod(
          _user!.uid, _startDate!, _endDate!);
      final List<Expense> expenses = querySnapshot.docs
          .map((doc) => Expense.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      if (!mounted) return;
      if (expenses.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('No expenses found in the selected period.')));
        return;
      }

      final provider = Provider.of<ExpensesProvider>(context, listen: false);
      final pdfData = await generateExpensePdf(
          expenses,
          '${DateFormat.yMd().format(_startDate!)} - ${DateFormat.yMd().format(_endDate!)}',
          provider.currencySymbol);

      // --- SAVE LOGIC ---
      Directory? directory;
      if (Platform.isAndroid) {
        // Try getting external storage for user visibility
        try {
            // For Android 11+ this might require special handling or just use getExternalStorageDirectory
            // and users access it via app-specific storage. 
            // However, to make it "Download" visible, scoped storage is complex.
            // A simpler reliable way for "auto open" is saving to app docs and opening.
            // But user asked for "save in phone". 
            // Let's try to get the standard downloads directory if possible, or fallback.
            directory = await getExternalStorageDirectory();
            String newPath = "";
            List<String> paths = directory!.path.split("/");
            for(int x = 1; x < paths.length; x++){
              String folder = paths[x];
              if(folder != "Android"){
                newPath += "/$folder";
              } else {
                break;
              }
            }
            newPath = "$newPath/Download";
            directory = Directory(newPath);
            if (!await directory.exists()) {
              // Fallback if we can't guess/access Download
               directory = await getExternalStorageDirectory(); 
            }
        } catch(e) {
           directory = await getApplicationDocumentsDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      // Ensure directory exists or fallback
      if (directory == null || !await directory.exists()) {
         directory = await getApplicationDocumentsDirectory();
      }

      final fileName = 'Expense-Report-${DateFormat('yyyyMMdd').format(DateTime.now())}.pdf';
      final file = File('${directory.path}/$fileName');
      
      // Request storage permission if needed (mostly for older Androids or specific paths)
      // For app-specific directories, usually no permission needed in modern Android.
      // But if we try /storage/emulated/0/Download, we might need it.
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        // Just try requesting, if denied we might fail writing to public dir
        await Permission.storage.request(); 
      }

      try {
        await file.writeAsBytes(pdfData);
      } catch (e) {
        // If writing to Downloads failed (permission), fallback to app docs
        final fallbackDir = await getApplicationDocumentsDirectory();
        final fallbackFile = File('${fallbackDir.path}/$fileName');
        await fallbackFile.writeAsBytes(pdfData);
        // Point 'file' to the fallback for opening
        // Note: 'file' variable is final, so we just use fallbackFile for opening
        if (share) {
             await Share.shareXFiles([XFile(fallbackFile.path)], text: 'Here is my expense report.');
             return;
        }
        await OpenFile.open(fallbackFile.path);
        if (mounted) {
           ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Report saved to internal storage & opened.')),
          );
        }
        return;
      }

      if (!mounted) return;
      
      if (share) {
        await Share.shareXFiles([XFile(file.path)],
            text: 'Here is my expense report.');
      } else {
        // --- AUTO OPEN ---
        final result = await OpenFile.open(file.path);
        
        String msg = 'Report saved.';
        if (result.type != ResultType.done) {
          msg += ' Could not open automatically (${result.message}).';
        } else {
          msg += ' Opening...';
        }
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg)),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Failed to generate report: ${e.toString()}')));
      }
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & Settings')),
      // Use a FutureBuilder to fetch the user's profile once.
      body: FutureBuilder<UserProfile?>(
        future: _profileFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          // Once data is fetched, populate the form fields if they are currently null/default.
          if (snapshot.hasData && snapshot.data != null) {
            final profile = snapshot.data!;
            // Only populate name if it's currently showing the default/placeholder.
            if (_nameController.text == (_user?.displayName ?? '') && profile.displayName.isNotEmpty) {
               _nameController.text = profile.displayName;
            }
            // Populate the DOB and Gender only if they haven't been modified yet.
            _dob ??= profile.dob;
            _gender ??= profile.gender;
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
    return Center(
        child: Text(_user?.email ?? 'No email associated',
            style: const TextStyle(color: Colors.grey, fontSize: 16)));
  }

  bool _isEditing = false; // Add state

  Widget _buildPersonalInfoCard(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text('Personal Information',
                style: Theme.of(context).textTheme.titleLarge),
            IconButton(
              icon: Icon(_isEditing ? Icons.check : Icons.edit),
              onPressed: () {
                if (_isEditing) {
                   _saveProfile();
                   setState(() => _isEditing = false);
                } else {
                   setState(() => _isEditing = true);
                }
              },
              tooltip: _isEditing ? 'Save' : 'Edit',
            ),
          ],
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                    controller: _nameController,
                    enabled: _isEditing,
                    decoration: const InputDecoration(
                        labelText: 'Display Name', icon: Icon(Icons.person))),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.cake),
                  title: const Text('Date of Birth'),
                  trailing: Text(_dob == null
                      ? (_isEditing ? 'Tap to select' : 'Not Set')
                      : DateFormat.yMd().format(_dob!)),
                  onTap: _isEditing ? () async {
                    final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: _dob ?? DateTime(2000),
                        firstDate: DateTime(1920),
                        lastDate: DateTime.now());
                    if (pickedDate != null) setState(() => _dob = pickedDate);
                  } : null,
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.wc),
                  title: const Text('Gender'),
                  trailing: _isEditing 
                     ? DropdownButton<String>(
                        value: _gender,
                        hint: const Text('Select'),
                        items: ['Male', 'Female', 'Other']
                            .map((label) =>
                                DropdownMenuItem(value: label, child: Text(label)))
                            .toList(),
                        onChanged: (value) => setState(() => _gender = value),
                      )
                     : Text(_gender ?? 'Not Set'),
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
            Text('Security & Settings',
                style: Theme.of(context).textTheme.titleLarge),
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  ListTile(
                    leading: const Icon(Icons.currency_exchange),
                    title: const Text('Currency'),
                    trailing: Text(expensesProvider.currencySymbol),
                    onTap: () => showCurrencyPicker(
                        context: context,
                        onSelect: (currency) =>
                            expensesProvider.setCurrency(currency.symbol)),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  SwitchListTile(
                    secondary: const Icon(Icons.dark_mode_outlined),
                    title: const Text('Dark Mode'),
                    value: expensesProvider.themeMode == ThemeMode.dark,
                    onChanged: (val) => expensesProvider.toggleTheme(val),
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.account_balance),
                    title: const Text('Monthly Budget'),
                    subtitle: Text('Set your spending goal'),
                    trailing: Text('${expensesProvider.currencySymbol}${expensesProvider.monthlyBudget.toStringAsFixed(0)}'),
                    onTap: () {
                      showDialog(
                        context: context,
                        builder: (ctx) {
                          final controller = TextEditingController(text: expensesProvider.monthlyBudget.toStringAsFixed(0));
                          return AlertDialog(
                            title: const Text('Set Monthly Budget'),
                            content: TextField(
                              controller: controller,
                              keyboardType: TextInputType.number,
                              decoration: InputDecoration(
                                prefixText: '${expensesProvider.currencySymbol} ',
                                labelText: 'Budget Amount',
                              ),
                            ),
                            actions: [
                              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
                              ElevatedButton(
                                onPressed: () {
                                  final val = double.tryParse(controller.text);
                                  if (val != null && val > 0) {
                                    expensesProvider.setMonthlyBudget(val);
                                    Navigator.pop(ctx);
                                  }
                                },
                                child: const Text('Set'),
                              ),
                            ],
                          );
                        },
                      );
                    },
                  ),
                  const Divider(height: 1, indent: 16, endIndent: 16),
                  ListTile(
                    leading: const Icon(Icons.lock_outline),
                    title: const Text('Change Password'),
                    onTap: () {
                      if (_user?.email != null) {
                        _auth.sendPasswordResetEmail(email: _user!.email!);
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(
                                'Password reset link sent to ${_user!.email}')));
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text(
                                'This option is only available for email accounts.')));
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
                      label: Text(_startDate == null
                          ? 'Start Date'
                          : DateFormat.yMd().format(_startDate!)),
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                            context: context,
                            initialDate: _startDate ?? DateTime.now(),
                            firstDate: DateTime(2020),
                            lastDate: DateTime.now());
                        if (pickedDate != null) {
                          setState(() => _startDate = pickedDate);
                        }
                      },
                    ),
                    TextButton.icon(
                      icon: const Icon(Icons.calendar_today),
                      label: Text(_endDate == null
                          ? 'End Date'
                          : DateFormat.yMd().format(_endDate!)),
                      onPressed: () async {
                        final pickedDate = await showDatePicker(
                            context: context,
                            initialDate:
                                _endDate ?? _startDate ?? DateTime.now(),
                            firstDate: _startDate ?? DateTime(2020),
                            lastDate: DateTime.now());
                        if (pickedDate != null) {
                          setState(() => _endDate = pickedDate);
                        }
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
                      Expanded(
                          child: OutlinedButton.icon(
                              icon: const Icon(Icons.download),
                              label: const Text('Download'),
                              onPressed: () =>
                                  _generateAndProcessReport(share: false))),
                      const SizedBox(width: 16),
                      Expanded(
                          child: ElevatedButton.icon(
                              icon: const Icon(Icons.share),
                              label: const Text('Share'),
                              onPressed: () =>
                                  _generateAndProcessReport(share: true))),
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
      style: ElevatedButton.styleFrom(
          backgroundColor: Colors.red.shade400,
          padding: const EdgeInsets.symmetric(vertical: 16)),
      onPressed: () async {
        await GoogleSignIn().signOut();
        await _auth.signOut();
        if (context.mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      },
    );
  }
}
