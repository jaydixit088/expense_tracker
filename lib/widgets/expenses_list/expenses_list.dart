import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/widgets/expenses_list/expense_item.dart';
import 'package:expense_tracker/providers/expenses_provider.dart';
import 'package:expense_tracker/widgets/new_expense.dart';

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
        return Dismissible(
          key: ValueKey(expense.id),
          direction: DismissDirection.endToStart,
          background: Container(
            color: Theme.of(context).colorScheme.error.withOpacity(0.75),
            margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(Icons.delete, color: Colors.white, size: 30),
                SizedBox(width: 20),
              ],
            ),
          ),
          onDismissed: (direction) {
            // Remove the expense from the database via the provider.
            Provider.of<ExpensesProvider>(context, listen: false).removeExpense(expense.id);
            // Show a confirmation snackbar.
            ScaffoldMessenger.of(context).clearSnackBars();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(duration: Duration(seconds: 2), content: Text('Expense deleted.')),
            );
          },
          child: GestureDetector(
            onTap: () => _openEditExpenseOverlay(context, expense),
            child: ExpenseItem(expense),
          ),
        );
      },
    );
  }
}
