import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_profile.dart';
import '../services/chat_service.dart';
import '../widgets/app_backdrop.dart';
import 'chat_screen.dart';

class NewChatScreen extends StatefulWidget {
  const NewChatScreen({super.key});

  @override
  State<NewChatScreen> createState() => _NewChatScreenState();
}

class _NewChatScreenState extends State<NewChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _groupNameController = TextEditingController();

  List<UserProfile> _searchResults = [];
  final List<UserProfile> _selectedUsers = [];
  bool _isSearching = false;
  bool _isCreatingGroup = false;

  @override
  void dispose() {
    _searchController.dispose();
    _groupNameController.dispose();
    super.dispose();
  }

  Future<void> _search(String query) async {
    if (query.isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }

    setState(() => _isSearching = true);
    final results = await _chatService.searchUsers(query);
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    results.removeWhere((user) => user.id == currentUserId);

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _toggleSelectUser(UserProfile user) {
    setState(() {
      if (_selectedUsers.contains(user)) {
        _selectedUsers.remove(user);
      } else {
        _selectedUsers.add(user);
      }
    });
  }

  Future<void> _createDirectChat(UserProfile otherUser) async {
    try {
      final roomId = await _chatService.createOrGetDirectRoom(otherUser.id);
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => ChatScreen(roomId: roomId)),
      );
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Не удалось создать чат: $e')));
    }
  }

  Future<void> _createGroupChat() async {
    if (_groupNameController.text.isEmpty || _selectedUsers.isEmpty) return;
    final participantIds = _selectedUsers.map((u) => u.id).toList();
    final roomId = await _chatService.createGroupRoom(
      _groupNameController.text.trim(),
      participantIds,
    );

    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => ChatScreen(roomId: roomId)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isCreatingGroup ? 'Новая группа' : 'Новый чат'),
        actions: [
          if (!_isCreatingGroup)
            TextButton.icon(
              onPressed: () => setState(() => _isCreatingGroup = true),
              icon: const Icon(Icons.group_add_rounded, size: 18),
              label: const Text('Группа'),
            ),
          if (_isCreatingGroup)
            TextButton(
              onPressed: _selectedUsers.isEmpty ? null : _createGroupChat,
              child: const Text('Создать'),
            ),
        ],
      ),
      body: AppBackdrop(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 8,
                ),
                child: Column(
                  children: [
                    if (_isCreatingGroup) ...[
                      TextField(
                        controller: _groupNameController,
                        decoration: const InputDecoration(
                          labelText: 'Название группы',
                          prefixIcon: Icon(Icons.groups_rounded),
                        ),
                      ),
                      const SizedBox(height: 10),
                    ],
                    TextField(
                      controller: _searchController,
                      onChanged: _search,
                      decoration: InputDecoration(
                        hintText: _isCreatingGroup
                            ? 'Найти участников'
                            : 'Найти по username',
                        prefixIcon: const Icon(Icons.search_rounded),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            if (_isCreatingGroup && _selectedUsers.isNotEmpty)
              SizedBox(
                height: 56,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _selectedUsers.length,
                  itemBuilder: (context, index) {
                    final user = _selectedUsers[index];
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: Chip(
                        label: Text(user.username),
                        onDeleted: () => _toggleSelectUser(user),
                        avatar: CircleAvatar(
                          backgroundColor: Theme.of(
                            context,
                          ).colorScheme.primary.withValues(alpha: 0.2),
                          child: Text(
                            user.username.substring(0, 1).toUpperCase(),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            Expanded(
              child: _isSearching
                  ? const Center(child: CircularProgressIndicator())
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
                      itemCount: _searchResults.length,
                      itemBuilder: (context, index) {
                        final user = _searchResults[index];
                        final isSelected = _selectedUsers.contains(user);

                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: GlassCard(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 10,
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: CircleAvatar(
                                backgroundColor: Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.2),
                                backgroundImage:
                                    (user.avatarUrl != null &&
                                        user.avatarUrl!.isNotEmpty)
                                    ? NetworkImage(user.avatarUrl!)
                                    : null,
                                child:
                                    (user.avatarUrl == null ||
                                        user.avatarUrl!.isEmpty)
                                    ? Text(
                                        user.username
                                            .substring(0, 1)
                                            .toUpperCase(),
                                      )
                                    : null,
                              ),
                              title: Text(user.username),
                              subtitle: Text(user.fullName ?? ''),
                              trailing: _isCreatingGroup
                                  ? Icon(
                                      isSelected
                                          ? Icons.check_circle_rounded
                                          : Icons
                                                .radio_button_unchecked_rounded,
                                      color: isSelected
                                          ? Theme.of(
                                              context,
                                            ).colorScheme.secondary
                                          : Theme.of(
                                              context,
                                            ).colorScheme.outline,
                                    )
                                  : const Icon(Icons.chevron_right_rounded),
                              onTap: _isCreatingGroup
                                  ? () => _toggleSelectUser(user)
                                  : () => _createDirectChat(user),
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
