import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/analytics_service.dart';

final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.instance.authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  return authState?.session?.user ?? SupabaseService.instance.currentUser;
});

final authAnalyticsProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<AuthState>>(authStateProvider, (previous, next) async {
    final prevUser = previous?.value?.session?.user;
    final nextUser = next.value?.session?.user;

    if (prevUser == null && nextUser != null) {
      await AnalyticsService.instance.capture(AnalyticsEvent.authGoogleSuccess);
    }
  });
});
