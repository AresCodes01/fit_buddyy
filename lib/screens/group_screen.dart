import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import 'chat_screen.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _groupNameController = TextEditingController();

  void _createGroup() async {
    final user = Provider.of<UserModel?>(context, listen: false);
    final db = context.read<FirebaseService>();
    final name = _groupNameController.text.trim();

    if (user != null && name.isNotEmpty) {
      if (user.isAnonymous) {
        _showLoginRequiredDialog();
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context); // Close dialog

      try {
        await db.createGroup(name, user.id);
        _groupNameController.clear();
        messenger.showSnackBar(
          const SnackBar(content: Text('Gruppe erfolgreich erstellt!')),
        );
      } catch (e) {
        messenger.showSnackBar(
          SnackBar(content: Text('Fehler: $e')),
        );
      }
    }
  }

  void _showLoginRequiredDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Anmeldung erforderlich'),
        content: const Text('Um Gruppen beizutreten oder zu erstellen, musst du ein Konto erstellen.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<FirebaseService>().signOut(); // Triggers AuthWrapper to show AuthScreen
            },
            child: const Text('Jetzt registrieren'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _groupNameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    final db = context.read<FirebaseService>();

    if (user == null) return const Center(child: CircularProgressIndicator());

    // UI für anonyme User
    if (user.isAnonymous) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.group_add, size: 80, color: Colors.grey),
              const SizedBox(height: 20),
              const Text(
                'Gruppen & Community',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                'Vergleiche deine Schritte mit Freunden und motiviert euch gegenseitig. Melde dich an, um loszulegen!',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                  backgroundColor: Colors.blueAccent,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => db.signOut(),
                child: const Text('Jetzt registrieren / einloggen'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.getGroups(user.groupIds),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final groups = snapshot.data ?? [];
          
          if (groups.isEmpty) {
            return const Center(child: Text('Tritt einer Gruppe bei oder erstelle eine!'));
          }

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.group)),
                title: Text(group['name']),
                subtitle: Text('${(group['members'] as List).length} Mitglieder'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => ChatScreen(
                      groupId: group['id'], 
                      groupName: group['name'],
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.blueAccent,
        foregroundColor: Colors.white,
        child: const Icon(Icons.add),
        onPressed: () => _showCreateGroupDialog(),
      ),
    );
  }

  void _showCreateGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neue Gruppe'),
        content: TextField(
          controller: _groupNameController, 
          decoration: const InputDecoration(hintText: 'Gruppenname'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context), 
            child: const Text('Abbrechen'),
          ),
          ElevatedButton(
            onPressed: _createGroup, 
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );
  }
}
