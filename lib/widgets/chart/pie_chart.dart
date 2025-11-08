import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:google_fonts/google_fonts.dart'; // We'll use this for robust font rendering

import 'package:expense_tracker/models/expense.dart';
// Note: We don't actually need ExpenseBucket here, we can do the grouping directly.

/// A widget that displays a pie chart summarizing expenses by category.
class ExpensesPieChart extends StatelessWidget {
  const ExpensesPieChart({super.key, required this.expenses});

  final List<Expense> expenses;

  @override
  Widget build(BuildContext context) {
    if (expenses.isEmpty) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text('No expense data to display.'),
      );
    }

    // --- DATA GROUPING AND AGGREGATION ---
    // Use a `fold` operation to create a map of category totals.
    // This is a concise and modern way to aggregate data.
    final Map<String, double> categoryTotals = expenses.fold({}, (Map<String, double> map, expense) {
      map[expense.category] = (map[expense.category] ?? 0) + expense.amount;
      return map;
    });

    final double totalExpenses = categoryTotals.values.fold(0.0, (sum, amount) => sum + amount);

    // --- CHART SECTION GENERATION ---
    List<PieChartSectionData> showingSections() {
      // A more extensive and visually appealing color list.
      const List<Color> colors = [
        Colors.blue, Colors.orange, Colors.pink, Colors.green, Colors.purple, 
        Colors.teal, Colors.red, Colors.amber, Colors.indigo, Colors.cyan
      ];
      int colorIndex = 0;

      return categoryTotals.entries.map((entry) {
        final percentage = (entry.value / totalExpenses) * 100;
        final sectionColor = colors[colorIndex % colors.length];
        colorIndex++;

        // The same robust icon logic from ExpenseItem.
        final icon = categoryIcons[entry.key] ?? categoryIcons['custom']!;

        return PieChartSectionData(
          color: sectionColor,
          value: percentage,
          title: '${percentage.toStringAsFixed(0)}%',
          radius: 60,
          // --- FONT FIX ---
          // Use a reliable font from google_fonts to ensure text always renders.
          titleStyle: GoogleFonts.roboto(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.white),
          badgeWidget: Icon(icon, size: 20, color: Colors.white, semanticLabel: entry.key),
          badgePositionPercentageOffset: .98,
        );
      }).toList();
    }

    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      child: PieChart(
        PieChartData(
          sections: showingSections(),
          borderData: FlBorderData(show: false),
          sectionsSpace: 2,
          centerSpaceRadius: 40,
        ),
      ),
    );
  }
}
