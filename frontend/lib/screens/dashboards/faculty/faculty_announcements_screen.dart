import 'package:flutter/material.dart';
import '../coordinator/coordinator_announcements_screen.dart';

class FacultyAnnouncementsScreen extends StatelessWidget {
  const FacultyAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Using CoordinatorAnnouncementsScreen to allow faculties to create and manage announcements
    return const CoordinatorAnnouncementsScreen(isReadOnly: false);
  }
}
