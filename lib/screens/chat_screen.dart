import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../widgets/common_widgets.dart';

class ChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const ChatScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final _messageController = TextEditingController();
  String _leaderboardMode = 'Tag'; // 'Tag' oder 'Woche'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this); // Jetzt 3 Tabs
  }

  void _sendMessage() async {
    final user = Provider.of<UserModel?>(context, listen: false);
    final db = context.read<FirebaseService>();
    final text = _messageController.text.trim();
    if (user != null && text.isNotEmpty) {
      _messageController.clear();
      try {
        await db.sendMessage(widget.groupId, user.id, user.displayName, text);
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Fehler: $e")));
      }
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _messageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.groupName),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Theme.of(context).colorScheme.primary,
          tabs: const [
            Tab(icon: Icon(Icons.chat), text: "Chat"),
            Tab(icon: Icon(Icons.leaderboard), text: "Rangliste"),
            Tab(icon: Icon(Icons.psychology), text: "KI Coach"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatTab(),
          _buildLeaderboardTab(),
          _buildCoachTab(),
        ],
      ),
    );
  }

  Widget _buildChatTab() {
    final user = Provider.of<UserModel?>(context);
    final db = context.read<FirebaseService>();
    if (user == null) return const LoadingSpinner();

    return Column(
      children: [
        Expanded(
          child: StreamBuilder<QuerySnapshot>(
            stream: FirebaseFirestore.instance.collection('groups').doc(widget.groupId).collection('messages').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) return Center(child: Text("Fehler: ${snapshot.error}"));
              if (snapshot.connectionState == ConnectionState.waiting) return const LoadingSpinner();
              
              final docs = snapshot.data?.docs ?? [];
              final sortedDocs = docs.toList()..sort((a, b) {
                Timestamp t1 = a['timestamp'] ?? Timestamp.now();
                Timestamp t2 = b['timestamp'] ?? Timestamp.now();
                return t2.compareTo(t1);
              });

              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(12),
                itemCount: sortedDocs.length,
                itemBuilder: (context, index) {
                  final msg = sortedDocs[index].data() as Map<String, dynamic>;
                  final isMe = msg['senderId'] == user.id;
                  return _buildMessageBubble(msg, isMe);
                },
              );
            },
          ),
        ),
        _buildMessageInput(),
      ],
    );
  }

  Widget _buildMessageBubble(Map<String, dynamic> msg, bool isMe) {
    final theme = Theme.of(context);
    final isSystem = msg['senderName'] == 'System';

    if (isSystem) {
      return Center(
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 8),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          decoration: BoxDecoration(color: Colors.grey.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
          child: Text(msg['text'] ?? '', style: const TextStyle(fontSize: 11, color: Colors.grey, fontStyle: FontStyle.italic)),
        ),
      );
    }

    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4),
        padding: const EdgeInsets.all(12),
        constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: isMe ? theme.colorScheme.primary : Colors.grey[300],
          borderRadius: BorderRadius.circular(16).copyWith(
            bottomRight: isMe ? const Radius.circular(0) : const Radius.circular(16),
            bottomLeft: isMe ? const Radius.circular(16) : const Radius.circular(0),
          ),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            if (!isMe) Text(msg['senderName'] ?? 'Buddy', style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.black54)),
            Text(msg['text'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Container(
      padding: const EdgeInsets.all(8),
      color: Theme.of(context).scaffoldBackgroundColor,
      child: Row(
        children: [
          Expanded(
            child: TextField(
              controller: _messageController,
              decoration: InputDecoration(
                hintText: "Schreib eine Nachricht...",
                filled: true,
                fillColor: Colors.grey.withOpacity(0.1),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none),
                contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              ),
              onSubmitted: (_) => _sendMessage(),
            ),
          ),
          const SizedBox(width: 8),
          IconButton(onPressed: _sendMessage, icon: const Icon(Icons.send), color: Theme.of(context).colorScheme.primary),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    final db = context.read<FirebaseService>();
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12.0),
          child: SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'Tag', label: Text('Heute'), icon: Icon(Icons.today)),
              ButtonSegment(value: 'Woche', label: Text('Woche'), icon: Icon(Icons.view_week)),
            ],
            selected: {_leaderboardMode},
            onSelectionChanged: (newSelection) {
              setState(() => _leaderboardMode = newSelection.first);
            },
          ),
        ),
        Expanded(
          child: StreamBuilder<List<UserModel>>(
            stream: db.getGroupMembers(widget.groupId),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) return const LoadingSpinner();
              
              final members = snapshot.data ?? [];
              if (_leaderboardMode == 'Tag') {
                members.sort((a, b) => b.dailySteps.compareTo(a.dailySteps));
              } else {
                members.sort((a, b) => (b.weeklySteps).compareTo(a.weeklySteps));
              }

              return ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: members.length,
                itemBuilder: (context, index) {
                  final member = members[index];
                  int steps = _leaderboardMode == 'Tag' ? member.dailySteps : (member.weeklySteps);
                  
                  return Card(
                    margin: const EdgeInsets.only(bottom: 10),
                    child: ListTile(
                      leading: CircleAvatar(backgroundColor: _getRankColor(index), child: Text("${index + 1}", style: const TextStyle(color: Colors.white))),
                      title: Text(member.displayName, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Level ${member.level}"),
                      trailing: Text("$steps Schritte", style: TextStyle(color: Theme.of(context).colorScheme.primary, fontWeight: FontWeight.bold)),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildCoachTab() {
    final user = Provider.of<UserModel?>(context);
    if (user == null) return const LoadingSpinner();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          const Icon(Icons.psychology, size: 80, color: Color(0xFF00BFA5)),
          const SizedBox(height: 10),
          const Text("KI Coach", style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildCoachCard(
            "Wochen-Check", 
            "Du hast diese Woche bereits ${user.workoutsThisWeek} Workouts geschafft. Dein Ziel sind ${user.workoutGoalWeekly}. Bleib dran!",
            Icons.insights
          ),
          const SizedBox(height: 15),
          _buildCoachCard(
            "Motivation", 
            "Wusstest du? Menschen, die in Gruppen trainieren, bleiben zu 80% länger motiviert. Deine Buddies zählen auf dich!",
            Icons.bolt
          ),
          const SizedBox(height: 15),
          _buildCoachCard(
            "Monats-Ausblick", 
            "Noch 5 Tage bis zum Monatsende. Wenn du dein Level hältst, bekommst du einen Bonus-Freezer!",
            Icons.calendar_month
          ),
        ],
      ),
    );
  }

  Widget _buildCoachCard(String title, String text, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Theme.of(context).colorScheme.primary.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: Theme.of(context).colorScheme.primary),
              const SizedBox(width: 10),
              Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 10),
          Text(text, style: const TextStyle(height: 1.5)),
        ],
      ),
    );
  }

  Color _getRankColor(int index) {
    if (index == 0) return Colors.amber;
    if (index == 1) return Colors.blueGrey;
    if (index == 2) return Colors.brown;
    return Colors.grey;
  }
}
