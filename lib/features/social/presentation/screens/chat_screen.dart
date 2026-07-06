import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:fit_buddyy/features/auth/domain/models/user_model.dart';
import 'package:fit_buddyy/features/social/domain/repositories/social_repository.dart';
import 'package:fit_buddyy/features/social/presentation/screens/group_details_screen.dart';

class ChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;

  const ChatScreen({super.key, required this.groupId, required this.groupName});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _controller = TextEditingController();

  void _sendMessage() async {
    final user = context.read<UserModel?>();
    final socialRepo = context.read<SocialRepository>();
    if (user != null && _controller.text.isNotEmpty) {
      await socialRepo.sendMessage(widget.groupId, user.id, user.displayName, _controller.text);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<UserModel?>();
    final socialRepo = context.read<SocialRepository>();

    return Scaffold(
      appBar: AppBar(
        title: GestureDetector(
          onTap: () async {
            final group = await socialRepo.getGroupById(widget.groupId);
            if (group != null && context.mounted) {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => GroupDetailsScreen(group: group)),
              );
            }
          },
          child: Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.white24,
                child: Text(widget.groupName[0].toUpperCase(),
                    style: const TextStyle(fontSize: 14, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(widget.groupName, style: const TextStyle(fontSize: 16)),
                    const Text("Tippe für Info",
                        style: TextStyle(fontSize: 11, color: Colors.white70)),
                  ],
                ),
              ),
            ],
          ),
        ),
        backgroundColor: Theme.of(context).colorScheme.primary,
        foregroundColor: Colors.white,
        actions: [
          IconButton(icon: const Icon(Icons.more_vert), onPressed: () {}),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).brightness == Brightness.light
              ? const Color(0xFFE5DDD5)
              : const Color(0xFF0B141A),
        ),
        child: Column(
          children: [
            Expanded(
              child: StreamBuilder<QuerySnapshot>(
                stream: socialRepo.getMessages(widget.groupId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  final docs = snapshot.data!.docs;

                  return ListView.builder(
                    reverse: true,
                    itemCount: docs.length,
                    itemBuilder: (context, index) {
                      final msg = docs[index].data() as Map<String, dynamic>;
                      final isMe = msg['senderId'] == user?.id;
                      final isSystem = msg['senderName'] == 'System';
                      final date = (msg['timestamp'] as Timestamp?)?.toDate() ?? DateTime.now();

                      if (isSystem) {
                        return Center(
                          child: Container(
                            margin: const EdgeInsets.symmetric(vertical: 8),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                            decoration: BoxDecoration(
                              color: Theme.of(context).brightness == Brightness.light
                                  ? Colors.grey[200]
                                  : Colors.white.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              msg['text'],
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 12,
                                fontStyle: FontStyle.italic,
                                color: Theme.of(context).brightness == Brightness.light
                                    ? Colors.black54
                                    : Colors.white70,
                              ),
                            ),
                          ),
                        );
                      }

                      return Align(
                        alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                        child: Container(
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isMe
                                ? Theme.of(context).colorScheme.primary
                                : (Theme.of(context).brightness == Brightness.light
                                    ? Colors.grey[300]
                                    : Colors.grey[800]),
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (!isMe)
                                Text(
                                  msg['senderName'],
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 10,
                                    color: Theme.of(context).brightness == Brightness.light
                                        ? Colors.black87
                                        : Colors.white70,
                                  ),
                                ),
                              Text(
                                msg['text'],
                                style: TextStyle(
                                    color: isMe
                                        ? Colors.white
                                        : (Theme.of(context).brightness == Brightness.light
                                            ? Colors.black
                                            : Colors.white)),
                              ),
                              Text(
                                DateFormat('HH:mm').format(date),
                                style: TextStyle(
                                  fontSize: 8,
                                  color: isMe
                                      ? Colors.white70
                                      : (Theme.of(context).brightness == Brightness.light
                                          ? Colors.black54
                                          : Colors.white60),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
            Container(
              padding: EdgeInsets.only(
                left: 8,
                right: 8,
                top: 8,
                bottom: MediaQuery.of(context).padding.bottom + 8,
              ),
              color: Theme.of(context).brightness == Brightness.light
                  ? Colors.white
                  : Colors.grey[900],
              child: Row(
                children: [
                  Expanded(
                      child: TextField(
                          controller: _controller,
                          decoration: const InputDecoration(
                            hintText: "Nachricht...",
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.symmetric(horizontal: 12),
                          ))),
                  IconButton(
                      icon: Icon(Icons.send, color: Theme.of(context).colorScheme.primary),
                      onPressed: _sendMessage),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
