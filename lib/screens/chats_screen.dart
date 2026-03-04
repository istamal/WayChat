import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_room.dart';
import '../services/chat_service.dart';
import '../widgets/app_backdrop.dart';
import 'chat_screen.dart';
import 'new_chat_screen.dart';

class ChatsScreen extends StatefulWidget {
  const ChatsScreen({super.key});

  @override
  State<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends State<ChatsScreen> {
  final ChatService _chatService = ChatService();
  late Future<List<ChatRoom>> _roomsFuture;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    _refreshRooms();
  }

  void _refreshRooms() {
    setState(() {
      _roomsFuture = _chatService.getMyRooms();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
          child: GlassCard(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: TextField(
              decoration: const InputDecoration(
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                filled: false,
                prefixIcon: Icon(Icons.search_rounded),
                hintText: 'Поиск чатов',
              ),
              onChanged: (value) {
                setState(() => _searchQuery = value.toLowerCase());
              },
            ),
          ),
        ),
        SizedBox(
          height: 94,
          child: FutureBuilder<List<ChatRoom>>(
            future: _roomsFuture,
            builder: (context, snapshot) {
              if (!snapshot.hasData) return const SizedBox.shrink();
              final rooms = snapshot.data ?? [];
              final directRooms = rooms
                  .where((r) => r.isDirect)
                  .take(8)
                  .toList();
              if (directRooms.isEmpty) return const SizedBox.shrink();

              return ListView.builder(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                itemCount: directRooms.length,
                itemBuilder: (context, index) {
                  final room = directRooms[index];
                  final user = room.getOtherParticipant(
                    Supabase.instance.client.auth.currentUser!.id,
                  );
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) =>
                                ChatScreen(roomId: room.id, room: room),
                          ),
                        ).then((_) => _refreshRooms());
                      },
                      child: Column(
                        children: [
                          _buildAvatar(
                            user?.avatarUrl,
                            user?.username,
                            radius: 28,
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: 64,
                            child: Text(
                              user?.username ?? '?',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              textAlign: TextAlign.center,
                              style: Theme.of(context).textTheme.bodySmall,
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
        Expanded(
          child: FutureBuilder<List<ChatRoom>>(
            future: _roomsFuture,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError) {
                return Center(child: Text('Ошибка: ${snapshot.error}'));
              }

              final allRooms = snapshot.data ?? [];
              final rooms = _searchQuery.isEmpty
                  ? allRooms
                  : allRooms.where((r) {
                      final currentUserId =
                          Supabase.instance.client.auth.currentUser!.id;
                      final roomNameMatch =
                          r.name?.toLowerCase().contains(_searchQuery) ?? false;
                      final directNameMatch =
                          r.isDirect &&
                          (r
                                  .getOtherParticipant(currentUserId)
                                  ?.username
                                  .toLowerCase()
                                  .contains(_searchQuery) ??
                              false);
                      return roomNameMatch || directNameMatch;
                    }).toList();

              if (rooms.isEmpty) {
                return Center(
                  child: GlassCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.mark_chat_unread_rounded,
                          size: 56,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          'Чатов пока нет',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Начните первый диалог',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 14),
                        ElevatedButton.icon(
                          onPressed: _navigateToNewChat,
                          icon: const Icon(Icons.add_comment_rounded),
                          label: const Text('Начать чат'),
                        ),
                      ],
                    ),
                  ),
                );
              }

              return ListView.builder(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 110),
                itemCount: rooms.length,
                itemBuilder: (context, index) => _buildRoomTile(rooms[index]),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRoomTile(ChatRoom room) {
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;

    String title;
    String subtitle;
    String? avatarUrl;
    IconData? groupIcon;

    if (room.isDirect) {
      final other = room.getOtherParticipant(currentUserId);
      title = other?.username ?? 'Пользователь';
      subtitle = room.lastMessage?.content ?? 'Начните общение';
      avatarUrl = other?.avatarUrl;
    } else {
      title = room.name ?? 'Групповой чат';
      subtitle = room.lastMessage?.content ?? 'Нет сообщений';
      groupIcon = Icons.groups_rounded;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: GlassCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () {
            Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => ChatScreen(roomId: room.id, room: room),
              ),
            ).then((_) => _refreshRooms());
          },
          child: Row(
            children: [
              groupIcon != null
                  ? CircleAvatar(
                      radius: 27,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.secondary.withValues(alpha: 0.18),
                      child: Icon(
                        groupIcon,
                        color: Theme.of(context).colorScheme.secondary,
                      ),
                    )
                  : _buildAvatar(avatarUrl, title, radius: 27),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              ),
              if (room.lastMessage != null)
                Text(
                  DateFormat.Hm().format(room.lastMessage!.createdAt),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(
    String? avatarUrl,
    String? username, {
    double radius = 24,
  }) {
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(avatarUrl),
      );
    }

    final firstLetter = (username != null && username.isNotEmpty)
        ? username.substring(0, 1).toUpperCase()
        : '?';

    return CircleAvatar(
      radius: radius,
      backgroundColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.18),
      child: Text(
        firstLetter,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }

  void _navigateToNewChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewChatScreen()),
    ).then((_) => _refreshRooms());
  }
}
