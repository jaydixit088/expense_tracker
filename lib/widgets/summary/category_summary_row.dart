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
      final provider = Provider.of<ExpensesProvider>(context, listen: false);
      final selectedCategory = Provider.of<ExpensesProvider>(context).categoryFilter;

      // Calculate total
      double total = 0;
      if (categoryName == 'custom') {
        const defaults = ['food', 'travel', 'home', 'work'];
        total = expenses
            .where((exp) => !defaults.contains(exp.category))
            .fold(0.0, (sum, exp) => sum + exp.amount);
      } else {
        total = expenses
            .where((exp) => exp.category == categoryName)
            .fold(0.0, (sum, exp) => sum + exp.amount);
      }

      final isSelected = selectedCategory == categoryName;

      return TweenAnimationBuilder(
        duration: const Duration(milliseconds: 300),
        tween: Tween<double>(begin: isSelected ? 1.0 : 0.95, end: isSelected ? 1.1 : 1.0),
        curve: Curves.easeOutBack,
        builder: (context, double scale, child) {
          return Transform.scale(
            scale: scale,
            child: child,
          );
        },
        child: Container(
          width: 110,
          margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
          child: GestureDetector(
            onTap: () {
              provider.setCategoryFilter(isSelected ? null : categoryName);
            },
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeInOut,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              decoration: BoxDecoration(
                // Active: Color background. Inactive: Grey/White background.
                color: isSelected ? color : Theme.of(context).cardColor,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: isSelected ? color.withOpacity(0.4) : Colors.black12,
                    blurRadius: isSelected ? 8 : 4,
                    offset: const Offset(0, 4),
                  )
                ],
                border: Border.all(
                  color: isSelected ? Colors.transparent : Colors.grey.withOpacity(0.2),
                  width: 1,
                ),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    iconData,
                    color: isSelected ? Colors.white : color,
                    size: 26,
                  ),
                  const SizedBox(height: 8),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '${provider.currencySymbol}${total.toStringAsFixed(0)}',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: isSelected ? Colors.white : Theme.of(context).textTheme.bodyMedium?.color,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // --- MAIN WIDGET BUILD ---
    return Container(
      height: 90,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            // Build a card for each of the default categories.
            // We look up the icon from our global `categoryIcons` map.
            buildCategoryCard(Category.food.name, categoryIcons[Category.food.name]!, Colors.orange),
            buildCategoryCard(Category.travel.name, categoryIcons[Category.travel.name]!, Colors.blue),
            buildCategoryCard(Category.home.name, categoryIcons[Category.home.name]!, Colors.purple),
            buildCategoryCard(Category.work.name, categoryIcons[Category.work.name]!, Colors.green),
            // Added 'Other' category for generic expenses
            buildCategoryCard('custom', categoryIcons['custom']!, Colors.deepPurple),
          ],
        ),
      ),
    );
  }
}
