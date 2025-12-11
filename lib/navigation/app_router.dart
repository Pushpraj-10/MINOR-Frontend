import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/screens/error/error_screen.dart';
import 'package:frontend/screens/auth/login_page.dart';
import 'package:frontend/screens/auth/register_page.dart';
import 'package:frontend/screens/professor/dashboard.dart';
import 'package:frontend/screens/student/dashboard.dart';
import 'package:frontend/screens/professor/session/sessionCreation.dart';
import 'package:frontend/screens/professor/session/sessions_list_page.dart';
import 'package:frontend/screens/professor/session/session_attendance_page.dart';
import 'package:frontend/screens/student/attendance/attendance_page.dart';
import 'package:frontend/screens/student/attendance/attendance_dashboard.dart';
import 'package:frontend/screens/student/attendance/leave_page.dart';
import 'package:frontend/screens/admin/manage_users_screen.dart';
import 'package:frontend/screens/admin/edit_user_role_screen.dart';
import 'package:frontend/screens/admin/biometric_requests_screen.dart';
import 'package:frontend/screens/admin/dashboard.dart';
import 'package:frontend/screens/professor/attendance-record/attendance_records.dart';
import 'package:frontend/screens/professor/attendance-record/leave_requests.dart';
import 'package:frontend/screens/admin/bulk_users.dart';
import 'package:frontend/screens/admin/reports_page.dart';
import 'package:frontend/screens/professor/reports_page.dart';

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
        return const AttendanceDashboard();
      },
    ),
    GoRoute(
      path: '/student/attendance/scan',
      builder: (BuildContext context, GoRouterState state) {
        return const AttendancePage();
      },
    ),
    GoRoute(
      path: '/student/attendance/leave',
      builder: (BuildContext context, GoRouterState state) {
        return const LeavePage();
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
      path: '/professor/attendance-records',
      builder: (BuildContext context, GoRouterState state) {
        return const AttendanceRecordsPage();
      },
    ),
    GoRoute(
      path: '/professor/leave-requests',
      builder: (BuildContext context, GoRouterState state) {
        return const LeaveRequestsPage();
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
    GoRoute(
      path: '/admin/bulk-users',
      builder: (BuildContext context, GoRouterState state) {
        return const BulkUsersScreen();
      },
    ),
    GoRoute(
      path: '/admin/reports',
      builder: (BuildContext context, GoRouterState state) {
        return const AdminReportsPage();
      },
    ),
    GoRoute(
      path: '/professor/reports',
      builder: (BuildContext context, GoRouterState state) {
        return const ProfessorReportsPage();
      },
    ),
  ],
);
