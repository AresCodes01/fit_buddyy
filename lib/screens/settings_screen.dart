import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  bool _isGenerating = false;

  void _generateTestData() async {
    setState(() => _isGenerating = true);
    final user = Provider.of<UserModel?>(context, listen: false);
    final db = FirebaseFirestore.instance;

    if (user != null) {
      final now = DateTime.now();
      WriteBatch batch = db.batch();

      for (int i = 0; i < 7; i++) {
        final date = now.subtract(Duration(days: i));
        final dateId = date.toString().split(' ')[0]; // YYYY-MM-DD
        final steps = 3000 + (i * 1200) % 7000; 

        DocumentReference ref = db.collection('users').doc(user.id).collection('daily_stats').doc(dateId);
        batch.set(ref, {
          'steps': steps,
          'timestamp': Timestamp.fromDate(date), // WICHTIG: Unterschiedliche Zeitstempel!
        });
      }

      await batch.commit();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Test-Daten für 7 unterschiedliche Tage erstellt! 🔥')),
        );
      }
    }
    setState(() => _isGenerating = false);
  }

  void _showStepGoalDialog(UserModel user, FirebaseService db) {
    final controller = TextEditingController(text: user.goalValue.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Tagesziel anpassen'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: 'Anzahl Schritte', suffixText: 'Schritte'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              final val = int.tryParse(controller.text);
              if (val != null && val > 0) {
                db.updateStepGoal(user.id, val);
                Navigator.pop(context);
              }
            },
            child: const Text('Speichern'),
          ),
        ],
      ),
    );
  }

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
          _buildGoalSection(userModel, db),
          const Divider(),
          _buildWorkoutGoalSection(userModel, db),
          const Divider(),
          _buildThemeSection(themeProvider),
          const Divider(),
          _buildInfoSection(userModel),
          const Divider(),
          _buildDeveloperSection(),
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

  Widget _buildGoalSection(UserModel user, FirebaseService db) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle("Schritt-Ziele"),
        ListTile(
          leading: const Icon(Icons.flag_outlined, color: Colors.blueAccent),
          title: const Text('Dein Tagesziel'),
          subtitle: Text('${user.goalValue} Schritte pro Tag'),
          trailing: TextButton(
            child: const Text("Ändern", style: TextStyle(fontWeight: FontWeight.bold)),
            onPressed: () => _showStepGoalDialog(user, db),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection(UserModel user) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle("Dein Fortschritt"),
        const ListTile(
          leading: Icon(Icons.flash_on, color: Colors.amber),
          title: Text("Punkte-System"),
          subtitle: Text("Du erhältst 1 XP pro 100 Schritte und Bonus bei Erreichen deines Ziels."),
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
          leading: const Icon(Icons.fitness_center, color: Colors.blueAccent),
          title: const Text('Workouts pro Woche'),
          subtitle: Text('${user.workoutGoalWeekly} Einheiten geplant'),
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

  Widget _buildDeveloperSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SectionTitle("Entwickler Tools"),
        ListTile(
          leading: const Icon(Icons.bug_report, color: Colors.orange),
          title: const Text("Wochen-Trend testen"),
          subtitle: const Text("Erzeugt zufällige Schritte für die letzten 7 Tage"),
          trailing: _isGenerating 
            ? const CircularProgressIndicator() 
            : const Icon(Icons.play_arrow),
          onTap: _generateTestData,
        ),
      ],
    );
  }

  Widget _buildAccountSection(UserModel user, FirebaseService db) {
    return Column(
      children: [
        if (user.isAnonymous)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: () => db.signOut(),
                icon: const Icon(Icons.login),
                label: const Text("Konto erstellen / Einloggen"),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  backgroundColor: Colors.green,
                ),
              ),
            ),
          )
        else
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text("Abmelden"),
            onTap: () => db.signOut(),
          ),
      ],
    );
  }
}
