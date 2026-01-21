import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:expense_tracker/models/expense.dart';
import 'package:expense_tracker/models/monthly_budget.dart';
import 'package:expense_tracker/models/organisation.dart';

/// Manages the application's state for expenses, filters, and user preferences.
/// This provider centralizes all business logic related to expenses.
class ExpensesProvider with ChangeNotifier {


  // --- STATE ---
  String _currencySymbol = '₹';
  final List<String> _customCategories = [];
  DateTime? _filterDate = DateTime.now(); // Represents the selected MONTH
  String? _categoryFilter;
  String _searchQuery = '';
  double _monthlyBudget = 0; // Current loaded budget
  bool _isLoadingBudget = false;
  ThemeMode _themeMode = ThemeMode.system;
  Organisation? _selectedOrganisation; // Null means Personal

  // --- KEYS ---
  static const String _currencyKey = 'user_currency_preference';
  static const String _themeKey = 'user_theme_preference';

  // --- GETTERS ---
  String get currencySymbol => _currencySymbol;
  List<String> get customCategories => _customCategories;
  DateTime? get filterDate => _filterDate;
  String? get categoryFilter => _categoryFilter;
  String get searchQuery => _searchQuery;
  double get monthlyBudget => _monthlyBudget;
  ThemeMode get themeMode => _themeMode;
  Organisation? get selectedOrganisation => _selectedOrganisation;

  bool get canEdit {
    if (_selectedOrganisation == null) return true;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    if (_selectedOrganisation!.adminId == user.uid) return true;
    final permission = _selectedOrganisation!.permissions[user.uid];
    return permission == 'readwrite';
  }

  ExpensesProvider() {
    _loadPreferences();
  }

  // --- PREFERENCES ---

  Future<void> _loadPreferences() async {
    final prefs = await SharedPreferences.getInstance();
    _currencySymbol = prefs.getString(_currencyKey) ?? '₹';
    
    final themeString = prefs.getString(_themeKey);
    if (themeString == 'light') {
      _themeMode = ThemeMode.light;
    } else if (themeString == 'dark') {
      _themeMode = ThemeMode.dark;
    } else {
      _themeMode = ThemeMode.system;
    }
    
    notifyListeners();
  }

