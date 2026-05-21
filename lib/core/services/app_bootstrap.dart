import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'analytics_service.dart';

class AppBootstrap {
  Future<void> initialize() async {
    await dotenv.load(mergeWith: {});
    await AnalyticsService.instance.initialize();
    await _initializeSupabaseIfConfigured();
  }

  Future<void> _initializeSupabaseIfConfigured() async {
    final url = dotenv.env['SUPABASE_URL'] ?? '';
    final anonKey = dotenv.env['SUPABASE_ANON_KEY'] ?? '';

    if (url.isEmpty || anonKey.isEmpty) {
      return;
    }

    await Supabase.initialize(url: url, anonKey: anonKey);
  }
}
