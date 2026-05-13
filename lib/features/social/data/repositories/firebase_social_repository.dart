import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../domain/repositories/social_repository.dart';

class FirebaseSocialRepository implements SocialRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Future<void> createGroup(String name, String userId) async {
    DocumentReference groupRef = await _db.collection('groups').add({
      'name': name, 'members': [userId], 'createdAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('users').doc(userId).update({
      'groupIds': FieldValue.arrayUnion([groupRef.id])
    });
  }

  @override
  Future<void> joinGroup(String groupId, String userId) async {
    final groupDoc = await _db.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) throw Exception("Gruppe nicht gefunden");
    await _db.runTransaction((transaction) async {
      transaction.update(_db.collection('groups').doc(groupId), {'members': FieldValue.arrayUnion([userId])});
      transaction.update(_db.collection('users').doc(userId), {'groupIds': FieldValue.arrayUnion([groupId])});
    });
  }

  @override
  Stream<List<Map<String, dynamic>>> getGroups(List<String> groupIds) {
    if (groupIds.isEmpty) return Stream.value([]);
    return _db.collection('groups').where(FieldPath.documentId, whereIn: groupIds).snapshots().map((snap) =>
        snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  @override
  Stream<List<UserModel>> getGroupMembers(String groupId) {
    return _db.collection('groups').doc(groupId).snapshots().asyncMap((snap) async {
      final List<dynamic> memberIds = snap.data()?['members'] ?? [];
      if (memberIds.isEmpty) return [];
      final memberSnaps = await _db.collection('users').where(FieldPath.documentId, whereIn: memberIds).get();
      return memberSnaps.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  @override
  Future<void> sendMessage(String gId, String uId, String uName, String msg) async {
    await _db.collection('groups').doc(gId).collection('messages').add({
      'senderId': uId, 'senderName': uName, 'text': msg, 'timestamp': FieldValue.serverTimestamp(),
    });
  }

  @override
  Stream<QuerySnapshot> getMessages(String gId) =>
    _db.collection('groups').doc(gId).collection('messages').orderBy('timestamp', descending: true).snapshots();

  @override
  Future<Map<String, dynamic>?> getGroupById(String groupId) async {
    final doc = await _db.collection('groups').doc(groupId).get();
    if (!doc.exists) return null;
    return {'id': doc.id, ...doc.data()!};
  }
}
