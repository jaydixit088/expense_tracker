import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:currency_picker/currency_picker.dart';

import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/providers/expenses_provider.dart';

/// A modal bottom sheet for adding a new expense or editing an existing one.
class NewExpense extends StatefulWidget {
  const NewExpense({super.key, this.expenseToEdit});

  // If `expenseToEdit` is not null, the widget is in "edit" mode.
  final Expense? expenseToEdit;

  @override
  State<NewExpense> createState() => _NewExpenseState();
}

class _NewExpenseState extends State<NewExpense> {
  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  DateTime? _selectedDate;
  String? _selectedCategory; // Nullable to handle initial state

  bool get _isEditing => widget.expenseToEdit != null;

  @override
  void initState() {
    super.initState();
    if (_isEditing) {
      final expense = widget.expenseToEdit!;
      _titleController.text = expense.title;
      _amountController.text = expense.amount.toString();
      _selectedDate = expense.date;
      _selectedCategory = expense.category;
    }
  }

  /// Presents the date picker to the user.
  void _presentDatePicker() async {
    final now = DateTime.now();
    final pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? now,
      firstDate: DateTime(now.year - 5),
      lastDate: now,
    );
    if (pickedDate != null) {
      setState(() => _selectedDate = pickedDate);
    }
  }
  
  /// Shows a dialog to add a new custom category.
  Future<void> _showAddCategoryDialog() async {
    final newCategoryController = TextEditingController();
    final newCategory = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Add Custom Category'),
        content: TextField(
          controller: newCategoryController,
          maxLength: 20,
          decoration: const InputDecoration(labelText: 'Category Name'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (newCategoryController.text.trim().isNotEmpty) {
                Navigator.pop(ctx, newCategoryController.text.trim());
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );

    if (newCategory != null) {
      // Add to provider and set as selected
      Provider.of<ExpensesProvider>(context, listen: false).addCustomCategory(newCategory);
      setState(() => _selectedCategory = newCategory);
    }
  }

  /// Validates the form and submits the expense data to the provider.
  void _submitExpenseData() {
    final enteredAmount = double.tryParse(_amountController.text);
    final amountIsInvalid = enteredAmount == null || enteredAmount <= 0;

    if (_titleController.text.trim().isEmpty || amountIsInvalid || _selectedDate == null || _selectedCategory == null) {
      showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Invalid Input'),
          content: const Text('Please make sure a valid title, amount, date, and category were entered.'),
          actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Okay'))],
        ),
      );
      return;
    }

    final provider = Provider.of<ExpensesProvider>(context, listen: false);
    
    if (_isEditing) {
      provider.updateExpense(
        widget.expenseToEdit!.id,
        Expense(
          id: widget.expenseToEdit!.id,
          userId: widget.expenseToEdit!.userId, // Preserve original userId
          title: _titleController.text,
          amount: enteredAmount,
          date: _selectedDate!,
          category: _selectedCategory!,
        ),
      );
    } else {
      provider.addExpense(
        Expense(
          // ID and userId will be set by the provider
          title: _titleController.text,
          amount: enteredAmount,
          date: _selectedDate!,
          category: _selectedCategory!,
          userId: '', // Placeholder, will be replaced in provider
        ),
      );
    }
    
    Navigator.pop(context);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final expensesProvider = Provider.of<ExpensesProvider>(context);

    // Combine default and custom categories for the dropdown.
    final defaultCategories = Category.values.map((c) => c.name);
    final allCategories = [...defaultCategories, ...expensesProvider.customCategories];
    
    // Ensure the selected category is in the list, otherwise default to null.
    if (_selectedCategory != null && !allCategories.contains(_selectedCategory)) {
      _selectedCategory = null;
    }

    return Padding(
      padding: EdgeInsets.fromLTRB(16, 48, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(_isEditing ? 'Edit Expense' : 'Add New Expense', style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 24),
            TextField(controller: _titleController, maxLength: 50, decoration: const InputDecoration(labelText: 'Title')),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: TextField(
                    controller: _amountController,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(labelText: 'Amount', prefixText: '${expensesProvider.currencySymbol} '),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  icon: Text(expensesProvider.currencySymbol, style: const TextStyle(fontSize: 24)),
                  onPressed: () => showCurrencyPicker(context: context, onSelect: (c) => expensesProvider.setCurrency(c.symbol)),
                  tooltip: 'Change Currency',
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    hint: const Text('Select Category'),
                    items: [
                      ...allCategories.map((category) => DropdownMenuItem(
                        value: category,
                        child: Text(category.toUpperCase()),
                      )),
                      // Special item to trigger the dialog
                      const DropdownMenuItem(
                        value: 'add_new_category',
                        child: Row(children: [Icon(Icons.add, size: 16), SizedBox(width: 8), Text('Add New')]),
                      ),
                    ],
                    onChanged: (value) {
                      if (value == 'add_new_category') {
                        _showAddCategoryDialog();
                      } else if (value != null) {
                        setState(() => _selectedCategory = value);
                      }
                    },
                    decoration: const InputDecoration(labelText: 'Category'),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Text(_selectedDate == null ? 'No date chosen' : DateFormat.yMd().format(_selectedDate!)),
                      IconButton(onPressed: _presentDatePicker, icon: const Icon(Icons.calendar_month)),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text('Cancel')),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _submitExpenseData, child: Text(_isEditing ? 'Update Expense' : 'Save Expense')),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
