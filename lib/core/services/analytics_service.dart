import 'package:posthog_flutter/posthog_flutter.dart';

enum AnalyticsEvent {
  appOpened('app_opened'),
  onboardingCompleted('onboarding_completed'),
  projectCreated('project_created'),
  firstCaptureTaken('first_capture_taken'),
  captureAdded('capture_added'),
  replayGenerated('replay_generated'),
  exportStarted('export_started'),
  exportCompleted('export_completed'),
  opacityAdjusted('opacity_adjusted'),
  cameraOpened('camera_opened'),
  permissionDenied('permission_denied'),
  authGoogleStarted('auth_google_started'),
  authGoogleSuccess('auth_google_success'),
  authGoogleFailed('auth_google_failed'),
  logoutCompleted('logout_completed');

  const AnalyticsEvent(this.key);

  final String key;
}

class AnalyticsService {
  AnalyticsService._();

  static final instance = AnalyticsService._();

  bool _enabled = false;

  Future<void> initialize() async {
    const apiKey = String.fromEnvironment('POSTHOG_API_KEY');
    if (apiKey.isEmpty) {
      return;
    }

    final config = PostHogConfig(apiKey);
    config.host = const String.fromEnvironment(
      'POSTHOG_HOST',
      defaultValue: 'https://us.i.posthog.com',
    );
    config.captureApplicationLifecycleEvents = true;

    await Posthog().setup(config);
    _enabled = true;
    await capture(AnalyticsEvent.appOpened);
  }

  Future<void> capture(
    AnalyticsEvent event, {
    Map<String, Object> properties = const {},
  }) async {
    if (!_enabled) {
      return;
    }

    await Posthog().capture(eventName: event.key, properties: properties);
  }
}
