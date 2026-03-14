import 'package:flutter/material.dart';
import '../coordinator/coordinator_announcements_screen.dart';

class PrincipalAnnouncementsScreen extends StatelessWidget {
  const PrincipalAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Using CoordinatorAnnouncementsScreen to allow Principals to create and manage announcements
    return const CoordinatorAnnouncementsScreen(isReadOnly: false);
  }
}
