import 'user_profile.dart';

class Message {
  final String id;
  final String roomId;
  final String userId;
  final String content;
  final DateTime createdAt;
  final DateTime? readAt;
  final UserProfile? user; // опционально, для отображения автора
  final String? imageUrl;
  final String? voiceUrl;

  Message({
    required this.id,
    required this.roomId,
    required this.userId,
    required this.content,
    required this.createdAt,
    this.readAt,
    this.user,
    this.imageUrl,
    this.voiceUrl,
  });

  factory Message.fromJson(Map<String, dynamic> json) {
    // Supabase sometimes returns literal string "null" when a column is
    // actually NULL, or the column may contain an empty string.  both of
    // these are not valid URLs and were causing the audio player to attempt
    // to play "null" which resulted in a DarwinAudioError.  Normalize those
    // values to Dart `null` so our UI logic can ignore them.
    String? normalizeUrl(dynamic value) {
      if (value == null) return null;
      final s = value.toString().trim();
      if (s.isEmpty) return null;
      if (s.toLowerCase() == 'null') return null;
      return s;
    }

    return Message(
      id: json['id'],
      roomId: json['room_id'],
      userId: json['user_id'],
      content: json['content'],
      createdAt: DateTime.parse(json['created_at']),
      readAt: json['read_at'] != null
          ? DateTime.tryParse(json['read_at'].toString())
          : null,
      user: json['user'] != null ? UserProfile.fromJson(json['user']) : null,
      imageUrl: normalizeUrl(json['image_url']),
      voiceUrl: normalizeUrl(json['voice_url']),
    );
  }
}
