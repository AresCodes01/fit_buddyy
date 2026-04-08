class UserModel {
  final String id;
  final String email;
  final String displayName;
  final int dailySteps;
  final int streak;
  final List<String> groupIds;

  UserModel({
    required this.id,
    required this.email,
    required this.displayName,
    this.dailySteps = 0,
    this.streak = 0,
    this.groupIds = const [],
  });

  factory UserModel.fromMap(Map<String, dynamic> data, String documentId) {
    return UserModel(
      id: documentId,
      email: data['email'] ?? '',
      displayName: data['displayName'] ?? '',
      dailySteps: data['dailySteps'] ?? 0,
      streak: data['streak'] ?? 0,
      groupIds: List<String>.from(data['groupIds'] ?? []),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'displayName': displayName,
      'dailySteps': dailySteps,
      'streak': streak,
      'groupIds': groupIds,
    };
  }
}
