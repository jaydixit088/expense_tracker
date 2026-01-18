
class Invitation {
  final String id;
  final String orgId;
  final String orgName;
  final String inviterName;
  final String email;
  final String permission;
  final String status; // 'pending', 'accepted', 'rejected'

  Invitation({
    required this.id,
    required this.orgId,
    required this.orgName,
    required this.inviterName,
    required this.email,
    required this.permission,
    required this.status,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'orgId': orgId,
      'orgName': orgName,
      'inviterName': inviterName,
      'email': email,
      'permission': permission,
      'status': status,
    };
  }

  factory Invitation.fromMap(Map<String, dynamic> map) {
    return Invitation(
      id: map['id'] ?? '',
      orgId: map['orgId'] ?? '',
      orgName: map['orgName'] ?? '',
      inviterName: map['inviterName'] ?? '',
      email: map['email'] ?? '',
      permission: map['permission'] ?? 'readonly',
      status: map['status'] ?? 'pending',
    );
  }
}
