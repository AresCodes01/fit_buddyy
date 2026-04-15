import 'package:cloud_firestore/cloud_firestore.dart';

class DailyStatsModel {
  final String dateId; // Format: YYYY-MM-DD
  final int steps;
  final DateTime timestamp;

  DailyStatsModel({
    required this.dateId,
    required this.steps,
    required this.timestamp,
  });

  factory DailyStatsModel.fromMap(Map<String, dynamic> data, String id) {
    return DailyStatsModel(
      dateId: id,
      steps: data['steps'] ?? 0,
      timestamp: (data['timestamp'] as Timestamp).toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'steps': steps,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }
}
