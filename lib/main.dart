import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'splash_screen.dart';
import 'theme/app_theme.dart';
import 'theme/theme_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://rtlgrqbyuwepieykfxpx.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InJ0bGdycWJ5dXdlcGlleWtmeHB4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzIyNzQ0NTgsImV4cCI6MjA4Nzg1MDQ1OH0.ukMnTA4GxkwqGa0FFtzctSnbsI-oZTD5LFkg01t4Mj8',
  );

  await ThemeController.instance.load();

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: ThemeController.instance,
      builder: (context, _) {
        return MaterialApp(
          title: 'WayChat',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: ThemeController.instance.mode,
          home: const SplashScreen(),
        );
      },
    );
  }
}
