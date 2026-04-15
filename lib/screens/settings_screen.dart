import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../services/firebase_service.dart';
import '../models/user_model.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final userModel = Provider.of<UserModel?>(context);
    final authService = Provider.of<FirebaseService>(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Einstellungen'),
      ),
      body: ListView(
        children: [
          const SizedBox(height: 20),
          // Profil Sektion
          ListTile(
            leading: const CircleAvatar(
              backgroundColor: Colors.blueAccent,
              child: Icon(Icons.person, color: Colors.white),
            ),
            title: Text(userModel?.displayName ?? 'Gast'),
            subtitle: Text(userModel?.email ?? (userModel?.isAnonymous == true ? 'Anonymer Account' : '')),
          ),
          const Divider(),
          
          // Design Sektion
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Design', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          ),
          SwitchListTile(
            title: const Text('Dark Mode'),
            secondary: Icon(themeProvider.isDarkMode ? Icons.dark_mode : Icons.light_mode),
            value: themeProvider.isDarkMode,
            onChanged: (bool value) {
              themeProvider.toggleTheme(value);
            },
          ),
          const Divider(),

          // Account Sektion
          const Padding(
            padding: EdgeInsets.all(16.0),
            child: Text('Account', style: TextStyle(fontWeight: FontWeight.bold, color: Colors.blueAccent)),
          ),
          if (userModel?.isAnonymous == true)
            ListTile(
              leading: const Icon(Icons.app_registration, color: Colors.green),
              title: const Text('Jetzt registrieren'),
              onTap: () {
                authService.signOut();
              },
            ),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Abmelden'),
            onTap: () {
              authService.signOut();
            },
          ),
          
          const Divider(),
          const AboutListTile(
            icon: Icon(Icons.info_outline),
            applicationName: 'Fit Buddy',
            applicationVersion: '1.0.0',
            child: Text('Deine Fitness App für tägliche Motivation.'),
          ),
        ],
      ),
    );
  }
}
