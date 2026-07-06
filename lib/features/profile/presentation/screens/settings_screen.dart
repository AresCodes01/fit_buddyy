import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fit_buddyy/features/auth/domain/models/user_model.dart';
import 'package:fit_buddyy/features/auth/domain/repositories/auth_repository.dart';
import 'package:fit_buddyy/features/home/domain/repositories/steps_repository.dart';
import 'package:fit_buddyy/providers/theme_provider.dart';
import 'package:fit_buddyy/features/auth/presentation/screens/link_account_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  void _showEditNameDialog(BuildContext context, AuthRepository repo, UserModel user) {
    final controller = TextEditingController(text: user.displayName);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Name ändern"),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(labelText: "Anzeigename"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Abbrechen")),
          ElevatedButton(
            onPressed: () async {
              if (controller.text.isNotEmpty) {
                await repo.updateDisplayName(user.id, controller.text);
                if (context.mounted) Navigator.pop(context);
              }
            },
            child: const Text("Speichern"),
          ),
        ],
      ),
    );
  }

  void _showEditEmailDialog(BuildContext context, AuthRepository repo, UserModel user) {
    final controller = TextEditingController(text: user.email);
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("E-Mail ändern"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: controller,
              decoration: const InputDecoration(labelText: "Neue E-Mail Adresse"),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 8),
            const Text(
              "Hinweis: Du erhältst eine Bestätigungsmail an die neue Adresse.",
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Abbrechen")),
          ElevatedButton(
            onPressed: () async {
              try {
                await repo.updateEmail(controller.text);
                if (context.mounted) {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Bestätigungsmail gesendet!")),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text("Fehler: $e")),
                  );
                }
              }
            },
            child: const Text("Update"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserModel?>();
    final authRepo = context.read<AuthRepository>();
    final themeProvider = context.read<ThemeProvider>();
    final stepsRepo = context.read<StepsRepository>();

    if (user == null) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Einstellungen')),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          Center(
            child: CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).colorScheme.primary,
              child: Text(
                user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : "?",
                style: const TextStyle(fontSize: 40, color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => _showEditNameDialog(context, authRepo, user),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(user.displayName, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                const Icon(Icons.edit, size: 18, color: Colors.grey),
              ],
            ),
          ),
          if (!user.isAnonymous)
            GestureDetector(
              onTap: () => _showEditEmailDialog(context, authRepo, user),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(user.email, style: const TextStyle(color: Colors.grey)),
                  const SizedBox(width: 4),
                  const Icon(Icons.edit, size: 14, color: Colors.grey),
                ],
              ),
            ),
          
          if (user.isAnonymous) ...[
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: Card(
                color: Theme.of(context).colorScheme.primaryContainer,
                elevation: 0,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      const Text("Sichere deine Daten!", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 12),
                      const Text("Erstelle ein Konto, um deine Erfolge und Gruppen nie zu verlieren.", textAlign: TextAlign.center, style: TextStyle(fontSize: 15)),
                      const SizedBox(height: 16),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(builder: (context) => const LinkAccountScreen()),
                            );
                          },
                          child: const Text("Jetzt Registrieren / Anmelden"),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
          const Divider(height: 40),
          _buildSettingsTile(context, icon: Icons.dark_mode, title: "Dunkler Modus", 
            trailing: Switch(value: themeProvider.themeMode == ThemeMode.dark, onChanged: (val) => themeProvider.toggleTheme(val))),
          _buildSettingsTile(context, icon: Icons.flag, title: "Tagesziel Schritte", subtitle: "${user.goalValue} Schritte",
            onTap: () => _showStepGoalDialog(context, stepsRepo, user)),
          if (!user.isAnonymous)
            _buildSettingsTile(context, icon: Icons.logout, title: "Abmelden", titleColor: Colors.red,
              onTap: () => authRepo.signOut()),
        ],
      ),
    );
  }

  Widget _buildSettingsTile(BuildContext context, {required IconData icon, required String title, String? subtitle, Widget? trailing, VoidCallback? onTap, Color? titleColor}) {
    return ListTile(
      leading: Icon(icon, color: titleColor ?? Theme.of(context).colorScheme.primary),
      title: Text(title, style: TextStyle(color: titleColor, fontWeight: FontWeight.w500)),
      subtitle: subtitle != null ? Text(subtitle) : null,
      trailing: trailing ?? const Icon(Icons.chevron_right, size: 20),
      onTap: onTap,
    );
  }

  void _showStepGoalDialog(BuildContext context, StepsRepository repo, UserModel user) {
    final controller = TextEditingController(text: user.goalValue.toString());
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Tagesziel anpassen"),
        content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Schritte pro Tag")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Abbrechen")),
          ElevatedButton(onPressed: () async {
              int? newGoal = int.tryParse(controller.text);
              if (newGoal != null) {
                await repo.updateStepGoal(user.id, newGoal);
                if (context.mounted) Navigator.pop(context);
              }
            }, child: const Text("Speichern")),
        ],
      ),
    );
  }
}
