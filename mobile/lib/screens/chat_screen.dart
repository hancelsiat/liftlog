import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../utils/app_theme.dart';
import '../utils/ph_time.dart';

class ChatScreen extends StatefulWidget {
  final User partner;

  const ChatScreen({super.key, required this.partner});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  late final ChatProvider _chatProvider;
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (_authProvider.user != null) {
      _chatProvider.connect(widget.partner.id, _authProvider.user!, widget.partner, context);
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
  }

  void _scrollToBottom() {
    if (_scrollController.hasClients) {
      _scrollController.jumpTo(_scrollController.position.maxScrollExtent);
    }
  }

  void _sendMessage() {
    final text = _messageController.text.trim();
    if (text.isNotEmpty && _authProvider.user != null) {
      _chatProvider.sendMessage(text, widget.partner.id, _authProvider.user!);
      _messageController.clear();
      _scrollToBottom();
    }
  }

  @override
  void dispose() {
    _messageController.dispose();
    _scrollController.dispose();
    _chatProvider.disconnect();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final chatProvider = Provider.of<ChatProvider>(context);
    final authProvider = Provider.of<AuthProvider>(context);
    final currentUser = authProvider.user;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.partner.username),
            if (chatProvider.partnerOnline) const Text('online', style: TextStyle(fontSize: 12, color: Colors.green)),
          ],
        ),
        backgroundColor: AppTheme.darkBackground,
        foregroundColor: Colors.white,
      ),
      backgroundColor: AppTheme.darkBackground,
      body: Column(
        children: [
          Expanded(
            child: chatProvider.isLoading 
              ? const Center(child: CircularProgressIndicator(color: Colors.white))
              : ListView.builder(
                  controller: _scrollController,
                  padding: const EdgeInsets.all(16),
                  itemCount: chatProvider.messages.length,
                  itemBuilder: (context, index) {
                    final msg = chatProvider.messages[index];
                    final isMe = msg.from.id == currentUser?.id;
                    return Align(
                      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isMe ? AppTheme.primaryColor : AppTheme.cardBackground,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              msg.content,
                              style: TextStyle(
                                color: isMe ? Colors.white : AppTheme.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              PhTime.formatChatTime(msg.createdAt),
                              style: const TextStyle(fontSize: 10, color: Colors.white54),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
          ),
          if (chatProvider.isTyping)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text('Partner is typing...', style: TextStyle(color: Colors.white70, fontStyle: FontStyle.italic)),
            ),
          Container(
            padding: const EdgeInsets.all(8),
            color: AppTheme.cardBackground,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageController,
                    style: const TextStyle(color: Colors.white),
                    decoration: const InputDecoration(
                      hintText: 'Type message...',
                      hintStyle: TextStyle(color: Colors.white54),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.all(Radius.circular(25)),
                      ),
                      filled: true,
                      fillColor: Color(0xFF2A2A2A),
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.blue),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
