import 'package:flutter/foundation.dart';
import 'package:sentry_flutter/sentry_flutter.dart';

class ErrorTrackingService {
  static Future<void> captureFlutterError(FlutterErrorDetails details) {
    return Sentry.captureException(
      details.exception,
      stackTrace: details.stack,
      hint: Hint.withMap({
        'library': details.library,
        'context': details.context?.toDescription(),
      }),
    );
  }

  static Future<void> captureException(
    Object error, {
    StackTrace? stackTrace,
    Map<String, Object?> context = const {},
  }) {
    return Sentry.captureException(
      error,
      stackTrace: stackTrace,
      hint: context.isEmpty ? null : Hint.withMap(context),
    );
  }
}
