import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/models/expense.dart';

/// Manages the application's state for expenses, filters, and user preferences.
/// This provider centralizes all business logic related to expenses.
class ExpensesProvider with ChangeNotifier {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // --- STATE ---
  String _currencySymbol = '₹';
  List<String> _customCategories = [];
  DateTime? _filterDate;
  String? _categoryFilter;

  // --- KEYS ---
  static const String _currencyKey = 'user_currency_preference';

  // --- GETTERS ---
  String get currencySymbol => _currencySymbol;
  List<String> get customCategories => _customCategories;
  DateTime? get filterDate => _filterDate;
  String? get categoryFilter => _categoryFilter;

  ExpensesProvider() {
    _loadCurrency();
    // In the future, you might load custom categories from Firestore here too.
  }

  // --- PREFERENCES ---

  Future<void> _loadCurrency() async {
    final prefs = await SharedPreferences.getInstance();
    _currencySymbol = prefs.getString(_currencyKey) ?? '₹';
    notifyListeners();
  }

  Future<void> setCurrency(String symbol) async {
    _currencySymbol = symbol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, symbol);
    notifyListeners();
  }

  // --- FILTERS ---

  void setFilterDate(DateTime? date) {
    _filterDate = date;
    notifyListeners(); // The UI will rebuild the stream when this changes.
  }

  void setCategoryFilter(String? category) {
    _categoryFilter = category;
    notifyListeners(); // The UI will rebuild the stream when this changes.
  }

  // --- CORE DATABASE LOGIC ---

  /// The single source of truth for fetching expenses.
  /// This stream intelligently rebuilds its query based on the current filters.
  Stream<List<Expense>> get expensesStream {
    final user = _auth.currentUser;
    if (user == null) {
      return Stream.value([]); // Return an empty stream if no user is logged in.
    }

    // Start with the base query.
    Query query = _firestore
        .collection('users')
        .doc(user.uid)
        .collection('expenses')
        .orderBy('date', descending: true);

    // --- DYNAMIC FILTERING ON THE SERVER ---

    // Apply date filter if it exists.
    if (_filterDate != null) {
      final startOfDay = DateTime(_filterDate!.year, _filterDate!.month, _filterDate!.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      query = query
          .where('date', isGreaterThanOrEqualTo: startOfDay.toIso8601String())
          .where('date', isLessThan: endOfDay.toIso8601String());
    }

    // Apply category filter if it exists.
    if (_categoryFilter != null && _categoryFilter != 'custom') {
      query = query.where('category', isEqualTo: _categoryFilter);
    }
    
    // Note: Filtering for 'custom' categories on Firestore is complex.
    // The previous client-side filtering logic for 'custom' is acceptable for now.
    // If we need to, we can add it back later, but let's keep it simple first.

    // Execute the query and map the results.
    return query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Expense.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });
  }

  Future<void> addExpense(Expense expense) async {
    final user = _auth.currentUser;
    if (user == null) return;

    // The Expense constructor already creates an ID. We don't need to do it again.
    final expenseWithUser = Expense(
      userId: user.uid,
      title: expense.title,
      amount: expense.amount,
      date: expense.date,
      category: expense.category,
    );

    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('expenses')
        .doc(expenseWithUser.id) // Use the ID from the new object.
        .set(expenseWithUser.toMap());
  }

  Future<void> updateExpense(String id, Expense newExpense) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('expenses')
        .doc(id)
        .update(newExpense.toMap());
  }

  Future<void> removeExpense(String expenseId) async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _firestore
        .collection('users')
        .doc(user.uid)
        .collection('expenses')
        .doc(expenseId)
        .delete();
  }
  
  void addCustomCategory(String category) {
    if (!Category.values.any((e) => e.name == category) && !_customCategories.contains(category)) {
      _customCategories.add(category);
      notifyListeners();
    }
  }
}
