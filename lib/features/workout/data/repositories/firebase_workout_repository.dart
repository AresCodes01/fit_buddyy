import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fit_buddyy/features/workout/domain/models/workout_session.dart';
import 'package:fit_buddyy/features/workout/domain/repositories/workout_repository.dart';

class FirebaseWorkoutRepository implements WorkoutRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Future<void> saveWorkout(WorkoutSession session) async {
    final batch = _firestore.batch();

    // 1. Save workout to user's subcollection
    final workoutRef = _firestore
        .collection('users')
        .doc(session.userId)
        .collection('workouts')
        .doc();
    
    batch.set(workoutRef, session.toMap());

    // 2. Add to group feeds for each group the user is in
    // Note: In a real app, we might want to fetch groupIds from the user document here 
    // or pass them into this method. For this implementation, we'll assume the caller 
    // provides the session which could be extended or we fetch user data.
    // To keep it clean as requested, I'll fetch the user document to get groupIds.
    
    final userDoc = await _firestore.collection('users').doc(session.userId).get();
    final List<String> groupIds = List<String>.from(userDoc.data()?['groupIds'] ?? []);

    for (String groupId in groupIds) {
      final messageRef = _firestore
          .collection('groups')
          .doc(groupId)
          .collection('messages')
          .doc();
      
      batch.set(messageRef, {
        'senderId': session.userId,
        'senderName': 'System',
        'text': '🔥 ${session.userName} hat ein Workout beendet: ${session.type.label} (${session.duration.inMinutes} Min)!',
        'timestamp': FieldValue.serverTimestamp(),
      });
    }

    // 3. Update user stats (e.g. workoutsThisWeek, points)
    final userRef = _firestore.collection('users').doc(session.userId);
    batch.update(userRef, {
      'workoutsThisWeek': FieldValue.increment(1),
      'points': FieldValue.increment(50), // Example points
    });

    await batch.commit();
  }

  @override
  Stream<List<WorkoutSession>> getWorkouts(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('workouts')
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => WorkoutSession.fromMap(doc.data(), doc.id))
            .toList());
  }
}
