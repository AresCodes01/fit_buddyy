class UserModel {
  final String id;
  final String email;
  final String displayName;
  final String photoUrl;
  final int dailySteps;
  final int weeklySteps;
  final int streak;
  final int level;
  final int points;
  final List<String> groupIds;
  final bool isAnonymous;
  final String goalType; 
  final int goalValue;
  final int workoutGoalWeekly;
  final int workoutsThisWeek;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.photoUrl = '',
    this.dailySteps = 0,
    this.weeklySteps = 0,
    this.streak = 0,
    this.level = 1,
    this.points = 0,
    this.groupIds = const [],
    this.isAnonymous = false,
    this.goalType = 'interval',
    this.goalValue = 100,
    this.workoutGoalWeekly = 3,
    this.workoutsThisWeek = 0,
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      id: documentId,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      photoUrl: data['photoUrl'] ?? '',
      dailySteps: data['dailySteps'] ?? 0,
      weeklySteps: data['weeklySteps'] ?? 0,
      streak: data['streak'] ?? 0,
      level: data['level'] ?? 1,
      points: data['points'] ?? 0,
      groupIds: List<String>.from(data['groupIds'] ?? []),
      isAnonymous: data['isAnonymous'] ?? false,
      goalType: data['goalType'] ?? 'interval',
      goalValue: data['goalValue'] ?? 100,
      workoutGoalWeekly: data['workoutGoalWeekly'] ?? 3,
      workoutsThisWeek: data['workoutsThisWeek'] ?? 0,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'photoUrl': photoUrl,
      'dailySteps': dailySteps,
      'weeklySteps': weeklySteps,
      'streak': streak,
      'level': level,
      'points': points,
      'groupIds': groupIds,
      'isAnonymous': isAnonymous,
      'goalType': goalType,
      'goalValue': goalValue,
      'workoutGoalWeekly': workoutGoalWeekly,
      'workoutsThisWeek': workoutsThisWeek,
    };
  }
}
