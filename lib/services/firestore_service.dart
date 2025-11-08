import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/user_profile.dart';

/// A service class dedicated to all interactions with the Cloud Firestore database.
///
/// This approach, known as the "Repository Pattern" or "Service Layer," is a best
/// practice. It centralizes all your database queries in one place, making the
/// rest of your app cleaner, easier to test, and simpler to maintain.
class FirestoreService {
  // A private instance of Firestore. Using '_' makes it private to this file.
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  /// Creates a new user profile document in Firestore, typically after sign-up.
  /// This is separate from `saveUserProfile` to make the intent clear.
  Future<void> createUserProfile({
    required String uid,
    required String displayName,
    String? email,
  }) {
    final userProfile = UserProfile(
      uid: uid,
      displayName: displayName,
      email: email,
      // You could set other initial values here if needed, e.g., dob: null
    );
    // Uses the generic save method to create the document.
    return saveUserProfile(userProfile);
  }

  /// Saves or updates a user's profile in the 'users' collection.
  ///
  /// The `SetOptions(merge: true)` is crucial. It ensures that if you're only
  /// updating one field (like the display name), you don't accidentally
  /// delete other existing fields (like their email or date of birth).
  Future<void> saveUserProfile(UserProfile userProfile) {
    return _db
        .collection('users')
        .doc(userProfile.uid)
        .set(userProfile.toMap(), SetOptions(merge: true));
  }

  /// Retrieves a single UserProfile document from Firestore by user ID.
  ///
  /// Returns a `UserProfile` object if the document exists, otherwise returns `null`.
  /// This is a safe way to fetch data without causing null exceptions.
  Future<UserProfile?> getUserProfile(String uid) async {
    final doc = await _db.collection('users').doc(uid).get();
    if (doc.exists) {
      return UserProfile.fromMap(doc.data()!);
    }
    return null;
  }

  // Note: All the methods for getting/adding/updating/deleting expenses
  // are correctly located in the `ExpensesProvider`, because they are related
  // to the app's *state*. This service class is for one-off database operations.
}
