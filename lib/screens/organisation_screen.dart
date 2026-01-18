
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:expense_tracker/models/organisation.dart';
import 'package:expense_tracker/models/invitation.dart'; // Import Invitation
import 'package:expense_tracker/services/firestore_service.dart';
import 'package:expense_tracker/providers/expenses_provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:expense_tracker/widgets/organisation_item.dart';

class OrganisationScreen extends StatefulWidget {
  const OrganisationScreen({super.key});

  @override
  State<OrganisationScreen> createState() => _OrganisationScreenState();
}

class _OrganisationScreenState extends State<OrganisationScreen> {
  final _firestoreService = FirestoreService();
  final _auth = FirebaseAuth.instance;

  String? _encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  Future<void> _acceptInvite(Invitation invite) async {
      try {
          final user = _auth.currentUser;
          if (user != null) {
              await _firestoreService.acceptInvitation(invite, user.uid);
              if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation Accepted!')));
                  setState(() {}); // Refresh UI
              }
          }
      } catch (e) {
          if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
  }

  Future<void> _rejectInvite(Invitation invite) async {
      try {
          await _firestoreService.rejectInvitation(invite.id);
          if (mounted) {
               ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation Rejected')));
               setState(() {});
          }
      } catch (e) {
           if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
  }




  Future<void> _deleteOrg(Organisation org) async {
    try {
      await _firestoreService.deleteOrganisation(org.id);
      if (mounted) setState(() {}); 
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error deleting organisation: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = _auth.currentUser;
    if (user == null) return const Scaffold(body: Center(child: Text('Please login')));

    return Scaffold(
      appBar: AppBar(title: const Text('My Organisations')),
      body: Column(
        children: [
            // Pending Invitations Section
            StreamBuilder<List<Invitation>>(
                stream: _firestoreService.getInvitationsStream(user.email ?? ''),
                builder: (context, snapshot) {
                    if (snapshot.hasError) return Text('Error loading invites: ${snapshot.error}');
                    if (!snapshot.hasData || snapshot.data!.isEmpty) return const SizedBox.shrink();

                    final invites = snapshot.data!;
                    return Card(
                      color: Colors.orange.shade50,
                      margin: const EdgeInsets.all(8.0),
                      child: ExpansionTile(
                          initiallyExpanded: true,
                          leading: const Icon(Icons.mail, color: Colors.orange),
                          title: Text('Pending Invitations (${invites.length})', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
                          children: invites.map((invite) => ListTile(
                              title: Text(invite.orgName, style: const TextStyle(fontWeight: FontWeight.bold)),
                              subtitle: Text('Invited by: ${invite.inviterName}\nAccess: ${invite.permission == 'readwrite' ? 'Read & Write' : 'Read Only'}'),
                              isThreeLine: true,
                              trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                      IconButton(
                                          icon: const Icon(Icons.check_circle, color: Colors.green, size: 30),
                                          onPressed: () => _acceptInvite(invite),
                                          tooltip: 'Accept',
                                      ),
                                      IconButton(
                                          icon: const Icon(Icons.cancel, color: Colors.red, size: 30),
                                          onPressed: () => _rejectInvite(invite),
                                          tooltip: 'Reject',
                                      ),
                                  ],
                              ),
                          )).toList(),
                      ),
                    );
                },
            ),

            // Organisation List
            Expanded(
              child: FutureBuilder<List<Organisation>>(
                future: _firestoreService.getUserOrganisations(user.uid),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snapshot.hasError) {
                    return Center(child: Text('Error: ${snapshot.error}'));
                  }
                  final orgs = snapshot.data ?? [];
        
                  if (orgs.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                           Icon(Icons.business, size: 64, color: Colors.grey[300]),
                           const SizedBox(height: 16),
                           const Text('No organisations found.', style: TextStyle(fontSize: 18, color: Colors.grey)),
                           const SizedBox(height: 16),
                           ElevatedButton.icon(
                             icon: const Icon(Icons.add),
                             onPressed: _showCreateOrgDialog,
                             label: const Text('Create New Organisation'),
                             style: ElevatedButton.styleFrom(
                               padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                             ),
                           )
                        ],
                      ),
                    );
                  }
        
                  return ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: orgs.length,
                    itemBuilder: (context, index) {
                      final org = orgs[index];
                      final isAdmin = org.adminId == user.uid;
                      
                      return OrganisationItem(
                        org: org,
                        isAdmin: isAdmin,
                        currentUserId: user.uid,
                        onTap: () {
                           // Switch context to this organisation
                           Provider.of<ExpensesProvider>(context, listen: false).selectOrganisation(org);
                           Navigator.pop(context); // Close Manage Screen
                           Navigator.of(context).popUntil((route) => route.isFirst); // Go back to Home
                        },
                        onDelete: _deleteOrg,
                        onInvite: _showInviteDialog,
                      );
                    },
                  );
                },
              ),
            ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _showCreateOrgDialog,
        child: const Icon(Icons.add),
        tooltip: 'Create Organisation',
      ),
    );
  }

  void _showCreateOrgDialog() {
    final nameController = TextEditingController();
    final budgetController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Create Organisation'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Company Name'),
            ),
            TextField(
              controller: budgetController,
              decoration: const InputDecoration(labelText: 'Monthly Expenses (Budget)'),
              keyboardType: TextInputType.number,
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () async {
              final name = nameController.text.trim();
              final budget = double.tryParse(budgetController.text) ?? 0.0;
              final user = _auth.currentUser;

              if (name.isNotEmpty && user != null) {
                // Determine Admin Name (display name or email)
                final adminName = user.displayName ?? user.email ?? 'Admin';
                
                final newOrg = Organisation(
                  id: DateTime.now().millisecondsSinceEpoch.toString(), // Simple ID gen
                  name: name,
                  adminId: user.uid,
                  adminName: adminName,
                  monthlyExpenses: budget,
                  members: [user.uid],
                  permissions: {user.uid: 'readwrite'}, // Admin has readwrite
                );

                await _firestoreService.createOrganisation(newOrg);
                if (mounted) {
                   Navigator.pop(ctx);
                   setState(() {}); // Refresh list
                }
              }
            },
            child: const Text('Create'),
          ),
        ],
      ),
    );
  }

  void _showInviteDialog(Organisation org) {
    final emailController = TextEditingController();
    String permission = 'readonly';
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('Manage Members & Invitations'),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(labelText: 'User Email'),
                    keyboardType: TextInputType.emailAddress,
                  ),
                  const SizedBox(height: 16),
                  DropdownButton<String>(
                    value: permission,
                    items: const [
                      DropdownMenuItem(value: 'readonly', child: Text('Read Only')),
                      DropdownMenuItem(value: 'readwrite', child: Text('Read & Write')),
                    ],
                    onChanged: (val) {
                      if (val != null) setState(() => permission = val);
                    },
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: isLoading ? null : () async {
                      final email = emailController.text.trim();
                      if (email.isNotEmpty) {
                        setState(() => isLoading = true);
                        try {
                            final userProfile = await _firestoreService.getUserByEmail(email);
                            if (userProfile != null) {
                                // Check if already a member
                                if (org.members.contains(userProfile.uid)) {
                                    setState(() => isLoading = false);
                                    if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('User is already a member.')));
                                    return;
                                }

                                // Create Invitation 
                                final invitation = Invitation(
                                    id: DateTime.now().millisecondsSinceEpoch.toString(),
                                    orgId: org.id,
                                    orgName: org.name,
                                    inviterName: org.adminName,
                                    email: email,
                                    permission: permission,
                                    status: 'pending',
                                );
                                await _firestoreService.sendInvitation(invitation);
                                
                                // Send Email Notification
                                final Uri emailLaunchUri = Uri(
                                    scheme: 'mailto',
                                    path: email,
                                    query: _encodeQueryParameters(<String, String>{
                                    'subject': 'Invitation to join ${org.name} on KharchaGuru',
                                    'body': 'Hello,\n\n'
                                            'You have been invited to join the organisation "${org.name}" on KharchaGuru.\n\n'
                                            'Access Level: ${permission == 'readonly' ? 'Read Only' : 'Read & Write'}\n\n'
                                            'Please open the KharchaGuru app to accept the invitation and view shared expenses.\n\n'
                                            'Best regards,\nKharchaGuru Team'
                                    }),
                                );
                            
                                try {
                                    await launchUrl(emailLaunchUri);
                                } catch (e) {
                                    debugPrint('Could not launch email client: $e');
                                }

                                emailController.clear(); // Clear input
                                setState(() => isLoading = false);
                                if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation sent successfully!')));
                            } else {
                                // User not found in DB
                                setState(() => isLoading = false);
                                // Ask to invite via email anyway
                                if (mounted) {
                                    showDialog(
                                        context: context,
                                        builder: (context) => AlertDialog(
                                        title: const Text('User Not Found'),
                                        content: const Text(
                                            'This email is not registered with KharchaGuru.\n'
                                            'Would you like to send them an invitation customized to join the app?'
                                        ),
                                        actions: [
                                            TextButton(onPressed: () => Navigator.pop(context), child: const Text('No')),
                                            TextButton(
                                            onPressed: () async {
                                                Navigator.pop(context);
                                                final Uri inviteUri = Uri(
                                                scheme: 'mailto',
                                                path: email,
                                                query: _encodeQueryParameters(<String, String>{
                                                    'subject': 'Join KharchaGuru Expense Tracker',
                                                    'body': 'Hi,\n\nI want to share expenses with you on KharchaGuru.\n'
                                                            'Please download the app and sign up with this email: $email.\n\n'
                                                            'Once you are registered, let me know so I can add you to the organisation "${org.name}".'
                                                }),
                                                );
                                                try {
                                                await launchUrl(inviteUri);
                                                } catch (e) {
                                                // ignore
                                                }
                                            }, 
                                            child: const Text('Yes, Send Invite')
                                            ),
                                        ],
                                        )
                                    );
                                }
                            }
                        } catch (e) {
                            setState(() => isLoading = false);
                            if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error inviting user: $e')));
                        }
                      }
                    },
                    child: isLoading 
                        ? const SizedBox(
                            width: 20, 
                            height: 20, 
                            child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)
                          ) 
                        : const Text('Send Invitation'),
                  ),
                  const Divider(),
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: Text('Members & Invitations', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                      height: 150, // Fixed height for list
                      child: StreamBuilder<List<Invitation>>(
                          stream: _firestoreService.getOrgInvitationsStream(org.id),
                          builder: (context, snapshot) {
                              if (snapshot.connectionState == ConnectionState.waiting) {
                                  return const Center(child: CircularProgressIndicator());
                              }
                              final invites = snapshot.data ?? [];
                              if (invites.isEmpty) {
                                  return const Center(child: Text('No members or invitations.'));
                              }
                              return ListView.builder(
                                  itemCount: invites.length,
                                  itemBuilder: (context, index) {
                                      final invite = invites[index];
                                      Color statusColor = Colors.grey;
                                      if (invite.status == 'accepted') statusColor = Colors.green;
                                      if (invite.status == 'rejected') statusColor = Colors.red;
                                      if (invite.status == 'pending') statusColor = Colors.orange;

                                      return ListTile(
                                          contentPadding: EdgeInsets.zero,
                                          title: Text(invite.email, style: const TextStyle(fontSize: 14)),
                                          subtitle: Text(
                                              '${invite.permission == 'readwrite' ? 'Read/Write' : 'Read-only'} • ${invite.status.toUpperCase()}',
                                              style: TextStyle(fontSize: 12, color: statusColor, fontWeight: FontWeight.bold)
                                          ),
                                          trailing: Row(
                                            mainAxisSize: MainAxisSize.min,
                                            children: [
                                              // Revoke/Delete for Pending
                                              if (invite.status == 'pending')
                                                IconButton(
                                                  icon: const Icon(Icons.delete_outline, color: Colors.grey, size: 20),
                                                  onPressed: () async {
                                                     await _firestoreService.deleteInvitation(invite.id);
                                                     if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation revoked.')));
                                                  },
                                                  tooltip: 'Revoke Invitation',
                                                ),
                                              
                                              // Actions for Accepted (Manage Member)
                                              if (invite.status == 'accepted') ...[
                                                  IconButton(
                                                    icon: const Icon(Icons.edit, color: Colors.blue, size: 20),
                                                    onPressed: () {
                                                        // Find member UID logic is hard since Invitation doesn't store UID until Accepted?
                                                        // Wait, Invitation doesn't have UID field explicitly usually, but we need it.
                                                        // Actually, we need UID for 'removeMember' call which updates Organisation.
                                                        // 'removeMember(orgId, memberUid, inviteId)'
                                                        // The invitation doc doesn't strictly have the UID unless we saved it.
                                                        // But we can look up user by email again? Or maybe we can rely on `members` list?
                                                        // Actually, we don't have the UID just from the Invitation object here unless I update Invitation model to store 'inviteeUid' on acceptance.
                                                        // Let's check Invitation model.
                                                        _showManageMemberDialog(org, invite);
                                                    },
                                                    tooltip: 'Manage Member',
                                                  ),
                                              ],
                                              
                                              if (invite.status == 'rejected')
                                                const Icon(Icons.close, color: Colors.red, size: 16),
                                            ],
                                          ),
                                      );
                                  },
                              );
                          },
                      ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
            ],
          );
        },
      ),
    );
  }

  void _showManageMemberDialog(Organisation org, Invitation invite) async {
      // We need the UID of the member.
      // Since Invitation object might not have it (check model), we might need to fetch it by email.
      // FirestoreService.getUserByEmail(invite.email)
      
      final userProfile = await _firestoreService.getUserByEmail(invite.email);
      if (userProfile == null) {
          if(mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error: User not found in database.')));
          return;
      }
      final memberUid = userProfile.uid;

      if (!mounted) return;

      showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
              title: Text('Manage ${invite.email}'),
              content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                      ElevatedButton(
                          onPressed: () async {
                              // Toggle permission
                              final newPerm = invite.permission == 'readonly' ? 'readwrite' : 'readonly';
                              await _firestoreService.updateMemberPermission(org.id, memberUid, invite.id, newPerm);
                              if (mounted) {
                                  Navigator.pop(ctx);
                                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Permission changed to $newPerm')));
                              }
                          }, 
                          child: Text('Change to ${invite.permission == 'readonly' ? 'Read & Write' : 'Read Only'}')
                      ),
                      const SizedBox(height: 12),
                      ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                          onPressed: () async {
                              final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (c) => AlertDialog(
                                      title: const Text('Remove Member?'),
                                      content: const Text('Are you sure you want to remove this member?'),
                                      actions: [
                                          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('Cancel')),
                                          TextButton(onPressed: () => Navigator.pop(c, true), child: const Text('Remove')),
                                      ],
                                  )
                              );
                              if (confirm == true) {
                                  await _firestoreService.removeMember(org.id, memberUid, invite.id);
                                  if (mounted) {
                                      Navigator.pop(ctx);
                                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Member removed.')));
                                  }
                              }
                          }, 
                          child: const Text('Remove Member')
                      ),
                  ],
              ),
              actions: [
                  TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
              ],
          )
      );
  }
}
