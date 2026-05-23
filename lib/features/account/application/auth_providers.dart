import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/analytics_service.dart';
import '../domain/user_profile.dart';

class PremiumCache {
  static const _prefix = 'evolo_premium_';

  static Future<bool> isPremiumLocal(String userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getBool('$_prefix$userId') ?? false;
    } catch (_) {
      return false;
    }
  }

  static Future<void> setPremiumLocal(String userId, bool isPremium) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('$_prefix$userId', isPremium);
    } catch (_) {}
  }
}

final authStateProvider = StreamProvider<AuthState>((ref) {
  return SupabaseService.instance.authStateChanges;
});

final currentUserProvider = Provider<User?>((ref) {
  final authState = ref.watch(authStateProvider).value;
  return authState?.session?.user ?? SupabaseService.instance.currentUser;
});

class UserProfileNotifier extends AsyncNotifier<EvoloProfile?> {
  @override
  FutureOr<EvoloProfile?> build() async {
    final user = ref.watch(currentUserProvider);
    if (user == null) {
      return null;
    }
    return _loadProfile(user.id);
  }

  Future<EvoloProfile?> _loadProfile(String userId) async {
    final cachedPremium = await PremiumCache.isPremiumLocal(userId);
    EvoloProfile? cachedProfile;
    
    if (cachedPremium) {
      cachedProfile = EvoloProfile(
        id: userId,
        isPremium: true,
        premiumSource: 'cache',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );
      state = AsyncValue.data(cachedProfile);
    }

    try {
      final profile = await SupabaseService.instance.getProfile(userId);
      if (profile != null) {
        await PremiumCache.setPremiumLocal(userId, profile.isPremium);
        return profile;
      }
      return cachedProfile;
    } catch (e) {
      if (cachedPremium) {
        return cachedProfile;
      }
      rethrow;
    }
  }

  Future<void> updateLocalProfile(EvoloProfile profile) async {
    await PremiumCache.setPremiumLocal(profile.id, profile.isPremium);
    state = AsyncValue.data(profile);
  }
}

final userProfileProvider = AsyncNotifierProvider<UserProfileNotifier, EvoloProfile?>(
  UserProfileNotifier.new,
);

final isPremiumUserProvider = Provider<bool>((ref) {
  final profileState = ref.watch(userProfileProvider);
  return profileState.maybeWhen(
    data: (profile) => profile?.isPremium ?? false,
    orElse: () => false,
  );
});

final authAnalyticsProvider = Provider<void>((ref) {
  ref.listen<AsyncValue<AuthState>>(authStateProvider, (previous, next) async {
    final prevUser = previous?.value?.session?.user;
    final nextUser = next.value?.session?.user;

    if (prevUser == null && nextUser != null) {
      final isPremium = await PremiumCache.isPremiumLocal(nextUser.id);
      
      await AnalyticsService.instance.identifyUser(
        userId: nextUser.id,
        authProvider: nextUser.appMetadata['provider']?.toString(),
        isPremium: isPremium,
        createdAt: nextUser.createdAt,
      );
      await AnalyticsService.instance.capture(AnalyticsEvent.authGoogleSuccess);
    } else if (prevUser != null && nextUser == null) {
      await AnalyticsService.instance.resetUser();
    }
  });
});
