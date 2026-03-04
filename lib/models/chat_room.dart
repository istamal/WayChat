import 'user_profile.dart';
import 'message.dart';

class ChatRoom {
  final String id;
  final String? name;
  final bool isPrivate;
  final DateTime createdAt;
  final String? createdBy;
  final List<UserProfile> participants; // участники, включая текущего
  final Message? lastMessage; // последнее сообщение

  ChatRoom({
    required this.id,
    this.name,
    required this.isPrivate,
    required this.createdAt,
    this.createdBy,
    required this.participants,
    this.lastMessage,
  });

  // Определяем, является ли комната личной (диалог)
  bool get isDirect => isPrivate && participants.length == 2;

  // Получить собеседника для личной комнаты (текущий пользователь исключается)
  UserProfile? getOtherParticipant(String currentUserId) {
    if (!isDirect) return null;
    return participants.firstWhere((p) => p.id != currentUserId);
  }

  factory ChatRoom.fromJson(Map<String, dynamic> json) {
    return ChatRoom(
      id: json['id'],
      name: json['name'],
      isPrivate: json['is_private'] ?? false,
      createdAt: DateTime.parse(json['created_at']),
      createdBy: json['created_by'],
      participants: [], // будут заполнены отдельно
      lastMessage: json['last_message'] != null
          ? Message.fromJson(json['last_message'])
          : null,
    );
  }
}
