import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';
import '../widgets/common_widgets.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userModel = Provider.of<UserModel?>(context);
    final db = Provider.of<FirebaseService>(context);

    if (userModel == null) return const LoadingSpinner();

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          _buildProfileSection(userModel),
          const Divider(),
          _buildInfoSection(userModel),
          const Divider(),
          _buildWorkoutGoalSection(userModel, db),
          const Divider(),
          _buildThemeSection(themeProvider),
          const Divider(),
          _buildAccountSection(userModel, db),
        ],
      ),
    );
  }

  Widget _buildProfileSection(UserModel user) {
    return ListTile(
      leading: const CircleAvatar(
        backgroundColor: Colors.blueAccent,
        child: Icon(Icons.person, color: Colors.white),
      ),
      title: Text(user.displayName),
      subtitle: Text(user.isAnonymous ? 'Gast-Account' : user.email),
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        decoration: BoxDecoration(color: Colors.blueAccent, borderRadius: BorderRadius.circular(12)),
        child: Text('Level ${user.level}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
      ),
    );
  }

  Widget _buildInfoSection(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle("Dein Fortschritt"),
        ListTile(
          leading: const Icon(Icons.flash_on, color: Colors.amber),
          title: const Text("Punkte-System"),
          subtitle: const Text("Du erhältst 1 XP pro 100 Schritte und Bonus bei 10.000 Schritten."),
        ),
        ListTile(
          leading: const Icon(Icons.ac_unit, color: Colors.lightBlueAccent),
          title: const Text("Streak Freezer"),
          subtitle: Text("Du hast aktuell ${user.streakFreezers} Freezer übrig."),
        ),
      ],
    );
  }

  Widget _buildWorkoutGoalSection(UserModel user, FirebaseService db) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle("Wöchentliches Workout-Ziel"),
        ListTile(
          title: const Text('Ziel setzen'),
          subtitle: Text('${user.workoutGoalWeekly} Workouts pro Woche geplant'),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                icon: const Icon(Icons.remove_circle_outline, color: Colors.redAccent),
                onPressed: user.workoutGoalWeekly > 1 
                  ? () => db.updateWorkoutGoal(user.id, user.workoutGoalWeekly - 1)
                  : null,
              ),
              Text('${user.workoutGoalWeekly}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              IconButton(
                icon: const Icon(Icons.add_circle_outline, color: Colors.green),
                onPressed: user.workoutGoalWeekly < 7 
                  ? () => db.updateWorkoutGoal(user.id, user.workoutGoalWeekly + 1)
                  : null,
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildThemeSection(ThemeProvider theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle("Design"),
        SwitchListTile(
          title: const Text('Dark Mode'),
          secondary: Icon(theme.isDarkMode ? Icons.dark_mode : Icons.light_mode),
          value: theme.isDarkMode,
          onChanged: (bool value) => theme.toggleTheme(value),
        ),
      ],
    );
  }

  Widget _buildAccountSection(UserModel user, FirebaseService db) {
    return Column(
      children: [
        if (user.isAnonymous)
          ListTile(
            leading: const Icon(Icons.app_registration, color: Colors.green),
            title: const Text('Jetzt registrieren'),
            onTap: () => db.signOut(),
          ),
        ListTile(
          leading: const Icon(Icons.logout, color: Colors.redAccent),
          title: const Text('Abmelden'),
          onTap: () => db.signOut(),
        ),
      ],
    );
  }
}
