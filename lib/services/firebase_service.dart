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
        'displayName': user.displayName ?? (user.isAnonymous ? 'Fit-Entdecker' : 'User'),
        'photoUrl': user.photoURL ?? '',
        'level': 1,
        'points': 0,
        'dailySteps': 0,
        'weeklySteps': 0,
        'streak': 0,
        'groupIds': [],
        'isAnonymous': user.isAnonymous,
        'workoutGoalWeekly': 3,
        'workoutsThisWeek': 0,
        'streakFreezers': 0,
        'goalValue': 10000, // Standard-Tagesziel
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
  }

  Stream<UserModel?> getUserData(String uid) {
    return _db.collection('users').doc(uid).snapshots().map((snap) {
      if (snap.exists && snap.data() != null) return UserModel.fromMap(snap.data()!, snap.id);
      return null;
    });
  }

  Future<void> updateWorkoutGoal(String uid, int weeklyGoal) async {
    await _db.collection('users').doc(uid).update({'workoutGoalWeekly': weeklyGoal});
  }

  // NEU: Tagesziel für Schritte aktualisieren
  Future<void> updateStepGoal(String uid, int goal) async {
    await _db.collection('users').doc(uid).update({'goalValue': goal});
  }

  Future<UserCredential?> signInAnonymously() async {
    try {
      UserCredential result = await _auth.signInAnonymously();
      if (result.user != null) await syncOrCreateUser(result.user!);
      return result;
    } catch (e) {
      return null;
    }
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

  Future<UserCredential?> signIn(String email, String password) => _auth.signInWithEmailAndPassword(email: email, password: password);
  Future<void> signOut() async {
    await _auth.signOut();
  }

  Stream<DailyStatsModel?> getDailyStats(String uid, String dateId) {
    return _db.collection('users').doc(uid).collection('daily_stats').doc(dateId).snapshots().map((snap) {
      if (snap.exists && snap.data() != null) return DailyStatsModel.fromMap(snap.data()!, snap.id);
      return null;
    });
  }

  Stream<List<DailyStatsModel>> getWeeklyStatsStream(String uid) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    return _db.collection('users').doc(uid).collection('daily_stats')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .snapshots()
        .map((snap) => snap.docs.map((doc) => DailyStatsModel.fromMap(doc.data(), doc.id)).toList());
  }

  Future<void> updateSteps(String uid, String dateId, int steps) async {
    final userDoc = await _db.collection('users').doc(uid).get();
    if (!userDoc.exists) return;

    final userData = userDoc.data()!;
    int totalPoints = userData['points'] ?? 0;
    int oldLevel = userData['level'] ?? 1;
    int streakFreezers = userData['streakFreezers'] ?? 0;
    int goalValue = userData['goalValue'] ?? 10000;
    List<dynamic> groupIds = userData['groupIds'] ?? [];
    String displayName = userData['displayName'] ?? 'User';

    int newXP = (steps / 100).floor();
    if (steps >= goalValue) {
      newXP += 50;
    }

    int oldSteps = userData['dailySteps'] ?? 0;
    int oldXPFromSteps = (oldSteps / 100).floor() + (oldSteps >= goalValue ? 50 : 0);
    int diffXP = newXP - oldXPFromSteps;

    int newTotalPoints = totalPoints + diffXP;
    int newLevel = (newTotalPoints / 500).floor() + 1;
    int weeklySteps = (userData['weeklySteps'] ?? 0) + (steps - oldSteps);

    WriteBatch batch = _db.batch();
    
    if (newLevel > oldLevel) {
      streakFreezers += 1;
      for (String gId in groupIds) {
        DocumentReference msgRef = _db.collection('groups').doc(gId).collection('messages').doc();
        batch.set(msgRef, {
          'senderId': uid, 'senderName': 'System',
          'text': "🎉 $displayName ist gerade auf Level $newLevel aufgestiegen!",
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
    }

    batch.set(_db.collection('users').doc(uid).collection('daily_stats').doc(dateId), {
      'steps': steps, 'timestamp': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    batch.update(_db.collection('users').doc(uid), {
      'dailySteps': steps, 
      'weeklySteps': weeklySteps,
      'points': newTotalPoints, 
      'level': newLevel,
      'streakFreezers': streakFreezers,
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

  Stream<List<UserModel>> getGroupMembers(String groupId) {
    return _db.collection('groups').doc(groupId).snapshots().asyncMap((snap) async {
      final List<dynamic> memberIds = snap.data()?['members'] ?? [];
      if (memberIds.isEmpty) return [];
      final memberSnaps = await _db.collection('users').where(FieldPath.documentId, whereIn: memberIds).get();
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

  Future<void> sendMessage(String gId, String uId, String uName, String msg) async {
    await _db.collection('groups').doc(gId).collection('messages').add({
      'senderId': uId, 'senderName': uName, 'text': msg, 'timestamp': FieldValue.serverTimestamp(),
    });
  }

  Stream<QuerySnapshot> getMessages(String gId) =>
    _db.collection('groups').doc(gId).collection('messages').orderBy('timestamp', descending: true).snapshots();
}
