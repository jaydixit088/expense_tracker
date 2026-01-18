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
import 'package:expense_tracker/widgets/app_drawer.dart';

/// The main screen that displays the user's expenses, charts, and summaries.
class ExpensesScreen extends StatefulWidget {
  const ExpensesScreen({super.key});

  @override
  State<ExpensesScreen> createState() => _ExpensesScreenState();
}

class _ExpensesScreenState extends State<ExpensesScreen> {
  bool _isSearching = false;
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }
  
  /// Opens the modal bottom sheet to add a new expense.
  void _openAddExpenseOverlay() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows the modal to take up more screen height
      builder: (_) => const NewExpense(),
    );
  }

  /// Shows a date picker and sets the filter in the provider.
  /// Shows a date picker and sets the filter in the provider.
  void _presentDatePicker() async {
    final now = DateTime.now();
    final expensesProvider = Provider.of<ExpensesProvider>(context, listen: false);
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: expensesProvider.filterDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
      helpText: 'SELECT MONTH', // Guide the user
      fieldHintText: 'Month/Year',
    );
    // The provider now handles monthly filtering using any date within that month.
    expensesProvider.setFilterDate(pickedDate);
  }

  void _showEditBudgetDialog() {
    final provider = Provider.of<ExpensesProvider>(context, listen: false);
    final controller = TextEditingController(text: provider.monthlyBudget.toString());

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Set Monthly Budget'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            prefixText: provider.currencySymbol,
            labelText: 'Budget Amount',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () {
              final newBudget = double.tryParse(controller.text);
              if (newBudget != null && newBudget >= 0) {
                provider.setMonthlyBudget(newBudget);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // We listen to the provider to rebuild the UI when filters change.
    final expensesProvider = Provider.of<ExpensesProvider>(context);

    return Scaffold(
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: _isSearching 
          ? TextField(
              controller: _searchController,
              autofocus: true,
              style: const TextStyle(color: Colors.black, fontSize: 18),
              decoration: const InputDecoration(
                hintText: 'Search expenses...',
                border: InputBorder.none,
                hintStyle: TextStyle(color: Colors.black54),
                contentPadding: EdgeInsets.zero,
                filled: false,
              ),
              onChanged: (value) => Provider.of<ExpensesProvider>(context, listen: false).setSearchQuery(value),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                 Text(expensesProvider.selectedOrganisation?.name ?? 'KharchaGuru'),
                 if (expensesProvider.selectedOrganisation != null)
                   const Text('Organisation', style: TextStyle(fontSize: 10, fontWeight: FontWeight.normal)),
              ],
            ),
        actions: [
          // Search Toggle
          IconButton(
            icon: Icon(_isSearching ? Icons.close : Icons.search),
            onPressed: () {
              setState(() {
                _isSearching = !_isSearching;
                if (!_isSearching) {
                  _searchController.clear();
                  Provider.of<ExpensesProvider>(context, listen: false).setSearchQuery('');
                }
              });
            },
            tooltip: 'Search',
          ),
          // Clear Filter Button
          if (expensesProvider.filterDate != null || expensesProvider.categoryFilter != null)
            IconButton(
              icon: const Icon(Icons.filter_list_off),
              onPressed: () {
                expensesProvider.setFilterDate(null);
                expensesProvider.setCategoryFilter(null);
              },
              tooltip: 'Clear Filter',
            ),
          // Date Filter Button
          IconButton(
            icon: const Icon(Icons.calendar_month),
            onPressed: _presentDatePicker,
            tooltip: 'Select Month',
          ),
        ],
      ),
      floatingActionButton: expensesProvider.canEdit ? FloatingActionButton(
        onPressed: _openAddExpenseOverlay,
        child: const Icon(Icons.add),
      ) : null,
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
            return Center(child: Text('An error occurred: ${snapshot.error}'));
          }

          final displayedExpenses = snapshot.data ?? [];

          return Column(
            children: [
              // Budget Progress Indicator (Advanced Feature)
              _buildBudgetCard(expensesProvider, displayedExpenses),
              
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
                  child: Text(
                    'Viewing expenses for ${DateFormat.yMMMM().format(expensesProvider.filterDate!)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
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

  Widget _buildBudgetCard(ExpensesProvider provider, List<Expense> expenses) {
    final totalSpent = expenses.fold(0.0, (sum, exp) => sum + exp.amount);
    final budget = provider.monthlyBudget;
    final percentage = budget > 0 ? (totalSpent / budget).clamp(0.0, 1.0) : 0.0;
    final isOverBudget = totalSpent > budget;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
      child: TweenAnimationBuilder<double>(
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOut,
        tween: Tween<double>(begin: 0, end: 1),
        builder: (context, val, child) {
          return Transform.scale(
            scale: 0.95 + (0.05 * val),
            child: Opacity(opacity: val, child: child),
          );
        },
        child: Card(
          elevation: 6,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              gradient: LinearGradient(
                colors: [Colors.blue.shade50, Colors.white],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Monthly Budget', 
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(color: Colors.grey[700], fontWeight: FontWeight.bold)
                    ),
                    IconButton(
                      icon: const Icon(Icons.edit, size: 20, color: Colors.blueAccent),
                      onPressed: _showEditBudgetDialog,
                      tooltip: 'Edit Budget',
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                   children: [
                    Text(
                      '${provider.currencySymbol}${totalSpent.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        color: isOverBudget ? Colors.red : Colors.blueGrey[800],
                        fontSize: 28,
                      ),
                    ),
                    Text(
                      ' / ${provider.currencySymbol}${budget.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.w500,
                        color: Colors.grey[600],
                        fontSize: 16,
                      ),
                    ),
                   ]
                ),
                const SizedBox(height: 16),
                TweenAnimationBuilder<double>(
                  duration: const Duration(milliseconds: 1000),
                  curve: Curves.easeOutCubic,
                  tween: Tween<double>(begin: 0, end: percentage),
                  builder: (context, value, _) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: value,
                            backgroundColor: Colors.grey[200],
                            valueColor: AlwaysStoppedAnimation<Color>(isOverBudget ? Colors.red : (value > 0.8 ? Colors.orange : Colors.green)),
                            minHeight: 10,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text('${(value * 100).toInt()}%', style: TextStyle(fontSize: 12, color: Colors.grey[600])),
                      ],
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
