import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fit_buddyy/features/auth/domain/models/user_model.dart';
import 'package:fit_buddyy/features/social/domain/models/raid_model.dart';
import 'package:fit_buddyy/features/social/domain/repositories/social_repository.dart';
import 'dart:math';

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
    // Start initial raid for new group
    await startWeeklyRaid(groupRef.id);
  }

  // ... (joinGroup, getGroups, getGroupMembers, sendMessage, getMessages, getGroupById - no changes needed to existing logic, just keeping them)

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
    // Listen to group changes to get the latest list of member IDs
    return _db.collection('groups').doc(groupId).snapshots().asyncExpand((groupSnap) {
      if (!groupSnap.exists) return Stream.value([]);
      
      final List<dynamic> memberIds = groupSnap.data()?['members'] ?? [];
      if (memberIds.isEmpty) return Stream.value([]);
      
      // Return a live stream of member documents to ensure real-time leaderboard updates
      return _db.collection('users')
          .where(FieldPath.documentId, whereIn: memberIds)
          .snapshots()
          .map((userSnaps) => userSnaps.docs.map((doc) => UserModel.fromMap(doc.data(), doc.id)).toList());
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

  // Boss Raid Methods

  @override
  Stream<RaidModel?> getActiveRaid(String groupId) {
    return _db.collection('groups').doc(groupId).collection('raids')
        .snapshots()
        .map((snap) {
          final now = DateTime.now();
          
      // Wir holen einfach alle und filtern in Dart (verhindert Index-Fehler)
          final raids = snap.docs.map((d) => RaidModel.fromMap(d.id, d.data())).toList();
          
          // 1. Suche nach dem aktuellsten aktiven Boss
          final activeRaids = raids.where((r) => r.status == 'active' && r.endDate.isAfter(now)).toList();
          
          if (activeRaids.isNotEmpty) {
            // Sortiere nach Enddatum (bald endend zuerst)
            activeRaids.sort((a, b) => a.endDate.compareTo(b.endDate));
            return activeRaids.first;
          }

          // 2. Suche nach dem ZULETZT besiegten Boss der Woche (für das Loot-Overlay)
          final defeatedRaids = raids.where((r) => r.status == 'defeated').toList();
          if (defeatedRaids.isNotEmpty) {
            defeatedRaids.sort((a, b) => b.endDate.compareTo(a.endDate));
            return defeatedRaids.first;
          }

          // 3. Wenn gar nichts da ist, starte neuen
          _checkAndStartNewRaid(groupId, snap.docs);
          
          return null;
        });
  }

  Future<void> _checkAndStartNewRaid(String groupId, List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekId = "W${monday.year}-${monday.month}-${monday.day}";

    // Prüfen, ob für diese Woche schon ein Boss existiert
    bool hasRaidThisWeek = docs.any((doc) => doc.data()['weekId'] == weekId);
    
    if (!hasRaidThisWeek) {
      await startWeeklyRaid(groupId);
    }
  }

  @override
  Future<void> contributeToRaid(String groupId, String raidId, String userId, int steps) async {
    final raidRef = _db.collection('groups').doc(groupId).collection('raids').doc(raidId);
    
    await _db.runTransaction((transaction) async {
      final snapshot = await transaction.get(raidRef);
      if (!snapshot.exists) return;
      
      final data = snapshot.data()!;
      if (data['status'] == 'defeated') return;

      int currentSteps = data['currentSteps'] ?? 0;
      int targetSteps = data['targetSteps'] ?? 100000;
      Map<String, dynamic> participants = Map<String, dynamic>.from(data['participants'] ?? {});
      
      int userContr = (participants[userId] ?? 0) + steps;
      participants[userId] = userContr;
      
      int newSteps = currentSteps + steps;
      bool isNowDefeated = newSteps >= targetSteps;
      String status = isNowDefeated ? 'defeated' : 'active';
      
      Map<String, dynamic> updateData = {
        'currentSteps': newSteps,
        'status': status,
        'participants': participants,
      };

      if (isNowDefeated && data['rewardDistributed'] != true) {
        // Markiere als belohnt, damit XP nur 1x vergeben werden
        updateData['rewardDistributed'] = true;

        // 1. XP-Belohnung für alle Teilnehmer (2000 XP)
        for (String participantId in participants.keys) {
          final userRef = _db.collection('users').doc(participantId);
          transaction.update(userRef, {
            'points': FieldValue.increment(2000),
          });
        }
        
        // 3. System-Nachricht in den Chat schicken
        DocumentReference msgRef = _db.collection('groups').doc(groupId).collection('messages').doc();
        transaction.set(msgRef, {
          'senderId': 'System',
          'senderName': 'System',
          'text': "🎊 DER BOSS WURDE BEZWUNGEN! Alle Teilnehmer erhalten 2000 XP! 🎊",
          'timestamp': FieldValue.serverTimestamp(),
        });
      }
      
      transaction.update(raidRef, updateData);
    });
  }

  @override
  Future<void> startWeeklyRaid(String groupId) async {
    final now = DateTime.now();
    final monday = now.subtract(Duration(days: now.weekday - 1));
    final weekId = "W${monday.year}-${monday.month}-${monday.day}";
    
    final raidQuery = await _db.collection('groups').doc(groupId).collection('raids')
        .where('weekId', isEqualTo: weekId)
        .get();
        
    if (raidQuery.docs.isNotEmpty) return;

    final bossTypes = BossType.values;
    final randomBoss = bossTypes[Random().nextInt(bossTypes.length)];
    final sunday = monday.add(const Duration(days: 6, hours: 23, minutes: 59));

    await _db.collection('groups').doc(groupId).collection('raids').add({
      'title': 'Besiegt den ${randomBoss.label}!',
      'bossType': randomBoss.name,
      'targetSteps': 100000,
      'currentSteps': 0,
      'endDate': Timestamp.fromDate(sunday),
      'status': 'active',
      'participants': {},
      'claimedBy': [], // Initialize empty
      'weekId': weekId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> claimRaidReward(String groupId, String raidId, String userId) async {
    await _db.collection('groups').doc(groupId).collection('raids').doc(raidId).update({
      'claimedBy': FieldValue.arrayUnion([userId])
    });
  }
}
