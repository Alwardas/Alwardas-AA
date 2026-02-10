
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:permission_handler/permission_handler.dart';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // Android Initialization
    // Make sure @mipmap/ic_launcher exists. Default flutter project has it.
    const AndroidInitializationSettings initializationSettingsAndroid =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // iOS Initialization
    const DarwinInitializationSettings initializationSettingsDarwin =
        DarwinInitializationSettings(
      requestSoundPermission: false,
      requestBadgePermission: false,
      requestAlertPermission: false,
    );

    const InitializationSettings initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsDarwin,
    );

    await flutterLocalNotificationsPlugin.initialize(
      initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) async {
        // Handle notification tap here if needed
      },
    );
  }

  Future<void> requestPermissions() async {
    // Android 13+ Notification Permission
    final status = await Permission.notification.status;
    if (status.isDenied || status.isPermanentlyDenied) {
        await Permission.notification.request();
    }
    
    // iOS Permission
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin>()
        ?.requestPermissions(
          alert: true,
          badge: true,
          sound: true,
        );

    // Storage Permission
    if (await Permission.storage.status.isDenied) {
        await Permission.storage.request();
    }
  }
  
  // Also request storage permissions for downloading reports
  Future<void> requestStoragePermissions() async {
    // For Android 11+ (API 30+), Manage External Storage is restricted.
    // However, for basic downloads to Public directory, we might need simple storage permission on older devices
    // or rely on Scoped Storage which doesn't need explicit permission for app-owned files.
    // But since user asked for "permissions", we can try requesting relevant ones.
    
    if (await Permission.storage.request().isGranted) {
      // Granted
    }
    // Android 13 uses specialized permissions for media files, but 'storage' usually maps correctly for general access if needed.
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
    String? payload,
  }) async {
    const AndroidNotificationDetails androidPlatformChannelSpecifics =
        AndroidNotificationDetails(
      'default_channel_id', 
      'Default Channel', 
      channelDescription: 'General Notifications',
      importance: Importance.max,
      priority: Priority.high,
      ticker: 'ticker',
      showWhen: true,
    );
    
    const NotificationDetails platformChannelSpecifics =
        NotificationDetails(android: androidPlatformChannelSpecifics);
        
    await flutterLocalNotificationsPlugin.show(
      id,
      title,
      body,
      platformChannelSpecifics,
      payload: payload,
    );
  }
}
