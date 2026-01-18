
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:open_file/open_file.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:expense_tracker/providers/expenses_provider.dart';
import 'package:expense_tracker/services/firestore_service.dart';
import 'package:expense_tracker/services/pdf_service.dart';
import 'package:expense_tracker/models/expense.dart';

import 'package:expense_tracker/screens/profile_screen.dart';
import 'package:expense_tracker/screens/organisation_screen.dart';
import 'package:expense_tracker/screens/auth_screen.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  final _firestoreService = FirestoreService();
  bool _isGeneratingReport = false;

  Future<void> _logout() async {
    await GoogleSignIn().signOut();
    await FirebaseAuth.instance.signOut();
    // Navigator logic handled by AuthGate usually, but we can force it
    // Assuming AuthGate listens to stream, popping drawer is enough or push replacement
    if (mounted) {
       // Just pop, the stream builder in AuthGate/Main will handle the switch to Welcome/Auth
       // But to be safe if checking manually:
       Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  Future<void> _generateReport(BuildContext context, {bool share = false}) async {
    // Show Date Range Picker
    final dateRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      helpText: 'Select Report Period',
    );

    if (dateRange == null) return;

    setState(() => _isGeneratingReport = true);
    // Close drawer to show loading? Or keeping drawer open. 
    // Usually fetching in background is better, but let's blocking UI for simplicity or show snackbar.
    Navigator.pop(context); // Close drawer
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Generating report...')));

    try {
      final user = FirebaseAuth.instance.currentUser;
      final provider = Provider.of<ExpensesProvider>(context, listen: false);
      if (user == null) return;

      final snapshot = await _firestoreService.getExpensesForPeriod(
        user.uid, 
        dateRange.start, 
        dateRange.end,
        organisationId: provider.selectedOrganisation?.id
      );

      final List<Expense> expenses = snapshot.docs
          .map((doc) => Expense.fromMap(doc.data() as Map<String, dynamic>))
          .toList();

      if (expenses.isEmpty) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('No expenses found for this period.')));
        return;
      }

      final pdfData = await generateExpensePdf(
          expenses,
          '${DateFormat.yMd().format(dateRange.start)} - ${DateFormat.yMd().format(dateRange.end)}',
          provider.currencySymbol);

      await _saveAndOpenPdf(context, pdfData, share);

    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isGeneratingReport = false);
    }
  }

  Future<void> _saveAndOpenPdf(BuildContext context, List<int> pdfData, bool share) async {
      final fileName = 'Expense-Report-${DateFormat('yyyyMMdd-HHmm').format(DateTime.now())}.pdf';
      Directory? directory;
      if (Platform.isAndroid) {
        try {
            directory = await getExternalStorageDirectory();
            // Try to put in Download if possible, mimicking ProfileScreen logic roughly
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
               directory = await getExternalStorageDirectory(); 
            }
        } catch(e) {
           directory = await getApplicationDocumentsDirectory();
        }
      } else {
        directory = await getApplicationDocumentsDirectory();
      }

      if (directory == null || !await directory.exists()) {
         directory = await getApplicationDocumentsDirectory();
      }

      final file = File('${directory.path}/$fileName');
      
      var status = await Permission.storage.status;
      if (!status.isGranted) {
        await Permission.storage.request(); 
      }

      try {
        await file.writeAsBytes(pdfData);
      } catch (e) {
        final fallbackDir = await getApplicationDocumentsDirectory();
        final fallbackFile = File('${fallbackDir.path}/$fileName');
        await fallbackFile.writeAsBytes(pdfData);
        if (share) {
             await Share.shareXFiles([XFile(fallbackFile.path)], text: 'Expense Report');
             return;
        }
        await OpenFile.open(fallbackFile.path);
        return;
      }

      if (share) {
        await Share.shareXFiles([XFile(file.path)], text: 'Expense Report');
      } else {
        await OpenFile.open(file.path);
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Report opened.')));
      }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final provider = Provider.of<ExpensesProvider>(context);
    final org = provider.selectedOrganisation;

    return Drawer(
      child: Column(
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(user?.displayName ?? 'User'),
            accountEmail: Text(user?.email ?? ''),
            currentAccountPicture: CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                (user?.displayName ?? 'U').substring(0, 1).toUpperCase(),
                style: const TextStyle(fontSize: 40.0, color: Colors.blue),
              ),
            ),
            decoration: BoxDecoration(
               gradient: LinearGradient(colors: [Colors.blue.shade700, Colors.blue.shade400])
            ),
          ),
          
          // Workspace Selector
          ListTile(
            title: const Text('Current Workspace', style: TextStyle(fontSize: 12, color: Colors.grey)),
            subtitle: Text(org == null ? 'Personal Expenses' : org.name, 
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            trailing: const Icon(Icons.swap_horiz, color: Colors.blue),
            onTap: () {
              Navigator.pop(context); // Close drawer
              Navigator.push(context, MaterialPageRoute(builder: (_) => const OrganisationScreen()));
            },
          ),
          if (org != null)
             ListTile(
               leading: const Icon(Icons.arrow_back),
               title: const Text('Switch to Personal'),
               onTap: () {
                 provider.selectOrganisation(null);
                 Navigator.pop(context);
               },
             ),
          
          const Divider(),

          // Features
          ListTile(
            leading: const Icon(Icons.person),
            title: const Text('Profile'),
            onTap: () {
               Navigator.pop(context);
               Navigator.push(context, MaterialPageRoute(builder: (_) => const ProfileScreen()));
            },
          ),
          ExpansionTile(
            leading: const Icon(Icons.business),
            title: const Text('Organisations'),
            children: [
               ListTile(
                 contentPadding: const EdgeInsets.only(left: 72),
                 title: const Text('Manage Organisations'),
                 onTap: () {
                    Navigator.pop(context);
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const OrganisationScreen()));
                 },
               ),
               // Add more quick links if needed
            ],
          ),
          
          const Divider(),

          // Reports
          ListTile(
            leading: const Icon(Icons.download),
            title: const Text('Download Report'),
            onTap: () => _generateReport(context, share: false),
          ),
           ListTile(
            leading: const Icon(Icons.share),
            title: const Text('Share Report'),
            onTap: () => _generateReport(context, share: true),
          ),

          const Divider(),

          // Settings
          SwitchListTile(
            secondary: const Icon(Icons.dark_mode),
            title: const Text('Dark Mode'),
            value: provider.themeMode == ThemeMode.dark,
            onChanged: (val) => provider.toggleTheme(val),
          ),

          const Spacer(),

          // Logout
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.red),
            title: const Text('Logout', style: TextStyle(color: Colors.red)),
            onTap: () {
               Navigator.pop(context);
               _logout();
            },
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }
}
