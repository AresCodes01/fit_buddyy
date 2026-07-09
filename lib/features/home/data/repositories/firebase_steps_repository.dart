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
    
    // WICHTIG: weeklySteps muss korrekt berechnet werden, falls dailySteps in Firestore 
    // noch von einem alten Tag stammt. Wir vertrauen hier auf die dateId Logik.
    int weeklySteps = (userData['weeklySteps'] ?? 0) + (steps - oldSteps);
    
    // Sicherheitscheck: Falls oldSteps größer ist (neuer Tag Reset), 
    // dann ist das Delta für weeklySteps einfach die neuen Schritte
    if (steps < oldSteps) {
      weeklySteps = (userData['weeklySteps'] ?? 0) + steps;
    }

    WriteBatch batch = _db.batch();
    
    if (newLevel > oldLevel) {
      // Prüfen, ob wir für dieses Level in diesem Batch schon eine Nachricht haben
      // oder ob es ein massiver Sprung ist (z.B. Raid Belohnung)
      for (String gId in groupIds) {
        DocumentReference msgRef = _db.collection('groups').doc(gId).collection('messages').doc();
        batch.set(msgRef, {
          'senderId': uid, 'senderName': 'System',
          'text': "🎉 $displayName ist gerade auf Level $newLevel aufgestiegen!",
          'timestamp': FieldValue.serverTimestamp(),
          'levelTag': "${uid}_$newLevel", // Eindeutiger Tag gegen Duplikate
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
    });

    // Add Raid contribution
    int stepDelta = steps - oldSteps;
    if (stepDelta > 0) {
      for (String gId in groupIds) {
        // Wir suchen nach allen Raids, die noch nicht beendet sind (flexiblere Abfrage)
        final raidQuery = await _db.collection('groups').doc(gId).collection('raids').get();

        for (var raidDoc in raidQuery.docs) {
          final data = raidDoc.data();
          final isDefeated = data['status'] == 'defeated' || data['isCompleted'] == true;
          final endDate = (data['endDate'] as Timestamp).toDate();
          
          if (!isDefeated && endDate.isAfter(DateTime.now())) {
            int targetSteps = data['targetSteps'] ?? 100000;
            int currentSteps = data['currentSteps'] ?? 0;
            
            Map<String, dynamic> updates = {
              'currentSteps': FieldValue.increment(stepDelta),
              'participants.$uid': FieldValue.increment(stepDelta),
            };

            if (currentSteps + stepDelta >= targetSteps) {
              updates['status'] = 'defeated';
              updates['isCompleted'] = true;
              updates['rewardDistributed'] = true;

              // Belohnung an alle Teilnehmer verteilen
              Map<String, dynamic> participants = Map<String, dynamic>.from(data['participants'] ?? {});
              // Aktuellen User hinzufügen, falls noch nicht drin
              participants[uid] = (participants[uid] ?? 0) + stepDelta;

              for (String pId in participants.keys) {
                batch.update(_db.collection('users').doc(pId), {
                  'points': FieldValue.increment(2000),
                });
              }

              // System-Nachricht
              DocumentReference msgRef = _db.collection('groups').doc(gId).collection('messages').doc();
              batch.set(msgRef, {
                'senderId': 'System',
                'senderName': 'System',
                'text': "🎊 BOSS BESIEGT! 2000 XP Belohnung für alle Teilnehmer! 🎊",
                'timestamp': FieldValue.serverTimestamp(),
                'levelTag': "${gId}_victory_${raidDoc.id}",
              });
            }

            batch.update(raidDoc.reference, updates);
          }
        }
      }
    }
    
    await batch.commit();
  }

  @override
  Future<void> updateStepGoal(String uid, int goal) async {
    await _db.collection('users').doc(uid).update({'goalValue': goal});
  }

  @override
  Future<List<DailyStatsModel>> getHistoricalStats(String uid, int days) async {
    final now = DateTime.now();
    final startDate = now.subtract(Duration(days: days));
    final query = await _db.collection('users').doc(uid).collection('daily_stats')
        .where('timestamp', isGreaterThanOrEqualTo: Timestamp.fromDate(startDate))
        .orderBy('timestamp', descending: true)
        .get();

    return query.docs.map((doc) => DailyStatsModel.fromMap(doc.data(), doc.id)).toList();
  }
}
