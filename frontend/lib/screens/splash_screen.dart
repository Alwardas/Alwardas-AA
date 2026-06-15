import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../core/services/auth_service.dart';
import '../core/services/notification_service.dart';
import 'package:go_router/go_router.dart';
import '../core/services/hive_service.dart';
import 'package:provider/provider.dart';
import '../core/providers/theme_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  late VideoPlayerController _controller;
  bool _isNavigated = false;

  @override
  void initState() {
    super.initState();
    _initServices();
    _initializeVideo();
  }

  Future<void> _initServices() async {
    try {
      await NotificationService().init();
      await NotificationService().requestPermissions();
    } catch (e) {
      debugPrint("Service Init Error: $e");
    }
  }

  void _initializeVideo() {
    _controller = VideoPlayerController.asset("assets/1766819269806.mp4");
    
    // Set volume to 0 to prevent audio focus conflicts (critical during calls)
    _controller.setVolume(0.0);

    Future<void> init() async {
      try {
        // Use a timeout for the initialization itself to prevent hanging on hardware lock
        await _controller.initialize().timeout(const Duration(milliseconds: 1500));
        if (mounted) {
          setState(() {});
          _controller.setPlaybackSpeed(1.35);
          _controller.play().catchError((e) => debugPrint("Play error: $e"));
        }
      } catch (error) {
        debugPrint("Video initialization error or timeout: $error");
        _checkSession(); // Jump to next screen immediately on failure
      }
    }
    init();

    // Aggressive safety timeout: if video doesn't initialize/play in 2 seconds, proceed
    Future.delayed(const Duration(milliseconds: 2000), () {
      if (mounted && !_isNavigated) {
        if (!_controller.value.isInitialized || !_controller.value.isPlaying) {
           debugPrint("Safety jump triggered");
           _checkSession();
        }
      }
    });

    _controller.addListener(() {
      if (_controller.value.hasError) {
        debugPrint("Video player error: ${_controller.value.errorDescription}");
        _checkSession();
        return;
      }
      
      if (_controller.value.isInitialized &&
          _controller.value.position >= _controller.value.duration &&
          !_isNavigated) {
        _checkSession();
      }
    });
  }

  Future<void> _checkSession() async {
    if (_isNavigated) return;
    _isNavigated = true;

    final userData = await AuthService.getUserSession();
    
    if (!mounted) return;

    if (userData != null) {
      debugPrint("Session Found: Role=${userData['role']}");
      await HiveService.saveSession(userData);
      if (mounted) {
        context.go('/dashboard');
      }
    } else {
      debugPrint("No Session Found");
      context.go('/login');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final themeProvider = Provider.of<ThemeProvider>(context);
    final isDark = themeProvider.isDarkMode;

    return Scaffold(
      body: Container(
        color: Colors.black,
        child: Stack(
          alignment: Alignment.center,
          children: [
            if (_controller.value.isInitialized)
              SizedBox.expand(
                child: FittedBox(
                  fit: BoxFit.contain,
                  child: SizedBox(
                    width: _controller.value.size.width,
                    height: _controller.value.size.height,
                    child: VideoPlayer(_controller),
                  ),
                ),
              )
            else
              CircularProgressIndicator(color: isDark ? Colors.white : Colors.blue),
          ],
        ),
      ),
    );
  }
}
