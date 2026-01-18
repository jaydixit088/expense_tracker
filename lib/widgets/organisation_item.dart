import 'package:flutter/material.dart';
import 'package:expense_tracker/models/organisation.dart';
import 'package:expense_tracker/widgets/dissolving_view.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/providers/expenses_provider.dart';

class OrganisationItem extends StatefulWidget {
  final Organisation org;
  final bool isAdmin;
  final String currentUserId;
  final Future<void> Function(Organisation) onDelete;
  final VoidCallback onTap;
  final Function(Organisation) onInvite;

  const OrganisationItem({
    super.key,
    required this.org,
    required this.isAdmin,
    required this.currentUserId,
    required this.onDelete,
    required this.onTap,
    required this.onInvite,
  });

  @override
  State<OrganisationItem> createState() => _OrganisationItemState();
}

class _OrganisationItemState extends State<OrganisationItem> {
  final GlobalKey<DissolvingViewState> _dissolveKey = GlobalKey();

  Future<void> _handleDelete() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Organisation?'),
        content: Text('Are you sure you want to delete "${widget.org.name}"? This cannot be undone.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      // Trigger dissolve animation
      _dissolveKey.currentState?.dissolve();
    }
  }

  @override
  Widget build(BuildContext context) {
    return DissolvingView(
      key: _dissolveKey,
      onDissolved: () {
        widget.onDelete(widget.org);
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: widget.isAdmin 
                ? [Colors.blue.shade800, Colors.blue.shade600] 
                : [Colors.indigo.shade700, Colors.indigo.shade500],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 4),
            )
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        backgroundColor: Colors.white.withOpacity(0.2),
                        radius: 24,
                        child: Text(
                          widget.org.name.substring(0, 1).toUpperCase(),
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.org.name,
                              style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                            ),
                            Text(
                              widget.isAdmin ? 'You are Admin' : 'Admin: ${widget.org.adminName}',
                              style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                      if (widget.isAdmin) ...[
                        IconButton(
                            icon: const Icon(Icons.person_add, color: Colors.white),
                            onPressed: () => widget.onInvite(widget.org),
                            tooltip: 'Invite Members',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete, color: Colors.white54),
                          onPressed: _handleDelete,
                          tooltip: 'Delete Organisation',
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 16),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Monthly Budget', style: TextStyle(color: Colors.blue.shade100, fontSize: 12)),
                          Text(
                            '${Provider.of<ExpensesProvider>(context, listen: false).currencySymbol}${widget.org.monthlyExpenses.toStringAsFixed(0)}',
                            style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold),
                          ),
                        ],
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.people, color: Colors.white, size: 16),
                            const SizedBox(width: 4),
                            Text(
                              '${widget.org.members.length} Members',
                              style: const TextStyle(color: Colors.white, fontSize: 12),
                            ),
                          ],
                        ),
                      )
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
