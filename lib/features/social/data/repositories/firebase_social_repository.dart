import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../auth/domain/models/user_model.dart';
import '../../domain/models/raid_model.dart';
import '../../domain/repositories/social_repository.dart';
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

  // Boss Raid Methods

  @override
  Stream<RaidModel?> getActiveRaid(String groupId) {
    return _db.collection('groups').doc(groupId).collection('raids')
        .snapshots()
        .map((snap) {
          final now = DateTime.now();
          
          // 1. Suche nach einem wirklich aktiven Boss
          final activeDocs = snap.docs.where((doc) {
            final data = doc.data();
            final endDate = (data['endDate'] as Timestamp).toDate();
            final isNotDefeated = data['status'] != 'defeated' && data['isCompleted'] != true;
            return isNotDefeated && endDate.isAfter(now);
          }).toList();
          
          if (activeDocs.isNotEmpty) {
            return RaidModel.fromMap(activeDocs.first.id, activeDocs.first.data());
          }

          // 2. Wenn kein aktiver Boss da ist, prüfen wir, ob wir einen neuen starten müssen
          // Wir tun dies verzögert, um Endlosschleifen im Stream zu vermeiden
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

      if (isNowDefeated) {
        // Generate Loot for the group
        updateData['rewards'] = {
          'xp': 2000,
          'items': [
            {
              'name': 'Legendärer Laufschuh',
              'emoji': '👟',
              'rarity': 'legendary',
              'bonusType': 'xp_multiplier',
              'bonusValue': 1.5,
            }
          ]
        };
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
      'weekId': weekId,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }
}
