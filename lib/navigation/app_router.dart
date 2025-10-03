import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/screens/error/error_screen.dart';
import 'package:frontend/screens/auth/login_page.dart';
import 'package:frontend/screens/professor/dashboard.dart';
import 'package:frontend/screens/student/dashboard.dart';
import 'package:frontend/screens/professor/session/sessionCreation.dart';

final GoRouter router = GoRouter(
  errorBuilder: (context, state) => ErrorScreen(error: state.error),
  routes: <GoRoute>[
    GoRoute(
      path: '/',
      builder: (BuildContext context, GoRouterState state) {
        return const LoginPage();
      },
    ),
    GoRoute(
      path: '/dashboard/student',
      builder: (BuildContext context, GoRouterState state) {
        return StudentDashboard();
      },
    ),
    GoRoute(
      path: '/dashboard/professor',
      builder: (BuildContext context, GoRouterState state) {
        return ProfessorDashboard();
      },
    ),
    GoRoute(
      path: '/SessionCreation/professor',
      builder: (BuildContext context, GoRouterState state) {
        return CreatePassPage();
      },
    ),
  ],
);
