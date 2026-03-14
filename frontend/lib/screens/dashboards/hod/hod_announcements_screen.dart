import 'package:flutter/material.dart';
import '../coordinator/coordinator_announcements_screen.dart';

class HODAnnouncementsScreen extends StatelessWidget {
  const HODAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Using CoordinatorAnnouncementsScreen to allow HODs to create and manage announcements
    return const CoordinatorAnnouncementsScreen(isReadOnly: false);
  }
}
