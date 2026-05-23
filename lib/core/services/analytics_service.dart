import 'package:flutter_dotenv/flutter_dotenv.dart';
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
  logoutCompleted('logout_completed'),
  premiumScreenOpened('premium_screen_opened'),
  purchaseStarted('purchase_started'),
  purchaseSuccess('purchase_success'),
  purchaseFailed('purchase_failed'),
  restoreStarted('restore_started'),
  restoreSuccess('restore_success'),
  premiumEnabled('premium_enabled');

  const AnalyticsEvent(this.key);

  final String key;
}

class AnalyticsService {
  AnalyticsService._();

  static final instance = AnalyticsService._();

  bool _enabled = false;
  String? _identifiedUserId;

  Future<void> initialize() async {
    const apiKeyFromDefine = String.fromEnvironment('POSTHOG_API_KEY');
    final apiKey = apiKeyFromDefine.isNotEmpty
        ? apiKeyFromDefine
        : dotenv.env['POSTHOG_API_KEY'] ?? '';
    if (apiKey.isEmpty) {
      return;
    }

    final config = PostHogConfig(apiKey);
    const hostFromDefine = String.fromEnvironment('POSTHOG_HOST');
    config.host = hostFromDefine.isNotEmpty
        ? hostFromDefine
        : dotenv.env['POSTHOG_HOST'] ?? 'https://us.i.posthog.com';
    config.captureApplicationLifecycleEvents = true;

    await Posthog().setup(config);
    _enabled = true;
    await _registerAppProperties();
    await capture(AnalyticsEvent.appOpened);
  }

  Future<void> capture(
    AnalyticsEvent event, {
    Map<String, Object> properties = const {},
  }) async {
    if (!_enabled) {
      return;
    }

    try {
      await Posthog().capture(eventName: event.key, properties: properties);
    } catch (_) {
      // Analytics should never block product flows.
    }
  }

  Future<void> identifyUser({
    required String userId,
    String? authProvider,
    bool? isPremium,
    String? createdAt,
  }) async {
    if (!_enabled || _identifiedUserId == userId) {
      return;
    }

    final userProperties = <String, Object>{};
    if (authProvider != null && authProvider.isNotEmpty) {
      userProperties['auth_provider'] = authProvider;
    }
    if (isPremium != null) {
      userProperties['is_premium'] = isPremium;
    }

    final userPropertiesSetOnce = <String, Object>{};
    if (createdAt != null && createdAt.isNotEmpty) {
      userPropertiesSetOnce['created_at'] = createdAt;
    }

    try {
      await Posthog().identify(
        userId: userId,
        userProperties: userProperties,
        userPropertiesSetOnce: userPropertiesSetOnce,
      );
      _identifiedUserId = userId;
      await Posthog().reloadFeatureFlags();
    } catch (_) {
      // Analytics identity should not affect authentication.
    }
  }

  Future<void> resetUser() async {
    if (!_enabled || _identifiedUserId == null) {
      return;
    }

    try {
      await Posthog().reset();
      _identifiedUserId = null;
      await _registerAppProperties();
    } catch (_) {
      // Analytics reset should not affect logout.
    }
  }

  Future<void> _registerAppProperties() async {
    const appEnvFromDefine = String.fromEnvironment('APP_ENV');
    final appEnv = appEnvFromDefine.isNotEmpty
        ? appEnvFromDefine
        : dotenv.env['APP_ENV'] ?? 'development';

    try {
      await Posthog().register('app_env', appEnv);
    } catch (_) {
      // Super properties are helpful, but optional.
    }
  }
}