  Future<void> toggleTheme(bool isDark) async {
    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_themeKey, isDark ? 'dark' : 'light');
    notifyListeners();
  }

  Future<void> setCurrency(String symbol) async {
    _currencySymbol = symbol;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_currencyKey, symbol);
    notifyListeners();
  }

  // --- ORGANISATION ---
  
  void selectOrganisation(Organisation? org) {
    _selectedOrganisation = org;
    _cachedStream = null; // Force refresh stream
    _filterDate = DateTime.now(); // Reset filters when switching context
    _categoryFilter = null;
    notifyListeners();
    // Re-fetch budget for the new context
    if (org != null) {
       _monthlyBudget = org.monthlyExpenses; // Use org budget
    } else {
       _fetchBudgetForMonth(null); // Fetch personal budget
    }
  }

  // --- FILTERS & BUDGET ---

  /// Sets the filter to the Month of the provided date.
  /// Also fetches the budget for that month.
  Future<void> setFilterDate(DateTime? date) async {
    _filterDate = date;
    notifyListeners();
    if (_selectedOrganisation == null) {
      await _fetchBudgetForMonth(date);
    } 
    // For organisation, budget is currently static/global per org, 
    // but we could implement monthly budgets for orgs too later.
  }

  void setCategoryFilter(String? category) {
    _categoryFilter = category;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  /// Updates the budget for the CURRENTLY selected month (or current month if null).
  Future<void> setMonthlyBudget(double amount) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    if (_selectedOrganisation != null) {
        // Update Organisation Budget
        // Check Admin permissions
        if (_selectedOrganisation!.adminId != user.uid) {
            // Only admin can change budget? Or ReadWrite? Let's say Admin only for budget.
             // Actually requirement: "User can add organisation like their company name,admin name and monthly expenses"
             // Implies admin sets it.
             return; 
        }

        // We need to update the organisation doc locally and remotely
        // Note: This updates the 'static' monthly budget field in Org model.
        // It doesn't use the MonthlyBudget collection which is time-based.
        // This is a disconnect, but fits the simple "monthly expenses" field description.
        // To be consistent with personal, we *could* use collections, but let's stick to the model field for now.
        
        final updatedOrg = Organisation(
           id: _selectedOrganisation!.id,
           name: _selectedOrganisation!.name,
           adminId: _selectedOrganisation!.adminId,
           adminName: _selectedOrganisation!.adminName,
           monthlyExpenses: amount,
           members: _selectedOrganisation!.members,
           permissions: _selectedOrganisation!.permissions,
        );
        
        await FirebaseFirestore.instance.collection('organisations').doc(updatedOrg.id).update({'monthlyExpenses': amount});
        _selectedOrganisation = updatedOrg;
        _monthlyBudget = amount;
        notifyListeners();
        return;
    }

    // Personal Budget Logic
    _monthlyBudget = amount;
    notifyListeners();

    final targetDate = _filterDate ?? DateTime.now();
    final budgetId = MonthlyBudget.generateId(targetDate.year, targetDate.month);
    
    final budget = MonthlyBudget(
      id: budgetId,
      userId: user.uid,
      amount: amount,
      year: targetDate.year,
      month: targetDate.month,
    );

    try {
      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('budgets')
          .doc(budgetId)
          .set(budget.toMap());
    } catch (e) {
      debugPrint('Error saving budget: $e');
    }
  }

  Future<void> _fetchBudgetForMonth(DateTime? date) async {
    if (_selectedOrganisation != null) {
        _monthlyBudget = _selectedOrganisation!.monthlyExpenses;
        notifyListeners();
        return;
    }

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final targetDate = date ?? DateTime.now();
    final budgetId = MonthlyBudget.generateId(targetDate.year, targetDate.month);

    try {
      _isLoadingBudget = true;
      // notifyListeners(); // Optional: trigger loading state in UI

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .collection('budgets')
          .doc(budgetId)
          .get();

      if (doc.exists) {
        final budgetData = MonthlyBudget.fromMap(doc.data()!);
        _monthlyBudget = budgetData.amount;
      } else {
        // If no budget set for this month, default to 10000 or logic to copy previous
        _monthlyBudget = 10000; 
      }
    } catch (e) {
      debugPrint('Error fetching budget: $e');
      _monthlyBudget = 10000; // Fallback
    } finally {
      _isLoadingBudget = false;
      notifyListeners();
    }
  }

  // --- CORE DATABASE LOGIC ---

  Stream<List<Expense>>? _cachedStream;
  DateTime? _lastFilterDate;
  Organisation? _lastSelectedOrganisation;
  
  /// The single source of truth for fetching expenses.
  Stream<List<Expense>> get expensesStream {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return Stream.value([]);
    }

    // Return cached stream if inputs haven't changed.
    if (_cachedStream != null && _filterDate == _lastFilterDate && _selectedOrganisation?.id == _lastSelectedOrganisation?.id) {
      return _applyClientFilters(_cachedStream!);
    }

    _lastFilterDate = _filterDate;
    _lastSelectedOrganisation = _selectedOrganisation;

    // Start with the base query.
    Query query;
    if (_selectedOrganisation != null) {
        query = FirebaseFirestore.instance
            .collection('organisations')
            .doc(_selectedOrganisation!.id)
            .collection('expenses')
            .orderBy('date', descending: true);
    } else {
        query = FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('expenses')
            .orderBy('date', descending: true);
    }

    // Apply Month filter
    if (_filterDate != null) {
      // Calculate start and end of the MONTH
      final startOfMonth = DateTime(_filterDate!.year, _filterDate!.month, 1);
      // To get end of month: Go to next month's 1st day, subtract 1 second (or just use < next month start)
      final startOfNextMonth = DateTime(_filterDate!.year, _filterDate!.month + 1, 1);
      
      query = query
          .where('date', isGreaterThanOrEqualTo: startOfMonth.toIso8601String())
          .where('date', isLessThan: startOfNextMonth.toIso8601String());
    }

    _cachedStream = query.snapshots().map((snapshot) {
      return snapshot.docs
          .map((doc) => Expense.fromMap(doc.data() as Map<String, dynamic>))
          .toList();
    });

    return _applyClientFilters(_cachedStream!);
  }

  Stream<List<Expense>> _applyClientFilters(Stream<List<Expense>> stream) {
    return stream.map((expenses) {
      var filtered = expenses;

      // Apply category filter
      if (_categoryFilter != null) {
        if (_categoryFilter == 'custom') {
           // Show all except the default 4
           const defaults = ['food', 'travel', 'home', 'work'];
           filtered = filtered.where((exp) => !defaults.contains(exp.category)).toList();
        } else {
           filtered = filtered.where((exp) => exp.category == _categoryFilter).toList();
        }
      }

      // Apply search query
      if (_searchQuery.isNotEmpty) {
        filtered = filtered.where((exp) => 
          exp.title.toLowerCase().contains(_searchQuery.toLowerCase()) || 
          exp.category.toLowerCase().contains(_searchQuery.toLowerCase())
        ).toList();
      }

      return filtered;
    }).handleError((e) {
      debugPrint('EXPENSE_TRACKER_ERROR: $e');
    });
  }

  Future<void> addExpense(Expense expense) async {
    if (!canEdit) throw Exception('Permission denied: Read-only access');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');

      // Add organisationId to expense if in organisation mode
      final expenseWithUser = Expense(
        id: expense.id,
        userId: user.uid,
        title: expense.title,
        amount: expense.amount,
        date: expense.date,
        category: expense.category,
        additionalInfo: expense.additionalInfo,
        organisationId: _selectedOrganisation?.id,
      );

      if (_selectedOrganisation != null) {
          await FirebaseFirestore.instance
            .collection('organisations')
            .doc(_selectedOrganisation!.id)
            .collection('expenses')
            .doc(expenseWithUser.id)
            .set(expenseWithUser.toMap());
      } else {
          await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('expenses')
            .doc(expenseWithUser.id)
            .set(expenseWithUser.toMap());
      }

    } catch (e) {
      debugPrint('Error adding expense: $e');
      rethrow;
    }
  }

  Future<void> updateExpense(String id, Expense newExpense) async {
    if (!canEdit) throw Exception('Permission denied: Read-only access');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');
      
      // Ensure organisationId is preserved or set correctly
      final expenseToUpdate = Expense(
         id: newExpense.id,
         userId: newExpense.userId,
         title: newExpense.title,
         amount: newExpense.amount,
         date: newExpense.date,
         category: newExpense.category,
         additionalInfo: newExpense.additionalInfo,
         organisationId: _selectedOrganisation?.id, 
      );

      if (_selectedOrganisation != null) {
          await FirebaseFirestore.instance
            .collection('organisations')
            .doc(_selectedOrganisation!.id)
            .collection('expenses')
            .doc(id)
            .update(expenseToUpdate.toMap());
      } else {
          await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('expenses')
            .doc(id)
            .update(expenseToUpdate.toMap());
      }
    } catch (e) {
      debugPrint('Error updating expense: $e');
      rethrow;
    }
  }

  Future<void> removeExpense(String expenseId) async {
    if (!canEdit) throw Exception('Permission denied: Read-only access');

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) throw Exception('User not logged in');
      
      if (_selectedOrganisation != null) {
          await FirebaseFirestore.instance
            .collection('organisations')
            .doc(_selectedOrganisation!.id)
            .collection('expenses')
            .doc(expenseId)
            .delete();
      } else {
          await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .collection('expenses')
            .doc(expenseId)
            .delete();
      }
    } catch (e) {
      debugPrint('Error removing expense: $e');
      rethrow;
    }
  }
  
  void addCustomCategory(String category) {
    if (!Category.values.any((e) => e.name == category) && !_customCategories.contains(category)) {
      _customCategories.add(category);
      notifyListeners();
    }
  }
}
