import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';

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

    if (userModel == null) return const Center(child: CircularProgressIndicator());

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          _buildProfileSection(userModel),
          const Divider(),
          _buildStepGoalSection(userModel, db),
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

  Widget _buildStepGoalSection(UserModel user, FirebaseService db) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Schritt-Ziele', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
        ),
        ListTile(
          title: const Text('Ziel-Typ'),
          subtitle: Text(user.goalType == 'interval' ? 'Punkte pro Intervall' : 'Tagesziel-Bonus'),
          trailing: DropdownButton<String>(
            value: user.goalType,
            items: const [
              DropdownMenuItem(value: 'interval', child: Text('Intervall')),
              DropdownMenuItem(value: 'target', child: Text('Tagesziel')),
            ],
            onChanged: (val) {
              if (val != null) {
                db.updateGoals(user.id, val, user.goalValue);
              }
            },
          ),
        ),
        ListTile(
          title: const Text('Ziel-Wert'),
          subtitle: Text('${user.goalValue} Schritte'),
          trailing: TextButton(
            child: Text('${user.goalValue}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            onPressed: () => _showStepValueDialog(user, db),
          ),
        ),
      ],
    );
  }

  Widget _buildWorkoutGoalSection(UserModel user, FirebaseService db) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.all(16.0),
          child: Text('Workout-Ziele', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
        ),
        ListTile(
          title: const Text('Wochenziel'),
          subtitle: Text('${user.workoutGoalWeekly} Workouts pro Woche'),
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
    return SwitchListTile(
      title: const Text('Dark Mode'),
      secondary: Icon(theme.isDarkMode ? Icons.dark_mode : Icons.light_mode),
      value: theme.isDarkMode,
      onChanged: (bool value) => theme.toggleTheme(value),
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

  void _showStepValueDialog(UserModel user, FirebaseService db) {
    final controller = TextEditingController(text: user.goalValue.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(user.goalType == 'interval' ? 'Intervall anpassen' : 'Tagesziel anpassen'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Wert eingeben'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null) {
                db.updateGoals(user.id, user.goalType, val);
                Navigator.pop(context);
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }
}
