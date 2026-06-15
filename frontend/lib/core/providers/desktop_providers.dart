import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/dio_client.dart';
import '../services/hive_service.dart';

final dioClientProvider = Provider<DioClient>((ref) {
  return DioClient();
});

class DesktopSessionNotifier extends StateNotifier<Map<String, dynamic>?> {
  DesktopSessionNotifier() : super(HiveService.getSession());

  void setSession(Map<String, dynamic> userData) {
    HiveService.saveSession(userData);
    state = userData;
  }

  void clearSession() {
    HiveService.clearSession();
    state = null;
  }
}

final desktopSessionProvider = StateNotifierProvider<DesktopSessionNotifier, Map<String, dynamic>?>((ref) {
  return DesktopSessionNotifier();
});

final desktopNavigationProvider = StateProvider<String>((ref) {
  return 'Dashboard';
});

final desktopNotificationCountProvider = StateProvider<int>((ref) {
  return 0;
});
