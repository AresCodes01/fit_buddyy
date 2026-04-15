import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/user_model.dart';
import '../services/firebase_service.dart';
import 'package:intl/intl.dart';

class ChatScreen extends StatefulWidget {
  final String groupId;
  final String groupName;
  final UserModel user;

  const ChatScreen({super.key, required this.groupId, required this.groupName, required this.user});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final FirebaseService _db = FirebaseService();
  final _messageController = TextEditingController();

  void _sendMessage() async {
    if (_messageController.text.isNotEmpty) {
      await _db.sendMessage(widget.groupId, widget.user.id, widget.user.displayName, _messageController.text);
      _messageController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.groupName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _db.getMessages(widget.groupId),
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                final messages = snapshot.data!.docs;
                return ListView.builder(
                  reverse: true,
                  itemCount: messages.length,
                  itemBuilder: (context, index) {
                    final msg = messages[index].data() as Map<String, dynamic>;
                    final isMe = msg['senderId'] == widget.user.id;
                    return ListTile(
                      title: Text(msg['senderName'] ?? 'Unbekannt', style: TextStyle(fontWeight: FontWeight.bold, color: isMe ? Colors.blue : Colors.grey)),
                      subtitle: Text(msg['text'] ?? ''),
                      trailing: Text(msg['timestamp'] != null 
                          ? DateFormat('HH:mm').format((msg['timestamp'] as Timestamp).toDate()) 
                          : ''),
                    );
                  },
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _messageController, decoration: const InputDecoration(hintText: 'Nachricht senden...'))),
                IconButton(icon: const Icon(Icons.send), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
