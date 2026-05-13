import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fit_buddyy/features/auth/domain/models/user_model.dart';
import 'package:fit_buddyy/features/social/domain/repositories/social_repository.dart';
import 'package:fit_buddyy/features/auth/domain/repositories/auth_repository.dart';
import 'chat_screen.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _nameController = TextEditingController();

  void _showCreateGroupDialog(SocialRepository socialRepo, String userId) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Neue Gruppe erstellen'),
        content: TextField(
          controller: _nameController,
          decoration: const InputDecoration(hintText: "Gruppenname"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              if (_nameController.text.isNotEmpty) {
                await socialRepo.createGroup(_nameController.text, userId);
                if (mounted) {
                  _nameController.clear();
                  Navigator.pop(context);
                }
              }
            },
            child: const Text('Erstellen'),
          ),
        ],
      ),
    );
  }

  void _showJoinGroupDialog(SocialRepository socialRepo, String userId) {
    final controller = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Gruppe beitreten'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(hintText: "Gruppen-ID einfügen"),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('Abbrechen')),
          ElevatedButton(
            onPressed: () async {
              try {
                await socialRepo.joinGroup(controller.text.trim(), userId);
                if (mounted) Navigator.pop(context);
              } catch (e) {
                if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fehler: $e")));
              }
            },
            child: const Text('Beitreten'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserModel?>();
    final socialRepo = context.read<SocialRepository>();

    if (user == null) return const Center(child: CircularProgressIndicator());

    if (user.isAnonymous) {
      return Scaffold(
        appBar: AppBar(title: const Text('Gruppen')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.group_add, size: 80, color: Colors.grey),
                const SizedBox(height: 24),
                Text(
                  "Gemeinsam stärker!",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Um Gruppen beizutreten oder eigene zu erstellen, benötigst du ein Konto.",
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 16, color: Colors.grey),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      padding: const EdgeInsets.all(16),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: () => context.read<AuthRepository>().signOut(),
                    child: const Text("Jetzt registrieren", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deine Gruppen'),
        actions: [
          IconButton(icon: const Icon(Icons.add), onPressed: () => _showCreateGroupDialog(socialRepo, user.id)),
          IconButton(icon: const Icon(Icons.link), onPressed: () => _showJoinGroupDialog(socialRepo, user.id)),
        ],
      ),
      body: user.groupIds.isEmpty
          ? const Center(child: Text("Du bist noch in keiner Gruppe."))
          : StreamBuilder<List<Map<String, dynamic>>>(
              stream: socialRepo.getGroups(user.groupIds),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final groups = snapshot.data!;

                return ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: groups.length,
                  separatorBuilder: (context, index) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final group = groups[index];
                    return Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).cardColor,
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.03),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          )
                        ],
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        leading: CircleAvatar(
                          radius: 28,
                          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
                          child: Text(
                            group['name'][0].toUpperCase(),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                        title: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              group['name'],
                              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                            ),
                            Text(
                              "12:45", // Beispielzeit
                              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 4.0),
                          child: Text(
                            "Klicke um zu chatten...",
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
                          ),
                        ),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ChatScreen(groupId: group['id'], groupName: group['name']),
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
    );
  }
}
