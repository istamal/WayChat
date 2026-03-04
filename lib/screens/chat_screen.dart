import 'dart:async';
import 'dart:io';
import 'dart:math' as math;

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:record/record.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/chat_room.dart';
import '../models/message.dart';
import '../models/user_profile.dart';
import '../services/chat_service.dart';
import '../widgets/app_backdrop.dart';

class ChatScreen extends StatefulWidget {
  final String roomId;
  final ChatRoom? room;

  const ChatScreen({super.key, required this.roomId, this.room});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen>
    with SingleTickerProviderStateMixin {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  StreamSubscription<List<Message>>? _messagesSubscription;
  Timer? _messagesPollingTimer;
  bool _isPollingFallbackActive = false;
  List<Message> _messages = [];

  Uint8List? _pendingImageBytes;
  String? _pendingImageName;

  late Record _audioRecorder;
  bool _isRecording = false;
  bool _recordByHold = false;
  Duration _recordDuration = Duration.zero;
  Timer? _recordTimer;
  String? _activeRecordingPath;
  String? _recordingPath;
  late AnimationController _eqController;

  late AudioPlayer _audioPlayer;
  String? _playingVoiceUrl;
  bool _isPlaying = false;
  bool _isDraftPlaying = false;
  bool _holdCancelTriggered = false;
  final Set<String> _readReceiptSyncedIds = <String>{};

  final Map<String, UserProfile> _userCache = {};

  @override
  void initState() {
    super.initState();
    _audioRecorder = Record();
    _audioPlayer = AudioPlayer();
    _eqController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();

    _audioPlayer.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state == PlayerState.playing;
      });
    });

    _audioPlayer.onPlayerComplete.listen((_) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _playingVoiceUrl = null;
        _isDraftPlaying = false;
      });
    });

    _startMessagesRealtimeSubscription();
  }

  void _startMessagesRealtimeSubscription() {
    _messagesSubscription?.cancel();
    _messagesSubscription = _chatService.subscribeToMessages(widget.roomId).listen(
      (messages) async {
        await _handleIncomingMessages(messages);
      },
      onError: (error, stackTrace) async {
        print('Realtime messages subscription error: $error');
        if (!mounted) return;
        _startMessagesPollingFallback();
      },
      cancelOnError: false,
    );
  }

  void _startMessagesPollingFallback() {
    if (_isPollingFallbackActive) return;
    _isPollingFallbackActive = true;
    _messagesPollingTimer?.cancel();

    _pollMessagesOnce();
    _messagesPollingTimer = Timer.periodic(const Duration(seconds: 3), (_) {
      _pollMessagesOnce();
    });
  }

  Future<void> _pollMessagesOnce() async {
    if (!mounted) return;
    try {
      final messages = await _chatService.getMessages(widget.roomId);
      await _handleIncomingMessages(messages);
    } catch (e) {
      print('Polling messages error: $e');
    }
  }

  Future<void> _handleIncomingMessages(List<Message> messages) async {
    messages.sort((a, b) => a.createdAt.compareTo(b.createdAt));
    if (mounted) {
      setState(() => _messages = messages);
    }
    await _ensureUserProfiles(messages);
    await _markIncomingMessagesAsRead(messages);
    _scrollToBottom();
  }

  Future<void> _markIncomingMessagesAsRead(List<Message> messages) async {
    final currentUserId = Supabase.instance.client.auth.currentUser?.id;
    if (currentUserId == null) return;

    final unreadIncomingIds = messages
        .where(
          (m) =>
              m.userId != currentUserId &&
              m.readAt == null &&
              !_readReceiptSyncedIds.contains(m.id),
        )
        .map((m) => m.id)
        .toList();

    if (unreadIncomingIds.isEmpty) return;

    _readReceiptSyncedIds.addAll(unreadIncomingIds);
    try {
      await _chatService.markMessagesAsRead(
        widget.roomId,
        messageIds: unreadIncomingIds,
      );
    } catch (e) {
      _readReceiptSyncedIds.removeAll(unreadIncomingIds);
      print('Error marking messages as read: $e');
    }
  }

  Future<void> _ensureUserProfiles(List<Message> messages) async {
    final missing = messages
        .map((m) => m.userId)
        .where((id) => !_userCache.containsKey(id))
        .toSet()
        .toList();

    if (missing.isEmpty) return;

    try {
      final response = await Supabase.instance.client
          .from('profiles')
          .select()
          .inFilter('id', missing);

      for (final json in response) {
        final profile = UserProfile.fromJson(json);
        _userCache[profile.id] = profile;
      }

      if (mounted) setState(() {});
    } catch (e) {
      print('Error loading profiles: $e');
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 280),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageController.text.trim();
    if (text.isEmpty && _pendingImageBytes == null && _recordingPath == null) {
      return;
    }

    final userId = Supabase.instance.client.auth.currentUser!.id;
    String? imageUrl;
    String? voiceUrl;

    if (_isPlaying) {
      await _audioPlayer.stop();
      if (mounted) {
        setState(() {
          _playingVoiceUrl = null;
          _isPlaying = false;
          _isDraftPlaying = false;
        });
      }
    }

    if (_pendingImageBytes != null) {
      final filename =
          '${widget.roomId}/${DateTime.now().millisecondsSinceEpoch}_$userId.jpg';
      try {
        imageUrl = await _chatService.uploadFile(
          _pendingImageBytes!,
          'chat-images',
          filename,
        );
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(e.toString())));
        return;
      }
    }

    final sentRecordingPath = _recordingPath;
    if (sentRecordingPath != null) {
      try {
        final audioFile = File(sentRecordingPath);
        final bytes = await audioFile.readAsBytes();
        final filename =
            '${widget.roomId}/${DateTime.now().millisecondsSinceEpoch}_$userId.m4a';
        voiceUrl = await _chatService.uploadFile(
          bytes,
          'voice-messages',
          filename,
        );
        await audioFile.delete();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Ошибка загрузки голоса: $e')));
        return;
      }
    }

    if (mounted) {
      setState(() {
        _messageController.clear();
        _pendingImageBytes = null;
        _pendingImageName = null;
        _recordingPath = null;
        _recordDuration = Duration.zero;
      });
    }

    try {
      await _chatService.sendMessage(
        widget.roomId,
        text,
        imageUrl: imageUrl,
        voiceUrl: voiceUrl,
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка отправки: $e')));
    }
  }

  Future<void> _startRecording() async {
    if (_isRecording) return;
    try {
      if (await _audioRecorder.hasPermission()) {
        await _discardRecordedVoice();
        final tempPath = _getTempPath();
        _activeRecordingPath =
            '$tempPath/voice_${DateTime.now().millisecondsSinceEpoch}.m4a';

        await _audioRecorder.start(
          path: _activeRecordingPath,
          encoder: AudioEncoder.aacLc,
        );
        _recordTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _isRecording = true;
          _recordByHold = false;
          _recordDuration = Duration.zero;
        });
        _recordTimer = Timer.periodic(const Duration(seconds: 1), (_) {
          if (!mounted || !_isRecording) return;
          setState(() {
            _recordDuration += const Duration(seconds: 1);
          });
        });
      } else {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Требуется разрешение на запись аудио')),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка записи: $e')));
    }
  }

  Future<void> _startRecordingByHold() async {
    if (_isRecording) return;
    await _startRecording();
    if (!mounted || !_isRecording) return;
    setState(() {
      _recordByHold = true;
      _holdCancelTriggered = false;
    });
  }

  Future<void> _stopRecording({bool sendAfterStop = false}) async {
    if (!_isRecording) return;
    try {
      final stoppedPath = await _audioRecorder.stop();
      _recordTimer?.cancel();
      final savedPath = stoppedPath ?? _activeRecordingPath;
      _activeRecordingPath = null;
      final duration = _recordDuration;

      if (duration.inMilliseconds < 500 || savedPath == null) {
        if (savedPath != null) {
          final file = File(savedPath);
          if (await file.exists()) {
            await file.delete();
          }
        }
        if (!mounted) return;
        setState(() {
          _isRecording = false;
          _recordByHold = false;
          _recordDuration = Duration.zero;
          _recordingPath = null;
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _recordByHold = false;
        _recordingPath = savedPath;
        _holdCancelTriggered = false;
      });

      if (sendAfterStop) {
        await _sendMessage();
      }
    } catch (e) {
      print('Error stopping recording: $e');
    }
  }

  Future<void> _cancelRecordingBySwipe() async {
    if (!_isRecording || _holdCancelTriggered) return;
    _holdCancelTriggered = true;
    try {
      final stoppedPath = await _audioRecorder.stop();
      _recordTimer?.cancel();
      final savedPath = stoppedPath ?? _activeRecordingPath;
      _activeRecordingPath = null;
      if (savedPath != null) {
        final file = File(savedPath);
        if (await file.exists()) {
          await file.delete();
        }
      }
      if (!mounted) return;
      setState(() {
        _isRecording = false;
        _recordByHold = false;
        _recordDuration = Duration.zero;
        _recordingPath = null;
        _holdCancelTriggered = true;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Запись отменена')));
    } catch (e) {
      print('Error cancelling recording: $e');
    }
  }

  Future<void> _discardRecordedVoice() async {
    final path = _recordingPath;
    if (_isDraftPlaying ||
        (_playingVoiceUrl != null && _playingVoiceUrl == path)) {
      await _audioPlayer.stop();
    }
    if (mounted) {
      setState(() {
        _recordingPath = null;
        _recordDuration = Duration.zero;
        _isPlaying = false;
        _isDraftPlaying = false;
        _playingVoiceUrl = null;
      });
    }
    if (path == null) return;
    final file = File(path);
    if (await file.exists()) {
      await file.delete();
    }
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  String _formatMessageTime(DateTime dateTime) {
    final hours = dateTime.hour.toString().padLeft(2, '0');
    final minutes = dateTime.minute.toString().padLeft(2, '0');
    return '$hours:$minutes';
  }

  String _getTempPath() {
    if (Platform.isAndroid) return '/data/user/0/com.example.waychat/cache';
    return '/tmp';
  }

  Future<void> _pickAndPrepareImage() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (xfile == null) return;

    final bytes = await xfile.readAsBytes();
    setState(() {
      _pendingImageBytes = bytes;
      _pendingImageName = xfile.name;
    });
  }

  void _showAttachmentOptions() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(14),
          child: GlassCard(
            child: SafeArea(
              child: Wrap(
                children: [
                  ListTile(
                    leading: const Icon(Icons.image_rounded),
                    title: const Text('Изображение из галереи'),
                    onTap: () {
                      Navigator.pop(context);
                      _pickAndPrepareImage();
                    },
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _removePendingImage() {
    setState(() {
      _pendingImageBytes = null;
      _pendingImageName = null;
    });
  }

  Future<void> _playVoiceMessage(String voiceUrl) async {
    if (voiceUrl.trim().isEmpty) return;

    final uri = Uri.tryParse(voiceUrl);
    if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
      print('Invalid voice URL, skipping playback: $voiceUrl');
      return;
    }

    try {
      await _audioPlayer.stop();
      setState(() {
        _playingVoiceUrl = voiceUrl;
        _isPlaying = true;
        _isDraftPlaying = false;
      });
      await _audioPlayer.play(UrlSource(uri.toString()));
    } on PlatformException catch (e) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _playingVoiceUrl = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка воспроизведения: $e')));
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isPlaying = false;
        _playingVoiceUrl = null;
      });
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка воспроизведения: $e')));
    }
  }

  Future<void> _toggleDraftPlayback() async {
    final path = _recordingPath;
    if (path == null) return;

    try {
      if (_isDraftPlaying && _playingVoiceUrl == path && _isPlaying) {
        await _audioPlayer.pause();
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _isDraftPlaying = false;
        });
        return;
      }

      await _audioPlayer.stop();
      if (!mounted) return;
      setState(() {
        _playingVoiceUrl = path;
        _isPlaying = true;
        _isDraftPlaying = true;
      });
      await _audioPlayer.play(DeviceFileSource(path));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Ошибка предпрослушивания: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = Supabase.instance.client.auth.currentUser!.id;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    String title = 'Чат';
    if (widget.room != null) {
      if (widget.room!.isDirect) {
        final other = widget.room!.getOtherParticipant(currentUserId);
        title = other?.username ?? 'Собеседник';
      } else {
        title = widget.room!.name ?? 'Группа';
      }
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Вложение',
            onPressed: _showAttachmentOptions,
            icon: const Icon(Icons.attach_file_rounded),
          ),
        ],
      ),
      body: AppBackdrop(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                controller: _scrollController,
                padding: const EdgeInsets.fromLTRB(10, 6, 10, 10),
                itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final message = _messages[index];
                  final isMe = message.userId == currentUserId;
                  final incomingBubbleColor = isDark
                      ? const Color(0xFF1F2937).withValues(alpha: 0.9)
                      : Colors.white.withValues(alpha: 0.88);
                  final incomingBorderColor = isDark
                      ? Colors.white.withValues(alpha: 0.10)
                      : Colors.black.withValues(alpha: 0.06);
                  final incomingTextColor = isDark
                      ? Theme.of(context).colorScheme.onSurface
                      : const Color(0xFF1D1B20);
                  final incomingMetaColor = isDark
                      ? Colors.white70
                      : Colors.black54;
                  final authorName =
                      message.user?.username ??
                      _userCache[message.userId]?.username ??
                      'Пользователь';

                  return Align(
                    alignment: isMe
                        ? Alignment.centerRight
                        : Alignment.centerLeft,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.78,
                      ),
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.symmetric(
                          vertical: 10,
                          horizontal: 12,
                        ),
                        decoration: BoxDecoration(
                          gradient: isMe
                              ? const LinearGradient(
                                  colors: [
                                    Color(0xFF0D47A1),
                                    Color(0xFF00897B),
                                  ],
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                )
                              : null,
                          color: isMe
                              ? null
                              : incomingBubbleColor,
                          borderRadius: BorderRadius.only(
                            topLeft: const Radius.circular(18),
                            topRight: const Radius.circular(18),
                            bottomLeft: Radius.circular(isMe ? 18 : 6),
                            bottomRight: Radius.circular(isMe ? 6 : 18),
                          ),
                          border: Border.all(
                            color: isMe
                                ? Colors.transparent
                                : incomingBorderColor,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (!isMe)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Text(
                                  authorName,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(fontWeight: FontWeight.w700),
                                ),
                              ),
                            if (message.imageUrl != null &&
                                message.imageUrl!.isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.network(
                                    message.imageUrl!,
                                    fit: BoxFit.cover,
                                    errorBuilder:
                                        (context, error, stackTrace) =>
                                            Container(
                                              height: 120,
                                              color: Colors.black12,
                                              alignment: Alignment.center,
                                              child: const Icon(
                                                Icons.broken_image_rounded,
                                              ),
                                            ),
                                  ),
                                ),
                              ),
                            if (message.voiceUrl != null &&
                                message.voiceUrl!.isNotEmpty &&
                                (message.voiceUrl!.startsWith('http://') ||
                                    message.voiceUrl!.startsWith('https://')))
                              Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: _buildVoiceMessage(
                                  message.voiceUrl!,
                                  isMe,
                                ),
                              ),
                            if (message.content.isNotEmpty)
                              Text(
                                message.content,
                                style: Theme.of(context).textTheme.bodyLarge
                                    ?.copyWith(
                                      color: isMe
                                          ? Colors.white
                                          : incomingTextColor,
                                    ),
                              ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  _formatMessageTime(message.createdAt),
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: isMe
                                            ? Colors.white.withValues(
                                                alpha: 0.75,
                                              )
                                            : incomingMetaColor,
                                      ),
                                ),
                                if (isMe) const SizedBox(width: 4),
                                if (isMe)
                                  Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        Icons.done_rounded,
                                        size: 14,
                                        color: message.readAt != null
                                            ? const Color(0xFF81D4FA)
                                            : Colors.white.withValues(
                                                alpha: 0.75,
                                              ),
                                      ),
                                      if (message.readAt != null)
                                        const Padding(
                                          padding: EdgeInsets.only(left: 0.2),
                                          child: Icon(
                                            Icons.done_rounded,
                                            size: 14,
                                            color: Color(0xFF81D4FA),
                                          ),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
            if (_pendingImageBytes != null)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.9),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: SizedBox(
                        width: 70,
                        height: 70,
                        child: Image.memory(
                          _pendingImageBytes!,
                          fit: BoxFit.cover,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _pendingImageName ?? 'Изображение',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: _removePendingImage,
                    ),
                  ],
                ),
              ),
            if (_isRecording)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Theme.of(
                    context,
                  ).colorScheme.errorContainer.withValues(alpha: 0.45),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.fiber_manual_record_rounded,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            _recordByHold
                                ? 'Запись... отпустите, чтобы отправить'
                                : 'Запись... нажмите стоп, чтобы сохранить',
                            style: Theme.of(context).textTheme.bodySmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                          const SizedBox(height: 4),
                          if (_recordByHold)
                            Text(
                              'Свайп влево для отмены',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                          if (_recordByHold) const SizedBox(height: 4),
                          AnimatedBuilder(
                            animation: _eqController,
                            builder: (context, child) {
                              final phase = _eqController.value * 2 * math.pi;
                              return Row(
                                children: List.generate(5, (index) {
                                  final amp =
                                      (math.sin(phase + index * 0.7) + 1) / 2;
                                  final height = 6 + amp * 14;
                                  return Container(
                                    width: 4,
                                    height: height,
                                    margin: const EdgeInsets.only(right: 4),
                                    decoration: BoxDecoration(
                                      color: Theme.of(
                                        context,
                                      ).colorScheme.error,
                                      borderRadius: BorderRadius.circular(3),
                                    ),
                                  );
                                }),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 10),
                    if (_recordByHold)
                      Icon(
                        Icons.keyboard_double_arrow_left_rounded,
                        color: Theme.of(context).colorScheme.error,
                      ),
                    if (_recordByHold) const SizedBox(width: 6),
                    Text(
                      _formatDuration(_recordDuration),
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ],
                ),
              ),
            if (!_isRecording && _recordingPath != null)
              Container(
                margin: const EdgeInsets.fromLTRB(12, 0, 12, 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.audiotrack_rounded,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Голосовое сохранено: ${_formatDuration(_recordDuration)}',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          TextButton.icon(
                            style: TextButton.styleFrom(
                              minimumSize: const Size(0, 30),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 0,
                              ),
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                            ),
                            onPressed: _toggleDraftPlayback,
                            icon: Icon(
                              _isDraftPlaying
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              size: 20,
                            ),
                            label: Text(
                              _isDraftPlaying
                                  ? 'Пауза предпрослушивания'
                                  : 'Предпрослушать',
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Удалить',
                      onPressed: _discardRecordedVoice,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: IconButton(
                        tooltip: 'Отправить голосовое',
                        onPressed: _sendMessage,
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
              child: GlassCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                child: Row(
                  children: [
                    IconButton(
                      onPressed: _showAttachmentOptions,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                    ),
                    Expanded(
                      child: TextField(
                        controller: _messageController,
                        onSubmitted: (_) => _sendMessage(),
                        decoration: const InputDecoration(
                          hintText: 'Сообщение...',
                          border: InputBorder.none,
                          enabledBorder: InputBorder.none,
                          focusedBorder: InputBorder.none,
                          filled: false,
                        ),
                      ),
                    ),
                    GestureDetector(
                      onLongPressStart: (_) => _startRecordingByHold(),
                      onLongPressMoveUpdate: (details) {
                        if (!_recordByHold || _holdCancelTriggered) return;
                        if (details.offsetFromOrigin.dx < -80) {
                          _cancelRecordingBySwipe();
                        }
                      },
                      onLongPressEnd: (_) {
                        if (_holdCancelTriggered) {
                          setState(() {
                            _holdCancelTriggered = false;
                          });
                          return;
                        }
                        _stopRecording(sendAfterStop: true);
                      },
                      child: IconButton(
                        icon: Icon(
                          _isRecording
                              ? Icons.stop_circle_rounded
                              : Icons.mic_none_rounded,
                          color: _isRecording ? Colors.red.shade700 : null,
                        ),
                        tooltip: _isRecording
                            ? 'Остановить запись'
                            : 'Нажмите для записи, удерживайте для быстрой отправки',
                        onPressed: _isRecording
                            ? () => _stopRecording()
                            : _startRecording,
                      ),
                    ),
                    Container(
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.primary,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        onPressed: _sendMessage,
                        icon: const Icon(
                          Icons.send_rounded,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildVoiceMessage(String voiceUrl, bool isMe) {
    final isPlaying = _playingVoiceUrl == voiceUrl && _isPlaying;

    return GestureDetector(
      onTap: () async {
        try {
          if (isPlaying) {
            await _audioPlayer.pause();
            if (mounted) setState(() => _isPlaying = false);
          } else if (_playingVoiceUrl == voiceUrl) {
            await _audioPlayer.resume();
          } else {
            await _playVoiceMessage(voiceUrl);
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Ошибка аудиоплеера: $e')));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isMe
              ? Colors.white.withValues(alpha: 0.18)
              : Colors.black.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isPlaying
                  ? Icons.pause_circle_filled_rounded
                  : Icons.play_circle_fill_rounded,
              size: 22,
              color: isMe
                  ? Colors.white
                  : Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              isPlaying ? 'Идёт воспроизведение' : 'Голосовое сообщение',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isMe ? Colors.white : null,
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _recordTimer?.cancel();
    _messagesSubscription?.cancel();
    _messagesPollingTimer?.cancel();
    _messageController.dispose();
    _scrollController.dispose();
    _audioRecorder.dispose();
    _audioPlayer.dispose();
    _eqController.dispose();
    super.dispose();
  }
}
