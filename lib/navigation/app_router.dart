import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:frontend/screens/error/error_screen.dart';
import 'package:frontend/screens/auth/login_page.dart';
import 'package:frontend/screens/auth/register_page.dart';
import 'package:frontend/screens/professor/dashboard.dart';
import 'package:frontend/screens/student/dashboard.dart';
import 'package:frontend/screens/professor/session/sessionCreation.dart';
import 'package:frontend/screens/student/session/attendance_scan_page.dart';
import 'package:frontend/screens/student/session/face_detection_page.dart';

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
    GoRoute(
      path: '/student/attendance/face_verification',
      builder: (BuildContext context, GoRouterState state) {
        return const FaceDetectionPage();
      },
    ),
  ],
);
