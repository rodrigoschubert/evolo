package com.rsfsoftware.evolo

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugins.GeneratedPluginRegistrant

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        try {
            super.configureFlutterEngine(flutterEngine)
        } catch (t: Throwable) {
            android.util.Log.e("MainActivity", "Automatic plugin registration failed: ${t.message}", t)
        }
        // Manually call registerWith to ensure plugins are registered
        GeneratedPluginRegistrant.registerWith(flutterEngine)
    }
}
