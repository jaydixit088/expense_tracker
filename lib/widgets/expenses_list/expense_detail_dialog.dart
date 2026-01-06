import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:expense_tracker/models/expense.dart';

/// A dialog that displays full details of an expense with an edit option.
class ExpenseDetailDialog extends StatelessWidget {
  const ExpenseDetailDialog({super.key, required this.expense, required this.onEdit});

  final Expense expense;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Expense Details', style: GoogleFonts.outfit(fontSize: 20, fontWeight: FontWeight.bold)),
                IconButton(icon: const Icon(Icons.close), onPressed: () => Navigator.pop(context)),
              ],
            ),
            const Divider(),
            const SizedBox(height: 16),
            _buildDetailRow('Title', expense.title),
            const SizedBox(height: 12),
            _buildDetailRow('Amount', '${expense.amount.toStringAsFixed(2)}'),
            const SizedBox(height: 12),
            _buildDetailRow('Date', DateFormat.yMd().format(expense.date)),
            const SizedBox(height: 12),
            _buildDetailRow('Category', expense.category.toUpperCase()),
            const SizedBox(height: 12),
            if (expense.additionalInfo != null && expense.additionalInfo!.isNotEmpty) ...[
               _buildDetailRow('Note', expense.additionalInfo!),
               const SizedBox(height: 12),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.edit),
                label: const Text('Edit Expense'),
                onPressed: () {
                  Navigator.pop(context); // Close detail dialog
                  onEdit(); // Trigger edit
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
      ],
    );
  }
}
