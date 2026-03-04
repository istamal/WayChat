import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'home_screen.dart';
import 'services/chat_service.dart';
import 'widgets/app_backdrop.dart';

class ProfileSetupScreen extends StatefulWidget {
  const ProfileSetupScreen({super.key});

  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  final _usernameController = TextEditingController();
  final ChatService _chatService = ChatService();

  bool _isLoading = false;
  String? _errorText;
  String? _avatarUrl;

  Future<void> _saveProfile() async {
    final username = _usernameController.text.trim();
    if (username.isEmpty) {
      setState(() => _errorText = 'Введите имя пользователя');
      return;
    }
    if (username.length < 3) {
      setState(() => _errorText = 'Минимум 3 символа');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Не авторизован');

      final existing = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('username', username)
          .maybeSingle();

      if (existing != null) {
        setState(() {
          _errorText = 'Имя пользователя уже занято';
          _isLoading = false;
        });
        return;
      }

      await Supabase.instance.client
          .from('profiles')
          .update({'username': username, 'avatar_url': _avatarUrl})
          .eq('id', user.id);

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (context) => const HomeScreen()),
        (route) => false,
      );
    } catch (e) {
      setState(() {
        if (e.toString().contains('unique')) {
          _errorText = 'Имя пользователя уже занято';
        } else {
          _errorText = 'Ошибка при сохранении: $e';
        }
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAvatar() async {
    final picker = ImagePicker();
    final xfile = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 80,
    );
    if (xfile == null) return;

    setState(() => _isLoading = true);
    try {
      final bytes = await xfile.readAsBytes();
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception('Не авторизован');
      final path =
          'avatars/${user.id}_${DateTime.now().millisecondsSinceEpoch}.jpg';
      final url = await _chatService.uploadFile(bytes, 'avatars', path);
      setState(() => _avatarUrl = url);
    } catch (_) {
      setState(() => _errorText = 'Ошибка загрузки изображения');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Ваш профиль'),
        automaticallyImplyLeading: false,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: AppBackdrop(
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: GlassCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: GestureDetector(
                      onTap: _pickAvatar,
                      child: Stack(
                        children: [
                          CircleAvatar(
                            radius: 52,
                            backgroundColor: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.12),
                            backgroundImage: _avatarUrl != null
                                ? NetworkImage(_avatarUrl!)
                                : null,
                            child: _avatarUrl == null
                                ? const Icon(Icons.person_rounded, size: 50)
                                : null,
                          ),
                          Positioned(
                            right: 2,
                            bottom: 2,
                            child: Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: Theme.of(context).colorScheme.primary,
                                shape: BoxShape.circle,
                              ),
                              child: const Icon(
                                Icons.photo_camera_rounded,
                                color: Colors.white,
                                size: 16,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Придумайте имя пользователя',
                    style: Theme.of(context).textTheme.headlineSmall,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'По нему вас смогут найти в чатах',
                    style: Theme.of(context).textTheme.bodyMedium,
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 22),
                  TextField(
                    controller: _usernameController,
                    autofocus: true,
                    textCapitalization: TextCapitalization.none,
                    decoration: InputDecoration(
                      prefixIcon: const Icon(Icons.alternate_email_rounded),
                      labelText: 'Имя пользователя',
                      errorText: _errorText,
                    ),
                  ),
                  const SizedBox(height: 18),
                  ElevatedButton.icon(
                    onPressed: _isLoading ? null : _saveProfile,
                    icon: _isLoading
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle_rounded),
                    label: Text(
                      _isLoading ? 'Сохраняем...' : 'Сохранить профиль',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
