import 'package:flutter/material.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import 'chat_screen.dart';

class GroupScreen extends StatefulWidget {
  final UserModel user;
  const GroupScreen({super.key, required this.user});

  @override
  _GroupScreenState createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final FirebaseService _db = FirebaseService();
  final _groupNameController = TextEditingController();

  void _createGroup() async {
    if (_groupNameController.text.isNotEmpty) {
      await _db.createGroup(_groupNameController.text, widget.user.id);
      _groupNameController.clear();
      Navigator.pop(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Meine Gruppen')),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _db.getGroups(widget.user.groupIds),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
          final groups = snapshot.data!;
          return ListView.builder(
            itemCount: groups.length,
            itemBuilder: (context, index) {
              final group = groups[index];
              return ListTile(
                title: Text(group['name']),
                subtitle: Text('${(group['members'] as List).length} Mitglieder'),
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (context) => ChatScreen(groupId: group['id'], groupName: group['name'], user: widget.user)),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        child: const Icon(Icons.add),
        onPressed: () => showDialog(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Neue Gruppe'),
            content: TextField(controller: _groupNameController, decoration: const InputDecoration(hintText: 'Gruppenname')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
              TextButton(onPressed: _createGroup, child: const Text('Erstellen')),
            ],
          ),
        ),
      ),
    );
  }
}
