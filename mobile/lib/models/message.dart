import 'user.dart';

class Message {
  final String id;
  final User from;
  final User to;
  final String content;
  final List<String> readBy;
  final bool isEdited;
  final bool isDeleted;
  final bool reported;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Message({
    required this.id,
    required this.from,
    required this.to,
    required this.content,
    this.readBy = const [],
    this.isEdited = false,
    this.isDeleted = false,
    this.reported = false,
    required this.createdAt,
    this.updatedAt,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    return Message(
      id: json['_id'] ?? json['id'] ?? '',
      from: User.fromJson(
        json['from'] is Map
            ? json['from']
            : {'_id': json['from'], 'username': 'User'},
      ),
      to: User.fromJson(
        json['to'] is Map
            ? json['to']
            : {'_id': json['to'], 'username': 'User'},
      ),
      content: json['content'] ?? '',
      readBy:
          (json['readBy'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      isEdited: json['isEdited'] ?? false,
      isDeleted: json['isDeleted'] ?? false,
      reported: json['reported'] ?? false,
      createdAt: json['createdAt'] != null
          ? DateTime.parse(json['createdAt'])
          : DateTime.now(),
      updatedAt: json['updatedAt'] != null
          ? DateTime.parse(json['updatedAt'].toString())
          : null,
    );
  }

  bool get isRead => readBy.isNotEmpty;
}
