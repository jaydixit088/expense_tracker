import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';

// A top-level formatter for consistent date formatting across the app.
final formatter = DateFormat.yMd();

// A top-level UUID generator to create unique IDs.
const uuid = Uuid();

// An enum for the predefined categories. This helps avoid typos in the code.
enum Category { food, travel, leisure, work }

// A map that links category names to their corresponding icons.
// This is a clean way to manage UI elements related to your data.
final Map<String, IconData> categoryIcons = {
  // Using the enum's `name` property for keys is a good practice.
  // It ensures your keys always match your enum definitions.
  Category.food.name: Icons.lunch_dining,
  Category.travel.name: Icons.flight_takeoff,
  Category.leisure.name: Icons.movie,
  Category.work.name: Icons.work,
  // You can also add a default/fallback icon for any custom categories.
  'custom': Icons.wallet_outlined,
};

/// The core data model for a single expense.
/// This class is well-structured, using final properties for immutability.
class Expense {
  Expense({
    String? id,
    required this.userId,
    required this.title,
    required this.amount,
    required this.date,
    required this.category,
  }) : id = id ?? uuid.v4(); // Smart constructor: assigns a new ID if one isn't provided.

  final String id;
  final String userId; // Crucial for linking data to users in Firebase.
  final String title;
  final double amount;
  final DateTime date;
  final String category; // Using String is flexible, allowing for custom categories.

  /// A getter for a user-friendly date string.
  String get formattedDate {
    return formatter.format(date);
  }

  /// Converts the Expense object to a Map for Firestore.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'title': title,
      'amount': amount,
      'date': date.toIso8601String(), // ISO 8601 is the standard for storing dates as strings.
      'category': category,
    };
  }

  /// A factory constructor to create an Expense from a Map (data from Firestore).
  factory Expense.fromMap(Map<String, dynamic> map) {
    return Expense(
      id: map['id'],
      userId: map['userId'],
      title: map['title'],
      amount: map['amount'],
      date: DateTime.parse(map['date']),
      category: map['category'],
    );
  }
}
