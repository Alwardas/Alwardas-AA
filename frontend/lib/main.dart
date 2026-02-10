import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';

import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Performance: Increase image cache limit (100MB) for smoother asset loading
  PaintingBinding.instance.imageCache.maximumSize = 100 * 1024 * 1024;
  
  // Hard reset API URL to production to clear any legacy local IPs stored in device cache
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('api_base_url');

  runApp(
    ChangeNotifierProvider(
      create: (_) => ThemeProvider(),
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Alwardas Academics & Administration',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      builder: (context, child) {
        return ScrollConfiguration(
          behavior: const CustomScrollBehavior(),
          child: child!,
        );
      },
      home: const SplashScreen(),
    );
  }
}

class CustomScrollBehavior extends ScrollBehavior {
  const CustomScrollBehavior();

  @override
  ScrollPhysics getScrollPhysics(BuildContext context) {
    return const BouncingScrollPhysics(
      parent: AlwaysScrollableScrollPhysics(),
    );
  }

  @override
  Widget buildOverscrollIndicator(
      BuildContext context, Widget child, ScrollableDetails details) {
    return child; // Removes the Android 'stretch/glow' for a cleaner look
  }
}
