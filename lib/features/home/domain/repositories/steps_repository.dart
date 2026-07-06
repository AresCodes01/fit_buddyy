import '../models/daily_stats_model.dart';

abstract class StepsRepository {
  Stream<DailyStatsModel?> getDailyStats(String uid, String dateId);
  Stream<List<DailyStatsModel>> getWeeklyStatsStream(String uid);
  Future<void> updateSteps(String uid, String dateId, int steps);
  Future<void> updateStepGoal(String uid, int goal);
  Future<List<DailyStatsModel>> getHistoricalStats(String uid, int days);
}
