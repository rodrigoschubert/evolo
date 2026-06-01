import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'analytics_service.dart';

class AppBootstrap {
  Future<void> initialize() async {
    try {
      debugPrint('Evolo [Bootstrap]: Loading environment variables...');
      await dotenv.load();
    } catch (e) {
      debugPrint('Evolo [Bootstrap]: WARNING - Could not load .env file: $e');
    }

    try {
      debugPrint('Evolo [Bootstrap]: Initializing Analytics...');
      await AnalyticsService.instance.initialize();
    } catch (e) {
      debugPrint('Evolo [Bootstrap]: Error initializing Analytics: $e');
    }

    try {
      debugPrint('Evolo [Bootstrap]: Initializing Supabase...');
      await _initializeSupabaseIfConfigured();
    } catch (e) {
      debugPrint('Evolo [Bootstrap]: Error initializing Supabase: $e');
    }
    
    debugPrint('Evolo [Bootstrap]: Initialization complete.');
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
