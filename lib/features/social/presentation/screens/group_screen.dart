import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fit_buddyy/features/auth/domain/models/user_model.dart';
import 'package:fit_buddyy/features/social/domain/repositories/social_repository.dart';
import 'package:fit_buddyy/features/auth/domain/repositories/auth_repository.dart';
import 'package:fit_buddyy/features/social/domain/models/raid_model.dart';
import 'package:fit_buddyy/features/home/presentation/screens/ai_buddy_chat_screen.dart';
import '../widgets/raid_card.dart';
import 'chat_screen.dart';
import 'package:fit_buddyy/features/auth/presentation/screens/link_account_screen.dart';

class GroupScreen extends StatefulWidget {
  const GroupScreen({super.key});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  final _nameController = TextEditingController();
  bool _raidsChecked = false;

  void _checkAndStartRaids(SocialRepository socialRepo, List<String> groupIds) {
    if (_raidsChecked) return;
    _raidsChecked = true;
    
    Future.microtask(() {
      for (String id in groupIds) {
        socialRepo.startWeeklyRaid(id);
      }
    });
  }

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
                if (context.mounted) {
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
                if (context.mounted) Navigator.pop(context);
              } catch (e) {
                if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fehler: $e")));
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
        appBar: AppBar(title: const Text('Chats')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.chat_bubble_outline, size: 80, color: Colors.grey),
                const SizedBox(height: 24),
                Text(
                  "Chatte mit deinem Buddy!",
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 12),
                const Text(
                  "Um mit der KI zu chatten oder Gruppen beizutreten, benötigst du ein Konto.",
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
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => const LinkAccountScreen()),
                      );
                    },
                    child: const Text("Jetzt registrieren", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (user.groupIds.isNotEmpty) {
      _checkAndStartRaids(socialRepo, user.groupIds);
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Deine Chats'),
        actions: [
          IconButton(
            icon: const Icon(Icons.group_add_outlined), 
            onPressed: () => _showCreateGroupDialog(socialRepo, user.id),
            tooltip: "Gruppe erstellen",
          ),
          IconButton(
            icon: const Icon(Icons.link), 
            onPressed: () => _showJoinGroupDialog(socialRepo, user.id),
            tooltip: "Gruppe beitreten",
          ),
        ],
      ),
      body: CustomScrollView(
        slivers: [
          // AI Buddy Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: _buildAiBuddyTile(context, user),
            ),
          ),
          
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Divider(),
            ),
          ),

          // Groups Section
          user.groupIds.isEmpty
              ? const SliverToBoxAdapter(
                  child: Center(
                    child: Padding(
                      padding: EdgeInsets.all(32.0),
                      child: Text("Noch keine Gruppen-Chats."),
                    ),
                  ),
                )
              : StreamBuilder<List<Map<String, dynamic>>>(
                  stream: socialRepo.getGroups(user.groupIds),
                  builder: (context, snapshot) {
                    if (!snapshot.hasData) return const SliverToBoxAdapter(child: Center(child: CircularProgressIndicator()));
                    final groups = snapshot.data!;

                    return SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final group = groups[index];
                            return Padding(
                              padding: const EdgeInsets.only(bottom: 12.0),
                              child: GroupItem(group: group, socialRepo: socialRepo),
                            );
                          },
                          childCount: groups.length,
                        ),
                      ),
                    );
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildAiBuddyTile(BuildContext context, UserModel user) {
    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Theme.of(context).colorScheme.primary.withValues(alpha: 0.1),
              Theme.of(context).colorScheme.secondary.withValues(alpha: 0.05),
            ],
          ),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.2),
            width: 1,
          ),
        ),
        child: Material(
          color: Colors.transparent,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: Stack(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const LinearGradient(
                      colors: [Colors.cyanAccent, Colors.purpleAccent],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.purpleAccent.withValues(alpha: 0.3),
                        blurRadius: 8,
                        spreadRadius: 2,
                      )
                    ],
                  ),
                  child: const Center(
                    child: Text("🤖", style: TextStyle(fontSize: 32)),
                  ),
                ),
                Positioned(
                  right: 0,
                  bottom: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: BoxDecoration(
                      color: Colors.greenAccent,
                      shape: BoxShape.circle,
                      border: Border.all(color: Theme.of(context).scaffoldBackgroundColor, width: 2),
                    ),
                  ),
                ),
              ],
            ),
            title: const Text(
              "Fit Buddyy Agent",
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: const Text(
              "Dein persönlicher KI-Coach",
              style: TextStyle(color: Colors.purpleAccent, fontWeight: FontWeight.w500),
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => const AiBuddyChatScreen(),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class GroupItem extends StatefulWidget {
  final Map<String, dynamic> group;
  final SocialRepository socialRepo;

  const GroupItem({super.key, required this.group, required this.socialRepo});

  @override
  State<GroupItem> createState() => _GroupItemState();
}

class _GroupItemState extends State<GroupItem> {
  late Stream<RaidModel?> _raidStream;

  @override
  void initState() {
    super.initState();
    _raidStream = widget.socialRepo.getActiveRaid(widget.group['id']);
  }

  @override
  void didUpdateWidget(GroupItem oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.group['id'] != widget.group['id']) {
      _raidStream = widget.socialRepo.getActiveRaid(widget.group['id']);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        StreamBuilder<RaidModel?>(
          stream: _raidStream,
          builder: (context, raidSnapshot) {
            if (raidSnapshot.connectionState == ConnectionState.waiting) {
              return const Padding(
                padding: EdgeInsets.symmetric(vertical: 8.0),
                child: Center(child: SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              );
            }
            if (raidSnapshot.hasData && raidSnapshot.data != null) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12.0),
                child: RaidCard(raid: raidSnapshot.data!),
              );
            }
            return const SizedBox.shrink();
          },
        ),
        Material(
          color: Theme.of(context).cardColor,
          borderRadius: BorderRadius.circular(20),
          clipBehavior: Clip.antiAlias,
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            leading: CircleAvatar(
              radius: 28,
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                widget.group['name'][0].toUpperCase(),
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            title: Text(
              widget.group['name'],
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            subtitle: const Text("Gruppen-Chat"),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () => Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(groupId: widget.group['id'], groupName: widget.group['name']),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
