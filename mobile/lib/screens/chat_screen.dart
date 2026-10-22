import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/chat_provider.dart';
import '../providers/auth_provider.dart';
import '../models/user.dart';
import '../utils/ph_time.dart';
import '../widgets/gym/gym.dart';

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

  /// Messages already on screen when the history loaded. Only messages
  /// added after that get the send/receive animation.
  int? _initialCount;

  @override
  void initState() {
    super.initState();
    _authProvider = Provider.of<AuthProvider>(context, listen: false);
    _chatProvider = Provider.of<ChatProvider>(context, listen: false);
    if (_authProvider.user != null) {
      _chatProvider.connect(
        widget.partner.id,
        _authProvider.user!,
        widget.partner,
        context,
      );
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
      // The new bubble is laid out next frame; follow it down.
      WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToBottom());
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

    if (chatProvider.isLoading) {
      _initialCount = null;
    } else {
      _initialCount ??= chatProvider.messages.length;
    }

    return GymScaffold(
      eyebrow: chatProvider.partnerOnline ? '● Online' : 'Chat',
      title: widget.partner.username,
      body: Column(
        children: [
          const Divider(),
          Expanded(
            child: chatProvider.isLoading
                ? const GymLoader()
                : ListView.builder(
                    controller: _scrollController,
                    keyboardDismissBehavior:
                        ScrollViewKeyboardDismissBehavior.onDrag,
                    padding: const EdgeInsets.fromLTRB(
                      GymScaffold.side,
                      AuthSpace.s,
                      GymScaffold.side,
                      AuthSpace.s,
                    ),
                    itemCount: chatProvider.messages.length,
                    itemBuilder: (context, index) {
                      final msg = chatProvider.messages[index];
                      final isMe = msg.from.id == currentUser?.id;
                      final isNew = index >= (_initialCount ?? 0);
                      return _Bubble(
                        key: ValueKey(msg.id),
                        text: msg.content,
                        time: PhTime.formatChatTime(msg.createdAt),
                        isMe: isMe,
                        animate: isNew,
                      );
                    },
                  ),
          ),
          AnimatedSize(
            duration: AuthMotion.reduced(context)
                ? Duration.zero
                : AuthMotion.base,
            curve: AuthMotion.enter,
            child: chatProvider.isTyping
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      GymScaffold.side,
                      0,
                      GymScaffold.side,
                      8,
                    ),
                    child: Row(
                      children: [
                        const BarLoader(color: AuthColors.textMuted),
                        const SizedBox(width: 10),
                        Text(
                          'Partner is typing...',
                          style: AuthType.body(size: 13),
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          _Composer(controller: _messageController, onSend: _sendMessage),
        ],
      ),
    );
  }
}

/// One message. New messages (sent or received after the history loaded)
/// scale up from their own corner and fade in; history renders still.
class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.text,
    required this.time,
    required this.isMe,
    required this.animate,
  });

  final String text;
  final String time;
  final bool isMe;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    const r = Radius.circular(AuthRadius.dialog);
    const tail = Radius.circular(4);
    final bubble = Container(
      constraints: BoxConstraints(
        maxWidth: MediaQuery.sizeOf(context).width * 0.78,
      ),
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: isMe ? AuthColors.accent : AuthColors.surface,
        border: isMe ? null : Border.all(color: AuthColors.line),
        borderRadius: BorderRadius.only(
          topLeft: r,
          topRight: r,
          bottomLeft: isMe ? r : tail,
          bottomRight: isMe ? tail : r,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            text,
            style: AuthType.body(
              color: isMe ? AuthColors.onAccent : AuthColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            time.toUpperCase(),
            style: AuthType.mono(
              color: isMe
                  ? AuthColors.onAccent.withValues(alpha: 0.6)
                  : AuthColors.textFaint,
            ).copyWith(fontSize: 10),
          ),
        ],
      ),
    );

    final aligned = Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: bubble,
    );

    if (!animate || AuthMotion.reduced(context)) return aligned;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AuthMotion.base,
      curve: AuthMotion.enter,
      child: aligned,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(
          scale: 0.92 + 0.08 * t,
          alignment: isMe ? Alignment.bottomRight : Alignment.bottomLeft,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - t)),
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Input row pinned above the keyboard. The send button is disabled while
/// the field is empty and springs on tap.
class _Composer extends StatefulWidget {
  const _Composer({required this.controller, required this.onSend});

  final TextEditingController controller;
  final VoidCallback onSend;

  @override
  State<_Composer> createState() => _ComposerState();
}

class _ComposerState extends State<_Composer> {
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_rebuild);
  }

  void _rebuild() => setState(() {});

  @override
  void dispose() {
    _focus
      ..removeListener(_rebuild)
      ..dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return Container(
      padding: const EdgeInsets.fromLTRB(
        GymScaffold.side,
        10,
        GymScaffold.side,
        12,
      ),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AuthColors.line)),
      ),
      child: Row(
        children: [
          Expanded(
            child: AnimatedContainer(
              duration: AuthMotion.reduced(context)
                  ? Duration.zero
                  : AuthMotion.fast,
              constraints: const BoxConstraints(minHeight: 44),
              decoration: BoxDecoration(
                color: focused ? AuthColors.surfaceHi : AuthColors.surface,
                borderRadius: BorderRadius.circular(AuthRadius.field),
                border: Border.all(
                  color: focused ? AuthColors.accent : AuthColors.line,
                ),
              ),
              child: TextField(
                controller: widget.controller,
                focusNode: _focus,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                style: AuthType.input(),
                cursorColor: AuthColors.accent,
                decoration: InputDecoration(
                  hintText: 'Type message...',
                  hintStyle: AuthType.input(color: AuthColors.textFaint),
                  filled: false,
                  isDense: true,
                  border: InputBorder.none,
                  enabledBorder: InputBorder.none,
                  focusedBorder: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 12,
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: widget.controller,
            builder: (context, value, _) => GymIconButton(
              icon: Icons.arrow_upward,
              tooltip: 'Send',
              filled: true,
              onTap: value.text.trim().isEmpty ? null : widget.onSend,
            ),
          ),
        ],
      ),
    );
  }
}
