import 'dart:typed_data';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/chat_room.dart';
import '../models/message.dart';
import '../models/user_profile.dart';

class ChatService {
  final SupabaseClient _client = Supabase.instance.client;

  // Получить список комнат текущего пользователя с участниками и последним сообщением
  Future<List<ChatRoom>> getMyRooms() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    // 1. Получить все room_id, где пользователь участник
    final participantRows = await _client
        .from('chat_room_participants')
        .select('room_id')
        .eq('user_id', userId);

    if (participantRows.isEmpty) return [];

    final roomIds = participantRows
        .map((row) => row['room_id'] as String)
        .toList();

    // 2. Получить комнаты с последним сообщением (подзапрос)
    final roomsData = await _client
        .from('chat_rooms')
        .select('''
          *,
          last_message:messages(
            *,
            user:user_id(*)
          )
        ''')
        .inFilter('id', roomIds)
        .order(
          'last_message_time',
          ascending: false,
        ); // сортируем по времени последнего сообщения

    if (roomsData.isEmpty) return [];

    // 3. Для каждой комнаты получить участников
    List<ChatRoom> rooms = [];
    for (var roomJson in roomsData) {
      // Получаем участников этой комнаты
      final participantsData = await _client
          .from('chat_room_participants')
          .select('user_id, profiles!inner(*)')
          .eq('room_id', roomJson['id']);

      List<UserProfile> participants = [];
      for (var p in participantsData) {
        participants.add(UserProfile.fromJson(p['profiles']));
      }

      // Последнее сообщение
      Message? lastMessage;
      if (roomJson['last_message'] != null &&
          roomJson['last_message'].isNotEmpty) {
        // last_message — это массив, берём первый (самый последний)
        lastMessage = Message.fromJson(roomJson['last_message'][0]);
      }

      rooms.add(
        ChatRoom(
          id: roomJson['id'],
          name: roomJson['name'],
          isPrivate: roomJson['is_private'] ?? false,
          createdAt: DateTime.parse(roomJson['created_at']),
          createdBy: roomJson['created_by'],
          participants: participants,
          lastMessage: lastMessage,
        ),
      );
    }

