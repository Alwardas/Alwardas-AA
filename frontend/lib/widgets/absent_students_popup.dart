import 'package:flutter/material.dart';
import '../screens/common/absent_students_screen.dart';

class AbsentStudentsPopup {
  static void show(BuildContext context, List<dynamic> absents, String title, {DateTime? date}) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AbsentStudentsScreen(absents: absents, title: title, date: date),
      ),
    );
  }
}
