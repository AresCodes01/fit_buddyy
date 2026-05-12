import 'package:cloud_firestore/cloud_firestore.dart';

enum WorkoutType {
  strengthTraining('Krafttraining', '🏋️'),
  cardio('Cardio', '🏃'),
  yoga('Yoga', '🧘'),
  cycling('Radfahren', '🚴'),
  swimming('Schwimmen', '🏊'),
  other('Sonstiges', '🔥');

  final String label;
  final String icon;
  const WorkoutType(this.label, this.icon);
}

class WorkoutSession {
  final String? id;
  final String userId;
  final String userName;
  final Duration duration;
  final WorkoutType type;
  final int calories;
  final String intensity;
  final DateTime timestamp;

  WorkoutSession({
    this.id,
    required this.userId,
    required this.userName,
    required this.duration,
    required this.type,
    required this.calories,
    required this.intensity,
    required this.timestamp,
  });

  Map<String, dynamic> toMap() {
    return {
      'userId': userId,
      'userName': userName,
      'durationMinutes': duration.inMinutes,
      'type': type.name,
      'calories': calories,
      'intensity': intensity,
      'timestamp': Timestamp.fromDate(timestamp),
    };
  }

  factory WorkoutSession.fromMap(Map<String, dynamic> map, String id) {
    return WorkoutSession(
      id: id,
      userId: map['userId'] ?? '',
      userName: map['userName'] ?? '',
      duration: Duration(minutes: map['durationMinutes'] ?? 0),
      type: WorkoutType.values.firstWhere(
        (e) => e.name == map['type'],
        orElse: () => WorkoutType.other,
      ),
      calories: map['calories'] ?? 0,
      intensity: map['intensity'] ?? 'Mittel',
      timestamp: (map['timestamp'] as Timestamp).toDate(),
    );
  }
}
