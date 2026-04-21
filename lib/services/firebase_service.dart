import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_model.dart';
import '../models/daily_stats_model.dart';

class FirebaseService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<User?> get authState => _auth.authStateChanges();

  Future<void> syncOrCreateUser(User user) async {
    final docRef = _db.collection('users').doc(user.uid);
    final docSnap = await docRef.get();

    if (!docSnap.exists) {
      await docRef.set({
        'email': user.email ?? '',
        'displayName': user.displayName ?? (user.isAnonymous ? 'Gast' : 'User'),
        'photoUrl': user.photoURL ?? '',
        'level': 1,
        'points': 0,
        'dailySteps': 0,
        'streak': 0,
        'groupIds': [],
        'isAnonymous': user.isAnonymous,
        'goalType': 'interval',
        'goalValue': 100,
        'workoutGoalWeekly': 3,
        'workoutsThisWeek': 0,
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<UserModel?> getUserData(String? uid) {
    if (uid == null) return Stream.value(null);
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (snap.exists && snap.data() != null) return UserModel.fromMap(snap.data()!, snap.id);
      return null;
    });
  }

  Future<void> _updateUser(String uid, Map<String, dynamic> data) => _db.collection('users').doc(uid).update(data);
  Future<void> updateGoals(String uid, String goalType, int goalValue) => _updateUser(uid, {'goalType': goalType, 'goalValue': goalValue});
  Future<void> updateWorkoutGoal(String uid, int weeklyGoal) => _updateUser(uid, {'workoutGoalWeekly': weeklyGoal});

  Future<UserCredential?> signInAnonymously() async {
    try {
      UserCredential result = await _auth.signInAnonymously();
      if (result.user != null) await syncOrCreateUser(result.user!);
      return result;
    } catch (e) {
      return null;
    }
  }

  Stream<DailyStatsModel?> getDailyStats(String uid, String dateId) {
    return _db.collection('users').doc(uid).collection('daily_stats').doc(dateId).snapshots().map((snap) {
      if (snap.exists && snap.data() != null) return DailyStatsModel.fromMap(snap.data()!, snap.id);
      return null;
    });
  }

  Future<List<DailyStatsModel>> getWeeklyStats(String uid) async {
    final now = DateTime.now();
    final query = await _db.collection('users').doc(uid).collection('daily_stats')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(now.subtract(const Duration(days: 7))))
        .orderBy('timestamp', descending: true).get();
    return query.docs.map((doc) => DailyStatsModel.fromMap(doc.data(), doc.id)).toList();
  }

  Future<UserCredential?> signUp(String email, String password, String name) async {
    try {
      UserCredential result = await _auth.createUserWithEmailAndPassword(email: email, password: password);
      if (result.user != null) {
        await result.user!.updateDisplayName(name);
        await syncOrCreateUser(result.user!);
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

  Future<void> signOut() => _auth.signOut();

  Future<void> updateSteps(String uid, String dateId, int steps) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) return;

    final userData = userDoc.data()!;
    final goalType = userData['goalType'] ?? 'interval';
    final goalValue = userData['goalValue'] ?? 100;
    int points = userData['points'] ?? 0;

    if (goalType == 'interval') {
      points = (steps / goalValue).floor();
    } else if (goalType == 'target' && steps >= goalValue) {
      points += 50; 
    }

    WriteBatch batch = _db.batch();
    batch.set(_db.collection('users').doc(uid).collection('daily_stats').doc(dateId), {
      'steps': steps, 'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.update(_db.collection('users').doc(uid), {
      'dailySteps': steps, 'points': points, 'level': (points / 500).floor() + 1,
    });
    await batch.commit();
  }

  Future<void> createGroup(String name, String userId) async {
    DocumentReference groupRef = await _db.collection('groups').add({
      'name': name, 'members': [userId], 'createdAt': FieldValue.serverTimestamp(),
    });
    await _db.collection('users').doc(userId).update({
      'groupIds': FieldValue.arrayUnion([groupRef.id])
    });
  }

  Future<void> joinGroup(String groupId, String userId) async {
    final groupDoc = await _db.collection('groups').doc(groupId).get();
    if (!groupDoc.exists) throw Exception("Gruppe nicht gefunden");
    await _db.runTransaction((transaction) async {
      transaction.update(_db.collection('groups').doc(groupId), {'members': FieldValue.arrayUnion([userId])});
      transaction.update(_db.collection('users').doc(userId), {'groupIds': FieldValue.arrayUnion([groupId])});
    });
  }

  Stream<List<Map<String, dynamic>>> getGroups(List<String> groupIds) {
    if (groupIds.isEmpty) return Stream.value([]);
    return _db.collection('groups').where(FieldPath.documentId, whereIn: groupIds).snapshots().map((snap) =>
        snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  // WICHTIG: Mitglieder einer Gruppe laden
  Stream<List<UserModel>> getGroupMembers(String groupId) {
    return _db.collection('groups').doc(groupId).snapshots().asyncMap((snap) async {
      final List<dynamic> memberIds = snap.data()?['members'] ?? [];
      if (memberIds.isEmpty) return [];
      
      final memberSnaps = await _db.collection('users')
          .where(FieldPath.documentId, whereIn: memberIds)
          .get();
          
      return memberSnaps.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList();
    });
  }

  Future<void> logWorkout(UserModel user, String type, String duration) async {
      await _db.collection('users').doc(user.id).collection('workouts').add({
          'type': type, 'duration': duration, 'timestamp': FieldValue.serverTimestamp(),
      });
      await _db.collection('users').doc(user.id).update({
        'points': FieldValue.increment(10), 'workoutsThisWeek': FieldValue.increment(1)
      });
      for (String gId in user.groupIds) {
        await sendMessage(gId, user.id, user.displayName, "Ich habe ein Workout gemacht: $type ($duration)! 🔥");
      }
  }

  Stream<List<Map<String, dynamic>>> getWorkouts(String userId) {
    return _db.collection('users').doc(userId).collection('workouts').orderBy('timestamp', descending: true).snapshots()
        .map((snap) => snap.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList());
  }

  Future<void> sendMessage(String gId, String uId, String uName, String msg) =>
    _db.collection('groups').doc(gId).collection('messages').add({
      'senderId': uId, 'senderName': uName, 'text': msg, 'timestamp': FieldValue.serverTimestamp(),
    });

  Stream<QuerySnapshot> getMessages(String gId) =>
    _db.collection('groups').doc(gId).collection('messages').orderBy('timestamp', descending: true).snapshots();
}
