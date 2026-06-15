import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'hive_service.dart';

import '../../screens/splash_screen.dart';
import '../../screens/auth/login_screen.dart';
import '../../screens/auth/desktop_login_screen.dart';
import '../../screens/common/responsive_layout.dart';
import '../../pages/login_page.dart';
import '../../screens/dashboards/student/student_dashboard.dart';
import '../../screens/dashboards/parent/parent_dashboard.dart';
import '../../screens/dashboards/faculty/faculty_dashboard.dart';
import '../../screens/dashboards/hod/hod_dashboard.dart';
import '../../screens/dashboards/principal/principal_dashboard.dart';
import '../../screens/dashboards/admin/admin_dashboard.dart';
import '../../screens/dashboards/coordinator/coordinator_dashboard.dart';
import '../../screens/dashboards/incharge/incharge_dashboard.dart';
import '../../screens/dashboards/finance/fee_management_dashboard.dart';
import '../../screens/desktop/desktop_layout_shell.dart';

final desktopRouter = GoRouter(
  initialLocation: '/',
  redirect: (context, state) {
    final session = HiveService.getSession();
    final loggingIn = state.matchedLocation == '/login';

    if (session == null && state.matchedLocation != '/' && !loggingIn) {
      return '/login';
    }

    if (session != null && loggingIn) {
      return '/dashboard';
    }

    return null;
  },
  routes: [
    GoRoute(
      path: '/',
      builder: (context, state) => const SplashScreen(),
    ),
    GoRoute(
      path: '/login',
      builder: (context, state) => const LoginPage(),
    ),
    GoRoute(
      path: '/dashboard',
      builder: (context, state) {
        final session = HiveService.getSession();
        if (session == null) return const LoginPage();

        return LayoutBuilder(
          builder: (context, constraints) {
            final role = session['role'] ?? '';
            final isMobileRole = role == 'Student' || role == 'Parent';

            if (constraints.maxWidth > 900 && !isMobileRole) {
              return DesktopLayoutShell(userData: session);
            }

            // Return traditional mobile/tablet dashboards
            switch (role) {
              case 'Student':
                return StudentDashboard(userData: session);
              case 'Parent':
                return ParentDashboard(userData: session);
              case 'Faculty':
                return FacultyDashboard(userData: session);
              case 'HOD':
                return HodDashboard(userData: session);
              case 'Principal':
                return PrincipalDashboard(userData: session);
              case 'Admin':
                return AdminDashboard(userData: session);
              case 'Coordinator':
                return CoordinatorDashboard(userData: session);
              case 'Incharge':
                return InchargeDashboard(userData: session);
              case 'Accountant':
              case 'Finance':
                return FeeManagementDashboard(userData: session);
              default:
                return const LoginPage();
            }
          },
        );
      },
    ),
    // Define fallback sub routes to preserve external references
    GoRoute(
      path: '/mobile-student',
      builder: (context, state) => StudentDashboard(userData: HiveService.getSession() ?? {}),
    ),
    GoRoute(
      path: '/mobile-parent',
      builder: (context, state) => ParentDashboard(userData: HiveService.getSession() ?? {}),
    ),
  ],
);
