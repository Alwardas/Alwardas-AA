import 'package:flutter/material.dart';
import '../desktop/desktop_layout_shell.dart';

class ResponsiveLayout extends StatelessWidget {
  final Widget mobileBody;
  final Widget desktopBody;
  final String? userRole;

  const ResponsiveLayout({
    super.key,
    required this.mobileBody,
    required this.desktopBody,
    this.userRole,
  });

  static bool isMobile(BuildContext context) =>
      MediaQuery.of(context).size.width < 900;

  static bool isDesktop(BuildContext context) =>
      MediaQuery.of(context).size.width >= 900;

  @override
  Widget build(BuildContext context) {
    // If userRole is Student or Parent, they always use the mobile dashboard layout
    if (userRole == 'Student' || userRole == 'Parent') {
      return mobileBody;
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth >= 900) {
          return desktopBody;
        } else {
          return mobileBody;
        }
      },
    );
  }
}
