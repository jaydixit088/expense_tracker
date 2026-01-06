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
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 16),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: LinearGradient(
            colors: [
              Theme.of(context).cardColor,
              Theme.of(context).cardColor.withOpacity(0.95),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                // Display the determined icon.
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: Theme.of(context).colorScheme.primary, size: 28),
                ),
                const SizedBox(width: 16),
                // Expanded takes up the remaining space to prevent overflow.
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        expense.title,
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold, fontSize: 18),
                      ),
                      const SizedBox(height: 4),
                      Text(expense.category.toUpperCase(), 
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: 1.1)
                      ),
                       if (expense.additionalInfo != null && expense.additionalInfo!.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Text(
                          expense.additionalInfo!,
                          style: Theme.of(context).textTheme.bodySmall?.copyWith(fontStyle: FontStyle.italic, color: Colors.grey[600]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                // This column is for the amount and date, aligned to the right.
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '$currencySymbol${expense.amount.toStringAsFixed(2)}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold, 
                        color: Theme.of(context).colorScheme.primary,
                        fontSize: 16
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(Icons.calendar_today, size: 12, color: Colors.grey),
                        const SizedBox(width: 4),
                        Text(expense.formattedDate, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
