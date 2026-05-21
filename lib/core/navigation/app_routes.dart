abstract final class AppRoutes {
  static const onboarding = '/onboarding';
  static const projects = '/projects';
  static const premium = '/premium';

  static const onboardingName = 'Onboarding';
  static const projectsName = 'Projects';
  static const captureName = 'Capture';
  static const timelineName = 'Timeline';
  static const replayName = 'Replay';
  static const premiumName = 'Premium';

  static String capture(String projectId) => '/projects/$projectId/capture';
  static String timeline(String projectId) => '/projects/$projectId/timeline';
  static String replay(String projectId) => '/projects/$projectId/replay';
}
