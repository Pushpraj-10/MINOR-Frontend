import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/screens/error/error_screen.dart';
import 'package:frontend/screens/auth/login_page.dart';
import 'package:frontend/screens/auth/register_page.dart';
import 'package:frontend/screens/professor/dashboard.dart';
import 'package:frontend/screens/student/dashboard.dart';
import 'package:frontend/screens/professor/session/sessionCreation.dart';
import 'package:frontend/screens/professor/sessions/sessions_list_page.dart';
import 'package:frontend/screens/professor/sessions/session_attendance_page.dart';
import 'package:frontend/screens/student/session/attendance_scan_page.dart';
import 'package:frontend/screens/admin/manage_users_screen.dart';
import 'package:frontend/screens/admin/edit_user_role_screen.dart';
import 'package:frontend/screens/admin/biometric_requests_screen.dart';
import 'package:frontend/screens/admin/dashboard.dart';

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
      path: '/register',
      builder: (BuildContext context, GoRouterState state) {
        return const RegisterPage();
      },
    ),
    GoRoute(
      path: '/student/dashboard',
      builder: (BuildContext context, GoRouterState state) {
        return StudentDashboard();
      },
    ),
    GoRoute(
      path: '/professor/dashboard',
      builder: (BuildContext context, GoRouterState state) {
        return ProfessorDashboard();
      },
    ),
    GoRoute(
      path: '/admin/dashboard',
      builder: (BuildContext context, GoRouterState state) {
        return const AdminDashboard();
      },
    ),
    GoRoute(
      path: '/professor/session',
      builder: (BuildContext context, GoRouterState state) {
        return CreatePassPage();
      },
    ),
    GoRoute(
      path: '/student/attendance',
      builder: (BuildContext context, GoRouterState state) {
        return const AttendanceScanPage();
      },
    ),
    // Face verification route removed (face-embedding flow archived)
    GoRoute(
      path: '/professor/sessions',
      builder: (BuildContext context, GoRouterState state) {
        return const ProfessorSessionsListPage();
      },
    ),
    GoRoute(
      path: '/professor/sessions/:sessionId/students',
      builder: (BuildContext context, GoRouterState state) {
        final sessionId = state.pathParameters['sessionId']!;
        return SessionAttendancePage(sessionId: sessionId);
      },
    ),
    GoRoute(
      path: '/admin/manage-users',
      builder: (BuildContext context, GoRouterState state) {
        return const ManageUsersScreen();
      },
    ),
    GoRoute(
      path: '/admin/users/:uid/edit-role',
      builder: (BuildContext context, GoRouterState state) {
        final uid = state.pathParameters['uid']!;
        final initial = state.extra;
        return EditUserRoleScreen(uid: uid, initialUser: initial);
      },
    ),
    GoRoute(
      path: '/admin/biometric-requests',
      builder: (BuildContext context, GoRouterState state) {
        return const BiometricRequestsScreen();
      },
    ),
  ],
);
