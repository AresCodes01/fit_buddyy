import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:provider/provider.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import '../widgets/common_widgets.dart';
import 'package:intl/intl.dart';

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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  void _sendMessage() async {
    final user = Provider.of<UserModel?>(context, listen: false);
    final db = context.read<FirebaseService>();
    if (user != null && _messageController.text.trim().isNotEmpty) {
      final text = _messageController.text.trim();
      _messageController.clear();
      await db.sendMessage(widget.groupId, user.id, user.displayName, text);
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
          tabs: const [
            Tab(icon: Icon(Icons.chat), text: "Chat"),
            Tab(icon: Icon(Icons.leaderboard), text: "Leaderboard"),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildChatTab(),
          _buildLeaderboardTab(),
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
            stream: db.getMessages(widget.groupId),
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const LoadingSpinner();
              final messages = snapshot.data!.docs;
              return ListView.builder(
                reverse: true,
                itemCount: messages.length,
                itemBuilder: (context, index) {
                  final msg = messages[index].data() as Map<String, dynamic>;
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
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? Colors.blueAccent : Colors.grey[200],
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
          children: [
            Text(isMe ? 'Du' : (msg['senderName'] ?? 'Buddy'), 
                 style: TextStyle(fontWeight: FontWeight.bold, fontSize: 10, color: isMe ? Colors.white70 : Colors.black54)),
            Text(msg['text'] ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageInput() {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Row(
        children: [
          Expanded(child: TextField(controller: _messageController, decoration: const InputDecoration(hintText: 'Nachricht...'))),
          IconButton(icon: const Icon(Icons.send, color: Colors.blueAccent), onPressed: _sendMessage),
        ],
      ),
    );
  }

  Widget _buildLeaderboardTab() {
    final db = context.read<FirebaseService>();
    return StreamBuilder<List<UserModel>>(
      stream: db.getGroupMembers(widget.groupId),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const LoadingSpinner();
        final members = snapshot.data!;
        // Sortieren nach Schritten (Absteigend)
        members.sort((a, b) => b.dailySteps.compareTo(a.dailySteps));

        return ListView.builder(
          itemCount: members.length,
          itemBuilder: (context, index) {
            final member = members[index];
            return ListTile(
              leading: CircleAvatar(
                backgroundColor: _getRankColor(index),
                child: Text('${index + 1}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
              ),
              title: Text(member.displayName),
              subtitle: Text('Level ${member.level}'),
              trailing: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${member.dailySteps}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const Text('Schritte', style: TextStyle(fontSize: 10, color: Colors.grey)),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Color _getRankColor(int index) {
    if (index == 0) return Colors.amber; // Gold
    if (index == 1) return Colors.grey;  // Silber
    if (index == 2) return Colors.brown; // Bronze
    return Colors.blueAccent.withOpacity(0.5);
  }
}
