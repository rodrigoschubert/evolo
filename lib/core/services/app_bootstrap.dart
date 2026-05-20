import 'package:supabase_flutter/supabase_flutter.dart';

import 'analytics_service.dart';

class AppBootstrap {
  Future<void> initialize() async {
    await AnalyticsService.instance.initialize();
    await _initializeSupabaseIfConfigured();
  }

  Future<void> _initializeSupabaseIfConfigured() async {
    const url = String.fromEnvironment('SUPABASE_URL');
    const anonKey = String.fromEnvironment('SUPABASE_ANON_KEY');

    if (url.isEmpty || anonKey.isEmpty) {
      return;
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
  }
}
