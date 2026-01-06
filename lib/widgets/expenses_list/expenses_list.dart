import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/widgets/expenses_list/expense_item.dart';
import 'package:expense_tracker/providers/expenses_provider.dart';
import 'package:expense_tracker/widgets/new_expense.dart';
import 'package:expense_tracker/widgets/expenses_list/expense_detail_dialog.dart';

/// A widget that displays a scrollable list of expenses.
class ExpensesList extends StatelessWidget {
  const ExpensesList({super.key, required this.expenses});

  final List<Expense> expenses;

  /// Opens the edit overlay for a specific expense.
  void _openEditExpenseOverlay(BuildContext context, Expense expense) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => NewExpense(expenseToEdit: expense),
    );
  }

  @override
  Widget build(BuildContext context) {
    // A ListView.builder is highly efficient for long lists.
    return ListView.builder(
      itemCount: expenses.length,
      itemBuilder: (ctx, index) {
        final expense = expenses[index];
        // Dismissible allows for swipe-to-delete functionality.
        return TweenAnimationBuilder(
          duration: Duration(milliseconds: 300 + (index * 50)),
          tween: Tween<double>(begin: 0, end: 1),
          builder: (context, double value, child) {
            return Opacity(
              opacity: value,
              child: Transform.translate(
                offset: Offset(0, 20 * (1 - value)),
                child: child,
              ),
            );
          },
          child: Dismissible(
            key: ValueKey(expense.id),
            direction: DismissDirection.endToStart,
            background: Container(
              color: Theme.of(context).colorScheme.error.withOpacity(0.75),
              margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
              alignment: Alignment.centerRight,
              padding: const EdgeInsets.only(right: 20),
              child: const Icon(Icons.delete, color: Colors.white, size: 30),
            ),
            onDismissed: (direction) async {
              final provider = Provider.of<ExpensesProvider>(context, listen: false);
              try {
                 await provider.removeExpense(expense.id);
                 if (!context.mounted) return;
                 ScaffoldMessenger.of(context).clearSnackBars();
                 ScaffoldMessenger.of(context).showSnackBar(
                   SnackBar(
                     duration: const Duration(seconds: 4),
                     content: const Text('Expense deleted.'),
                     action: SnackBarAction(
                       label: 'Undo',
                       onPressed: () {
                         provider.addExpense(expense);
                       },
                     ),
                   ),
                 );
              } catch (e) {
                 if (!context.mounted) return;
                 ScaffoldMessenger.of(context).showSnackBar(
                   const SnackBar(content: Text('Failed to delete expense.')),
                 );
              }
            },
            child: GestureDetector(
              onTap: () {
                showDialog(
                  context: context,
                  builder: (ctx) => ExpenseDetailDialog(
                    expense: expense,
                    onEdit: () => _openEditExpenseOverlay(context, expense),
                  ),
                );
              },
              child: ExpenseItem(expense),
            ),
          ),
        );
      },
    );
  }
}
