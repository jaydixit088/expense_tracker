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
    final Map<String, double> categoryTotals = expenses.fold({}, (Map<String, double> map, expense) {
      map[expense.category] = (map[expense.category] ?? 0) + expense.amount;
      return map;
    });

    final double totalExpenses = categoryTotals.values.fold(0.0, (sum, amount) => sum + amount);

    if (totalExpenses == 0) {
      return Container(
        height: 200,
        alignment: Alignment.center,
        child: const Text('Total expenses are zero.'),
      );
    }

    // Calculate currency symbol (assuming generic or passed down, but for now just empty or implicitly understood)
    // Actually we can get it from provider if needed, but for simplicity let's stick to design.

    // --- CHART SECTION GENERATION ---
    List<PieChartSectionData> showingSections() {
      // Modern Vibrant Palette
      final List<Color> colors = [
        const Color(0xFF4361EE), // Vibrant Blue
        const Color(0xFFF72585), // Neon Pink
        const Color(0xFF4CC9F0), // Sky Blue
        const Color(0xFF7209B7), // Deep Purple
        const Color(0xFFFFB703), // Marigold
        const Color(0xFFFB8500), // Pumpkin Orange
        const Color(0xFF06D6A0), // Teal/Green
        const Color(0xFFEF476F), // Red-Pink
      ];
      int colorIndex = 0;

      return categoryTotals.entries.map((entry) {
        final percentage = (entry.value / totalExpenses) * 100;
        final sectionColor = colors[colorIndex % colors.length];
        colorIndex++;

        final icon = categoryIcons[entry.key] ?? categoryIcons['custom']!;

        return PieChartSectionData(
          color: sectionColor,
          value: percentage,
          title: '${percentage.toStringAsFixed(0)}%',
          radius: 50, // Slightly thicker
          titleStyle: GoogleFonts.outfit(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.white),
          badgeWidget: Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: sectionColor.withOpacity(0.9), 
              shape: BoxShape.circle,
              border: Border.all(color: Colors.white, width: 1.5),
            ),
            child: Icon(icon, size: 16, color: Colors.white)
          ),
          badgePositionPercentageOffset: 1.1,
          titlePositionPercentageOffset: 0.6,
        );
      }).toList();
    }

    return SizedBox(
      height: 250,
      child: Stack(
        children: [
          PieChart(
            PieChartData(
              sections: showingSections(),
              borderData: FlBorderData(show: false),
              sectionsSpace: 2,
              centerSpaceRadius: 65,
              startDegreeOffset: 180,
            ),
          ),
          Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                 Text('Total', style: GoogleFonts.outfit(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
                 Text(
                   totalExpenses.toStringAsFixed(0), 
                   style: GoogleFonts.outfit(
                     fontSize: 28, 
                     fontWeight: FontWeight.bold, 
                     // Ensure high contrast in both themes
                     color: Theme.of(context).primaryColor
                   )
                 ),
              ],
            ),
          )
        ],
      ),
    );
  }
}
