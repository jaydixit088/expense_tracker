import 'package:flutter/material.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/widgets/chart/chart_bar.dart';

/// A widget that displays a bar chart summarizing expenses for default categories.
///
/// NOTE: This widget has largely been superseded by the more modern `ExpensesPieChart`,
/// but is preserved here for completeness.
class Chart extends StatelessWidget {
  const Chart({super.key, required this.expenses});

  final List<Expense> expenses;

  /// A getter that groups all expenses into buckets for each default category.
  List<ExpenseBucket> get buckets {
    return Category.values
        .map((category) => ExpenseBucket.forCategory(expenses, category))
        .toList();
  }

  /// A getter that finds the highest total expense amount among all buckets.
  /// This is used to scale the chart bars correctly.
  double get maxTotalExpense {
    return buckets.fold(0.0, (max, bucket) {
      return bucket.totalExpenses > max ? bucket.totalExpenses : max;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = MediaQuery.of(context).platformBrightness == Brightness.dark;
    
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      width: double.infinity,
      height: 180,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary.withOpacity(0.3),
            Theme.of(context).colorScheme.primary.withOpacity(0.0),
          ],
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
        ),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                // Create a ChartBar for each bucket.
                for (final bucket in buckets)
                  ChartBar(
                    fill: maxTotalExpense == 0
                        ? 0
                        : bucket.totalExpenses / maxTotalExpense,
                  )
              ],
            ),
          ),
          const SizedBox(height: 12),
          // Row of icons at the bottom of the chart.
          Row(
            children: buckets.map((bucket) {
              // --- CORRECTED ICON LOGIC ---
              // We must use the `name` of the enum as the key for the map.
              final icon = categoryIcons[bucket.category.name];
              
              return Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4),
                  child: Icon(
                    icon,
                    color: isDarkMode
                        ? Theme.of(context).colorScheme.secondary
                        : Theme.of(context).colorScheme.primary.withOpacity(0.7),
                  ),
                ),
              );
            }).toList(),
          )
        ],
      ),
    );
  }
}
