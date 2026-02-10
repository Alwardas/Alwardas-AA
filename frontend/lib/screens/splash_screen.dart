import 'package:flutter/material.dart';
import 'package:video_player/video_player.dart';
import '../core/services/auth_service.dart';
import '../core/services/notification_service.dart';
import 'auth/login_screen.dart';
import 'dashboards/student/student_dashboard.dart';
import 'dashboards/parent/parent_dashboard.dart';
import 'dashboards/faculty/faculty_dashboard.dart';
import 'dashboards/hod/hod_dashboard.dart';
import 'dashboards/principal/principal_dashboard.dart';
import 'package:provider/provider.dart';
import '../core/providers/theme_provider.dart';
import 'dashboards/admin/admin_dashboard.dart';

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
    await NotificationService().init();
    await NotificationService().requestPermissions();
  }

  void _initializeVideo() {
    _controller = VideoPlayerController.asset("assets/1766819269806.mp4")
      ..initialize().then((_) {
        setState(() {});
        _controller.setPlaybackSpeed(1.35);
        _controller.play();
      });

    _controller.addListener(() {
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

    Widget destination;
    if (userData != null) {
      final role = userData['role'];
      switch (role) {
        case 'Student': destination = StudentDashboard(userData: userData); break;
        case 'Parent': destination = ParentDashboard(userData: userData); break;
        case 'Faculty': destination = FacultyDashboard(userData: userData); break;
        case 'HOD': destination = HodDashboard(userData: userData); break;
        case 'Principal': destination = PrincipalDashboard(userData: userData); break;
        case 'Admin': destination = AdminDashboard(userData: userData); break;
        default: destination = const LoginScreen();
      }
    } else {
      destination = const LoginScreen();
    }

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => destination),
    );
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
