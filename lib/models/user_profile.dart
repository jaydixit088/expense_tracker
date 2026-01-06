// Imports the necessary Firebase package to use the Timestamp class.
import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents the profile data for a user stored in Firestore.
/// This model separates user data from the core FirebaseUser object,
/// which is an excellent practice for managing custom user profiles.
class UserProfile {
  // All properties are final, ensuring the object is immutable.
  final String uid;
  final String? email; // <-- YOUR FIX IS CORRECT! Made nullable to support non-email sign-ins.
  final String displayName;
  final DateTime? dob; // Nullable, as date of birth may not always be provided.
  final String? gender; // Nullable, as gender may not always be provided.

  UserProfile({
    required this.uid,
    this.email, // <-- CORRECT! This is an optional parameter.
    required this.displayName,
    this.dob,
    this.gender,
  });

  /// Converts the UserProfile object into a Map that can be written to Firestore.
  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      // Correctly handles null dates by converting DateTime to Firestore's Timestamp format.
      'dob': dob != null ? Timestamp.fromDate(dob!) : null,
      'gender': gender,
    };
  }

  /// A factory constructor to create a UserProfile instance from a Firestore document Map.
  factory UserProfile.fromMap(Map<String, dynamic> map) {
    DateTime? parsedDob;
    if (map['dob'] != null) {
      if (map['dob'] is Timestamp) {
        parsedDob = (map['dob'] as Timestamp).toDate();
      } else if (map['dob'] is String) {
        parsedDob = DateTime.tryParse(map['dob']);
      }
    }

    return UserProfile(
      uid: map['uid'] ?? '',
      email: map['email'],
      displayName: map['displayName'] ?? '',
      dob: parsedDob,
      gender: map['gender'],
    );
  }
}
