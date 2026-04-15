import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authState => _auth.authStateChanges();

  Stream<UserModel?> getUserData(String? uid) {
    if (uid == null) return Stream.value(null);
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (snap.exists && snap.data() != null) {
        return UserModel.fromMap(snap.data()!, snap.id);
      }
      return null;
    });
  }

  Future<UserCredential?> signUp(String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      User? user = result.user;
      if (user != null) {
        await _db.collection('users').doc(user.uid).set({
          'email': email,
          'displayName': name,
          'dailySteps': 0,
          'streak': 0,
          'groupIds': [],
        });
      }
      return result;
    } catch (e) {
      return null;
    }
  }

  Future<UserCredential?> signIn(String email, String password) async {
    try {
      return await _auth.signInWithEmailAndPassword(email: email, password: password);
    } catch (e) {
      return null;
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<void> updateSteps(String uid, int steps) async {
    await _db.collection('users').doc(uid).update({'dailySteps': steps});
  }

  Future<void> createGroup(String name, String userId) async {
    DocumentReference groupRef = await _db.collection('groups').add({
      'name': name,
      'members': [userId],
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('users').doc(userId).update({
      'groupIds': FieldValue.arrayUnion([groupRef.id])
    });
  }

  Stream<List<Map<String, dynamic>>> getGroups(List<String> groupIds) {
    if (groupIds.isEmpty) return Stream.value([]);
    return _db.collection('groups').where(FieldPath.documentId, whereIn: groupIds).snapshots().map((snap) =>
        snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Future<void> sendMessage(String groupId, String userId, String userName, String message) async {
    await _db.collection('groups').doc(groupId).collection('messages').add({
      'senderId': userId,
      'senderName': userName,
      'text': message,
      'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getMessages(String groupId) {
    return _db.collection('groups').doc(groupId).collection('messages').orderBy('timestamp', descending: true).snapshots();
  }
  
  Future<void> logWorkout(String userId, String type, String duration) async {
      await _db.collection('users').doc(userId).collection('workouts').add({
          'type': type,
          'duration': duration,
          'timestamp': FieldValue.serverTimestamp(),
      });
  }
}
