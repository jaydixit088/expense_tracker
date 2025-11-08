import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';

// Data and Providers
import 'package:expense_tracker/providers/expenses_provider.dart';
import 'package:expense_tracker/models/expense.dart';

// Screens
import 'package:expense_tracker/screens/profile_screen.dart';

// Widgets
import 'package:expense_tracker/widgets/new_expense.dart';
import 'package:expense_tracker/widgets/expenses_list/expenses_list.dart';
import 'package:expense_tracker/widgets/chart/pie_chart.dart';
import 'package:expense_tracker/widgets/summary/category_summary_row.dart';

/// The main screen that displays the user's expenses, charts, and summaries.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  
  /// Opens the modal bottom sheet to add a new expense.
  void _openAddExpenseOverlay() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the modal to take up more screen height
      builder: (_) => const NewExpense(),
    );
  }

  /// Shows a date picker and sets the filter in the provider.
  void _presentDatePicker() async {
    final now = DateTime.now();
    final expensesProvider = Provider.of<ExpensesProvider>(context, listen: false);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: expensesProvider.filterDate ?? now,
      firstDate: DateTime(now.year - 5), // Allow filtering up to 5 years back
      lastDate: now,
    );
    expensesProvider.setFilterDate(pickedDate);
  }

  @override
  Widget build(BuildContext context) {
    // We listen to the provider to rebuild the UI when filters change.
    final expensesProvider = Provider.of<ExpensesProvider>(context);
    final isCustomFilterActive = expensesProvider.categoryFilter == 'custom';

    return Scaffold(
      appBar: AppBar(
        leading: IconButton(
          icon: const Icon(Icons.person_outline),
          onPressed: () => Navigator.of(context).push(MaterialPageRoute(builder: (_) => const ProfileScreen())),
          tooltip: 'Profile',
        ),
        title: const Text('Expense Tracker'),
        actions: [
          // Clear Filter Button
          if (expensesProvider.filterDate != null || expensesProvider.categoryFilter != null)
            IconButton(
              icon: const Icon(Icons.clear),
              onPressed: () {
                expensesProvider.setFilterDate(null);
                expensesProvider.setCategoryFilter(null);
              },
              tooltip: 'Clear Filter',
            ),
          // Date Filter Button
          IconButton(
            icon: const Icon(Icons.calendar_today),
            onPressed: _presentDatePicker,
            tooltip: 'Filter by Date',
          ),
          // Custom Category Filter Button
          IconButton(
            icon: Icon(
              Icons.paid_outlined,
              color: isCustomFilterActive ? Theme.of(context).colorScheme.primary : null,
            ),
            onPressed: () => expensesProvider.setCategoryFilter(isCustomFilterActive ? null : 'custom'),
            tooltip: 'Filter Custom Expenses',
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _openAddExpenseOverlay,
        child: const Icon(Icons.add),
      ),
      // The main body uses a StreamBuilder to reactively display data from Firestore.
      // The `expensesStream` getter in the provider automatically rebuilds the query
      // whenever a filter is changed, so the UI just needs to listen.
      body: StreamBuilder<List<Expense>>(
        stream: expensesProvider.expensesStream,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return const Center(child: Text('An error occurred.'));
          }

          final displayedExpenses = snapshot.data ?? [];

          return Column(
            children: [
              // The Pie Chart shows data based on the currently displayed (filtered) expenses.
              ExpensesPieChart(expenses: displayedExpenses),

              // The Category Summary always shows data for ALL expenses.
              // To achieve this, we can wrap it in its own StreamBuilder that doesn't use filters.
              // (For simplicity now, we'll just pass the filtered list, but this is where
              // you would add a second stream if you wanted a true 'all-time' summary).
              CategorySummaryRow(expenses: displayedExpenses),
              
              // Informative text to show the active filter.
              if (expensesProvider.filterDate != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: Text('Showing expenses for ${DateFormat.yMd().format(expensesProvider.filterDate!)}'),
                ),

              // The main list of expenses.
              Expanded(
                child: displayedExpenses.isEmpty
                    ? const Center(child: Text('No expenses found.'))
                    : ExpensesList(expenses: displayedExpenses),
              ),
            ],
          );
        },
      ),
    );
  }
}
