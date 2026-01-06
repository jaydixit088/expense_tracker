
import 'package:cloud_firestore/cloud_firestore.dart';

class MonthlyBudget {
  final String id;
  final String userId;
  final double amount;
  final int year;
  final int month;

  MonthlyBudget({
    required this.id,
    required this.userId,
    required this.amount,
    required this.year,
    required this.month,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'amount': amount,
      'year': year,
      'month': month,
    };
  }

  factory MonthlyBudget.fromMap(Map<String, dynamic> map) {
    return MonthlyBudget(
      id: map['id'] ?? '',
      userId: map['userId'] ?? '',
      amount: (map['amount'] ?? 0.0).toDouble(),
      year: map['year'] ?? DateTime.now().year,
      month: map['month'] ?? DateTime.now().month,
    );
  }
  
  // Helper to generate a consistent ID like "2024-01"
  static String generateId(int year, int month) {
    return '$year-${month.toString().padLeft(2, '0')}';
  }
}
