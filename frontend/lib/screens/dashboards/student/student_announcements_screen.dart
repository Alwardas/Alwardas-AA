import 'package:flutter/material.dart';
import '../coordinator/coordinator_announcements_screen.dart';

class StudentAnnouncementsScreen extends StatelessWidget {
  const StudentAnnouncementsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const CoordinatorAnnouncementsScreen(isReadOnly: true);
  }
}
