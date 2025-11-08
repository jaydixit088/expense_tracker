import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/providers/expenses_provider.dart';

/// A horizontal row of cards, each summarizing a default expense category.
/// Tapping a card toggles the category filter in the `ExpensesProvider`.
class CategorySummaryRow extends StatelessWidget {
  const CategorySummaryRow({super.key, required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    
    // --- LOCAL WIDGET HELPER ---
    // This is a great pattern for creating complex, repetitive UI elements
    // without creating an entirely new StatefulWidget.
    Widget buildCategoryCard(String categoryName, IconData iconData, Color color) {
      // Use the provider to get the current filter state and to set a new one.
      final provider = Provider.of<ExpensesProvider>(context, listen: false);
      // We `listen: true` here for the filter so the card can rebuild and show its selected state.
      final selectedCategory = Provider.of<ExpensesProvider>(context).categoryFilter;

      // Calculate the total for this specific category.
      final total = expenses
          .where((exp) => exp.category == categoryName)
          .fold(0.0, (sum, exp) => sum + exp.amount);

      final isSelected = selectedCategory == categoryName;

      return Expanded(
        child: GestureDetector(
          onTap: () {
            // If the card is already selected, tapping it again clears the filter.
            // Otherwise, it sets the filter to this category.
            provider.setCategoryFilter(isSelected ? null : categoryName);
          },
          // AnimatedContainer provides a smooth transition for selection effects.
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            margin: const EdgeInsets.symmetric(horizontal: 4),
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.white : Colors.white.withOpacity(0.8),
              borderRadius: BorderRadius.circular(15),
              border: isSelected ? Border.all(color: color, width: 2.5) : Border.all(color: Colors.white.withOpacity(0.5)),
              boxShadow: isSelected ? [BoxShadow(color: color.withOpacity(0.5), blurRadius: 8, offset: const Offset(0, 4))] : [],
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  iconData,
                  color: isSelected ? color : Colors.black54,
                  size: 28,
                ),
                const SizedBox(height: 8),
                // FittedBox ensures the text shrinks to fit if it's too long.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '${provider.currencySymbol}${total.toStringAsFixed(0)}',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                      color: isSelected ? Colors.black87 : Colors.black54,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    // --- MAIN WIDGET BUILD ---
    return Container(
      height: 90,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          // Build a card for each of the default categories.
          // We look up the icon from our global `categoryIcons` map.
          buildCategoryCard(Category.food.name, categoryIcons[Category.food.name]!, Colors.orange),
          buildCategoryCard(Category.travel.name, categoryIcons[Category.travel.name]!, Colors.blue),
          buildCategoryCard(Category.leisure.name, categoryIcons[Category.leisure.name]!, Colors.pink),
          buildCategoryCard(Category.work.name, categoryIcons[Category.work.name]!, Colors.green),
        ],
      ),
    );
  }
}
