import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'profile_setup_screen.dart';
import 'screens/chats_screen.dart';
import 'screens/new_chat_screen.dart';
import 'theme/theme_controller.dart';
import 'widgets/app_backdrop.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  bool _isLoading = true;
  bool _needsProfileSetup = false;
  int _currentIndex = 0;

  @override
  void initState() {
    super.initState();
    _checkProfile();
  }

  Future<void> _checkProfile() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', user.id)
          .maybeSingle();

      if (profile == null || profile['username'] == null) {
        _needsProfileSetup = true;
      } else {
        final username = profile['username'] as String;
        _needsProfileSetup = username.contains('@');
      }
    } catch (_) {
      _needsProfileSetup = true;
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_needsProfileSetup) {
      return const ProfileSetupScreen();
    }

    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        final isDark = ThemeController.instance.isDark;

        return Scaffold(
          appBar: AppBar(
            title: const Text('WayChat'),
            actions: [
              IconButton(
                icon: Icon(
                  isDark ? Icons.wb_sunny_rounded : Icons.nights_stay_rounded,
                ),
                tooltip: isDark ? 'Светлая тема' : 'Тёмная тема',
                onPressed: () => ThemeController.instance.toggle(),
              ),
              IconButton(
                icon: const Icon(Icons.logout_rounded),
                tooltip: 'Выйти',
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                },
              ),
            ],
          ),
          body: AppBackdrop(
            child: IndexedStack(
              index: _currentIndex,
              children: const [ChatsScreen()],
            ),
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const NewChatScreen()),
              );
              setState(() => _currentIndex = 0);
            },
            icon: const Icon(Icons.edit_square),
            label: const Text('Новый чат'),
          ),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _currentIndex,
            onDestinationSelected: (index) async {
              if (index == 1) {
                await Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const ProfileSetupScreen(),
                  ),
                );
                setState(() => _currentIndex = 0);
                return;
              }
              setState(() => _currentIndex = index);
            },
            destinations: const [
              NavigationDestination(
                icon: Icon(Icons.chat_bubble_outline_rounded),
                selectedIcon: Icon(Icons.chat_bubble_rounded),
                label: 'Чаты',
              ),
              NavigationDestination(
                icon: Icon(Icons.person_outline_rounded),
                selectedIcon: Icon(Icons.person_rounded),
                label: 'Профиль',
              ),
            ],
          ),
        );
      },
    );
  }
}
