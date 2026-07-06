import 'package:flutter/material.dart';
import 'package:fit_buddyy/features/auth/domain/models/user_model.dart';

class UserComparisonScreen extends StatelessWidget {
  final UserModel currentUser;
  final UserModel targetUser;

  const UserComparisonScreen({
    super.key,
    required this.currentUser,
    required this.targetUser,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('1 vs 1 Vergleich')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildUserAvatar(currentUser),
                const Text("VS", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.red)),
                _buildUserAvatar(targetUser),
              ],
            ),
            const SizedBox(height: 32),
            _buildStatRow(context, "Schritte heute", currentUser.dailySteps, targetUser.dailySteps),
            _buildStatRow(context, "Wochenschritte", currentUser.weeklySteps, targetUser.weeklySteps),
            _buildStatRow(context, "Workouts (Woche)", currentUser.workoutsThisWeek, targetUser.workoutsThisWeek),
            _buildStatRow(context, "Level", currentUser.level, targetUser.level),
            _buildStatRow(context, "XP Punkte", currentUser.points, targetUser.points),
            _buildStatRow(context, "Streak", currentUser.streak, targetUser.streak),
          ],
        ),
      ),
    );
  }

  Widget _buildUserAvatar(UserModel user) {
    return Column(
      children: [
        CircleAvatar(
          radius: 40,
          backgroundColor: Colors.blueGrey,
          child: Text(
            user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : "?",
            style: const TextStyle(fontSize: 32, color: Colors.white, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        Text(user.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
      ],
    );
  }

  Widget _buildStatRow(BuildContext context, String label, num val1, num val2) {
    final bool isBetter = val1 >= val2;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Text(label, style: const TextStyle(fontSize: 14, color: Colors.grey)),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  "$val1",
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: isBetter
                        ? Colors.green
                        : (Theme.of(context).brightness == Brightness.light
                            ? Colors.black
                            : Colors.white),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: LinearProgressIndicator(
                  value: (val1 + val2 == 0) ? 0.5 : val1 / (val1 + val2),
                  backgroundColor: Colors.red.withValues(alpha: 0.4),
                  color: Colors.green,
                  minHeight: 10,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Text(
                  "$val2",
                  textAlign: TextAlign.left,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: !isBetter
                        ? Colors.green
                        : (Theme.of(context).brightness == Brightness.light
                            ? Colors.black
                            : Colors.white),
                  ),
                ),
              ),
            ],
          ),
          const Divider(),
        ],
      ),
    );
  }
}
