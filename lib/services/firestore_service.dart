import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/user_profile.dart';
// **THE FIX IS HERE: We needed to import the Expense model**

class FirestoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Future<void> createUserProfile({
    required String uid,
    required String displayName,
    String? email,
  }) {
    final userProfile = UserProfile(
      uid: uid,
      displayName: displayName,
      email: email,
    );
    return saveUserProfile(userProfile);
  }

  Future<void> saveUserProfile(UserProfile userProfile) {
    return _db
        .collection('users')
        .doc(userProfile.uid)
        .set(userProfile.toMap(), SetOptions(merge: true));
  }

  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserProfile.fromMap(doc.data()!);
    }
    return null;
  }

  Future<QuerySnapshot> getExpensesForPeriod(String uid, DateTime startDate, DateTime endDate) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
        .where('date', isLessThanOrEqualTo: DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59).toIso8601String())
        .orderBy('date', descending: true)
        .get();
  }
}
