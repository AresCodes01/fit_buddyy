import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:fit_buddyy/features/auth/domain/models/user_model.dart';
import 'package:fit_buddyy/features/social/domain/repositories/social_repository.dart';
import 'package:fit_buddyy/features/social/domain/models/raid_model.dart';
import '../widgets/dungeon_widget.dart';
import 'user_comparison_screen.dart';

class GroupDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> group;

  const GroupDetailsScreen({super.key, required this.group});

  @override
  State<GroupDetailsScreen> createState() => _GroupDetailsScreenState();
}

class _GroupDetailsScreenState extends State<GroupDetailsScreen> {
  @override
  Widget build(BuildContext context) {
    final group = widget.group;
    final socialRepo = context.read<SocialRepository>();
    final currentUser = context.watch<UserModel?>();

    return Scaffold(
      appBar: AppBar(title: const Text('Gruppeninfo')),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 20),
            CircleAvatar(
              radius: 50,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                group['name'][0].toUpperCase(),
                style: TextStyle(fontSize: 40, color: Theme.of(context).colorScheme.primary),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              group['name'],
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              "Gruppen-ID: ${group['id']}",
              style: TextStyle(color: Colors.grey[600]),
            ),
            const SizedBox(height: 24),
            ListTile(
              leading: const Icon(Icons.person_add_outlined),
              title: const Text("Mitglieder einladen"),
              subtitle: const Text("Teile die Gruppen-ID mit anderen"),
              trailing: const Icon(Icons.copy),
              onTap: () {
                Clipboard.setData(ClipboardData(text: group['id']));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text("ID in Zwischenablage kopiert!")),
                );
              },
            ),
            const Divider(),

            // Dungeon / Boss Kampf Bereich
            StreamBuilder<RaidModel?>(
              stream: socialRepo.getActiveRaid(group['id']),
              builder: (context, snapshot) {
                if (snapshot.hasData && snapshot.data != null) {
                  return DungeonWidget(raid: snapshot.data!);
                }
                return const SizedBox.shrink();
              },
            ),
            
            // Rangliste Bereich
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    "Rangliste (Schritte heute)",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 16),
                  StreamBuilder<List<UserModel>>(
                    stream: socialRepo.getGroupMembers(group['id']),
                    builder: (context, snapshot) {
                      if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                      
                      final members = snapshot.data!;
                      members.sort((a, b) => b.dailySteps.compareTo(a.dailySteps));

                      return ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: members.length,
                        itemBuilder: (context, index) {
                          final member = members[index];
                          final isMe = member.id == currentUser?.id;
                          
                          return Card(
                            elevation: isMe ? 2 : 0,
                            color: isMe ? Theme.of(context).colorScheme.primaryContainer.withValues(alpha: 0.3) : Colors.transparent,
                            child: ListTile(
                              leading: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text("${index + 1}.", style: const TextStyle(fontWeight: FontWeight.bold)),
                                  const SizedBox(width: 8),
                                  CircleAvatar(
                                    backgroundImage: member.photoUrl.isNotEmpty 
                                      ? NetworkImage(member.photoUrl) : null,
                                    child: member.photoUrl.isEmpty ? const Icon(Icons.person) : null,
                                  ),
                                ],
                              ),
                              title: Text(member.displayName, style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
                              subtitle: Text("${member.dailySteps} Schritte"),
                              trailing: const Icon(Icons.compare_arrows, size: 20, color: Colors.grey),
                              onTap: () {
                                if (currentUser != null && !isMe) {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (context) => UserComparisonScreen(
                                        currentUser: currentUser,
                                        targetUser: member,
                                      ),
                                    ),
                                  );
                                }
                              },
                            ),
                          );
                        },
                      );
                    },
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
