import 'dart:async';
import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import 'package:shared_preferences/shared_preferences.dart';
import '../models/message.dart';
import '../models/user.dart';
import '../services/api_service.dart';
import '../utils/error_handler.dart';

class ChatProvider with ChangeNotifier {
  final ApiService _apiService = ApiService();
  List<Message> _messages = [];
  User? _partner;
  bool _isLoading = false;
  String? _error;
  bool _isTyping = false;
  bool _partnerOnline = false;
  DateTime? _partnerLastSeen;
  IO.Socket? _socket;
  StreamSubscription? _socketSubscription;

  List<Message> get messages => _messages;
  User? get partner => _partner;
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get isTyping => _isTyping;
  bool get partnerOnline => _partnerOnline;
  DateTime? get partnerLastSeen => _partnerLastSeen;

  Future<void> connect(String partnerId, User currentUser, User partner, BuildContext context) async {
    _isLoading = true;
    notifyListeners();

    try {
      _partner = partner;  // Use the passed partner instead of getProfile()
      _messages = await _apiService.getChatHistory(partnerId);

      final prefs = await SharedPreferences.getInstance();
      final token = prefs.getString('token');

      if (_socket == null && token != null) {
        _socket = IO.io(ApiService.baseUrl.replaceAll('/api', ''), <String, dynamic>{
          'transports': ['websocket'],
          'auth': {'token': token},
          // Always create a fresh connection; otherwise the cached socket is
          // reused and old listeners stay attached (duplicate messages).
          'forceNew': true,
          'autoConnect': false,
        });

        _socket!.connect();

        _socket!.onConnect((_) {
          _socket!.emit('joinChat', partnerId);
          print('Socket connected for chat with ${partner.username}');
          markAsRead(partnerId);  // Mark as read on connect
        });

        _socket!.on('newMessage', (data) {
          final msg = Message.fromJson(data as Map<String, dynamic>);
          if (msg.from.id != currentUser.id) {
            _messages.add(msg);
            notifyListeners();
          }
        });

        _socket!.on('userTyping', (data) {
          if (data['from'] == partnerId) {
            _isTyping = data['isTyping'] ?? false;
            notifyListeners();
          }
        });

        _socket!.on('userOnline', (data) {
          if (data['userId'] == partnerId) {
            _partnerOnline = true;
            _partnerLastSeen = data['lastSeen'] != null ? DateTime.tryParse(data['lastSeen'].toString()) : null;
            notifyListeners();
          }
        });

        _socket!.on('messagesRead', (data) {
          notifyListeners();
        });

        _socket!.on('error', (data) {
          _error = data['message'].toString();
          showErrorSnackBar(context, _error!);
          notifyListeners();
        });
      }

      _isLoading = false;
      notifyListeners();
    } catch (e) {
      _error = e.toString();
      if (context.mounted) {
        showErrorSnackBar(context, _error!);
      }
      _isLoading = false;
      notifyListeners();
    }
  }

  void sendMessage(String content, String partnerId, User currentUser) {
    if (_socket != null && content.trim().isNotEmpty) {
      _socket!.emit('sendMessage', {'to': partnerId, 'content': content});

      // Optimistic update
      final optimisticMsg = Message(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        from: currentUser,
        to: _partner ?? currentUser,
        content: content,
        createdAt: DateTime.now(),
      );
      _messages.add(optimisticMsg);
      notifyListeners();
    }
  }

  void setTyping(bool typing, String partnerId) {
    if (_socket != null) {
      _socket!.emit('typing', {'to': partnerId, 'isTyping': typing});
    }
  }

  Future<void> markAsRead(String partnerId) async {
    try {
      await _apiService.markMessagesAsRead(partnerId);
      if (_socket != null) {
        _socket!.emit('markRead', {'from': partnerId});
      }
      // Update local read status
      for (var msg in _messages) {
        if (!msg.readBy.contains(partnerId)) {
          // simulate
        }
      }
      notifyListeners();
    } catch (e) {
      print('Mark read error: $e');
    }
  }

  void disconnect() {
    _socket?.clearListeners();
    _socket?.disconnect();
    _socket?.dispose();
    _socket = null;
    _messages.clear();
    notifyListeners();
  }

  void clearError() {
    _error = null;
    notifyListeners();
  }

  @override
  void dispose() {
    disconnect();
    super.dispose();
  }
}
