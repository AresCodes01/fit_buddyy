import '../models/workout_session.dart';

abstract class WorkoutRepository {
  Future<void> saveWorkout(WorkoutSession session);
  Stream<List<WorkoutSession>> getWorkouts(String userId);
}
