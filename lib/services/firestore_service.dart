import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:expense_tracker/models/user_profile.dart';
import 'package:expense_tracker/models/organisation.dart';
import 'package:expense_tracker/models/invitation.dart';

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

  Future<QuerySnapshot> getExpensesForPeriod(String uid, DateTime startDate, DateTime endDate, {String? organisationId}) {
    if (organisationId != null) {
      return _db
          .collection('organisations')
          .doc(organisationId)
          .collection('expenses')
          .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
          .where('date', isLessThanOrEqualTo: DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59).toIso8601String())
          .orderBy('date', descending: true)
          .get();
    }
    return _db
        .collection('users')
        .doc(uid)
        .collection('expenses')
        .where('date', isGreaterThanOrEqualTo: startDate.toIso8601String())
        .where('date', isLessThanOrEqualTo: DateTime(endDate.year, endDate.month, endDate.day, 23, 59, 59).toIso8601String())
        .orderBy('date', descending: true)
        .get();
  }

  // --- Organisation Methods ---

  Future<void> createOrganisation(Organisation org) {
    return _db.collection('organisations').doc(org.id).set(org.toMap());
  }

  Future<List<Organisation>> getUserOrganisations(String uid) async {
    final snapshot = await _db
        .collection('organisations')
        .where('members', arrayContains: uid)
        .get();
    return snapshot.docs.map((doc) => Organisation.fromMap(doc.data())).toList();
  }

  Future<void> updateOrganisation(Organisation org) {
    return _db.collection('organisations').doc(org.id).update(org.toMap());
  }

  Future<UserProfile?> getUserByEmail(String email) async {
    final snapshot = await _db
        .collection('users')
        .where('email', isEqualTo: email)
        .limit(1)
        .get();
    if (snapshot.docs.isNotEmpty) {
      return UserProfile.fromMap(snapshot.docs.first.data());
    }
    return null;
  }

  // --- Invitation Methods ---

  Future<void> sendInvitation(Invitation invitation) {
    return _db.collection('invitations').doc(invitation.id).set(invitation.toMap());
  }

  Stream<List<Invitation>> getInvitationsStream(String email) {
    return _db
        .collection('invitations')
        .where('email', isEqualTo: email)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Invitation.fromMap(doc.data())).toList());
  }

  Stream<List<Invitation>> getOrgInvitationsStream(String orgId) {
    return _db
        .collection('invitations')
        .where('orgId', isEqualTo: orgId)
        .snapshots()
        .map((snapshot) =>
            snapshot.docs.map((doc) => Invitation.fromMap(doc.data())).toList());
  }

  Future<void> deleteInvitation(String invitationId) {
    return _db.collection('invitations').doc(invitationId).delete();
  }

  Future<void> acceptInvitation(Invitation invitation, String userId) async {
    final batch = _db.batch();

    // 1. Update Invitation Status
    final inviteRef = _db.collection('invitations').doc(invitation.id);
    batch.update(inviteRef, {'status': 'accepted'});

    // 2. Add user to Organisation
    // We use arrayUnion to add the member without needing to read the document first.
    // This avoids the "Permission Denied" error because the user isn't a member yet so they can't read.
    final orgRef = _db.collection('organisations').doc(invitation.orgId);
    
    batch.update(orgRef, {
        'members': FieldValue.arrayUnion([userId]),
        'permissions.$userId': invitation.permission, // Dot notation to update map key
    });

    await batch.commit();
  }

  Future<void> rejectInvitation(String invitationId) {
    return _db.collection('invitations').doc(invitationId).update({'status': 'rejected'});
  }

  Future<void> deleteOrganisation(String orgId) async {
    // Note: This only deletes the organisation document.
    // Subcollections (expenses) are not automatically deleted in Firestore.
    // Ideally, a Cloud Function should handle recursive deletion.
    // For this app, we will delete the org doc and associated invitations.
    
    final batch = _db.batch();
    
    // Delete Org
    batch.delete(_db.collection('organisations').doc(orgId));
    
    // Delete associated invitations
    final invitesSnapshot = await _db.collection('invitations').where('orgId', isEqualTo: orgId).get();
    for (var doc in invitesSnapshot.docs) {
      batch.delete(doc.reference);
    }

    await batch.commit();
  }

  Future<void> removeMember(String orgId, String memberUid, String inviteId) async {
    final batch = _db.batch();

    // 1. Remove from Organisation
    final orgRef = _db.collection('organisations').doc(orgId);
    batch.update(orgRef, {
      'members': FieldValue.arrayRemove([memberUid]),
      'permissions.$memberUid': FieldValue.delete(),
    });

    // 2. Delete Invitation or update status
    // Deleting invitation puts it back to cleaner state
    final inviteRef = _db.collection('invitations').doc(inviteId);
    batch.delete(inviteRef); 

    await batch.commit();
  }

  Future<void> updateMemberPermission(String orgId, String memberUid, String inviteId, String newPermission) async {
    final batch = _db.batch();

    // 1. Update Organisation
    final orgRef = _db.collection('organisations').doc(orgId);
    batch.update(orgRef, {
      'permissions.$memberUid': newPermission,
    });

    // 2. Update Invitation (for display consistency)
    final inviteRef = _db.collection('invitations').doc(inviteId);
    batch.update(inviteRef, {'permission': newPermission});

    await batch.commit();
  }
}

