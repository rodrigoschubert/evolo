import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/constants/app_constants.dart';

final onboardingStoreProvider = Provider<OnboardingStore>((ref) {
  return OnboardingStore();
});

class OnboardingStore {
  Future<bool> isCompleted() async {
    final preferences = await SharedPreferences.getInstance();
    return preferences.getBool(AppConstants.onboardingCompletedKey) ?? false;
  }

  Future<void> complete() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool(AppConstants.onboardingCompletedKey, true);
  }
}
