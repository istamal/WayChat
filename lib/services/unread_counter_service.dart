import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_app_badger/flutter_app_badger.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class UnreadCounterService {
  UnreadCounterService._();

  static final UnreadCounterService instance = UnreadCounterService._();

  final SupabaseClient _client = Supabase.instance.client;

  final ValueNotifier<Map<String, int>> unreadByRoom =
      ValueNotifier<Map<String, int>>(<String, int>{});
  final ValueNotifier<int> totalUnread = ValueNotifier<int>(0);

  StreamSubscription<List<Map<String, dynamic>>>? _subscription;
  String? _activeUserId;

  Future<void> start() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      await stop();
      return;
    }

    if (_activeUserId == userId && _subscription != null) return;
    await stop();
    _activeUserId = userId;

    _subscription = _client
        .from('messages')
        .stream(primaryKey: ['id'])
        .neq('user_id', userId)
        .order('created_at')
        .listen(
          _handleUnreadMessages,
          onError: (_) async {
            await _loadUnreadSnapshot();
          },
        );

    await _loadUnreadSnapshot();
  }

  Future<void> _loadUnreadSnapshot() async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      _setCounters(const <String, int>{});
      return;
    }

    try {
      final rows = await _client
          .from('messages')
          .select('id, room_id')
          .neq('user_id', userId)
          .isFilter('read_at', null);
      _handleUnreadMessages(
        rows
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList(growable: false),
      );
    } catch (_) {}
  }

  void _handleUnreadMessages(List<Map<String, dynamic>> rows) {
    final Map<String, int> next = <String, int>{};
    for (final row in rows) {
      if (row['read_at'] != null) continue;
      final roomId = row['room_id']?.toString();
      if (roomId == null || roomId.isEmpty) continue;
      next[roomId] = (next[roomId] ?? 0) + 1;
    }

    _setCounters(next);
  }

  void _setCounters(Map<String, int> counters) {
    unreadByRoom.value = counters;
    final total = counters.values.fold<int>(0, (a, b) => a + b);
    totalUnread.value = total;
    _syncAppIconBadge(total);
  }

  void _syncAppIconBadge(int count) {
    FlutterAppBadger.isAppBadgeSupported()
        .then((supported) {
          if (!supported) return;
          if (count > 0) {
            FlutterAppBadger.updateBadgeCount(count);
          } else {
            FlutterAppBadger.removeBadge();
          }
        })
        .catchError((_) {});
  }

  Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
    _activeUserId = null;
    _setCounters(const <String, int>{});
  }
}
