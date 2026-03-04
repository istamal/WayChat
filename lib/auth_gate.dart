import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'email_login_screen.dart'; // ← изменённый импорт
import 'home_screen.dart';
import 'profile_setup_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  Future<bool> _hasProfileSetup(String userId) async {
    try {
      final profile = await Supabase.instance.client
          .from('profiles')
          .select('username')
          .eq('id', userId)
          .maybeSingle();

      return profile != null &&
          profile['username'] != null &&
          profile['username'].isNotEmpty;
    } catch (e) {
      print('Error checking profile: $e');
      return false;
    }
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.active) {
          final session = snapshot.data?.session;
          if (session != null) {
            return FutureBuilder<bool>(
              future: _hasProfileSetup(session.user.id),
              builder: (context, profileSnapshot) {
                if (profileSnapshot.connectionState ==
                    ConnectionState.waiting) {
                  return const Scaffold(
                    body: Center(child: CircularProgressIndicator()),
                  );
                }

                if (profileSnapshot.hasData && profileSnapshot.data == true) {
                  return const HomeScreen();
                } else {
                  return const ProfileSetupScreen();
                }
              },
            );
          }
        }
        return const EmailLoginScreen();
      },
    );
  }
}
