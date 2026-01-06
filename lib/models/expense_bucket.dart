// The 'part of' directive is not needed here as this is a standalone class.
// We import the 'expense.dart' file to use the Expense class.
import 'package:expense_tracker/models/expense.dart';

/// A helper class designed for UI purposes, specifically for grouping expenses
/// by category and calculating their total sum. This is a great pattern for
/// preparing data for widgets like charts or summary views.
class ExpenseBucket {
  /// The main constructor for creating a bucket with a pre-filtered list of expenses.
  const ExpenseBucket({
    required this.category,
    required this.expenses,
  });

  /// A utility constructor that creates a bucket for a specific category
  /// by filtering a list of all expenses.
  ExpenseBucket.forCategory(List<Expense> allExpenses, this.category)
      // The `where` method filters the list. It's more efficient than a for loop.
      //
      // --- CRITICAL FIX ---
      // We must compare the `expense.category` (which is a String) to the
      // `name` of the enum `this.category` (which is also a String).
      // Comparing `expense.category == this.category` would be a type mismatch error.
      : expenses = allExpenses
            .where((expense) => expense.category == category.name)
            .toList();

  // The category this bucket represents (e.g., Category.food).
  final Category category;
  // The list of expenses that belong to this category.
  final List<Expense> expenses;

  /// A getter to calculate the total sum of all expenses in the bucket.
  double get totalExpenses {
    // A more modern and concise way to sum a list of values.
    // `fold` starts with an initial value (0) and iterates through the list,
    // adding each expense's amount to the running total.
    return expenses.fold(0, (sum, expense) => sum + expense.amount);
  }
}
