import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/providers/expenses_provider.dart';

/// A widget that displays a single expense item in a Card.
/// This is the main component of the expenses list.
class ExpenseItem extends StatelessWidget {
  const ExpenseItem(this.expense, {super.key});

  final Expense expense;

  @override
  Widget build(BuildContext context) {
    // We use `listen: false` here because this widget doesn't need to rebuild
    // when the currency symbol changes globally. It will get the latest symbol
    // whenever the parent list rebuilds.
    final currencySymbol = Provider.of<ExpensesProvider>(context, listen: false).currencySymbol;

    // --- LOGIC FOR DISPLAYING THE CORRECT CATEGORY ICON ---
    // 1. Check if the expense's category is one of the default enum values.
    final isDefaultCategory = Category.values.any((e) => e.name == expense.category);
    // 2. If it is, get the specific icon from the map.
    // 3. If not, it's a custom category, so fall back to the generic 'custom' icon.
    // The '!' is safe because we know 'custom' is in the map.
    final icon = isDefaultCategory ? categoryIcons[expense.category]! : categoryIcons['custom']!;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            // Display the determined icon.
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            // Expanded takes up the remaining space to prevent overflow.
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    expense.title,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(expense.category.toUpperCase(), style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            // This column is for the amount and date, aligned to the right.
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$currencySymbol${expense.amount.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(expense.formattedDate),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
