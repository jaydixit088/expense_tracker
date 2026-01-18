
import 'package:cloud_firestore/cloud_firestore.dart';

class Organisation {
  final String id;
  final String name;
  final String adminId;
  final String adminName;
  final double monthlyExpenses; // Target or Budget? Prompt says "monthly expenses for their company". Might mean budget or just tracking total? 
                                // "User can add organisation like their company name, admin name and monthly expenses". 
                                // I'll assume this is a budget/target or just a record. Let's treating it like the 'budget' feature in personal.
  final List<String> members; // UIDs
  final Map<String, String> permissions; // UID -> 'readonly' | 'readwrite'

  Organisation({
    required this.id,
    required this.name,
    required this.adminId,
    required this.adminName,
    required this.monthlyExpenses,
    required this.members,
    required this.permissions,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'adminId': adminId,
      'adminName': adminName,
      'monthlyExpenses': monthlyExpenses,
      'members': members,
      'permissions': permissions,
    };
  }

  factory Organisation.fromMap(Map<String, dynamic> map) {
    return Organisation(
      id: map['id'] ?? '',
      name: map['name'] ?? '',
      adminId: map['adminId'] ?? '',
      adminName: map['adminName'] ?? '',
      monthlyExpenses: (map['monthlyExpenses'] ?? 0.0).toDouble(),
      members: List<String>.from(map['members'] ?? []),
      permissions: Map<String, String>.from(map['permissions'] ?? {}),
    );
  }
}