    // Сортировка: по времени последнего сообщения (уже сделано в запросе)
    return rooms;
  }

  // Создать личную комнату (если уже существует, вернуть её)
  Future<String> createOrGetDirectRoom(String otherUserId) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');

    // Проверяем, существует ли уже личная комната между этими двумя
    // Для этого нужно найти комнату, где is_private = true и участники ровно эти двое.
    // Можно через подзапрос: ищем комнаты, в которых участвуют оба, и где всего 2 участника.
    // Упростим: создадим функцию на стороне БД или запрос с having.
    // Пока реализуем через поиск: найдём все комнаты, где участвует текущий пользователь,
    // проверим их участников.

    final rooms = await _client
        .from('chat_room_participants')
        .select('room_id, chat_rooms!inner(is_private)')
        .eq('user_id', currentUserId)
        .eq('chat_rooms.is_private', true);

    Set<String> candidateRoomIds = {};
    for (var row in rooms) {
      candidateRoomIds.add(row['room_id'] as String);
    }

    if (candidateRoomIds.isNotEmpty) {
      // Для каждой комнаты проверим участников
      for (var roomId in candidateRoomIds) {
        final participants = await _client
            .from('chat_room_participants')
            .select('user_id')
            .eq('room_id', roomId);

        if (participants.length == 2) {
          final userIds = participants
              .map((p) => p['user_id'] as String)
              .toSet();
          if (userIds.contains(currentUserId) &&
              userIds.contains(otherUserId)) {
            return roomId; // нашли существующую
          }
        }
      }
    }

    print('Current user ID: $currentUserId');
    print(
      'Inserting room with data: ${{'is_private': true, 'created_by': currentUserId}}',
    );

    // Если не нашли, создаём новую комнату
    final newRoom = await _client
        .from('chat_rooms')
        .insert({'is_private': true, 'created_by': currentUserId})
        .select('id')
        .single();

    final roomId = newRoom['id'] as String;

    // Добавляем участников
    await _client.from('chat_room_participants').insert([
      {'room_id': roomId, 'user_id': currentUserId},
      {'room_id': roomId, 'user_id': otherUserId},
    ]);

    return roomId;
  }

  // Создать групповую комнату
  Future<String> createGroupRoom(
    String name,
    List<String> participantIds,
  ) async {
    final currentUserId = _client.auth.currentUser?.id;
    if (currentUserId == null) throw Exception('Not authenticated');

    print('Creating group room with name: $name, created_by: $currentUserId');

    try {
      final newRoom = await _client
          .from('chat_rooms')
          .insert({
            'name': name,
            'is_private': false,
            'created_by': currentUserId,
          })
          .select('id')
          .single();
      final roomId = newRoom['id'] as String;
      print('Room created with id: $roomId');

      List<Map<String, String>> participants = participantIds
          .map((id) => <String, String>{'room_id': roomId, 'user_id': id})
          .toList();
      if (!participantIds.contains(currentUserId)) {
        participants.add(<String, String>{
          'room_id': roomId,
          'user_id': currentUserId,
        });
      }

      print('Inserting participants: $participants');
      try {
        await _client.from('chat_room_participants').insert(participants);
        print('Participants inserted successfully');
      } catch (e) {
        print('Error inserting participants: $e');
        rethrow;
      }

      return roomId;
    } catch (e) {
      print('Error in createGroupRoom: $e');
      rethrow;
    }
  }

  // Отправить сообщение
  Future<void> sendMessage(
    String roomId,
    String content, {
    String? imageUrl,
    String? voiceUrl,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) throw Exception('Not authenticated');

    final payload = {'room_id': roomId, 'user_id': userId, 'content': content};
    if (imageUrl != null) payload['image_url'] = imageUrl;
    if (voiceUrl != null) payload['voice_url'] = voiceUrl;

    await _client.from('messages').insert(payload);

    // Обновляем last_message_time в chat_rooms
    await _client
        .from('chat_rooms')
        .update({'last_message_time': DateTime.now().toIso8601String()})
        .eq('id', roomId);
  }

  // Загрузить файл в Supabase Storage и вернуть публичный URL
  Future<String> uploadFile(Uint8List bytes, String bucket, String path) async {
    try {
      // Используем uploadBinary (поддерживает загрузку Uint8List)
      await _client.storage.from(bucket).uploadBinary(path, bytes);

      // getPublicUrl возвращает публичный URL файла
      final url = _client.storage.from(bucket).getPublicUrl(path);

      print('Uploaded file URL: $url');
      return url;
    } catch (e) {
      final msg = e.toString();
      // Детальная информация об ошибке для диагностики
      print('Storage error details: $msg');
      if (msg.contains('Bucket not found')) {
        throw Exception(
          'Bucket "$bucket" not found. Please create it in Supabase Storage.',
        );
      }
      if (msg.contains('policy') ||
          msg.contains('403') ||
          msg.contains('Unauthorized')) {
        throw Exception(
          'Permission denied for bucket "$bucket". Check RLS policies in Supabase Storage.',
        );
      }
      rethrow;
    }
  }

  // Подписка на новые сообщения в комнате
  Stream<List<Message>> subscribeToMessages(String roomId) {
    return _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('room_id', roomId)
        .order('created_at')
        .map((maps) => maps.map(Message.fromJson).toList());
  }

  // Поиск пользователей по username (ILIKE)
  Future<List<UserProfile>> searchUsers(String query) async {
    if (query.isEmpty) return [];
    final response = await _client
        .from('profiles')
        .select()
        .ilike('username', '%$query%')
        .limit(20);
    return response.map((json) => UserProfile.fromJson(json)).toList();
  }
}
