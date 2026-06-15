import 'package:flutter/material.dart';
import 'screens/splash_screen.dart';
import 'core/services/notification_service.dart';

import 'package:provider/provider.dart' as legacy_provider;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/theme_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'core/services/hive_service.dart';
import 'core/services/desktop_routing.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PaintingBinding.instance.imageCache.maximumSize = 30 * 1024 * 1024;
  
  // Initialize Hive Caching database
  await HiveService.init();

  NotificationService().init().then((_) {
     NotificationService().requestPermissions();
  }).catchError((e) {
    debugPrint("Notification Async Init Error: $e");
  });

  try {
    final prefs = await SharedPreferences.getInstance().timeout(const Duration(seconds: 2));
    await prefs.remove('api_base_url');
  } catch (e) {
    debugPrint("Startup Prefs Error: $e");
  }

  runApp(
    ProviderScope(
      child: legacy_provider.ChangeNotifierProvider(
        create: (_) => ThemeProvider(),
        child: const MyApp(),
      ),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = legacy_provider.Provider.of<ThemeProvider>(context);
    return MaterialApp.router(
      debugShowCheckedModeBanner: false,
      title: 'Alwardas Academics & Administration',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: themeProvider.themeMode,
      routerConfig: desktopRouter,
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
