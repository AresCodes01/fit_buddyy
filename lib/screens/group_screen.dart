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
  final _joinIdController = TextEditingController();
  bool _isCreating = false;

  void _createGroup() async {
    if (_isCreating) return;

    final user = Provider.of<UserModel?>(context, listen: false);
    final db = context.read<FirebaseService>();
    final name = _groupNameController.text.trim();

    if (user != null && name.isNotEmpty) {
      if (user.isAnonymous) {
        _showLoginRequiredDialog();
        return;
      }

      setState(() => _isCreating = true);
      final messenger = ScaffoldMessenger.of(context);
      
      try {
        await db.createGroup(name, user.id);
        if (mounted) {
          Navigator.pop(context); // Dialog schließen
          _groupNameController.clear();
          messenger.showSnackBar(const SnackBar(content: Text('Gruppe erfolgreich erstellt!')));
        }
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
      } finally {
        if (mounted) setState(() => _isCreating = false);
      }
    }
  }

  void _joinGroup() async {
    final user = Provider.of<UserModel?>(context, listen: false);
    final db = context.read<FirebaseService>();
    final groupId = _joinIdController.text.trim();

    if (user != null && groupId.isNotEmpty) {
      if (user.isAnonymous) {
        _showLoginRequiredDialog();
        return;
      }

      final messenger = ScaffoldMessenger.of(context);
      try {
        await db.joinGroup(groupId, user.id);
        if (mounted) {
          Navigator.pop(context);
          _joinIdController.clear();
          messenger.showSnackBar(const SnackBar(content: Text('Erfolgreich beigetreten!')));
        }
      } catch (e) {
        messenger.showSnackBar(SnackBar(content: Text('Fehler: $e')));
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              context.read<FirebaseService>().signOut();
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
    _joinIdController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = Provider.of<UserModel?>(context);
    final db = context.read<FirebaseService>();

    if (user == null) return const Center(child: CircularProgressIndicator());

    if (user.isAnonymous) {
      return _buildGuestView(db);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gruppen'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _showJoinGroupDialog,
            tooltip: 'Beitreten',
          ),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: db.getGroups(user.groupIds),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          
          final groups = snapshot.data ?? [];
          
          if (groups.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.group_off, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Noch keine Gruppen.', style: TextStyle(color: Colors.grey)),
                  Text('Erstelle eine oder tritt einer bei!'),
                ],
              ),
            );
          }

          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                leading: const CircleAvatar(backgroundColor: Colors.blueAccent, child: Icon(Icons.group, color: Colors.white)),
                title: Text(group['name']),
                subtitle: Text('${(group['members'] as List).length} Mitglieder - ID: ${group['id'].toString().substring(0, 5)}...'),
                trailing: const Icon(Icons.chevron_right),
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

  Widget _buildGuestView(FirebaseService db) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.group_add, size: 80, color: Colors.grey),
            const SizedBox(height: 20),
            const Text('Gruppen & Community', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            const Text('Vergleiche deine Schritte mit Freunden. Melde dich an, um loszulegen!', textAlign: TextAlign.center),
            const SizedBox(height: 30),
            ElevatedButton(onPressed: () => db.signOut(), child: const Text('Jetzt registrieren')),
          ],
        ),
      ),
    );
  }

  void _showCreateGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Neue Gruppe'),
          content: TextField(
            controller: _groupNameController, 
            decoration: const InputDecoration(hintText: 'Gruppenname'),
            autofocus: true,
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
            if (_isCreating)
              const CircularProgressIndicator()
            else
              ElevatedButton(onPressed: _createGroup, child: const Text('Erstellen')),
          ],
        ),
      ),
    );
  }

  void _showJoinGroupDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gruppe beitreten'),
        content: TextField(
          controller: _joinIdController, 
          decoration: const InputDecoration(hintText: 'Gruppen-ID eingeben', helperText: 'Frage einen Freund nach seiner ID'),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(onPressed: _joinGroup, child: const Text('Beitreten')),
        ],
      ),
    );
  }
}
