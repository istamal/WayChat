import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_room.dart';
import '../services/unread_counter_service.dart';
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
  Set<String> _presenceUserIds = <String>{};
  Map<String, bool> _presenceByUserId = <String, bool>{};
  StreamSubscription<List<Map<String, dynamic>>>? _presenceSubscription;

  bool _isValidNetworkUrl(String? value) {
    if (value == null) return false;
    final url = value.trim();
    if (url.isEmpty) return false;
    final uri = Uri.tryParse(url);
    return uri != null && (uri.isScheme('http') || uri.isScheme('https'));
  }

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

  void _ensurePresenceSubscription(List<ChatRoom> rooms) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final ids = rooms
        .where((r) => r.isDirect)
        .map((r) => r.getOtherParticipant(currentUserId)?.id)
        .whereType<String>()
        .toSet();

    if (_presenceUserIds.length == ids.length &&
        _presenceUserIds.containsAll(ids)) {
      return;
    }

    _presenceUserIds = ids;
    _presenceSubscription?.cancel();

    if (ids.isEmpty) {
      _safeSetState(() => _presenceByUserId = <String, bool>{});
      return;
    }

    final seed = <String, bool>{};
    for (final room in rooms.where((r) => r.isDirect)) {
      final other = room.getOtherParticipant(currentUserId);
      if (other?.id == null) continue;
      seed[other!.id] = other.isOnline == true;
    }
    _safeSetState(() => _presenceByUserId = seed);

    _presenceSubscription = Supabase.instance.client
        .from('profiles')
        .stream(primaryKey: ['id'])
        .inFilter('id', ids.toList())
        .listen(
          (rows) {
            if (!mounted || rows.isEmpty) return;
            final next = Map<String, bool>.from(_presenceByUserId);
            for (final row in rows) {
              final id = row['id']?.toString();
              if (id == null || id.isEmpty) continue;
              final isOnline = row['is_online'] == true || row['online'] == true;
              next[id] = isOnline;
            }
            _safeSetState(() => _presenceByUserId = next);
          },
          onError: (error) {
            print('Presence list stream error: $error');
          },
        );
  }

  void _safeSetState(VoidCallback fn) {
    if (!mounted) return;
    final binding = WidgetsBinding.instance;
    if (binding.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      binding.addPostFrameCallback((_) {
        if (mounted) setState(fn);
      });
      return;
    }
    setState(fn);
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return const SizedBox.shrink();

    return ValueListenableBuilder<Map<String, int>>(
      valueListenable: UnreadCounterService.instance.unreadByRoom,
      builder: (context, unreadByRoom, _) => Column(
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
                _ensurePresenceSubscription(rooms);
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
                    final user = room.getOtherParticipant(currentUserId);
                    final isOnline = user?.id != null
                        ? _presenceByUserId[user!.id] ?? user.isOnline == true
                        : false;
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
                              user?.displayNameOrUsername,
                              radius: 28,
                              isOnline: isOnline,
                            ),
                            const SizedBox(height: 6),
                            SizedBox(
                              width: 64,
                              child: Text(
                                user?.displayNameOrUsername ?? '?',
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
                _ensurePresenceSubscription(allRooms);
                final rooms = _searchQuery.isEmpty
                    ? allRooms
                    : allRooms.where((r) {
                        final currentUserId =
                            Supabase.instance.client.auth.currentUser?.id;
                        if (currentUserId == null) return false;
                        final roomNameMatch =
                            r.name?.toLowerCase().contains(_searchQuery) ??
                            false;
                        final directNameMatch =
                            r.isDirect &&
                            (r
                                    .getOtherParticipant(currentUserId)
                                    ?.displayNameOrUsername
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
                  itemBuilder: (context, index) =>
                      _buildRoomTile(rooms[index], unreadByRoom),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRoomTile(ChatRoom room, Map<String, int> unreadByRoom) {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return const SizedBox.shrink();
    final unreadCount = unreadByRoom[room.id] ?? 0;

    String title;
    String subtitle;
    String? avatarUrl;
    IconData? groupIcon;
    bool? isOnline;

    if (room.isDirect) {
      final other = room.getOtherParticipant(currentUserId);
      title = other?.displayNameOrUsername ?? 'Пользователь';
      subtitle = room.lastMessage?.content ?? 'Начните общение';
      avatarUrl = other?.avatarUrl;
      if (other?.id != null) {
        isOnline = _presenceByUserId[other!.id] ?? other.isOnline == true;
      }
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
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      DateFormat.Hm().format(room.lastMessage!.createdAt),
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    if (unreadCount > 0) const SizedBox(height: 6),
                    if (unreadCount > 0)
                      Badge(
                        label: Text(
                          unreadCount > 99 ? '99+' : unreadCount.toString(),
                        ),
                      ),
                  ],
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
    bool isOnline = false,
  }) {
    if (_isValidNetworkUrl(avatarUrl)) {
      return Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: radius,
            backgroundImage: NetworkImage(avatarUrl!.trim()),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: _PresenceDot(isOnline: isOnline, size: 10),
          ),
        ],
      );
    }

    final firstLetter = (username != null && username.isNotEmpty)
        ? username.substring(0, 1).toUpperCase()
        : '?';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        CircleAvatar(
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
        ),
        Positioned(
          right: -1,
          bottom: -1,
          child: _PresenceDot(isOnline: isOnline, size: 10),
        ),
      ],
    );
  }

  void _navigateToNewChat() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const NewChatScreen()),
    ).then((_) => _refreshRooms());
  }

  @override
  void dispose() {
    _presenceSubscription?.cancel();
    super.dispose();
  }
}

class _PresenceDot extends StatelessWidget {
  final bool isOnline;
  final double size;

  const _PresenceDot({required this.isOnline, this.size = 8});

  @override
  Widget build(BuildContext context) {
    final color = isOnline ? const Color(0xFF16A34A) : Colors.grey;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        border: Border.all(color: Colors.white, width: 1.5),
      ),
    );
  }
}
