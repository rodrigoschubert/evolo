import 'dart:async';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

import 'app.dart';
import 'core/services/app_bootstrap.dart';
import 'core/services/error_tracking_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final bootstrap = AppBootstrap();
  await bootstrap.initialize();

  FlutterError.onError = (details) {
    FlutterError.presentError(details);
    unawaited(ErrorTrackingService.captureFlutterError(details));
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    unawaited(ErrorTrackingService.captureException(error, stackTrace: stack));
    return true;
  };

  await runZonedGuarded(
    () async {
      final sentryDsn = const String.fromEnvironment('SENTRY_DSN');

      if (sentryDsn.isEmpty) {
        runApp(const ProviderScope(child: EvoloApp()));
        return;
      }

      await SentryFlutter.init((options) {
        options.dsn = sentryDsn;
        options.tracesSampleRate = 0.2;
        options.environment = const String.fromEnvironment(
          'APP_ENV',
          defaultValue: 'development',
        );
      }, appRunner: () => runApp(const ProviderScope(child: EvoloApp())));
    },
    (error, stackTrace) {
      unawaited(
        ErrorTrackingService.captureException(error, stackTrace: stackTrace),
      );
    },
  );
}
