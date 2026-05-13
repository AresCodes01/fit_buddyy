import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/models/daily_stats_model.dart';
import '../../domain/repositories/steps_repository.dart';

class FirebaseStepsRepository implements StepsRepository {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  @override
  Stream<DailyStatsModel?> getDailyStats(String uid, String dateId) {
    return _db.collection('users').doc(uid).collection('daily_stats').doc(dateId).snapshots().map((snap) {
      if (snap.exists && snap.data() != null) return DailyStatsModel.fromMap(snap.data()!, snap.id);
      return null;
    });
  }

  @override
  Stream<List<DailyStatsModel>> getWeeklyStatsStream(String uid) {
    final now = DateTime.now();
    final sevenDaysAgo = now.subtract(const Duration(days: 7));
    return _db.collection('users').doc(uid).collection('daily_stats')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(sevenDaysAgo))
        .snapshots()
        .map((snap) => snap.docs.map((doc) => DailyStatsModel.fromMap(doc.data(), doc.id)).toList());
  }

  @override
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

  @override
  Future<void> updateStepGoal(String uid, int goal) async {
    await _db.collection('users').doc(uid).update({'goalValue': goal});
  }
}
