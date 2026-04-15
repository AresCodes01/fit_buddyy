import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/daily_stats_model.dart';

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

  // Erstellt ein Basis-Dokument für anonyme User oder falls Daten fehlen
  Future<void> createUserDocument(User user, {String? name}) async {
    final doc = await _db.collection('users').doc(user.uid).get();
    if (!doc.exists) {
      await _db.collection('users').doc(user.uid).set({
        'email': user.email ?? '',
        'displayName': name ?? (user.isAnonymous ? 'Gast' : 'User'),
        'dailySteps': 0,
        'streak': 0,
        'groupIds': [],
        'isAnonymous': user.isAnonymous,
      });
    }
  }

  Future<UserCredential?> signInAnonymously() async {
    try {
      UserCredential result = await _auth.signInAnonymously();
      if (result.user != null) {
        await createUserDocument(result.user!);
      }
      return result;
    } catch (e) {
      print("Anonym Error: $e");
      return null;
    }
  }

  // Abrufen der Schritte für einen spezifischen Tag
  Stream<DailyStatsModel?> getDailyStats(String uid, String dateId) {
    return _db
        .collection('users')
        .doc(uid)
        .collection('daily_stats')
        .doc(dateId)
        .snapshots()
        .map((snap) {
      if (snap.exists && snap.data() != null) {
        return DailyStatsModel.fromMap(snap.data()!, snap.id);
      }
      return null;
    });
  }

  // Abrufen der Statistiken für die letzten 7 Tage
  Future<List<DailyStatsModel>> getWeeklyStats(String uid) async {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));

    final query = await _db
        .collection('users')
        .doc(uid)
        .collection('daily_stats')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .orderBy('timestamp', descending: true)
        .get();

    return query.docs.map((doc) => DailyStatsModel.fromMap(doc.data(), doc.id)).toList();
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
          'isAnonymous': false,
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

  // Aktualisierte updateSteps Methode für Historie
  Future<void> updateSteps(String uid, String dateId, int steps) async {
    final docRef = _db.collection('users').doc(uid).collection('daily_stats').doc(dateId);
    
    await docRef.set({
      'steps': steps,
      'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Auch den globalen Counter für heute aktualisieren
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
