import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:posthog_flutter/posthog_flutter.dart';

import '../../features/account/presentation/premium_screen.dart';
import '../../features/capture/presentation/capture_screen.dart';
import '../../features/onboarding/presentation/onboarding_screen.dart';
import '../../features/projects/presentation/projects_screen.dart';
import '../../features/replay/presentation/replay_screen.dart';
import '../../features/timeline/presentation/timeline_screen.dart';
import 'app_routes.dart';

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    initialLocation: AppRoutes.onboarding,
    redirect: (context, state) {
      final uri = state.uri;
      if (uri.scheme == 'evolo' && uri.host == 'login-callback') {
        return AppRoutes.premium;
      }
      return null;
    },
    observers: [PosthogObserver()],
    routes: [
      GoRoute(
        name: AppRoutes.onboardingName,
        path: AppRoutes.onboarding,
        builder: (context, state) => const OnboardingScreen(),
      ),
      GoRoute(
        name: AppRoutes.projectsName,
        path: AppRoutes.projects,
        builder: (context, state) => const ProjectsScreen(),
      ),
      GoRoute(
        name: AppRoutes.captureName,
        path: '/projects/:projectId/capture',
        builder: (context, state) =>
            CaptureScreen(projectId: state.pathParameters['projectId']!),
      ),
      GoRoute(
        name: AppRoutes.timelineName,
        path: '/projects/:projectId/timeline',
        builder: (context, state) =>
            TimelineScreen(projectId: state.pathParameters['projectId']!),
      ),
      GoRoute(
        name: AppRoutes.replayName,
        path: '/projects/:projectId/replay',
        builder: (context, state) =>
            ReplayScreen(projectId: state.pathParameters['projectId']!),
      ),
      GoRoute(
        name: AppRoutes.premiumName,
        path: AppRoutes.premium,
        builder: (context, state) => const PremiumScreen(),
      ),
    ],
  );
});
